# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式 MapExplorer + TileMap 世界验证白河村捕鱼与放鹿动画会在 0050 后及时渐显。
## 带窗口运行时截图只写入被 Git 忽略的 generated/pal/visual_tests/。
extends SceneTree

const OUTPUT_DIR := "res://generated/pal/visual_tests"

var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	await _test_fishing(database)
	if _failure.is_empty():
		await _test_deer_release(database)
	if _failure.is_empty():
		print("PASS: TileMap 正式 MapExplorer 已揭开捕鱼 0–26 帧与放鹿自动动画")
	quit(0 if _failure.is_empty() else 1)


func _test_fishing(database: PalContentDatabase) -> void:
	var fishing_spot: PalEventObject = database.event_objects[830]
	PalDebugCheckpoint._pending = {
		"id": "baihe_fishing_runtime_test",
		"scene": 48,
		"script": 14358,
		"event": fishing_spot.object_id,
		"position": fishing_spot.position + Vector2i(-16, -8),
		"direction": GameSession.DIR_EAST,
		"music": 12,
	}
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	var vm: ScriptVM = explorer._script_vm
	var visible_frames: Dictionary = {}
	var saw_opaque_fade := false
	var screenshot_saved := false
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and (vm.is_busy() or explorer._screen_fade_active or visible_frames.size() < 27):
		saw_opaque_fade = saw_opaque_fade or (explorer._fade_overlay.visible and explorer._fade_overlay.modulate.a > 0.99)
		if not explorer._screen_fade_active and not explorer._fade_overlay.visible:
			var frame: int = explorer._session.scripted_party_frame(0)
			if frame >= 0 and frame <= 26:
				visible_frames[frame] = true
				if frame == 13 and not screenshot_saved:
					screenshot_saved = await _save_runtime_frame(explorer, "baihe_fishing_animation.png")
		if vm.waiting_for_dialog:
			explorer._dialog_box.reveal_all()
			vm.advance_dialog()
		await process_frame
	var failure := ""
	if explorer._tile_world == null or explorer._tile_world.loaded_map_number != database.scenes[48].map_number:
		failure = "捕鱼回归没有载入正式 PalTileMapWorld"
	elif not saw_opaque_fade:
		failure = "捕鱼脚本没有经过 0050 纯黑阶段"
	elif visible_frames.size() != 27:
		failure = "捕鱼动作没有在黑幕揭开后显示完整 0–26 帧：%s" % [visible_frames.keys()]
	elif explorer._screen_fade_active or explorer._fade_overlay.visible:
		failure = "捕鱼动作结束后仍残留黑色遮罩"
	_cleanup_explorer(explorer)
	await process_frame
	if not failure.is_empty():
		_fail(failure)


func _test_deer_release(database: PalContentDatabase) -> void:
	var deer: PalEventObject = database.event_objects[796]
	PalDebugCheckpoint._pending = {
		"id": "baihe_deer_release_runtime_test",
		"scene": 47,
		"script": 14840,
		"event": deer.object_id,
		"position": deer.position + Vector2i(-16, -8),
		"direction": GameSession.DIR_EAST,
		"music": 12,
	}
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	var vm: ScriptVM = explorer._script_vm
	var animated_deer: PalEventObject = explorer._database.event_objects[796]
	var visible_poses: Dictionary = {}
	var saw_opaque_fade := false
	var screenshot_saved := false
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and (vm.is_busy() or explorer._screen_fade_active or visible_poses.size() < 4):
		saw_opaque_fade = saw_opaque_fade or (explorer._fade_overlay.visible and explorer._fade_overlay.modulate.a > 0.99)
		if animated_deer.is_visible() and not explorer._screen_fade_active and not explorer._fade_overlay.visible:
			visible_poses[Vector3i(animated_deer.position.x, animated_deer.position.y, animated_deer.current_frame)] = true
			if visible_poses.size() >= 4 and not screenshot_saved:
				screenshot_saved = await _save_runtime_frame(explorer, "baihe_deer_release.png")
		if vm.waiting_for_dialog:
			explorer._dialog_box.reveal_all()
			vm.advance_dialog()
		await process_frame
	var failure := ""
	if explorer._tile_world == null or explorer._tile_world.loaded_map_number != database.scenes[47].map_number:
		failure = "放鹿回归没有载入正式 PalTileMapWorld"
	elif not saw_opaque_fade:
		failure = "放鹿脚本没有经过 0050 纯黑阶段"
	elif visible_poses.size() < 4:
		failure = "放鹿的 0009 自动动画仍未在黑幕揭开后运动：%s" % [visible_poses.keys()]
	elif explorer._screen_fade_active or explorer._fade_overlay.visible:
		failure = "放鹿动作结束后仍残留黑色遮罩"
	_cleanup_explorer(explorer)
	await process_frame
	if not failure.is_empty():
		_fail(failure)


func _save_runtime_frame(explorer, filename: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	await RenderingServer.frame_post_draw
	var image: Image = explorer.get_viewport().get_texture().get_image()
	if image == null:
		_fail("无法读取 %s 的正式 TileMap 画面" % filename)
		return false
	image.resize(320, 200, Image.INTERPOLATE_NEAREST)
	var nonblack_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r > 0.04 or color.g > 0.04 or color.b > 0.04:
				nonblack_pixels += 1
	if nonblack_pixels < 5000:
		_fail("%s 仍接近全黑：%d 个非黑像素" % [filename, nonblack_pixels])
		return false
	var output_directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_directory)
	if image.save_png(output_directory.path_join(filename)) != OK:
		_fail("无法保存 %s" % filename)
		return false
	return true


func _cleanup_explorer(explorer) -> void:
	if explorer._script_vm != null:
		explorer._script_vm.stop()
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
		explorer._audio_player._music_player.stream = null
		for player in explorer._audio_player._sound_players:
			player.stream = null
	explorer.free()


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
		printerr("FAIL: %s" % message)
