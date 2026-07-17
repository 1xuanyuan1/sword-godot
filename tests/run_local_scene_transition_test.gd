# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_inn_exit(database)
	if failure.is_empty():
		failure = await _test_inn_exit_runtime()
	if failure.is_empty():
		failure = await _test_bath_cutscene_runtime()
	if failure.is_empty():
		failure = _test_stairs(database)
	if failure.is_empty():
		failure = _test_kitchen_entry(database)
	if failure.is_empty():
		failure = _test_scene_teleport(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 客栈出口、仙灵岛洗澡与倒地动作、楼梯动画、厨房入口及场景传送回归通过")
	quit(0)


func _test_inn_exit(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.run_trigger(4667, 1)
	var failure := ""
	if not unsupported.is_empty():
		failure = "客栈出口脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif vm.running or vm.waiting_for_dialog or vm.waiting_for_frames:
		failure = "客栈出口脚本没有结束"
	elif requested_scenes != [2] or session.scene_index != 2:
		failure = "客栈出口没有请求进入场景 3：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(1440, 1536):
		failure = "客栈出口落点错误：%s" % session.party_world_position()
	vm.free()
	return failure


func _test_inn_exit_runtime() -> String:
	# 使用真实 MapExplorer、Tween 和延后场景切换，覆盖“0059 后紧跟 0050”时
	# 渐显抢先杀掉渐隐 Tween、导致 VM 永久等待的生命周期回归。
	PalDebugCheckpoint._pending = {
		"id": "inn_exit_runtime_test",
		"scene": 0,
		"script": 0,
		"position": Vector2i(1408, 1520),
	}
	var explorer: Control = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	var exit_event: PalEventObject = explorer._scene_events[0]
	explorer._run_event_trigger(exit_event)
	await create_timer(1.3).timeout
	var failure := ""
	var vm: ScriptVM = explorer._script_vm
	if explorer._session.scene_index != 2 or explorer._pending_scene_index != -1:
		failure = "客栈出口真实转场没有稳定进入场景 3：scene=%d pending=%d" % [explorer._session.scene_index, explorer._pending_scene_index]
	elif explorer._screen_fade_active or explorer._fade_overlay.visible or vm.waiting_for_screen_fade:
		failure = "客栈出口渐变结束后仍锁住输入：screen=%s overlay=%s vm=%s" % [explorer._screen_fade_active, explorer._fade_overlay.visible, vm.waiting_for_screen_fade]
	elif explorer._touch_scan_active or explorer._active_trigger_event != null or vm.running or vm.waiting_for_dialog or vm.waiting_for_rng or vm.waiting_for_battle:
		failure = "客栈出口真实转场残留运行时门禁"
	else:
		var before: Vector2i = explorer._session.party_world_position()
		var movement := GameSession.movement_for_direction(GameSession.DIR_NORTH)
		if not explorer._try_move(movement) or explorer._session.party_world_position() == before:
			failure = "客栈出口落地后无法实际移动一步"
	explorer.queue_free()
	await process_frame
	return failure


func _test_bath_cutscene_runtime() -> String:
	PalDebugCheckpoint._pending = {
		"id": "bath_cutscene_runtime_test",
		# 事件对象 204 的剧情入口和赵灵儿 209 都属于场景 13（地图 119）。
		# 不能只在相似的户外地图验证李逍遥动作，否则会漏掉真正的花树背景和赵灵儿。
		"scene": 13,
		"script": 9649,
		"event": 204,
		"position": Vector2i(1104, 1432),
		"music": 61,
	}
	var explorer: Control = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	explorer.set_process(false)
	var vm: ScriptVM = explorer._script_vm
	var bath_event: PalEventObject = explorer._database.event_objects[208]
	var bath_event_is_loaded := false
	for event in explorer._scene_events:
		if event.object_id == 209:
			bath_event_is_loaded = true
			break
	var failure := ""
	if explorer._session.scene_index != 13 or explorer._database.scenes[13].map_number != 119:
		failure = "洗澡过场没有载入花树场景 13 / 地图 119"
	elif not bath_event_is_loaded or bath_event.sprite_number != 339:
		failure = "花树场景缺少赵灵儿事件对象 209 / MGO 339"
	if not failure.is_empty():
		explorer.queue_free()
		await process_frame
		return failure
	var samples: Array[Dictionary] = []
	var sampled_frames: Array[int] = []
	var can_capture_pixels := DisplayServer.get_name() != "headless"
	var saw_li_costume_scene_visible := false
	var guard := 0
	while guard < 1000 and 16 not in sampled_frames:
		if (
			explorer._database.player_roles.scene_sprite_numbers[0] == 361
			and explorer._script_camera_offset == Vector2i.ZERO
			and not explorer._screen_fade_active
			and not explorer._fade_overlay.visible
		):
			saw_li_costume_scene_visible = true
		# 稳定可见段包括固定镜头后的洗澡姿势第 0 帧，以及惊叫后的第 9–16 帧。
		# 第 8 帧紧接第二次 0050，本来就只作为渐隐转场起始姿势，不要求静止截图。
		var should_sample: bool = (
			bath_event.current_frame == 0 and explorer._script_camera_offset == Vector2i(192, 96)
		) or bath_event.current_frame >= 9 and bath_event.current_frame <= 16
		if should_sample and bath_event.current_frame not in sampled_frames and not explorer._screen_fade_active:
			sampled_frames.append(bath_event.current_frame)
			var nonblack_pixels := -1
			var image: Image = null
			if can_capture_pixels:
				image = explorer.get_viewport().get_texture().get_image()
				image.resize(320, 200, Image.INTERPOLATE_NEAREST)
				nonblack_pixels = 0
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						var color := image.get_pixel(x, y)
						if color.r > 0.04 or color.g > 0.04 or color.b > 0.04:
							nonblack_pixels += 1
			samples.append({
				"frame": bath_event.current_frame,
				"nonblack": nonblack_pixels,
				"overlay": explorer._fade_overlay.visible,
				"alpha": explorer._fade_overlay.modulate.a,
			})
			if can_capture_pixels and nonblack_pixels > 5000:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://generated/pal/visual_tests"))
				image.save_png(ProjectSettings.globalize_path("res://generated/pal/visual_tests/bath_cutscene_%02d.png" % bath_event.current_frame))
		if explorer._screen_fade_active or vm.waiting_for_screen_fade:
			await create_timer(0.7).timeout
		elif vm.waiting_for_dialog:
			vm.advance_dialog()
		elif vm.waiting_for_frames:
			if vm.tick_frame():
				explorer._refresh_world()
			await process_frame
		else:
			await process_frame
		guard += 1
	var minimum_nonblack_pixels := 64000
	var all_sampled_frames_uncovered := true
	for sample in samples:
		if int(sample["nonblack"]) >= 0:
			minimum_nonblack_pixels = mini(minimum_nonblack_pixels, int(sample["nonblack"]))
		if bool(sample["overlay"]) or float(sample["alpha"]) > 0.001:
			all_sampled_frames_uncovered = false
	if bath_event.current_frame < 16:
		failure = "洗澡过场没有执行到 MGO 339 第 16 帧：frame=%d" % bath_event.current_frame
	elif not saw_li_costume_scene_visible:
		failure = "发现衣服后的李逍遥动作场景仍被黑色遮罩覆盖"
	elif sampled_frames.size() != 9 or 0 not in sampled_frames:
		failure = "洗澡过场没有捕获洗澡姿势及惊叫后的完整可见帧：%s" % [samples]
	elif not all_sampled_frames_uncovered:
		failure = "洗澡或晃衣服画面仍被黑色遮罩覆盖：%s" % [samples]
	elif can_capture_pixels and minimum_nonblack_pixels < 5000:
		failure = "洗澡过场至少一帧仍接近全黑：%s" % [samples]
	elif explorer._screen_fade_active or explorer._fade_overlay.visible or explorer._fade_overlay.modulate.a > 0.001:
		failure = "洗澡及晃衣服动作结束后仍残留黑色遮罩"
	# 继续完成偷看剧情，再触发 EventObject 205 的后续追打段。官方脚本在两次
	# 006E 小步移动后切到 Sprite 193，并用 0015 的第 0 帧表现李逍遥倒地。
	if failure.is_empty():
		var finish_guard := 0
		while finish_guard < 3000 and (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk or vm.waiting_for_party_ride or vm.waiting_for_screen_fade):
			if explorer._screen_fade_active or vm.waiting_for_screen_fade:
				await create_timer(0.7).timeout
			elif vm.waiting_for_dialog:
				vm.advance_dialog()
			elif vm.waiting_for_frames or vm.waiting_for_party_walk or vm.waiting_for_party_ride:
				if vm.tick_frame():
					explorer._refresh_world()
				await process_frame
			else:
				await process_frame
			finish_guard += 1
		var knockdown_event: PalEventObject = explorer._database.event_objects[204]
		if vm.running or knockdown_event.state <= 0 or knockdown_event.trigger_script != 9792:
			failure = "洗澡剧情没有正确启用后续追打事件 205：running=%s state=%d trigger=%d cursor=%d" % [vm.running, knockdown_event.state, knockdown_event.trigger_script, vm._cursor]
		else:
			explorer._run_event_trigger(knockdown_event)
			var knockdown_guard := 0
			var saw_knockdown_pose := false
			while knockdown_guard < 1000 and not saw_knockdown_pose:
				saw_knockdown_pose = (
					explorer._database.player_roles.scene_sprite_numbers[0] == 193
					and explorer._session.scripted_party_frame(0) == 0
					and vm.waiting_for_dialog
				)
				if saw_knockdown_pose:
					break
				if vm.waiting_for_dialog:
					vm.advance_dialog()
				elif vm.waiting_for_frames or vm.waiting_for_party_walk or vm.waiting_for_party_ride:
					if vm.tick_frame():
						explorer._refresh_world()
					await process_frame
				else:
					await process_frame
				knockdown_guard += 1
			if not saw_knockdown_pose:
				failure = "追打剧情没有执行到李逍遥 Sprite 193 第 0 帧倒地动作"
			else:
				var sprite: PalSprite = explorer._player_sprite_for_role(0)
				var displayed_frame: PalIndexedImage = explorer._party_frame(sprite, 0, 0)
				var expected_frame := RleDecoder.decode(sprite.get_frame(0))
				if not displayed_frame.is_valid() or displayed_frame.indices != expected_frame.indices:
					failure = "残留步态标志覆盖了李逍遥 Sprite 193 第 0 帧倒地动作"
				elif can_capture_pixels:
					var knockdown_image := explorer.get_viewport().get_texture().get_image()
					knockdown_image.resize(320, 200, Image.INTERPOLATE_NEAREST)
					knockdown_image.save_png(ProjectSettings.globalize_path("res://generated/pal/visual_tests/bath_cutscene_knockdown.png"))
	explorer.queue_free()
	await process_frame
	return failure


func _test_stairs(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	var stairs_event: PalEventObject = database.event_objects[2]
	session.set_party_world_position(stairs_event.position)
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._database = database
	explorer._session = session
	explorer._scene_events = database.events_for_scene(0)
	explorer._script_vm = vm
	var next_entries: Array[int] = []
	var steps: Array[int] = []
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.script_finished.connect(explorer._on_script_finished)
	vm.party_step_performed.connect(func() -> void: steps.append(1))
	var touch_triggered: bool = explorer._trigger_touch_event()
	var guard := 0
	while vm.running and guard < 100:
		vm.tick_frame()
		guard += 1
	explorer._continue_touch_scan()
	var failure := ""
	if not touch_triggered:
		failure = "客栈楼梯没有由真实接触范围自动触发"
	elif session.party_world_position() != stairs_event.position + Vector2i(-64, -64):
		failure = "客栈楼梯自动移动脚本落点错误：%s" % session.party_world_position()
	elif next_entries != [42]:
		failure = "客栈楼梯触发入口没有保持可重复"
	elif steps.size() != 8:
		failure = "客栈楼梯没有执行完整的 8 步行走动画：%d" % steps.size()
	explorer.free()
	vm.free()
	return failure


func _test_kitchen_entry(database: PalContentDatabase) -> String:
	# 模拟首段剧情已经完成后的场景状态；8145 是 7952 执行后返回的稳定入口。
	database.scenes[0].script_on_enter = 8145
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 2
	var portal_vm := ScriptVM.new()
	portal_vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	portal_vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	portal_vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	portal_vm.run_trigger(4631, 52)
	var failure := ""
	if not unsupported.is_empty():
		failure = "厨房入口脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif requested_scenes != [0] or session.scene_index != 0:
		failure = "厨房入口没有请求进入场景 1：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(1248, 1104):
		failure = "厨房入口落点错误：%s" % session.party_world_position()
	portal_vm.free()
	if not failure.is_empty():
		return failure

	var enter_vm := ScriptVM.new()
	enter_vm.configure(database, session)
	var messages: Array[int] = []
	var next_entries: Array[int] = []
	enter_vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	enter_vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	enter_vm.run_trigger(database.scenes[0].script_on_enter)
	if not messages.is_empty():
		failure = "进入厨房后错误地重播了 %d 条开场消息" % messages.size()
	elif next_entries != [8145]:
		failure = "厨房所属场景没有保持稳定进入入口：%s" % next_entries
	enter_vm.free()
	return failure


func _test_scene_teleport(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 5 # 场景 6 的离开脚本入口为 6051。
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var unsupported: Array[String] = []
	var requested_scenes: Array[int] = []
	var sounds: Array[int] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(39677)
	var failure := ""
	if not unsupported.is_empty():
		failure = "场景传送脚本遇到未支持指令：%s" % ", ".join(unsupported)
	elif requested_scenes != [3] or session.scene_index != 3:
		failure = "场景 6 传送脚本没有请求进入场景 4：%s" % requested_scenes
	elif session.party_world_position() != Vector2i(224, 1376):
		failure = "场景传送落点错误：%s" % session.party_world_position()
	elif sounds != [45] or not session.party_formation_collapsed:
		failure = "传送后的音效或队伍收拢状态错误：sound=%s collapsed=%s" % [sounds, session.party_formation_collapsed]
	vm.free()
	return failure
