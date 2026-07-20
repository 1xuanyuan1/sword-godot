# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证白河村后山、玉佛寺双战、玉佛珠取得与寺院清空主线。
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
	var failure := _test_jade_buddha_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 白河村后山、玉佛寺双战、玉佛珠取得及寺院清空主线完成")
	quit(0)


func _test_jade_buddha_mainline(database: PalContentDatabase) -> String:
	# 从六神丹剧情结束后的稳定状态继续；这里只固定上一阶段已独立回归的最终状态。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 52
	session.party_roles = PackedInt32Array([0, 1, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1424, 600))
	session.music_number = 55
	database.event_objects[904].state = 0 # 赵灵儿病中对象 905 已离场。
	database.event_objects[905].state = 2 # 韩医仙对象 906 保留在诊厅。
	database.event_objects[905].trigger_script = 15050
	database.event_objects[906].state = 0
	database.event_objects[907].state = 0
	database.event_objects[909].state = 0

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 离开诊厅和韩医仙屋外，从白河村后山的正式入口抵达玉佛寺。
	var failure := _run_transition(vm, database.event_objects[903], 51, Vector2i(896, 832))
	if not failure.is_empty():
		vm.free()
		return "恢复后退出诊厅失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[885], 52, Vector2i(1280, 880))
	if not failure.is_empty():
		vm.free()
		return "韩医仙屋外进入白河村后山失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[926], 55, Vector2i(1472, 1824))
	if not failure.is_empty():
		vm.free()
		return "白河村后山进入玉佛寺空地失败：%s" % failure
	_run_stage(vm, database.scenes[55].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [16165] or _music_requests != [[10, true, 0.0]] or session.music_number != 10:
		vm.free()
		return "玉佛寺空地进入状态不正确：next=%s music=%s/%d unsupported=%s" % [_next_entries, _music_requests, session.music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[937], 57, Vector2i(1392, 1400))
	if not failure.is_empty():
		vm.free()
		return "玉佛寺空地进入大殿失败：%s" % failure

	# 调查智修大师后连续完成僧众敌队 28 与小石头敌队 35；两场都走真实敌队、战场和奖励。
	_clear_trace()
	var abbot := database.event_objects[958]
	vm.run_trigger(abbot.trigger_script, abbot.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4747, 4794) or _battle_requests != [[28, 15, true]] or not vm.waiting_for_battle:
		vm.free()
		return "智修大师剧情或第一战入口不正确：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	failure = _resolve_battle(database, session, 28, 15, PackedInt32Array([451, 482, 453]), 28015)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4747, 4813) or _battle_requests != [[28, 15, true], [35, 15, true]] or not vm.waiting_for_battle:
		vm.free()
		return "第一战后剧情或小石头战入口不正确：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
	failure = _resolve_battle(database, session, 35, 15, PackedInt32Array([524]), 35015)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(4747, 4909) or _requested_scenes != [56] or session.scene_index != 56 or _next_entries != [15806]:
		vm.free()
		return "玉佛珠长剧情或寺院切换不完整：messages=%s scenes=%s/%d next=%s unsupported=%s" % [_messages, _requested_scenes, session.scene_index, _next_entries, _unsupported]
	if session.party_roles != PackedInt32Array([0, 1, 2]) or session.item_count(274) != 1 or session.party_world_position() != Vector2i(704, 1024):
		vm.free()
		return "取得玉佛珠后的队伍、物品或切场景前落点错误：party=%s pearl=%d pos=%s" % [session.party_roles, session.item_count(274), session.party_world_position()]
	if database.event_objects[938].state != 0 or database.event_objects[939].state != 0 or database.event_objects[940].state != 0 or database.event_objects[954].state != 0 or database.event_objects[955].state != 0 or database.event_objects[956].state != 0 or database.event_objects[957].state != 0:
		vm.free()
		return "玉佛寺僧众对象没有随剧情清空"

	# 正式运行会在 0059 后加载清空版场景 56，并执行一次性进入脚本改写后山入口。
	_run_stage(vm, database.scenes[56].script_on_enter)
	if not _unsupported.is_empty() or _messages != [4926] or _next_entries != [16224] or _music_requests != [[78, true, 0.0]]:
		vm.free()
		return "玉佛寺清空版进入脚本不正确：messages=%s next=%s music=%s unsupported=%s" % [_messages, _next_entries, _music_requests, _unsupported]
	if session.scene_index != 56 or session.party_world_position() != Vector2i(1184, 560) or session.music_number != 78 or database.event_objects[926].trigger_script != 14107:
		vm.free()
		return "玉佛寺清空后的稳定状态错误：scene=%d pos=%s music=%d road=%d" % [session.scene_index, session.party_world_position(), session.music_number, database.event_objects[926].trigger_script]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "玉佛寺敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "玉佛寺敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null or reward.experience <= 0 or reward.cash <= 0:
		return "玉佛寺敌队 %d 没有产生真实胜利奖励" % team_id
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
	while vm.is_busy() and not vm.waiting_for_battle and guard < 40000:
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
