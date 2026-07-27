# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实窗口渲染器检查 1920×1080 Shell 与 320×200 经典 SubViewport 的实际像素布局。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/presentation_shell_1080p.png"
const HD_OUTPUT_PATH := "res://generated/pal/visual_tests/presentation_shell_hd2d_synthetic_1080p.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE)
	var packed := load("res://scenes/presentation_shell.tscn") as PackedScene
	var shell := packed.instantiate() as PalPresentationShell if packed != null else null
	if shell == null:
		printerr("FAIL: 1920×1080 Presentation Shell 无法实例化")
		quit(1)
		return
	root.add_child(shell)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var container := shell.get_node_or_null("ClassicViewportContainer") as SubViewportContainer
	var expected_rect := Rect2(160, 40, 1600, 1000)
	if container == null or Rect2(container.position, container.size) != expected_rect:
		printerr("FAIL: 经典 SubViewport 区域错误：%s" % (Rect2(container.position, container.size) if container != null else Rect2()))
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE:
		printerr("FAIL: 真实窗口截图尺寸错误：%s" % (image.get_size() if image != null else Vector2i.ZERO))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		printerr("FAIL: 无法写入 Presentation Shell 截图：%s" % error_string(save_error))
		quit(1)
		return

	var hd_world := shell.get_node_or_null("HdWorldRoot") as PalHd2DWorld
	var snapshot := PalWorldPresentationSnapshot.new()
	snapshot.camera_focus_3d = Vector3.ZERO
	for index in range(3):
		var actor := PalPresentationActor.new()
		actor.kind = PalPresentationActor.KIND_PARTY if index == 0 else PalPresentationActor.KIND_EVENT
		actor.source_object_id = index
		actor.sprite_number = index + 1
		actor.logical_id = "character/synthetic_%02d/field" % index
		actor.world_position_3d = Vector3(float(index - 1) * 1.2, 0.0, float(index) * -0.6)
		if index == 0:
			snapshot.party.append(actor)
		else:
			snapshot.events.append(actor)
	hd_world.sync_snapshot(snapshot)
	shell.set_presentation_mode(PalPresentationShell.MODE_HD2D)
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var hd_image := root.get_texture().get_image()
	var hd_save_error := hd_image.save_png(ProjectSettings.globalize_path(HD_OUTPUT_PATH)) if hd_image != null else ERR_CANT_CREATE
	if hd_image == null or hd_image.get_size() != PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE or hd_save_error != OK:
		printerr("FAIL: HD-2D 合成占位世界真实窗口截图失败")
		quit(1)
		return
	print("PASS: 1920×1080 Presentation Shell 真实窗口截图：%s / %s" % [OUTPUT_PATH, HD_OUTPUT_PATH])
	quit(0)
