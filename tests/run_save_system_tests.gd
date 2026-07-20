# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用纯合成状态验证 100 槽 Godot 存档的往返、损坏和兼容性诊断。
extends SceneTree

const PoisonDefinition := preload("res://src/content/pal_poison_definition.gd")

var _failures: Array[String] = []


func _init() -> void:
	var database := _database_fixture()
	var session := _session_fixture()
	var save_directory := "user://pal_save_system_tests"
	var manager := PalSaveManager.new()
	_expect(manager.configure(database, save_directory, "synthetic-content-v1"), "save manager accepts an isolated synthetic fingerprint")
	for slot in range(1, PalSaveManager.SLOT_COUNT + 1):
		manager.delete_slot(slot)
	_expect(PalSaveManager.SLOT_COUNT == 100 and PalSaveManager.SLOTS_PER_PAGE == 5, "save system exposes one hundred slots in five-slot pages")
	_expect(manager.slot_path(1).ends_with("slot_001.json") and manager.slot_path(100).ends_with("slot_100.json"), "slot paths use stable three-digit names")

	# 保存前写入会话与剧情运行时修改，确保读取不是只恢复玩家坐标。
	session.scene_index = 1
	session.set_party_world_position(Vector2i(1232, 744))
	session.cash = 9876
	session.music_number = 31
	session.follower_sprite_numbers = PackedInt32Array([301, 302])
	session.collect_value = 8
	session.chase_speed_change_cycles = 12
	session.chase_range_multiplier = 3
	session.auto_battle_pending = true
	session.set_item_count(3, 7)
	session.role_hp[0] = 73
	database.scenes[1].script_on_enter = 9
	database.event_objects[1].position = Vector2i(640, 352)
	database.event_objects[1].state = 0
	database.event_objects[1].trigger_script = 8
	database.set_object_script(3, 0, 7)
	database.set_object_script(2, 0, 6)
	database.set_object_script(1, 2, 5)
	database.player_roles.scene_sprite_numbers[0] = 208
	_expect(manager.save_slot(100, session), "slot 100 saves a complete initialized session")
	var metadata := manager.slot_metadata(100)
	_expect(metadata.get("can_load") == true and metadata.get("scene_index") == 1 and metadata.get("map_number") == 12, "slot metadata exposes scene and map: %s" % [metadata])
	var party: Array = metadata.get("party", [])
	_expect(party.size() == 2 and party[0].get("role_index") == 0 and party[0].get("level") == 8 and party[1].get("role_index") == 1, "slot metadata preserves party members and levels")

	# 污染所有关键值后读档；完整往返应恢复会话、剧情对象和脚本游标。
	session.scene_index = 0
	session.set_party_world_position(Vector2i.ZERO)
	session.cash = 1
	session.follower_sprite_numbers = PackedInt32Array()
	session.collect_value = 0
	session.chase_speed_change_cycles = 0
	session.chase_range_multiplier = 1
	session.inventory.clear()
	session.role_hp[0] = 1
	database.scenes[1].script_on_enter = 0
	database.event_objects[1].position = Vector2i.ZERO
	database.event_objects[1].state = 2
	database.event_objects[1].trigger_script = 0
	database.set_object_script(3, 0, 0)
	database.set_object_script(2, 0, 0)
	database.set_object_script(1, 2, 0)
	database.player_roles.scene_sprite_numbers[0] = 1
	_expect(manager.load_slot(100, session), "slot 100 loads after structural and checksum validation: %s" % manager.error_message)
	_expect(session.scene_index == 1 and session.party_world_position() == Vector2i(1232, 744) and session.cash == 9876 and session.item_count(3) == 7 and session.role_hp[0] == 73, "load restores scene, position, cash, inventory and role values")
	_expect(session.follower_sprite_numbers == PackedInt32Array([301, 302]) and session.collect_value == 8 and session.chase_speed_change_cycles == 12 and session.chase_range_multiplier == 3 and not session.auto_battle_pending, "load restores persistent TD-001 state and clears the next-battle-only flag")
	_expect(database.scenes[1].script_on_enter == 9 and database.event_objects[1].position == Vector2i(640, 352) and database.event_objects[1].state == 0 and database.event_objects[1].trigger_script == 8, "load restores scene and EventObject runtime mutations")
	_expect(database.items[3].script_on_use == 7 and database.magic_objects[2].script_on_success == 6 and database.enemy_objects[1].script_on_ready == 5 and database.poisons[3].player_script == 7 and database.player_roles.scene_sprite_numbers[0] == 208, "load restores all OBJECT union cursor views and player scene sprite")
	_expect(not session.equipment_effects_ready, "load marks derived equipment effects for deterministic rebuild")

	# 校验和损坏必须在修改当前游戏之前失败。
	_expect(manager.save_slot(1, session), "slot 1 creates a checksum test fixture")
	var checksum_record := _read_json(manager.slot_path(1))
	var checksum_payload: Dictionary = JSON.parse_string(str(checksum_record["payload_json"]))
	checksum_payload["session"]["cash"] = 123
	checksum_record["payload_json"] = JSON.stringify(checksum_payload, "", false)
	_write_json(manager.slot_path(1), checksum_record)
	manager.configure(database, save_directory, "synthetic-content-v1")
	var cash_before_failed_load := session.cash
	_expect(not manager.load_slot(1, session) and "校验和" in manager.error_message and session.cash == cash_before_failed_load, "checksum mismatch rejects a valid-looking modified JSON without partial restore")

	_expect(manager.save_slot(2, session), "slot 2 creates a version test fixture")
	var version_record := _read_json(manager.slot_path(2))
	version_record["header"]["format_version"] = PalSaveManager.FORMAT_VERSION + 1
	_write_json(manager.slot_path(2), version_record)
	manager.configure(database, save_directory, "synthetic-content-v1")
	_expect(not manager.load_slot(2, session) and "版本不兼容" in manager.error_message, "future save versions are rejected explicitly")

	_expect(manager.save_slot(3, session), "slot 3 creates a content fingerprint fixture")
	var other_content_manager := PalSaveManager.new()
	_expect(other_content_manager.configure(database, save_directory, "synthetic-content-v2"), "second content fingerprint configures")
	_expect(not other_content_manager.load_slot(3, session) and "资源版本" in other_content_manager.error_message, "content fingerprint mismatch is diagnosed")

	var corrupt_file := FileAccess.open(manager.slot_path(4), FileAccess.WRITE)
	corrupt_file.store_string("{broken")
	corrupt_file = null
	manager.configure(database, save_directory, "synthetic-content-v1")
	var corrupt_metadata := manager.slot_metadata(4)
	_expect(corrupt_metadata.get("exists") == true and corrupt_metadata.get("can_load") == false and not str(corrupt_metadata.get("error", "")).is_empty(), "corrupt JSON appears as an unusable slot with a diagnostic")
	_expect(not manager.save_slot(0, session) and not manager.save_slot(101, session), "slot bounds reject zero and values above one hundred")

	for slot in range(1, PalSaveManager.SLOT_COUNT + 1):
		manager.delete_slot(slot)
	if _failures.is_empty():
		print("PASS: 23 versioned save-system checks")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		quit(1)


func _database_fixture() -> PalContentDatabase:
	var database := PalContentDatabase.new()
	var roles := PalPlayerRoles.new()
	roles.scene_sprite_numbers = PackedInt32Array([1, 2, 3, 4, 5, 6])
	roles.avatar_numbers = PackedInt32Array([1, 2, 3, 4, 5, 6])
	roles.name_word_indices = PackedInt32Array([0, 1, 2, 3, 4, 5])
	database.player_roles = roles
	for index in range(2):
		var scene := PalSceneDefinition.new()
		scene.map_number = 11 + index
		scene.script_on_enter = index + 1
		scene.script_on_teleport = index + 3
		scene.event_object_index = index
		database.scenes.append(scene)
		var event := PalEventObject.new()
		event.object_id = index + 1
		event.position = Vector2i(100 + index * 16, 80 + index * 8)
		event.state = 2
		event.trigger_script = index + 1
		event.auto_script = index + 2
		database.event_objects.append(event)
	for _index in range(16):
		database.scripts.append(PalScriptEntry.new())
	for object_id in range(4):
		var item := PalItemDefinition.new()
		item.object_id = object_id
		item.script_on_use = object_id
		item.script_on_equip = object_id
		item.script_on_throw = object_id
		database.items.append(item)
		var magic := PalMagicObjectDefinition.new()
		magic.object_id = object_id
		magic.script_on_success = object_id
		magic.script_on_use = object_id
		database.magic_objects.append(magic)
		var enemy := PalEnemyObjectDefinition.new()
		enemy.object_id = object_id
		enemy.script_on_turn_start = object_id
		enemy.script_on_battle_end = object_id
		enemy.script_on_ready = object_id
		database.enemy_objects.append(enemy)
		var poison := PoisonDefinition.PoisonData.new()
		poison.object_id = object_id
		poison.player_script = object_id
		poison.enemy_script = object_id
		database.poisons.append(poison)
	return database


func _session_fixture() -> GameSession:
	var session := GameSession.new()
	session.reset_new_game()
	session.party_roles = PackedInt32Array([0, 1])
	session.party_script_frames = PackedInt32Array([-1, -1, -1])
	session.party_direction = GameSession.DIR_EAST
	session.set_party_world_position(Vector2i(320, 240))
	session.role_levels = PackedInt32Array([8, 7, 6, 5, 4, 3])
	session.role_max_hp = PackedInt32Array([150, 140, 130, 120, 110, 100])
	session.role_max_mp = PackedInt32Array([100, 90, 80, 70, 60, 50])
	session.role_hp = session.role_max_hp.duplicate()
	session.role_mp = session.role_max_mp.duplicate()
	session.role_experience = PackedInt32Array([10, 20, 30, 40, 50, 60])
	session.role_attack_strength = PackedInt32Array([30, 29, 28, 27, 26, 25])
	session.role_magic_strength = PackedInt32Array([20, 21, 22, 23, 24, 25])
	session.role_defense = PackedInt32Array([15, 16, 17, 18, 19, 20])
	session.role_dexterity = PackedInt32Array([25, 24, 23, 22, 21, 20])
	session.role_flee_rate = PackedInt32Array([10, 11, 12, 13, 14, 15])
	session.role_poison_resistance = PackedInt32Array([1, 2, 3, 4, 5, 6])
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		session.role_equipments_by_role.append(PackedInt32Array([0, 0, 0, 0, 0, 0]))
		session.role_elemental_resistances_by_role.append(PackedInt32Array([role_index, 0, 0, 0, 0]))
		session.role_status_rounds_by_role.append(PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]))
		session.role_poisons_by_role.append({})
		session.learned_magics_by_role.append(PackedInt32Array([1]) if role_index == 0 else PackedInt32Array())
	return session


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  ", false))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
