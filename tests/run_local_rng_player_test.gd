# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成内容验证剧情脚本引用的 RNG 动画均已导入，并实际播放一个两帧区间。
## 测试只输出动画和帧数量，不提交或转储原版画面。
extends SceneTree


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
	# Headless 帧间隔可能接近零；显式推进足够的测试时间，不依赖机器渲染速度。
	player._process(0.01)
	await process_frame
	if not finished[0] or player.visible:
		_fail("RNG 两帧区间没有结束或没有正确隐藏")
		return
	print("PASS: %d 个脚本 RNG 动画共 %d 帧均已导入，HUD 两帧播放完成" % [referenced_animations.size(), total_frames])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
