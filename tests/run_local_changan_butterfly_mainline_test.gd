# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证长安尚书府、彩依、毒娘子与御剑抵达蜀山主线。
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
	var failure := _test_changan_butterfly_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 长安尚书府、林天南、彩依、毒娘子与御剑抵达蜀山主线完成")
	quit(0)


func _test_changan_butterfly_mainline(database: PalContentDatabase) -> String:
	# 从随尚书夫人乘船抵达长安、首次入城对白结束后的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 99
	session.party_roles = PackedInt32Array([2, 0])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(432, 328))
	session.set_item_count(262, 1)
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
	vm.rng_animation_requested.connect(func(number: int, first: int, last: int, fps: int) -> void: _rng_requests.append([number, first, last, fps]))

	# 入尚书府拜见云姨，经后院进入刘晋元居所。
	var failure := _run_transition(vm, database.event_objects[1884], 113, Vector2i(1568, 1216))
	if not failure.is_empty():
		vm.free()
		return "长安没有进入尚书府：%s" % failure
	_run_scene_enter(vm, database, 113)
	if not _unsupported.is_empty() or session.music_number != 73:
		vm.free()
		return "尚书府外音乐状态错误：music=%d unsupported=%s" % [session.music_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[2197], 117, Vector2i(1104, 648))
	if not failure.is_empty():
		vm.free()
		return "尚书府外没有进入大厅：%s" % failure
	_run_scene_enter(vm, database, 117)
	if not _unsupported.is_empty() or _messages != _message_range(6573, 6651) or database.scenes[117].script_on_enter != 21735:
		vm.free()
		return "初见云姨剧情不完整：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[117].script_on_enter, _unsupported]

	# 搜查楼上柜子取得开坛所需的檀香、蜡烛与符纸；物品由真实调查脚本交付。
	failure = _run_transition(vm, database.event_objects[2236], 118, Vector2i(704, 512))
	if not failure.is_empty():
		vm.free()
		return "尚书府大厅没有进入楼上：%s" % failure
	failure = _run_event(vm, database.event_objects[2261])
	if not failure.is_empty() or session.item_count(83) != 1 or session.item_count(81) != 1:
		vm.free()
		return "楼上柜子没有交付檀香和蜡烛：failure=%s incense=%d candle=%d" % [failure, session.item_count(83), session.item_count(81)]
	failure = _run_event(vm, database.event_objects[2262])
	if not failure.is_empty() or session.item_count(82) != 1:
		vm.free()
		return "楼上柜子没有交付符纸：failure=%s paper=%d" % [failure, session.item_count(82)]
	failure = _run_transition(vm, database.event_objects[2248], 117, Vector2i(992, 400))
	if not failure.is_empty():
		vm.free()
		return "尚书府楼上没有返回大厅：%s" % failure
	failure = _run_transition(vm, database.event_objects[2235], 114, Vector2i(1024, 928))
	if not failure.is_empty():
		vm.free()
		return "尚书府大厅没有进入后院：%s" % failure
	failure = _run_transition(vm, database.event_objects[2209], 115, Vector2i(1744, 1784))
	if not failure.is_empty():
		vm.free()
		return "尚书府后院没有进入幽径：%s" % failure
	failure = _run_transition(vm, database.event_objects[2223], 107, Vector2i(608, 1856))
	if not failure.is_empty():
		vm.free()
		return "尚书府幽径没有抵达刘晋元居所外：%s" % failure
	failure = _run_transition(vm, database.event_objects[2071], 121, Vector2i(800, 656))
	if not failure.is_empty():
		vm.free()
		return "刘晋元居所外没有进入一层：%s" % failure
	_run_scene_enter(vm, database, 121)
	if not _unsupported.is_empty() or _messages != _message_range(7128, 7149):
		vm.free()
		return "刘晋元居所初访对话错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_transition(vm, database.event_objects[2277], 122, Vector2i(736, 448))
	if not failure.is_empty():
		vm.free()
		return "刘晋元居所没有进入内厅：%s" % failure
	failure = _run_transition(vm, database.event_objects[2279], 123, Vector2i(800, 704))
	if not failure.is_empty():
		vm.free()
		return "刘晋元居所内厅没有进入病房：%s" % failure
	failure = _run_event(vm, database.event_objects[2283])
	if not failure.is_empty() or _messages != _message_range(6667, 6726) or session.party_roles != PackedInt32Array([2, 0]) or database.scenes[122].script_on_enter != 22390 or database.event_objects[2076].state != 1:
		vm.free()
		return "探病、彩依喂药或晚宴入口错误：failure=%s messages=%s party=%s inner_enter=%d maid=%d" % [failure, _messages, session.party_roles, database.scenes[122].script_on_enter, database.event_objects[2076].state]

	# 离开病房时讨论彩依，随后由婢女带到膳厅用餐。
	failure = _run_transition(vm, database.event_objects[2280], 122, Vector2i(352, 624))
	if not failure.is_empty():
		vm.free()
		return "病房没有返回内厅：%s" % failure
	_run_scene_enter(vm, database, 122)
	if not _unsupported.is_empty() or _messages != _message_range(6992, 7007):
		vm.free()
		return "探病后的私下对话错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_transition(vm, database.event_objects[2278], 121, Vector2i(624, 552))
	if not failure.is_empty():
		vm.free()
		return "刘晋元内厅没有返回一层：%s" % failure
	failure = _run_transition(vm, database.event_objects[2274], 107, Vector2i(864, 1104))
	if not failure.is_empty():
		vm.free()
		return "刘晋元居所没有回到院外：%s" % failure
	failure = _run_event(vm, database.event_objects[2076])
	if not failure.is_empty() or _messages != _message_range(6988, 6991) or session.scene_index != 119 or database.scenes[119].script_on_enter != 22423:
		vm.free()
		return "婢女没有带队前往晚宴：failure=%s messages=%s scene=%d enter=%d" % [failure, _messages, session.scene_index, database.scenes[119].script_on_enter]
	_run_scene_enter(vm, database, 119)
	if not _unsupported.is_empty() or _messages != _message_range(7008, 7062) or session.scene_index != 120:
		vm.free()
		return "尚书府晚宴不完整：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 120)
	if not _unsupported.is_empty() or _messages != _message_range(7063, 7069) or session.party_roles != PackedInt32Array([2, 0]) or database.event_objects[1899].state != 2 or database.event_objects[1900].state != 2:
		vm.free()
		return "晚宴结束状态错误：messages=%s party=%s beggars=%d/%d unsupported=%s" % [_messages, session.party_roles, database.event_objects[1899].state, database.event_objects[1900].state, _unsupported]

	# 回城向乞丐打听彩依传闻；真实脚本会收走当前现金的一半。
	failure = _return_to_changan(vm, database)
	if not failure.is_empty():
		vm.free()
		return failure
	var cash_before_beggar := session.cash
	failure = _run_event(vm, database.event_objects[1900])
	if not failure.is_empty() or _messages != _message_range(6843, 6882) or session.cash != cash_before_beggar / 2 or database.scenes[117].script_on_enter != 22669:
		vm.free()
		return "乞丐传闻或林天南入口错误：failure=%s messages=%s cash=%d/%d enter=%d" % [failure, _messages, session.cash, cash_before_beggar, database.scenes[117].script_on_enter]

	# 再入尚书府遇见林天南，转到后院完成敌队 38 的七诀剑气剧情战。
	failure = _enter_mansion_hall(vm, database)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 117)
	if not _unsupported.is_empty() or _messages != _message_range(7150, 7229) or session.scene_index != 116 or database.scenes[116].script_on_enter != 22841:
		vm.free()
		return "林天南到访或后院决斗入口错误：messages=%s scene=%d enter=%d unsupported=%s" % [_messages, session.scene_index, database.scenes[116].script_on_enter, _unsupported]
	_clear_trace()
	var duel_scene := database.scenes[116]
	var duel_entry := duel_scene.script_on_enter
	vm.run_trigger(duel_entry)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(7236, 7284) or _battle_requests != [[38, 7, true]] or not vm.waiting_for_battle:
		var duel_waiting := vm.waiting_for_battle
		vm.free()
		return "林天南剧情战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, duel_waiting, _unsupported]
	failure = _resolve_battle(database, session, 38, 7, PackedInt32Array([525]), 38007, false)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _next_entries.is_empty():
		duel_scene.script_on_enter = _next_entries[-1]
	if not _unsupported.is_empty() or _messages != _message_range(7236, 7372) or database.scenes[123].script_on_enter != 23158:
		vm.free()
		return "林天南战后、月如约定或彩依采花剧情错误：messages=%s sickroom_enter=%d unsupported=%s" % [_messages, database.scenes[123].script_on_enter, _unsupported]

	# 返回病房目睹彩依强迫刘晋元服药，刘晋元醒来后向母亲求助。
	failure = _run_transition(vm, database.event_objects[2227], 107, Vector2i(1104, 1080))
	if not failure.is_empty():
		vm.free()
		return "决斗后没有返回刘晋元院外：%s" % failure
	failure = _run_transition(vm, database.event_objects[2071], 121, Vector2i(800, 656))
	if not failure.is_empty():
		vm.free()
		return "决斗后没有进入刘晋元居所：%s" % failure
	failure = _run_transition(vm, database.event_objects[2277], 122, Vector2i(736, 448))
	if not failure.is_empty():
		vm.free()
		return "决斗后没有进入刘晋元内厅：%s" % failure
	failure = _run_transition(vm, database.event_objects[2279], 123, Vector2i(800, 704))
	if not failure.is_empty():
		vm.free()
		return "决斗后没有进入病房：%s" % failure
	_run_scene_enter(vm, database, 123)
	if not _unsupported.is_empty() or _messages != _message_range(7373, 7443) or database.event_objects[2284].trigger_script != 23377:
		vm.free()
		return "彩依强迫服药剧情错误：messages=%s caiyi=%d unsupported=%s" % [_messages, database.event_objects[2284].trigger_script, _unsupported]
	failure = _run_event(vm, database.event_objects[2284])
	if not failure.is_empty() or _messages != [7444] or session.scene_index != 124:
		vm.free()
		return "病房调查没有进入刘晋元醒来场景：failure=%s messages=%s scene=%d" % [failure, _messages, session.scene_index]
	_run_scene_enter(vm, database, 124)
	if not _unsupported.is_empty() or _messages != _message_range(7445, 7476) or database.event_objects[2080].state != 2:
		vm.free()
		return "刘晋元醒来后的控诉剧情错误：messages=%s liu=%d unsupported=%s" % [_messages, database.event_objects[2080].state, _unsupported]

	# 刘晋元逃到院外，请云姨帮忙并取得三万文，随后在城中聘请茅山道士。
	failure = _leave_sickroom_to_courtyard(vm, database, 124)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_event(vm, database.event_objects[2080])
	if not failure.is_empty() or _messages != _message_range(7477, 7535) or database.event_objects[2077].state != 2 or database.event_objects[2320].trigger_script != 23719:
		vm.free()
		return "刘晋元求助或茅山道士入口错误：failure=%s messages=%s yunyi=%d taoist=%d" % [failure, _messages, database.event_objects[2077].state, database.event_objects[2320].trigger_script]
	var cash_before_aid := session.cash
	failure = _run_event(vm, database.event_objects[2077])
	if not failure.is_empty() or _messages != _message_range(7547, 7552) or session.cash != cash_before_aid + 30000:
		vm.free()
		return "云姨没有交付三万文：failure=%s messages=%s cash=%d/%d" % [failure, _messages, session.cash, cash_before_aid]
	failure = _return_to_changan(vm, database)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_transition(vm, database.event_objects[1885], 126, Vector2i(752, 680))
	if not failure.is_empty():
		vm.free()
		return "长安没有进入酒楼：%s" % failure
	var cash_before_wine := session.cash
	failure = _run_event(vm, database.event_objects[2299])
	if not failure.is_empty() or _messages != _message_range(6162, 6166) or session.cash != cash_before_wine - 100 or session.item_count(86) != 1:
		vm.free()
		return "酒楼没有售出作法用酒：failure=%s messages=%s cash=%d/%d wine=%d" % [failure, _messages, session.cash, cash_before_wine, session.item_count(86)]
	failure = _run_transition(vm, database.event_objects[2297], 127, Vector2i(720, 1304))
	if not failure.is_empty():
		vm.free()
		return "酒楼没有进入茅山道士所在区域：%s" % failure
	var cash_before_taoist := session.cash
	failure = _run_event(vm, database.event_objects[2320])
	if not failure.is_empty() or _messages != _message_range(7570, 7600) or session.cash != cash_before_taoist - 15000 or session.scene_index != 118 or database.scenes[118].script_on_enter != 23772:
		vm.free()
		return "茅山道士交易或返府入口错误：failure=%s messages=%s cash=%d/%d scene=%d enter=%d" % [failure, _messages, session.cash, cash_before_taoist, session.scene_index, database.scenes[118].script_on_enter]
	_run_scene_enter(vm, database, 118)
	if not _unsupported.is_empty() or _messages != _message_range(7601, 7644) or session.scene_index != 125:
		vm.free()
		return "茅山道士诊断剧情错误：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 125)
	if not _unsupported.is_empty() or _messages != _message_range(7645, 7692) or database.scenes[107].script_on_enter != 24103:
		vm.free()
		return "茅山道士作法失败剧情错误：messages=%s courtyard_enter=%d unsupported=%s" % [_messages, database.scenes[107].script_on_enter, _unsupported]

	# 离开病房后被花香迷倒；回城从河中救出酒剑仙，请其真正开坛作法。
	failure = _leave_sickroom_to_courtyard(vm, database, 125)
	if not failure.is_empty():
		vm.free()
		return failure
	_run_scene_enter(vm, database, 107)
	if not _unsupported.is_empty() or _messages != _message_range(7713, 7728) or database.event_objects[1912].state != 1:
		vm.free()
		return "茅山道士逃走后的花香剧情错误：messages=%s canal=%d unsupported=%s" % [_messages, database.event_objects[1912].state, _unsupported]
	failure = _return_to_changan(vm, database)
	if not failure.is_empty():
		vm.free()
		return failure
	failure = _run_event(vm, database.event_objects[1912])
	if not failure.is_empty() or _messages != _message_range(8074, 8153) or database.event_objects[1913].state != 2:
		vm.free()
		return "河中救出酒剑仙剧情错误：failure=%s messages=%s immortal=%d" % [failure, _messages, database.event_objects[1913].state]
	failure = _run_event(vm, database.event_objects[1913])
	if not failure.is_empty() or _messages != _message_range(8154, 8157) or session.scene_index != 114 or session.item_count(81) != 0 or session.item_count(82) != 0 or session.item_count(83) != 0 or session.item_count(86) != 0:
		vm.free()
		return "作法用品没有交给酒剑仙：failure=%s messages=%s scene=%d items=%d/%d/%d/%d" % [failure, _messages, session.scene_index, session.item_count(81), session.item_count(82), session.item_count(83), session.item_count(86)]
	_run_scene_enter(vm, database, 114)
	if not _unsupported.is_empty() or session.party_roles != PackedInt32Array([0]) or database.event_objects[2220].state != 2:
		vm.free()
		return "酒剑仙开坛布置错误：party=%s altar=%d unsupported=%s" % [session.party_roles, database.event_objects[2220].state, _unsupported]
	failure = _run_event(vm, database.event_objects[2220])
	if not failure.is_empty() or _messages != _message_range(8164, 8193) or session.party_roles != PackedInt32Array([0]) or database.event_objects[2084].state != 1:
		vm.free()
		return "醉仙封魔大法或月如离队错误：failure=%s messages=%s party=%s flower_event=%d" % [failure, _messages, session.party_roles, database.event_objects[2084].state]

	# 月如在后花园找到蝶精彩依；敌队 39 战后打开毒仙林入口。
	failure = _run_transition(vm, database.event_objects[2209], 115, Vector2i(1744, 1784))
	if not failure.is_empty():
		vm.free()
		return "开坛后没有进入尚书府幽径：%s" % failure
	failure = _run_transition(vm, database.event_objects[2223], 107, Vector2i(608, 1856))
	if not failure.is_empty():
		vm.free()
		return "开坛后没有抵达刘晋元院外：%s" % failure
	_run_scene_enter(vm, database, 107)
	_clear_trace()
	var butterfly_event := database.event_objects[2084]
	var butterfly_entry := butterfly_event.trigger_script
	vm.run_trigger(butterfly_entry, butterfly_event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(8195, 8224) or _battle_requests != [[39, 28, true]] or not vm.waiting_for_battle:
		var butterfly_waiting := vm.waiting_for_battle
		vm.free()
		return "蝶精彩依剧情战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, butterfly_waiting, _unsupported]
	failure = _resolve_battle(database, session, 39, 28, PackedInt32Array([468]), 39028, false)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(butterfly_event, butterfly_entry)
	if not _unsupported.is_empty() or session.party_roles != PackedInt32Array([2, 0]) or database.event_objects[2234].state != 1:
		vm.free()
		return "蝶精彩依战后没有恢复双人队或开启毒仙林：party=%s forest=%d unsupported=%s" % [session.party_roles, database.event_objects[2234].state, _unsupported]

	# 从后院追入毒仙林，抵达蜘蛛巢穴并击败敌队 42 毒娘子。
	failure = _run_transition(vm, database.event_objects[2070], 116, Vector2i(256, 1872))
	if not failure.is_empty():
		vm.free()
		return "刘晋元院外没有进入毒仙林后门：%s" % failure
	failure = _run_transition(vm, database.event_objects[2226], 138, Vector2i(480, 1808))
	if not failure.is_empty():
		vm.free()
		return "尚书府后门没有进入毒仙林迷宫：%s" % failure
	_run_scene_enter(vm, database, 138)
	if not _unsupported.is_empty() or session.music_number != 36 or session.battle_music_number != 39 or session.battlefield_number != 7:
		vm.free()
		return "毒仙林音乐或战场状态错误：music=%d battle_music=%d field=%d unsupported=%s" % [session.music_number, session.battle_music_number, session.battlefield_number, _unsupported]
	failure = _run_transition(vm, database.event_objects[2420], 137, Vector2i(1552, 1432))
	if not failure.is_empty():
		vm.free()
		return "毒仙林迷宫没有抵达蜘蛛巢穴：%s" % failure
	_clear_trace()
	var spider_event := database.event_objects[2416]
	var spider_entry := spider_event.trigger_script
	vm.run_trigger(spider_entry, spider_event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(8615, 8665) or _battle_requests != [[42, 27, true]] or not vm.waiting_for_battle:
		var spider_waiting := vm.waiting_for_battle
		vm.free()
		return "毒娘子战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, spider_waiting, _unsupported]
	failure = _resolve_battle(database, session, 42, 27, PackedInt32Array([435]), 42027, false)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(spider_event, spider_entry)
	if not _unsupported.is_empty() or _messages != _message_range(8615, 8691) or session.scene_index != 139 or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "毒娘子战后酒剑仙救场错误：messages=%s scene=%d party=%s unsupported=%s" % [_messages, session.scene_index, session.party_roles, _unsupported]

	# 彩依牺牲前依次回忆晋元救蝶、蝶仙化形和二人成亲，随后御剑抵达蜀山。
	_run_scene_enter(vm, database, 139)
	if not _unsupported.is_empty() or _messages != _message_range(8692, 8732) or session.scene_index != 140:
		vm.free()
		return "彩依牺牲前剧情没有进入第一段回忆：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 140)
	if not _unsupported.is_empty() or _messages != _message_range(8788, 8796) or session.scene_index != 139:
		vm.free()
		return "晋元救蝶回忆错误：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 139)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.scene_index != 141:
		vm.free()
		return "回忆转场没有进入蝶仙化形：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 141)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.scene_index != 142:
		vm.free()
		return "蝶仙化形回忆转场错误：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 142)
	if not _unsupported.is_empty() or _messages != _message_range(8797, 8811) or session.scene_index != 139:
		vm.free()
		return "刘家订婚回忆错误：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 139)
	if not _unsupported.is_empty() or _messages != _message_range(8733, 8787) or _rng_requests != [[3, 0, -1, 8]] or session.scene_index != 154:
		vm.free()
		return "彩依牺牲、酒剑仙反省或御剑过场错误：messages=%s rng=%s scene=%d unsupported=%s" % [_messages, _rng_requests, session.scene_index, _unsupported]
	_run_scene_enter(vm, database, 154)
	if not _unsupported.is_empty() or _messages != _message_range(8812, 8846) or PalSceneCatalog.name_for_scene_index(session.scene_index) != "蜀山·前山" or session.party_roles != PackedInt32Array([0, 2]) or session.party_world_position() != Vector2i(1024, 1600) or session.music_number != 69 or session.item_count(262) != 1 or session.item_count(267) != 1 or session.item_count(264) != 0:
		vm.free()
		return "第十一章结束状态错误：scene=%s party=%s pos=%s music=%d poison=%d earth=%d thunder=%d messages=%s unsupported=%s" % [PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.party_world_position(), session.music_number, session.item_count(262), session.item_count(267), session.item_count(264), _messages, _unsupported]
	vm.free()
	return ""


func _enter_mansion_hall(vm: ScriptVM, database: PalContentDatabase) -> String:
	var failure := _run_transition(vm, database.event_objects[1884], 113, Vector2i(1568, 1216))
	if not failure.is_empty():
		return "长安没有再次进入尚书府：%s" % failure
	_run_scene_enter(vm, database, 113)
	failure = _run_transition(vm, database.event_objects[2197], 117, Vector2i(1104, 648))
	if not failure.is_empty():
		return "尚书府外没有再次进入大厅：%s" % failure
	return ""


func _return_to_changan(vm: ScriptVM, database: PalContentDatabase) -> String:
	match vm.session.scene_index:
		120:
			var failure := _run_transition(vm, database.event_objects[2270], 117, Vector2i(848, 456))
			if not failure.is_empty():
				return "膳厅没有返回尚书府大厅：%s" % failure
		107:
			var failure := _run_transition(vm, database.event_objects[2072], 115, Vector2i(688, 1464))
			if not failure.is_empty():
				return "刘晋元院外没有返回尚书府幽径：%s" % failure
			failure = _run_transition(vm, database.event_objects[2224], 114, Vector2i(256, 768))
			if not failure.is_empty():
				return "尚书府幽径没有返回后院：%s" % failure
			failure = _run_transition(vm, database.event_objects[2210], 117, Vector2i(720, 520))
			if not failure.is_empty():
				return "尚书府后院没有返回大厅：%s" % failure
		_:
			pass
	if vm.session.scene_index == 117:
		var failure := _run_transition(vm, database.event_objects[2237], 113, Vector2i(1296, 1064))
		if not failure.is_empty():
			return "尚书府大厅没有返回府外：%s" % failure
	if vm.session.scene_index == 113:
		var failure := _run_transition(vm, database.event_objects[2198], 99, Vector2i(432, 312))
		if not failure.is_empty():
			return "尚书府没有返回长安：%s" % failure
	if vm.session.scene_index != 99:
		return "返回长安后的场景错误：%d" % vm.session.scene_index
	return ""


func _leave_sickroom_to_courtyard(vm: ScriptVM, database: PalContentDatabase, scene_index: int) -> String:
	if vm.session.scene_index != scene_index:
		return "病房阶段场景为 %d，预期 %d" % [vm.session.scene_index, scene_index]
	var exit_event_index := 2288 if scene_index == 124 else 2290
	var failure := _run_transition(vm, database.event_objects[exit_event_index], 122, Vector2i(352, 624))
	if not failure.is_empty():
		return "病房没有返回内厅：%s" % failure
	_run_scene_enter(vm, database, 122)
	failure = _run_transition(vm, database.event_objects[2278], 121, Vector2i(624, 552))
	if not failure.is_empty():
		return "刘晋元内厅没有返回一层：%s" % failure
	_run_scene_enter(vm, database, 121)
	failure = _run_transition(vm, database.event_objects[2274], 107, Vector2i(864, 1104))
	if not failure.is_empty():
		return "刘晋元居所没有返回院外：%s" % failure
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int, require_reward: bool) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "长安敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "长安敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "长安敌队 %d 没有完成真实胜利结算" % team_id
	if require_reward and (reward.experience <= 0 or reward.cash <= 0):
		return "长安敌队 %d 没有产生真实胜利奖励" % team_id
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
	_rng_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 120000:
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
