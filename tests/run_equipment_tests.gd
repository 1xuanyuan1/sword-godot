# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用完全合成的角色、物品与脚本验证六槽装备、背包交换和属性效果。
## 本测试不读取 `Data/` 或 `generated/`，可直接在 GitHub CI 运行。
extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	var database := _synthetic_database()
	var session := GameSession.new()
	session.party_roles = PackedInt32Array([0])
	var manager := PalEquipmentManager.new()
	_expect(manager.configure(database, session), "equipment manager rebuilds initial equipment")
	_expect(session.equipped_item(0, 3) == 166, "initial hand equipment is preserved")
	_expect(session.attack_strength_for(0) == 22 and session.dexterity_for(0) == 23, "initial weapon script contributes attack and dexterity")
	var weapon_preview := manager.preview_stat_differences(167, 0)
	_expect(weapon_preview.valid and weapon_preview.can_equip and weapon_preview.deltas == PackedInt32Array([3, 0, 0, -3, 0]), "shop preview compares a candidate weapon against the currently equipped weapon")
	_expect(session.equipped_item(0, 3) == 166 and session.attack_strength_for(0) == 22 and session.dexterity_for(0) == 23, "shop preview does not mutate the live equipment or stats")
	var ineligible_preview := manager.preview_stat_differences(167, 1)
	_expect(ineligible_preview.valid and not ineligible_preview.can_equip and ineligible_preview.deltas.is_empty(), "shop preview marks an ineligible role without simulating equipment")
	_expect(session.cooperative_magic_for(0, database.player_roles) == 105, "base PLAYERROLES cooperative magic is available without equipment override")
	session.set_equipment_effect(0, GameSession.EQUIPMENT_EFFECT_COOPERATIVE_MAGIC, 0, 205)
	_expect(session.cooperative_magic_for(0, database.player_roles) == 205, "equipment effect group 65 overrides cooperative magic")
	session.clear_equipment_effects(0, 0)
	session.set_item_count(166, 1)
	_expect(manager.equip_item(166, 0) and session.item_count(166) == 1 and manager.last_unequipped_item == 166, "equipping the same item preserves inventory and wLastUnequippedItem")
	session.set_item_count(166, 0)

	session.set_item_count(201, 1)
	_expect(manager.equip_item(201, 0), "equippable head item can be equipped")
	_expect(session.equipped_item(0, 0) == 201 and session.item_count(201) == 0, "new head item leaves inventory and enters its slot")
	_expect(session.defense_for(0) == 24 and manager.last_unequipped_item == 0, "empty slot adds defense without producing an old item")

	session.set_item_count(167, 1)
	_expect(manager.equip_item(167, 0), "second weapon replaces the initial weapon")
	_expect(session.equipped_item(0, 3) == 167 and session.item_count(166) == 1 and session.item_count(167) == 0, "replacement returns the old weapon to inventory")
	_expect(manager.last_unequipped_item == 166 and session.attack_strength_for(0) == 25 and session.dexterity_for(0) == 20, "replacement clears old slot effects before applying new ones")
	_expect(session.can_attack_all(0, database.player_roles), "001A attack-all effect is visible to battle logic")

	_expect(not manager.equip_item(167, 1), "role permission flags reject an ineligible character")
	_expect(manager.unequip_slot(0, 3), "equipped weapon can be removed")
	_expect(session.equipped_item(0, 3) == 0 and session.item_count(167) == 1 and session.attack_strength_for(0) == 20, "unequip restores inventory and base stats")
	_expect(not session.can_attack_all(0, database.player_roles), "unequip clears special attack-all effect")

	session.set_item_count(170, 1)
	_expect(manager.equip_item(170, 0) and session.has_equipment_status(0, PalEquipmentManager.STATUS_DUAL_ATTACK), "002D equipment script keeps the dual-attack status")
	_expect(manager.remove_equipment_from_script(0, 0), "0023 zero slot removes all equipment")
	_expect(session.equipment_for_role(0) == PackedInt32Array([0, 0, 0, 0, 0, 0]), "0023 clears all six equipment slots")
	_expect(not session.has_equipment_status(0, PalEquipmentManager.STATUS_DUAL_ATTACK) and session.defense_for(0) == 20, "0023 clears status and attribute effects")

	session.set_item_count(201, 1)
	manager.equip_item(201, 0)
	var removal_script := database.scripts.size()
	_append_script(database, 0x0020, [201, 1, 0])
	_append_script(database, 0, [0, 0, 0])
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.run_trigger(removal_script)
	_expect(session.equipped_item(0, 0) == 0 and session.item_count(201) == 0, "0020 removes an equipped quest item when inventory is empty")
	vm.free()

	if _failures.is_empty():
		print("PASS: %d equipment system checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("%d/%d equipment checks failed" % [_failures.size(), _checks])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _synthetic_database() -> PalContentDatabase:
	var database := PalContentDatabase.new()
	database.player_roles = _synthetic_roles()
	database.words.resize(220)
	database.words[0] = "李逍遥"
	database.words[166] = "木剑"
	database.words[167] = "测试剑"
	database.words[170] = "双击剑"
	database.words[201] = "皮帽"
	_append_script(database, 0, [0, 0, 0])
	var wood_sword_script := database.scripts.size()
	_append_script(database, 0x0018, [0x0e, 166, 0])
	_append_script(database, 0x0017, [0x0e, GameSession.EQUIPMENT_EFFECT_ATTACK, 2])
	_append_script(database, 0x0017, [0x0e, GameSession.EQUIPMENT_EFFECT_DEXTERITY, 3])
	_append_script(database, 0, [0, 0, 0])
	var test_sword_script := database.scripts.size()
	_append_script(database, 0x0018, [0x0e, 167, 0])
	_append_script(database, 0x0017, [0x0e, GameSession.EQUIPMENT_EFFECT_ATTACK, 5])
	_append_script(database, 0x001a, [GameSession.EQUIPMENT_EFFECT_ATTACK_ALL, 1, 0])
	_append_script(database, 0, [0, 0, 0])
	var dual_sword_script := database.scripts.size()
	_append_script(database, 0x0018, [0x0e, 170, 0])
	_append_script(database, 0x002d, [PalEquipmentManager.STATUS_DUAL_ATTACK, 0x7ff8, 0])
	_append_script(database, 0, [0, 0, 0])
	var leather_cap_script := database.scripts.size()
	_append_script(database, 0x0018, [0x0b, 201, 0])
	_append_script(database, 0x0017, [0x0b, GameSession.EQUIPMENT_EFFECT_DEFENSE, 4])
	_append_script(database, 0, [0, 0, 0])
	_add_item(database, 166, wood_sword_script)
	_add_item(database, 167, test_sword_script)
	_add_item(database, 170, dual_sword_script)
	_add_item(database, 201, leather_cap_script)
	return database


func _synthetic_roles() -> PalPlayerRoles:
	var roles := PalPlayerRoles.new()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		roles.avatar_numbers.append(0)
		roles.battle_sprite_numbers.append(0)
		roles.scene_sprite_numbers.append(0)
		roles.name_word_indices.append(0)
		roles.attack_all.append(0)
		roles.levels.append(1)
		roles.max_hp.append(100)
		roles.max_mp.append(50)
		roles.hp.append(100)
		roles.mp.append(50)
		roles.equipments_by_role.append(PackedInt32Array([0, 0, 0, 166 if role_index == 0 else 0, 0, 0]))
		roles.attack_strengths.append(20)
		roles.magic_strengths.append(20)
		roles.defenses.append(20)
		roles.dexterities.append(20)
		roles.flee_rates.append(20)
		roles.poison_resistances.append(0)
		roles.elemental_resistances_by_role.append(PackedInt32Array([0, 0, 0, 0, 0]))
		roles.covered_by.append(0)
		roles.magics_by_role.append(PackedInt32Array())
		roles.cooperative_magics.append(0)
		roles.walk_frames.append(3)
		roles.death_sounds.append(0)
		roles.attack_sounds.append(0)
		roles.weapon_sounds.append(0)
		roles.critical_sounds.append(0)
		roles.magic_sounds.append(0)
		roles.cover_sounds.append(0)
		roles.dying_sounds.append(0)
	roles.cooperative_magics[0] = 105
	return roles


func _append_script(database: PalContentDatabase, operation: int, operands: Array) -> void:
	var entry := PalScriptEntry.new()
	entry.operation = operation
	entry.operands = PackedInt32Array(operands)
	database.scripts.append(entry)


func _add_item(database: PalContentDatabase, item_id: int, equip_script: int) -> void:
	while database.items.size() <= item_id:
		database.items.append(PalItemDefinition.new())
	var item := PalItemDefinition.new()
	item.object_id = item_id
	item.script_on_equip = equip_script
	item.flags = PalItemDefinition.FLAG_EQUIPABLE | PalItemDefinition.FLAG_EQUIPABLE_BY_ROLE_FIRST
	database.items[item_id] = item
