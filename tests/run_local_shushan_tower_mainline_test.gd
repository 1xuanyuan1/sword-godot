# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证蜀山、锁妖塔、七星盘龙柱、塔毁与月如回忆主线。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _music_requests: Array = []
var _battle_requests: Array = []
var _rng_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_shushan_tower_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 蜀山、锁妖塔、七星盘龙柱、塔毁与李逍遥醒来主线完成")
	quit(0)


func _test_shushan_tower_mainline(database: PalContentDatabase) -> String:
	# 从彩依牺牲后随酒剑仙抵达蜀山前山的章节边界继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 154
	session.party_roles = PackedInt32Array([0, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(1024, 1600))
	session.set_item_count(262, 1)
	session.set_item_count(267, 1)

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))
	vm.rng_animation_requested.connect(func(number: int, first: int, last: int, fps: int) -> void: _rng_requests.append([number, first, last, fps]))

	# 抵达对白后进入正殿，向剑圣确认灵儿被关进锁妖塔。
	_run_scene_enter(vm, database, 154)
	var failure := _expect_stage("蜀山抵达", 8812, 8846)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2614], 156, Vector2i(576, 1664))
	if not failure.is_empty():
		vm.free()
		return "蜀山前山没有进入正殿外：%s" % failure
	failure = _run_transition(vm, database.event_objects[2746], 158, Vector2i(608, 1488))
	if not failure.is_empty():
		vm.free()
		return "蜀山正殿外没有进入正殿内：%s" % failure
	_run_scene_enter(vm, database, 158)
	failure = _expect_stage("蜀山正殿入场", 8859, 8932)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_event(vm, database.event_objects[2755])
	if not failure.is_empty():
		vm.free()
		return "初问剑圣出现错误：%s" % failure
	failure = _expect_stage("初问剑圣", 8933, 8943)
	if not failure.is_empty():
		vm.free()
		return failure

	# 到弟子房取得玉佛珠并获知真相，返回正殿与剑圣争执。
	failure = _run_transition(vm, database.event_objects[2759], 159, Vector2i(656, 1528))
	if not failure.is_empty():
		vm.free()
		return "蜀山正殿没有进入弟子房：%s" % failure
	failure = _run_event(vm, database.event_objects[2781])
	if not failure.is_empty() or session.item_count(274) != 1 or database.event_objects[2755].trigger_script != 27428:
		vm.free()
		return "弟子房没有交付玉佛珠或改写剑圣事件：failure=%s jade=%d sword_saint=%d" % [failure, session.item_count(274), database.event_objects[2755].trigger_script]
	failure = _expect_stage("弟子房获知真相", 8991, 9040)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2780], 158, Vector2i(960, 1152))
	if not failure.is_empty():
		vm.free()
		return "弟子房没有返回正殿：%s" % failure
	failure = _run_event(vm, database.event_objects[2755])
	if not failure.is_empty() or session.scene_index != 157 or database.scenes[157].script_on_enter != 27594:
		vm.free()
		return "与剑圣争执后没有进入后山：failure=%s scene=%d enter=%d" % [failure, session.scene_index, database.scenes[157].script_on_enter]
	failure = _expect_stage("与剑圣争执", 9050, 9138)
	if not failure.is_empty():
		vm.free()
		return failure

	# 酒剑仙传授三项仙术，交付雷灵珠和补给，并打开蜀山云海入口。
	_run_scene_enter(vm, database, 157)
	if not _unsupported.is_empty() or not session.has_magic(0, 370) or not session.has_magic(0, 390) or not session.has_magic(0, 393) or session.item_count(264) != 1 or session.item_count(62) != 3 or session.item_count(66) != 3 or session.item_count(63) != 3 or session.item_count(86) != 2 or session.party_roles != PackedInt32Array([0, 2]) or database.event_objects[2750].trigger_script != 27052:
		vm.free()
		return "酒剑仙授艺或补给错误：magic=%s/%s/%s items=%d/%d/%d/%d/%d party=%s gate=%d unsupported=%s" % [session.has_magic(0, 370), session.has_magic(0, 390), session.has_magic(0, 393), session.item_count(264), session.item_count(62), session.item_count(66), session.item_count(63), session.item_count(86), session.party_roles, database.event_objects[2750].trigger_script, _unsupported]
	failure = _expect_stage("酒剑仙授艺", 9139, 9179)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2750], 160, Vector2i(464, 1736))
	if not failure.is_empty():
		vm.free()
		return "蜀山后山没有进入云海前段：%s" % failure
	failure = _run_transition(vm, database.event_objects[2791], 161, Vector2i(432, 168))
	if not failure.is_empty():
		vm.free()
		return "云海前段没有进入后段：%s" % failure
	failure = _run_transition(vm, database.event_objects[2803], 162, Vector2i(672, 704))
	if not failure.is_empty():
		vm.free()
		return "云海后段没有抵达锁妖塔外：%s" % failure
	failure = _run_event(vm, database.event_objects[2810])
	if not failure.is_empty() or session.scene_index != 163 or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "锁妖塔外没有进入全景过场：failure=%s scene=%d party=%s" % [failure, session.scene_index, session.party_roles]
	_run_scene_enter(vm, database, 163)
	if not _unsupported.is_empty() or session.scene_index != 145 or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "锁妖塔全景没有进入八层：scene=%d party=%s unsupported=%s" % [session.scene_index, session.party_roles, _unsupported]
	_run_scene_enter(vm, database, 145)
	if not _unsupported.is_empty() or session.music_number != 80 or session.battle_music_number != 43 or session.battlefield_number != 35:
		vm.free()
		return "锁妖塔八层音乐或战场错误：music=%d battle_music=%d field=%d unsupported=%s" % [session.music_number, session.battle_music_number, session.battlefield_number, _unsupported]

	# 镇狱明王警告后逐层推进，完成姜清与天鬼皇两段剧情战。
	failure = _run_event(vm, database.event_objects[2479])
	if not failure.is_empty():
		vm.free()
		return "镇狱明王初次警告错误：%s" % failure
	failure = _expect_stage("镇狱明王初次警告", 9323, 9360)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2478], 164, Vector2i(1440, 288))
	if not failure.is_empty():
		vm.free()
		return "锁妖塔八层没有进入七层：%s" % failure
	failure = _run_transition(vm, database.event_objects[2814], 165, Vector2i(1024, 720))
	if not failure.is_empty():
		vm.free()
		return "锁妖塔七层没有进入六层：%s" % failure
	failure = _run_transition(vm, database.event_objects[2856], 146, Vector2i(1520, 1160))
	if not failure.is_empty():
		vm.free()
		return "锁妖塔六层没有进入姜清层：%s" % failure
	_run_scene_enter(vm, database, 146)
	failure = _run_battle_event(vm, database, database.event_objects[2482], 163, 35, PackedInt32Array([494]), 163035)
	if not failure.is_empty() or session.item_count(186) != 1:
		vm.free()
		return "姜清剧情战或七星剑错误：failure=%s sword=%d" % [failure, session.item_count(186)]
	failure = _expect_stage("姜清剧情战", 9188, 9261)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2481], 166, Vector2i(848, 712))
	if not failure.is_empty():
		vm.free()
		return "姜清层没有进入四层：%s" % failure
	failure = _run_transition(vm, database.event_objects[2903], 147, Vector2i(1280, 288))
	if not failure.is_empty():
		vm.free()
		return "锁妖塔四层没有进入天鬼皇层：%s" % failure
	_run_scene_enter(vm, database, 147)
	failure = _run_event(vm, database.event_objects[2506])
	if not failure.is_empty():
		vm.free()
		return "天鬼皇前置事件错误：%s" % failure
	failure = _run_battle_event(vm, database, database.event_objects[2510], 293, 35, PackedInt32Array([529]), 293035)
	if not failure.is_empty():
		vm.free()
		return "天鬼皇剧情战错误：%s" % failure
	failure = _expect_stage("天鬼皇剧情战", 9264, 9321)
	if not failure.is_empty():
		vm.free()
		return failure

	# 书中仙加入后抵达塔底，救出灵儿并击败镇狱明王。
	failure = _run_transition(vm, database.event_objects[2504], 153, Vector2i(1456, 1384))
	if not failure.is_empty():
		vm.free()
		return "天鬼皇层没有进入书中仙层：%s" % failure
	_run_scene_enter(vm, database, 153)
	failure = _run_event(vm, database.event_objects[2581])
	if not failure.is_empty() or database.event_objects[2579].trigger_script != 28232:
		vm.free()
		return "沉思鬼谜题没有引出书中仙：failure=%s book_entry=%d" % [failure, database.event_objects[2579].trigger_script]
	failure = _expect_stage("沉思鬼谜题", 9361, 9418)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_event(vm, database.event_objects[2579])
	if not failure.is_empty() or session.item_count(290) != 1:
		vm.free()
		return "书中仙没有加入：failure=%s book=%d" % [failure, session.item_count(290)]
	failure = _expect_stage("书中仙加入", 9441, 9485)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[2577], 155, Vector2i(320, 1712))
	if not failure.is_empty():
		vm.free()
		return "书中仙层没有进入化妖池：%s" % failure
	_run_scene_enter(vm, database, 155)
	failure = _run_transition(vm, database.event_objects[2615], 167, Vector2i(464, 856))
	if not failure.is_empty():
		vm.free()
		return "化妖池没有进入塔底外层：%s" % failure
	_run_scene_enter(vm, database, 167)
	failure = _run_transition(vm, database.event_objects[2954], 144, Vector2i(464, 1160))
	if not failure.is_empty():
		vm.free()
		return "塔底外层没有进入灵儿被缚处：%s" % failure
	_run_scene_enter(vm, database, 144)
	failure = _run_event(vm, database.event_objects[2474])
	if not failure.is_empty() or session.scene_index != 168 or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "救灵儿剧情没有进入第一段往事：failure=%s scene=%d party=%s" % [failure, session.scene_index, session.party_roles]
	failure = _expect_stage("救灵儿与灵岛往事入口", 9486, 9496)
	if not failure.is_empty():
		vm.free()
		return failure

	# 灵岛三段往事结束后回到塔底，完成镇狱明王战与群妖议事。
	_run_scene_enter(vm, database, 168)
	if not _unsupported.is_empty() or session.scene_index != 169:
		vm.free()
		return "灵岛仙宫往事转场错误：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 169)
	if not _unsupported.is_empty() or session.scene_index != 170:
		vm.free()
		return "灵池往事转场错误：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 170)
	if not _unsupported.is_empty() or session.scene_index != 168:
		vm.free()
		return "还魂往事没有回到第一段场景：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 168)
	if not _unsupported.is_empty() or session.scene_index != 144 or database.scenes[144].script_on_enter != 28380:
		vm.free()
		return "三段往事没有返回塔底：scene=%d enter=%d unsupported=%s" % [session.scene_index, database.scenes[144].script_on_enter, _unsupported]
	failure = _run_scene_battle(vm, database, 144, 188, 31, PackedInt32Array([519]), 188031)
	if not failure.is_empty() or session.party_roles != PackedInt32Array([0, 1, 2]) or session.scene_index != 152:
		vm.free()
		return "镇狱明王战或灵儿归队错误：failure=%s scene=%d party=%s" % [failure, session.scene_index, session.party_roles]
	failure = _expect_stage("镇狱明王剧情战", 9497, 9531)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 152)
	if not _unsupported.is_empty() or session.scene_index != 151 or database.scenes[151].script_on_enter != 29093:
		vm.free()
		return "群妖议事没有进入七星盘龙柱前厅：scene=%d enter=%d unsupported=%s" % [session.scene_index, database.scenes[151].script_on_enter, _unsupported]
	failure = _expect_stage("群妖议事", 9532, 9765)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 151)
	if not _unsupported.is_empty() or session.party_roles != PackedInt32Array([1, 0, 2]):
		vm.free()
		return "七星盘龙柱前队伍错误：party=%s unsupported=%s" % [session.party_roles, _unsupported]
	failure = _run_transition(vm, database.event_objects[2560], 143, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "塔底前厅没有进入七星盘龙柱：%s" % failure
	_run_scene_enter(vm, database, 143)
	if not _unsupported.is_empty() or session.battlefield_number != 31 or session.party_roles != PackedInt32Array([1, 0, 2]):
		vm.free()
		return "七星盘龙柱入场状态错误：field=%d party=%s unsupported=%s" % [session.battlefield_number, session.party_roles, _unsupported]
	failure = _expect_stage("七星盘龙柱入场", 9773, 9773)
	if not failure.is_empty():
		vm.free()
		return failure

	# 七柱分别使用七个真实敌队；只有最后一柱胜利才触发崩塌。
	for pillar_index in range(7):
		failure = _run_battle_event(vm, database, database.event_objects[2465 + pillar_index], 305 + pillar_index, 31, PackedInt32Array([539 + pillar_index]), 305031 + pillar_index, false)
		if not failure.is_empty():
			vm.free()
			return "第 %d 根七星盘龙柱错误：%s" % [pillar_index + 1, failure]
		if database.event_objects[2465 + pillar_index].state != 0:
			vm.free()
			return "第 %d 根七星盘龙柱战后仍可重复触发：state=%d" % [pillar_index + 1, database.event_objects[2465 + pillar_index].state]
		if pillar_index < 6 and session.scene_index != 143:
			vm.free()
			return "只破坏 %d 根盘龙柱就提前离塔：scene=%d" % [pillar_index + 1, session.scene_index]
		if pillar_index < 6 and not _messages.is_empty():
			vm.free()
			return "第 %d 根盘龙柱战后错误触发塔毁对白：messages=%s" % [pillar_index + 1, _messages]
	if session.scene_index != 148:
		vm.free()
		return "七柱全毁后没有进入锁妖塔崩塌场景：scene=%d" % session.scene_index
	failure = _expect_stage("七柱全毁", 9774, 9774)
	if not failure.is_empty():
		vm.free()
		return failure

	# 锁妖塔崩塌、酒剑仙救援和月如恍惚过场。
	_run_scene_enter(vm, database, 148)
	if not _unsupported.is_empty() or session.scene_index != 149 or _rng_requests.size() != 2:
		vm.free()
		return "锁妖塔崩塌过场错误：scene=%d rng=%s unsupported=%s" % [session.scene_index, _rng_requests, _unsupported]
	_run_scene_enter(vm, database, 149)
	if not _unsupported.is_empty() or session.scene_index != 150 or _rng_requests.size() != 2:
		vm.free()
		return "酒剑仙救援过场错误：scene=%d rng=%s unsupported=%s" % [session.scene_index, _rng_requests, _unsupported]
	failure = _expect_stage("酒剑仙救援", 9789, 9795)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 150)
	if not _unsupported.is_empty() or session.scene_index != 171 or session.item_count(290) != 0:
		vm.free()
		return "塔毁后没有进入月如恍惚场景：scene=%d book=%d unsupported=%s" % [session.scene_index, session.item_count(290), _unsupported]
	failure = _expect_stage("塔毁后的长安幻景", 9775, 9788)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 171)
	if not _unsupported.is_empty() or session.scene_index != 173:
		vm.free()
		return "月如恍惚后没有进入李逍遥醒来场景：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	failure = _expect_stage("月如恍惚", 10409, 10414)
	if not failure.is_empty():
		vm.free()
		return failure

	# 醒来后连续经历七段月如往事，再看剑圣黯然离去，最终回到稳定房间状态。
	_run_scene_enter(vm, database, 173)
	if not _unsupported.is_empty() or session.scene_index != 192:
		vm.free()
		return "李逍遥醒来没有进入第一段月如往事：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	failure = _expect_stage("李逍遥醒来", 10415, 10484)
	if not failure.is_empty():
		vm.free()
		return failure
	var memory_message_ranges: Array[Vector2i] = [
		Vector2i(318, 321),
		Vector2i(322, 338),
		Vector2i(339, 345),
		Vector2i(346, 349),
		Vector2i(350, 353),
		Vector2i(354, 371),
		Vector2i(372, 375),
	]
	for memory_scene in range(192, 199):
		_run_scene_enter(vm, database, memory_scene)
		var expected_scene := memory_scene + 1 if memory_scene < 198 else 173
		if not _unsupported.is_empty() or session.scene_index != expected_scene:
			vm.free()
			return "月如往事场景 %d 衔接错误：scene=%d expected=%d unsupported=%s" % [memory_scene, session.scene_index, expected_scene, _unsupported]
		var message_range := memory_message_ranges[memory_scene - 192]
		failure = _expect_stage("月如往事场景 %d" % memory_scene, message_range.x, message_range.y)
		if not failure.is_empty():
			vm.free()
			return failure
	_run_scene_enter(vm, database, 173)
	if not _unsupported.is_empty() or session.scene_index != 176:
		vm.free()
		return "月如往事后没有进入剑圣黯离场景：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	failure = _expect_stage("月如往事结束", 10485, 10485)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 176)
	if not _unsupported.is_empty() or session.scene_index != 173:
		vm.free()
		return "剑圣黯离后没有回到李逍遥房间：scene=%d unsupported=%s" % [session.scene_index, _unsupported]
	failure = _expect_stage("剑圣黯离", 10486, 10512)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 173)
	if not _unsupported.is_empty() or PalSceneCatalog.name_for_scene_index(session.scene_index) != "李逍遥醒来" or session.party_roles != PackedInt32Array([0]) or session.party_world_position() != Vector2i(528, 488) or session.music_number != 0 or session.item_count(262) != 1 or session.item_count(264) != 1 or session.item_count(267) != 1 or session.item_count(274) != 1 or session.item_count(186) != 1 or session.item_count(290) != 0 or database.scenes[173].script_on_enter != 32359:
		vm.free()
		return "第十二章结束状态错误：scene=%s party=%s pos=%s music=%d pearls=%d/%d/%d jade=%d sword=%d book=%d enter=%d unsupported=%s" % [PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.party_world_position(), session.music_number, session.item_count(262), session.item_count(264), session.item_count(267), session.item_count(274), session.item_count(186), session.item_count(290), database.scenes[173].script_on_enter, _unsupported]
	vm.free()
	return ""


func _run_battle_event(vm: ScriptVM, database: PalContentDatabase, event: PalEventObject, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int, expected_boss: bool = true) -> String:
	var entry := event.trigger_script
	_clear_trace()
	vm.run_trigger(entry, event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[team_id, field_id, expected_boss]] or not vm.waiting_for_battle:
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


func _run_scene_battle(vm: ScriptVM, database: PalContentDatabase, scene_index: int, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var scene := database.scenes[scene_index]
	var entry := scene.script_on_enter
	_clear_trace()
	vm.run_trigger(entry)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[team_id, field_id, true]] or not vm.waiting_for_battle:
		return "敌队 %d 场景入口错误：battles=%s waiting=%s unsupported=%s" % [team_id, _battle_requests, vm.waiting_for_battle, _unsupported]
	var failure := _resolve_battle(database, vm.session, team_id, field_id, expected_objects, seed)
	if not failure.is_empty():
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _next_entries.is_empty():
		scene.script_on_enter = _next_entries[-1]
	if not _unsupported.is_empty():
		return "敌队 %d 战后出现未支持指令：%s" % [team_id, _unsupported]
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "锁妖塔敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "锁妖塔敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "锁妖塔敌队 %d 没有完成真实胜利结算" % team_id
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


func _expect_stage(label: String, first_message: int, last_message: int) -> String:
	if not _unsupported.is_empty():
		return "%s 出现未支持指令：%s" % [label, _unsupported]
	if _messages != _message_range(first_message, last_message):
		return "%s 消息区段错误：messages=%s expected=%d-%d" % [label, _messages, first_message, last_message]
	return ""


func _clear_trace() -> void:
	_messages.clear()
	_requested_scenes.clear()
	_next_entries.clear()
	_unsupported.clear()
	_music_requests.clear()
	_battle_requests.clear()
	_rng_requests.clear()


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
