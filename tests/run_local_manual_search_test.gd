# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本地 PAL 数据验证客栈手动搜索的 half 格选择与真实触发脚本。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		print("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return

	var session := GameSession.new()
	session.reset_new_game()
	var scene_events: Array[PalEventObject] = database.events_for_scene(0)
	var target: PalEventObject
	for event in scene_events:
		if event.is_visible() and event.is_search_trigger() and event.trigger_script > 0:
			target = event
			break
	if target == null:
		_fail("客栈没有可用于回归的手动搜索事件")
		return

	# 把目标放在朝东 SearchNear 的第一个前向检查点，验证真实 EventObject 数组的选择优先级。
	session.party_direction = GameSession.DIR_EAST
	session.set_party_world_position(target.position - GameSession.movement_for_direction(GameSession.DIR_EAST))
	var explorer = load("res://src/world/map_explorer.gd").new()
	var checkpoints: Array[Vector2i] = explorer._search_trigger_positions(session.party_world_position(), session.party_direction)
	var found: PalEventObject = explorer._find_search_event(checkpoints, scene_events)
	if found == null or found.object_id != target.object_id:
		explorer.free()
		_fail("客栈搜索命中错误：期望事件 %d，实际 %s" % [target.object_id, "无" if found == null else str(found.object_id)])
		return

	var unsupported: Array[String] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.set_scene_map(database.load_map(database.scenes[0].map_number))
	vm.unsupported_instruction.connect(
		func(index: int, operation: int) -> void:
			unsupported.append("0x%04X@%d" % [operation, index])
	)
	vm.run_trigger(found.trigger_script, found.object_id)
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames) and guard < 10000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1

	if not unsupported.is_empty():
		_fail("客栈手动搜索脚本遇到未支持指令：%s" % ", ".join(unsupported))
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		_fail("客栈手动搜索脚本没有在保护帧数内结束")
	else:
		print("PASS: 客栈事件 %d 按官方 half 格搜索命中，触发脚本 0x%04X 完整结束" % [found.object_id, found.trigger_script])
		quit(0)
	explorer.free()
	vm.free()


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
