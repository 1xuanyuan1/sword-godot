# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证黑水镇、玉佛珠封锁、将军冢双 Boss、土灵珠与返回白河村。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _music_requests: Array = []
var _sound_requests: Array[int] = []
var _battle_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_blackwater_tomb_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 黑水镇、玉佛珠封锁、鬼将军／赤鬼王、土灵珠及返回白河村主线完成")
	quit(0)


func _test_blackwater_tomb_mainline(database: PalContentDatabase) -> String:
	# 从玉佛寺清空版的一次性进入脚本结束状态继续，玉佛珠尚在背包且未装备。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 56
	session.party_roles = PackedInt32Array([0, 1, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1184, 560))
	session.music_number = 78
	session.set_item_count(274, 1)
	database.event_objects[926].trigger_script = 14107

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.sound_requested.connect(func(number: int) -> void: _sound_requests.append(number))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 从清空后的玉佛寺返回后山，向北进入黑水镇、乱葬岗荒野和墓地。
	var failure := _run_transition(vm, database.event_objects[944], 53, Vector2i(416, 544))
	if not failure.is_empty():
		vm.free()
		return "清空版玉佛寺返回后山失败：%s" % failure
	_run_stage(vm, database.scenes[53].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [15514] or _music_requests != [[78, true, 0.0]] or session.battlefield_number != 8:
		vm.free()
		return "白河村后山重入状态不正确：next=%s music=%s field=%d unsupported=%s" % [_next_entries, _music_requests, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[924], 60, Vector2i(1312, 1376))
	if not failure.is_empty():
		vm.free()
		return "白河村后山进入黑水镇失败：%s" % failure
	_run_stage(vm, database.scenes[60].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [16913] or _music_requests != [[60, true, 0.0]] or session.battlefield_number != 20 or session.battle_music_number != 40:
		vm.free()
		return "黑水镇进入状态不正确：next=%s music=%s field=%d battle_music=%d unsupported=%s" % [_next_entries, _music_requests, session.battlefield_number, session.battle_music_number, _unsupported]
	# 镇内对象 1215 的真实宝箱提供返程所需引路蜂，不能在进入血池后凭空注入。
	var guide_bee_chest := database.event_objects[1214]
	_run_stage(vm, guide_bee_chest.trigger_script, guide_bee_chest.object_id)
	if not _unsupported.is_empty() or _messages != [161] or _next_entries != [887] or session.item_count(151) != 1:
		vm.free()
		return "黑水镇宝箱没有取得引路蜂：messages=%s next=%s bee=%d unsupported=%s" % [_messages, _next_entries, session.item_count(151), _unsupported]
	guide_bee_chest.trigger_script = _next_entries[0]
	failure = _run_transition(vm, database.event_objects[1200], 62, Vector2i(1840, 1896))
	if not failure.is_empty():
		vm.free()
		return "黑水镇进入乱葬岗荒野失败：%s" % failure
	_run_stage(vm, database.scenes[62].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [16917] or session.battlefield_number != 29:
		vm.free()
		return "乱葬岗荒野进入状态不正确：next=%s field=%d unsupported=%s" % [_next_entries, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[1230], 63, Vector2i(416, 1840))
	if not failure.is_empty():
		vm.free()
		return "乱葬岗荒野进入墓地失败：%s" % failure
	_run_stage(vm, database.scenes[63].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [16919] or _music_requests != [[60, true, 0.0]] or session.battlefield_number != 50:
		vm.free()
		return "乱葬岗墓地进入状态不正确：next=%s music=%s field=%d unsupported=%s" % [_next_entries, _music_requests, session.battlefield_number, _unsupported]

	# 原始脚本 0086 的数量操作数为 0，但仍必须装备一件玉佛珠；未装备时会被尸妖逼退。
	var tomb_gate := database.event_objects[1250]
	var barrier := database.event_objects[1251]
	_run_stage(vm, tomb_gate.trigger_script, tomb_gate.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4927, 4928) or _next_entries != [16393] or barrier.state != 1 or session.equipped_item_count(274) != 0:
		vm.free()
		return "未装备玉佛珠时没有被墓地封锁：messages=%s next=%s barrier=%d equipped=%d unsupported=%s" % [_messages, _next_entries, barrier.state, session.equipped_item_count(274), _unsupported]
	var equipment_manager := PalEquipmentManager.new()
	if not equipment_manager.configure(database, session) or not equipment_manager.equip_item(274, 1):
		vm.free()
		return "赵灵儿无法装备玉佛珠：%s" % equipment_manager.error_message
	if session.item_count(274) != 0 or session.equipped_item_count(274) != 1:
		vm.free()
		return "玉佛珠没有从背包进入赵灵儿装备：bag=%d equipped=%d" % [session.item_count(274), session.equipped_item_count(274)]
	_run_stage(vm, tomb_gate.trigger_script, tomb_gate.object_id)
	if not _unsupported.is_empty() or not _messages.is_empty() or _next_entries != [16271] or barrier.state != 0:
		vm.free()
		return "装备玉佛珠后没有解除墓地封锁：messages=%s next=%s barrier=%d unsupported=%s" % [_messages, _next_entries, barrier.state, _unsupported]
	tomb_gate.trigger_script = _next_entries[0]
	failure = _run_transition(vm, tomb_gate, 59, Vector2i(1360, 1528))
	if not failure.is_empty():
		vm.free()
		return "墓地入口没有进入将军冢上层：%s" % failure
	_run_stage(vm, database.scenes[59].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [16907] or _music_requests != [[78, true, 0.0]] or session.battlefield_number != 34 or session.battle_music_number != 40:
		vm.free()
		return "将军冢上层进入状态不正确：next=%s music=%s field=%d battle_music=%d unsupported=%s" % [_next_entries, _music_requests, session.battlefield_number, session.battle_music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[1126], 64, Vector2i(1232, 1160))
	if not failure.is_empty():
		vm.free()
		return "将军冢上层进入下层失败：%s" % failure

	# 鬼将军使用真实敌队 26／战场 18；胜利后切入坠落演出并抵达血池。
	_clear_trace()
	var ghost_general := database.event_objects[1352]
	vm.run_trigger(ghost_general.trigger_script, ghost_general.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != [4929] or _battle_requests != [[26, 18, true]] or not vm.waiting_for_battle:
		vm.free()
		return "鬼将军战入口不正确：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	failure = _resolve_battle(database, session, 26, 18, PackedInt32Array([472]), 26018)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _requested_scenes != [65] or session.scene_index != 65 or _next_entries != [16550] or ghost_general.state != 0:
		vm.free()
		return "鬼将军胜利后没有切入坠落场景：scenes=%s/%d next=%s boss=%d unsupported=%s" % [_requested_scenes, session.scene_index, _next_entries, ghost_general.state, _unsupported]
	_run_stage(vm, database.scenes[65].script_on_enter)
	if not _unsupported.is_empty() or _requested_scenes != [58] or session.scene_index != 58 or _next_entries != [16573] or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "将军冢坠落演出没有抵达血池：scenes=%s/%d next=%s party=%s unsupported=%s" % [_requested_scenes, session.scene_index, _next_entries, session.party_roles, _unsupported]
	if database.event_objects[1407].state != 0 or database.event_objects[1408].state != 0 or database.event_objects[1409].state != 0:
		vm.free()
		return "坠落演出的三名队员 EventObject 没有清理"
	_run_stage(vm, database.scenes[58].script_on_enter)
	if not _unsupported.is_empty() or _messages != _message_range(4930, 4940) or _next_entries != [16649] or _music_requests != [[83, true, 0.0]]:
		vm.free()
		return "血池坠落后会合剧情不完整：messages=%s next=%s music=%s unsupported=%s" % [_messages, _next_entries, _music_requests, _unsupported]
	if session.party_roles != PackedInt32Array([0, 1, 2]) or session.party_world_position() != Vector2i(1760, 1792) or session.battlefield_number != 32 or database.player_roles.scene_sprite_numbers[0] != 2:
		vm.free()
		return "血池会合后的队伍状态错误：party=%s pos=%s field=%d sprite=%d" % [session.party_roles, session.party_world_position(), session.battlefield_number, database.player_roles.scene_sprite_numbers[0]]

	# 赤鬼王使用敌队 27／战场 19；战前清除尸妖，战后取得土灵珠并开放血池传送脚本。
	_clear_trace()
	var red_ghost := database.event_objects[1053]
	vm.run_trigger(red_ghost.trigger_script, red_ghost.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4943, 4956) or _battle_requests != [[27, 19, true]] or not vm.waiting_for_battle:
		vm.free()
		return "赤鬼王战入口不正确：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	if database.event_objects[1205].state != 0 or database.event_objects[1232].state != 0 or database.event_objects[1253].state != 0:
		vm.free()
		return "赤鬼王战前没有清除黑水镇／乱葬岗尸妖"
	failure = _resolve_battle(database, session, 27, 19, PackedInt32Array([473]), 27019)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4943, 4982) or _next_entries != [16763] or session.item_count(267) != 1:
		vm.free()
		return "赤鬼王胜利、土灵珠或战后剧情不完整：messages=%s next=%s pearl=%d unsupported=%s" % [_messages, _next_entries, session.item_count(267), _unsupported]
	if red_ghost.state != 0 or database.scenes[58].script_on_teleport != 16277 or session.music_number != 30 or session.battlefield_number != 32 or session.battle_music_number != 39:
		vm.free()
		return "赤鬼王战后稳定状态错误：boss=%d teleport=%d music=%d field=%d battle_music=%d" % [red_ghost.state, database.scenes[58].script_on_teleport, session.music_number, session.battlefield_number, session.battle_music_number]

	# 血池没有普通出口；使用真实引路蜂脚本 0038 调用刚开放的场景传送，再原路返回白河村。
	var guide_bee := database.item_definition(151)
	_run_stage(vm, guide_bee.script_on_use, 0xffff)
	if not _unsupported.is_empty() or not vm.script_success or _requested_scenes != [63] or session.scene_index != 63 or session.party_world_position() != Vector2i(608, 240) or _sound_requests != [45]:
		vm.free()
		return "引路蜂没有从血池传送到墓地：scenes=%s/%d pos=%s sound=%s success=%s unsupported=%s" % [_requested_scenes, session.scene_index, session.party_world_position(), _sound_requests, vm.script_success, _unsupported]
	if guide_bee.is_consuming():
		session.change_item_count(151, -1)
	_run_stage(vm, database.scenes[63].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1249], 62, Vector2i(1568, 288))
	if not failure.is_empty():
		vm.free()
		return "墓地返回乱葬岗荒野失败：%s" % failure
	_run_stage(vm, database.scenes[62].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1229], 60, Vector2i(192, 464))
	if not failure.is_empty():
		vm.free()
		return "乱葬岗荒野返回黑水镇失败：%s" % failure
	_run_stage(vm, database.scenes[60].script_on_enter)
	failure = _run_transition(vm, database.event_objects[1199], 53, Vector2i(1376, 320))
	if not failure.is_empty():
		vm.free()
		return "黑水镇返回白河村后山失败：%s" % failure
	_run_stage(vm, database.scenes[53].script_on_enter)
	failure = _run_transition(vm, database.event_objects[923], 48, Vector2i(720, 504))
	if not failure.is_empty():
		vm.free()
		return "白河村后山返回村内失败：%s" % failure
	_run_stage(vm, database.scenes[48].script_on_enter)
	failure = _run_transition(vm, database.event_objects[802], 51, Vector2i(416, 1264))
	if not failure.is_empty():
		vm.free()
		return "白河村返回韩医仙屋外失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[885], 52, Vector2i(1280, 880))
	if not failure.is_empty():
		vm.free()
		return "韩医仙屋外返回诊厅失败：%s" % failure

	# 赤鬼王脚本已把诊厅对象 907 打开；对话后确认灵儿被掳走，作为下一章稳定入口。
	var messenger := database.event_objects[906]
	_run_stage(vm, messenger.trigger_script, messenger.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4405, 4425) or _next_entries != [15167] or messenger.state != 0 or database.event_objects[907].state != 2:
		vm.free()
		return "返回白河村后的灵儿被掳剧情不完整：messages=%s next=%s messenger=%d followup=%d unsupported=%s" % [_messages, _next_entries, messenger.state, database.event_objects[907].state, _unsupported]
	if session.scene_index != 52 or session.party_roles != PackedInt32Array([0, 1, 2]) or session.item_count(267) != 1 or session.equipped_item_count(274) != 1 or session.item_count(151) != 0:
		vm.free()
		return "第七章结束状态错误：scene=%d party=%s earth=%d jade=%d bee=%d" % [session.scene_index, session.party_roles, session.item_count(267), session.equipped_item_count(274), session.item_count(151)]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "将军冢敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "将军冢敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null or reward.experience <= 0 or reward.cash <= 0:
		return "将军冢敌队 %d 没有产生真实胜利奖励" % team_id
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
	_sound_requests.clear()
	_battle_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 50000:
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
