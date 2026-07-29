# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 真实窗口验证 Map 012 使用 384×216 TileMap 视野，且经典 UI 保持中央 320×200。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/map_012_remaster_2d_1080p.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE)
	var packed := load("res://scenes/presentation_shell.tscn") as PackedScene
	var shell := packed.instantiate() as PalPresentationShell if packed != null else null
	if shell == null:
		_fail("无法实例化 Presentation Shell")
		return
	shell.initial_classic_scene = ""
	root.add_child(shell)
	shell.set_presentation_mode(PalPresentationShell.MODE_REMASTER_2D)
	if not PalDebugCheckpoint.request("wine_dish_toast"):
		_fail("无法准备 Map 012 客栈检查点")
		return
	if shell.open_classic_scene("res://scenes/map_explorer.tscn") != OK:
		_fail("无法在重制 Shell 中打开地图探索场景")
		return
	for _frame in range(40):
		await process_frame
	await RenderingServer.frame_post_draw

	var viewport := shell.get_node_or_null("ClassicViewportContainer/ClassicViewport") as SubViewport
	var explorer := viewport.get_node_or_null("MapExplorer") if viewport != null else null
	var world: PalTileMapWorld = explorer._tile_world if explorer != null else null
	var snapshot: PalWorldPresentationSnapshot = world.latest_snapshot if world != null else null
	if viewport == null or viewport.size != Vector2i(384, 216):
		_fail("Map 012 重制 SubViewport 不是 384×216")
		return
	if explorer == null or explorer._ui_root.position != Vector2(32, 8) or explorer._ui_root.size != Vector2(320, 200):
		_fail("Map 012 经典 UI 核心没有固定在 (32,8,320,200)")
		return
	if world == null or world.loaded_map_number != 12 or world.presentation_mode() != PalTileMapWorld.PRESENTATION_REMASTER_2D:
		_fail("Map 012 没有使用正式 PalTileMapWorld 重制配置")
		return
	var sync_ok := true
	if snapshot == null:
		sync_ok = world.sync_world(explorer._session, explorer._scene_events, explorer._script_camera_offset)
		snapshot = world.latest_snapshot
	if snapshot == null or snapshot.logical_view_size != Vector2i(384, 216):
		_fail("Map 012 没有生成 384×216 共享展示快照：sync=%s map=%s db=%s roles=%s error=%s｜%s" % [sync_ok, world._map_instance != null, world._database != null, explorer._session.party_roles, world.error_message, explorer._status.text])
		return
	var expected_origin := snapshot.viewport_position + snapshot.camera_offset - Vector2i(32, 8)
	if snapshot.render_viewport_position != expected_origin:
		_fail("重制视野没有在经典相机中心周围扩展：%s" % snapshot.render_viewport_position)
		return

	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080):
		_fail("Map 012 重制截图不是 1920×1080")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		_fail("无法保存 Map 012 重制截图")
		return
	print("PASS: Map 012 384×216 TileMap 与中央经典 UI：%s" % OUTPUT_PATH)
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
