# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_inn_exit(database)
	if failure.is_empty():
		failure = _test_stairs(database)
	if failure.is_empty():
		failure = _test_kitchen_entry(database)
	if failure.is_empty():
		failure = _test_scene_teleport(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 客栈出口、楼梯动画、厨房入口及场景传送离开脚本完成，落点正确且没有重播开场")
	quit(0)


func _test_inn_exit(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.run_trigger(4667, 1)
	var failure := ""
	if not unsupported.is_empty():
		failure = "客栈出口脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		failure = "客栈出口脚本没有结束"
	elif requested_scenes != [2] or session.scene_index != 2:
		failure = "客栈出口没有请求进入场景 3：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(1440, 1536):
		failure = "客栈出口落点错误：%s" % session.party_world_position()
	vm.free()
	return failure


func _test_stairs(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var stairs_event: PalEventObject = database.event_objects[2]
	session.set_party_world_position(stairs_event.position)
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._database = database
	explorer._session = session
	explorer._scene_events = database.events_for_scene(0)
	explorer._script_vm = vm
	var next_entries: Array[int] = []
	var steps: Array[int] = []
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.script_finished.connect(explorer._on_script_finished)
	vm.party_step_performed.connect(func() -> void: steps.append(1))
	var touch_triggered: bool = explorer._trigger_touch_event()
	var guard := 0
	while vm.running and guard < 100:
		vm.tick_frame()
		guard += 1
	explorer._continue_touch_scan()
	var failure := ""
	if not touch_triggered:
		failure = "客栈楼梯没有由真实接触范围自动触发"
	elif session.party_world_position() != stairs_event.position + Vector2i(-64, -64):
		failure = "客栈楼梯自动移动脚本落点错误：%s" % session.party_world_position()
	elif next_entries != [42]:
		failure = "客栈楼梯触发入口没有保持可重复"
	elif steps.size() != 8:
		failure = "客栈楼梯没有执行完整的 8 步行走动画：%d" % steps.size()
	explorer.free()
	vm.free()
	return failure


func _test_kitchen_entry(database: PalContentDatabase) -> String:
	# 模拟首段剧情已经完成后的场景状态；8145 是 7952 执行后返回的稳定入口。
	database.scenes[0].script_on_enter = 8145
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 2
	var portal_vm := ScriptVM.new()
	portal_vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	portal_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	portal_vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	portal_vm.run_trigger(4631, 52)
	var failure := ""
	if not unsupported.is_empty():
		failure = "厨房入口脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif requested_scenes != [0] or session.scene_index != 0:
		failure = "厨房入口没有请求进入场景 1：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(1248, 1104):
		failure = "厨房入口落点错误：%s" % session.party_world_position()
	portal_vm.free()
	if not failure.is_empty():
		return failure

	var enter_vm := ScriptVM.new()
	enter_vm.configure(database, session)
	var messages: Array[int] = []
	var next_entries: Array[int] = []
	enter_vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	enter_vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	enter_vm.run_trigger(database.scenes[0].script_on_enter)
	if not messages.is_empty():
		failure = "进入厨房后错误地重播了 %d 条开场消息" % messages.size()
	elif next_entries != [8145]:
		failure = "厨房所属场景没有保持稳定进入入口：%s" % next_entries
	enter_vm.free()
	return failure


func _test_scene_teleport(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 5 # 场景 6 的离开脚本入口为 6051。
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	var sounds: Array[int] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(39677)
	var failure := ""
	if not unsupported.is_empty():
		failure = "场景传送脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif requested_scenes != [3] or session.scene_index != 3:
		failure = "场景 6 传送脚本没有请求进入场景 4：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(224, 1376):
		failure = "场景传送落点错误：%s" % session.party_world_position()
	elif sounds != [45] or not session.party_formation_collapsed:
		failure = "传送后的音效或队伍收拢状态错误：sound=%s collapsed=%s" % [sounds, session.party_formation_collapsed]
	vm.free()
	return failure
