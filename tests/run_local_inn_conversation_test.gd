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
	session.scene_index = 2
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.run_trigger(4701, 57)
	var guard := 0
	while (vm.running or vm.waiting_for_dialog) and guard < 10000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1
	var expected_messages: Array[int] = []
	for index in range(604, 634):
		expected_messages.append(index)
	if not unsupported.is_empty():
		printerr("FAIL: 客栈黑苗人事件遇到未支持指令：%s" % ", ".join(unsupported))
		quit(1)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		printerr("FAIL: 客栈黑苗人事件没有结束")
		quit(1)
	elif messages != expected_messages:
		printerr("FAIL: 客栈黑苗人对话不完整：%s" % messages)
		quit(1)
	elif session.cash != 500:
		printerr("FAIL: 客栈黑苗人事件没有获得 500 文钱")
		quit(1)
	elif database.portrait_for_speaker("李大娘") != 55:
		printerr("FAIL: 李大娘的默认肖像没有解析为 55")
		quit(1)
	else:
		print("PASS: 客栈黑苗人事件完成，消息 604–633，获得 500 文钱")
		quit(0)
	vm.free()
