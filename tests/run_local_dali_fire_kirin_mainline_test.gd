# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证大理族议、火麒麟、女娲神殿与进入回魂仙梦主线。
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
	var failure := _test_dali_fire_kirin_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 大理族议、火麒麟、火灵珠／麒麟角与进入回魂仙梦主线完成")
	quit(0)


func _test_dali_fire_kirin_mainline(database: PalContentDatabase) -> String:
	# 从神木林树洞后抵达大理的稳定状态继续；蛋壳必须留给回魂仙梦返回后的真实脚本。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 205
	session.party_roles = PackedInt32Array([0, 4])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(352, 1744))
	for item_id in [186, 262, 263, 264, 267, 274]:
		session.set_item_count(item_id, 1)
	database.scenes[205].script_on_enter = 33031

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 大理入口先建立场景音乐和战场，再进入族议厅推进黑白苗争端。
	_run_scene_enter(vm, database, 205)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.music_number != 55 or session.battlefield_number != 20:
		vm.free()
		return "大理入口状态错误：messages=%s music=%d field=%d unsupported=%s" % [_messages, session.music_number, session.battlefield_number, _unsupported]
	var failure := _run_transition(vm, database.event_objects[3671], 204, Vector2i(1488, 1592))
	if not failure.is_empty():
		vm.free()
		return "大理没有进入族议厅：%s" % failure
	failure = _run_event(vm, database.event_objects[3652])
	if not failure.is_empty() or _messages != _message_range(10945, 11056) or session.party_roles != PackedInt32Array([4]) or database.event_objects[3652].trigger_script != 33874:
		vm.free()
		return "族议长剧情状态错误：failure=%s messages=%s party=%s next=%d" % [failure, _messages, session.party_roles, database.event_objects[3652].trigger_script]
	failure = _run_event(vm, database.event_objects[3653])
	if not failure.is_empty() or _messages != _message_range(11057, 11073) or _requested_scenes != [205] or session.scene_index != 205 or session.party_roles != PackedInt32Array([4, 0]) or database.scenes[205].script_on_enter != 34113:
		vm.free()
		return "族议结束或返回大理状态错误：failure=%s messages=%s scenes=%s/%d party=%s enter=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.party_roles, database.scenes[205].script_on_enter]
	_run_scene_enter(vm, database, 205)
	if not _unsupported.is_empty() or _messages != _message_range(11187, 11191) or session.party_world_position() != Vector2i(496, 296) or database.scenes[205].script_on_enter != 34128:
		vm.free()
		return "族议后大理入口续跑错误：messages=%s pos=%s enter=%d unsupported=%s" % [_messages, session.party_world_position(), database.scenes[205].script_on_enter, _unsupported]

	# 从大理东侧进入火麒麟洞，沿主通道抵达最深处。
	failure = _run_transition(vm, database.event_objects[3681], 211, Vector2i(272, 1608))
	if not failure.is_empty():
		vm.free()
		return "大理没有进入火麒麟洞：%s" % failure
	_run_scene_enter(vm, database, 211)
	if not _unsupported.is_empty() or session.music_number != 83 or session.battle_music_number != 38 or session.battlefield_number != 19:
		vm.free()
		return "火麒麟洞音乐或战场错误：music=%d battle_music=%d field=%d unsupported=%s" % [session.music_number, session.battle_music_number, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[3796], 199, Vector2i(1728, 1296))
	if not failure.is_empty():
		vm.free()
		return "火麒麟洞没有抵达最深处：%s" % failure
	_run_scene_enter(vm, database, 199)
	if not _unsupported.is_empty() or session.music_number != 83 or session.battlefield_number != 19:
		vm.free()
		return "火麒麟战前场景状态错误：music=%d field=%d unsupported=%s" % [session.music_number, session.battlefield_number, _unsupported]

	# 火麒麟使用真实敌队、战场与对象；胜利后取得火灵珠和火眼麒麟角。
	failure = _run_battle_event(vm, database, database.event_objects[3542], 224, 19, PackedInt32Array([463]), 224019)
	if not failure.is_empty():
		vm.free()
		return "火麒麟剧情战错误：%s" % failure
	if _messages != _message_range(11192, 11318) or session.item_count(266) != 1 or session.item_count(276) != 1 or session.item_count(275) != 0 or session.party_roles != PackedInt32Array([4, 0]) or database.event_objects[3615].trigger_script != 34491 or database.event_objects[3669].trigger_script != 34728:
		vm.free()
		return "火麒麟战后道具或后续入口错误：messages=%s fire=%d horn=%d egg=%d party=%s temple=%d exit=%d" % [_messages, session.item_count(266), session.item_count(276), session.item_count(275), session.party_roles, database.event_objects[3615].trigger_script, database.event_objects[3669].trigger_script]

	# 原路离洞，进入女娲神殿；神殿长剧情把李逍遥送入回魂仙梦。
	failure = _run_transition(vm, database.event_objects[3541], 211, Vector2i(656, 456))
	if not failure.is_empty():
		vm.free()
		return "火麒麟战后没有返回洞窟：%s" % failure
	failure = _run_transition(vm, database.event_objects[3797], 205, Vector2i(1664, 864))
	if not failure.is_empty():
		vm.free()
		return "火麒麟洞没有返回大理：%s" % failure
	failure = _run_transition(vm, database.event_objects[3672], 210, Vector2i(560, 1272))
	if not failure.is_empty():
		vm.free()
		return "大理没有进入女娲神殿外：%s" % failure
	_run_scene_enter(vm, database, 210)
	if not _unsupported.is_empty() or session.music_number != 55:
		vm.free()
		return "女娲神殿外入口状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[3792], 202, Vector2i(288, 1392))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿外没有进入神殿：%s" % failure
	_run_scene_enter(vm, database, 202)
	if not _unsupported.is_empty() or session.music_number != 16:
		vm.free()
		return "女娲神殿入口状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_event(vm, database.event_objects[3615])
	if not failure.is_empty() or _messages != _message_range(11370, 11418) or _requested_scenes != [200] or session.scene_index != 200 or session.party_roles != PackedInt32Array([0]) or database.event_objects[3615].trigger_script != 34601 or database.event_objects[3669].trigger_script != 33047:
		vm.free()
		return "女娲神殿长剧情、梦境入口或大理出口恢复错误：failure=%s messages=%s scenes=%s/%d party=%s next=%d exit=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.party_roles, database.event_objects[3615].trigger_script, database.event_objects[3669].trigger_script]
	_run_scene_enter(vm, database, 200)
	if not _unsupported.is_empty() or _messages != _message_range(11485, 11513) or _requested_scenes != [226] or PalSceneCatalog.name_for_scene_index(session.scene_index) != "路途·回魂仙梦" or session.party_roles != PackedInt32Array([0]) or session.party_world_position() != Vector2i(896, 832) or session.music_number != 59 or session.item_count(266) != 1 or session.item_count(276) != 1 or session.item_count(275) != 0:
		vm.free()
		return "第十四章结束状态错误：messages=%s scenes=%s scene=%s party=%s pos=%s music=%d fire=%d horn=%d egg=%d unsupported=%s" % [_messages, _requested_scenes, PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.party_world_position(), session.music_number, session.item_count(266), session.item_count(276), session.item_count(275), _unsupported]
	for item_id in [186, 262, 263, 264, 267, 274]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "进入回魂仙梦前关键物品 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
	vm.free()
	return ""


func _run_battle_event(vm: ScriptVM, database: PalContentDatabase, event: PalEventObject, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var entry := event.trigger_script
	_clear_trace()
	vm.run_trigger(entry, event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[team_id, field_id, true]] or not vm.waiting_for_battle:
		return "敌队 %d 入口错误：battles=%s waiting=%s unsupported=%s" % [team_id, _battle_requests, vm.waiting_for_battle, _unsupported]
	var failure := _resolve_battle(database, vm.session, team_id, field_id, expected_objects, seed)
	if not failure.is_empty():
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(event, entry)
	if not _unsupported.is_empty():
		return "敌队 %d 战后出现未支持指令：%s" % [team_id, _unsupported]
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "火麒麟敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "火麒麟敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "火麒麟敌队 %d 没有完成真实胜利结算" % team_id
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


func _run_transition(vm: ScriptVM, event: PalEventObject, expected_scene: int, expected_position: Vector2i) -> String:
	var failure := _run_event(vm, event)
	if not failure.is_empty():
		return failure
	if _requested_scenes != [expected_scene] or vm.session.scene_index != expected_scene:
		return "入口 %d 转场为 scenes=%s/%d，预期 %d" % [event.object_id, _requested_scenes, vm.session.scene_index, expected_scene]
	if vm.session.party_world_position() != expected_position:
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
	while vm.is_busy() and not vm.waiting_for_battle and guard < 160000:
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
