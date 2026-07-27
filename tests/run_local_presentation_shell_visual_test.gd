# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实窗口渲染器检查 1920×1080 Shell 与 320×200 经典 SubViewport 的实际像素布局。
## HD-2D 尚无审核素材时只检查结构，禁止把诊断占位色块保存为视觉成果。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/presentation_shell_1080p.png"


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
	var hd_camera := hd_world.get_node_or_null("FixedCinematicCamera") as Camera3D if hd_world != null else null
	var actor_root := hd_world.get_node_or_null("ActorRoot") as Node3D if hd_world != null else null
	var fallback_ground := hd_world.get_node_or_null("EnvironmentRoot/SyntheticFallbackGround") as MeshInstance3D if hd_world != null else null
	if hd_world == null or hd_camera == null or actor_root == null or fallback_ground == null:
		printerr("FAIL: HD-2D 展示骨架缺少世界、固定镜头、人物根节点或诊断地面")
		quit(1)
		return
	if hd_world.diagnostic_placeholders_enabled or fallback_ground.visible:
		printerr("FAIL: HD-2D 诊断占位必须默认隐藏")
		quit(1)
		return
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
	for child in actor_root.get_children():
		var sprite := child as Sprite3D
		if sprite != null and sprite.visible:
			printerr("FAIL: 缺少审核高清素材时不应显示合成人物：%s" % sprite.name)
			quit(1)
			return
	print("PASS: 1920×1080 经典 Presentation Shell 截图与隐藏占位的 HD-2D 结构：%s" % OUTPUT_PATH)
	quit(0)
