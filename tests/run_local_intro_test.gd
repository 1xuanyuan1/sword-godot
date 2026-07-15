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
	while vm.waiting_for_dialog and advance_guard < 1000:
		vm.advance_dialog()
		advance_guard += 1
	if not unsupported.is_empty():
		printerr("FAIL: 首场景进入脚本遇到未支持指令：%s" % ", ".join(unsupported))
		quit(1)
	elif vm.running or vm.waiting_for_dialog:
		printerr("FAIL: 首场景进入脚本没有结束")
		quit(1)
	else:
		print("PASS: 首场景进入脚本完成，逐句消息 %d 条" % messages.size())
		quit(0)
	vm.free()
