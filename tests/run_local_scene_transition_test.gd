# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var session := GameSession.new()
	session.reset_new_game()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.run_trigger(4667, 1)
	if not unsupported.is_empty():
		printerr("FAIL: 客栈出口脚本遇到未支持指令：%s" % ", ".join(unsupported))
		quit(1)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		printerr("FAIL: 客栈出口脚本没有结束")
		quit(1)
	elif requested_scenes != [2] or session.scene_index != 2:
		printerr("FAIL: 客栈出口没有请求进入场景 3：%s" % requested_scenes)
		quit(1)
	elif session.party_world_position() != Vector2i(1440, 1536):
		printerr("FAIL: 客栈出口落点错误：%s" % session.party_world_position())
		quit(1)
	else:
		var stair_session := GameSession.new()
		stair_session.reset_new_game()
		var stair_vm := ScriptVM.new()
		stair_vm.configure(database, stair_session)
		var stair_next_entries: Array[int] = []
		var stair_steps: Array[int] = []
		stair_vm.script_finished.connect(func(next_entry: int) -> void: stair_next_entries.append(next_entry))
		stair_vm.party_step_performed.connect(func() -> void: stair_steps.append(1))
		stair_vm.run_trigger(42, 3)
		var guard := 0
		while stair_vm.running and guard < 100:
			stair_vm.tick_frame()
			guard += 1
		if stair_session.party_world_position() != Vector2i(96, 48):
			printerr("FAIL: 客栈楼梯自动移动脚本落点错误：%s" % stair_session.party_world_position())
			quit(1)
		elif stair_next_entries != [42]:
			printerr("FAIL: 客栈楼梯触发入口没有保持可重复")
			quit(1)
		elif stair_steps.size() != 8:
			printerr("FAIL: 客栈楼梯没有执行完整的 8 步行走动画：%d" % stair_steps.size())
			quit(1)
		else:
			print("PASS: 客栈出口及楼梯自动触发脚本完成，落点正确")
			quit(0)
		stair_vm.free()
	vm.free()
