# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成资源验证桂花酒之后的买虾、病倒求药、黑苗人离店和御剑教学主线。
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
		failure = _test_black_miao_night_departure(database)
	if failure.is_empty():
		failure = _test_temple_sword_training(database)
	if failure.is_empty():
		failure = _test_boat_steps_and_item_narration(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 买虾、求药归来、黑苗人离店、御剑教学、天亮返店、赵灵儿营救战、张四登船、仙灵岛抵达与道具叙述 Toast 主线完成")
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


func _test_black_miao_night_departure(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 2
	session.music_number = 36
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	if database.event_objects[59].trigger_script != 6254 or database.event_objects[59].trigger_mode != 7:
		vm.free()
		return "求药归来后没有把黑苗人安装到夜间离店触发入口"
	vm.run_trigger(6254, 60)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "黑苗人夜间离店遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1236, 1264):
		failure = "黑苗人夜间离店消息不完整：%s" % [messages]
	elif next_entries != [6254]:
		failure = "黑苗人离店触发入口没有按 0000 保持：%s" % [next_entries]
	elif database.event_objects[59].state != 0:
		failure = "黑苗人没有在夜间剧情后离开客栈：状态 %d" % database.event_objects[59].state
	elif database.event_objects[59].auto_script != 6309 or database.event_objects[60].auto_script != 6313 or database.event_objects[61].auto_script != 6317:
		failure = "黑苗人离店的三个自动脚本没有运行到稳定结束入口：%d/%d/%d" % [database.event_objects[59].auto_script, database.event_objects[60].auto_script, database.event_objects[61].auto_script]
	vm.free()
	return failure


func _test_temple_sword_training(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	# EventObject 196 属于 0-based 场景 10（山神庙），不要借用余杭室内场景索引。
	session.scene_index = 10
	session.music_number = 36
	session.night_palette = true
	var vm := ScriptVM.new()
	vm.configure(database, session)
	# 故意把李逍遥置于低 HP/MP，确认教学结尾的 001D 真正恢复了运行时状态。
	session.role_hp[0] = 1
	session.role_mp[0] = 0
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	var music_requests: Array = []
	var fade_requests: Array = []
	var rng_requests: Array = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.screen_fade_requested.connect(func(fade_out: bool, duration: float) -> void: fade_requests.append([fade_out, duration]))
	vm.rng_animation_requested.connect(func(number: int, first_frame: int, last_frame: int, fps: int) -> void: rng_requests.append([number, first_frame, last_frame, fps]))
	var teacher := database.event_objects[195]
	if teacher.trigger_script != 6622 or teacher.trigger_mode != 6:
		vm.free()
		return "山神庙醉道士没有指向御剑教学入口 6622：脚本 %d，模式 %d" % [teacher.trigger_script, teacher.trigger_mode]
	vm.run_trigger(6622, 196)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "山神庙御剑教学遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1360, 1400):
		failure = "山神庙御剑教学消息不完整：%s" % [messages]
	elif rng_requests != [[1, 0, -1, 14]]:
		failure = "御剑教学没有播放完整的 RNG #1：%s" % [rng_requests]
	elif fade_requests.size() != 2 or fade_requests[0][0] != true or fade_requests[1][0] != true:
		failure = "御剑教学过场渐隐时序不正确：%s" % [fade_requests]
	elif [0, true, 0.0] not in music_requests or [86, true, 0.0] not in music_requests or session.music_number != 86:
		failure = "御剑教学停止场景音乐或切换过场音乐不正确：%s" % [music_requests]
	elif not session.has_magic(0, 345):
		failure = "李逍遥没有在御剑教学后习得对象 345"
	elif session.role_hp[0] != session.role_max_hp[0] or session.role_mp[0] != session.role_max_mp[0]:
		failure = "御剑教学没有恢复李逍遥 HP/MP：%d/%d，%d/%d" % [session.role_hp[0], session.role_max_hp[0], session.role_mp[0], session.role_max_mp[0]]
	elif session.night_palette:
		failure = "御剑教学结束后没有切回日间调色板"
	elif session.party_world_position() != Vector2i(672, 400) or database.player_roles.scene_sprite_for(0) != 2:
		failure = "御剑教学结束后的队伍位置或李逍遥造型不正确：%s，Sprite %d" % [session.party_world_position(), database.player_roles.scene_sprite_for(0)]
	elif teacher.state != 0 or teacher.trigger_mode != 2:
		failure = "醉道士没有在教学后隐藏并降为近距离触发：状态 %d，模式 %d" % [teacher.state, teacher.trigger_mode]
	elif database.scenes[6].script_on_enter != 6767:
		failure = "御剑教学没有安装下一阶段场景 7 进入脚本：%d" % database.scenes[6].script_on_enter
	else:
		var expected_event_states := {
			172: 2, 173: 2, 49: 0, 102: 0, 103: 0, 104: 0, 105: 0,
			78: 2, 79: 2, 80: 2, 81: 2, 82: 2, 88: 2, 89: 1,
			86: 2, 87: 2, 90: 2, 91: 2, 92: 2, 93: 1, 94: 1,
			77: 2, 57: 2, 61: 2, 62: 2, 28: 2,
		}
		for event_id: int in expected_event_states:
			var actual_state: int = database.event_objects[event_id - 1].state
			if actual_state != expected_event_states[event_id]:
				failure = "御剑教学后 EventObject %d 状态错误：%d，应为 %d" % [event_id, actual_state, expected_event_states[event_id]]
				break
	if failure.is_empty() and next_entries != [6622]:
		failure = "御剑教学触发入口没有按 0000 保持：%s" % [next_entries]
	vm.free()
	if failure.is_empty():
		failure = _test_post_training_dawn_and_rescue(database, session)
	return failure


func _test_post_training_dawn_and_rescue(database: PalContentDatabase, session: GameSession) -> String:
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	var music_requests: Array = []
	var fade_requests: Array = []
	var battle_requests: Array = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.screen_fade_requested.connect(func(fade_out: bool, duration: float) -> void: fade_requests.append([fade_out, duration]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: battle_requests.append([team, field, boss]))

	# 教学结束后进入十里坡出口：天亮独白、BGM 70，并为余杭室外安装日间 BGM 入口。
	session.scene_index = 6
	vm.run_trigger(database.scenes[6].script_on_enter)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "御剑教学后天亮入口遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1401, 1402) or next_entries != [6775]:
		failure = "御剑教学后天亮独白或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif music_requests != [[0, false, 3.0], [70, true, 0.0]] or session.music_number != 70:
		failure = "御剑教学后天亮音乐时序不正确：%s" % [music_requests]
	elif database.scenes[3].script_on_enter != 3149:
		failure = "天亮剧情没有安装余杭室外日间音乐入口：%d" % database.scenes[3].script_on_enter
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	music_requests.clear()
	session.scene_index = 3
	vm.run_trigger(database.scenes[3].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "余杭日间进入脚本遇到未支持指令：%s" % [unsupported]
	elif not messages.is_empty() or next_entries != [3151] or music_requests != [[49, true, 0.0]] or session.music_number != 49:
		failure = "余杭日间进入脚本状态不正确：消息 %s，入口 %s，音乐 %s" % [messages, next_entries, music_requests]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	music_requests.clear()
	session.scene_index = 2
	vm.run_trigger(6776, 57)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "天亮返回客栈与李大娘对话遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1403, 1438) or next_entries != [6831]:
		failure = "天亮返回客栈对话或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif database.event_objects[56].auto_script != 0 or database.event_objects[3].trigger_script != 6838:
		failure = "李大娘早餐剧情没有清理自动脚本或安装密道提示：%d/%d" % [database.event_objects[56].auto_script, database.event_objects[3].trigger_script]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	music_requests.clear()
	fade_requests.clear()
	battle_requests.clear()
	var captive := database.event_objects[27]
	if captive.state != 2 or captive.trigger_script != 6906:
		vm.free()
		return "御剑教学后客房没有出现赵灵儿营救事件：状态 %d，脚本 %d" % [captive.state, captive.trigger_script]
	session.scene_index = 0
	vm.run_trigger(6906, 28)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "赵灵儿营救战前剧情遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[18, 21, true]]:
		failure = "赵灵儿营救没有请求敌队 18／战场 21 的 Boss 战：%s" % [battle_requests]
	elif messages != _message_range(1475, 1497) or session.party_roles != PackedInt32Array([0, 1]):
		failure = "赵灵儿营救战前对话或临时入队状态不正确：消息 %s，队伍 %s" % [messages, session.party_roles]
	if not failure.is_empty():
		vm.free()
		return failure

	# 模拟赵灵儿在战斗中倒下，确认战后 0022 会复活并清除临时状态。
	session.set_role_status(1, GameSession.STATUS_BRAVERY, 5)
	session.role_hp[1] = 0
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "赵灵儿营救战后剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1475, 1512) or next_entries != [6906]:
		failure = "赵灵儿营救战后对话或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0, 1]) or session.role_hp[1] != session.role_max_hp[1] or session.role_mp[1] != session.role_max_mp[1]:
		failure = "营救战后赵灵儿没有正式入队并恢复：队伍 %s，HP/MP %d/%d" % [session.party_roles, session.role_hp[1], session.role_mp[1]]
	elif session.status_rounds_for(1, GameSession.STATUS_BRAVERY) != 0:
		failure = "营救战后 0022 没有清除赵灵儿临时状态"
	elif captive.state != 0 or database.event_objects[28].state != 0 or database.event_objects[29].state != 1:
		failure = "营救战后客房人物状态不正确：%d/%d/%d" % [captive.state, database.event_objects[28].state, database.event_objects[29].state]
	elif database.event_objects[56].trigger_script != 7031 or database.event_objects[56].trigger_mode != 6:
		failure = "营救战后没有安装李大娘后续入口：脚本 %d，模式 %d" % [database.event_objects[56].trigger_script, database.event_objects[56].trigger_mode]
	elif music_requests != [[34, true, 0.0], [24, true, 3.0]] or fade_requests != [[true, 0.6]] or session.music_number != 24:
		failure = "营救战前后音乐或渐隐时序不正确：音乐 %s，渐隐 %s" % [music_requests, fade_requests]
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
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk or vm.waiting_for_party_ride or vm.waiting_for_screen_fade or vm.waiting_for_rng) and guard < 30000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		elif vm.waiting_for_screen_fade:
			vm.complete_screen_fade()
		elif vm.waiting_for_rng:
			vm.complete_rng_animation()
		else:
			vm.tick_frame()
		guard += 1


func _message_range(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result
