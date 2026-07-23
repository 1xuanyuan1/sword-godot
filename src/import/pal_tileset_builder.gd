# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c and scene.c map semantics.
# SPDX-License-Identifier: GPL-3.0-or-later
## 把一张 PAL MAP/GOP 组合转换为 Godot 4.7 的 TileSet 和 TileMapLayer 场景。
## 生成结果只写入被 Git 忽略的本地内容目录，不包含在项目发布仓库中。
class_name PalTileSetBuilder
extends RefCounted

const TILE_SIZE := Vector2i(32, 16)
const PAL_FRAME_SIZE := Vector2i(32, 15)
const ATLAS_COLUMNS := 32
const ATLAS_SOURCE_ID := 0
const LAYER_BOTTOM := 0
const LAYER_TOP := 1
# SDLPal 在地图外复用 (0,0,0) 底层图块；该范围足以覆盖越界的 320×200 视口。
const VIEWPORT_PADDING_X := 12
const VIEWPORT_PADDING_Y := 15


## 将 PAL 的 `(map_x, map_y, half)` 转成 Godot 等距单元坐标。
## 该换算使单元中心精确落在 PAL 世界坐标 `(x×32+half×16, y×16+half×8)`。
static func pal_half_to_map_cell(map_x: int, map_y: int, half: int) -> Vector2i:
	return Vector2i(map_x + map_y + half, map_y - map_x)


## 将 Godot 等距单元坐标还原为 `(map_x, map_y, half)`；结果用 `Vector3i` 保存。
static func map_cell_to_pal_half(cell: Vector2i) -> Vector3i:
	var half := posmod(cell.x + cell.y, 2)
	var map_x := int((cell.x - cell.y - half) / 2.0)
	var map_y := int((cell.x + cell.y - half) / 2.0)
	return Vector3i(map_x, map_y, half)


## 在内存中构建 TileSet；输入无效或 GOP 帧不是 32×15 时返回 `null`。
## 主要供合成测试和运行时诊断使用，正式导入应调用 `build_map_resources`。
static func build_tileset(map_data: PalMapData, tile_sprite: PalSprite) -> TileSet:
	var bundle := _build_bundle(map_data, tile_sprite)
	return bundle.get("tile_set") as TileSet


## 生成一张地图的外部 TileSet 和包含四个 TileMapLayer 的 PackedScene。
## `content_root` 可为绝对路径、`res://` 或 `user://`；返回字典包含成功状态、路径和诊断。
static func build_map_resources(map_number: int, map_data: PalMapData, tile_sprite: PalSprite, content_root: String) -> Dictionary:
	var result := {
		"success": false,
		"error": "",
		"map_number": map_number,
		"tile_frames": 0,
		"alternative_tiles": 0,
		"fallback_bottom_tiles": 0,
		"ignored_top_tiles": 0,
		"tileset_path": "",
		"tilemap_path": "",
	}
	var bundle := _build_bundle(map_data, tile_sprite)
	if bundle.get("tile_set") == null:
		result["error"] = str(bundle.get("error", "TileSet 构建失败"))
		return result

	var absolute_root := _absolute_path(content_root)
	var tileset_directory := absolute_root.path_join("world/tilesets")
	var tilemap_directory := absolute_root.path_join("world/tilemaps")
	for directory in [tileset_directory, tilemap_directory]:
		var make_error := DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			result["error"] = "无法创建 TileMap 生成目录：%s" % directory
			return result

	# 动态创建的 PortableCompressedTexture2D 需要二进制 .res 才能保存实际像素数据。
	var tileset_path := _resource_path(tileset_directory.path_join("%03d.res" % map_number))
	var tilemap_path := _resource_path(tilemap_directory.path_join("%03d.tscn" % map_number))
	var tile_set: TileSet = bundle["tile_set"]
	tile_set.resource_name = "PAL Map %03d TileSet" % map_number
	var save_error := ResourceSaver.save(tile_set, tileset_path)
	if save_error != OK:
		result["error"] = "无法保存地图 %d TileSet：%s" % [map_number, error_string(save_error)]
		return result

	# 重新加载外部资源，确保 PackedScene 引用单独的 .tres，而不是再次内嵌一份图集。
	var external_tileset := ResourceLoader.load(tileset_path, "TileSet", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	if external_tileset == null:
		result["error"] = "无法重新加载地图 %d TileSet：%s" % [map_number, tileset_path]
		return result
	var packed_scene := _build_map_scene(
		map_number,
		map_data,
		external_tileset,
		bundle["alternatives"],
		int(bundle["fallback_bottom_index"]),
		tile_sprite.frame_count()
	)
	if packed_scene == null:
		result["error"] = "无法打包地图 %d TileMapLayer 场景" % map_number
		return result
	save_error = ResourceSaver.save(packed_scene, tilemap_path)
	if save_error != OK:
		result["error"] = "无法保存地图 %d TileMapLayer 场景：%s" % [map_number, error_string(save_error)]
		return result

	result["success"] = true
	result["tile_frames"] = tile_sprite.frame_count()
	result["alternative_tiles"] = (bundle["alternatives"] as Dictionary).size()
	result["fallback_bottom_tiles"] = int(bundle["fallback_bottom_tiles"])
	result["ignored_top_tiles"] = int(bundle["ignored_top_tiles"])
	result["tileset_path"] = tileset_path
	result["tilemap_path"] = tilemap_path
	return result


static func _build_bundle(map_data: PalMapData, tile_sprite: PalSprite) -> Dictionary:
	if map_data == null or not map_data.is_valid():
		return {"tile_set": null, "error": "PAL 地图数据无效"}
	if tile_sprite == null or not tile_sprite.is_valid():
		return {"tile_set": null, "error": "PAL GOP Sprite 无效"}

	var atlas_rows := ceili(tile_sprite.frame_count() / float(ATLAS_COLUMNS))
	var atlas_size := Vector2i(ATLAS_COLUMNS * TILE_SIZE.x, maxi(1, atlas_rows) * TILE_SIZE.y)
	var atlas_bytes := PackedByteArray()
	atlas_bytes.resize(atlas_size.x * atlas_size.y * 2)
	atlas_bytes.fill(0)
	for frame_index in range(tile_sprite.frame_count()):
		var frame := RleDecoder.decode(tile_sprite.get_frame(frame_index))
		if not frame.is_valid():
			return {"tile_set": null, "error": "GOP 图块 %d 解码失败：%s" % [frame_index, frame.error_message]}
		if Vector2i(frame.width, frame.height) != PAL_FRAME_SIZE:
			return {"tile_set": null, "error": "GOP 图块 %d 应为 32×15，实际为 %d×%d" % [frame_index, frame.width, frame.height]}
		var atlas_cell := _atlas_coords(frame_index)
		var target_origin := Vector2i(atlas_cell.x * TILE_SIZE.x, atlas_cell.y * TILE_SIZE.y)
		for source_y in range(frame.height):
			for source_x in range(frame.width):
				var source_index := source_y * frame.width + source_x
				var destination_pixel := (target_origin.y + source_y) * atlas_size.x + target_origin.x + source_x
				atlas_bytes[destination_pixel * 2] = frame.indices[source_index]
				atlas_bytes[destination_pixel * 2 + 1] = frame.opacity[source_index]

	var atlas_image := Image.create_from_data(atlas_size.x, atlas_size.y, false, Image.FORMAT_RG8, atlas_bytes)
	var atlas_texture := PortableCompressedTexture2D.new()
	# 动态纹理若不保留压缩缓冲，首次加载后将只剩尺寸，无法再次保存进 TileSet。
	atlas_texture.keep_compressed_buffer = true
	atlas_texture.create_from_image(atlas_image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	atlas_texture.resource_name = "PAL indexed map atlas"

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	_add_custom_data_layer(tile_set, "pal_layer", TYPE_INT)
	_add_custom_data_layer(tile_set, "pal_sprite_index", TYPE_INT)
	_add_custom_data_layer(tile_set, "pal_blocked", TYPE_BOOL)
	_add_custom_data_layer(tile_set, "pal_height", TYPE_INT)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = TILE_SIZE
	for frame_index in range(tile_sprite.frame_count()):
		atlas_source.create_tile(_atlas_coords(frame_index))
	tile_set.add_source(atlas_source, ATLAS_SOURCE_ID)

	var alternatives: Dictionary = {}
	var fallback_bottom_index := PalMapData.bottom_sprite_index(map_data.tile_value(0, 0, 0))
	if fallback_bottom_index < 0 or fallback_bottom_index >= tile_sprite.frame_count():
		return {"tile_set": null, "error": "地图左上角的底层后备图块无效：%d" % fallback_bottom_index}
	var fallback_bottom_tiles := 0
	var ignored_top_tiles := 0
	for map_y in range(PalMapData.HEIGHT):
		for map_x in range(PalMapData.WIDTH):
			for half in range(PalMapData.HALVES):
				var value := map_data.tile_value(map_x, map_y, half)
				var bottom_index := PalMapData.bottom_sprite_index(value)
				if bottom_index < 0 or bottom_index >= tile_sprite.frame_count():
					# SDLPal `PAL_MapBlitToSurface` 在底层帧缺失时复用 (0,0,0) 图块。
					bottom_index = fallback_bottom_index
					fallback_bottom_tiles += 1
				var bottom_key := _alternative_key(LAYER_BOTTOM, bottom_index, PalMapData.is_blocked(value), PalMapData.tile_height(value, false))
				if not alternatives.has(bottom_key):
					var bottom_alternative := _create_alternative(atlas_source, bottom_index, LAYER_BOTTOM, PalMapData.is_blocked(value), PalMapData.tile_height(value, false))
					if bottom_alternative < 0:
						return {"tile_set": null, "error": "无法创建底层 alternative tile：%s" % bottom_key}
					alternatives[bottom_key] = bottom_alternative

				var top_index := PalMapData.top_sprite_index(value)
				if top_index < 0:
					continue
				if top_index >= tile_sprite.frame_count():
					# 官方渲染器对缺失上层帧直接跳过，不影响底层阻挡语义。
					ignored_top_tiles += 1
					continue
				var top_key := _alternative_key(LAYER_TOP, top_index, false, PalMapData.tile_height(value, true))
				if not alternatives.has(top_key):
					var top_alternative := _create_alternative(atlas_source, top_index, LAYER_TOP, false, PalMapData.tile_height(value, true))
					if top_alternative < 0:
						return {"tile_set": null, "error": "无法创建上层 alternative tile：%s" % top_key}
					alternatives[top_key] = top_alternative

	return {
		"tile_set": tile_set,
		"alternatives": alternatives,
		"fallback_bottom_index": fallback_bottom_index,
		"fallback_bottom_tiles": fallback_bottom_tiles,
		"ignored_top_tiles": ignored_top_tiles,
		"error": "",
	}


static func _build_map_scene(map_number: int, map_data: PalMapData, tile_set: TileSet, alternatives: Dictionary, fallback_bottom_index: int, frame_count: int) -> PackedScene:
	var root := Node2D.new()
	root.name = "PalTileMap%03d" % map_number
	var static_bottom := _create_layer("StaticBottom", tile_set, 0, false)
	var static_top := _create_layer("StaticTop", tile_set, 1, false)
	var cover_bottom := _create_layer("CoverBottom", tile_set, 2, true)
	var cover_top := _create_layer("CoverTop", tile_set, 2, true)
	for layer in [static_bottom, static_top, cover_bottom, cover_top]:
		root.add_child(layer)
		layer.owner = root

	for map_y in range(PalMapData.HEIGHT):
		for map_x in range(PalMapData.WIDTH):
			for half in range(PalMapData.HALVES):
				var cell := pal_half_to_map_cell(map_x, map_y, half)
				var value := map_data.tile_value(map_x, map_y, half)
				var bottom_index := PalMapData.bottom_sprite_index(value)
				if bottom_index < 0 or bottom_index >= frame_count:
					bottom_index = fallback_bottom_index
				var bottom_key := _alternative_key(LAYER_BOTTOM, bottom_index, PalMapData.is_blocked(value), PalMapData.tile_height(value, false))
				static_bottom.set_cell(cell, ATLAS_SOURCE_ID, _atlas_coords(bottom_index), int(alternatives[bottom_key]))
				var top_index := PalMapData.top_sprite_index(value)
				if top_index >= 0 and top_index < frame_count:
					var top_key := _alternative_key(LAYER_TOP, top_index, false, PalMapData.tile_height(value, true))
					static_top.set_cell(cell, ATLAS_SOURCE_ID, _atlas_coords(top_index), int(alternatives[top_key]))

	# 原版在视口超出 64×128 边界时仍绘制左上角底层图块，楼梯等合法落点会依赖它。
	var fallback_value := map_data.tile_value(0, 0, 0)
	var fallback_key := _alternative_key(LAYER_BOTTOM, fallback_bottom_index, PalMapData.is_blocked(fallback_value), PalMapData.tile_height(fallback_value, false))
	for map_y in range(-VIEWPORT_PADDING_Y, PalMapData.HEIGHT + VIEWPORT_PADDING_Y):
		for map_x in range(-VIEWPORT_PADDING_X, PalMapData.WIDTH + VIEWPORT_PADDING_X):
			if map_x >= 0 and map_x < PalMapData.WIDTH and map_y >= 0 and map_y < PalMapData.HEIGHT:
				continue
			for half in range(PalMapData.HALVES):
				var cell := pal_half_to_map_cell(map_x, map_y, half)
				static_bottom.set_cell(cell, ATLAS_SOURCE_ID, _atlas_coords(fallback_bottom_index), int(alternatives[fallback_key]))

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	root.free()
	return packed_scene if pack_error == OK else null


static func _create_layer(layer_name: String, tile_set: TileSet, z: int, y_sorted: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	# Godot 等距原点位于首格中心 (16,8)；PAL 的 (0,0,0) 中心是世界原点。
	layer.position = Vector2(-16, -8)
	layer.z_index = z
	layer.y_sort_enabled = y_sorted
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


static func _create_alternative(source: TileSetAtlasSource, sprite_index: int, layer: int, blocked: bool, height: int) -> int:
	var coords := _atlas_coords(sprite_index)
	var alternative_id := source.create_alternative_tile(coords)
	if alternative_id < 0:
		return -1
	var tile_data := source.get_tile_data(coords, alternative_id)
	if tile_data == null:
		return -1
	tile_data.set_custom_data("pal_layer", layer)
	tile_data.set_custom_data("pal_sprite_index", sprite_index)
	tile_data.set_custom_data("pal_blocked", blocked)
	tile_data.set_custom_data("pal_height", height)
	# SDLPal 覆盖块的基准 Y 为单元中心 + 7 + 图层 + 逻辑高度×8。
	tile_data.y_sort_origin = 7 + layer + height * 8
	return alternative_id


static func _add_custom_data_layer(tile_set: TileSet, layer_name: String, type: Variant.Type) -> void:
	var layer_index := tile_set.get_custom_data_layers_count()
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(layer_index, layer_name)
	tile_set.set_custom_data_layer_type(layer_index, type)


static func _alternative_key(layer: int, sprite_index: int, blocked: bool, height: int) -> String:
	return "%d:%d:%d:%d" % [layer, sprite_index, 1 if blocked else 0, height]


static func _atlas_coords(sprite_index: int) -> Vector2i:
	return Vector2i(sprite_index % ATLAS_COLUMNS, int(sprite_index / ATLAS_COLUMNS))


static func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path.simplify_path()


static func _resource_path(absolute_path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var user_root := ProjectSettings.globalize_path("user://").trim_suffix("/")
	if absolute_path.begins_with(user_root + "/"):
		return "user://" + absolute_path.trim_prefix(user_root + "/")
	# 打包运行时 res:// 位于 PCK，globalize_path 可能返回空根或 `/`；不能因此
	# 把任意绝对用户路径误标成 res://Users/...。
	if not project_root.is_empty() and project_root != "/" and absolute_path.begins_with(project_root + "/"):
		return "res://" + absolute_path.trim_prefix(project_root + "/")
	return absolute_path
