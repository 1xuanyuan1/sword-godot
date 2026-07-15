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
	# 对话结束后继续驱动 NPC 自动脚本，验证黑苗人都进入客房而非卡在门口。
	for frame in range(200):
		vm.tick_frame()
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._build_interface()
	explorer._dialog_box._ready()
	explorer._database = database
	explorer._session = session
	explorer._dialog_box.begin(0, 0, explorer._load_portrait_texture(55))
	explorer._dialog_box.hide_dialog()
	explorer._on_dialog_message(606)
	explorer._on_dialog_message(607)
	var portrait_context_ok: bool = explorer._dialog_box.has_portrait() and explorer._dialog_box._portrait_column.visible and explorer._dialog_box._speaker.text == "李大娘"
	explorer.free()
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
	elif not portrait_context_ok:
		printerr("FAIL: 对话隐藏后重新出现的李大娘台词没有恢复立绘")
		quit(1)
	elif database.event_objects[59].state != 0 or database.event_objects[60].state != 0 or database.event_objects[61].state != 0:
		printerr("FAIL: 黑苗 NPC 自动路线没有完成：%s" % [database.event_objects[59].state, database.event_objects[60].state, database.event_objects[61].state])
		quit(1)
	else:
		print("PASS: 客栈消息 604–633、李大娘隐式对话立绘、500 文钱及黑苗 NPC 入房均完成")
		quit(0)
	vm.free()
