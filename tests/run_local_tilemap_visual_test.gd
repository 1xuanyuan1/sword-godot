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
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var world := PalTileMapWorld.new()
	viewport.add_child(world)
	for test_case in TEST_CASES:
		var failure := await _compare_case(database, viewport, world, test_case)
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
	var scene := database.scenes[session.scene_index]
	var events := database.events_for_scene(session.scene_index)
	if not world.load_map(database, scene.map_number):
		return "%s：%s" % [test_case["name"], world.error_message]
	world.set_walk_animation(0, false)
	if not world.sync_world(session, events):
		return "%s：%s" % [test_case["name"], world.error_message]

	await process_frame
	await process_frame
	var native_image := viewport.get_texture().get_image()
	if native_image == null:
		return "当前为 dummy renderer；请去掉 --headless，使用真实 GL Compatibility 渲染器运行"
	var scene_items: Array = world._build_scene_items(session, events, session.viewport_position)
	var map_data := database.load_map(scene.map_number)
	var tile_sprite := database.load_map_tiles(scene.map_number)
	var cpu_indexed := PalSceneRenderer.render(map_data, tile_sprite, Rect2i(session.viewport_position, Vector2i(320, 200)), scene_items)
	var palette := database.load_palette(session.palette_index, session.night_palette)
	var cpu_image := cpu_indexed.to_rgba_image(palette)
	if native_image.get_size() != cpu_image.get_size():
		return "%s 截图尺寸不一致：TileMap %s / CPU %s" % [test_case["name"], native_image.get_size(), cpu_image.get_size()]

	var different := 0
	var maximum_channel_difference := 0
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

	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_name := str(test_case["name"])
	native_image.save_png(output_directory.path_join("tilemap_%s_native.png" % output_name))
	cpu_image.save_png(output_directory.path_join("tilemap_%s_cpu.png" % output_name))
	if different > 0:
		return "%s（map %d）有 %d 个差异像素，最大通道差 %d；截图已写入 visual_tests" % [output_name, scene.map_number, different, maximum_channel_difference]
	return ""


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
