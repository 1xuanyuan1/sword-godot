# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证灵儿被掳、鬼阴山守卫、石长老剧情及抵达扬州前山道。
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
	var failure := _test_ghost_mountain_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 灵儿被掳、鬼阴山守卫、石长老剧情及抵达扬州前山道主线完成")
	quit(0)


func _test_ghost_mountain_mainline(database: PalContentDatabase) -> String:
	# 从赤鬼王返程并得知灵儿被掳后的稳定诊厅状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 52
	session.party_roles = PackedInt32Array([0, 1, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1280, 880))
	session.set_item_count(267, 1)
	session.set_item_count(274, 1)
	var equipment_manager := PalEquipmentManager.new()
	if not equipment_manager.configure(database, session) or not equipment_manager.equip_item(274, 1):
		return "无法恢复赵灵儿已装备玉佛珠状态：%s" % equipment_manager.error_message
	database.event_objects[905].state = 0
	database.event_objects[906].state = 0
	database.event_objects[907].state = 2
	database.event_objects[907].trigger_script = 15209
	database.event_objects[813].state = 0
	database.event_objects[934].trigger_script = 15212
	database.event_objects[935].trigger_script = 15212

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 沿诊厅、韩医仙屋外、白河村和后山正式入口抵达鬼阴山守卫处。
	var failure := _run_transition(vm, database.event_objects[903], 51, Vector2i(896, 832))
	if not failure.is_empty():
		vm.free()
		return "诊厅返回韩医仙屋外失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[884], 48, Vector2i(1600, 720))
	if not failure.is_empty():
		vm.free()
		return "韩医仙屋外返回白河村失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[801], 53, Vector2i(1056, 1792))
	if not failure.is_empty():
		vm.free()
		return "白河村进入后山失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[925], 54, Vector2i(1728, 1488))
	if not failure.is_empty():
		vm.free()
		return "后山进入鬼阴山前路失败：%s" % failure
	_run_stage(vm, database.scenes[54].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [15512] or session.battlefield_number != 2:
		vm.free()
		return "鬼阴山前路进入状态错误：next=%s field=%d unsupported=%s" % [_next_entries, session.battlefield_number, _unsupported]

	# 两名守卫共用剧情入口，敌队 33／战场 52 胜利后同时离场。
	_clear_trace()
	var guard := database.event_objects[934]
	vm.run_trigger(guard.trigger_script, guard.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4428, 4442) or _battle_requests != [[33, 52, true]] or not vm.waiting_for_battle:
		vm.free()
		return "鬼阴山守卫战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	failure = _resolve_battle(database, session, 33, 52, PackedInt32Array([527, 454]), 33052)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _next_entries != [15212] or database.event_objects[934].state != 0 or database.event_objects[935].state != 0:
		vm.free()
		return "鬼阴山守卫胜利后没有清理入口：next=%s guards=%d/%d unsupported=%s" % [_next_entries, database.event_objects[934].state, database.event_objects[935].state, _unsupported]

	# 穿过前路、迷宫和绝顶，进入鬼阴坛密谋场景。
	failure = _run_transition(vm, database.event_objects[933], 69, Vector2i(1632, 720))
	if not failure.is_empty():
		vm.free()
		return "鬼阴山前路进入迷宫失败：%s" % failure
	_run_stage(vm, database.scenes[69].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1454], 67, Vector2i(1696, 1728))
	if not failure.is_empty():
		vm.free()
		return "鬼阴山迷宫进入山路失败：%s" % failure
	_run_stage(vm, database.scenes[67].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1442], 68, Vector2i(560, 1848))
	if not failure.is_empty():
		vm.free()
		return "鬼阴山山路进入绝顶失败：%s" % failure
	_run_stage(vm, database.scenes[68].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1446], 75, Vector2i(976, 1880))
	if not failure.is_empty():
		vm.free()
		return "鬼阴山绝顶进入石室失败：%s" % failure
	_run_stage(vm, database.scenes[75].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1502], 66, Vector2i(816, 1704))
	if not failure.is_empty():
		vm.free()
		return "鬼阴坛石室进入密谋场景失败：%s" % failure
	_run_stage(vm, database.scenes[66].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [17333] or _music_requests != [[19, true, 0.0]] or session.battlefield_number != 16 or session.battle_music_number != 39:
		vm.free()
		return "鬼阴坛密谋场景进入状态错误：next=%s music=%s field=%d battle_music=%d unsupported=%s" % [_next_entries, _music_requests, session.battlefield_number, session.battle_music_number, _unsupported]

	# 石长老剧情战使用敌队 34／战场 16；胜利后玉佛珠被剧情卸下并带走赵灵儿。
	_clear_trace()
	var elder_event := database.event_objects[1413]
	vm.run_trigger(elder_event.trigger_script, elder_event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4983, 4984) or _battle_requests != [[34, 16, true]] or not vm.waiting_for_battle:
		vm.free()
		return "石长老战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	failure = _resolve_battle(database, session, 34, 16, PackedInt32Array([527, 496, 527]), 34016)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4983, 5048) or _requested_scenes != [76] or session.scene_index != 76 or _next_entries != [17062]:
		vm.free()
		return "石长老战后长剧情或场景切换错误：messages=%s scenes=%s/%d next=%s unsupported=%s" % [_messages, _requested_scenes, session.scene_index, _next_entries, _unsupported]
	if session.party_roles != PackedInt32Array([0]) or session.item_count(274) != 0 or session.equipped_item_count(274) != 0 or session.item_count(267) != 1:
		vm.free()
		return "石长老战后队伍或灵珠状态错误：party=%s jade=%d/%d earth=%d" % [session.party_roles, session.item_count(274), session.equipped_item_count(274), session.item_count(267)]

	# 得救场景让林月如归队并恢复李逍遥造型，随后由后门抵达扬州前山道。
	_run_stage(vm, database.scenes[76].script_on_enter)
	if not _unsupported.is_empty() or _messages != _message_range(5050, 5080) or _next_entries != [17318]:
		vm.free()
		return "鬼阴坛得救剧情不完整：messages=%s next=%s unsupported=%s" % [_messages, _next_entries, _unsupported]
	if session.party_roles != PackedInt32Array([0, 2]) or session.party_world_position() != Vector2i(1216, 976) or database.player_roles.scene_sprite_numbers[0] != 2:
		vm.free()
		return "鬼阴坛得救后的队伍状态错误：party=%s pos=%s sprite=%d" % [session.party_roles, session.party_world_position(), database.player_roles.scene_sprite_numbers[0]]
	failure = _run_transition(vm, database.event_objects[1561], 77, Vector2i(416, 1056))
	if not failure.is_empty():
		vm.free()
		return "鬼阴坛得救场景进入后门失败：%s" % failure
	_run_stage(vm, database.scenes[77].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1571], 79, Vector2i(288, 448))
	if not failure.is_empty():
		vm.free()
		return "鬼阴坛后门进入山道失败：%s" % failure
	_run_stage(vm, database.scenes[79].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1581], 82, Vector2i(224, 848))
	if not failure.is_empty():
		vm.free()
		return "鬼阴山后山道没有抵达扬州前山道：%s" % failure
	if PalSceneCatalog.name_for_scene_index(session.scene_index) != "山道·扬州前" or session.party_roles != PackedInt32Array([0, 2]) or session.item_count(267) != 1:
		vm.free()
		return "第八章结束状态错误：scene=%s party=%s earth=%d" % [PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.item_count(267)]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "鬼阴山敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "鬼阴山敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null or reward.experience <= 0 or reward.cash <= 0:
		return "鬼阴山敌队 %d 没有产生真实胜利奖励" % team_id
	return ""


func _run_stage(vm: ScriptVM, root: int, event_object_id: int = 0) -> void:
	_clear_trace()
	vm.run_trigger(root, event_object_id)
	_drive_script(vm)


func _run_transition(vm: ScriptVM, event: PalEventObject, expected_scene: int, expected_position: Vector2i) -> String:
	_run_stage(vm, event.trigger_script, event.object_id)
	if not _unsupported.is_empty():
		return "入口 %d 出现未支持指令：%s" % [event.object_id, _unsupported]
	if _requested_scenes != [expected_scene] or vm.session.scene_index != expected_scene or vm.session.party_world_position() != expected_position:
		return "入口 %d 转场为 scenes=%s/%d pos=%s，预期 %d %s" % [event.object_id, _requested_scenes, vm.session.scene_index, vm.session.party_world_position(), expected_scene, expected_position]
	return ""


func _clear_trace() -> void:
	_messages.clear()
	_requested_scenes.clear()
	_next_entries.clear()
	_unsupported.clear()
	_music_requests.clear()
	_battle_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 60000:
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
