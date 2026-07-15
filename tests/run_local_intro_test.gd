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
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	var entry := database.scenes[0].script_on_enter
	vm.run_trigger(entry)
	var advance_guard := 0
	var intro_pose_frames: Dictionary = {}
	while (vm.running or vm.waiting_for_dialog) and advance_guard < 10000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		var scripted_frame := session.scripted_party_frame(0)
		if scripted_frame >= 0:
			intro_pose_frames[scripted_frame] = true
		advance_guard += 1
	if not unsupported.is_empty():
		printerr("FAIL: 首场景进入脚本遇到未支持指令：%s" % ", ".join(unsupported))
		quit(1)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		printerr("FAIL: 首场景进入脚本没有结束")
		quit(1)
	elif database.event_objects.size() < 11 or database.event_objects[10].state != 0 or database.event_objects[10].position != Vector2i(1152, 384):
		printerr("FAIL: 李大娘自动离场脚本没有完成")
		quit(1)
	elif not intro_pose_frames.has(2) or not intro_pose_frames.has(3):
		printerr("FAIL: 李逍遥的大侠姿势帧没有执行")
		quit(1)
	else:
		print("PASS: 首场景进入脚本完成，逐句消息 %d 条，李逍遥动作及李大娘离场均已执行" % messages.size())
		quit(0)
	vm.free()
