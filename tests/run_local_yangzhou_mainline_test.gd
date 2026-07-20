# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证扬州投宿、屋顶追贼、井底取证、两次审案与离城主线。
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
	var failure := _test_yangzhou_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 扬州投宿、两次女飞贼战、井底取证、审案与抵达蛤蟆谷前主线完成")
	quit(0)


func _test_yangzhou_mainline(database: PalContentDatabase) -> String:
	# 从鬼阴坛得救后抵达扬州前山道的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 82
	session.party_roles = PackedInt32Array([0, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(224, 848))
	session.set_item_count(267, 1)
	session.cash = 1000

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 由扬州前山道进入城外检查点，接受只准进、不准出的盘查后入城。
	var failure := _run_transition(vm, database.event_objects[1646], 78, Vector2i(416, 1456))
	if not failure.is_empty():
		vm.free()
		return "扬州前山道没有进入城外检查点：%s" % failure
	_run_scene_enter(vm, database, 78)
	if not _unsupported.is_empty() or session.music_number != 54 or session.battle_music_number != 38:
		vm.free()
		return "扬州城外音乐状态错误：music=%d battle_music=%d unsupported=%s" % [session.music_number, session.battle_music_number, _unsupported]
	failure = _run_event(vm, database.event_objects[1575])
	if not failure.is_empty() or _messages != _message_range(5088, 5091) or session.scene_index != 81:
		vm.free()
		return "扬州巡捕盘查或入城状态错误：failure=%s messages=%s scene=%d" % [failure, _messages, session.scene_index]

	# 进入客栈，先完成柳媚娘教训无赖的小插曲，再向掌柜投宿。
	failure = _run_transition(vm, database.event_objects[1622], 92, Vector2i(816, 904))
	if not failure.is_empty():
		vm.free()
		return "扬州街区没有进入客栈：%s" % failure
	failure = _run_event(vm, database.event_objects[1813])
	if not failure.is_empty() or _messages != _message_range(5105, 5113) or database.event_objects[1813].state != 0 or database.event_objects[1814].state != 2:
		vm.free()
		return "客栈无赖事件不完整：failure=%s messages=%s states=%d/%d" % [failure, _messages, database.event_objects[1813].state, database.event_objects[1814].state]
	failure = _run_event(vm, database.event_objects[1815])
	if not failure.is_empty() or _messages != _message_range(5142, 5162) or database.event_objects[1860].state != 1:
		vm.free()
		return "客栈投宿或房间入口未开启：failure=%s messages=%s room=%d" % [failure, _messages, database.event_objects[1860].state]
	failure = _run_event(vm, database.event_objects[1815])
	if not failure.is_empty() or _messages != _message_range(5163, 5165):
		vm.free()
		return "掌柜没有给出客房方向：failure=%s messages=%s" % [failure, _messages]

	# 进入客房后完成月如夜谈、失窃及李逍遥单人追贼状态。
	failure = _run_transition(vm, database.event_objects[1802], 96, Vector2i(400, 504))
	if not failure.is_empty():
		vm.free()
		return "客栈没有进入投宿客房：%s" % failure
	failure = _run_event(vm, database.event_objects[1860])
	if not failure.is_empty() or _messages != _message_range(5118, 5141):
		vm.free()
		return "夜宿失窃剧情不完整：failure=%s messages=%s" % [failure, _messages]
	if session.party_roles != PackedInt32Array([0]) or not session.night_palette or database.event_objects[1704].state != 2 or database.event_objects[1705].state != 2 or database.event_objects[1834].state != 1:
		vm.free()
		return "夜间追贼状态错误：party=%s night=%s roof=%d/%d inn=%d" % [session.party_roles, session.night_palette, database.event_objects[1704].state, database.event_objects[1705].state, database.event_objects[1834].state]

	# 返回大厅遭遇女飞贼；敌队 29／战场 21 胜利后月如与逍遥联手追上屋顶。
	failure = _run_transition(vm, database.event_objects[1854], 92, Vector2i(1200, 728))
	if not failure.is_empty():
		vm.free()
		return "客房没有返回客栈大厅：%s" % failure
	_clear_trace()
	var inn_thief := database.event_objects[1834]
	var inn_entry := inn_thief.trigger_script
	vm.run_trigger(inn_entry, inn_thief.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != [5166, 5167] or _battle_requests != [[29, 21, true]] or not vm.waiting_for_battle:
		var waiting := vm.waiting_for_battle
		vm.free()
		return "客栈女飞贼战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, waiting, _unsupported]
	failure = _resolve_battle(database, session, 29, 21, PackedInt32Array([478]), 29021)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(inn_thief, inn_entry)
	if not _unsupported.is_empty() or _messages != _message_range(5166, 5187) or session.party_roles != PackedInt32Array([2, 0]):
		vm.free()
		return "客栈女飞贼战后追逐状态错误：messages=%s party=%s unsupported=%s" % [_messages, session.party_roles, _unsupported]

	# 从客栈屋顶沿城墙追逐到东北屋面；正式路线同时覆盖可重复移动的飞贼事件。
	failure = _run_transition(vm, database.event_objects[1799], 84, Vector2i(912, 360))
	if not failure.is_empty():
		vm.free()
		return "客栈没有追到第一段屋顶：%s" % failure
	_run_scene_enter(vm, database, 84)
	if not _unsupported.is_empty() or session.battlefield_number != 30:
		vm.free()
		return "扬州屋顶战场状态错误：field=%d unsupported=%s" % [session.battlefield_number, _unsupported]
	failure = _run_event(vm, database.event_objects[1697])
	if not failure.is_empty():
		vm.free()
		return "屋顶飞贼第一段移动脚本失败：%s" % failure
	_tick_world(vm, 700)
	var moving_thief := database.event_objects[1697]
	if moving_thief.position != Vector2i(480, 144) or moving_thief.trigger_mode != PalEventObject.TRIGGER_TOUCH_FAR or moving_thief.auto_script != 17858:
		vm.free()
		return "屋顶飞贼第一段路线不完整：pos=%s mode=%d auto=%d" % [moving_thief.position, moving_thief.trigger_mode, moving_thief.auto_script]
	failure = _run_event(vm, database.event_objects[1697])
	if not failure.is_empty():
		vm.free()
		return "屋顶飞贼第二段移动脚本失败：%s" % failure
	_tick_world(vm, 700)
	if moving_thief.position != Vector2i(1136, 360) or moving_thief.trigger_mode != 0 or moving_thief.auto_script != 17863:
		vm.free()
		return "屋顶飞贼第二段路线不完整：pos=%s mode=%d auto=%d" % [moving_thief.position, moving_thief.trigger_mode, moving_thief.auto_script]
	failure = _run_transition(vm, database.event_objects[1696], 97, Vector2i(432, 1096))
	if not failure.is_empty():
		vm.free()
		return "第一段屋顶没有进入城墙：%s" % failure
	failure = _run_transition(vm, database.event_objects[1868], 85, Vector2i(352, 224))
	if not failure.is_empty():
		vm.free()
		return "城墙没有进入东北屋面：%s" % failure
	_run_scene_enter(vm, database, 85)

	# 天亮前再次击败敌队 29，取回女飞贼留下的布包 271。
	_clear_trace()
	var roof_thief := database.event_objects[1704]
	var roof_entry := roof_thief.trigger_script
	vm.run_trigger(roof_entry, roof_thief.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != [5188] or _battle_requests != [[29, 30, true]] or not vm.waiting_for_battle:
		var waiting := vm.waiting_for_battle
		vm.free()
		return "屋顶女飞贼战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, waiting, _unsupported]
	failure = _resolve_battle(database, session, 29, 30, PackedInt32Array([478]), 29030)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(roof_thief, roof_entry)
	if not _unsupported.is_empty() or _messages != _message_range(5188, 5193) or session.night_palette or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "屋顶女飞贼战后天亮状态错误：messages=%s night=%s party=%s unsupported=%s" % [_messages, session.night_palette, session.party_roles, _unsupported]
	failure = _run_event(vm, database.event_objects[1705])
	if not failure.is_empty() or _messages != [5276] or session.item_count(271) != 1:
		vm.free()
		return "屋顶没有取得布包 271：failure=%s messages=%s bag=%d" % [failure, _messages, session.item_count(271)]

	# 经城墙返回客栈，把布包交还古董商并得知紫金葫芦仍然失踪。
	failure = _run_transition(vm, database.event_objects[1699], 97, Vector2i(544, 1040))
	if not failure.is_empty():
		vm.free()
		return "东北屋面没有返回城墙：%s" % failure
	failure = _run_transition(vm, database.event_objects[1865], 84, Vector2i(464, 152))
	if not failure.is_empty():
		vm.free()
		return "城墙没有返回客栈屋顶：%s" % failure
	failure = _run_transition(vm, database.event_objects[1693], 92, Vector2i(736, 496))
	if not failure.is_empty():
		vm.free()
		return "屋顶没有返回客栈：%s" % failure
	failure = _run_transition(vm, database.event_objects[1802], 96, Vector2i(400, 504))
	if not failure.is_empty():
		vm.free()
		return "客栈没有返回古董商房间：%s" % failure
	var merchant := database.event_objects[1857]
	failure = _run_event(vm, merchant)
	if not failure.is_empty() or _messages != _message_range(5283, 5285):
		vm.free()
		return "古董商失窃状态错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_event(vm, merchant)
	if not failure.is_empty() or _messages != _message_range(5286, 5287):
		vm.free()
		return "古董商财物失窃说明不完整：failure=%s messages=%s" % [failure, _messages]
	var bag := database.item_definition(271)
	if bag == null or bag.script_on_use != 39728:
		vm.free()
		return "布包 271 缺少真实交还脚本"
	session.set_party_world_position(merchant.position)
	session.party_direction = GameSession.DIR_EAST
	failure = _run_item(vm, session, bag)
	if not failure.is_empty() or merchant.trigger_script != 18471 or session.item_count(271) != 1:
		vm.free()
		return "布包没有交给古董商：failure=%s merchant=%d bag=%d" % [failure, merchant.trigger_script, session.item_count(271)]
	failure = _run_event(vm, merchant)
	if not failure.is_empty() or _messages != _message_range(5288, 5320) or session.item_count(271) != 0 or database.event_objects[1724].state != 0 or database.event_objects[1725].state != 2:
		vm.free()
		return "归还布包或开启姬三娘宅状态错误：failure=%s messages=%s widow=%d/%d" % [failure, _messages, database.event_objects[1724].state, database.event_objects[1725].state]

	# 到姬三娘宅询问，月如负气离队；返回街区后由进入脚本续接屋顶事件。
	failure = _run_transition(vm, database.event_objects[1854], 92, Vector2i(1200, 728))
	if not failure.is_empty():
		vm.free()
		return "古董商房间没有返回客栈：%s" % failure
	failure = _run_transition(vm, database.event_objects[1798], 81, Vector2i(704, 544))
	if not failure.is_empty():
		vm.free()
		return "客栈没有返回扬州街区：%s" % failure
	failure = _run_transition(vm, database.event_objects[1620], 83, Vector2i(208, 376))
	if not failure.is_empty():
		vm.free()
		return "扬州街区没有进入北城区：%s" % failure
	failure = _run_transition(vm, database.event_objects[1653], 88, Vector2i(816, 1224))
	if not failure.is_empty():
		vm.free()
		return "北城区没有进入姬三娘宅：%s" % failure
	failure = _run_event(vm, database.event_objects[1725])
	if not failure.is_empty() or _messages != _message_range(5198, 5269) or session.party_roles != PackedInt32Array([0]) or database.scenes[83].script_on_enter != 18432:
		vm.free()
		return "姬三娘试探或月如离队状态错误：failure=%s messages=%s party=%s enter=%d" % [failure, _messages, session.party_roles, database.scenes[83].script_on_enter]
	failure = _run_transition(vm, database.event_objects[1723], 83, Vector2i(1088, 464))
	if not failure.is_empty():
		vm.free()
		return "姬三娘宅没有返回北城区：%s" % failure
	_run_scene_enter(vm, database, 83)
	if not _unsupported.is_empty() or _messages != _message_range(5272, 5275) or database.event_objects[1706].state != 2:
		vm.free()
		return "月如屋顶后续没有开启：messages=%s event=%d unsupported=%s" % [_messages, database.event_objects[1706].state, _unsupported]

	# 由北城区登上屋顶找到月如，目睹姬三娘把证物丢入井中并恢复双人队。
	failure = _run_transition(vm, database.event_objects[1654], 85, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "北城区没有登上月如所在屋顶：%s" % failure
	failure = _run_event(vm, database.event_objects[1706])
	if not failure.is_empty() or _messages != _message_range(5378, 5403) or session.party_roles != PackedInt32Array([2, 0]):
		vm.free()
		return "月如和好或井口观察剧情错误：failure=%s messages=%s party=%s" % [failure, _messages, session.party_roles]

	# 从姬三娘宅井口进入暗室和井底密道，取得紫金葫芦后被官差押往府衙。
	failure = _run_transition(vm, database.event_objects[1700], 83, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "屋顶没有返回北城区：%s" % failure
	failure = _run_transition(vm, database.event_objects[1653], 88, Vector2i(816, 1224))
	if not failure.is_empty():
		vm.free()
		return "北城区没有重返姬三娘宅：%s" % failure
	failure = _run_transition(vm, database.event_objects[1735], 89, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "井口没有进入隐藏暗室：%s" % failure
	_run_scene_enter(vm, database, 89)
	if not _unsupported.is_empty() or _messages != [5531] or database.event_objects[1782].state != 2:
		vm.free()
		return "暗室秘门没有开启：messages=%s door=%d unsupported=%s" % [_messages, database.event_objects[1782].state, _unsupported]
	failure = _run_transition(vm, database.event_objects[1738], 91, Vector2i(512, 1360))
	if not failure.is_empty():
		vm.free()
		return "暗室没有进入井底密道：%s" % failure
	_run_scene_enter(vm, database, 91)
	if not _unsupported.is_empty() or _messages != _message_range(5913, 5917):
		vm.free()
		return "首次进入井底密道剧情错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_event(vm, database.event_objects[1765])
	if not failure.is_empty() or _messages != [5404] or session.scene_index != 83:
		vm.free()
		return "井底紫金葫芦取证或返城错误：failure=%s messages=%s scene=%d" % [failure, _messages, session.scene_index]
	_run_scene_enter(vm, database, 83)
	if not _unsupported.is_empty() or _messages != _message_range(5509, 5512) or session.scene_index != 80:
		vm.free()
		return "官差包围或押往府衙状态错误：messages=%s scene=%d unsupported=%s" % [_messages, session.scene_index, _unsupported]

	# 首次审案会把月如扣押、李逍遥释放查案，并恢复逍遥普通场景造型。
	_run_scene_enter(vm, database, 80)
	if not _unsupported.is_empty() or _messages != _message_range(5414, 5508):
		vm.free()
		return "首次审案对白不完整：messages=%s unsupported=%s" % [_messages, _unsupported]
	if session.party_roles != PackedInt32Array([0]) or database.player_roles.scene_sprite_numbers[0] != 2 or database.event_objects[1755].state != 1:
		vm.free()
		return "首次审案后队伍、造型或牢房状态错误：party=%s sprite=%d prisoner=%d" % [session.party_roles, database.player_roles.scene_sprite_numbers[0], database.event_objects[1755].state]

	# 离开府衙后进入牢房，按真实脚本缴纳探监费并向月如承诺抓到真凶。
	failure = _run_transition(vm, database.event_objects[1592], 83, Vector2i(512, 928))
	if not failure.is_empty():
		vm.free()
		return "府衙没有返回北城区：%s" % failure
	failure = _run_transition(vm, database.event_objects[1652], 87, Vector2i(464, 1816))
	if not failure.is_empty():
		vm.free()
		return "北城区没有进入地牢入口：%s" % failure
	failure = _run_transition(vm, database.event_objects[1722], 90, Vector2i(1056, 1264))
	if not failure.is_empty():
		vm.free()
		return "地牢入口没有进入牢房：%s" % failure
	var cash_before_jail := session.cash
	failure = _run_event(vm, database.event_objects[1757])
	if not failure.is_empty() or _messages != _message_range(5918, 5922) or session.cash != cash_before_jail - 300:
		vm.free()
		return "探监许可费流程错误：failure=%s messages=%s cash=%d/%d" % [failure, _messages, session.cash, cash_before_jail]
	failure = _run_event(vm, database.event_objects[1755])
	if not failure.is_empty() or _messages != _message_range(5520, 5530):
		vm.free()
		return "牢房探望月如对白不完整：failure=%s messages=%s" % [failure, _messages]

	# 返回井底密道，击败敌队 30／战场 30 的黑衣女贼集团。
	failure = _run_transition(vm, database.event_objects[1740], 87, Vector2i(448, 1568))
	if not failure.is_empty():
		vm.free()
		return "牢房没有返回地牢入口：%s" % failure
	failure = _run_transition(vm, database.event_objects[1721], 83, Vector2i(1664, 1024))
	if not failure.is_empty():
		vm.free()
		return "地牢入口没有返回北城区：%s" % failure
	failure = _run_transition(vm, database.event_objects[1653], 89, Vector2i(816, 1224))
	if not failure.is_empty():
		vm.free()
		return "北城区没有从已开启入口进入姬三娘暗室：%s" % failure
	_run_scene_enter(vm, database, 89)
	failure = _run_transition(vm, database.event_objects[1738], 91, Vector2i(512, 1360))
	if not failure.is_empty():
		vm.free()
		return "暗室没有再次进入井底密道：%s" % failure
	_run_scene_enter(vm, database, 91)
	_clear_trace()
	var true_thief := database.event_objects[1767]
	var true_thief_entry := true_thief.trigger_script
	vm.run_trigger(true_thief_entry, true_thief.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _messages != _message_range(5532, 5538) or _battle_requests != [[30, 16, true]] or not vm.waiting_for_battle:
		var waiting := vm.waiting_for_battle
		vm.free()
		return "黑衣女贼战入口错误：messages=%s battles=%s waiting=%s unsupported=%s" % [_messages, _battle_requests, waiting, _unsupported]
	failure = _resolve_battle(database, session, 30, 16, PackedInt32Array([526, 479, 526]), 30016)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(true_thief, true_thief_entry)
	if not _unsupported.is_empty() or session.scene_index != 80:
		vm.free()
		return "黑衣女贼战后没有押往府衙：scene=%d unsupported=%s" % [session.scene_index, _unsupported]

	# 复审洗清嫌疑、月如归队；领取 5500 文悬赏后由北门抵达蛤蟆谷前山路。
	_run_scene_enter(vm, database, 80)
	if not _unsupported.is_empty() or _messages != _message_range(5539, 5680) or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "真凶复审或月如归队错误：messages=%s party=%s unsupported=%s" % [_messages, session.party_roles, _unsupported]
	var cash_before_reward := session.cash
	failure = _run_event(vm, database.event_objects[1593])
	if not failure.is_empty() or _messages != _message_range(5868, 5906) or session.cash != cash_before_reward + 5500:
		vm.free()
		return "扬州悬赏结算错误：failure=%s messages=%s cash=%d/%d" % [failure, _messages, session.cash, cash_before_reward]
	failure = _run_transition(vm, database.event_objects[1592], 83, Vector2i(512, 928))
	if not failure.is_empty():
		vm.free()
		return "府衙复审后没有返回北城区：%s" % failure
	failure = _run_event(vm, database.event_objects[1674])
	if not failure.is_empty() or _messages != _message_range(5689, 5690):
		vm.free()
		return "北门巡捕没有放行：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[1657], 104, Vector2i(224, 1072))
	if not failure.is_empty():
		vm.free()
		return "扬州北门没有抵达蛤蟆谷前山路：%s" % failure
	_run_scene_enter(vm, database, 104)
	if PalSceneCatalog.name_for_scene_index(session.scene_index) != "山路·蛤蟆谷前" or session.party_roles != PackedInt32Array([0, 2]) or session.item_count(267) != 1:
		vm.free()
		return "第九章结束状态错误：scene=%s party=%s earth=%d" % [PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, session.item_count(267)]
	vm.free()
	return ""


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "扬州敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "扬州敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null or reward.experience <= 0 or reward.cash <= 0:
		return "扬州敌队 %d 没有产生真实胜利奖励" % team_id
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


func _run_item(vm: ScriptVM, session: GameSession, item: PalItemDefinition) -> String:
	var entry := item.script_on_use
	_run_stage(vm, entry, 0xffff)
	if not _next_entries.is_empty():
		item.script_on_use = _next_entries[-1]
	if vm.script_success and item.is_consuming():
		session.change_item_count(item.object_id, -1)
	if not _unsupported.is_empty():
		return "物品 %d 出现未支持指令：%s" % [item.object_id, _unsupported]
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


func _tick_world(vm: ScriptVM, frame_count: int) -> void:
	for _frame in range(frame_count):
		vm.tick_frame()


func _clear_trace() -> void:
	_messages.clear()
	_requested_scenes.clear()
	_next_entries.clear()
	_unsupported.clear()
	_music_requests.clear()
	_battle_requests.clear()


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 80000:
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
