# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证圣姑救治、灵儿生产、试炼窟、傀儡虫与第十七章入口。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

const PUPPET_WORM_ITEM := 152
const PUPPET_WORM_ENEMIES := [465, 490, 492, 498, 536, 550]

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
	var failure := _test_shenggu_trial_cave_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 圣姑救治、灵儿生产、试炼窟、傀儡虫与第十七章入口主线完成")
	quit(0)


func _test_shenggu_trial_cave_mainline(database: PalContentDatabase) -> String:
	var puppet_worm := database.item_definition(PUPPET_WORM_ITEM)
	if puppet_worm == null or database.get_word(PUPPET_WORM_ITEM) != "傀儡蟲" or puppet_worm.script_on_use != 39535:
		return "傀儡虫 152 的真实物品定义错误"
	if database.enemy_teams[223].active_object_ids() != PackedInt32Array([501, 490]):
		return "盖罗娇敌队 223 编组错误：%s" % database.enemy_teams[223].active_object_ids()
	for object_id in PUPPET_WORM_ENEMIES:
		var enemy_object := database.enemy_object_definition(object_id)
		if enemy_object == null or enemy_object.script_on_battle_end != 41844:
			return "傀儡虫掉落敌人 %d 的战后脚本错误" % object_id
	var drop_entry := database.scripts[41844]
	if drop_entry.operation != 0x001f or drop_entry.operands[0] != PUPPET_WORM_ITEM:
		return "傀儡虫战后掉落入口 41844 错误：%04X/%s" % [drop_entry.operation, drop_entry.operands]

	# 从第十五章返回女娲神殿后的完整稳定状态继续；前章脚本已经恢复大理西侧出口，
	# 并把圣姑、祭坛石碑及场景入口改写到回魂仙梦后的后续段。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 202
	session.party_roles = PackedInt32Array([0, 4])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1168, 760))
	for item_id in [186, 262, 263, 264, 265, 266, 267, 274, 275, 276]:
		session.set_item_count(item_id, 1)
	session.music_number = 55
	database.scenes[202].script_on_enter = 34711
	database.event_objects[3029].trigger_script = 32431
	database.event_objects[3640].trigger_script = 38777
	database.event_objects[3669].trigger_script = 33047

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 从女娲神殿原路返回圣姑住处，交出两味圣药。
	var failure := _run_transition(vm, database.event_objects[3613], 210, Vector2i(1312, 736))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿没有抵达神殿外：%s" % failure
	failure = _run_transition(vm, database.event_objects[3791], 205, Vector2i(448, 944))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿外没有返回大理：%s" % failure
	failure = _run_transition(vm, database.event_objects[3669], 201, Vector2i(1504, 416))
	if not failure.is_empty():
		vm.free()
		return "回魂仙梦后的大理西侧出口仍被封闭：%s" % failure
	for transition in [
		[3593, 178, Vector2i(1744, 1032)],
		[3106, 185, Vector2i(1840, 1032)],
		[3295, 175, Vector2i(384, 944)],
		[3070, 173, Vector2i(704, 624)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "返回圣姑住处失败：%s" % failure
	failure = _run_event(vm, database.event_objects[3029])
	if not failure.is_empty() or _messages != _message_range(10515, 10558) or _requested_scenes != [172] or session.scene_index != 172 or session.item_count(275) != 0 or session.item_count(276) != 0:
		vm.free()
		return "两味圣药救治灵儿错误：failure=%s messages=%s scenes=%s/%d egg=%d horn=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.item_count(275), session.item_count(276)]

	# 场景 172 连续完成生产剧情并开启三十六只傀儡虫任务。
	_run_scene_enter(vm, database, 172)
	if not _unsupported.is_empty() or _messages != _message_range(10596, 10649) or session.party_roles != PackedInt32Array([0]) or session.party_world_position() != Vector2i(560, 472) or database.scenes[172].script_on_enter != 32808 or database.event_objects[3070].trigger_script != 32138:
		vm.free()
		return "灵儿生产或试炼窟任务入口错误：messages=%s party=%s pos=%s enter=%d door=%d unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), database.scenes[172].script_on_enter, database.event_objects[3070].trigger_script, _unsupported]
	failure = _run_event(vm, database.event_objects[3018])
	if not failure.is_empty() or _messages != _message_range(10650, 10659) or session.item_count(PUPPET_WORM_ITEM) != 0 or session.scene_index != 172:
		vm.free()
		return "傀儡虫数量不足提示错误：failure=%s messages=%s worms=%d scene=%d" % [failure, _messages, session.item_count(PUPPET_WORM_ITEM), session.scene_index]

	# 从圣姑住处经大理城郊进入试炼窟外；生产剧情已清除封路士兵。
	for transition in [
		[3010, 175, Vector2i(1424, 712)],
		[3069, 185, Vector2i(1808, 1160)],
		[3296, 178, Vector2i(1664, 1440)],
		[3107, 201, Vector2i(208, 504)],
		[3595, 213, Vector2i(752, 184)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "前往试炼窟失败：%s" % failure
	_run_scene_enter(vm, database, 213)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.music_number != 70 or session.battlefield_number != 6:
		vm.free()
		return "试炼窟外入口音乐或战场错误：messages=%s music=%d field=%d unsupported=%s" % [_messages, session.music_number, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[3874], 214, Vector2i(1776, 1544))
	if not failure.is_empty():
		vm.free()
		return "试炼窟外没有抵达盖罗娇区域：%s" % failure
	_run_scene_enter(vm, database, 214)

	# 盖罗娇使用敌队 223／战场 6；队中的五毒巨蝎通过真实战后脚本掉落首只傀儡虫。
	failure = _run_battle_event(vm, database, database.event_objects[3886], 223, 6, PackedInt32Array([501, 490]), 223006)
	if not failure.is_empty() or _messages != _message_range(11549, 11610) or session.item_count(PUPPET_WORM_ITEM) != 1 or session.party_roles != PackedInt32Array([0, 4]):
		vm.free()
		return "盖罗娇剧情战或傀儡虫掉落错误：failure=%s messages=%s worms=%d party=%s" % [failure, _messages, session.item_count(PUPPET_WORM_ITEM), session.party_roles]

	# 进入洞内后覆盖一至三层、支路和最深的女娲遗迹，固定每段正式转场落点。
	failure = _run_transition(vm, database.event_objects[3883], 215, Vector2i(448, 1152))
	if not failure.is_empty():
		vm.free()
		return "试炼窟入口转场失败：%s" % failure
	_run_scene_enter(vm, database, 215)
	if not _unsupported.is_empty() or _messages != _message_range(11514, 11533) or database.scenes[215].script_on_enter != 34860 or session.music_number != 35 or session.battlefield_number != 58:
		vm.free()
		return "试炼窟介绍或洞内环境错误：messages=%s enter=%d music=%d field=%d unsupported=%s" % [_messages, database.scenes[215].script_on_enter, session.music_number, session.battlefield_number, _unsupported]
	for transition in [
		[3900, 216, Vector2i(1232, 1144)],
		[3918, 217, Vector2i(928, 272)],
		[3943, 218, Vector2i(768, 320)],
		[3965, 219, Vector2i(736, 480)],
		[4013, 221, Vector2i(1248, 464)],
		[4057, 222, Vector2i(720, 1544)],
		[4100, 223, Vector2i(1184, 1504)],
		[4150, 222, Vector2i(448, 960)],
		[4103, 220, Vector2i(1024, 528)],
		[4053, 224, Vector2i(928, 896)],
		[4174, 225, Vector2i(384, 1152)],
		[4194, 212, Vector2i(1456, 312)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "试炼窟分层或女娲遗迹转场失败：%s" % failure
	_run_scene_enter(vm, database, 212)
	if not _unsupported.is_empty() or session.music_number != 16:
		vm.free()
		return "女娲遗迹入口状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_event(vm, database.event_objects[3836])
	if not failure.is_empty() or _messages != [11611] or session.item_count(294) != 1:
		vm.free()
		return "女娲遗迹芦苇漂取得错误：failure=%s messages=%s reed=%d" % [failure, _messages, session.item_count(294)]

	# 土灵珠 267 的真实使用脚本通过当前场景 teleport 把队伍送回试炼窟入口，且不消耗灵珠。
	var earth_pearl := database.item_definition(267)
	if earth_pearl == null or earth_pearl.script_on_use != 39818 or earth_pearl.is_consuming():
		vm.free()
		return "土灵珠 267 的真实使用定义错误"
	failure = _run_item(vm, session, earth_pearl)
	if not failure.is_empty() or _requested_scenes != [214] or session.scene_index != 214 or session.party_world_position() != Vector2i(832, 736) or session.item_count(267) != 1:
		vm.free()
		return "土灵珠没有脱离试炼窟：failure=%s scenes=%s/%d pos=%s earth=%d" % [failure, _requested_scenes, session.scene_index, session.party_world_position(), session.item_count(267)]

	# 反向返回圣姑处；重复刷怪已有真实掉落验证，这里把合法收集结果补齐到三十六只再交付。
	for transition in [
		[3882, 213, Vector2i(384, 864)],
		[3875, 201, Vector2i(1248, 800)],
		[3593, 178, Vector2i(1744, 1032)],
		[3106, 185, Vector2i(1840, 1032)],
		[3295, 175, Vector2i(384, 944)],
		[3070, 172, Vector2i(704, 624)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "离开试炼窟并返回圣姑处失败：%s" % failure
	session.set_item_count(PUPPET_WORM_ITEM, 36)
	failure = _run_event(vm, database.event_objects[3018])
	if not failure.is_empty() or _messages != _message_range(10660, 10661) or _requested_scenes != [173] or session.scene_index != 173 or session.item_count(PUPPET_WORM_ITEM) != 0 or database.scenes[173].script_on_enter != 32872:
		vm.free()
		return "三十六只傀儡虫交付错误：failure=%s messages=%s scenes=%s/%d worms=%d enter=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.item_count(PUPPET_WORM_ITEM), database.scenes[173].script_on_enter]

	# 交付后的场景入口组成灵儿／逍遥／阿奴三人队，并稳定停在前往五灵珠祭坛的第十七章边界。
	_run_scene_enter(vm, database, 173)
	if not _unsupported.is_empty() or _messages != _message_range(10672, 10696) or session.party_roles != PackedInt32Array([1, 0, 4]) or session.party_world_position() != Vector2i(720, 616) or database.scenes[173].script_on_enter != 32941 or database.event_objects[3070].trigger_script != 32134 or database.event_objects[3107].trigger_script != 32122 or database.event_objects[3875].trigger_script != 35294:
		vm.free()
		return "第十七章稳定入口错误：messages=%s party=%s pos=%s enter=%d door=%d lingshan=%d cave=%d unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), database.scenes[173].script_on_enter, database.event_objects[3070].trigger_script, database.event_objects[3107].trigger_script, database.event_objects[3875].trigger_script, _unsupported]
	for item_id in [186, 262, 263, 264, 265, 266, 267, 274, 294]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "第十六章结束关键物品 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
	vm.free()
	return ""


func _run_battle_event(vm: ScriptVM, database: PalContentDatabase, event: PalEventObject, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed_value: int) -> String:
	var entry := event.trigger_script
	_clear_trace()
	vm.run_trigger(entry, event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[team_id, field_id, true]] or not vm.waiting_for_battle:
		return "敌队 %d 入口错误：battles=%s waiting=%s unsupported=%s" % [team_id, _battle_requests, vm.waiting_for_battle, _unsupported]
	var failure := _resolve_battle(database, vm.session, team_id, field_id, expected_objects, seed_value)
	if not failure.is_empty():
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(event, entry)
	return "" if _unsupported.is_empty() else "敌队 %d 战后出现未支持指令：%s" % [team_id, _unsupported]


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed_value: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed_value, true):
		return "试炼窟敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "试炼窟敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "试炼窟敌队 %d 没有完成真实胜利结算" % team_id
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
	return "" if _unsupported.is_empty() else "事件 %d 出现未支持指令：%s" % [event.object_id, _unsupported]


func _run_item(vm: ScriptVM, session: GameSession, item: PalItemDefinition) -> String:
	var entry := item.script_on_use
	_run_stage(vm, entry, 0xffff)
	if not _next_entries.is_empty():
		item.script_on_use = _next_entries[-1]
	if vm.script_success and item.is_consuming():
		session.change_item_count(item.object_id, -1)
	return "" if _unsupported.is_empty() else "物品 %d 出现未支持指令：%s" % [item.object_id, _unsupported]


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
