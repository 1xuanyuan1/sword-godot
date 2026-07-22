# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成内容渲染正式片头、标题菜单与资源实验室，并验证经典读取页可独立打开和取消。
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
	var startup_scene := load("res://scenes/main.tscn") as PackedScene
	var startup = startup_scene.instantiate() if startup_scene != null else null
	if startup == null:
		_fail("无法实例化正式启动场景")
		return
	viewport.add_child(startup)
	await process_frame
	await process_frame
	if startup.phase != PalStartup.Phase.TRADEMARK or startup._trademark_frame_count != 54 or startup._trademark_texture == null:
		_fail("正式启动没有从完整商标 RNG #6 开始")
		return
	var manifest_file := FileAccess.open("res://generated/pal/manifest.json", FileAccess.READ)
	var manifest = JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else null
	var rng_six = manifest.get("files", {}).get("rng_runtime", {}).get("animations", {}).get("6", {}) if manifest is Dictionary else {}
	if not manifest is Dictionary or int(manifest.get("format_version", 0)) < PalImportReport.FORMAT_VERSION or int(rng_six.get("palette", -1)) != 3:
		_fail("本地导入产物没有用 SDLPal 商标调色板 3 生成 RNG #6")
		return
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	startup._trademark_elapsed = float(startup._trademark_frame_count - 1) / PalStartup.TRADEMARK_FPS
	await process_frame
	var trademark_image := viewport.get_texture().get_image()
	if trademark_image == null or trademark_image.get_size() != Vector2i(320, 200) or trademark_image.save_png(output_directory.path_join("startup_trademark.png")) != OK:
		_fail("无法保存 320×200 商标 RNG 截图")
		return
	startup._trademark_elapsed = float(startup._trademark_frame_count) / PalStartup.TRADEMARK_FPS + PalStartup.TRADEMARK_HOLD_SECONDS + PalStartup.TRADEMARK_FADE_SECONDS
	startup._process(0.0)
	if startup.phase != PalStartup.Phase.SPLASH or startup._audio_player.current_music_number != PalStartup.TITLE_MUSIC or not startup._audio_player._music_player.playing:
		_fail("商标结束后没有进入山水片头并播放标题曲")
		return
	startup._splash_elapsed = PalStartup.SPLASH_PALETTE_FADE_SECONDS
	startup._split_position = 1
	startup._title_reveal_height = startup._title_texture.get_height()
	await process_frame
	var splash_image := viewport.get_texture().get_image()
	if splash_image == null or splash_image.get_size() != Vector2i(320, 200) or splash_image.save_png(output_directory.path_join("startup_splash.png")) != OK:
		_fail("无法保存 320×200 山水片头截图")
		return
	startup._finish_splash()
	startup._process(PalStartup.SPLASH_EXIT_DELAY_SECONDS + 0.01)
	if startup.phase != PalStartup.Phase.SPLASH_FADE:
		_fail("确认山水片头后没有执行原版淡出")
		return
	startup._process(PalStartup.OPENING_MENU_FADE_SECONDS + 0.01)
	startup._opening_menu_elapsed = PalStartup.OPENING_MENU_FADE_SECONDS
	await process_frame
	await process_frame
	if startup.phase != PalStartup.Phase.OPENING_MENU or startup.menu_selection != 0 or startup._audio_player.current_music_number != PalStartup.OPENING_MENU_MUSIC or not startup._audio_player._music_player.playing:
		_fail("片头结束后没有进入正式标题菜单")
		return
	if startup._database.get_word(7) != "新的故事" or startup._database.get_word(8) != "舊的回憶":
		_fail("标题菜单没有使用原版词条")
		return
	var opening_image := viewport.get_texture().get_image()
	if opening_image == null or opening_image.get_size() != Vector2i(320, 200) or opening_image.save_png(output_directory.path_join("startup_opening_menu.png")) != OK:
		_fail("无法保存 320×200 正式标题菜单截图")
		return
	startup.menu_selection = 1
	startup._confirm_opening_menu()
	await process_frame
	await process_frame
	if not startup._save_menu.visible or startup._save_menu.current_page != PalGameMenu.Page.LOAD_SLOTS:
		_fail("标题菜单的“旧的回忆”没有打开经典 100 槽读取界面")
		return
	var opening_load_image := viewport.get_texture().get_image()
	if opening_load_image == null or opening_load_image.get_size() != Vector2i(320, 200) or opening_load_image.save_png(output_directory.path_join("startup_opening_load.png")) != OK:
		_fail("无法保存标题菜单的 320×200 读取界面截图")
		return
	startup._save_menu.go_back()
	if startup._save_menu.visible or startup.phase != PalStartup.Phase.OPENING_MENU:
		_fail("标题读档界面取消后没有返回标题菜单")
		return
	startup.menu_selection = 0
	startup._confirm_opening_menu()
	if startup.phase != PalStartup.Phase.FADE_TO_GAME:
		_fail("标题菜单的“新的故事”没有进入新游戏转场")
		return
	startup.free()
	await process_frame

	var lab_scene := load("res://scenes/import_lab.tscn") as PackedScene
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
	if lab._rng_button.disabled:
		_fail("资源实验室没有从压缩 RNG.MKF 启用运行时预览入口")
		return
	if lab._explore_button.get_global_rect().intersects(lab._load_save_button.get_global_rect()):
		_fail("开始新游戏与读取存档按钮发生布局重叠")
		return
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
