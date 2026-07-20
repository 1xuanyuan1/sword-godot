# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 带窗口验证 TD-001 的 TileMap 正式画面、经典交互页与 DOS 结局合成。
## 截图只写入被 Git 忽略的 generated/pal/visual_tests/。
extends SceneTree

const OUTPUT_DIR := "res://generated/pal/visual_tests"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地 DOS 内容不可用：%s" % database.error_message)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var world := PalTileMapWorld.new()
	viewport.add_child(world)
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 0
	session.set_party_world_position(Vector2i(1248, 1040))
	var events := database.events_for_scene(0)
	var scene := database.scenes[0]
	if not world.load_map(database, scene.map_number) or not world.sync_world(session, events):
		_fail("TileMap 正式路径加载失败：%s" % world.error_message)
		return
	var base := await _capture(viewport, "td001_tilemap_base.png")

	# 0098：真实 DOS 使用的 MGO 82/83 放在轨迹第 4、5 格，并交给同一 Y-sort 根。
	var leader := session.party_world_position()
	session.follower_sprite_numbers = PackedInt32Array([82, 83])
	session.trail_positions[3] = leader + Vector2i(-32, 16)
	session.trail_positions[4] = leader + Vector2i(32, 24)
	session.trail_directions[3] = GameSession.DIR_EAST
	session.trail_directions[4] = GameSession.DIR_WEST
	world.sync_world(session, events)
	var followers := await _capture(viewport, "td001_followers.png")
	if _pixel_difference(base, followers) <= 0:
		_fail("0098 跟随者没有改变 TileMap 正式画面")
		return

	# 0071：正式 320×200 screen-texture Shader；零强度时覆盖层完全隐藏。
	world.set_screen_wave(24, 0)
	var wave := await _capture(viewport, "td001_screen_wave.png")
	world.set_screen_wave(0, 0)
	if _pixel_difference(followers, wave) <= 0:
		_fail("0071 波动 Shader 没有产生逐行像素变化")
		return

	# 0035：震屏只偏移正式世界根，复位后不改变会话或相机坐标。
	world.set_screen_effect_offset(Vector2(0, 5))
	var shake := await _capture(viewport, "td001_screen_shake.png")
	world.set_screen_effect_offset(Vector2.ZERO)
	if _pixel_difference(followers, shake) <= 0:
		_fail("0035 正式世界偏移没有改变像素")
		return

	# 008B：重新同步 TileMap 和人物共用的索引调色板。
	session.palette_index = 5
	if not world.sync_world(session, events):
		_fail("008B 调色板 5 无法同步：%s" % world.error_message)
		return
	var palette := await _capture(viewport, "td001_palette_5.png")
	if _pixel_difference(followers, palette) <= 0:
		_fail("008B 调色板切换没有改变正式画面")
		return

	# 0099：原数据确实把当前场景动态切到 MAP 164；直接重载 TileMapLayer，不跑进入脚本。
	session.palette_index = 0
	if not world.load_map(database, 164) or not world.sync_world(session, events):
		_fail("0099 动态 MAP 164 无法重载：%s" % world.error_message)
		return
	await _capture(viewport, "td001_dynamic_map_164.png")
	if world.loaded_map_number != 164:
		_fail("0099 没有保留动态地图编号")
		return

	# UI 使用独立 CanvasLayer，保持经典 UI Sprite、调色板和键盘菜单布局。
	var ui_layer := CanvasLayer.new()
	viewport.add_child(ui_layer)
	var menu := PalGameMenu.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)
	await process_frame
	session.cash = 9999
	menu.configure(database, session)
	menu.open_confirmation()
	await _capture(viewport, "td001_confirmation.png")
	menu.open_shop(0, true)
	await _capture(viewport, "td001_shop_buy.png")
	if not menu._shop_ids.is_empty():
		menu._confirm_shop_selection()
		await _capture(viewport, "td001_shop_buy_confirm.png")
	var sellable_id := _first_sellable_item(database)
	if sellable_id > 0:
		session.set_item_count(sellable_id, 2)
	menu.open_shop(0, false)
	await _capture(viewport, "td001_shop_sell.png")
	menu.hide()

	# 008C：按当前调色板的指定颜色生成正式覆盖色；运行时 Tween 的阻塞/方向另由行为测试验证。
	var overlay := ColorRect.new()
	overlay.size = Vector2(320, 200)
	overlay.color = _palette_color(database.load_palette(0, false), 79, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)
	await _capture(viewport, "td001_color_fade_79_midpoint.png")
	overlay.hide()

	# 0096：固定版 61/62 背景、571 双帧兽形、572 四帧少女和强度 2 波动。
	var ending := PalEndingPlayer.new()
	ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ending)
	await process_frame
	ending.configure(database, session)
	ending.play(ScriptVM.ENDING_ANIMATION, 0, 0, 0)
	if ending._active_tween != null:
		ending._active_tween.custom_step(5.0)
	ending._process(0.2)
	var ending_0096 := await _capture(viewport, "td001_ending_0096.png")
	if not ending._beast_first.visible or not ending._beast_second.visible or not ending._girl.visible:
		_fail("0096 未同时合成 571 双帧与 572 少女")
		return
	if _non_white_pixels(ending_0096) < 1000:
		_fail("0096 结局合成截图为空白")
		return
	ending._kill_tween()
	ending.play(ScriptVM.ENDING_SHOW_FBP_EFFECT, 69, 571, 0)
	var ending_00a5 := await _capture(viewport, "td001_ending_00a5.png")
	if ending._background.texture == null or ending._effect.texture == null:
		_fail("00A5 未合成 FBP 与 MGO 特效")
		return
	if _non_white_pixels(ending_00a5) < 1000:
		_fail("00A5 FBP/MGO 合成截图为空白")
		return

	print("PASS: TD-001 TileMap/Shader/调色板/跟随者/动态地图/商店/确认框/颜色覆盖/结局窗口截图已生成")
	quit(0)


func _capture(viewport: SubViewport, filename: String) -> Image:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename)))
	return image


func _pixel_difference(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var different := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				different += 1
	return different


func _non_white_pixels(image: Image) -> int:
	if image == null:
		return 0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r < 0.98 or color.g < 0.98 or color.b < 0.98:
				count += 1
	return count


func _first_sellable_item(database: PalContentDatabase) -> int:
	for item in database.items:
		if item != null and item.object_id > 0 and item.is_sellable():
			return item.object_id
	return 0


func _palette_color(palette: PackedByteArray, index: int, alpha: float) -> Color:
	var offset := clampi(index, 0, 255) * 3
	if palette.size() < offset + 3:
		return Color(0, 0, 0, alpha)
	return Color(float(palette[offset]) / 255.0, float(palette[offset + 1]) / 255.0, float(palette[offset + 2]) / 255.0, alpha)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
