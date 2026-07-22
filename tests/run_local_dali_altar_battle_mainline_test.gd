# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证灵儿拜母、五灵珠祭坛、祈雨、大理庆典、地魔兽与第十八章入口。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

const SACRED_PEARL_ITEM := 260
const ELEMENTAL_PEARLS := [263, 264, 265, 266, 267]

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
	var failure := _test_dali_altar_battle_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 灵儿拜母、五灵珠祭坛、祈雨、大理庆典、地魔兽与第十八章入口主线完成")
	quit(0)


func _test_dali_altar_battle_mainline(database: PalContentDatabase) -> String:
	# 从第十六章交付三十六只傀儡虫后的稳定状态继续。
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 173
	session.party_roles = PackedInt32Array([1, 0, 4])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(720, 616))
	for item_id in [186, 262, 263, 264, 265, 266, 267, 274, 294]:
		session.set_item_count(item_id, 1)
	database.scenes[173].script_on_enter = 32941
	database.event_objects[3029].trigger_script = 32942
	database.event_objects[3070].trigger_script = 32134
	database.event_objects[3107].trigger_script = 32122
	database.event_objects[3875].trigger_script = 35294

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: _battle_requests.append([team, field, boss]))

	# 经圣姑屋外、神木林和灵山抵达战时大理。
	var failure := ""
	for transition in [
		[3022, 175, Vector2i(1424, 712)],
		[3069, 185, Vector2i(1808, 1160)],
		[3296, 178, Vector2i(1664, 1440)],
		[3107, 258, Vector2i(208, 504)],
	]:
		failure = _run_transition(vm, database.event_objects[int(transition[0])], int(transition[1]), transition[2])
		if not failure.is_empty():
			vm.free()
			return "前往战时大理失败：%s" % failure
	_run_scene_enter(vm, database, 258)
	if not _unsupported.is_empty() or not _messages.is_empty() or session.battlefield_number != 7 or session.battle_music_number != 41 or session.music_number != 21:
		vm.free()
		return "大理城郊战场入口错误：messages=%s field=%d battle_music=%d music=%d unsupported=%s" % [_messages, session.battlefield_number, session.battle_music_number, session.music_number, _unsupported]

	# 两段大理战场各执行一场真实黑苗遭遇，锁定正式敌队、对象与战场背景。
	failure = _run_battle_event(vm, database, database.event_objects[4699], 319, 7, false, PackedInt32Array([485, 549]), 319007)
	if not failure.is_empty() or not _messages.is_empty():
		vm.free()
		return "大理城郊黑苗遭遇错误：failure=%s messages=%s" % [failure, _messages]
	failure = _run_transition(vm, database.event_objects[4658], 259, Vector2i(336, 1736))
	if not failure.is_empty():
		vm.free()
		return "大理城郊没有进入试炼窟外战场：%s" % failure
	failure = _run_battle_event(vm, database, database.event_objects[4753], 102, 7, false, PackedInt32Array([485, 485]), 102007)
	if not failure.is_empty() or not _messages.is_empty():
		vm.free()
		return "试炼窟外黑苗遭遇错误：failure=%s messages=%s" % [failure, _messages]

	# 穿过女娲神殿外防线，灵儿祭拜巫后并取得祭天所需的圣灵珠和装备。
	failure = _run_transition(vm, database.event_objects[4705], 262, Vector2i(560, 1272))
	if not failure.is_empty():
		vm.free()
		return "大理战场没有抵达女娲神殿外：%s" % failure
	_run_scene_enter(vm, database, 262)
	if not _unsupported.is_empty() or not _messages.is_empty() or database.scenes[262].script_on_enter != 38317:
		vm.free()
		return "女娲神殿外防线入口错误：messages=%s enter=%d unsupported=%s" % [_messages, database.scenes[262].script_on_enter, _unsupported]
	failure = _run_transition(vm, database.event_objects[4812], 264, Vector2i(288, 1392))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿外没有进入神殿：%s" % failure
	failure = _run_transition(vm, database.event_objects[4864], 263, Vector2i(288, 1392))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿没有进入灵儿拜母剧情：%s" % failure
	_run_scene_enter(vm, database, 263)
	if not _unsupported.is_empty() or _messages != _message_range(12460, 12481) or _requested_scenes != [264] or session.scene_index != 264 or session.party_roles != PackedInt32Array([1, 0, 4]) or session.party_world_position() != Vector2i(1136, 776):
		vm.free()
		return "灵儿拜母剧情或返回落点错误：messages=%s scenes=%s/%d party=%s pos=%s unsupported=%s" % [_messages, _requested_scenes, session.scene_index, session.party_roles, session.party_world_position(), _unsupported]
	for item_id in [SACRED_PEARL_ITEM, 234, 195]:
		if session.item_count(item_id) != 1:
			vm.free()
			return "灵儿拜母后道具 %d 数量错误：%d" % [item_id, session.item_count(item_id)]
	if database.event_objects[4854].trigger_script != 3667:
		vm.free()
		return "灵儿拜母后女娲神殿族长入口未更新：%d" % database.event_objects[4854].trigger_script

	# 到祭坛先使用圣灵珠开启五个石孔，再按真实物品脚本逐颗放置五灵珠。
	failure = _run_transition(vm, database.event_objects[4841], 271, Vector2i(480, 1488))
	if not failure.is_empty():
		vm.free()
		return "女娲神殿没有抵达五灵珠祭坛：%s" % failure
	var sacred_pearl := database.item_definition(SACRED_PEARL_ITEM)
	if sacred_pearl == null or sacred_pearl.script_on_use != 39781:
		vm.free()
		return "圣灵珠 260 的祭坛使用入口错误"
	_face_event(session, database.event_objects[4922])
	failure = _run_item(vm, session, sacred_pearl)
	if not failure.is_empty() or session.item_count(SACRED_PEARL_ITEM) != 0 or database.event_objects[4922].state != 0 or database.event_objects[4923].state != 1:
		vm.free()
		return "圣灵珠没有开启祭坛：failure=%s sacred=%d marker=%d/%d" % [failure, session.item_count(SACRED_PEARL_ITEM), database.event_objects[4922].state, database.event_objects[4923].state]
	for event_index in range(4924, 4929):
		if database.event_objects[event_index].state != 2:
			vm.free()
			return "圣灵珠没有开启石孔 EventObject %d：state=%d" % [event_index + 1, database.event_objects[event_index].state]

	var pearl_slots := [
		[263, 4924, 39794], # 风：左
		[266, 4925, 39812], # 火：上
		[264, 4926, 39800], # 雷：右
		[267, 4927, 39818], # 土：下
		[265, 4928, 39806], # 水：中，最后一颗触发祈雨
	]
	for slot_index in range(pearl_slots.size()):
		var item_id := int(pearl_slots[slot_index][0])
		var event_index := int(pearl_slots[slot_index][1])
		var expected_entry := int(pearl_slots[slot_index][2])
		var pearl := database.item_definition(item_id)
		if pearl == null or pearl.script_on_use != expected_entry:
			vm.free()
			return "灵珠 %d 的祭坛使用入口错误" % item_id
		_face_event(session, database.event_objects[event_index])
		failure = _run_item(vm, session, pearl)
		if not failure.is_empty() or session.item_count(item_id) != 0 or database.event_objects[event_index].state != 3:
			vm.free()
			return "灵珠 %d 放置错误：failure=%s count=%d state=%d" % [item_id, failure, session.item_count(item_id), database.event_objects[event_index].state]
		var expected_scenes: Array = [257] if slot_index == pearl_slots.size() - 1 else []
		if _requested_scenes != expected_scenes:
			vm.free()
			return "灵珠 %d 放置后的场景请求错误：%s" % [item_id, _requested_scenes]
	if session.scene_index != 257 or session.party_world_position() != Vector2i(1152, 1040):
		vm.free()
		return "五灵珠摆满后的祭坛入口错误：scene=%d pos=%s" % [session.scene_index, session.party_world_position()]

	# 五珠摆满后依次经过军队撤退、废大理、降雨和神殿外祈雨动画，再回祭坛。
	var ceremony_stages := [
		[257, 260, 38537, _message_range(12490, 12492)],
		[260, 273, 38321, []],
		[273, 274, 38351, []],
		[274, 275, 38376, []],
		[275, 257, 38443, _message_range(12483, 12489)],
		[257, 261, 38537, _message_range(12493, 12494)],
	]
	for stage in ceremony_stages:
		var source_scene := int(stage[0])
		var target_scene := int(stage[1])
		_run_scene_enter(vm, database, source_scene)
		if not _unsupported.is_empty() or _messages != stage[3] or _requested_scenes != [target_scene] or session.scene_index != target_scene:
			vm.free()
			return "祭雨场景 %d→%d 错误：messages=%s scenes=%s/%d unsupported=%s" % [source_scene, target_scene, _messages, _requested_scenes, session.scene_index, _unsupported]
		if database.scenes[source_scene].script_on_enter != int(stage[2]):
			vm.free()
			return "祭雨场景 %d 的后续入口错误：%d" % [source_scene, database.scenes[source_scene].script_on_enter]

	# 庆典入口归还圣灵珠和五灵珠；地魔兽使用敌队 287／战场 36，战后进入无底深渊。
	_clear_trace()
	var celebration_scene := database.scenes[261]
	var celebration_entry := celebration_scene.script_on_enter
	vm.run_trigger(celebration_entry, 0xffff)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[287, 36, true]] or not vm.waiting_for_battle or _messages != _message_range(12502, 12523):
		var celebration_failure := "大理庆典或地魔兽入口错误：entry=%d messages=%s battles=%s waiting=%s unsupported=%s" % [celebration_entry, _messages, _battle_requests, vm.waiting_for_battle, _unsupported]
		vm.free()
		return celebration_failure
	failure = _resolve_battle(database, session, 287, 36, PackedInt32Array([466]), 287036)
	if not failure.is_empty():
		vm.free()
		return failure
	vm.complete_battle(PalBattleController.BattleResult.VICTORY)
	_drive_script(vm)
	if not _next_entries.is_empty():
		celebration_scene.script_on_enter = _next_entries[-1]
	if not _unsupported.is_empty() or _messages != _message_range(12502, 12534) or _requested_scenes != [290] or session.scene_index != 290 or session.party_world_position() != Vector2i(816, 1320):
		vm.free()
		return "地魔兽战后或无底深渊转场错误：messages=%s scenes=%s/%d pos=%s unsupported=%s" % [_messages, _requested_scenes, session.scene_index, session.party_world_position(), _unsupported]
	for item_id in [SACRED_PEARL_ITEM] + ELEMENTAL_PEARLS:
		if session.item_count(item_id) != 1:
			vm.free()
			return "祭雨后归还的灵珠 %d 数量错误：%d" % [item_id, session.item_count(item_id)]

	# 运行下一章入口，固定无底深渊的正式落点、音乐和战场作为第十八章边界。
	_run_scene_enter(vm, database, 290)
	if not _unsupported.is_empty() or not _messages.is_empty() or not _requested_scenes.is_empty() or session.scene_index != 290 or session.party_roles != PackedInt32Array([1, 0, 4]) or session.party_world_position() != Vector2i(240, 1672) or session.music_number != 26 or session.battlefield_number != 58 or database.scenes[290].script_on_enter != 3798:
		vm.free()
		return "第十八章稳定入口错误：messages=%s scenes=%s/%d party=%s pos=%s music=%d field=%d enter=%d unsupported=%s" % [_messages, _requested_scenes, session.scene_index, session.party_roles, session.party_world_position(), session.music_number, session.battlefield_number, database.scenes[290].script_on_enter, _unsupported]
	vm.free()
	return ""


func _run_battle_event(vm: ScriptVM, database: PalContentDatabase, event: PalEventObject, team_id: int, field_id: int, boss: bool, expected_objects: PackedInt32Array, seed_value: int) -> String:
	var entry := event.trigger_script
	_clear_trace()
	vm.run_trigger(entry, event.object_id)
	_drive_script(vm)
	if not _unsupported.is_empty() or _battle_requests != [[team_id, field_id, boss]] or not vm.waiting_for_battle:
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


func _run_item(vm: ScriptVM, session: GameSession, item: PalItemDefinition) -> String:
	var entry := item.script_on_use
	_run_stage(vm, entry, 0xffff)
	if not _next_entries.is_empty():
		item.script_on_use = _next_entries[-1]
	if vm.script_success and item.is_consuming():
		session.change_item_count(item.object_id, -1)
	return "" if _unsupported.is_empty() else "物品 %d 出现未支持指令：%s" % [item.object_id, _unsupported]


func _face_event(session: GameSession, event: PalEventObject) -> void:
	session.party_direction = GameSession.DIR_SOUTH
	session.set_party_world_position(event.position + Vector2i(16, -8))


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
