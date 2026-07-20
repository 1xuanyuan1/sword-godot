# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 带窗口验证室内暗格、十里坡草药和宝箱的 TileMap 金色采集星芒。
## 截图只写入被 Git 忽略的 generated/pal/visual_tests/。
extends SceneTree

const OUTPUT_DIR := "res://generated/pal/visual_tests"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地 DOS 内容不可用：%s" % database.error_message)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var world := PalTileMapWorld.new()
	viewport.add_child(world)

	var indoor := await _capture_collectible(database, viewport, world, 6, false, "collectible_marker_inn_hidden.png")
	if indoor == null:
		return
	var ten_mile := await _capture_collectible(database, viewport, world, 167, true, "collectible_marker_ten_mile_night.png")
	if ten_mile == null:
		return
	await create_timer(0.30).timeout
	var ten_mile_pulse := await _capture(viewport, "collectible_marker_ten_mile_pulse.png")
	if _pixel_difference(ten_mile, ten_mile_pulse) <= 0:
		_fail("金色星芒没有按 1.2 秒周期产生呼吸像素变化")
		return

	var session := GameSession.new()
	session.reset_new_game()
	var ten_mile_event: PalEventObject = database.event_objects[166]
	var ten_mile_scene := _scene_index_for_event(database, ten_mile_event.object_id)
	session.scene_index = ten_mile_scene
	session.night_palette = true
	session.set_party_world_position(ten_mile_event.position + Vector2i(64, 32))
	session.consume_collectible_marker(ten_mile_event.object_id)
	if not world.sync_world(session, database.events_for_scene(ten_mile_scene)):
		_fail("十里坡拾取后正式世界同步失败：%s" % world.error_message)
		return
	var ten_mile_collected := await _capture(viewport, "collectible_marker_ten_mile_collected.png")
	if _has_marker(world, ten_mile_event.object_id) or _pixel_difference(ten_mile, ten_mile_collected) <= 0:
		_fail("十里坡草药拾取后金色星芒没有消失")
		return

	if not await _capture_chest_states(database, viewport, world, 668):
		return
	print("PASS: 室内暗格、十里坡夜间草药、呼吸动画、宝箱三态和同层 Y-sort 遮挡截图已生成")
	quit(0)


func _capture_collectible(database: PalContentDatabase, viewport: SubViewport, world: PalTileMapWorld, event_object_id: int, night: bool, filename: String) -> Image:
	var event: PalEventObject = database.event_objects[event_object_id - 1]
	var scene_index := _scene_index_for_event(database, event_object_id)
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = scene_index
	session.night_palette = night
	# 保持事件位于视口内，但不要让队伍 Sprite 站在星芒正上方遮住测试像素。
	session.set_party_world_position(event.position + Vector2i(64, 32))
	var scene := database.scenes[scene_index]
	if not world.load_map(database, scene.map_number) or not world.sync_world(session, database.events_for_scene(scene_index)):
		_fail("EventObject %d 的正式 TileMap 无法加载：%s" % [event_object_id, world.error_message])
		return null
	var image := await _capture(viewport, filename)
	if image == null:
		_fail("当前为 dummy renderer；请去掉 --headless 使用 GL Compatibility 运行")
		return null
	if not _has_marker(world, event_object_id):
		_fail("EventObject %d 没有生成采集星芒" % event_object_id)
		return null
	var marker := world._sort_root.get_node_or_null("CollectibleMarker_%d" % event_object_id)
	if marker == null or marker.get_parent() != world._sort_root or not world._sort_root.y_sort_enabled:
		_fail("EventObject %d 的星芒没有进入正式 Y-sort/覆盖层" % event_object_id)
		return null
	return image


func _capture_chest_states(database: PalContentDatabase, viewport: SubViewport, world: PalTileMapWorld, event_object_id: int) -> bool:
	var event: PalEventObject = database.event_objects[event_object_id - 1]
	var scene_index := _scene_index_for_event(database, event_object_id)
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = scene_index
	session.set_party_world_position(event.position + Vector2i(64, 32))
	var scene := database.scenes[scene_index]
	if not world.load_map(database, scene.map_number) or not world.sync_world(session, database.events_for_scene(scene_index)):
		_fail("宝箱正式 TileMap 无法加载：%s" % world.error_message)
		return false
	var closed := await _capture(viewport, "collectible_marker_chest_closed.png")
	if not _has_marker(world, event_object_id):
		_fail("关闭宝箱没有采集星芒")
		return false
	event.current_frame = 1
	world.sync_world(session, database.events_for_scene(scene_index))
	var opened := await _capture(viewport, "collectible_marker_chest_opened.png")
	if not _has_marker(world, event_object_id) or _pixel_difference(closed, opened) <= 0:
		_fail("宝箱打开但尚未获得奖励时没有保留星芒或箱盖没有变化")
		return false
	event.trigger_script = 887
	session.consume_collectible_marker(event_object_id)
	world.sync_world(session, database.events_for_scene(scene_index))
	var collected := await _capture(viewport, "collectible_marker_chest_collected.png")
	if _has_marker(world, event_object_id) or _pixel_difference(opened, collected) <= 0:
		_fail("宝箱取得奖励后星芒没有消失")
		return false
	return true


func _scene_index_for_event(database: PalContentDatabase, event_object_id: int) -> int:
	var event_index := event_object_id - 1
	for scene_index in range(database.scenes.size()):
		var start := database.scenes[scene_index].event_object_index
		var finish := database.event_objects.size() if scene_index + 1 >= database.scenes.size() else database.scenes[scene_index + 1].event_object_index
		if event_index >= start and event_index < finish:
			return scene_index
	return -1


func _has_marker(world: PalTileMapWorld, event_object_id: int) -> bool:
	return world._sort_root != null and world._sort_root.get_node_or_null("CollectibleMarker_%d" % event_object_id) != null


func _capture(viewport: SubViewport, filename: String) -> Image:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename)))
	return image


func _pixel_difference(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var different := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				different += 1
	return different


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
