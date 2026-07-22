# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证圣姑住处、神木林、金翅凤凰、树洞与抵达大理主线。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
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
	var failure := _test_shenggu_sacred_tree_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 圣姑住处、神木林、金翅凤凰、树洞与抵达大理主线完成")
	quit(0)


func _test_shenggu_sacred_tree_mainline(database: PalContentDatabase) -> String:
	# DATA 升级表是本章开始时检查李逍遥仙术顺序的真实依据。
	var level_7_magics := database.level_progression.magic_objects_for_level(0, 7)
	var level_12_magics := database.level_progression.magic_objects_for_level(0, 12)
	var level_13_magics := database.level_progression.magic_objects_for_level(0, 13)
	if 349 not in level_7_magics or 346 in level_12_magics or 346 not in level_13_magics:
		return "李逍遥升级仙术顺序错误：level7=%s level12=%s level13=%s" % [level_7_magics, level_12_magics, level_13_magics]

	# 从第十二章结束的稳定状态继续；场景进入脚本已被月如往事与剑圣黯离改写为 32359。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 173
	session.party_roles = PackedInt32Array([0])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(528, 488))
	for item_id in [262, 264, 267, 274, 186]:
		session.set_item_count(item_id, 1)
	database.scenes[173].script_on_enter = 32359

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 房内两名伤者保持可检查状态；从房门抵达圣姑室外。
	var failure := _run_event(vm, database.event_objects[3023])
	if not failure.is_empty() or _messages != [10513]:
		vm.free()
		return "月如状态检查错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_event(vm, database.event_objects[3026])
	if not failure.is_empty() or _messages != [10514]:
		vm.free()
		return "灵儿状态检查错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[3022], 175, Vector2i(1424, 712))
	if not failure.is_empty():
		vm.free()
		return "圣姑房内没有抵达室外：%s" % failure
	_run_scene_enter(vm, database, 175)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[175].script_on_enter != 33027:
		vm.free()
		return "圣姑室外稳定入口错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[175].script_on_enter, _unsupported]

	# 正式路线由圣姑室外直达神木林底层，再进入 191 号迷宫与 184 号凤凰巢。
	failure = _run_transition(vm, database.event_objects[3069], 185, Vector2i(1808, 1160))
	if not failure.is_empty():
		vm.free()
		return "圣姑室外没有抵达神木林底层：%s" % failure
	_run_scene_enter(vm, database, 185)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[185].script_on_enter != 32084:
		vm.free()
		return "神木林底层入口错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[185].script_on_enter, _unsupported]
	failure = _run_transition(vm, database.event_objects[3297], 191, Vector2i(1488, 1512))
	if not failure.is_empty():
		vm.free()
		return "神木林底层没有进入主迷宫：%s" % failure
	_run_scene_enter(vm, database, 191)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[191].script_on_enter != 32088:
		vm.free()
		return "神木林主迷宫入口错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[191].script_on_enter, _unsupported]
	failure = _run_transition(vm, database.event_objects[3478], 184, Vector2i(912, 1352))
	if not failure.is_empty():
		vm.free()
		return "神木林主迷宫没有进入凤凰巢：%s" % failure
	_run_scene_enter(vm, database, 184)
	if not _unsupported.is_empty() or not _messages.is_empty():
		vm.free()
		return "凤凰巢稳定入口错误：messages=%s unsupported=%s" % [_messages, _unsupported]

	# 金翅凤凰使用真实敌队、战场与敌人对象；胜利后取得风灵珠并坠落到废神木林。
	failure = _run_battle_event(vm, database, database.event_objects[3273], 203, 14, PackedInt32Array([464]), 203014)
	if not failure.is_empty():
		vm.free()
		return "金翅凤凰剧情战错误：%s" % failure
	if _messages != _message_range(9822, 9847) or _requested_scenes != [187] or session.scene_index != 187 or session.party_world_position() != Vector2i(256, 496) or session.item_count(263) != 1 or database.event_objects[3273].state != 0 or database.event_objects[3273].trigger_script != 30718:
		vm.free()
		return "凤凰战后风灵珠或坠落状态错误：messages=%s scenes=%s/%d pos=%s wind=%d event=%d/%d" % [_messages, _requested_scenes, session.scene_index, session.party_world_position(), session.item_count(263), database.event_objects[3273].state, database.event_objects[3273].trigger_script]

	# 阿奴救醒李逍遥并说明蛋壳条件，之后按原版以队首身份加入。
	_run_scene_enter(vm, database, 187)
	if not _unsupported.is_empty() or _messages != _message_range(9848, 9921) or session.scene_index != 187 or session.party_roles != PackedInt32Array([4, 0]) or session.party_world_position() != Vector2i(544, 1440) or database.scenes[187].script_on_enter != 30996:
		vm.free()
		return "阿奴会合后的稳定状态错误：messages=%s scene=%d party=%s pos=%s enter=%d unsupported=%s" % [_messages, session.scene_index, session.party_roles, session.party_world_position(), database.scenes[187].script_on_enter, _unsupported]
	for item_id in [262, 263, 264, 267, 274, 186]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "阿奴会合后关键物品 %d 数量错误：%d" % [item_id, session.item_count(item_id)]

	# 与阿奴进入隐密树洞；入口长剧情后，深处事件把队伍顺序恢复为李逍遥／阿奴。
	failure = _run_transition(vm, database.event_objects[3320], 183, Vector2i(320, 624))
	if not failure.is_empty():
		vm.free()
		return "废神木林没有进入隐密树洞：%s" % failure
	_run_scene_enter(vm, database, 183)
	if not _unsupported.is_empty() or _messages != _message_range(9922, 9940) or session.party_roles != PackedInt32Array([4, 0]) or session.party_world_position() != Vector2i(336, 616) or database.scenes[183].script_on_enter != 31041:
		vm.free()
		return "树洞入口剧情状态错误：messages=%s party=%s pos=%s enter=%d unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), database.scenes[183].script_on_enter, _unsupported]
	failure = _run_event(vm, database.event_objects[3166])
	if not failure.is_empty() or _messages != _message_range(9941, 10023) or session.party_roles != PackedInt32Array([0, 4]) or session.party_world_position() != Vector2i(752, 1032) or database.event_objects[3166].trigger_script != 31045:
		vm.free()
		return "树洞深处剧情或队伍换序错误：failure=%s messages=%s party=%s pos=%s event=%d" % [failure, _messages, session.party_roles, session.party_world_position(), database.event_objects[3166].trigger_script]

	# 从树洞另一端返回神木林底层，经灵山抵达大理城郊和汉人聚居地。
	failure = _run_transition(vm, database.event_objects[3163], 186, Vector2i(384, 1248))
	if not failure.is_empty():
		vm.free()
		return "树洞深处没有抵达出口区域：%s" % failure
	_run_scene_enter(vm, database, 186)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[186].script_on_enter != 32091:
		vm.free()
		return "树洞出口区域状态错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[186].script_on_enter, _unsupported]
	failure = _run_transition(vm, database.event_objects[3315], 185, Vector2i(224, 1408))
	if not failure.is_empty():
		vm.free()
		return "树洞出口没有返回神木林底层：%s" % failure
	_run_scene_enter(vm, database, 185)
	if not _unsupported.is_empty() or not _messages.is_empty():
		vm.free()
		return "返回神木林底层时出现额外剧情：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_transition(vm, database.event_objects[3296], 178, Vector2i(1664, 1440))
	if not failure.is_empty():
		vm.free()
		return "神木林底层没有进入灵山：%s" % failure
	_run_scene_enter(vm, database, 178)
	if not _unsupported.is_empty() or not _messages.is_empty():
		vm.free()
		return "灵山入口状态错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_transition(vm, database.event_objects[3107], 201, Vector2i(208, 504))
	if not failure.is_empty():
		vm.free()
		return "灵山没有抵达大理城郊：%s" % failure
	_run_scene_enter(vm, database, 201)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[201].script_on_enter != 33029:
		vm.free()
		return "大理城郊入口状态错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[201].script_on_enter, _unsupported]
	failure = _run_transition(vm, database.event_objects[3594], 205, Vector2i(352, 1744))
	if not failure.is_empty():
		vm.free()
		return "大理城郊没有进入汉人聚居地：%s" % failure
	_run_scene_enter(vm, database, 205)
	if not _unsupported.is_empty() or not _messages.is_empty() or PalSceneCatalog.name_for_scene_index(session.scene_index) != "大理·废汉人聚居地" or session.party_roles != PackedInt32Array([0, 4]) or session.party_world_position() != Vector2i(352, 1744) or database.scenes[205].script_on_enter != 33031 or session.item_count(275) != 0:
		vm.free()
		return "抵达大理后的稳定状态错误：messages=%s scene=%s party=%s pos=%s enter=%d egg_shell=%d unsupported=%s" % [_messages, PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.party_world_position(), database.scenes[205].script_on_enter, session.item_count(275), _unsupported]
	for item_id in [262, 263, 264, 267, 274, 186]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "抵达大理后关键物品 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
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
		return "神木林敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "神木林敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "神木林敌队 %d 没有完成真实胜利结算" % team_id
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
