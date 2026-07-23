# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式 PalTileMapWorld 生成移动探索、菜单和对话触控层的 320×200 本地截图。
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var world := PalTileMapWorld.new()
	viewport.add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	viewport.add_child(ui_layer)
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 0
	session.set_party_world_position(Vector2i(1248, 1040))
	var scene := database.scenes[session.scene_index]
	if not world.load_map(database, scene.map_number) or not world.sync_world(session, database.events_for_scene(session.scene_index)):
		printerr("FAIL: 正式 TileMap 移动截图载入失败：%s" % world.error_message)
		quit(1)
		return
	var controls := PalMobileControls.new()
	controls.force_touch_ui = true
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(controls)
	controls.set_exploration_available(true)
	controls.handle_pointer_press(Vector2(78, 156), 1)
	controls.handle_pointer_drag(Vector2(106, 142), 1)
	await _settle_render()
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var exploration_image := viewport.get_texture().get_image()
	if exploration_image == null or exploration_image.get_size() != Vector2i(320, 200) or exploration_image.save_png(output_directory.path_join("mobile_exploration_controls.png")) != OK:
		printerr("FAIL: 移动探索截图没有生成有效的 320×200 画面")
		quit(1)
		return
	controls.set_talk_interaction_available(true)
	await _settle_render()
	var talk_image := viewport.get_texture().get_image()
	if talk_image == null or talk_image.save_png(output_directory.path_join("mobile_exploration_talk_controls.png")) != OK:
		printerr("FAIL: 人物附近的聊天气泡互动图标截图写入失败")
		quit(1)
		return
	controls.set_exploration_available(false)
	var menu := PalGameMenu.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)
	menu.configure(database, session)
	menu.open_main()
	await _settle_render()
	var menu_image := viewport.get_texture().get_image()
	if menu_image == null or menu_image.save_png(output_directory.path_join("mobile_game_menu.png")) != OK:
		printerr("FAIL: 移动菜单截图写入失败")
		quit(1)
		return
	var menu_touch := InputEventScreenTouch.new()
	menu_touch.position = Vector2(PalGameMenu.MAIN_ITEM_POSITIONS[3])
	menu_touch.pressed = true
	menu._gui_input(menu_touch)
	if menu.current_page != PalGameMenu.Page.SYSTEM:
		printerr("FAIL: 移动菜单没有消费真实 InputEventScreenTouch")
		quit(1)
		return
	menu.hide()
	var dialog := PalDialogBox.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(dialog)
	dialog.begin(1)
	dialog.show_speaker_title("李逍遥：")
	dialog.show_message("点击对话框继续")
	dialog.reveal_all()
	await _settle_render()
	var dialog_image := viewport.get_texture().get_image()
	if dialog_image == null or dialog_image.save_png(output_directory.path_join("mobile_dialog_touch.png")) != OK:
		printerr("FAIL: 移动对话截图写入失败")
		quit(1)
		return
	dialog.hide_dialog()
	var battle := PalBattlePreview.new()
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(battle)
	await _settle_render()
	battle.set_process(false)
	if battle._controller == null or battle._enemy_nodes.size() < 2:
		printerr("FAIL: 移动战斗触摸回归没有载入双敌人样板")
		quit(1)
		return
	if not battle._handle_pointer_press(Vector2(35, 148)) or battle._input_mode != PalBattlePreview.InputMode.ENEMY_TARGET:
		printerr("FAIL: 点击经典攻击图标没有进入选敌阶段")
		quit(1)
		return
	var enemy_node: Sprite2D = battle._enemy_nodes[1]
	var enemy_point := enemy_node.position + enemy_node.texture.get_size() * 0.5
	if not battle._handle_pointer_press(enemy_point) or battle._input_mode != PalBattlePreview.InputMode.COMMAND:
		printerr("FAIL: 点击敌人 Sprite 没有为首名队员提交攻击")
		quit(1)
		return
	await _settle_render()
	var battle_image := viewport.get_texture().get_image()
	if battle_image == null or battle_image.save_png(output_directory.path_join("mobile_battle_touch.png")) != OK:
		printerr("FAIL: 移动战斗触摸截图写入失败")
		quit(1)
		return
	print("PASS: 正式 TileMap 移动摇杆、固定菜单/互动键、菜单/战斗触摸、触控返回和对话截图已生成")
	quit(0)


func _settle_render() -> void:
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
