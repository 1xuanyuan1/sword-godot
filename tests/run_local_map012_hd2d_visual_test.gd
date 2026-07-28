# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 真实窗口加载 Map 012 技术审核包，验证环境、经典 Sprite3D 回退和 1920×1080 像素输出。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/map_012_hd2d_technical_review.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE)
	var packed := load("res://scenes/presentation_shell.tscn") as PackedScene
	var shell := packed.instantiate() as PalPresentationShell if packed != null else null
	if shell == null:
		_fail("无法实例化 Presentation Shell")
		return
	root.add_child(shell)
	for _frame in range(90):
		await process_frame
	await RenderingServer.frame_post_draw

	var hd_world := shell.get_node_or_null("HdWorldRoot") as PalHd2DWorld
	if hd_world == null or not hd_world.has_active_environment():
		_fail("Map 012 没有加载模块化 HD 环境；请传入技术预览和私仓参数")
		return
	var environment := hd_world.active_environment()
	if environment.name != "Map012Environment" or not environment.has_node("Architecture") or not environment.has_node("Furniture"):
		_fail("Map 012 环境缺少模块化 Architecture/Furniture 节点")
		return
	var visible_actors := 0
	var actor_root := hd_world.get_node_or_null("ActorRoot") as Node3D
	if actor_root != null:
		for child in actor_root.get_children():
			if child is Sprite3D and child.visible:
				visible_actors += 1
	if visible_actors <= 0:
		_fail("经典 MGO Sprite3D 回退没有显示任何当前人物")
		return

	var image := root.get_texture().get_image()
	if image == null or image.get_size() != PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE:
		_fail("真实窗口截图尺寸不是 1920×1080")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		_fail("保存截图失败：%s" % error_string(save_error))
		return
	print("PASS: Map 012 HD-2D 环境与 %d 个 Sprite3D 人物：%s" % [visible_actors, OUTPUT_PATH])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
