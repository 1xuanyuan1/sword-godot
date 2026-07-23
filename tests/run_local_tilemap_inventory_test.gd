# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 遍历本机导入的全部有效 MAP/GOP，确认每份资源都能由正式 PalTileMapWorld 载入。
## 该结构门禁可使用 headless；固定视口像素差仍由带窗口的视觉测试负责。
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var map_directory := DirAccess.open(database.root_path.path_join("world/maps"))
	var tilemap_directory := DirAccess.open(database.root_path.path_join("world/tilemaps"))
	if map_directory == null or tilemap_directory == null:
		_fail("MAP 或 TileMapLayer 目录缺失")
		return
	var map_numbers: Array[int] = []
	var tilemap_numbers: Dictionary = {}
	for file_name in map_directory.get_files():
		if file_name.ends_with(".map"):
			map_numbers.append(file_name.get_basename().to_int())
	for file_name in tilemap_directory.get_files():
		if file_name.ends_with(".tscn"):
			tilemap_numbers[file_name.get_basename().to_int()] = true
	map_numbers.sort()
	if map_numbers.is_empty() or map_numbers.size() != tilemap_numbers.size():
		_fail("有效 MAP 与 TileMapLayer 数量不一致：%d/%d" % [map_numbers.size(), tilemap_numbers.size()])
		return
	var world := PalTileMapWorld.new()
	root.add_child(world)
	for map_number in map_numbers:
		if not tilemap_numbers.has(map_number):
			_fail("地图 %d 缺少 TileMapLayer 场景" % map_number)
			return
		if not world.load_map(database, map_number):
			_fail("地图 %d 无法由正式 TileMap 世界载入：%s" % [map_number, world.error_message])
			return
		if world.loaded_map_number != map_number or world._static_bottom == null or world._static_top == null:
			_fail("地图 %d 正式 TileMap 节点结构不完整" % map_number)
			return
	var referenced_maps: Dictionary = {}
	for scene in database.scenes:
		if scene.map_number > 0:
			referenced_maps[scene.map_number] = true
	for map_number in referenced_maps:
		if not tilemap_numbers.has(map_number):
			_fail("场景引用地图 %d 没有正式 TileMap 资源" % map_number)
			return
	world.free()
	print("PASS: %d 份有效地图与 %d 个场景引用均可由正式 TileMapLayer 路径载入" % [map_numbers.size(), referenced_maps.size()])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
