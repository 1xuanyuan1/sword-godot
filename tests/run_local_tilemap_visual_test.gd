# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源比较 TileMapLayer 与 CPU SDLPal 基准的 320×200 像素输出。
## 差异截图只写入被 Git 忽略的 `generated/pal/visual_tests/`。
extends SceneTree

const TEST_POSITION := Vector2i(1248, 1040)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 0
	session.set_party_world_position(TEST_POSITION)
	var scene := database.scenes[session.scene_index]
	var events := database.events_for_scene(session.scene_index)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var world := PalTileMapWorld.new()
	viewport.add_child(world)
	if not world.load_map(database, scene.map_number):
		_fail(world.error_message)
		return
	world.set_walk_animation(0, false)
	if not world.sync_world(session, events):
		_fail(world.error_message)
		return

	await process_frame
	await process_frame
	var native_image := viewport.get_texture().get_image()
	if native_image == null:
		_fail("当前为 dummy renderer；请去掉 --headless，使用真实 GL Compatibility 渲染器运行")
		return
	var scene_items: Array = world._build_scene_items(session, events)
	var map_data := database.load_map(scene.map_number)
	var tile_sprite := database.load_map_tiles(scene.map_number)
	var cpu_indexed := PalSceneRenderer.render(map_data, tile_sprite, Rect2i(session.viewport_position, Vector2i(320, 200)), scene_items)
	var palette := database.load_palette(session.palette_index, session.night_palette)
	var cpu_image := cpu_indexed.to_rgba_image(palette)
	if native_image.get_size() != cpu_image.get_size():
		_fail("截图尺寸不一致：TileMap %s / CPU %s" % [native_image.get_size(), cpu_image.get_size()])
		return

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
	native_image.save_png(output_directory.path_join("tilemap_native.png"))
	cpu_image.save_png(output_directory.path_join("tilemap_cpu.png"))
	if different > 0:
		_fail("TileMap 与 CPU 有 %d 个差异像素，最大通道差 %d；截图已写入 visual_tests" % [different, maximum_channel_difference])
		return
	print("PASS: map %d TileMapLayer 与 CPU 基准 320×200 零像素差异" % scene.map_number)
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
