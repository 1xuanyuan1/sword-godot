# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal script.c PAL_RunTriggerScript equipment opcodes and global.c PAL_UpdateEquipments.
# SPDX-License-Identifier: GPL-3.0-or-later
## 解释物品装备脚本，并原子地维护装备槽、背包交换和装备属性效果。
## 静态脚本来自 `PalContentDatabase`，所有可变结果均写入 `GameSession`。
class_name PalEquipmentManager
extends RefCounted

const MAX_SCRIPT_STEPS := 64
const STATUS_DUAL_ATTACK := 8

## 最近一次装备或重建失败的中文原因；成功时为空。
var error_message: String = ""
## 最近一次替换下来的装备对象编号；没有旧装备时为 0。
var last_unequipped_item: int = 0
## 本地数据中遇到、但当前装备层尚未实现的操作码集合。
var unsupported_operations: PackedInt32Array = PackedInt32Array()

var database: PalContentDatabase
var session: GameSession
var _current_slot: int = -1
var _script_equipped_item: bool = false


## 注入内容数据库和会话，并按当前六槽装备重建全部属性效果。
## 数据无效时返回 `false`，不会修改背包中的物品数量。
func configure(content_database: PalContentDatabase, game_session: GameSession) -> bool:
	database = content_database
	session = game_session
	error_message = ""
	last_unequipped_item = 0
	unsupported_operations = PackedInt32Array()
	if database == null or session == null or database.player_roles == null:
		error_message = "装备系统缺少内容数据库、会话或 PLAYERROLES"
		return false
	if not session.initialize_role_state(database.player_roles):
		error_message = "装备系统无法初始化角色状态"
		return false
	return rebuild_all_effects()


## 清空旧加成并重新执行六名角色当前装备的装备脚本。
## 该过程只重建效果，不交换背包；损坏的装备对象会使返回值为 `false`。
func rebuild_all_effects() -> bool:
	if database == null or session == null:
		error_message = "装备系统尚未配置"
		return false
	error_message = ""
	unsupported_operations = PackedInt32Array()
	session.clear_all_equipment_effects()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		for slot_index in range(GameSession.EQUIPMENT_SLOT_COUNT):
			var item_id := session.equipped_item(role_index, slot_index)
			if item_id <= 0:
				continue
			var item := database.item_definition(item_id)
			if item == null or item.script_on_equip <= 0:
				error_message = "角色 %d 的装备槽 %d 引用了无效对象 %d" % [role_index, slot_index, item_id]
				return false
			if not _run_equip_script(item, role_index, false, slot_index):
				return false
	session.equipment_effects_ready = true
	_warn_about_unsupported_operations()
	return true


## 为指定角色装备背包中的物品。
## 会校验角色许可、库存和脚本；成功时新装备减一、旧装备回到背包，并更新 `last_unequipped_item`。
func equip_item(item_id: int, role_index: int) -> bool:
	error_message = ""
	last_unequipped_item = 0
	if database == null or session == null:
		error_message = "装备系统尚未配置"
		return false
	var item := database.item_definition(item_id)
	if item == null or not item.is_equipable():
		error_message = "对象 %d 不是可装备物品" % item_id
		return false
	if not item.can_equip_by_role(role_index):
		error_message = "%s不能装备%s" % [_role_name(role_index), database.get_word(item_id)]
		return false
	if session.item_count(item_id) <= 0:
		error_message = "背包中没有%s" % database.get_word(item_id)
		return false
	# PAL_EquipItemMenu 进入时先把待装备物写入 wLastUnequippedItem；若角色已经穿着同一物品，
	# 0018 不发生交换，界面仍停留在该物品而不是错误返回列表。
	last_unequipped_item = item_id
	_script_equipped_item = false
	if not _run_equip_script(item, role_index, true):
		return false
	if not _script_equipped_item:
		error_message = "%s的装备脚本没有执行 0018 装备指令" % database.get_word(item_id)
		return false
	session.equipment_effects_ready = true
	_warn_about_unsupported_operations()
	return true


## 卸下指定角色的一个装备槽并把物品放回背包。
## 槽为空或索引无效时返回 `false`；成功后会清除该槽全部装备效果。
func unequip_slot(role_index: int, slot_index: int) -> bool:
	error_message = ""
	last_unequipped_item = 0
	if session == null or role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT or slot_index < 0 or slot_index >= GameSession.EQUIPMENT_SLOT_COUNT:
		error_message = "卸下装备的角色或部位无效"
		return false
	var item_id := session.equipped_item(role_index, slot_index)
	if item_id <= 0:
		error_message = "该部位没有装备"
		return false
	session.clear_equipment_effects(role_index, slot_index)
	session.replace_equipped_item(role_index, slot_index, 0)
	session.change_item_count(item_id, 1)
	session.equipment_effects_ready = true
	last_unequipped_item = item_id
	return true


## 执行脚本操作码 `0023` 的卸装语义。
## `one_based_slot == 0` 卸下全部六槽，否则只卸下 1–6 对应部位。
func remove_equipment_from_script(role_index: int, one_based_slot: int) -> bool:
	error_message = ""
	last_unequipped_item = 0
	if session == null or role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		error_message = "0023 指定了无效角色 %d" % role_index
		return false
	if one_based_slot < 0 or one_based_slot > GameSession.EQUIPMENT_SLOT_COUNT:
		error_message = "0023 指定了无效装备部位 %d" % one_based_slot
		return false
	var slots := range(GameSession.EQUIPMENT_SLOT_COUNT) if one_based_slot == 0 else [one_based_slot - 1]
	var changed := false
	for slot_index in slots:
		var item_id := session.equipped_item(role_index, slot_index)
		session.clear_equipment_effects(role_index, slot_index)
		if item_id > 0:
			session.replace_equipped_item(role_index, slot_index, 0)
			session.change_item_count(item_id, 1)
			last_unequipped_item = item_id
			changed = true
	session.equipment_effects_ready = true
	return changed


## 从背包和当前队伍的装备槽中移除最多 `amount` 个指定对象，并返回实际数量。
## 对齐脚本 `0020`：先扣背包，不足部分直接清空装备槽，不把被移除装备放回背包。
func remove_item_including_equipment(item_id: int, amount: int) -> int:
	if session == null or item_id <= 0 or amount <= 0:
		return 0
	var remaining := amount
	var inventory_removed := mini(remaining, session.item_count(item_id))
	if inventory_removed > 0:
		session.change_item_count(item_id, -inventory_removed)
		remaining -= inventory_removed
	for role_index in session.party_roles:
		if remaining <= 0:
			break
		for slot_index in range(GameSession.EQUIPMENT_SLOT_COUNT):
			if session.equipped_item(role_index, slot_index) != item_id:
				continue
			session.clear_equipment_effects(role_index, slot_index)
			session.replace_equipped_item(role_index, slot_index, 0)
			remaining -= 1
			if remaining <= 0:
				break
	session.equipment_effects_ready = true
	return amount - remaining


func _run_equip_script(item: PalItemDefinition, role_index: int, exchange_inventory: bool, expected_slot: int = -1) -> bool:
	_current_slot = -1
	var entry_index := item.script_on_equip
	for _step in range(MAX_SCRIPT_STEPS):
		if entry_index <= 0 or entry_index >= database.scripts.size():
			error_message = "%s的装备脚本入口 %d 越界" % [database.get_word(item.object_id), entry_index]
			return false
		var entry := database.scripts[entry_index]
		match entry.operation:
			0x0000:
				return true
			0x0017:
				if not _set_extra_attribute(entry, role_index):
					return false
			0x0018:
				if not _equip_from_instruction(entry, item.object_id, role_index, exchange_inventory, expected_slot):
					return false
			0x001A:
				if not _set_player_stat(entry, role_index):
					return false
			0x0023:
				remove_equipment_from_script(entry.operands[0], entry.operands[1])
			0x002D:
				if _current_slot >= 0:
					session.set_equipment_status(_current_slot, entry.operands[0], role_index, entry.operands[1])
			_:
				# 少量后期饰品会施加 99 级毒等特殊效果；先保留诊断，不能把未知脚本伪造成普通数值。
				if entry.operation not in unsupported_operations:
					unsupported_operations.append(entry.operation)
		entry_index += 1
	error_message = "%s的装备脚本超过 %d 条指令" % [database.get_word(item.object_id), MAX_SCRIPT_STEPS]
	return false


func _equip_from_instruction(entry: PalScriptEntry, requested_item_id: int, role_index: int, exchange_inventory: bool, expected_slot: int) -> bool:
	var slot_index := entry.operands[0] - 0x0b
	var script_item_id := entry.operands[1]
	if slot_index < 0 or slot_index >= GameSession.EQUIPMENT_SLOT_COUNT:
		error_message = "0018 指定了无效装备部位 %d" % entry.operands[0]
		return false
	if script_item_id != requested_item_id:
		error_message = "物品 %d 的 0018 错误地引用对象 %d" % [requested_item_id, script_item_id]
		return false
	if expected_slot >= 0 and slot_index != expected_slot:
		error_message = "装备对象 %d 位于槽 %d，但脚本声明槽 %d" % [requested_item_id, expected_slot, slot_index]
		return false
	_current_slot = slot_index
	session.clear_equipment_effects(role_index, slot_index)
	if not exchange_inventory:
		if session.equipped_item(role_index, slot_index) != requested_item_id:
			error_message = "角色 %d 的槽 %d 没有重建所需的对象 %d" % [role_index, slot_index, requested_item_id]
			return false
		return true
	var previous := session.equipped_item(role_index, slot_index)
	if previous != requested_item_id:
		if session.item_count(requested_item_id) <= 0:
			error_message = "装备过程中%s已不在背包" % database.get_word(requested_item_id)
			return false
		session.replace_equipped_item(role_index, slot_index, requested_item_id)
		session.change_item_count(requested_item_id, -1)
		if previous > 0:
			session.change_item_count(previous, 1)
		last_unequipped_item = previous
	_script_equipped_item = true
	return true


func _set_extra_attribute(entry: PalScriptEntry, role_index: int) -> bool:
	var slot_index := entry.operands[0] - 0x0b
	if slot_index < 0 or slot_index >= GameSession.EQUIPMENT_EFFECT_SLOT_COUNT:
		error_message = "0017 指定了无效装备效果槽 %d" % entry.operands[0]
		return false
	return session.set_equipment_effect(slot_index, entry.operands[1], role_index, entry.operands[2])


func _set_player_stat(entry: PalScriptEntry, role_index: int) -> bool:
	var target_role := role_index if entry.operands[2] == 0 else entry.operands[2] - 1
	var effect_slot := _current_slot if _current_slot >= 0 else GameSession.EQUIPMENT_SLOT_COUNT
	return session.set_equipment_effect(effect_slot, entry.operands[0], target_role, entry.operands[1])


func _role_name(role_index: int) -> String:
	if database == null or database.player_roles == null:
		return "角色%d" % role_index
	return database.get_word(database.player_roles.name_word_for(role_index))


func _warn_about_unsupported_operations() -> void:
	if unsupported_operations.is_empty():
		return
	var labels: PackedStringArray = PackedStringArray()
	for operation in unsupported_operations:
		labels.append("%04X" % operation)
	push_warning("装备脚本仍包含待接入的特殊效果操作码：%s" % ", ".join(labels))
