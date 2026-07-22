# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从当前 EventObject 入口脚本识别场景中的实体一次性采集物。
## 分类只读取原版运行时状态；发光标识的额外消费记录由 GameSession 保存。
class_name PalCollectibleClassifier
extends RefCounted

const MAX_ENTRIES_PER_ROOT := 4096
const SIMPLE_PICKUP_OPERATIONS := {
	0x0000: true, 0x0001: true, 0x0002: true, 0x0003: true, 0x0004: true,
	0x0005: true, 0x0006: true, 0x0008: true, 0x0009: true, 0x0014: true,
	0x001e: true, 0x001f: true, 0x003b: true, 0x003e: true, 0x0047: true,
	0x0049: true, 0x004b: true, 0x0052: true, 0xffff: true,
}

var _database: PalContentDatabase
var _root_cache: Dictionary = {}


## 绑定当前内容数据库并清空按脚本根入口缓存的分类结果。
func configure(database: PalContentDatabase) -> void:
	if _database == database:
		return
	_database = database
	_root_cache.clear()


## 当前事件是否应显示采集标识。NPC、商贩、纯剧情物件及已经提示过的事件返回 false。
func is_available(event: PalEventObject, session: GameSession = null) -> bool:
	if event == null or _database == null or not event.is_visible() or not event.is_search_trigger():
		return false
	if event.trigger_script <= 0 or event.sprite_frames != 0:
		return false
	if session != null and session.is_collectible_marker_consumed(event.object_id):
		return false
	var analysis := _analysis_for_root(event.trigger_script)
	if not bool(analysis.get("valid", false)) or not bool(analysis.get("grants_reward", false)) or bool(analysis.get("has_cost", false)):
		return false
	# SearchNear 是原版静态物件、暗格、草药与尸骨的主要触发模式；其中少数
	# 会衔接额外剧情，但奖励载体仍是玩家面对的实体采集点。
	if event.trigger_mode == PalEventObject.TRIGGER_SEARCH_NEAR:
		return true
	# 更远的搜索范围也用于 NPC。只接受短拾取脚本，并要求它会打开或消费当前物件，
	# 且不能顺便修改别的 EventObject，从结构上排除商贩和主线奖励对话。
	return bool(analysis.get("simple_pickup", false)) \
		and bool(analysis.get("consumes_self", false)) \
		and not bool(analysis.get("mutates_other_event", false))


func _analysis_for_root(root: int) -> Dictionary:
	if _root_cache.has(root):
		return _root_cache[root]
	var result := {
		"valid": true,
		"grants_reward": false,
		"has_cost": false,
		"simple_pickup": true,
		"consumes_self": false,
		"mutates_other_event": false,
	}
	var pending: Array[int] = [root]
	var visited: Dictionary = {}
	while not pending.is_empty() and visited.size() < MAX_ENTRIES_PER_ROOT:
		var cursor: int = pending.pop_back()
		if cursor <= 0 or cursor >= _database.scripts.size() or visited.has(cursor):
			continue
		visited[cursor] = true
		var entry: PalScriptEntry = _database.scripts[cursor]
		if entry == null or entry.operands.size() < 3:
			result.valid = false
			continue
		if not SIMPLE_PICKUP_OPERATIONS.has(entry.operation):
			result.simple_pickup = false
		match entry.operation:
			0x001e:
				var cash_delta := _signed_word(entry.operands[0])
				result.grants_reward = bool(result.grants_reward) or cash_delta > 0
				result.has_cost = bool(result.has_cost) or cash_delta < 0
			0x001f:
				var item_delta := _signed_word(entry.operands[1])
				result.grants_reward = bool(result.grants_reward) or item_delta >= 0
				result.has_cost = bool(result.has_cost) or item_delta < 0
			0x0014, 0x004b, 0x0052:
				result.consumes_self = true
			0x0049:
				var target := int(entry.operands[0])
				if target not in [0, 0xffff]:
					result.mutates_other_event = true
				elif _signed_word(entry.operands[1]) == 0:
					result.consumes_self = true
		_append_successors(entry, cursor, pending)
	if not pending.is_empty():
		result.valid = false
	_root_cache[root] = result
	return result


func _append_successors(entry: PalScriptEntry, cursor: int, pending: Array[int]) -> void:
	match entry.operation:
		0x0000, 0x0001, 0x0002, 0x004e, 0x00a0:
			return
		0x0003:
			pending.append(entry.operands[0])
		0x0004:
			pending.append(cursor + 1)
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


func _append_branch(pending: Array[int], cursor: int, target: int) -> void:
	pending.append(cursor + 1)
	if target > 0:
		pending.append(target)


static func _signed_word(value: int) -> int:
	return value - 0x10000 if value >= 0x8000 else value
