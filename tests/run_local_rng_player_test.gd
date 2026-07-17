# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成内容验证剧情脚本引用的 RNG 动画均已导入，并实际播放一个两帧区间。
## Headless 验证时序；带窗口时把御剑术首帧写入被 Git 忽略的视觉目录，绝不提交原版画面。
extends SceneTree

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var referenced_animations: Dictionary = {}
	for entry in database.scripts:
		if entry.operation == 0x0036:
			referenced_animations[entry.operands[0]] = true
	if referenced_animations.is_empty():
		_fail("脚本中没有找到 RNG 动画引用")
		return
	var total_frames := 0
	for animation_number in referenced_animations:
		var directory_path := database.root_path.get_base_dir().path_join("rng/%03d" % animation_number)
		var directory := DirAccess.open(ProjectSettings.globalize_path(directory_path))
		if directory == null:
			_fail("脚本引用的 RNG 动画 %d 尚未导入" % animation_number)
			return
		var frame_count := 0
		for file_name in directory.get_files():
			if file_name.to_lower().ends_with(".png"):
				frame_count += 1
		if frame_count == 0:
			_fail("RNG 动画 %d 没有可播放帧" % animation_number)
			return
		total_frames += frame_count
	var player := PalRngPlayer.new()
	root.add_child(player)
	player.configure(database)
	await process_frame
	var finished := [false]
	player.playback_finished.connect(func() -> void: finished[0] = true)
	var first_animation := int(referenced_animations.keys()[0])
	if not player.play(first_animation, 0, 1, 1000):
		_fail("无法开始播放 RNG 动画 %d" % first_animation)
		return
	player.set_playback_paused(true)
	player._process(1.0)
	if player._frame_index != 0 or not player.visible:
		_fail("RNG 暂停时没有保持第一帧可见")
		return
	player.set_playback_paused(false)
	# Headless 帧间隔可能接近零；显式推进足够的测试时间，不依赖机器渲染速度。
	player._process(0.01)
	await process_frame
	if not finished[0] or player.visible:
		_fail("RNG 两帧区间没有结束或没有正确隐藏")
		return
	player.free()

	# 山神庙脚本在 RNG #1 前执行 0050。官方会让 RNG 第一帧消费待渐显并暂停电影计时；
	# 这里使用完整 MapExplorer 验证 HUD 黑色遮罩确实被揭开，而不只检查请求编号。
	DebugCheckpoint._pending = {
		"id": "training_rng_regression",
		"scene": 10,
		"script": 6622,
		"event": 196,
		"position": Vector2i(672, 400),
		"music": 36,
	}
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and not explorer._rng_player.visible:
		if explorer._script_vm.waiting_for_dialog:
			explorer._dialog_box.reveal_all()
			explorer._script_vm.advance_dialog()
		await process_frame
	if not explorer._rng_player.visible or not explorer._rng_player._paused or not explorer._screen_fade_active:
		_fail("御剑术 RNG #1 没有以暂停首帧开始渐显")
		return
	if explorer._rng_player._frame_index != 0 or not explorer._fade_overlay.visible:
		_fail("御剑术 RNG #1 渐显前没有保持第一帧或黑色遮罩状态")
		return
	await create_timer(0.7).timeout
	if explorer._screen_fade_active or explorer._fade_overlay.visible or explorer._rng_player._paused or not explorer._rng_player.visible or explorer._rng_player._frame_index > 1:
		_fail("御剑术 RNG #1 渐显后没有揭开画面并从首帧继续：frame=%d" % explorer._rng_player._frame_index)
		return
	if DisplayServer.get_name() != "headless":
		await process_frame
		var image: Image = explorer.get_viewport().get_texture().get_image()
		image.resize(320, 200, Image.INTERPOLATE_NEAREST)
		var nonblack_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color: Color = image.get_pixel(x, y)
				if color.r > 0.04 or color.g > 0.04 or color.b > 0.04:
					nonblack_pixels += 1
		if nonblack_pixels < 5000:
			_fail("御剑术 RNG #1 渐显后真实画面仍接近全黑：%d" % nonblack_pixels)
			return
		var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
		DirAccess.make_dir_recursive_absolute(output_directory)
		image.save_png(output_directory.path_join("training_rng_001.png"))
	explorer._rng_player.stop_playback(false)
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
	explorer.free()
	print("PASS: %d 个脚本 RNG 动画共 %d 帧均已导入；御剑术 RNG #1 首帧渐显并继续播放" % [referenced_animations.size(), total_frames])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
