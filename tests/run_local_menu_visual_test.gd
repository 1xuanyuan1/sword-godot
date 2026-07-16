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
	if wine == null or not database.load_ui_sprite().is_valid() or not database.load_item_bitmap(wine.bitmap).is_valid() or database.get_item_description(272).is_empty():
		printerr("FAIL: 原版菜单 Sprite、桂花酒图标或物品说明没有正确导入")
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
	var equipment_manager := PalEquipmentManager.new()
	if not equipment_manager.configure(database, session):
		printerr("FAIL: 初始装备脚本无法重建：%s" % equipment_manager.error_message)
		quit(1)
		return
	if session.equipment_for_role(0) != PackedInt32Array([196, 225, 208, 166, 235, 249]):
		printerr("FAIL: 李逍遥六件初始装备解析错误：%s" % session.equipment_for_role(0))
		quit(1)
		return
	session.set_item_count(272, 2)
	session.set_item_count(201, 1)
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
	menu._inventory_for_equipment = true
	menu._open_equipment_page(201)
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output_dir.path_join("classic_equipment.png"))
	menu.open_main()
	menu._main_selection = 3
	menu._confirm_selection()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output_dir.path_join("classic_system_audio.png"))
	print("PASS: 原版主菜单、物品页、装备页与系统音量页视觉快照已生成；李逍遥初始属性 攻%d 灵%d 防%d 身%d 逃%d" % [
		session.attack_strength_for(0),
		session.magic_strength_for(0),
		session.defense_for(0),
		session.dexterity_for(0),
		session.flee_rate_for(0),
	])
	quit(0)
