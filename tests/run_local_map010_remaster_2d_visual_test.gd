# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 真实窗口验证 Map 010 醉道士剧情机位使用私有高清 TileSet 与正式 PalTileMapWorld。
extends SceneTree

const OUTPUT_PATH := "res://generated/pal/visual_tests/map_010_remaster_2d_1080p.png"
const PRIVATE_MANIFEST := "res://sword-assets/manifests/remaster/chapter_01_map_010.v1.json"


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
	if not FileAccess.file_exists(PRIVATE_MANIFEST):
		_fail("Map 010 私有高清 Manifest 不存在")
		return
	if not PalDebugCheckpoint.request("drunken_swordsman"):
		_fail("无法准备醉道士剧情检查点")
		return
	if shell.open_classic_scene("res://scenes/map_explorer.tscn") != OK:
		_fail("无法在重制 Shell 中打开地图探索场景")
		return
	for _frame in range(40):
		await process_frame

	var viewport := shell.get_node_or_null("ClassicViewportContainer/ClassicViewport") as SubViewport
	var explorer := viewport.get_node_or_null("MapExplorer") if viewport != null else null
	var world: PalTileMapWorld = explorer._tile_world if explorer != null else null
	if viewport == null or viewport.size != Vector2i(384, 216):
		_fail("Map 010 重制 SubViewport 不是 384×216")
		return
	if world == null or world.loaded_map_number != 10:
		_fail("醉道士检查点没有载入 Map 010 的正式 PalTileMapWorld")
		return
	var preview_resolver := PalRemasterAssetResolver.new()
	preview_resolver.set_unapproved_preview_enabled(true)
	preview_resolver.set_failure_warnings_enabled(false)
	if not preview_resolver.reload():
		_fail("Map 010 私有高清资源预览清单无法加载：%s" % preview_resolver.error_message)
		return
	world.set_remaster_asset_resolver(preview_resolver)
	if not world.sync_world(explorer._session, explorer._scene_events, explorer._script_camera_offset):
		_fail("Map 010 高清 TileSet 同步失败：%s" % world.error_message)
		return
	if world.presentation_mode() != PalTileMapWorld.PRESENTATION_REMASTER_2D or not world.remaster_map_active():
		_fail("Map 010 私有 TileSet 没有在正式重制路径启用")
		return
	var snapshot: PalWorldPresentationSnapshot = world.latest_snapshot
	if snapshot == null or snapshot.logical_view_size != Vector2i(384, 216):
		_fail("Map 010 没有生成 384×216 共享展示快照")
		return
	var expected_origin := snapshot.viewport_position + snapshot.camera_offset - Vector2i(32, 8)
	if snapshot.render_viewport_position != expected_origin:
		_fail("Map 010 高清视野偏离经典相机中心：%s" % snapshot.render_viewport_position)
		return

	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080):
		_fail("Map 010 重制截图不是 1920×1080")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		_fail("无法保存 Map 010 重制截图")
		return
	print("PASS: Map 010 正式 TileMap 384×216 高清截图：%s" % OUTPUT_PATH)
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
