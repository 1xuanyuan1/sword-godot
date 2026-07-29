# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实窗口检查 1920×1080 Shell、384×216 重制视野和中央 320×200 经典 UI 核心。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/presentation_shell_1080p.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE)
	var packed := load("res://scenes/presentation_shell.tscn") as PackedScene
	var shell := packed.instantiate() as PalPresentationShell if packed != null else null
	if shell == null:
		_fail("1920×1080 Presentation Shell 无法实例化")
		return
	root.add_child(shell)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var container := shell.get_node_or_null("ClassicViewportContainer") as SubViewportContainer
	var expected_rect := Rect2(160, 40, 1600, 1000)
	if container == null or Rect2(container.position, container.size) != expected_rect:
		_fail("经典 SubViewport 区域错误：%s" % (Rect2(container.position, container.size) if container != null else Rect2()))
		return
	if shell.get_node_or_null("HdWorldRoot") != null or shell.get_node_or_null("RemasterHud") == null:
		_fail("3D 世界应已退役，并保留高清 2D HUD 承载节点")
		return
	shell.set_presentation_mode(PalPresentationShell.MODE_REMASTER_2D)
	var viewport := shell.get_node_or_null("ClassicViewportContainer/ClassicViewport") as SubViewport
	if not container.visible or not is_equal_approx(container.modulate.a, 1.0) or not shell.remaster_renderer_ready():
		_fail("高清 2D 模式必须保持正式 TileMap/经典内容回退可见")
		return
	if Rect2(container.position, container.size) != Rect2(0, 0, 1920, 1080) or viewport == null or viewport.size != Vector2i(384, 216):
		_fail("重制视野没有按 384×216 的 5 倍整数比例铺满 1080p")
		return
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE:
		_fail("真实窗口截图尺寸错误：%s" % (image.get_size() if image != null else Vector2i.ZERO))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		_fail("无法写入 Presentation Shell 截图：%s" % error_string(save_error))
		return
	print("PASS: 1920×1080 经典回退与纯 2D Presentation Shell：%s" % OUTPUT_PATH)
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
