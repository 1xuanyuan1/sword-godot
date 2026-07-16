# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成资源验证桂花酒之后的买虾、病倒求药和夜赴山神庙主线。
## 测试只比较消息编号和运行时状态，不输出或提交原版对话内容。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_shrimp_errand(database)
	if failure.is_empty():
		failure = _test_fish_vendor(database)
	if failure.is_empty():
		failure = _test_medicine_return_and_temple_reminder(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 买虾 790–803、鱼嫂 1182–1188、求药归来 1190–1213 与山神庙提醒 1214–1220 主线完成")
	quit(0)


func _test_shrimp_errand(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = -1
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.run_trigger(5157, 20)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "买虾任务遇到未支持指令：%s" % ", ".join(unsupported)
	elif messages != _message_range(790, 803):
		failure = "买虾任务消息不完整：%s" % messages
	elif session.cash != 50:
		failure = "李大娘给的 50 文没有进入会话：%d" % session.cash
	elif next_entries != [4981]:
		failure = "买虾任务没有返回正确的未来入口：%s" % next_entries
	vm.free()
	return failure


func _test_fish_vendor(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = -1
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.run_trigger(6022)
	_drive_script(vm)
	vm.run_trigger(6028)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "鱼嫂对话遇到未支持指令：%s" % ", ".join(unsupported)
	elif messages != _message_range(1182, 1188):
		failure = "鱼嫂两轮对话不完整：%s" % messages
	elif next_entries != [6028, 6028]:
		failure = "鱼嫂首次与稳定重复入口不正确：%s" % next_entries
	vm.free()
	return failure


func _test_medicine_return_and_temple_reminder(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = -1
	session.music_number = 31
	session.set_item_count(273, 1)
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var music_requests: Array = []
	var requested_scenes: Array[int] = []
	var next_entries: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.scene_change_requested.connect(func(scene_index: int) -> void: requested_scenes.append(scene_index))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.run_trigger(6072)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "求药归来剧情遇到未支持指令：%s" % ", ".join(unsupported)
	elif messages != _message_range(1190, 1213):
		failure = "求药归来剧情消息不完整：%s" % messages
	elif database.event_objects[101].state != 2 or database.event_objects[102].state != 2 or database.event_objects[103].state != 2 or database.event_objects[104].state != 2:
		failure = "病倒剧情没有批量启用 EventObject 102–105"
	elif database.event_objects[77].state != 0 or database.event_objects[93].state != 0:
		failure = "病倒剧情没有批量隐藏 EventObject 78–94"
	elif session.item_count(273) != 0:
		failure = "求得的物品 273 没有在剧情中消耗"
	elif [0, false, 2.0] not in music_requests or [36, true, 0.0] not in music_requests or session.music_number != 36:
		failure = "BGM 停止或夜间曲目切换不正确：%s" % music_requests
	elif not session.night_palette:
		failure = "剧情完成后没有切换夜间调色板"
	elif database.scenes[0].script_on_enter != 6198 or requested_scenes != [0] or session.scene_index != 0:
		failure = "场景 1 没有安装山神庙提醒入口并切回：entry=%d scenes=%s" % [database.scenes[0].script_on_enter, requested_scenes]
	elif next_entries != [6072]:
		failure = "求药归来脚本结束入口异常：%s" % next_entries
	if not failure.is_empty():
		vm.free()
		return failure
	messages.clear()
	next_entries.clear()
	vm.run_trigger(database.scenes[0].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "山神庙提醒遇到未支持指令：%s" % ", ".join(unsupported)
	elif messages != _message_range(1214, 1220):
		failure = "山神庙提醒消息不完整：%s" % messages
	elif next_entries != [6225]:
		failure = "山神庙提醒没有返回下一稳定入口：%s" % next_entries
	vm.free()
	return failure


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk) and guard < 30000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1


func _message_range(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result
