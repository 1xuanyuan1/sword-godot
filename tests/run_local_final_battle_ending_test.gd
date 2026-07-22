# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证拜月教主、水魔兽终战以及完整 DOS 结局音画请求链。
## 测试只比较消息编号、敌队编组和资源编号，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _battle_requests: Array = []
var _ending_requests: Array = []
var _rng_requests: Array = []
var _music_requests: Array = []
var _timeline: Array[String] = []
var _unsupported: Array[String] = []
var _backup_count := 0
var _quit_count := 0


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_final_battle_ending(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 拜月教主、水魔兽终战与完整 DOS 结局音画请求链完成")
	quit(0)


func _test_final_battle_ending(database: PalContentDatabase) -> String:
	# 从假巫王双战结束并返回王宫正殿后的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 280
	session.party_roles = PackedInt32Array([0])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1664, 1456))
	session.music_number = 34
	session.battlefield_number = 57
	session.battle_music_number = 38
	database.player_roles.scene_sprite_numbers[0] = 2
	database.event_objects[4997].state = 0
	database.event_objects[5004].state = 2
	database.event_objects[5053].state = 1
	database.event_objects[5055].state = 1
	for item_id in [260, 263, 264, 265, 266, 267]:
		session.set_item_count(item_id, 1)

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void:
		_battle_requests.append([team, field, boss])
		_timeline.append("battle:%d:%d" % [team, field])
	)
	vm.rng_animation_requested.connect(func(animation: int, first: int, last: int, fps: int) -> void: _rng_requests.append([animation, first, last, fps]))
	vm.music_requested.connect(func(music: int, loop: bool, fade: float) -> void:
		_music_requests.append([music, loop, fade])
		_timeline.append("music:%d" % music)
	)
	vm.ending_requested.connect(func(kind: int, first: int, second: int, third: int) -> void:
		_ending_requests.append([kind, first, second, third])
		_timeline.append("ending:%d:%d" % [kind, first])
	)
	vm.screen_backup_requested.connect(func() -> void:
		_backup_count += 1
		_timeline.append("backup")
	)
	vm.quit_requested.connect(func() -> void:
		_quit_count += 1
		_timeline.append("quit")
	)
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))

	# 最终对质会重新组成逍遥、灵儿、阿奴三人队，并进入敌队 313／战场 55。
	var final_event := database.event_objects[5055]
	vm.run_trigger(final_event.trigger_script, final_event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(503, 564) or _battle_requests != [[313, 55, true]] or not vm.waiting_for_battle:
		var entry_failure := "最终对质或终战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, vm.waiting_for_battle, _unsupported]
		vm.free()
		return entry_failure
	if session.party_roles != PackedInt32Array([0, 1, 4]) or session.party_world_position() != Vector2i(1104, 1368) or session.battle_music_number != 18 or session.battlefield_number != 55:
		var setup_failure := "终战队伍或环境错误：party=%s pos=%s battle_music=%d field=%d" % [session.party_roles, session.party_world_position(), session.battle_music_number, session.battlefield_number]
		vm.free()
		return setup_failure
	var failure := _resolve_battle(database, session, 313, 55, PackedInt32Array([546]), 313055)
	if not failure.is_empty():
		vm.free()
		return failure

	# 胜利后真实脚本必须连续完成消息、RNG 过场、音乐、结局播放器和统一退出请求。
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _unsupported.is_empty() or vm.is_busy() or _messages != _message_range(503, 584) or _backup_count != 1 or _quit_count != 1:
		var ending_failure := "终战后脚本未完整结束：messages=%s backup=%d quit=%d busy=%s unsupported=%s" % [_messages, _backup_count, _quit_count, vm.is_busy(), _unsupported]
		vm.free()
		return ending_failure

	var expected_rng := [
		[9, 0, 1, 8],
		[9, 1, 16, 8],
		[9, 17, 54, 8],
		[9, 55, 59, 8],
		[9, 60, 74, 8],
		[9, 75, 109, 8],
		[9, 110, 150, 7],
		[9, 151, -1, 9],
		[11, 0, 1, 16],
		[11, 2, -1, 7],
		[10, 0, -1, 6],
	]
	if _rng_requests != expected_rng:
		vm.free()
		return "终战后 RNG 过场帧段错误：%s" % [_rng_requests]

	var scroll := ScriptVM.ENDING_SCROLL_FBP
	var show_effect := ScriptVM.ENDING_SHOW_FBP_EFFECT
	var expected_endings := [
		[scroll, 68, 0, 15],
		[ScriptVM.ENDING_ANIMATION, 0, 0, 0],
		[show_effect, 70, 635, 7],
		[show_effect, 67, 65535, 7],
		[scroll, 66, 65535, 7],
		[show_effect, 65, 65535, 7],
		[show_effect, 49, 65535, 7],
	]
	for image_number in range(48, 39, -1):
		expected_endings.append([scroll, image_number, 0, 16])
	if _ending_requests != expected_endings:
		vm.free()
		return "完整结局图片／特效顺序错误：%s" % [_ending_requests]

	var expected_music := [
		[34, true, 0.0],
		[0, false, 3.0],
		[26, true, 3.0],
		[25, true, 0.0],
		[0, false, 3.0],
		[17, true, 0.0],
		[0, false, 3.0],
		[9, true, 0.0],
		[0, false, 3.0],
	]
	if _music_requests != expected_music:
		vm.free()
		return "完整结局音乐切换或淡出时序错误：%s" % [_music_requests]
	var expected_timeline: Array[String] = [
		"battle:313:55", "music:34", "music:0", "music:26", "music:25",
		"ending:%d:68" % scroll, "ending:%d:0" % ScriptVM.ENDING_ANIMATION, "music:0",
		"music:17", "backup", "ending:%d:70" % show_effect, "ending:%d:67" % show_effect,
		"ending:%d:66" % scroll, "ending:%d:65" % show_effect, "ending:%d:49" % show_effect,
		"music:0", "music:9",
	]
	for image_number in range(48, 39, -1):
		expected_timeline.append("ending:%d:%d" % [scroll, image_number])
	expected_timeline.append("music:0")
	expected_timeline.append("quit")
	if _timeline != expected_timeline:
		vm.free()
		return "终战、音乐和结局播放器相对顺序错误：%s" % [_timeline]
	if session.music_number != 0 or session.party_roles != PackedInt32Array([0, 1, 4]) or session.battlefield_number != 55 or database.event_objects[5055].state != 0 or database.event_objects[5056].state != 1 or database.event_objects[5057].state != 1:
		vm.free()
		return "结局结束状态错误：music=%d party=%s field=%d events=%d/%d/%d" % [session.music_number, session.party_roles, session.battlefield_number, database.event_objects[5055].state, database.event_objects[5056].state, database.event_objects[5057].state]
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
