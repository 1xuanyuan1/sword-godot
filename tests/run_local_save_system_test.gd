# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入的完整 PAL 数据验证真实 5332 个 EventObject 存档往返。
## 测试写入独立的 `user://pal_local_save_system_test/`，不会接触玩家正式存档。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("FAIL: %s" % database.error_message)
		quit(1)
		return
	var session := GameSession.new()
	session.reset_new_game()
	var equipment_manager := PalEquipmentManager.new()
	if not equipment_manager.configure(database, session):
		printerr("FAIL: %s" % equipment_manager.error_message)
		quit(1)
		return
	var manager := PalSaveManager.new()
	if not manager.configure(database, "user://pal_local_save_system_test"):
		printerr("FAIL: %s" % manager.error_message)
		quit(1)
		return
	manager.delete_slot(100)
	session.scene_index = 11
	session.party_roles = PackedInt32Array([0, 1])
	session.set_party_world_position(Vector2i(1232, 744))
	session.cash = 500
	session.set_item_count(272, 1)
	var event := database.event_objects[237]
	var original_event_state := event.state
	var original_scene_entry := database.scenes[11].script_on_enter
	event.state = 0
	database.scenes[11].script_on_enter = 0
	if not manager.save_slot(100, session):
		printerr("FAIL: %s" % manager.error_message)
		quit(1)
		return
	var metadata := manager.slot_metadata(100)
	session.scene_index = 0
	session.set_party_world_position(Vector2i.ZERO)
	session.cash = 0
	session.inventory.clear()
	event.state = original_event_state
	database.scenes[11].script_on_enter = original_scene_entry
	if not manager.load_slot(100, session):
		printerr("FAIL: %s" % manager.error_message)
		quit(1)
		return
	var valid: bool = bool(metadata.get("can_load", false)) and metadata.get("party", []).size() == 2
	valid = valid and session.scene_index == 11 and session.party_world_position() == Vector2i(1232, 744)
	valid = valid and session.cash == 500 and session.item_count(272) == 1
	valid = valid and event.state == 0 and database.scenes[11].script_on_enter == 0
	var file := FileAccess.open(manager.slot_path(100), FileAccess.READ)
	var file_size := file.get_length() if file != null else 0
	manager.delete_slot(100)
	if not valid:
		printerr("FAIL: 真实资源存档往返状态不一致：%s" % [metadata])
		quit(1)
		return
	print("PASS: 真实资源 100 槽存档往返完成；事件 %d 个，存档 %d 字节" % [database.event_objects.size(), file_size])
	quit(0)
