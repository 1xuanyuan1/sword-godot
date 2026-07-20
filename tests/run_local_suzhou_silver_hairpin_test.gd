# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式 MapExplorer + TileMap 世界回归苏州城内小贩的银钗隐藏剧情。
## 原版没有独立“好感度”字段；脚本通过对白、扣款和银钗物品表达这段互动。
extends SceneTree

var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	await process_frame
	if explorer._script_vm == null or explorer._database == null:
		_fail("MapExplorer 没有初始化正式 ScriptVM/内容数据库")
		return
	explorer._script_vm.stop()

	var database: PalContentDatabase = explorer._database
	var messages: Array[int] = []
	var shops: Array = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	explorer._script_vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	explorer._script_vm.shop_requested.connect(func(store_id: int, buying: bool) -> void: shops.append([store_id, buying]))
	explorer._script_vm.unsupported_instruction.connect(
		func(index: int, operation: int) -> void:
			unsupported.append("0x%04X@%d" % [operation, index])
	)
	explorer._script_vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))

	explorer._load_scene(22, false)
	explorer._session.party_roles = PackedInt32Array([0, 1])
	explorer._session.cash = 500
	var vendor: PalEventObject = database.event_objects[433]
	if vendor.trigger_script != 10752 or vendor.trigger_mode != 2:
		_fail("苏州杂货小贩没有指向银钗脚本 10752：脚本=%d 模式=%d" % [vendor.trigger_script, vendor.trigger_mode])
		return
	# 把队伍放在小贩前一个 half 格，以正式搜索入口触发，而不是直接调用 VM。
	explorer._session.party_direction = GameSession.DIR_EAST
	explorer._session.set_party_world_position(vendor.position - GameSession.movement_for_direction(GameSession.DIR_EAST))
	explorer._refresh_world()
	explorer._inspect_nearby_event()

	if not await _drive_until(explorer, func() -> bool: return not explorer._script_vm.is_busy()):
		_fail("银钗隐藏剧情没有在保护帧数内结束")
		return
	if not unsupported.is_empty():
		_fail("银钗隐藏剧情遇到未支持指令：%s" % ", ".join(unsupported))
	elif shops != []:
		_fail("赵灵儿已在队伍且现金足够时不应退回普通商店：%s" % [shops])
	elif messages != range_to_array(2854, 2869):
		_fail("银钗隐藏剧情对白范围不完整：%s" % [messages])
	elif explorer._session.cash != 100 or explorer._session.item_count(199) != 1:
		_fail("银钗隐藏剧情没有扣 400 文并获得物品 199：现金=%d 银钗=%d" % [explorer._session.cash, explorer._session.item_count(199)])
	elif next_entries != [10753] or vendor.trigger_script != 10753:
		_fail("银钗隐藏剧情没有安装后续稳定入口：%s / %d" % [next_entries, vendor.trigger_script])
	else:
		print("PASS: TileMap 正式路径完成苏州银钗隐藏剧情，扣款、对白、银钗奖励和稳定入口均正确")

	explorer._script_vm.stop()
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
		explorer._audio_player._music_player.stream = null
		for player in explorer._audio_player._sound_players:
			player.stream = null
	explorer.free()
	await process_frame
	quit(0 if _failure.is_empty() else 1)


func _drive_until(explorer, predicate: Callable) -> bool:
	for _guard in range(2000):
		if predicate.call():
			return true
		if explorer._script_vm.waiting_for_dialog:
			explorer._script_vm.advance_dialog()
		elif explorer._script_vm.waiting_for_shop:
			explorer._script_vm.complete_shop()
		elif explorer._script_vm.waiting_for_frames:
			explorer._script_vm.tick_frame()
		else:
			await process_frame
	return predicate.call()


func range_to_array(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result


func _fail(message: String) -> void:
	_failure = message
	printerr("FAIL: %s" % message)
	quit(1)
