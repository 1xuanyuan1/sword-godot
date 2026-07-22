# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证无底深渊、南诏王宫秘道、假巫王双战与最终对质入口。
## 测试只比较消息编号、场景状态和敌队编组，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _battle_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_bottomless_palace_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 无底深渊、南诏王宫秘道、假巫王双战与最终对质入口主线完成")
	quit(0)


func _test_bottomless_palace_mainline(database: PalContentDatabase) -> String:
	# 从第十七章地魔兽战后的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 290
	session.party_roles = PackedInt32Array([1, 0, 4])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(240, 1672))
	session.music_number = 26
	session.battlefield_number = 58
	for item_id in [260, 263, 264, 265, 266, 267]:
		session.set_item_count(item_id, 1)
	database.scenes[290].script_on_enter = 3798

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 三层无底深渊的正式出口固定为 290→291→292；最深层北端直达王宫秘道。
	_run_scene_enter(vm, database, 290)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.music_number != 26 or session.battlefield_number != 58:
		vm.free()
		return "无底深渊入口环境错误：messages=%s music=%d field=%d unsupported=%s" % [_messages, session.music_number, session.battlefield_number, _unsupported]
	var failure := _run_transition(vm, database.event_objects[5221], 291, Vector2i(208, 1800))
	if not failure.is_empty():
		vm.free()
		return "无底深渊第一层出口错误：%s" % failure
	failure = _run_transition(vm, database.event_objects[5251], 292, Vector2i(240, 1736))
	if not failure.is_empty():
		vm.free()
		return "无底深渊第二层出口错误：%s" % failure
	_run_scene_enter(vm, database, 292)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.music_number != 26 or session.battlefield_number != 58:
		vm.free()
		return "无底深渊最深层环境错误：messages=%s music=%d field=%d unsupported=%s" % [_messages, session.music_number, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[5305], 278, Vector2i(1408, 704))
	if not failure.is_empty():
		vm.free()
		return "无底深渊没有抵达王宫秘道：%s" % failure
	_run_scene_enter(vm, database, 278)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.music_number != 32 or session.battlefield_number != 16:
		vm.free()
		return "王宫秘道入口环境错误：messages=%s music=%d field=%d unsupported=%s" % [_messages, session.music_number, session.battlefield_number, _unsupported]

	# 穿过秘道内、地牢迷宫和外殿，抵达王宫正殿及假巫王内殿。
	for transition in [
		[5006, 287, Vector2i(336, 392)],
		[5126, 286, Vector2i(912, 952)],
		[5106, 284, Vector2i(1008, 712)],
		[5063, 276, Vector2i(848, 1528)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0]) - 1], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "王宫秘道或地牢迷宫转场错误：%s" % failure
	_run_scene_enter(vm, database, 276)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.party_world_position() != Vector2i(848, 1528) or session.battlefield_number != 55:
		vm.free()
		return "南诏王宫外入口错误：messages=%s pos=%s field=%d unsupported=%s" % [_messages, session.party_world_position(), session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[4990], 280, Vector2i(1296, 1272))
	if not failure.is_empty():
		vm.free()
		return "王宫外没有进入正殿：%s" % failure
	failure = _run_transition(vm, database.event_objects[5050], 277, Vector2i(704, 1696))
	if not failure.is_empty():
		vm.free()
		return "王宫正殿没有进入假巫王内殿：%s" % failure

	# 假巫王剧情依次结算石长老幻影和假巫王本体两场 Boss。
	var story_event := database.event_objects[4997]
	var story_entry := story_event.trigger_script
	_clear_trace()
	vm.run_trigger(story_entry, story_event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(434, 480) or _battle_requests != [[289, 57, true]] or not vm.waiting_for_battle:
		var first_failure := "假巫王前置剧情或敌队 289 错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
		vm.free()
		return first_failure
	failure = _resolve_battle(database, session, 289, 57, PackedInt32Array([528, 528]), 289057)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(434, 493) or _battle_requests != [[289, 57, true], [222, 57, true]] or not vm.waiting_for_battle:
		var second_failure := "假巫王第二段剧情或敌队 222 错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
		vm.free()
		return second_failure
	failure = _resolve_battle(database, session, 222, 57, PackedInt32Array([462]), 222057)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(story_event, story_entry)
	if not _unsupported.is_empty() or vm.is_busy() or _messages != _message_range(434, 501) or session.party_roles != PackedInt32Array([0]) or session.party_world_position() != Vector2i(1424, 1144) or session.music_number != 34 or session.battle_music_number != 38:
		var aftermath_failure := "假巫王双战战后状态错误：messages=%s party=%s pos=%s music=%d battle_music=%d busy=%s unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), session.music_number, session.battle_music_number, vm.is_busy(), _unsupported]
		vm.free()
		return aftermath_failure
	if database.event_objects[4997].state != 0 or database.event_objects[5004].state != 2 or database.event_objects[5055].state != 1:
		vm.free()
		return "假巫王战后没有关闭旧入口并解锁最终对质：fake=%d witness=%d final=%d" % [database.event_objects[4997].state, database.event_objects[5004].state, database.event_objects[5055].state]

	# 战后内殿对象给出最后一句提示；返回正殿后应停在最终对质事件 5056 前。
	failure = _run_event(vm, database.event_objects[5004])
	if not failure.is_empty() or _messages != [502]:
		vm.free()
		return "假巫王战后提示错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[4992], 280, Vector2i(1664, 1456))
	if not failure.is_empty():
		vm.free()
		return "假巫王内殿没有返回王宫正殿：%s" % failure
	if database.event_objects[5055].trigger_script != 4231 or database.event_objects[5055].state != 1 or session.party_roles != PackedInt32Array([0]) or session.battlefield_number != 57:
		vm.free()
		return "最终对质入口不稳定：script=%d state=%d party=%s field=%d" % [database.event_objects[5055].trigger_script, database.event_objects[5055].state, session.party_roles, session.battlefield_number]
	for item_id in [260, 263, 264, 265, 266, 267]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "最终对质前灵珠 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed_value: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed_value, true):
		return "敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "敌队 %d 没有完成真实胜利结算" % team_id
	return ""


func _run_scene_enter(vm: ScriptVM, database: PalContentDatabase, scene_index: int) -> void:
	var scene := database.scenes[scene_index]
	var entry := scene.script_on_enter
	_run_stage(vm, entry, 0xffff)
	if not _next_entries.is_empty():
		scene.script_on_enter = _next_entries[-1]


func _run_event(vm: ScriptVM, event: PalEventObject) -> String:
	var entry := event.trigger_script
	_run_stage(vm, entry, event.object_id)
	_update_event_entry(event, entry)
	return "" if _unsupported.is_empty() else "事件 %d 出现未支持指令：%s" % [event.object_id, _unsupported]


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
	_battle_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 240000:
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
