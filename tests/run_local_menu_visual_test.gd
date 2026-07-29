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
	if wine == null or not database.load_ui_sprite().is_valid() or not database.load_item_bitmap(wine.bitmap).is_valid() or database.get_item_description(272).is_empty() or not database.load_battle_background(0).is_valid() or not database.load_rgm_portrait(database.player_roles.avatar_for(0)).is_valid():
		printerr("FAIL: 原版菜单 Sprite、状态背景、头像、桂花酒图标或物品说明没有正确导入")
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
	var classic_main_image := viewport.get_texture().get_image()
	classic_main_image.save_png(output_dir.path_join("classic_main_menu.png"))
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
	menu._main_selection = 0
	menu._confirm_selection()
	await process_frame
	await process_frame
	var clean_status_image := viewport.get_texture().get_image()
	clean_status_image.save_png(output_dir.path_join("classic_status.png"))
	var ordinary_poison := database.poison_definition(551)
	var strong_attachment := database.poison_definition(561)
	if ordinary_poison == null or strong_attachment == null:
		printerr("FAIL: 状态页回归需要的真实普通毒或四级附着不存在")
		quit(1)
		return
	session.add_role_poison(0, 551, ordinary_poison.player_script)
	session.add_role_poison(0, 561, strong_attachment.player_script)
	session.set_role_status(0, GameSession.STATUS_SILENCE, 3)
	session.set_role_status(0, GameSession.STATUS_PROTECT, 5)
	menu.queue_redraw()
	await process_frame
	await process_frame
	var condition_status_image := viewport.get_texture().get_image()
	var condition_status_path := output_dir.path_join("classic_status_conditions.png")
	if condition_status_image.save_png(condition_status_path) != OK:
		printerr("FAIL: 无法写入场外毒与状态页截图")
		quit(1)
		return
	if _pixel_difference_in_rect(clean_status_image, condition_status_image, Rect2i(180, 52, 136, 96)) < 40:
		printerr("FAIL: 场外状态页没有绘制普通毒、四级附着与异常状态")
		quit(1)
		return
	var field_magic_id := 0
	var magic_candidates := PackedInt32Array()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		magic_candidates.append_array(database.player_roles.magics_for(role_index))
		if database.level_progression != null:
			magic_candidates.append_array(database.level_progression.magic_objects_for_level(role_index, PalLevelProgression.MAX_LEVEL))
	for magic_id in magic_candidates:
		var magic_object := database.magic_object_definition(magic_id)
		var magic_definition := database.magic_definition_for_object(magic_id)
		if magic_object != null and magic_definition != null and magic_object.is_usable_outside_battle():
			field_magic_id = magic_id
			session.add_magic(0, magic_id)
			session.role_mp[0] = maxi(session.role_mp[0], magic_definition.mp_cost)
			break
	menu.open_main()
	menu._main_selection = 1
	menu._confirm_selection()
	await process_frame
	await process_frame
	var condition_magic_image := viewport.get_texture().get_image()
	condition_magic_image.save_png(output_dir.path_join("classic_field_magic.png"))
	if field_magic_id <= 0:
		printerr("FAIL: 玩家初始/升级仙术表中没有找到合法的场外仙术")
		quit(1)
		return
	session.cure_role_poison(0, 551)
	session.cure_role_poison(0, 561)
	session.remove_role_status(0, GameSession.STATUS_SILENCE)
	session.remove_role_status(0, GameSession.STATUS_PROTECT)
	menu.queue_redraw()
	await process_frame
	await process_frame
	var clean_magic_image := viewport.get_texture().get_image()
	if _pixel_difference_in_rect(condition_magic_image, clean_magic_image, Rect2i(43, 139, 2, 2)) != 0:
		printerr("FAIL: 场外队伍异常状态图标仍绘制了方形黑底")
		quit(1)
		return
	var field_definition := database.magic_definition_for_object(field_magic_id)
	var hp_before := maxi(1, session.role_max_hp[0] - 30)
	session.role_hp[0] = hp_before
	session.role_max_mp[0] = maxi(session.role_max_mp[0], field_definition.mp_cost + 5)
	session.role_mp[0] = field_definition.mp_cost + 5
	var mp_before := session.role_mp[0]
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var explorer: Control = load("res://src/world/map_explorer.gd").new()
	var status_label := Label.new()
	explorer._database = database
	explorer._session = session
	explorer._script_vm = vm
	explorer._game_menu = menu
	explorer._status = status_label
	var unsupported: Array[String] = []
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.script_finished.connect(explorer._on_script_finished)
	explorer._on_magic_use_requested(field_magic_id, 0, 0)
	if explorer._pending_magic_object_id > 0 and explorer._pending_magic_stage == explorer.FIELD_MAGIC_STAGE_SUCCESS and not vm.running:
		explorer._run_pending_magic_stage()
	if not unsupported.is_empty() or explorer._pending_magic_object_id != 0 or session.role_hp[0] <= hp_before or session.role_mp[0] != mp_before - field_definition.mp_cost:
		printerr("FAIL: 真实场外仙术 %d 未完成：unsupported=%s pending=%d HP=%d MP=%d/%d" % [field_magic_id, unsupported, explorer._pending_magic_object_id, session.role_hp[0], session.role_mp[0], mp_before])
		quit(1)
		return
	status_label.free()
	explorer.free()
	vm.free()
	menu.open_main()
	menu._main_selection = 3
	menu._confirm_selection()
	menu._system_selection = 4
	menu.queue_redraw()
	await process_frame
	await process_frame
	var classic_system_image := viewport.get_texture().get_image()
	classic_system_image.save_png(output_dir.path_join("classic_system_audio.png"))
	var save_summaries: Array[Dictionary] = []
	for slot in range(1, PalSaveManager.SLOT_COUNT + 1):
		save_summaries.append({"slot": slot, "exists": false, "can_load": false, "save_count": 0, "saved_at": "", "scene_index": -1, "map_number": 0, "party": [], "error": ""})
	save_summaries[0] = {
		"slot": 1,
		"exists": true,
		"can_load": true,
		"save_count": 12,
		"saved_at": "2026-07-17 18:30:00",
		"scene_index": 0,
		"map_number": 12,
		"party": [{"role_index": 0, "level": 8}, {"role_index": 1, "level": 7}],
		"error": "",
	}
	save_summaries[1] = {"slot": 2, "exists": true, "can_load": false, "save_count": 0, "saved_at": "", "scene_index": -1, "map_number": 0, "party": [], "error": "存档文件结构损坏"}
	menu.configure_save_slots(save_summaries, 1)
	menu._system_selection = 0
	menu._confirm_selection()
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png(output_dir.path_join("classic_save_slots.png"))
	menu.configure_toy_features(true, "Toy 云存档与排行榜已连接")
	menu.open_main()
	menu._main_selection = 3
	menu._confirm_selection()
	menu._system_selection = 4
	await process_frame
	await process_frame
	var toy_system_image := viewport.get_texture().get_image()
	if toy_system_image.save_png(output_dir.path_join("classic_toy_system_menu.png")) != OK:
		printerr("FAIL: 无法写入 Toy 系统菜单截图")
		quit(1)
		return
	if _pixel_difference_in_rect(classic_system_image, toy_system_image, Rect2i(35, 20, 165, 175)) < 200:
		printerr("FAIL: Toy 系统菜单没有显示云端存档与排行榜入口")
		quit(1)
		return
	menu._confirm_selection()
	menu.notify_toy_cloud_info({}, "预览模式：正式页面将连接云存档")
	await process_frame
	await process_frame
	var toy_cloud_image := viewport.get_texture().get_image()
	if toy_cloud_image.save_png(output_dir.path_join("classic_toy_cloud.png")) != OK:
		printerr("FAIL: 无法写入 Toy 云存档页截图")
		quit(1)
		return
	menu._move_selection(Vector2i(1, 0))
	await process_frame
	await process_frame
	var toy_cloud_next_image := viewport.get_texture().get_image()
	if menu._toy_slot_label() != "本地存档 002" or toy_cloud_next_image.save_png(output_dir.path_join("classic_toy_cloud_002.png")) != OK:
		printerr("FAIL: Toy 云存档右箭头没有切到本地存档 002")
		quit(1)
		return
	if _pixel_difference_in_rect(toy_cloud_image, toy_cloud_next_image, Rect2i(15, 56, 150, 22)) < 10:
		printerr("FAIL: Toy 云存档首槽左箭头状态或存档编号没有随右移更新")
		quit(1)
		return
	menu._move_selection(Vector2i(-1, 0))
	menu._toy_selection = 0
	menu._confirm_selection()
	await process_frame
	await process_frame
	var toy_confirm_image := viewport.get_texture().get_image()
	if toy_confirm_image.save_png(output_dir.path_join("classic_toy_confirm.png")) != OK:
		printerr("FAIL: 无法写入 Toy 云存档确认框截图")
		quit(1)
		return
	if _pixel_difference_in_rect(toy_cloud_image, toy_confirm_image, Rect2i(36, 50, 248, 100)) < 800:
		printerr("FAIL: Toy 云存档确认框没有形成清晰的居中模态层")
		quit(1)
		return
	menu.go_back()
	menu.go_back()
	menu._system_selection = 5
	menu._confirm_selection()
	menu._toy_busy = true
	menu._move_selection(Vector2i(1, 0))
	if menu._toy_rank_board != 2:
		printerr("FAIL: 排行榜忙碌时无法从逍遥等级切换到队伍等级")
		quit(1)
		return
	menu.notify_toy_rank(2, [], {}, "预览模式：正式页面将显示排行榜")
	await process_frame
	await process_frame
	var toy_rank_image := viewport.get_texture().get_image()
	if toy_rank_image.save_png(output_dir.path_join("classic_toy_rank.png")) != OK:
		printerr("FAIL: 无法写入 Toy 排行榜页截图")
		quit(1)
		return
	if _pixel_difference_in_rect(toy_cloud_image, toy_rank_image, Rect2i(Vector2i.ZERO, Vector2i(320, 200))) < 800:
		printerr("FAIL: Toy 云存档页与排行榜页没有形成有效的像素差异")
		quit(1)
		return
	print("PASS: 原版主菜单、物品页、装备页、状态页、场外仙术页、系统音量页、100 槽存档页、Toy 扩展系统菜单、云存档、确认框与可切换空排行榜视觉快照已生成；样板仙术 %d；李逍遥初始属性 攻%d 灵%d 防%d 身%d 逃%d" % [
		field_magic_id,
		session.attack_strength_for(0),
		session.magic_strength_for(0),
		session.defense_for(0),
		session.dexterity_for(0),
		session.flee_rate_for(0),
	])
	quit(0)


func _pixel_difference_in_rect(first: Image, second: Image, region: Rect2i) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, first.get_size()))
	var difference := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				difference += 1
	return difference
