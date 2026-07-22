# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证回魂仙梦南诏、巫后、水魔兽、十年前余杭与水灵珠主线。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _battle_requests: Array = []
var _shop_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_nanzhao_flashback_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 回魂仙梦南诏、巫后、水魔兽、十年前余杭、水灵珠与凤凰蛋壳主线完成")
	quit(0)


func _test_nanzhao_flashback_mainline(database: PalContentDatabase) -> String:
	# 从女娲神殿送入回魂仙梦后的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 226
	session.party_roles = PackedInt32Array([0])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(896, 832))
	for item_id in [186, 262, 263, 264, 266, 267, 274, 276]:
		session.set_item_count(item_id, 1)
	session.cash = 10000

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))
	vm.shop_requested.connect(func(store_id: int, buying: bool) -> void: _shop_requests.append([store_id, buying]))

	# 回魂仙梦入口连续完成两场黑苗守卫战，再进入十年前南诏。
	_run_scene_enter(vm, database, 226)
	if not _unsupported.is_empty() or _messages != _message_range(11612, 11613) or session.party_world_position() != Vector2i(1568, 1696) or session.battlefield_number != 9 or database.scenes[226].script_on_enter != 35476:
		vm.free()
		return "回魂仙梦入口状态错误：messages=%s pos=%s field=%d enter=%d unsupported=%s" % [_messages, session.party_world_position(), session.battlefield_number, database.scenes[226].script_on_enter, _unsupported]
	var failure := _run_multi_battle_event(vm, database, database.event_objects[4252], [
		{"team": 102, "field": 9, "objects": PackedInt32Array([485, 485]), "seed": 102009},
		{"team": 113, "field": 9, "objects": PackedInt32Array([527, 527, 527]), "seed": 113009},
	])
	if not failure.is_empty() or _messages != _message_range(11614, 11672) or database.player_roles.scene_sprite_numbers[0] != 563:
		vm.free()
		return "回魂仙梦守卫战或剧情造型错误：failure=%s messages=%s sprite=%d" % [failure, _messages, database.player_roles.scene_sprite_numbers[0]]
	failure = _run_transition(vm, database.event_objects[4266], 234, Vector2i(1680, 1720))
	if not failure.is_empty() or _messages != _message_range(11673, 11686):
		vm.free()
		return "回魂仙梦没有进入十年前南诏：failure=%s messages=%s" % [failure, _messages]
	_run_scene_enter(vm, database, 234)
	if not _unsupported.is_empty() or _messages != _message_range(11687, 11724) or database.scenes[234].script_on_enter != 35860:
		vm.free()
		return "十年前南诏入场剧情错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[234].script_on_enter, _unsupported]

	# 进入王宫外观看巫后被捕，再穿过秘道寻找天蛇杖。
	failure = _run_transition(vm, database.event_objects[4381], 228, Vector2i(1216, 1504))
	if not failure.is_empty():
		vm.free()
		return "十年前南诏没有进入王宫外：%s" % failure
	_run_scene_enter(vm, database, 228)
	failure = _run_event(vm, database.event_objects[4295])
	if not failure.is_empty() or _messages != _message_range(11804, 11856):
		vm.free()
		return "南诏王宫外长剧情错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[4272], 235, Vector2i(640, 1600))
	if not failure.is_empty():
		vm.free()
		return "王宫外没有进入王宫：%s" % failure
	failure = _run_transition(vm, database.event_objects[4403], 237, Vector2i(720, 1656))
	if not failure.is_empty():
		vm.free()
		return "南诏王宫没有进入秘道外：%s" % failure
	failure = _run_transition(vm, database.event_objects[4466], 229, Vector2i(336, 696))
	if not failure.is_empty():
		vm.free()
		return "秘道外没有进入秘道：%s" % failure
	_run_scene_enter(vm, database, 229)
	failure = _run_transition(vm, database.event_objects[4297], 241, Vector2i(496, 1464))
	if not failure.is_empty():
		vm.free()
		return "秘道机关没有进入第一段内层：%s" % failure
	failure = _run_transition(vm, database.event_objects[4477], 242, Vector2i(1744, 1672))
	if not failure.is_empty():
		vm.free()
		return "秘道第一段没有进入第二段：%s" % failure
	failure = _run_transition(vm, database.event_objects[4482], 243, Vector2i(1696, 1568))
	if not failure.is_empty():
		vm.free()
		return "秘道第二段没有进入第三段：%s" % failure
	failure = _run_transition(vm, database.event_objects[4502], 245, Vector2i(624, 856))
	if not failure.is_empty():
		vm.free()
		return "秘道第三段没有进入天蛇杖房：%s" % failure
	failure = _run_event(vm, database.event_objects[4563])
	if not failure.is_empty() or _messages != [12157] or session.item_count(195) != 1 or database.event_objects[4483].state != 0:
		vm.free()
		return "天蛇杖取得状态错误：failure=%s messages=%s staff=%d guardian=%d" % [failure, _messages, session.item_count(195), database.event_objects[4483].state]

	# 带天蛇杖原路返回地牢，救出巫后并进入水底秘道。
	for transition in [
		[4561, 243, Vector2i(720, 648)],
		[4501, 242, Vector2i(336, 392)],
		[4481, 241, Vector2i(912, 952)],
		[4476, 229, Vector2i(1008, 712)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "携天蛇杖返回地牢失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[4296], 237, Vector2i(848, 1528))
	if not failure.is_empty():
		vm.free()
		return "携天蛇杖离开秘道失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[4465], 235, Vector2i(1296, 1272))
	if not failure.is_empty():
		vm.free()
		return "携天蛇杖返回王宫失败：%s" % failure
	for transition in [
		[4401, 236, Vector2i(704, 1696)],
		[4446, 227, Vector2i(560, 824)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "携天蛇杖返回地牢失败：%s" % failure
	_run_scene_enter(vm, database, 227)
	failure = _run_event(vm, database.event_objects[4269])
	if not failure.is_empty() or _messages != _message_range(11865, 11935) or session.scene_index != 227 or session.item_count(195) != 1:
		vm.free()
		return "天蛇杖开牢第一段错误：failure=%s messages=%s scene=%d staff=%d" % [failure, _messages, session.scene_index, session.item_count(195)]
	failure = _run_event(vm, database.event_objects[4269])
	if not failure.is_empty() or _messages != _message_range(11936, 11937) or _requested_scenes != [233] or session.scene_index != 233 or session.item_count(195) != 0:
		vm.free()
		return "天蛇杖开牢或救出巫后错误：failure=%s messages=%s scenes=%s/%d staff=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.item_count(195)]
	_run_scene_enter(vm, database, 233)
	if not _unsupported.is_empty() or _messages != _message_range(11940, 11967) or session.party_roles != PackedInt32Array([0, 3]) or session.party_world_position() != Vector2i(1408, 1088):
		vm.free()
		return "巫后脱困后的队伍状态错误：messages=%s party=%s pos=%s unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), _unsupported]
	failure = _run_event(vm, database.event_objects[4379])
	if not failure.is_empty() or _messages != _message_range(11968, 12003) or _requested_scenes != [232] or session.scene_index != 232:
		vm.free()
		return "巫后逃离地牢或进入水底秘道错误：failure=%s messages=%s scenes=%s/%d" % [failure, _messages, _requested_scenes, session.scene_index]
	_run_scene_enter(vm, database, 232)
	if not _unsupported.is_empty() or session.party_roles != PackedInt32Array([3, 0]) or session.party_world_position() != Vector2i(336, 376) or session.music_number != 82:
		vm.free()
		return "水底秘道入口状态错误：party=%s pos=%s music=%d unsupported=%s" % [session.party_roles, session.party_world_position(), session.music_number, _unsupported]

	# 水魔兽两次遇水复生；第二次战后巫后留下，李逍遥被送往十年前余杭。
	failure = _run_battle_event(vm, database, database.event_objects[4351], 315, 64, PackedInt32Array([547]), 315064)
	if not failure.is_empty() or _messages != _message_range(12004, 12034):
		vm.free()
		return "水底秘道前段水魔兽战错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[4348], 230, Vector2i(320, 368))
	if not failure.is_empty():
		vm.free()
		return "水底秘道前段没有进入后段：%s" % failure
	failure = _run_battle_event(vm, database, database.event_objects[4311], 315, 4, PackedInt32Array([547]), 315004)
	if not failure.is_empty():
		vm.free()
		return "水底秘道后段水魔兽战错误：%s" % failure
	failure = _run_event(vm, database.event_objects[4313])
	if not failure.is_empty() or _messages != _message_range(12035, 12049) or _requested_scenes != [231] or session.scene_index != 231 or session.party_roles != PackedInt32Array([3]):
		vm.free()
		return "水魔兽战后巫后剧情错误：failure=%s messages=%s scenes=%s/%d party=%s" % [failure, _messages, _requested_scenes, session.scene_index, session.party_roles]
	_run_scene_enter(vm, database, 231)
	if not _unsupported.is_empty() or _messages != _message_range(12050, 12051) or session.party_roles != PackedInt32Array([0]) or session.party_world_position() != Vector2i(528, 1464):
		vm.free()
		return "巫后送行状态错误：messages=%s party=%s pos=%s unsupported=%s" % [_messages, session.party_roles, session.party_world_position(), _unsupported]
	failure = _run_transition(vm, database.event_objects[4347], 246, session.party_world_position(), false)
	if not failure.is_empty():
		vm.free()
		return "回魂仙梦没有抵达十年前余杭：%s" % failure

	# 姥姥交付包袱；把包袱交给集市商人后，连续开启幼年李逍遥与水灵珠入口。
	_run_scene_enter(vm, database, 246)
	if not _unsupported.is_empty() or _messages != _message_range(12192, 12204):
		vm.free()
		return "十年前余杭山神庙外剧情错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_transition(vm, database.event_objects[4571], 248, Vector2i(464, 504))
	if not failure.is_empty():
		vm.free()
		return "山神庙外没有进入庙内：%s" % failure
	_run_scene_enter(vm, database, 248)
	if not _unsupported.is_empty() or _messages != _message_range(12205, 12207):
		vm.free()
		return "山神庙内入口剧情错误：messages=%s unsupported=%s" % [_messages, _unsupported]
	failure = _run_event(vm, database.event_objects[4590])
	if not failure.is_empty() or _messages != _message_range(12210, 12225):
		vm.free()
		return "姥姥与李逍遥首轮对话错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_event(vm, database.event_objects[4590])
	if not failure.is_empty() or _messages != _message_range(12226, 12227):
		vm.free()
		return "姥姥与李逍遥续轮对话错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_event(vm, database.event_objects[4588])
	if not failure.is_empty() or _messages != _message_range(12228, 12241) or session.item_count(292) != 1:
		vm.free()
		return "姥姥没有交付包袱：failure=%s messages=%s bag=%d" % [failure, _messages, session.item_count(292)]
	for transition in [
		[4587, 246, Vector2i(1024, 704)],
		[4570, 249, Vector2i(208, 184)],
		[4595, 247, Vector2i(336, 1176)],
		[4578, 253, Vector2i(240, 1640)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "前往十年前余杭集市失败：%s" % failure
	var bag := database.item_definition(292)
	var market_receiver := database.event_objects[4639]
	if bag == null or bag.script_on_use != 39844:
		vm.free()
		return "包袱 292 缺少真实交付脚本"
	session.set_party_world_position(market_receiver.position)
	session.party_direction = GameSession.DIR_EAST
	failure = _run_item(vm, session, bag)
	if not failure.is_empty() or not vm.script_success or market_receiver.trigger_script != 37539 or session.item_count(292) != 0:
		vm.free()
		return "包袱没有交给集市商人：failure=%s success=%s receiver=%d bag=%d" % [failure, vm.script_success, market_receiver.trigger_script, session.item_count(292)]
	failure = _run_event(vm, market_receiver)
	if not failure.is_empty() or _messages != _message_range(12267, 12277) or _requested_scenes != [248] or session.scene_index != 248 or database.scenes[248].script_on_enter != 37569:
		vm.free()
		return "包袱交付后没有返回山神庙：failure=%s messages=%s scenes=%s/%d enter=%d" % [failure, _messages, _requested_scenes, session.scene_index, database.scenes[248].script_on_enter]
	_run_scene_enter(vm, database, 248)
	if not _unsupported.is_empty() or _messages != _message_range(12278, 12296) or _requested_scenes != [253] or session.scene_index != 253 or database.scenes[253].script_on_enter != 37642:
		vm.free()
		return "姥姥送行或返回集市错误：messages=%s scenes=%s/%d enter=%d unsupported=%s" % [_messages, _requested_scenes, session.scene_index, database.scenes[253].script_on_enter, _unsupported]
	_run_scene_enter(vm, database, 253)
	if not _unsupported.is_empty() or _messages != _message_range(12297, 12340) or database.event_objects[4576].state != 2:
		vm.free()
		return "集市冲突或幼年逍遥入口错误：messages=%s child=%d unsupported=%s" % [_messages, database.event_objects[4576].state, _unsupported]

	# 回到山神庙外确认水灵珠，再到木匠铺购买真实 3 号商店中的木剑 166。
	for transition in [
		[4634, 247, Vector2i(1648, 1160)],
		[4579, 249, Vector2i(1776, 1896)],
		[4594, 246, Vector2i(1424, 936)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "返回山神庙外失败：%s" % failure
	failure = _run_event(vm, database.event_objects[4576])
	if not failure.is_empty() or _messages != _message_range(12341, 12345) or database.event_objects[4576].trigger_script != 37802 or database.event_objects[4575].state != 2:
		vm.free()
		return "幼年逍遥首次现身错误：failure=%s messages=%s next=%d pearl_event=%d" % [failure, _messages, database.event_objects[4576].trigger_script, database.event_objects[4575].state]
	failure = _run_event(vm, database.event_objects[4576])
	if not failure.is_empty() or _messages != _message_range(12346, 12347):
		vm.free()
		return "幼年逍遥现身续跑错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_event(vm, database.event_objects[4575])
	if not failure.is_empty() or _messages != _message_range(12348, 12375) or database.event_objects[4577].state != 2:
		vm.free()
		return "水灵珠线索或木剑要求错误：failure=%s messages=%s exchange=%d" % [failure, _messages, database.event_objects[4577].state]
	for transition in [
		[4570, 249, Vector2i(208, 184)],
		[4595, 247, Vector2i(336, 1176)],
		[4578, 253, Vector2i(240, 1640)],
		[4635, 256, Vector2i(672, 880)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "前往木匠铺失败：%s" % failure
	failure = _run_event(vm, database.event_objects[4649])
	if not failure.is_empty() or _messages != _message_range(12376, 12381) or _shop_requests != [[3, true]] or 166 not in database.stores[3].item_ids:
		vm.free()
		return "木匠铺木剑商店错误：failure=%s messages=%s shops=%s items=%s" % [failure, _messages, _shop_requests, database.stores[3].item_ids]
	# 商店买卖结算已有独立门禁；这里模拟玩家在已验证商店中合法买入一把木剑。
	session.set_item_count(166, 1)
	failure = _run_transition(vm, database.event_objects[4648], 253, Vector2i(384, 1344))
	if not failure.is_empty():
		vm.free()
		return "木匠铺没有返回集市：%s" % failure
	for transition in [
		[4634, 247, Vector2i(1648, 1160)],
		[4579, 249, Vector2i(1776, 1896)],
		[4594, 246, Vector2i(1424, 936)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "携木剑返回幼年逍遥处失败：%s" % failure

	# 木剑交换取得水灵珠，回到现在后由续跑脚本正式取得金凤凰蛋壳。
	failure = _run_event(vm, database.event_objects[4577])
	if not failure.is_empty() or _messages != _message_range(12388, 12394) or _requested_scenes != [202] or session.scene_index != 202 or session.item_count(166) != 0 or session.item_count(265) != 1 or database.scenes[202].script_on_enter != 34621:
		vm.free()
		return "木剑交换或水灵珠取得错误：failure=%s messages=%s scenes=%s/%d sword=%d water=%d enter=%d" % [failure, _messages, _requested_scenes, session.scene_index, session.item_count(166), session.item_count(265), database.scenes[202].script_on_enter]
	_run_scene_enter(vm, database, 202)
	if not _unsupported.is_empty() or _messages != _message_range(11420, 11453) or session.item_count(275) != 1 or session.item_count(265) != 1 or session.item_count(266) != 1 or session.item_count(276) != 1 or session.party_roles != PackedInt32Array([0, 4]) or session.music_number != 55 or database.scenes[202].script_on_enter != 34711:
		vm.free()
		return "第十五章结束状态错误：messages=%s egg=%d water=%d fire=%d horn=%d party=%s music=%d enter=%d unsupported=%s" % [_messages, session.item_count(275), session.item_count(265), session.item_count(266), session.item_count(276), session.party_roles, session.music_number, database.scenes[202].script_on_enter, _unsupported]
	for item_id in [186, 262, 263, 264, 265, 266, 267, 274, 275, 276]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "第十五章结束关键物品 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
	vm.free()
	return ""


func _run_multi_battle_event(vm: ScriptVM, database: PalContentDatabase, event: PalEventObject, battles: Array) -> String:
	var entry := event.trigger_script
	_clear_trace()
	vm.run_trigger(entry, event.object_id)
	for index in range(battles.size()):
		_drive_script(vm)
		var battle: Dictionary = battles[index]
		var expected_request := [int(battle["team"]), int(battle["field"]), true]
		if not _unsupported.is_empty() or _battle_requests.size() != index + 1 or _battle_requests[index] != expected_request or not vm.waiting_for_battle:
			return "第 %d 场战斗入口错误：battles=%s waiting=%s unsupported=%s" % [index + 1, _battle_requests, vm.waiting_for_battle, _unsupported]
		var failure := _resolve_battle(database, vm.session, int(battle["team"]), int(battle["field"]), battle["objects"], int(battle["seed"]))
		if not failure.is_empty():
			return failure
		vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	_update_event_entry(event, entry)
	return "" if _unsupported.is_empty() else "连续战斗后出现未支持指令：%s" % _unsupported


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
	return "" if _unsupported.is_empty() else "敌队 %d 战后出现未支持指令：%s" % [team_id, _unsupported]


func _resolve_battle(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_objects: PackedInt32Array, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "回魂仙梦敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	var actual_objects := PackedInt32Array(controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id))
	if actual_objects != expected_objects:
		return "回魂仙梦敌队 %d 对象不正确：%s" % [team_id, actual_objects]
	for enemy_index in range(controller.enemies.size()):
		controller._apply_enemy_damage(enemy_index, controller.enemies[enemy_index].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null:
		return "回魂仙梦敌队 %d 没有完成真实胜利结算" % team_id
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
	_battle_requests.clear()
	_shop_requests.clear()


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
