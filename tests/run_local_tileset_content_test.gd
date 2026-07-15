# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 验证本机导入的每张 MAP 都有可加载 TileSet/TileMapLayer，且所有可玩场景引用完整。
## 测试只输出数量和错误编号，不输出或提交任何原版图像、文字或资源。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var directory := DirAccess.open("res://generated/pal/content/world/maps")
	if directory == null:
		_fail("无法读取生成地图目录")
		return
	var map_numbers: Array[int] = []
	for file_name in directory.get_files():
		if file_name.ends_with(".map"):
			map_numbers.append(file_name.get_basename().to_int())
	map_numbers.sort()
	for map_number in map_numbers:
		var packed := database.load_tilemap_scene(map_number)
		if packed == null:
			_fail("地图 %d：%s" % [map_number, database.error_message])
			return
		var instance := packed.instantiate()
		var bottom := instance.get_node_or_null("StaticBottom") as TileMapLayer
		var top := instance.get_node_or_null("StaticTop") as TileMapLayer
		if bottom == null or top == null or bottom.tile_set == null or top.tile_set != bottom.tile_set:
			instance.free()
			_fail("地图 %d 的 TileMapLayer/TileSet 节点结构不完整" % map_number)
			return
		var origin_data := bottom.get_cell_tile_data(PalTileSetBuilder.pal_half_to_map_cell(0, 0, 0))
		if origin_data == null or int(origin_data.get_custom_data("pal_sprite_index")) < 0:
			instance.free()
			_fail("地图 %d 缺少原点 TileData 自定义数据" % map_number)
			return
		instance.free()

	var referenced: Dictionary = {}
	for scene_index in range(database.scenes.size() - 1):
		var map_number := database.scenes[scene_index].map_number
		if map_number <= 0:
			continue
		referenced[map_number] = true
		if not map_number in map_numbers:
			_fail("场景 %d 引用了未生成的地图 %d" % [scene_index, map_number])
			return
	print("PASS: %d 张导入地图、%d 个可玩场景、%d 个唯一场景地图均可加载 TileSet/TileMapLayer" % [map_numbers.size(), database.scenes.size() - 1, referenced.size()])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
