# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机压缩 RNG.MKF 验证全部动画、跳段预热、单纹理播放和御剑术首帧渐显。
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
	var archive_path := database.root_path.path_join("archives/rng.mkf")
	var archive := MkfArchive.load_file(archive_path)
	if not archive.is_valid():
		_fail("RNG 运行时归档不可用：%s" % archive.error_message)
		return
	var total_frames := 0
	var animation_count := 0
	for animation_number in range(archive.chunk_count()):
		var chunk := archive.get_chunk(animation_number)
		if chunk.is_empty():
			continue
		var animation := RngAnimation.from_mkf_chunk(chunk)
		var frame_count := animation.playable_frame_count() if animation.is_valid() else 0
		if frame_count <= 0:
			continue
		animation_count += 1
		total_frames += frame_count
		if referenced_animations.has(animation_number):
			referenced_animations[animation_number] = frame_count
	if animation_count != 12 or total_frames != 1464:
		_fail("RNG 运行时归档统计错误：animations=%d frames=%d" % [animation_count, total_frames])
		return
	for animation_number in referenced_animations:
		if int(referenced_animations[animation_number]) <= 0:
			_fail("脚本引用的 RNG 动画 %d 不可播放" % animation_number)
			return
	var full_stream := RngPlaybackStream.new()
	if not full_stream.configure(archive_path):
		_fail("RNG 全量流无法配置：%s" % full_stream.error_message)
		return
	for animation_number in range(archive.chunk_count()):
		var expected_frames := full_stream.animation_frame_count(animation_number)
		if expected_frames <= 0:
			continue
		if not full_stream.open(animation_number, 0, -1):
			_fail("RNG 动画 %d 无法打开：%s" % [animation_number, full_stream.error_message])
			return
		while full_stream.has_next():
			if not full_stream.advance():
				_fail("RNG 动画 %d 帧 %d 解码失败：%s" % [animation_number, full_stream.frame_index + 1, full_stream.error_message])
				return
		if full_stream.decoded_frame_count != expected_frames or full_stream.frame_index != expected_frames - 1:
			_fail("RNG 动画 %d 没有完整解码：%d/%d" % [animation_number, full_stream.decoded_frame_count, expected_frames])
			return
	full_stream.close()

	# 从非零帧开始时必须预热前序增量，结果应与手工顺序解码相同。
	var prewarm_animation_number := 1
	var prewarm_target := 10
	var prewarm_animation := RngAnimation.from_mkf_chunk(archive.get_chunk(prewarm_animation_number))
	var baseline_decoder := RngFrameDecoder.new()
	for frame_index in range(prewarm_target + 1):
		if not baseline_decoder.apply_delta(prewarm_animation.decompress_frame(frame_index)):
			_fail("RNG 跳段基准解码失败：%s" % baseline_decoder.error_message)
			return
	var jump_stream := RngPlaybackStream.new()
	if not jump_stream.configure(archive_path) or not jump_stream.open(prewarm_animation_number, prewarm_target, prewarm_target) or jump_stream.current_indices() != baseline_decoder.indices:
		_fail("RNG 非零起始帧没有正确预热前序增量：%s" % jump_stream.error_message)
		return
	var player := PalRngPlayer.new()
	root.add_child(player)
	if not player.configure(database):
		_fail("RNG 播放器无法绑定运行时归档：%s" % player.error_message)
		return
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
	var texture_id := player._texture.get_instance_id()
	player.set_playback_paused(false)
	player._process(0.001)
	if player._frame_index != 1 or player._texture.get_instance_id() != texture_id or player._stream.decoded_frame_count != 2:
		_fail("RNG 播放没有复用单一可更新纹理：frame=%d decoded=%d" % [player._frame_index, player._stream.decoded_frame_count])
		return
	# 最后一帧显示满一个帧间隔后才结束，显式推进避免依赖机器渲染速度。
	player._process(0.001)
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
	if explorer._dialog_box.visible or explorer._rng_player.get_index() >= explorer._dialog_box.get_index():
		_fail("RNG 开始时没有收起旧对话，或电影层阻挡了后续字幕")
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
	print("PASS: RNG.MKF 12 段／1464 帧流式可读，脚本引用、跳段预热、单纹理与御剑术首帧渐显均通过")
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
