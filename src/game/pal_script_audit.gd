# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从真实场景、对象和战斗根入口遍历脚本控制流，并按六类运行上下文验证支持情况。
class_name PalScriptAudit
extends RefCounted

enum Context {
	TRIGGER,
	AUTO,
	INSTANT,
	EQUIPMENT,
	BATTLE_EFFECT,
	ENEMY_BATTLE,
}

const CONTEXT_NAMES := ["主触发", "自动", "即时", "装备", "战斗效果", "敌人战斗"]
const MAX_ENTRIES_PER_ROOT := 4096


## 返回包含 roots/operations/unsupported/used_operations 的审计报告。
static func audit(database: PalContentDatabase) -> Dictionary:
	var report := {
		"contexts": {},
		"unsupported": [],
		"used_operations": {},
	}
	for context in range(CONTEXT_NAMES.size()):
		report.contexts[context] = {"name": CONTEXT_NAMES[context], "roots": [], "operations": {}}
	if database == null or database.scripts.is_empty():
		return report
	# “DOS 实际使用”按完整脚本表统计；根入口遍历另行记录每种上下文的可达集合。
	for script_entry in database.scripts:
		report.used_operations[script_entry.operation] = true

	var roots: Array[Dictionary] = []
	var object_ids := _discover_object_ids(database)
	for scene_index in range(database.scenes.size()):
		var scene := database.scenes[scene_index]
		_add_root(roots, Context.TRIGGER, scene.script_on_enter, "scene:%d:enter" % (scene_index + 1))
		_add_root(roots, Context.TRIGGER, scene.script_on_teleport, "scene:%d:teleport" % (scene_index + 1))
	for event in database.event_objects:
		_add_root(roots, Context.TRIGGER, event.trigger_script, "event:%d:trigger" % event.object_id)
		_add_root(roots, Context.AUTO, event.auto_script, "event:%d:auto" % event.object_id)

	for raw_item_id in object_ids.items:
		var item := database.item_definition(int(raw_item_id))
		if item == null:
			continue
		if item.is_usable():
			_add_root(roots, Context.TRIGGER, item.script_on_use, "item:%d:field-use" % item.object_id)
			if not _script_uses_field_world(database, item.script_on_use):
				_add_root(roots, Context.BATTLE_EFFECT, item.script_on_use, "item:%d:battle-use" % item.object_id)
		if item.is_throwable():
			_add_root(roots, Context.BATTLE_EFFECT, item.script_on_throw, "item:%d:throw" % item.object_id)
		if item.is_equipable():
			_add_root(roots, Context.EQUIPMENT, item.script_on_equip, "item:%d:equip" % item.object_id)

	for raw_magic_id in object_ids.magics:
		var magic_object := database.magic_object_definition(int(raw_magic_id))
		if magic_object == null:
			continue
		if magic_object.is_usable_outside_battle():
			_add_root(roots, Context.TRIGGER, magic_object.script_on_use, "magic:%d:field-use" % magic_object.object_id)
			_add_root(roots, Context.TRIGGER, magic_object.script_on_success, "magic:%d:field-success" % magic_object.object_id)
		if magic_object.is_usable_in_battle():
			_add_root(roots, Context.BATTLE_EFFECT, magic_object.script_on_use, "magic:%d:battle-use" % magic_object.object_id)
			_add_root(roots, Context.BATTLE_EFFECT, magic_object.script_on_success, "magic:%d:battle-success" % magic_object.object_id)

	for raw_poison_id in object_ids.poisons:
		var poison = database.poison_definition(int(raw_poison_id))
		if poison == null:
			continue
		_add_root(roots, Context.BATTLE_EFFECT, poison.player_script, "poison:%d:player" % poison.object_id)
		_add_root(roots, Context.BATTLE_EFFECT, poison.enemy_script, "poison:%d:enemy" % poison.object_id)

	for raw_object_id in object_ids.enemies:
		var object_id := int(raw_object_id)
		var enemy_object := database.enemy_object_definition(object_id)
		if enemy_object == null:
			continue
		_add_root(roots, Context.ENEMY_BATTLE, enemy_object.script_on_turn_start, "enemy:%d:turn" % object_id)
		_add_root(roots, Context.ENEMY_BATTLE, enemy_object.script_on_ready, "enemy:%d:ready" % object_id)
		_add_root(roots, Context.ENEMY_BATTLE, enemy_object.script_on_battle_end, "enemy:%d:end" % object_id)
		var enemy := database.enemy_definition_for_object(object_id)
		if enemy != null and enemy.magic > 0 and enemy.magic != 0xffff:
			var magic_object := database.magic_object_definition(enemy.magic)
			if magic_object != null:
				_add_root(roots, Context.BATTLE_EFFECT, magic_object.script_on_use, "enemy-magic:%d:use" % enemy.magic)
				_add_root(roots, Context.BATTLE_EFFECT, magic_object.script_on_success, "enemy-magic:%d:success" % enemy.magic)

	var instant_roots: Array[Dictionary] = []
	for root in _deduplicate_roots(roots):
		_traverse_root(database, root, report, instant_roots)
	for root in _deduplicate_roots(instant_roots):
		_traverse_root(database, root, report, [])
	return report


static func _discover_object_ids(database: PalContentDatabase) -> Dictionary:
	var result := {"items": {}, "magics": {}, "poisons": {}, "enemies": {}}
	for store in database.stores:
		if store != null:
			for item_id in store.item_ids:
				result.items[item_id] = true
	if database.player_roles != null:
		for equipments in database.player_roles.equipments_by_role:
			for item_id in equipments:
				if item_id > 0:
					result.items[item_id] = true
		for magics in database.player_roles.magics_by_role:
			for magic_id in magics:
				result.magics[magic_id] = true
		for magic_id in database.player_roles.cooperative_magics:
			if magic_id > 0:
				result.magics[magic_id] = true
	for script_entry in database.scripts:
		match script_entry.operation:
			0x0018:
				result.items[script_entry.operands[1]] = true
			0x001f, 0x0020, 0x0058, 0x0086:
				result.items[script_entry.operands[0]] = true
			0x0055, 0x0056, 0x0057, 0x0067, 0x0088:
				result.magics[script_entry.operands[0]] = true
			0x0028, 0x0029, 0x002a, 0x002b:
				result.poisons[script_entry.operands[1]] = true
			0x005d, 0x005e:
				result.poisons[script_entry.operands[0]] = true
			0x009e, 0x009f:
				if script_entry.operands[0] not in [0, 0xffff]:
					result.enemies[script_entry.operands[0]] = true
	for team in database.enemy_teams:
		if team == null:
			continue
		for object_id in team.active_object_ids():
			result.enemies[object_id] = true
	for raw_object_id in result.enemies:
		var object_id := int(raw_object_id)
		var enemy := database.enemy_definition_for_object(object_id)
		if enemy == null:
			continue
		if enemy.magic > 0 and enemy.magic != 0xffff:
			result.magics[enemy.magic] = true
		if enemy.steal_item > 0:
			result.items[enemy.steal_item] = true
		if enemy.attack_equivalent_item > 0:
			result.items[enemy.attack_equivalent_item] = true
	return result


## 物品没有“仅场外”独立标志；包含地图/事件/场景操作的使用脚本按官方用途归入主触发，
## 不会被战斗物品页当作战斗效果根入口。战斗控制器也以同一规则禁用这类剧情物品。
static func _script_uses_field_world(database: PalContentDatabase, root: int) -> bool:
	var field_operations := [
		0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0020, 0x0024, 0x0025,
		0x0038, 0x0040, 0x0049, 0x0050, 0x0051, 0x0052, 0x0059, 0x0062, 0x0063,
		0x0065, 0x006c, 0x006d, 0x006e, 0x006f, 0x0070, 0x0071, 0x0073, 0x0075,
		0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f, 0x0080, 0x0081, 0x0082,
		0x0083, 0x0084, 0x0087, 0x008b, 0x008c, 0x0094, 0x0095, 0x0097, 0x0098,
		0x0099, 0x009a, 0x009b, 0x00a0, 0x00a1, 0x00a4, 0x00a5, 0x00a6,
	]
	var pending: Array[int] = [root]
	var visited: Dictionary = {}
	while not pending.is_empty() and visited.size() < 512:
		var cursor: int = pending.pop_back()
		if cursor <= 0 or cursor >= database.scripts.size() or visited.has(cursor):
			continue
		visited[cursor] = true
		var entry := database.scripts[cursor]
		if entry.operation in field_operations:
			return true
		var ignored_instant_roots: Array[Dictionary] = []
		_append_successors(entry, cursor, Context.TRIGGER, pending, ignored_instant_roots, "classification")
	return false


static func unsupported_labels(report: Dictionary) -> PackedStringArray:
	var labels := PackedStringArray()
	for issue in report.get("unsupported", []):
		labels.append("%s:%04X@%04X(%s)" % [CONTEXT_NAMES[int(issue.context)], int(issue.operation), int(issue.entry), str(issue.root)])
	return labels


static func _add_root(roots: Array[Dictionary], context: int, entry: int, label: String) -> void:
	if entry > 0:
		roots.append({"context": context, "entry": entry, "label": label})


static func _deduplicate_roots(roots: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for root in roots:
		var key := "%d:%d" % [int(root.context), int(root.entry)]
		if seen.has(key):
			continue
		seen[key] = true
		result.append(root)
	return result


static func _traverse_root(database: PalContentDatabase, root: Dictionary, report: Dictionary, instant_roots: Array[Dictionary]) -> void:
	var context := int(root.context)
	var root_entry := int(root.entry)
	var context_report: Dictionary = report.contexts[context]
	context_report.roots.append(root_entry)
	var pending: Array[int] = [root_entry]
	var visited: Dictionary = {}
	var inspected := 0
	while not pending.is_empty() and inspected < MAX_ENTRIES_PER_ROOT:
		var cursor: int = pending.pop_back()
		if cursor <= 0 or cursor >= database.scripts.size() or visited.has(cursor):
			continue
		visited[cursor] = true
		inspected += 1
		var entry := database.scripts[cursor]
		context_report.operations[entry.operation] = true
		report.used_operations[entry.operation] = true
		if not _context_supports(context, entry.operation):
			var issue_key := "%d:%d:%d" % [context, cursor, entry.operation]
			var duplicate := false
			for issue in report.unsupported:
				if str(issue.key) == issue_key:
					duplicate = true
					break
			if not duplicate:
				report.unsupported.append({"key": issue_key, "context": context, "entry": cursor, "operation": entry.operation, "root": root.label})
		_append_successors(entry, cursor, context, pending, instant_roots, root.label)


static func _append_successors(entry: PalScriptEntry, cursor: int, context: int, pending: Array[int], instant_roots: Array[Dictionary], root_label: String) -> void:
	match entry.operation:
		0x0000, 0x004e, 0x00a0:
			return
		# 0001 会把持久入口更新到下一项。即时子脚本的 0001 只返回调用者，
		# 其他根入口都必须继续审计“下一次触发/下一回合”可达的后续段。
		0x0001:
			if context != Context.INSTANT:
				pending.append(cursor + 1)
		# 0002 把持久入口替换为 operand[0]；触发/自动脚本的空闲计数耗尽时
		# 还可能落到下一项，因此两条未来路径都要纳入。
		0x0002:
			pending.append(entry.operands[0])
			if context in [Context.TRIGGER, Context.AUTO]:
				pending.append(cursor + 1)
		0x0003:
			pending.append(entry.operands[0])
		0x0004:
			pending.append(cursor + 1)
			if context == Context.AUTO:
				_add_root(instant_roots, Context.INSTANT, entry.operands[0], "%s:instant@%04X" % [root_label, cursor])
			else:
				pending.append(entry.operands[0])
		0x0006:
			pending.append(cursor + 1)
			pending.append(entry.operands[1])
		0x001e:
			_append_branch(pending, cursor, entry.operands[1])
		0x0020, 0x002e, 0x0058, 0x0081, 0x0083, 0x0086, 0x0094, 0x009e:
			_append_branch(pending, cursor, entry.operands[2])
		0x0033, 0x0034, 0x0038, 0x003a, 0x0061, 0x0068, 0x0074, 0x0091:
			_append_branch(pending, cursor, entry.operands[0])
		0x005d, 0x005e, 0x0064, 0x0079, 0x0095, 0x009c:
			_append_branch(pending, cursor, entry.operands[1])
		0x00a2:
			for offset in range(1, maxi(1, entry.operands[0]) + 1):
				pending.append(cursor + offset)
		_:
			pending.append(cursor + 1)


static func _append_branch(pending: Array[int], cursor: int, target: int) -> void:
	pending.append(cursor + 1)
	if target > 0:
		pending.append(target)


static func _context_supports(context: int, operation: int) -> bool:
	match context:
		Context.TRIGGER:
			return ScriptVM.is_trigger_opcode_supported(operation)
		Context.AUTO:
			return ScriptVM.is_auto_opcode_supported(operation)
		Context.INSTANT:
			return ScriptVM.is_instant_opcode_supported(operation)
		Context.EQUIPMENT:
			return PalEquipmentManager.is_equipment_opcode_supported(operation)
		Context.BATTLE_EFFECT:
			return PalBattleController.is_battle_effect_opcode_supported(operation)
		Context.ENEMY_BATTLE:
			return PalBattleController.is_enemy_script_opcode_supported(operation)
		_:
			return false
