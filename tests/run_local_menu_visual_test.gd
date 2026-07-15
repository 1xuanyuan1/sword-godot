# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var wine := database.item_definition(272)
	if wine == null or not database.load_ui_sprite().is_valid() or not database.load_item_bitmap(wine.bitmap).is_valid():
		printerr("FAIL: 原版菜单 Sprite 或桂花酒图标没有正确导入")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("32261d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	var menu := PalGameMenu.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(menu)
	await process_frame
	var session := GameSession.new()
	session.cash = 550
	session.set_item_count(272, 2)
	menu.configure(database, session)
	if not menu.has_classic_resources():
		printerr("FAIL: 原版 UI 拼片或点阵字库加载失败")
		quit(1)
		return

	menu.open_main()
	await process_frame
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_dir)
	viewport.get_texture().get_image().save_png(output_dir.path_join("classic_main_menu.png"))
	menu.open_inventory()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output_dir.path_join("classic_inventory.png"))
	print("PASS: 原版主菜单与物品页视觉快照已生成")
	quit(0)
