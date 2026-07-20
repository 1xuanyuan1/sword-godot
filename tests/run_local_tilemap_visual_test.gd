# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源比较 TileMapLayer 与 CPU SDLPal 基准的 320×200 像素输出。
## 差异截图只写入被 Git 忽略的 `generated/pal/visual_tests/`。
extends SceneTree

const TEST_CASES: Array[Dictionary] = [
	{"name": "inn_room", "scene": 0, "position": Vector2i(1248, 1040), "night": false},
	{"name": "kitchen_entry", "scene": 0, "position": Vector2i(1248, 1104), "night": false},
	{"name": "stairs", "scene": 0, "position": Vector2i(96, 48), "night": false},
	{"name": "wine_outdoor", "scene": 2, "position": Vector2i(1088, 1648), "night": false},
	{"name": "roof_night", "scene": 3, "position": Vector2i(1440, 1536), "night": true},
	{"name": "hidden_dragon_nearby", "scene": 41, "position": Vector2i(1760, 1792), "night": false, "party": [2, 0]},
	{"name": "hidden_dragon_snake", "scene": 40, "position": Vector2i(816, 776), "night": false, "party": [0, 2]},
	{"name": "hidden_dragon_inner", "scene": 46, "position": Vector2i(1280, 1328), "night": false, "party": [0, 2]},
	{"name": "baihe_road", "scene": 47, "position": Vector2i(464, 1672), "night": false, "party": [0, 2]},
	{"name": "baihe_village", "scene": 48, "position": Vector2i(576, 1632), "night": false, "party": [0, 2]},
	{"name": "baihe_deer_hunt", "scene": 47, "position": Vector2i(704, 1040), "night": false, "party": [0], "event_states": {791: 0, 792: 0, 793: 0, 794: 0, 795: 0, 798: 2, 799: 2}},
	{"name": "baihe_han_outside", "scene": 51, "position": Vector2i(896, 832), "night": false, "party": [0]},
	{"name": "baihe_han_clinic_recovered", "scene": 52, "position": Vector2i(1472, 600), "night": false, "party": [0, 1, 2], "event_states": {905: 0, 907: 0, 908: 0, 910: 0}},
	{"name": "baihe_rear_road", "scene": 53, "position": Vector2i(352, 640), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_courtyard", "scene": 55, "position": Vector2i(1376, 1000), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_hall", "scene": 57, "position": Vector2i(800, 1088), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_cleared", "scene": 56, "position": Vector2i(1184, 560), "night": false, "party": [0, 1, 2]},
	{"name": "blackwater_village", "scene": 60, "position": Vector2i(1280, 1120), "night": false, "party": [0, 1, 2]},
	{"name": "burial_wilderness", "scene": 62, "position": Vector2i(1536, 1456), "night": false, "party": [0, 1, 2]},
	{"name": "burial_grave_gate", "scene": 63, "position": Vector2i(560, 384), "night": false, "party": [0, 1, 2]},
	{"name": "general_tomb_upper", "scene": 59, "position": Vector2i(1392, 1600), "night": false, "party": [0, 1, 2]},
	{"name": "general_tomb_lower_boss", "scene": 64, "position": Vector2i(640, 304), "night": false, "party": [0, 1, 2]},
	{"name": "blood_pool_red_ghost", "scene": 58, "position": Vector2i(832, 112), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_guards", "scene": 54, "position": Vector2i(320, 1464), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_maze", "scene": 69, "position": Vector2i(1504, 880), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_summit", "scene": 68, "position": Vector2i(1232, 1040), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_altar_plot", "scene": 66, "position": Vector2i(1344, 1120), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_altar_rescued", "scene": 76, "position": Vector2i(1216, 976), "night": false, "party": [0, 2]},
	{"name": "yangzhou_approach", "scene": 82, "position": Vector2i(224, 848), "night": false, "party": [0, 2]},
	{"name": "yangzhou_gate", "scene": 78, "position": Vector2i(432, 1192), "night": false, "party": [0, 2]},
	{"name": "yangzhou_inn_night", "scene": 92, "position": Vector2i(768, 528), "night": true, "party": [0], "event_states": {1814: 0, 1815: 2, 1835: 1}},
	{"name": "yangzhou_rooftop_night", "scene": 84, "position": Vector2i(752, 248), "night": true, "party": [2, 0]},
	{"name": "yangzhou_widow_house", "scene": 88, "position": Vector2i(1056, 1104), "night": false, "party": [0, 2], "event_states": {1725: 0, 1726: 2}},
	{"name": "yangzhou_well_tunnel", "scene": 91, "position": Vector2i(848, 1528), "night": false, "party": [2, 0]},
	{"name": "yangzhou_court", "scene": 80, "position": Vector2i(1504, 1056), "night": false, "party": [0, 2]},
	{"name": "toad_valley_approach", "scene": 104, "position": Vector2i(224, 1072), "night": false, "party": [0, 2]},
	{"name": "compact_two_person_formation", "scene": 41, "position": Vector2i(1808, 1768), "night": false, "party": [0, 1], "direction": GameSession.DIR_SOUTH, "steps": 3, "expected_follower_delta": Vector2i(32, -16)},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	for test_case in TEST_CASES:
		# Metal 后端在同一 SubViewport 连续换图时偶尔会读回上一地图的完整旧帧；每个用例
		# 使用独立视口和正式 PalTileMapWorld，避免用延长固定等待掩盖 GPU 换图时序。
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 200)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = false
		root.add_child(viewport)
		var world := PalTileMapWorld.new()
		# 新增星芒是正式 TileMap 辅助层，不属于 SDLPal CPU 像素基准。
		world.set_collectible_markers_enabled(false)
		viewport.add_child(world)
		var failure := await _compare_case(database, viewport, world, test_case)
		viewport.free()
		if not failure.is_empty():
			_fail(failure)
			return
	print("PASS: %d 个 TileMapLayer 固定视口与 CPU 基准均为 320×200 零像素差异" % TEST_CASES.size())
	quit(0)


func _compare_case(database: PalContentDatabase, viewport: SubViewport, world: PalTileMapWorld, test_case: Dictionary) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	if test_case.has("party"):
		session.party_roles = PackedInt32Array(test_case["party"])
	session.scene_index = int(test_case["scene"])
	session.night_palette = bool(test_case["night"])
	session.set_party_world_position(test_case["position"])
	if test_case.has("steps"):
		var direction: int = test_case["direction"]
		var movement := GameSession.movement_for_direction(direction)
		for _step in range(int(test_case["steps"])):
			session.record_party_step(direction, movement)
	if test_case.has("expected_follower_delta"):
		var follower_delta := session.party_member_world_position(1) - session.party_world_position()
		if follower_delta != test_case["expected_follower_delta"]:
			return "%s：紧凑队伍间距错误，实际 %s" % [test_case["name"], follower_delta]
	var scene := database.scenes[session.scene_index]
	var events := database.events_for_scene(session.scene_index)
	if not world.load_map(database, scene.map_number):
		return "%s：%s" % [test_case["name"], world.error_message]
	var original_event_states: Dictionary = {}
	for raw_event_id in test_case.get("event_states", {}):
		var event_id := int(raw_event_id)
		if event_id <= 0 or event_id > database.event_objects.size():
			continue
		var event := database.event_objects[event_id - 1]
		original_event_states[event_id] = event.state
		event.state = int(test_case["event_states"][raw_event_id])
	world.set_walk_animation(0, false)
	if not world.sync_world(session, events):
		_restore_event_states(database, original_event_states)
		return "%s：%s" % [test_case["name"], world.error_message]

	# 新建 SubViewport 后等待 TileMapLayer、人物和事件节点完成第一次稳定提交。
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var native_image := viewport.get_texture().get_image()
	if native_image == null:
		_restore_event_states(database, original_event_states)
		return "当前为 dummy renderer；请去掉 --headless，使用真实 GL Compatibility 渲染器运行"
	var scene_items: Array = world._build_scene_items(session, events, session.viewport_position)
	var map_data := database.load_map(scene.map_number)
	var tile_sprite := database.load_map_tiles(scene.map_number)
	var cpu_indexed := PalSceneRenderer.render(map_data, tile_sprite, Rect2i(session.viewport_position, Vector2i(320, 200)), scene_items)
	var palette := database.load_palette(session.palette_index, session.night_palette)
	var cpu_image := cpu_indexed.to_rgba_image(palette)
	if native_image.get_size() != cpu_image.get_size():
		_restore_event_states(database, original_event_states)
		return "%s 截图尺寸不一致：TileMap %s / CPU %s" % [test_case["name"], native_image.get_size(), cpu_image.get_size()]

	var different := 0
	var maximum_channel_difference := 0
	var difference_examples := PackedStringArray()
	for y in range(cpu_image.get_height()):
		for x in range(cpu_image.get_width()):
			var cpu := cpu_image.get_pixel(x, y)
			var native := native_image.get_pixel(x, y)
			var channel_difference := maxi(
				absi(roundi(cpu.r * 255.0) - roundi(native.r * 255.0)),
				maxi(
					absi(roundi(cpu.g * 255.0) - roundi(native.g * 255.0)),
					absi(roundi(cpu.b * 255.0) - roundi(native.b * 255.0))
				)
			)
			if channel_difference > 0:
				different += 1
				maximum_channel_difference = maxi(maximum_channel_difference, channel_difference)
				if difference_examples.size() < 8:
					difference_examples.append("(%d,%d) CPU=%s TileMap=%s" % [x, y, cpu.to_html(), native.to_html()])

	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_name := str(test_case["name"])
	native_image.save_png(output_directory.path_join("tilemap_%s_native.png" % output_name))
	cpu_image.save_png(output_directory.path_join("tilemap_%s_cpu.png" % output_name))
	_restore_event_states(database, original_event_states)
	if different > 0:
		return "%s（map %d）有 %d 个差异像素，最大通道差 %d：%s；截图已写入 visual_tests" % [output_name, scene.map_number, different, maximum_channel_difference, "、".join(difference_examples)]
	return ""


func _restore_event_states(database: PalContentDatabase, original_states: Dictionary) -> void:
	for raw_event_id in original_states:
		var event_id := int(raw_event_id)
		database.event_objects[event_id - 1].state = int(original_states[raw_event_id])


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
