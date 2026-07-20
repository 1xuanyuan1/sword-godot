# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证蛤蟆谷、金蟾鬼母、白苗酒店冲突与乘船抵达长安主线。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _music_requests: Array = []
var _battle_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_toad_mountain_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 蛤蟆谷、金蟾鬼母、五毒珠、白苗酒店与乘船抵达长安主线完成")
	quit(0)


func _test_toad_mountain_mainline(database: PalContentDatabase) -> String:
	# 从扬州女飞贼案结束、北门放行后的蛤蟆谷前山路继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 104
	session.party_roles = PackedInt32Array([0, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(224, 1072))
	session.set_item_count(267, 1)
	session.cash = 6500

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 沿蛤蟆谷前后段进入洞穴，首次见到受伤女子并得知北面栈道已毁。
	_run_scene_enter(vm, database, 104)
	if not _unsupported.is_empty() or session.music_number != 8 or session.battle_music_number != 41 or session.battlefield_number != 3:
		vm.free()
		return "蛤蟆谷前山路音乐或战场状态错误：music=%d battle_music=%d field=%d unsupported=%s" % [session.music_number, session.battle_music_number, session.battlefield_number, _unsupported]
	var failure := _run_transition(vm, database.event_objects[2039], 101, Vector2i(576, 1376))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆谷前山路没有进入谷地前段：%s" % failure
	_run_scene_enter(vm, database, 101)
	if not _unsupported.is_empty() or session.music_number != 35 or session.battlefield_number != 5:
		vm.free()
		return "蛤蟆谷前段音乐或战场状态错误：music=%d field=%d unsupported=%s" % [session.music_number, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[1955], 100, Vector2i(1792, 1744))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆谷前段没有进入后段：%s" % failure
	_run_scene_enter(vm, database, 100)
	if not _unsupported.is_empty() or session.music_number != 35 or session.battlefield_number != 17:
		vm.free()
		return "蛤蟆谷后段音乐或战场状态错误：music=%d field=%d unsupported=%s" % [session.music_number, session.battlefield_number, _unsupported]
	failure = _run_event(vm, database.event_objects[1921])
	if not failure.is_empty() or _messages != _message_range(8459, 8492):
		vm.free()
		return "蛤蟆谷受伤女子剧情不完整：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[1918], 102, Vector2i(544, 1808))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆谷后段没有进入洞穴：%s" % failure
	_run_scene_enter(vm, database, 102)
	if not _unsupported.is_empty() or session.music_number != 36 or session.battle_music_number != 45 or session.battlefield_number != 18:
		vm.free()
		return "蛤蟆洞音乐或战场状态错误：music=%d battle_music=%d field=%d unsupported=%s" % [session.music_number, session.battle_music_number, session.battlefield_number, _unsupported]
	failure = _run_event(vm, database.event_objects[1983])
	if not failure.is_empty() or _messages != _message_range(8495, 8524) or database.scenes[100].script_on_enter != 25891:
		vm.free()
		return "初访金蟾鬼母或返程入口没有安装：failure=%s messages=%s enter=%d" % [failure, _messages, database.scenes[100].script_on_enter]

	# 按剧情先退出洞穴商量，再返回触发金蟾鬼母与蛤蟆精 Boss 战。
	failure = _run_transition(vm, database.event_objects[1979], 100, Vector2i(896, 896))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆洞没有返回谷地后段：%s" % failure
	_run_scene_enter(vm, database, 100)
	if not _unsupported.is_empty() or _messages != _message_range(8527, 8535) or database.event_objects[1983].trigger_script != 25922:
		vm.free()
		return "月如识破疑点或 Boss 入口未开启：messages=%s boss=%d unsupported=%s" % [_messages, database.event_objects[1983].trigger_script, _unsupported]
	failure = _run_transition(vm, database.event_objects[1918], 102, Vector2i(544, 1808))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆谷没有再次进入洞穴：%s" % failure
	_run_scene_enter(vm, database, 102)
	_clear_trace()
	var toad_boss := database.event_objects[1983]
	var toad_boss_entry := toad_boss.trigger_script
	vm.run_trigger(toad_boss_entry, toad_boss.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(8536, 8552) or _battle_requests != [[36, 18, true]] or not vm.waiting_for_battle:
		var waiting_for_toad := vm.waiting_for_battle
		vm.free()
		return "金蟾鬼母战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, waiting_for_toad, _unsupported]
	failure = _resolve_battle(database, session, 36, 18, PackedInt32Array([500, 465]), 36018, true)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(toad_boss, toad_boss_entry)
	if not _unsupported.is_empty() or session.music_number != 82 or toad_boss.state != 0 or database.event_objects.slice(1985, 1993).any(func(event: PalEventObject) -> bool: return event.state != 2):
		vm.free()
		return "金蟾鬼母战后尸体状态错误：music=%d boss=%d unsupported=%s" % [session.music_number, toad_boss.state, _unsupported]

	# 调查蛤蟆精尸体，取得会保留到后续章节的五毒珠 262。
	failure = _run_event(vm, database.event_objects[1985])
	if not failure.is_empty() or _messages != [8553] or session.item_count(262) != 1:
		vm.free()
		return "蛤蟆精尸体没有交付五毒珠：failure=%s messages=%s pearl=%d" % [failure, _messages, session.item_count(262)]

	# 穿过洞穴后段抵达白苗酒店，在店内被盖罗娇以迷药留住。
	failure = _run_transition(vm, database.event_objects[1980], 103, Vector2i(1344, 1760))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆洞前段没有进入后段：%s" % failure
	_run_scene_enter(vm, database, 103)
	failure = _run_transition(vm, database.event_objects[2002], 105, Vector2i(1680, 520))
	if not failure.is_empty():
		vm.free()
		return "蛤蟆洞后段没有抵达白苗酒店山路：%s" % failure
	_run_scene_enter(vm, database, 105)
	if not _unsupported.is_empty() or session.music_number != 12:
		vm.free()
		return "白苗酒店外音乐状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[2045], 109, Vector2i(976, 712))
	if not failure.is_empty():
		vm.free()
		return "白苗酒店外没有进入店内：%s" % failure
	failure = _run_event(vm, database.event_objects[2136])
	if not failure.is_empty() or _messages != _message_range(6446, 6510) or session.scene_index != 105 or session.party_roles != PackedInt32Array([0]) or database.scenes[105].script_on_enter != 21035:
		vm.free()
		return "盖罗娇迷药剧情或店外伏击入口错误：failure=%s messages=%s scene=%d party=%s enter=%d" % [failure, _messages, session.scene_index, session.party_roles, database.scenes[105].script_on_enter]

	# 店外以剧情临时角色迎战石长老；战后剑圣带走灵儿，逍遥与月如恢复双人队。
	_clear_trace()
	var hotel_scene := database.scenes[105]
	var hotel_battle_entry := hotel_scene.script_on_enter
	vm.run_trigger(hotel_battle_entry)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(6376, 6401) or _battle_requests != [[37, 20, true]] or not vm.waiting_for_battle or session.party_roles != PackedInt32Array([4, 5, 4]):
		var waiting_for_hotel := vm.waiting_for_battle
		vm.free()
		return "白苗与石长老剧情战入口错误：messages=%s battles=%s waiting=%s party=%s unsupported=%s" % [_messages, _battle_requests, waiting_for_hotel, session.party_roles, _unsupported]
	failure = _resolve_battle(database, session, 37, 20, PackedInt32Array([496]), 37020, false)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _next_entries.is_empty():
		hotel_scene.script_on_enter = _next_entries[-1]
	if not _unsupported.is_empty() or _messages != _message_range(6376, 6445) or session.scene_index != 109 or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "石长老剧情战后没有回到酒店：messages=%s scene=%d party=%s unsupported=%s" % [_messages, session.scene_index, session.party_roles, _unsupported]
	_run_scene_enter(vm, database, 109)
	if not _unsupported.is_empty() or _messages != _message_range(6511, 6518) or session.party_roles != PackedInt32Array([0, 2]) or database.player_roles.scene_sprite_numbers[0] != 2:
		vm.free()
		return "剑圣带走灵儿后的苏醒状态错误：messages=%s party=%s sprite=%d unsupported=%s" % [_messages, session.party_roles, database.player_roles.scene_sprite_numbers[0], _unsupported]

	# 回到店外救醒盖罗娇，得知灵儿被剑圣带走并开启水仙尊王庙的船家剧情。
	failure = _run_transition(vm, database.event_objects[2130], 108, Vector2i(912, 1064))
	if not failure.is_empty():
		vm.free()
		return "白苗酒店内没有回到事后山路：%s" % failure
	_run_scene_enter(vm, database, 108)
	failure = _run_event(vm, database.event_objects[2114])
	if not failure.is_empty() or _messages != _message_range(6520, 6568) or session.party_roles != PackedInt32Array([2, 0]) or database.event_objects[2146].trigger_script != 19918:
		vm.free()
		return "救醒盖罗娇后的队伍或船家入口错误：failure=%s messages=%s party=%s boat=%d" % [failure, _messages, session.party_roles, database.event_objects[2146].trigger_script]

	# 从酒店后续场景前往长安城外，经水仙尊王庙码头随尚书夫人乘船入城。
	failure = _run_transition(vm, database.event_objects[2110], 106, Vector2i(1744, 1752))
	if not failure.is_empty():
		vm.free()
		return "白苗酒店山路没有进入长安城外田园：%s" % failure
	_run_scene_enter(vm, database, 106)
	if not _unsupported.is_empty() or session.music_number != 12:
		vm.free()
		return "长安城外田园音乐状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[2066], 111, Vector2i(1216, 1728))
	if not failure.is_empty():
		vm.free()
		return "长安城外没有抵达水仙尊王庙：%s" % failure
	failure = _run_transition(vm, database.event_objects[2161], 110, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "水仙尊王庙没有进入码头：%s" % failure
	failure = _run_event(vm, database.event_objects[2146])
	if not failure.is_empty() or _messages != _message_range(5967, 5995) or session.scene_index != 99:
		vm.free()
		return "尚书夫人乘船剧情没有抵达长安：failure=%s messages=%s scene=%d" % [failure, _messages, session.scene_index]
	_run_scene_enter(vm, database, 99)
	if not _unsupported.is_empty() or _messages != _message_range(6911, 6937) or PalSceneCatalog.name_for_scene_index(session.scene_index) != "长安" or session.party_roles != PackedInt32Array([2, 0]) or session.party_world_position() != Vector2i(432, 328) or session.music_number != 53 or session.item_count(262) != 1 or session.item_count(267) != 1:
		vm.free()
		return "第十章结束状态错误：scene=%s party=%s pos=%s music=%d poison_pearl=%d earth=%d messages=%s unsupported=%s" % [PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.party_world_position(), session.music_number, session.item_count(262), session.item_count(267), _messages, _unsupported]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int, require_reward: bool) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "蛤蟆山敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "蛤蟆山敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "蛤蟆山敌队 %d 没有完成真实胜利结算" % team_id
	if require_reward and (reward.experience <= 0 or reward.cash <= 0):
		return "蛤蟆山敌队 %d 没有产生真实胜利奖励" % team_id
	return ""


func _run_scene_enter(vm: ScriptVM, database: PalContentDatabase, scene_index: int) -> void:
	var scene := database.scenes[scene_index]
	var entry := scene.script_on_enter
	_run_stage(vm, entry)
	if not _next_entries.is_empty():
		scene.script_on_enter = _next_entries[-1]


func _run_event(vm: ScriptVM, event: PalEventObject) -> String:
	var entry := event.trigger_script
	_run_stage(vm, entry, event.object_id)
	_update_event_entry(event, entry)
	if not _unsupported.is_empty():
		return "事件 %d 出现未支持指令：%s" % [event.object_id, _unsupported]
	return ""


func _run_stage(vm: ScriptVM, root: int, event_object_id: int = 0) -> void:
	_clear_trace()
	vm.run_trigger(root, event_object_id)
	_drive_script(vm)


func _run_transition(vm: ScriptVM, event: PalEventObject, expected_scene: int, expected_position: Vector2i, check_position: bool = true) -> String:
	var failure := _run_event(vm, event)
	if not failure.is_empty():
		return failure
	if _requested_scenes != [expected_scene] or vm.session.scene_index != expected_scene:
		return "入口 %d 转场为 scenes=%s/%d，预期 %d" % [event.object_id, _requested_scenes, vm.session.scene_index, expected_scene]
	if check_position and vm.session.party_world_position() != expected_position:
		return "入口 %d 落点为 %s，预期 %s" % [event.object_id, vm.session.party_world_position(), expected_position]
	return ""


func _update_event_entry(event: PalEventObject, original_entry: int) -> void:
	if not _next_entries.is_empty():
		event.trigger_script = _next_entries[-1]
	elif event.trigger_script == 0:
		event.trigger_script = original_entry


func _clear_trace() -> void:
	_messages.clear()
	_requested_scenes.clear()
	_next_entries.clear()
	_unsupported.clear()
	_music_requests.clear()
	_battle_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 80000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		elif vm.waiting_for_confirmation:
			vm.complete_confirmation(true)
		elif vm.waiting_for_shop:
			vm.complete_shop()
		elif vm.waiting_for_key:
			vm.complete_key_wait()
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
