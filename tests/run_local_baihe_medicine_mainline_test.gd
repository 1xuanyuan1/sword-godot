# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证白河村安置赵灵儿、采集三味药材、配制六神丹并恢复三人队。
## 测试只比较消息编号、场景状态和道具变化，不输出或提交原版对白与画面资源。
extends SceneTree

var _messages: Array[int] = []
var _requested_scenes: Array[int] = []
var _next_entries: Array[int] = []
var _unsupported: Array[String] = []
var _music_requests: Array = []


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_baihe_medicine_mainline(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 白河村安置赵灵儿、银杏果／鲤鱼／鹿茸、六神丹及三人归队主线完成")
	quit(0)


func _test_baihe_medicine_mainline(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 48
	session.party_roles = PackedInt32Array([0, 2])
	session.initialize_role_state(database.player_roles)
	session.set_party_world_position(Vector2i(576, 1632))

	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: _requested_scenes.append(index))
	vm.script_finished.connect(func(next: int) -> void: _next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: _unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: _music_requests.append([number, loop, fade]))

	# 从隐龙窟结束状态进入白河村，并沿正式入口进入韩医仙屋外与诊厅。
	_run_stage(vm, database.scenes[48].script_on_enter)
	if not _unsupported.is_empty() or _next_entries != [15519] or _music_requests != [[12, true, 0.0]] or session.music_number != 12:
		vm.free()
		return "白河村进入状态不正确：next=%s music=%s/%d unsupported=%s" % [_next_entries, _music_requests, session.music_number, _unsupported]
	var failure := _run_transition(vm, database.event_objects[802], 51, Vector2i(416, 1264))
	if not failure.is_empty():
		vm.free()
		return "进入韩医仙屋外失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[885], 52, Vector2i(1280, 880))
	if not failure.is_empty():
		vm.free()
		return "进入韩医仙诊厅失败：%s" % failure

	# 初次诊治固定药方剧情，并开启屋外药材任务入口。
	var doctor := database.event_objects[905]
	_run_stage(vm, doctor.trigger_script, doctor.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4106, 4139) or _next_entries != [14554] or database.event_objects[897].trigger_script != 14652 or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "韩医仙初诊或药方入口不正确：messages=%s next=%s quest=%d party=%s unsupported=%s" % [_messages, _next_entries, database.event_objects[897].trigger_script, session.party_roles, _unsupported]
	doctor.trigger_script = _next_entries[0]

	# 退出诊厅后取得药方；月如留在诊厅，捕兽夹和借钓竿入口同时开放。
	failure = _run_transition(vm, database.event_objects[903], 51, Vector2i(896, 832))
	if not failure.is_empty():
		vm.free()
		return "初诊后退出诊厅失败：%s" % failure
	var quest_giver := database.event_objects[897]
	_run_stage(vm, quest_giver.trigger_script, quest_giver.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4203, 4219) or _requested_scenes != [52] or session.scene_index != 52 or _next_entries != [14688] or session.party_roles != PackedInt32Array([0]):
		vm.free()
		return "三味药方剧情状态不正确：messages=%s scenes=%s/%d next=%s party=%s unsupported=%s" % [_messages, _requested_scenes, session.scene_index, _next_entries, session.party_roles, _unsupported]
	if database.event_objects[797].state != 2 or database.event_objects[876].trigger_script != 14232:
		vm.free()
		return "药方剧情没有开放捕兽夹或钓竿：trap=%d fisherman=%d" % [database.event_objects[797].state, database.event_objects[876].trigger_script]
	quest_giver.trigger_script = _next_entries[0]

	# 离开诊厅，在韩医仙屋外采摘银杏果。
	failure = _run_transition(vm, database.event_objects[903], 51, Vector2i(896, 832))
	if not failure.is_empty():
		vm.free()
		return "药方后退出诊厅失败：%s" % failure
	var gingko_tree := database.event_objects[886]
	_run_stage(vm, gingko_tree.trigger_script, gingko_tree.object_id)
	if not _unsupported.is_empty() or _messages != [4193] or _next_entries != [14633] or session.item_count(281) != 1:
		vm.free()
		return "银杏果采集不正确：messages=%s next=%s count=%d unsupported=%s" % [_messages, _next_entries, session.item_count(281), _unsupported]
	gingko_tree.trigger_script = _next_entries[0]

	# 返回白河村民居借钓竿，再到河边使用真实物品脚本取得鲤鱼并归还钓竿。
	failure = _run_transition(vm, database.event_objects[884], 48, Vector2i(1600, 720))
	if not failure.is_empty():
		vm.free()
		return "韩医仙屋外返回白河村失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[803], 50, Vector2i(752, 456))
	if not failure.is_empty():
		vm.free()
		return "白河村进入钓竿民居失败：%s" % failure
	var fisherman := database.event_objects[876]
	_run_stage(vm, fisherman.trigger_script, fisherman.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4032, 4042) or _next_entries != [14249] or session.item_count(284) != 1:
		vm.free()
		return "借钓竿剧情不正确：messages=%s next=%s rod=%d unsupported=%s" % [_messages, _next_entries, session.item_count(284), _unsupported]
	fisherman.trigger_script = _next_entries[0]
	failure = _run_transition(vm, database.event_objects[870], 48, Vector2i(928, 1184))
	if not failure.is_empty():
		vm.free()
		return "钓竿民居返回白河村失败：%s" % failure
	var fishing_spot := database.event_objects[830]
	_face_event(session, fishing_spot)
	_run_stage(vm, database.item_definition(284).script_on_use, 0xffff)
	if not _unsupported.is_empty() or not vm.script_success or not vm.touch_trigger_armed or fishing_spot.trigger_script != 14358:
		vm.free()
		return "钓竿没有在河边安装捕鱼入口：success=%s armed=%s trigger=%d unsupported=%s" % [vm.script_success, vm.touch_trigger_armed, fishing_spot.trigger_script, _unsupported]
	_run_stage(vm, fishing_spot.trigger_script, fishing_spot.object_id)
	if not _unsupported.is_empty() or _messages != [4105] or session.item_count(282) != 1 or fisherman.trigger_script != 14252:
		vm.free()
		return "河边捕鱼没有取得鲤鱼或开启归还入口：messages=%s fish=%d fisherman=%d unsupported=%s" % [_messages, session.item_count(282), fisherman.trigger_script, _unsupported]
	failure = _run_transition(vm, database.event_objects[803], 50, Vector2i(752, 456))
	if not failure.is_empty():
		vm.free()
		return "捕鱼后重返钓竿民居失败：%s" % failure
	_run_stage(vm, fisherman.trigger_script, fisherman.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4043, 4044) or _next_entries != [14257] or session.item_count(284) != 0:
		vm.free()
		return "归还钓竿不正确：messages=%s next=%s rod=%d unsupported=%s" % [_messages, _next_entries, session.item_count(284), _unsupported]
	fisherman.trigger_script = _next_entries[0]

	# 前往白河村前山路取捕兽夹，面对鹿放置，执行真实 proximity 自动脚本并取得鹿茸。
	failure = _run_transition(vm, database.event_objects[870], 48, Vector2i(928, 1184))
	if not failure.is_empty():
		vm.free()
		return "归还钓竿后返回白河村失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[800], 47, Vector2i(1776, 1528))
	if not failure.is_empty():
		vm.free()
		return "白河村进入前山路失败：%s" % failure
	vm.set_scene_map(database.load_map(database.scenes[47].map_number))
	var deer := database.event_objects[796]
	var trap := database.event_objects[797]
	_run_stage(vm, trap.trigger_script, trap.object_id)
	if not _unsupported.is_empty() or _messages != [4247] or trap.state != 0 or session.item_count(285) != 1:
		vm.free()
		return "取得捕兽夹不正确：messages=%s state=%d count=%d unsupported=%s" % [_messages, trap.state, session.item_count(285), _unsupported]
	_face_event(session, deer)
	var trap_item := database.item_definition(285)
	_run_stage(vm, trap_item.script_on_use, 0xffff)
	if not _unsupported.is_empty() or not vm.script_success or trap.state != 2 or trap.position != deer.position:
		vm.free()
		return "捕兽夹没有放到鹿的路线：success=%s state=%d trap=%s deer=%s unsupported=%s" % [vm.script_success, trap.state, trap.position, deer.position, _unsupported]
	if trap_item.is_consuming():
		session.change_item_count(285, -1)
	for _step in range(3):
		vm._run_auto_script_step(trap)
	if trap.state != 0 or trap.auto_script != 14833 or deer.trigger_script != 14840:
		vm.free()
		return "捕兽夹 proximity 自动脚本没有捕获鹿：trap=%d/%d deer=%d" % [trap.state, trap.auto_script, deer.trigger_script]
	_run_stage(vm, deer.trigger_script, deer.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4248, 4252) or session.item_count(283) != 1 or deer.state != 0 or database.event_objects[887].state != 2:
		vm.free()
		return "取得鹿茸或放鹿剧情不正确：messages=%s antler=%d deer=%d released=%d unsupported=%s" % [_messages, session.item_count(283), deer.state, database.event_objects[887].state, _unsupported]

	# 回到韩医仙屋外交齐三味药，三件材料被消耗，月如归队并取得六神丹。
	failure = _run_transition(vm, database.event_objects[789], 48, Vector2i(576, 1632))
	if not failure.is_empty():
		vm.free()
		return "前山路返回白河村失败：%s" % failure
	failure = _run_transition(vm, database.event_objects[802], 51, Vector2i(416, 1264))
	if not failure.is_empty():
		vm.free()
		return "返回韩医仙屋外失败：%s" % failure
	_run_stage(vm, quest_giver.trigger_script, quest_giver.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4220, 4226) or _next_entries != [14716] or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "交付三味药后的队伍状态不正确：messages=%s next=%s party=%s unsupported=%s" % [_messages, _next_entries, session.party_roles, _unsupported]
	if session.item_count(281) != 0 or session.item_count(282) != 0 or session.item_count(283) != 0 or session.item_count(286) != 1 or doctor.trigger_script != 15042 or database.event_objects[908].trigger_script != 15046:
		vm.free()
		return "药材消耗、六神丹或诊厅入口不正确：281/282/283/286=%d/%d/%d/%d doctor=%d companion=%d" % [session.item_count(281), session.item_count(282), session.item_count(283), session.item_count(286), doctor.trigger_script, database.event_objects[908].trigger_script]
	quest_giver.trigger_script = _next_entries[0]

	# 进入诊厅，面对赵灵儿使用六神丹；完成后恢复李逍遥／赵灵儿／林月如三人队。
	failure = _run_transition(vm, database.event_objects[885], 52, Vector2i(1280, 880))
	if not failure.is_empty():
		vm.free()
		return "交药后进入诊厅失败：%s" % failure
	vm.set_scene_map(database.load_map(database.scenes[52].map_number))
	var linger := database.event_objects[904]
	_face_event(session, linger)
	var medicine := database.item_definition(286)
	_run_stage(vm, medicine.script_on_use, 0xffff)
	if not _unsupported.is_empty() or not vm.script_success or not vm.touch_trigger_armed or linger.trigger_script != 14864:
		vm.free()
		return "六神丹没有安装赵灵儿恢复入口：success=%s armed=%s trigger=%d unsupported=%s" % [vm.script_success, vm.touch_trigger_armed, linger.trigger_script, _unsupported]
	if medicine.is_consuming():
		session.change_item_count(286, -1)
	_run_stage(vm, linger.trigger_script, linger.object_id)
	if not _unsupported.is_empty() or _messages != _message_range(4254, 4345) or session.party_roles != PackedInt32Array([0, 1, 2]) or session.item_count(286) != 0:
		vm.free()
		return "赵灵儿恢复长剧情或三人归队不正确：messages=%s party=%s medicine=%d unsupported=%s" % [_messages, session.party_roles, session.item_count(286), _unsupported]
	if session.scene_index != 52 or session.party_world_position() != Vector2i(1424, 600) or session.music_number != 55 or linger.state != 0 or doctor.state != 2 or doctor.trigger_script != 15050 or database.event_objects[906].state != 0 or database.event_objects[907].state != 0:
		vm.free()
		return "六神丹剧情后的稳定场景状态不正确：scene=%d pos=%s music=%d linger=%d doctor=%d/%d companions=%d/%d" % [session.scene_index, session.party_world_position(), session.music_number, linger.state, doctor.state, doctor.trigger_script, database.event_objects[906].state, database.event_objects[907].state]
	vm.free()
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


func _face_event(session: GameSession, event: PalEventObject) -> void:
	session.party_direction = GameSession.DIR_EAST
	session.set_party_world_position(event.position + Vector2i(-16, -8))


func _clear_trace() -> void:
	_messages.clear()
	_requested_scenes.clear()
	_next_entries.clear()
	_unsupported.clear()
	_music_requests.clear()


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
