# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成内容渲染资源实验室的开始/读档入口，并验证经典读取页可独立打开和取消。
## 测试只读取正式存档摘要，截图写入被 Git 忽略的 `generated/pal/visual_tests/`。
extends SceneTree

const StartupRequest := preload("res://src/game/pal_startup_request.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab_scene := load("res://scenes/main.tscn") as PackedScene
	var lab = lab_scene.instantiate() if lab_scene != null else null
	if lab == null:
		_fail("无法实例化资源实验室主场景")
		return
	viewport.add_child(lab)
	await process_frame
	await process_frame
	if lab._explore_button.text != "开始新游戏" or lab._load_save_button.text != "读取存档":
		_fail("启动页没有显示开始新游戏／读取存档入口")
		return
	if lab._explore_button.disabled or lab._load_save_button.disabled or not lab._save_system_available:
		_fail("本地生成内容存在时开始游戏或读取存档入口不可用")
		return
	if lab._explore_button.get_global_rect().intersects(lab._load_save_button.get_global_rect()):
		_fail("开始新游戏与读取存档按钮发生布局重叠")
		return
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var lab_image := viewport.get_texture().get_image()
	if lab_image == null or lab_image.get_size() != Vector2i(320, 200) or lab_image.save_png(output_directory.path_join("startup_lab.png")) != OK:
		_fail("无法保存 320×200 资源实验室启动页截图")
		return
	lab._open_save_loader()
	await process_frame
	await process_frame
	if not lab._save_menu.visible or lab._save_menu.current_page != PalGameMenu.Page.LOAD_SLOTS:
		_fail("启动页没有直接打开经典 100 槽读取界面")
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(320, 200) or image.save_png(output_directory.path_join("startup_load_entry.png")) != OK:
		_fail("无法保存 320×200 启动读档界面截图")
		return
	lab._save_menu.go_back()
	if lab._save_menu.visible:
		_fail("启动页读取存档界面按 Esc 没有直接关闭")
		return
	var selected_save: Dictionary = {}
	for metadata in lab._save_manager.slot_summaries():
		if bool(metadata.get("can_load", false)):
			selected_save = metadata
			break
	lab.free()
	viewport.free()
	if selected_save.is_empty():
		print("PASS: 资源实验室提供开始新游戏与读取存档入口，经典 100 槽读取页可独立打开和取消；本机无正式存档，跳过恢复")
		quit(0)
		return
	var slot := int(selected_save.get("slot", 0))
	if not StartupRequest.request_load_slot(slot):
		_fail("可读取存档没有进入一次性启动请求")
		return
	var explorer_scene := load("res://scenes/map_explorer.tscn") as PackedScene
	var explorer = explorer_scene.instantiate() if explorer_scene != null else null
	if explorer == null:
		_fail("无法实例化探索场景验证启动读档")
		return
	root.add_child(explorer)
	await process_frame
	await process_frame
	if explorer._save_manager.current_slot != slot or explorer._loaded_scene_index != int(selected_save.get("scene_index", -1)):
		_fail("启动请求没有恢复所选槽位与场景：槽位 %d/%d，场景 %d/%d" % [explorer._save_manager.current_slot, slot, explorer._loaded_scene_index, int(selected_save.get("scene_index", -1))])
		return
	if explorer._active_scene_enter_index != -1 or StartupRequest.consume_load_slot() != 0:
		_fail("启动读档错误重跑场景进入脚本，或一次性请求没有清空")
		return
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
	explorer.free()
	await create_timer(0.1).timeout
	print("PASS: 启动页经典读档入口恢复正式槽位 %03d 与场景 %d，未重跑进入脚本" % [slot, int(selected_save.get("scene_index", -1))])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
