# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成资源验证仙灵岛石像机关，以及桂花酒后的求药、御剑教学和营救主线。
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
		failure = _test_first_island_statue_puzzle()
	if failure.is_empty():
		failure = _test_island_bath_dialog_presentation(database)
	if failure.is_empty():
		failure = _test_palace_marriage_night(database)
	if failure.is_empty():
		failure = _test_first_island_return_dialog_boundary(database)
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
	print("PASS: 买虾、仙灵岛洗澡、水月宫过夜与首次返航、御剑教学、水月宫惨案、林月如城外、苏州客栈与比武招亲后进入林家堡主线完成")
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


func _test_island_bath_dialog_presentation(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._build_interface()
	explorer._dialog_box._ready()
	explorer._database = database
	explorer._session = session
	var expected_speaker := database.get_word(database.player_roles.name_word_for(0))
	# 原脚本在这些短句前使用零肖像 003C/003D，也没有再次输出“李逍遥：”。
	explorer._on_dialog_started(1, 0, 0)
	explorer._on_dialog_message(2518)
	var portrait_ok: bool = (
		explorer._dialog_box.has_portrait()
		and explorer._dialog_box._portrait_column.visible
		and explorer._dialog_box._speaker.text == expected_speaker
	)
	var first_controls_ok: bool = (
		"~30" not in explorer._dialog_box._full_text
		and explorer._dialog_box._pending_pause_seconds > 0.0
	)
	explorer._on_dialog_started(0, 0, 16)
	explorer._on_dialog_message(2520)
	explorer._on_dialog_message(2541)
	var girl_speed_ok: bool = "$06" not in explorer._dialog_box._full_text
	explorer._on_dialog_started(1, 0, 2)
	explorer._on_dialog_message(2524)
	explorer._on_dialog_message(2544)
	var player_speed_ok: bool = "$04" not in explorer._dialog_box._full_text
	explorer.free()
	if not portrait_ok:
		return "仙灵岛洗澡剧情的零肖像李逍遥台词没有恢复头像和姓名"
	if not first_controls_ok or not girl_speed_ok or not player_speed_ok:
		return "仙灵岛洗澡剧情仍显示 M.MSG 速度或停顿控制码"
	return ""


func _test_palace_marriage_night(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 19
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.run_trigger(8992, 343)
	_drive_script(vm)
	var marriage_event := database.event_objects[342]
	var hidden_attendant := database.event_objects[347]
	var failure := ""
	if not unsupported.is_empty():
		failure = "水月宫成亲过夜剧情遇到未支持指令：%s" % ", ".join(unsupported)
	elif messages != _message_range(2294, 2362):
		failure = "水月宫成亲、过夜与天亮对白不完整：%s" % [messages]
	elif next_entries != [8992]:
		failure = "水月宫过夜剧情没有结束于原触发入口：%s" % [next_entries]
	elif session.night_palette:
		failure = "水月宫一夜过去后没有恢复日间调色板"
	elif database.player_roles.scene_sprite_numbers[0] != 2:
		failure = "水月宫天亮后李逍遥没有恢复普通场景造型：%d" % database.player_roles.scene_sprite_numbers[0]
	elif marriage_event.state != 2 or marriage_event.trigger_script != 9187:
		failure = "水月宫床边事件没有进入稳定后续入口：状态 %d，脚本 %d" % [marriage_event.state, marriage_event.trigger_script]
	elif hidden_attendant.state != 0:
		failure = "水月宫过夜后应离场的事件仍然可见：%d" % hidden_attendant.state
	vm.free()
	return failure


func _test_first_island_return_dialog_boundary(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 18
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	var requested_scenes: Array[int] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.scene_change_requested.connect(func(scene_index: int) -> void: requested_scenes.append(scene_index))
	var shore_boat := database.event_objects[116]
	var shore_boat_before_dialog := shore_boat.position
	vm.run_trigger(8681)
	var failure := ""
	if not vm.waiting_for_dialog or messages != _message_range(2185, 2187):
		failure = "首次返航第一轮对白等待不正确：消息 %s，waiting=%s" % [messages, vm.waiting_for_dialog]
	else:
		vm.advance_dialog()
	if failure.is_empty() and (not vm.waiting_for_dialog or messages != _message_range(2185, 2189)):
		failure = "首次返航第二轮对白等待不正确：消息 %s，waiting=%s" % [messages, vm.waiting_for_dialog]
	elif failure.is_empty():
		vm.advance_dialog()
	if failure.is_empty() and (not vm.waiting_for_dialog or messages != _message_range(2185, 2193)):
		failure = "首次返航李逍遥最后一轮对白等待不正确：消息 %s，waiting=%s" % [messages, vm.waiting_for_dialog]
	elif failure.is_empty() and (not requested_scenes.is_empty() or session.scene_index != 18 or shore_boat.position != shore_boat_before_dialog):
		failure = "首次返航最后一轮对白结束前已经回到余杭：场景 %s/%d，船 %s→%s" % [requested_scenes, session.scene_index, shore_boat_before_dialog, shore_boat.position]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.advance_dialog()
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "首次返航剧情遇到未支持指令：%s" % [unsupported]
	elif requested_scenes != [4] or session.scene_index != 4 or session.music_number != 8:
		failure = "首次返航对白结束后没有回到余杭：场景 %s/%d，BGM %d" % [requested_scenes, session.scene_index, session.music_number]
	elif shore_boat.position != Vector2i(1184, 1424) or next_entries != [8681]:
		failure = "首次返航结束后的船只或稳定入口不正确：船 %s，入口 %s" % [shore_boat.position, next_entries]
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


func _test_first_island_statue_puzzle() -> String:
	# 首次赴岛发生在后续剧情改写之前，使用独立数据库避免第二次赴岛状态反向污染。
	var database := PalContentDatabase.new()
	if not database.load_generated():
		return "仙灵岛石像回归无法重新加载本地生成资源：%s" % database.error_message
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 16
	session.set_item_count(279, 1)
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var positions: Array[int] = []
	var sounds: Array[int] = []
	var next_entries: Array[int] = []
	var statue_end_entries: Array[int] = []
	var unsupported: Array[String] = []
	vm.dialog_started.connect(func(position: int, _color: int, _portrait: int) -> void: positions.append(position))
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	for event_id in range(238, 244):
		var statue := database.event_objects[event_id - 1]
		session.party_direction = GameSession.DIR_SOUTH
		session.set_party_world_position(statue.position + Vector2i(16, -8))
		messages.clear()
		positions.clear()
		next_entries.clear()
		vm.run_trigger(database.item_definition(279).script_on_use, 0xffff)
		_drive_script(vm)
		if not vm.touch_trigger_armed or statue.trigger_mode != PalEventObject.TRIGGER_TOUCH_NORMAL or next_entries != [39645]:
			vm.free()
			return "面对第 %d 座石像使用破天锤没有武装接触事件：armed=%s mode=%d entry=%s" % [event_id - 237, vm.touch_trigger_armed, statue.trigger_mode, next_entries]
		next_entries.clear()
		vm.run_trigger(statue.trigger_script, event_id)
		_drive_script(vm)
		statue_end_entries.append(next_entries[0] if not next_entries.is_empty() else -1)
		if event_id < 243 and (not messages.is_empty() or not positions.is_empty()):
			vm.free()
			return "第 %d 座石像过早触发最终破碎叙述：%s" % [event_id - 237, messages]
	var failure := ""
	if not unsupported.is_empty():
		failure = "仙灵岛六座石像遇到未支持指令：%s" % [unsupported]
	elif database.event_objects.slice(237, 243).any(func(event: PalEventObject) -> bool: return event.state != 0):
		failure = "六座石像没有全部变为隐藏状态"
	elif messages != _message_range(2429, 2430) or positions != [3]:
		failure = "第六座石像没有显示合并 Toast：位置 %s，消息 %s" % [positions, messages]
	elif sounds != [262, 262, 262, 262, 262, 262]:
		failure = "石像破碎音效次数不正确：%s" % [sounds]
	elif statue_end_entries != [0, 0, 0, 0, 0, 9433]:
		failure = "石像状态判断的结束入口不正确：%s" % [statue_end_entries]
	elif session.item_count(279) != 0:
		failure = "第六座石像后破天锤没有从背包移除"
	elif database.event_objects[262].state != 1:
		failure = "第六座石像后荷叶通路 EventObject 263 没有开启"
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
	elif database.player_roles.scene_sprite_numbers[0] != 2 or session.scripted_party_frame(0) != 0:
		failure = "喂药剧情结束后李逍遥没有恢复普通 Sprite 2 的站立姿势：sprite=%d frame=%d" % [database.player_roles.scene_sprite_numbers[0], session.scripted_party_frame(0)]
	else:
		# 第一次玩家移动会清除剧情站立帧；渲染器随后必须从普通 Sprite 2 取步态。
		session.record_party_step(GameSession.DIR_EAST, Vector2i(16, 8))
		var walking_sprite := database.load_player_scene_sprite(0)
		if session.scripted_party_frame(0) != -1 or walking_sprite.frame_count() != 12:
			failure = "喂药后第一步仍沿用剧情动作或 Sprite 193：frame=%d sprite_frames=%d" % [session.scripted_party_frame(0), walking_sprite.frame_count()]
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
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	music_requests.clear()
	fade_requests.clear()
	session.scene_index = 2
	vm.run_trigger(7031, 57)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "营救战后向李大娘借船遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1514, 1530) or next_entries != [7067]:
		failure = "营救战后李大娘对话或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif database.event_objects[123].trigger_script != 7071:
		failure = "李大娘对话没有安装张四再赴仙灵岛入口：%d" % database.event_objects[123].trigger_script
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	vm.run_trigger(7067, 57)
	_drive_script(vm)
	if messages != _message_range(1531, 1532) or next_entries != [7067]:
		failure = "李大娘稳定提醒入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	vm.run_trigger(7071, 124)
	_drive_script(vm)
	var destination_boat := database.event_objects[117]
	if not unsupported.is_empty():
		failure = "张四再次送往仙灵岛遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1533, 1552) or next_entries != [7071]:
		failure = "张四再赴仙灵岛对话或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif database.event_objects[116].trigger_script != 5925 or database.event_objects[116].trigger_mode != 6:
		failure = "张四没有启用余杭码头登船入口：脚本 %d，模式 %d" % [database.event_objects[116].trigger_script, database.event_objects[116].trigger_mode]
	elif database.event_objects[123].state != 0 or destination_boat.state != 2 or destination_boat.position != Vector2i(1120, 1424):
		failure = "张四离场或目标船只状态不正确：张四 %d，船 %d/%s" % [database.event_objects[123].state, destination_boat.state, destination_boat.position]
	elif database.scenes[14].script_on_enter != 9541:
		failure = "再赴仙灵岛没有安装双人抵达入口：%d" % database.scenes[14].script_on_enter
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	fade_requests.clear()
	var boat := database.event_objects[116]
	var boat_start := boat.position
	session.set_party_world_position(Vector2i(1184, 1424))
	vm.run_trigger(0x1725, 117)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "赵灵儿同行登船遇到未支持指令：%s" % [unsupported]
	elif fade_requests != [[true, 0.6]] or session.scene_index != 14 or session.party_world_position() != Vector2i(752, 808):
		failure = "赵灵儿同行登船转场不正确：渐隐 %s，场景 %d，落点 %s" % [fade_requests, session.scene_index, session.party_world_position()]
	elif boat.position != boat_start + Vector2i(288, -144):
		failure = "赵灵儿同行时船只没有同步驶离：%s→%s" % [boat_start, boat.position]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[14].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "赵灵儿同行抵达仙灵岛遇到未支持指令：%s" % [unsupported]
	elif not messages.is_empty() or next_entries != [9545]:
		failure = "赵灵儿同行抵达入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([1, 0]) or session.music_number != 70 or session.battle_music_number != 37:
		failure = "赵灵儿同行抵达后的队伍或音乐不正确：队伍 %s，BGM %d/%d" % [session.party_roles, session.music_number, session.battle_music_number]
	vm.free()
	if failure.is_empty():
		failure = _test_island_massacre_funeral_and_return(database, session)
	return failure


func _test_island_massacre_funeral_and_return(database: PalContentDatabase, session: GameSession) -> String:
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var unsupported: Array[String] = []
	var next_entries: Array[int] = []
	var requested_scenes: Array[int] = []
	var battle_requests: Array = []
	var music_requests: Array = []
	var fade_requests: Array = []
	var fbp_requests: Array = []
	var camera_offsets: Array[Vector2i] = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.scene_change_requested.connect(func(scene_index: int) -> void: requested_scenes.append(scene_index))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: battle_requests.append([team, field, boss]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.screen_fade_requested.connect(func(fade_out: bool, duration: float) -> void: fade_requests.append([fade_out, duration]))
	vm.fbp_requested.connect(func(image_number: int, duration: float) -> void: fbp_requests.append([image_number, duration]))
	vm.camera_offset_requested.connect(func(offset: Vector2i) -> void: camera_offsets.append(offset))

	# 再次赴岛前的借船脚本会开启水月宫惨案接触点；石像和通路由首次赴岛用例独立覆盖。
	var massacre_event := database.event_objects[352]
	if massacre_event.state != 1 or massacre_event.trigger_script != 9361 or massacre_event.trigger_mode != PalEventObject.TRIGGER_TOUCH_FAR:
		vm.free()
		return "再次赴岛没有开启水月宫惨案入口：状态 %d，脚本 %d，模式 %d" % [massacre_event.state, massacre_event.trigger_script, massacre_event.trigger_mode]
	session.scene_index = 19
	vm.run_trigger(massacre_event.trigger_script, massacre_event.object_id)
	_drive_script(vm)
	var failure := ""
	if not unsupported.is_empty():
		failure = "水月宫惨案发现剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2422, 2427) or next_entries != [9361]:
		failure = "水月宫惨案发现消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0]) or massacre_event.state != 0:
		failure = "发现惨案后没有暂时移除赵灵儿或关闭接触点：队伍 %s，状态 %d" % [session.party_roles, massacre_event.state]
	elif database.event_objects[342].state != 1 or database.event_objects[342].auto_script not in [9358, 9359]:
		failure = "姥姥受伤对象没有出现并开始移动：状态 %d，自动脚本 %d" % [database.event_objects[342].state, database.event_objects[342].auto_script]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	music_requests.clear()
	var grandmother := database.event_objects[349]
	if grandmother.state != 2 or grandmother.trigger_script != 9196:
		vm.free()
		return "水月宫没有可触发的姥姥临终事件：状态 %d，脚本 %d" % [grandmother.state, grandmother.trigger_script]
	vm.run_trigger(grandmother.trigger_script, grandmother.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "姥姥临终剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2367, 2407) or next_entries != [9196]:
		failure = "姥姥临终消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [18] or session.scene_index != 18 or database.scenes[18].script_on_enter != 9321:
		failure = "姥姥临终后没有进入安葬场景：场景 %s/%d，入口 %d" % [requested_scenes, session.scene_index, database.scenes[18].script_on_enter]
	elif session.party_roles != PackedInt32Array([0]) or database.event_objects[349].state != 0 or database.event_objects[350].state != 0 or database.event_objects[351].state != 0:
		failure = "姥姥临终后队伍或水月宫人物状态未清理：队伍 %s，状态 %d/%d/%d" % [session.party_roles, database.event_objects[349].state, database.event_objects[350].state, database.event_objects[351].state]
	elif database.event_objects.slice(353, 359).any(func(event: PalEventObject) -> bool: return event.state != 0):
		failure = "水月宫安葬前尸体 EventObject 354–359 没有隐藏"
	elif database.event_objects[225].trigger_script != 9454:
		failure = "姥姥临终后没有安装张四返航入口：%d" % database.event_objects[225].trigger_script
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[18].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "水月宫安葬剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2408, 2421) or next_entries != [9357]:
		failure = "水月宫安葬消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0, 1]) or session.music_number != 76:
		failure = "安葬后赵灵儿没有归队或音乐不正确：队伍 %s，BGM %d" % [session.party_roles, session.music_number]
	elif database.event_objects[283].state != 0 or database.event_objects.slice(284, 312).any(func(event: PalEventObject) -> bool: return event.state != 2):
		failure = "安葬场景墓地 EventObject 状态不正确"
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	music_requests.clear()
	var shore_boat := database.event_objects[116]
	var shore_boat_before_dialog := shore_boat.position
	var scene_before_dialog := session.scene_index
	vm.run_trigger(database.event_objects[225].trigger_script, 226)
	if not vm.waiting_for_dialog or messages != [2434]:
		failure = "张四返航对白没有在正文结束处等待：消息 %s，waiting=%s" % [messages, vm.waiting_for_dialog]
	elif not requested_scenes.is_empty() or session.scene_index != scene_before_dialog or shore_boat.position != shore_boat_before_dialog:
		failure = "张四返航对白结束前已经切场景或移动船只：场景 %s/%d，船 %s→%s" % [requested_scenes, session.scene_index, shore_boat_before_dialog, shore_boat.position]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.advance_dialog()
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "水月宫返航剧情遇到未支持指令：%s" % [unsupported]
	elif messages != [2434] or next_entries != [9454]:
		failure = "张四返航消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [4] or session.scene_index != 4 or session.music_number != 49:
		failure = "返航没有回到余杭码头或恢复日间音乐：场景 %s/%d，BGM %d" % [requested_scenes, session.scene_index, session.music_number]
	elif shore_boat.position != Vector2i(1184, 1424) or shore_boat.trigger_script != 0 or database.event_objects[123].state != 2:
		failure = "返航后余杭船只或张四状态不正确：船 %s/%d，张四 %d" % [shore_boat.position, shore_boat.trigger_script, database.event_objects[123].state]
	if not failure.is_empty():
		vm.free()
		return failure

	# 返回客栈立即进入敌队 19 强制战；先验证阻塞请求，再模拟胜利继续到安置赵灵儿。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	music_requests.clear()
	battle_requests.clear()
	session.scene_index = 2
	if database.event_objects[59].state != 2 or database.event_objects[59].trigger_script != 7126:
		vm.free()
		return "返航后客栈没有开启黑苗头领强制战：状态 %d，脚本 %d" % [database.event_objects[59].state, database.event_objects[59].trigger_script]
	vm.run_trigger(7126, 60)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "返航客栈强制战前遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[19, 21, true]]:
		failure = "返航客栈没有请求敌队 19／战场 21 的 Boss 战：%s" % [battle_requests]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "返航客栈强制战后剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1553, 1600) or next_entries != [7126]:
		failure = "返航客栈强制战后消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [0] or session.scene_index != 0 or database.scenes[0].script_on_enter != 7283:
		failure = "强制战后没有进入安置赵灵儿的客房阶段：场景 %s/%d，入口 %d" % [requested_scenes, session.scene_index, database.scenes[0].script_on_enter]
	elif session.party_roles != PackedInt32Array([0]) or database.event_objects[30].state != 1:
		failure = "强制战后队伍或客房赵灵儿事件状态不正确：队伍 %s，事件31=%d" % [session.party_roles, database.event_objects[30].state]
	if not failure.is_empty():
		vm.free()
		return failure

	# 进入客房安置赵灵儿；场景进入脚本、床边查看和李大娘安排休息是三个独立触发点。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	fbp_requests.clear()
	vm.run_trigger(database.scenes[0].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "安置赵灵儿的客房进入脚本遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1601, 1602) or next_entries != [7290]:
		failure = "安置赵灵儿的客房消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_world_position() != Vector2i(720, 328):
		failure = "安置赵灵儿后李逍遥位置不正确：%s" % session.party_world_position()
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[0].script_on_enter = next_entries[0]

	messages.clear()
	next_entries.clear()
	var resting_linger := database.event_objects[30]
	vm.run_trigger(resting_linger.trigger_script, resting_linger.object_id)
	_drive_script(vm)
	if messages != [1603] or next_entries != [7291]:
		failure = "床边查看赵灵儿的消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	if not failure.is_empty():
		vm.free()
		return failure

	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	fbp_requests.clear()
	var aunt := database.event_objects[56]
	if aunt.state != 2 or aunt.trigger_script != 7294:
		vm.free()
		return "强制战后李大娘没有切到安排休息入口：状态 %d，脚本 %d" % [aunt.state, aunt.trigger_script]
	session.scene_index = 2
	vm.run_trigger(aunt.trigger_script, aunt.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "李大娘安排休息剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1604, 1612) or next_entries != [7294]:
		failure = "李大娘安排休息消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [0] or session.scene_index != 0 or database.scenes[0].script_on_enter != 7327:
		failure = "休息后没有切回夜间客房入口：场景 %s/%d，入口 %d" % [requested_scenes, session.scene_index, database.scenes[0].script_on_enter]
	elif aunt.state != 0 or resting_linger.state != 0:
		failure = "休息转场没有隐藏李大娘或床上的赵灵儿：状态 %d/%d" % [aunt.state, resting_linger.state]
	elif fbp_requests != [[0xffff, 0.0]]:
		failure = "休息叙述没有请求原版黑屏 FBP：%s" % [fbp_requests]
	elif fade_requests.size() != 3 or fade_requests[0][0] != true or not is_equal_approx(fade_requests[0][1], 0.6) or fade_requests[1][0] != false or not is_equal_approx(fade_requests[1][1], 0.6) or fade_requests[2][0] != true:
		failure = "休息黑屏的渐隐／默认渐显时序不正确：%s" % [fade_requests]
	if not failure.is_empty():
		vm.free()
		return failure

	# 夜间醒来换回普通造型，并在楼下安装李大娘后续事件。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	fbp_requests.clear()
	vm.run_trigger(database.scenes[0].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "夜间客房进入剧情遇到未支持指令：%s" % [unsupported]
	elif messages != [1618, 1619] or next_entries != [7345]:
		failure = "夜间醒来消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif not session.night_palette or session.party_world_position() != Vector2i(1296, 264) or database.player_roles.scene_sprite_numbers[0] != 2:
		failure = "夜间醒来的调色板、位置或李逍遥造型不正确：night=%s，位置=%s，造型=%d" % [session.night_palette, session.party_world_position(), database.player_roles.scene_sprite_numbers[0]]
	var night_aunt := database.event_objects[68]
	if failure.is_empty() and (night_aunt.state != 2 or night_aunt.trigger_script != 7346 or night_aunt.trigger_mode != PalEventObject.TRIGGER_TOUCH_FARTHER or night_aunt.position != Vector2i(1616, 1528)):
		failure = "夜间李大娘事件没有正确安装：状态 %d，脚本 %d，模式 %d，位置 %s" % [night_aunt.state, night_aunt.trigger_script, night_aunt.trigger_mode, night_aunt.position]
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[0].script_on_enter = next_entries[0]

	# 下楼接触李大娘后，完整跑过夜间长剧情、场景过程渐隐、黑屏叙述和次日恢复。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	fbp_requests.clear()
	session.scene_index = 2
	vm.run_trigger(night_aunt.trigger_script, night_aunt.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "夜间李大娘长剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1620, 1657) or next_entries != [7346]:
		failure = "夜间李大娘长剧情消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [0] or session.scene_index != 0 or session.night_palette or session.music_number != 8:
		failure = "夜间剧情结束后没有恢复白天客房与 BGM：场景 %s/%d，night=%s，BGM=%d" % [requested_scenes, session.scene_index, session.night_palette, session.music_number]
	elif fbp_requests != [[0xffff, 0.0]]:
		failure = "夜间剧情结尾没有请求原版黑屏 FBP：%s" % [fbp_requests]
	elif fade_requests.size() != 3 or fade_requests[0][0] != true or not is_equal_approx(fade_requests[0][1], 3.2) or fade_requests[1][0] != false or not is_equal_approx(fade_requests[1][1], 0.6) or fade_requests[2][0] != true:
		failure = "夜间剧情的场景渐隐／黑屏／次日渐隐时序不正确：%s" % [fade_requests]
	if not failure.is_empty():
		vm.free()
		return failure

	# 次日在二楼与李大娘长谈，取得包袱并安装赵灵儿同行及码头离村入口。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	fbp_requests.clear()
	var day_aunt := database.event_objects[38]
	if day_aunt.state != 2 or day_aunt.trigger_script != 7488:
		vm.free()
		return "次日二楼没有出现李大娘主线事件：状态 %d，脚本 %d" % [day_aunt.state, day_aunt.trigger_script]
	session.scene_index = 1
	vm.run_trigger(day_aunt.trigger_script, day_aunt.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "次日李大娘长谈遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1658, 1714) or next_entries != [7599]:
		failure = "次日李大娘长谈消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.item_count(280) != 1:
		failure = "李大娘交付的包袱没有进入背包：%d" % session.item_count(280)
	if not failure.is_empty():
		vm.free()
		return failure

	# 与同层的赵灵儿交谈后恢复双人队伍，并把余杭室外进入脚本切到离村段落。
	messages.clear()
	next_entries.clear()
	var linger := database.event_objects[37]
	if linger.state != 2 or linger.trigger_script != 7603:
		vm.free()
		return "次日赵灵儿没有进入同行触发状态：状态 %d，脚本 %d" % [linger.state, linger.trigger_script]
	vm.run_trigger(linger.trigger_script, linger.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "赵灵儿同行剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1717, 1720) or next_entries != [7603]:
		failure = "赵灵儿同行消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0, 1]) or linger.state != 0:
		failure = "赵灵儿同行后队伍或场景事件状态不正确：队伍 %s，状态 %d" % [session.party_roles, linger.state]
	elif database.scenes[3].script_on_enter != 7938 or database.event_objects[125].trigger_script != 7892:
		failure = "离开客栈后没有安装余杭告别或码头乘船入口：室外 %d，码头 %d" % [database.scenes[3].script_on_enter, database.event_objects[125].trigger_script]
	if not failure.is_empty():
		vm.free()
		return failure

	# 进入余杭室外自动走出四步并告别，结尾按原版把全队 HP/MP 恢复至上限。
	messages.clear()
	next_entries.clear()
	session.scene_index = 3
	vm.run_trigger(database.scenes[3].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "离开余杭的室外进入剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1896, 1897) or next_entries != [7951]:
		failure = "离开余杭的告别消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.role_hp[0] != session.role_max_hp[0] or session.role_hp[1] != session.role_max_hp[1] or session.role_mp[0] != session.role_max_mp[0] or session.role_mp[1] != session.role_max_mp[1]:
		failure = "离村前没有按原版恢复双人 HP/MP"
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[3].script_on_enter = next_entries[0]

	# 方老板码头对话先把李逍遥切成乘船造型，再启用船体 EventObject 的接触脚本。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	var dock_owner := database.event_objects[125]
	session.scene_index = 4
	vm.run_trigger(dock_owner.trigger_script, dock_owner.object_id)
	_drive_script(vm)
	var travel_boat := database.event_objects[126]
	if not unsupported.is_empty():
		failure = "余杭前往苏州的码头对话遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(1885, 1894) or next_entries != [7892]:
		failure = "方老板码头对话消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0]) or database.player_roles.scene_sprite_numbers[0] != 232 or dock_owner.state != 0:
		failure = "登船前队伍、李逍遥乘船造型或方老板事件状态不正确"
	elif travel_boat.trigger_mode != PalEventObject.TRIGGER_TOUCH_FARTHEST or travel_boat.trigger_script != 7916 or session.party_world_position() != Vector2i(1248, 1200):
		failure = "前往苏州的船体触发或登船位置不正确：模式 %d，脚本 %d，位置 %s" % [travel_boat.trigger_mode, travel_boat.trigger_script, session.party_world_position()]
	elif fade_requests.size() != 1 or not fade_requests[0][0] or not is_equal_approx(fade_requests[0][1], 0.6):
		failure = "余杭码头登船前没有按原版渐隐：%s" % [fade_requests]
	if not failure.is_empty():
		vm.free()
		return failure

	# 接触船体后同步移动船和队伍，恢复双人普通造型并切换到苏州城外场景。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	vm.run_trigger(travel_boat.trigger_script, travel_boat.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "余杭驶向苏州的乘船动画遇到未支持指令：%s" % [unsupported]
	elif next_entries != [7916] or requested_scenes != [21] or session.scene_index != 21:
		failure = "乘船后没有切换到苏州城外：入口 %s，场景 %s/%d" % [next_entries, requested_scenes, session.scene_index]
	elif session.party_roles != PackedInt32Array([0, 1]) or database.player_roles.scene_sprite_numbers[0] != 2 or session.party_world_position() != Vector2i(1360, 1688):
		failure = "抵达苏州前队伍、造型或落点不正确：队伍 %s，造型 %d，位置 %s" % [session.party_roles, database.player_roles.scene_sprite_numbers[0], session.party_world_position()]
	elif travel_boat.position != Vector2i(960, 1056) or fade_requests.size() != 1 or not fade_requests[0][0]:
		failure = "驶离后的船体终点或场景渐隐不正确：船 %s，渐变 %s" % [travel_boat.position, fade_requests]
	if not failure.is_empty():
		vm.free()
		return failure

	# 苏州城外进入脚本负责设置区域 BGM、战斗音乐和双人落点。
	messages.clear()
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[21].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州城外进入剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(3131, 3134) or next_entries != [11419]:
		failure = "苏州城外进入消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.music_number != 71 or session.battle_music_number != 37 or session.party_roles != PackedInt32Array([0, 1]):
		failure = "苏州城外音乐或队伍状态不正确：BGM %d/%d，队伍 %s" % [session.music_number, session.battle_music_number, session.party_roles]
	elif session.party_world_position() != Vector2i(1104, 1384):
		failure = "苏州城外进入落点不正确：%s" % session.party_world_position()
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[21].script_on_enter = next_entries[0]

	# 靠近树下事件后，短自动段隐藏远景占位并开启林月如的首次对话对象。
	messages.clear()
	next_entries.clear()
	var distant_event := database.event_objects[411]
	var yueru_event := database.event_objects[413]
	if distant_event.state != 2 or distant_event.trigger_script != 10037:
		vm.free()
		return "苏州城外没有可触发的林月如远景事件：状态 %d，脚本 %d" % [distant_event.state, distant_event.trigger_script]
	vm.run_trigger(distant_event.trigger_script, distant_event.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "林月如远景切换遇到未支持指令：%s" % [unsupported]
	elif not messages.is_empty() or next_entries != [10037] or distant_event.state != 0 or yueru_event.state != 2:
		failure = "林月如远景切换后的消息、入口或事件显隐不正确：消息 %s，入口 %s，状态 %d/%d" % [messages, next_entries, distant_event.state, yueru_event.state]
	if not failure.is_empty():
		vm.free()
		return failure

	# 第一次交锋包含长对话和敌队 21／战场 3 的不可逃跑战斗；胜利后月如被缚在树上。
	messages.clear()
	next_entries.clear()
	battle_requests.clear()
	vm.run_trigger(yueru_event.trigger_script, yueru_event.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "林月如首次交锋战前遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[21, 3, true]]:
		failure = "林月如首次交锋没有请求敌队 21／战场 3：%s" % [battle_requests]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	var tied_yueru := database.event_objects[419]
	var city_gate_prompt := database.event_objects[420]
	if not unsupported.is_empty():
		failure = "林月如首次交锋战后遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2560, 2638) or next_entries != [10045]:
		failure = "林月如首次交锋消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif yueru_event.state != 0 or tied_yueru.state != 2 or city_gate_prompt.state != 1 or city_gate_prompt.trigger_script != 10253:
		failure = "首次交锋后林月如、绑缚或城门折返事件状态不正确：%d/%d/%d，入口 %d" % [yueru_event.state, tied_yueru.state, city_gate_prompt.state, city_gate_prompt.trigger_script]
	if not failure.is_empty():
		vm.free()
		return failure

	# 第一次接近城门听到呼救，灵儿要求回去看看；同时把树下月如切到对话入口。
	messages.clear()
	next_entries.clear()
	vm.run_trigger(city_gate_prompt.trigger_script, city_gate_prompt.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州城门第一次呼救剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2655, 2667) or next_entries != [10282]:
		failure = "苏州城门第一次呼救消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif tied_yueru.trigger_script != 10227:
		failure = "第一次折返后树下林月如没有切换到争执入口：%d" % tied_yueru.trigger_script
	if not failure.is_empty():
		vm.free()
		return failure
	city_gate_prompt.trigger_script = next_entries[0]

	# 返回树下争执后再次离开；这段脚本把城门提示升级到第二次真实呼救入口。
	messages.clear()
	next_entries.clear()
	vm.run_trigger(tied_yueru.trigger_script, tied_yueru.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "第一次返回树下的争执剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2640, 2653) or next_entries != [10251]:
		failure = "第一次返回树下的争执消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif city_gate_prompt.trigger_script != 10303:
		failure = "树下争执后没有安装第二次城门呼救入口：%d" % city_gate_prompt.trigger_script
	if not failure.is_empty():
		vm.free()
		return failure
	tied_yueru.trigger_script = next_entries[0]

	# 第二次接近城门确认月如真的遇险，随后把树下对象改为可接触的解救入口。
	messages.clear()
	next_entries.clear()
	vm.run_trigger(city_gate_prompt.trigger_script, city_gate_prompt.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州城门第二次呼救剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2668, 2682) or next_entries != [10334]:
		failure = "苏州城门第二次呼救消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif tied_yueru.trigger_script != 10357 or tied_yueru.trigger_mode != PalEventObject.TRIGGER_TOUCH_FARTHER:
		failure = "第二次折返后树下林月如没有切换到解救入口：脚本 %d，模式 %d" % [tied_yueru.trigger_script, tied_yueru.trigger_mode]
	if not failure.is_empty():
		vm.free()
		return failure

	# 返回树下先击退敌队 22，随后完整执行月如刺伤、灵儿施法救治和双人恢复。
	messages.clear()
	next_entries.clear()
	battle_requests.clear()
	vm.run_trigger(tied_yueru.trigger_script, tied_yueru.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "返回解救林月如的战前剧情遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[22, 3, true]]:
		failure = "解救林月如没有请求敌队 22／战场 3：%s" % [battle_requests]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "解救林月如战后剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2683, 2692) or next_entries != [10357]:
		failure = "解救林月如战后消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0]) or tied_yueru.state != 0 or database.event_objects[412].state != 1:
		failure = "解救战后没有暂时移除赵灵儿或开启林月如刺伤事件：队伍 %s，状态 %d/%d" % [session.party_roles, tied_yueru.state, database.event_objects[412].state]
	if not failure.is_empty():
		vm.free()
		return failure

	# 林月如独立事件继续刺伤李逍遥，赵灵儿耗尽真气救治后恢复双人队伍。
	messages.clear()
	next_entries.clear()
	var stabbing_yueru := database.event_objects[412]
	vm.run_trigger(stabbing_yueru.trigger_script, stabbing_yueru.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "林月如刺伤与灵儿救治剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(2693, 2753) or next_entries != [10390]:
		failure = "林月如刺伤与灵儿救治消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0, 1]) or database.player_roles.scene_sprite_numbers[0] != 2 or not session.has_magic(1, 301):
		failure = "救治后队伍、李逍遥造型或赵灵儿新仙术不正确：队伍 %s，造型 %d，仙术=%s" % [session.party_roles, database.player_roles.scene_sprite_numbers[0], session.has_magic(1, 301)]
	elif session.role_hp[0] != session.role_max_hp[0] or session.role_hp[1] != session.role_max_hp[1] or session.role_mp[0] != session.role_max_mp[0] or session.role_mp[1] != session.role_max_mp[1]:
		failure = "灵儿救治后没有按原版恢复双人 HP/MP"
	elif tied_yueru.state != 0 or database.event_objects[414].state != 1 or stabbing_yueru.state != 0:
		failure = "救治结束后的林月如相关 EventObject 状态不正确"
	if not failure.is_empty():
		vm.free()
		return failure

	# 城门传送进入苏州城，内部场景进入脚本把区域音乐切为 50。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	var city_entrance := database.event_objects[410]
	vm.run_trigger(city_entrance.trigger_script, city_entrance.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "进入苏州城的传送脚本遇到未支持指令：%s" % [unsupported]
	elif requested_scenes != [20] or session.scene_index != 20 or session.party_world_position() != Vector2i(448, 1296):
		failure = "苏州城门没有切到城内正确落点：场景 %s/%d，位置 %s" % [requested_scenes, session.scene_index, session.party_world_position()]
	elif fade_requests.size() != 1 or not fade_requests[0][0] or not is_equal_approx(fade_requests[0][1], 0.6):
		failure = "进入苏州城没有请求默认渐隐：%s" % [fade_requests]
	if not failure.is_empty():
		vm.free()
		return failure
	messages.clear()
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[20].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州城内进入脚本遇到未支持指令：%s" % [unsupported]
	elif not messages.is_empty() or next_entries != [11365] or session.music_number != 50:
		failure = "苏州城内进入后的消息、稳定入口或 BGM 不正确：消息 %s，入口 %s，BGM %d" % [messages, next_entries, session.music_number]
	if not failure.is_empty():
		vm.free()
		return failure

	# 在苏州客栈入口救下刘晋元，战前停止街区音乐并请求敌队 23／战场 21。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	battle_requests.clear()
	music_requests.clear()
	fade_requests.clear()
	var inn_bully := database.event_objects[524]
	if inn_bully.state != 1 or inn_bully.trigger_script != 11165:
		vm.free()
		return "苏州客栈没有可触发的刘晋元解围事件：状态 %d，脚本 %d" % [inn_bully.state, inn_bully.trigger_script]
	session.scene_index = 27
	vm.run_trigger(inn_bully.trigger_script, inn_bully.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州客栈解围战前遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[23, 21, true]]:
		failure = "苏州客栈解围没有请求敌队 23／战场 21：%s" % [battle_requests]
	elif messages != _message_range(3046, 3050):
		failure = "苏州客栈解围战前消息不正确：%s" % [messages]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "苏州客栈解围战后遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(3046, 3052) or next_entries != [11165]:
		failure = "苏州客栈解围消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [25] or session.scene_index != 25 or database.scenes[25].script_on_enter != 11190:
		failure = "解围后没有进入刘晋元宴请场景：场景 %s/%d，入口 %d" % [requested_scenes, session.scene_index, database.scenes[25].script_on_enter]
	elif inn_bully.state != 0 or database.event_objects.slice(438, 453).any(func(event: PalEventObject) -> bool: return event.state != 0):
		failure = "解围后客栈恶少或苏州围观 EventObject 没有清理"
	elif session.music_number != 71:
		failure = "刘晋元宴请前没有恢复苏州区域音乐 71：%d" % session.music_number
	if not failure.is_empty():
		vm.free()
		return failure

	# 宴请进入脚本让灵儿先离队休息，跨过夜间调色板后在次日留下睡眠事件。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	fade_requests.clear()
	vm.run_trigger(database.scenes[25].script_on_enter)
	_drive_script(vm)
	var sleeping_linger := database.event_objects[507]
	if not unsupported.is_empty():
		failure = "刘晋元宴请与过夜剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(3053, 3075) or next_entries != [11274]:
		failure = "刘晋元宴请与过夜消息或未来入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0]) or session.night_palette or sleeping_linger.state != 1 or sleeping_linger.trigger_script != 11378:
		failure = "客栈次日的队伍、调色板或熟睡赵灵儿事件不正确：队伍 %s，night=%s，状态 %d，脚本 %d" % [session.party_roles, session.night_palette, sleeping_linger.state, sleeping_linger.trigger_script]
	elif database.player_roles.scene_sprite_numbers[0] != 2 or session.party_world_position() != Vector2i(640, 464):
		failure = "客栈次日李逍遥造型或落点不正确：造型 %d，位置 %s" % [database.player_roles.scene_sprite_numbers[0], session.party_world_position()]
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[25].script_on_enter = next_entries[0]

	# 叫醒赵灵儿后隐藏床上两个阶段 Sprite，并恢复双人队伍继续逛苏州。
	messages.clear()
	next_entries.clear()
	vm.run_trigger(sleeping_linger.trigger_script, sleeping_linger.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "客栈次日叫醒赵灵儿遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(3116, 3125) or next_entries != [11378]:
		failure = "客栈次日叫醒赵灵儿消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif session.party_roles != PackedInt32Array([0, 1]) or sleeping_linger.state != 0 or database.event_objects[508].state != 0:
		failure = "叫醒赵灵儿后队伍或床上 EventObject 没有恢复：队伍 %s，状态 %d/%d" % [session.party_roles, sleeping_linger.state, database.event_objects[508].state]
	if not failure.is_empty():
		vm.free()
		return failure

	# 从苏州街区进入林家堡擂台；场景入口用 00A3 将 CD 音轨回退为 RIX BGM 14。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	music_requests.clear()
	fade_requests.clear()
	camera_offsets.clear()
	var tournament_entrance := database.event_objects[423]
	session.scene_index = 22
	vm.run_trigger(tournament_entrance.trigger_script, tournament_entrance.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "进入比武招亲场景的传送脚本遇到未支持指令：%s" % [unsupported]
	elif requested_scenes != [31] or session.scene_index != 31 or session.party_world_position() != Vector2i(1376, 864):
		failure = "比武招亲入口没有切到擂台正确落点：场景 %s/%d，位置 %s" % [requested_scenes, session.scene_index, session.party_world_position()]
	if not failure.is_empty():
		vm.free()
		return failure
	messages.clear()
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[31].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "比武招亲场景进入脚本遇到未支持指令：%s" % [unsupported]
	elif not messages.is_empty() or next_entries != [13448] or session.music_number != 14 or music_requests != [[14, true, 0.0]]:
		failure = "比武招亲场景的消息、未来入口或 CD 回退 BGM 不正确：消息 %s，入口 %s，BGM %d/%s" % [messages, next_entries, session.music_number, music_requests]
	if not failure.is_empty():
		vm.free()
		return failure
	database.scenes[31].script_on_enter = next_entries[0]

	# 接触擂台主事件，完整执行观战、上台动画和镜头平移，随后请求敌队 24／战场 26。
	messages.clear()
	next_entries.clear()
	requested_scenes.clear()
	battle_requests.clear()
	music_requests.clear()
	camera_offsets.clear()
	var tournament_event := database.event_objects[550]
	vm.run_trigger(tournament_event.trigger_script, tournament_event.object_id)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "比武招亲战前剧情遇到未支持指令：%s" % [unsupported]
	elif not vm.waiting_for_battle or battle_requests != [[24, 26, true]]:
		failure = "比武招亲没有请求敌队 24／战场 26：%s" % [battle_requests]
	elif messages != _message_range(3309, 3409):
		failure = "比武招亲战前消息不正确：%s" % [messages]
	elif camera_offsets.is_empty() or camera_offsets[-1] != Vector2i(-16, -8):
		failure = "比武招亲战前 007F 镜头没有逐帧移动到原版偏移：%s" % [camera_offsets]
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty():
		failure = "比武招亲战后剧情遇到未支持指令：%s" % [unsupported]
	elif messages != _message_range(3309, 3441) or next_entries != [12111]:
		failure = "比武招亲完整消息或稳定入口不正确：消息 %s，入口 %s" % [messages, next_entries]
	elif requested_scenes != [33] or session.scene_index != 33 or database.scenes[33].script_on_enter != 12619:
		failure = "比武招亲后没有进入林家堡内厅：场景 %s/%d，入口 %d" % [requested_scenes, session.scene_index, database.scenes[33].script_on_enter]
	elif session.party_roles != PackedInt32Array([0]) or session.battle_music_number != 14:
		failure = "比武招亲后队伍或战斗音乐状态不正确：队伍 %s，战斗 BGM %d" % [session.party_roles, session.battle_music_number]
	elif camera_offsets.is_empty() or camera_offsets[-1] != Vector2i.ZERO:
		failure = "比武招亲切场景时没有复位剧情镜头：%s" % [camera_offsets]
	vm.free()
	return failure


func _test_boat_steps_and_item_narration(_progressed_database: PalContentDatabase) -> String:
	# 主线数据库已被第二次赴岛剧情改写；重新加载一份只读内容验证首次求药乘船。
	var database := PalContentDatabase.new()
	if not database.load_generated():
		return "首次乘船回归无法重新加载本地生成资源：%s" % database.error_message
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
