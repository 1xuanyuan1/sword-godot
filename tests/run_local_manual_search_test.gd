# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本地 PAL 数据验证客栈手动搜索的 half 格选择、真实触发脚本和初始房间物品。
extends SceneTree

const CollectibleClassifier := preload("res://src/game/pal_collectible_classifier.gd")


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		print("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return

	var session := GameSession.new()
	session.reset_new_game()
	var scene_events: Array[PalEventObject] = database.events_for_scene(0)
	var target: PalEventObject
	for event in scene_events:
		if event.is_visible() and event.is_search_trigger() and event.trigger_script > 0:
			target = event
			break
	if target == null:
		_fail("客栈没有可用于回归的手动搜索事件")
		return

	# 把目标放在朝东 SearchNear 的第一个前向检查点，验证真实 EventObject 数组的选择优先级。
	session.party_direction = GameSession.DIR_EAST
	session.set_party_world_position(target.position - GameSession.movement_for_direction(GameSession.DIR_EAST))
	var explorer = load("res://src/world/map_explorer.gd").new()
	var checkpoints: Array[Vector2i] = explorer._search_trigger_positions(session.party_world_position(), session.party_direction)
	var found: PalEventObject = explorer._find_search_event(checkpoints, scene_events)
	if found == null or found.object_id != target.object_id:
		explorer.free()
		_fail("客栈搜索命中错误：期望事件 %d，实际 %s" % [target.object_id, "无" if found == null else str(found.object_id)])
		return

	var unsupported: Array[String] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.set_scene_map(database.load_map(database.scenes[0].map_number))
	vm.unsupported_instruction.connect(
		func(index: int, operation: int) -> void:
			unsupported.append("0x%04X@%d" % [operation, index])
	)
	vm.run_trigger(found.trigger_script, found.object_id)
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames) and guard < 10000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1

	var failure := ""
	if not unsupported.is_empty():
		failure = "客栈手动搜索脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		failure = "客栈手动搜索脚本没有在保护帧数内结束"
	if failure.is_empty():
		failure = _test_initial_room_pickups(database)
	if failure.is_empty():
		failure = _test_collectible_classification(database)
	if failure.is_empty():
		failure = _test_repeatable_collectible_marker(database)
	if not failure.is_empty():
		explorer.free()
		vm.free()
		_fail(failure)
		return
	print("PASS: 客栈事件 %d 按官方 half 格搜索命中；室内/野外实体采集分类、拾取熄灭及重复鼠儿果均通过" % target.object_id)
	explorer.free()
	vm.free()
	quit(0)


func _test_initial_room_pickups(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var scene_events := database.events_for_scene(0)
	var explorer = load("res://src/world/map_explorer.gd").new()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	explorer._session = session
	explorer._collectible_classifier.configure(database)
	vm.instruction_started.connect(explorer._on_script_instruction_started)
	var unsupported: Array[String] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	for pickup in [{"object": 6, "script": 6324, "item": 201}, {"object": 7, "script": 6330, "item": 236}]:
		var event: PalEventObject = database.event_objects[int(pickup["object"]) - 1]
		if event.trigger_script != int(pickup["script"]) or not event.is_visible() or not event.is_search_trigger():
			explorer.free()
			vm.free()
			return "初始房间物品事件 %d 的入口或状态不正确" % int(pickup["object"])
		session.party_direction = GameSession.DIR_EAST
		session.set_party_world_position(event.position - GameSession.movement_for_direction(GameSession.DIR_EAST))
		var checkpoints: Array[Vector2i] = explorer._search_trigger_positions(session.party_world_position(), session.party_direction)
		var found: PalEventObject = explorer._find_search_event(checkpoints, scene_events)
		if found != event:
			explorer.free()
			vm.free()
			return "初始房间物品事件 %d 无法从相邻 half 格命中" % int(pickup["object"])
		explorer._active_collectible_event_id = event.object_id if explorer._collectible_classifier.is_available(event, session) else 0
		vm.run_trigger(event.trigger_script, event.object_id)
		_drive_script(vm)
		if session.item_count(int(pickup["item"])) != 1 or event.state != 0 or not session.is_collectible_marker_consumed(event.object_id):
			explorer.free()
			vm.free()
			return "物品 %d 没有进入背包或拾取点没有隐藏" % int(pickup["item"])
	if not unsupported.is_empty():
		explorer.free()
		vm.free()
		return "初始房间物品脚本遇到未支持指令：%s" % ", ".join(unsupported)
	explorer.free()
	vm.free()
	return ""


func _test_collectible_classification(database: PalContentDatabase) -> String:
	var classifier := CollectibleClassifier.new()
	classifier.configure(database)
	var session := GameSession.new()
	var expected_collectibles := [14, 167, 668, 2483, 3076]
	for event_object_id in expected_collectibles:
		var event: PalEventObject = database.event_objects[event_object_id - 1]
		if not classifier.is_available(event, session):
			return "真实实体采集物 EventObject %d 没有被识别" % event_object_id
	var excluded_events := [129, 1594, 2782, 3543, 4564]
	for event_object_id in excluded_events:
		var event: PalEventObject = database.event_objects[event_object_id - 1]
		if classifier.is_available(event, session):
			return "NPC、商贩或剧情事件 EventObject %d 被误判为采集物" % event_object_id
	return ""


func _test_repeatable_collectible_marker(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var event: PalEventObject = database.event_objects[3075]
	var original_state := event.state
	var original_trigger := event.trigger_script
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._session = session
	explorer._collectible_classifier.configure(database)
	explorer._active_collectible_event_id = event.object_id
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.instruction_started.connect(explorer._on_script_instruction_started)
	vm.run_trigger(event.trigger_script, event.object_id)
	_drive_script(vm)
	var classifier := CollectibleClassifier.new()
	classifier.configure(database)
	var failure := ""
	if session.item_count(104) != 1 or event.state != original_state or event.trigger_script != original_trigger:
		failure = "重复鼠儿果采摘改变了原版事件行为或没有获得物品"
	elif not session.is_collectible_marker_consumed(event.object_id) or classifier.is_available(event, session):
		failure = "重复鼠儿果首次采摘后没有永久熄灭标识"
	explorer.free()
	vm.free()
	return failure


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk) and guard < 10000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
