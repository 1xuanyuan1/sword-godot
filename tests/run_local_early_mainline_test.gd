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
	if failure.is_empty():
		failure = _test_boat_steps_and_item_narration(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 买虾、求药归来、张四登船、李逍遥乘船至仙灵岛与道具叙述 Toast 主线完成")
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


func _test_boat_steps_and_item_narration(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = -1
	var narration_vm := ScriptVM.new()
	narration_vm.configure(database, session)
	var narration_positions: Array[int] = []
	var narration_messages: Array[int] = []
	var unsupported: Array[String] = []
	narration_vm.dialog_started.connect(func(position: int, _color: int, _portrait: int) -> void: narration_positions.append(position))
	narration_vm.dialog_message.connect(func(index: int) -> void: narration_messages.append(index))
	narration_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	narration_vm.run_trigger(0x15c7)
	_drive_script(narration_vm)
	if narration_positions != [3] or narration_messages != [998, 999]:
		narration_vm.free()
		return "破天锤/忘忧散行为叙述没有合并为 Toast：位置 %s，消息 %s" % [narration_positions, narration_messages]
	narration_vm.free()
	var boat := database.event_objects[116]
	var destination_boat := database.event_objects[117]
	var original_position := boat.position
	var original_state := boat.state
	var destination_original_position := destination_boat.position
	var destination_original_state := destination_boat.state
	var boat_vm := ScriptVM.new()
	boat_vm.configure(database, session)
	boat_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	boat_vm.run_trigger(0x170c, 117)
	_drive_script(boat_vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "乘船流程遇到未支持指令：%s" % unsupported
	elif boat.position != original_position + Vector2i(0, 16) or boat.state != 0 or destination_boat.state != 2:
		failure = "乘船事件没有完成八步移动及船只切换：位置 %s→%s，状态 %d/%d" % [original_position, boat.position, boat.state, destination_boat.state]
	boat_vm.free()
	if not failure.is_empty():
		return failure
	# 恢复船只的原始状态，从登船接触脚本验证李逍遥、船只同步移动并切到仙灵岛。
	boat.position = original_position
	boat.state = original_state
	destination_boat.position = destination_original_position
	destination_boat.state = destination_original_state
	session.set_party_world_position(Vector2i(1184, 1424))
	var scene_changes: Array[int] = []
	var fade_requests: Array = []
	var boarding_vm := ScriptVM.new()
	boarding_vm.configure(database, session)
	boarding_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	boarding_vm.scene_change_requested.connect(func(scene_index: int) -> void: scene_changes.append(scene_index))
	boarding_vm.screen_fade_requested.connect(func(fade_out: bool, duration: float) -> void: fade_requests.append([fade_out, duration]))
	boarding_vm.run_trigger(0x1725, 117)
	_drive_script(boarding_vm)
	if not unsupported.is_empty():
		failure = "登船到仙灵岛流程遇到未支持指令：%s" % unsupported
	elif fade_requests != [[true, 0.6]]:
		failure = "余杭驶离后没有按原版渐隐：%s" % [fade_requests]
	elif scene_changes != [14] or session.scene_index != 14 or session.party_world_position() != Vector2i(752, 808):
		failure = "登船后没有切到仙灵岛：场景 %s/%d，落点 %s" % [scene_changes, session.scene_index, session.party_world_position()]
	elif boat.position != original_position + Vector2i(288, -144):
		failure = "李逍遥乘坐的船没有同步驶离码头：%s→%s" % [original_position, boat.position]
	boarding_vm.free()
	if not failure.is_empty():
		return failure
	var island_messages: Array[int] = []
	var island_next_entries: Array[int] = []
	var island_vm := ScriptVM.new()
	island_vm.configure(database, session)
	island_vm.dialog_message.connect(func(index: int) -> void: island_messages.append(index))
	island_vm.script_finished.connect(func(next_entry: int) -> void: island_next_entries.append(next_entry))
	island_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	island_vm.run_trigger(database.scenes[14].script_on_enter)
	_drive_script(island_vm)
	if not unsupported.is_empty():
		failure = "仙灵岛进入脚本遇到未支持指令：%s" % unsupported
	elif island_messages != _message_range(0x09a1, 0x09a6) or island_next_entries != [0x2544]:
		failure = "仙灵岛进入对话或稳定入口不完整：消息 %s，入口 %s" % [island_messages, island_next_entries]
	elif session.music_number != 70 or session.battle_music_number != 37 or session.party_world_position() != Vector2i(752, 808):
		failure = "仙灵岛进入状态不正确：BGM %d，战斗 BGM %d，落点 %s" % [session.music_number, session.battle_music_number, session.party_world_position()]
	island_vm.free()
	return failure


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk or vm.waiting_for_party_ride or vm.waiting_for_screen_fade) and guard < 30000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		elif vm.waiting_for_screen_fade:
			vm.complete_screen_fade()
		else:
			vm.tick_frame()
		guard += 1


func _message_range(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result
