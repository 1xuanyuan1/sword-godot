# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 严格加载 `pal-map-tileset.json`；地图实际引用帧不完整时整张地图回退经典 TileSet。
class_name PalRemasterMapTileset
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const SCALE := 5
const TILE_CELL_PX := Vector2i(160, 80)
const CONTENT_PX := Vector2i(160, 75)
const ATLAS_COLUMNS := 32


class FrameData:
	var source_frame_index: int = -1
	var rect: Rect2i


var error_message: String = ""
var map_number: int = -1
var source_frame_count: int = 0
var image_path: String = ""
var night_image_path: String = ""
var atlas_texture: Texture2D
var night_atlas_texture: Texture2D
var _frames: Dictionary = {}
var _frame_textures: Dictionary = {}
var _night_frame_textures: Dictionary = {}


func load_manifest(path: String, expected_map_number: int, expected_frame_count: int, required_frames: PackedInt32Array) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("地图 TileSet 清单无法读取：%s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return _fail("地图 TileSet 清单不是 JSON 对象：%s" % path)
	return load_data(parsed, path.get_base_dir(), expected_map_number, expected_frame_count, required_frames)


func load_data(data: Dictionary, base_path: String, expected_map_number: int, expected_frame_count: int, required_frames: PackedInt32Array) -> bool:
	_reset()
	if not _has_only_keys(data, ["schema_version", "map_number", "source_frame_count", "scale", "tile_cell_px", "content_px", "image", "night_image", "frames"]):
		return _fail("地图 TileSet 包含未声明字段")
	if str(data.get("schema_version", "")) != SCHEMA_VERSION:
		return _fail("地图 TileSet schema_version 必须为 %s" % SCHEMA_VERSION)
	map_number = _integer(data.get("map_number"), -1)
	source_frame_count = _integer(data.get("source_frame_count"), -1)
	if map_number != expected_map_number:
		return _fail("地图 TileSet 编号应为 %d，实际为 %d" % [expected_map_number, map_number])
	if source_frame_count != expected_frame_count or source_frame_count <= 0:
		return _fail("地图 TileSet 原帧数应为 %d，实际为 %d" % [expected_frame_count, source_frame_count])
	if _integer(data.get("scale"), -1) != SCALE or _point(data.get("tile_cell_px")) != TILE_CELL_PX or _point(data.get("content_px")) != CONTENT_PX:
		return _fail("地图 TileSet 必须使用 scale=5、160×80 单元和 160×75 有效内容")
	var relative_image := str(data.get("image", ""))
	if not _is_safe_png_path(relative_image):
		return _fail("地图 TileSet image 必须是安全的相对 PNG 路径")
	image_path = base_path.path_join(relative_image)
	var source_image := Image.new()
	if source_image.load(image_path) != OK or source_image.is_empty():
		return _fail("地图 TileSet 图片无法读取：%s" % image_path)
	var night_image: Image
	if data.has("night_image") and data.get("night_image") != null:
		var relative_night := str(data.get("night_image", ""))
		if not _is_safe_png_path(relative_night):
			return _fail("地图 TileSet night_image 必须是安全的相对 PNG 路径")
		night_image_path = base_path.path_join(relative_night)
		night_image = Image.new()
		if night_image.load(night_image_path) != OK or night_image.get_size() != source_image.get_size():
			return _fail("地图 TileSet 夜间图片缺失或尺寸不一致")

	var raw_frames = data.get("frames")
	if raw_frames is not Array or raw_frames.is_empty():
		return _fail("地图 TileSet frames 必须为非空数组")
	for raw_frame in raw_frames:
		if raw_frame is not Dictionary or not _has_only_keys(raw_frame, ["source_frame_index", "rect"]):
			return _fail("地图 TileSet 帧包含未声明字段")
		var frame_index := _integer(raw_frame.get("source_frame_index"), -1)
		if frame_index < 0 or frame_index >= source_frame_count or _frames.has(frame_index):
			return _fail("地图 TileSet 帧编号重复或越界：%d" % frame_index)
		var rect := _rect(raw_frame.get("rect"))
		if rect.size != TILE_CELL_PX or not Rect2i(Vector2i.ZERO, source_image.get_size()).encloses(rect):
			return _fail("地图 TileSet 帧 %d 必须是图片内的 160×80 区域" % frame_index)
		var frame := FrameData.new()
		frame.source_frame_index = frame_index
		frame.rect = rect
		_frames[frame_index] = frame
	for frame_index in required_frames:
		if not _frames.has(frame_index):
			return _fail("地图 TileSet 缺少实际引用的 GOP 帧 %d" % frame_index)

	atlas_texture = _build_packed_atlas(source_image, false)
	if atlas_texture == null:
		return _fail("地图 TileSet 无法构建运行时图集")
	if night_image != null:
		night_atlas_texture = _build_packed_atlas(night_image, true)
	return true


func frame_texture(frame_index: int, night: bool = false) -> Texture2D:
	var values := _night_frame_textures if night and night_atlas_texture != null else _frame_textures
	return values.get(frame_index) as Texture2D


func active_atlas_texture(night: bool) -> Texture2D:
	return night_atlas_texture if night and night_atlas_texture != null else atlas_texture


func _build_packed_atlas(source: Image, night: bool) -> Texture2D:
	var rows := ceili(source_frame_count / float(ATLAS_COLUMNS))
	var packed_size := Vector2i(ATLAS_COLUMNS * TILE_CELL_PX.x, maxi(1, rows) * TILE_CELL_PX.y)
	var packed := Image.create(packed_size.x, packed_size.y, false, Image.FORMAT_RGBA8)
	packed.fill(Color.TRANSPARENT)
	source.convert(Image.FORMAT_RGBA8)
	for frame_index in _frames:
		var frame: FrameData = _frames[frame_index]
		var atlas_coords := Vector2i(frame_index % ATLAS_COLUMNS, int(frame_index / ATLAS_COLUMNS))
		packed.blit_rect(source, frame.rect, atlas_coords * TILE_CELL_PX)
	var result := ImageTexture.create_from_image(packed)
	var values := _night_frame_textures if night else _frame_textures
	for frame_index in _frames:
		var atlas_coords := Vector2i(frame_index % ATLAS_COLUMNS, int(frame_index / ATLAS_COLUMNS))
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = result
		frame_texture.region = Rect2(Rect2i(atlas_coords * TILE_CELL_PX, TILE_CELL_PX))
		frame_texture.filter_clip = true
		values[frame_index] = frame_texture
	return result


func _reset() -> void:
	error_message = ""
	map_number = -1
	source_frame_count = 0
	image_path = ""
	night_image_path = ""
	atlas_texture = null
	night_atlas_texture = null
	_frames.clear()
	_frame_textures.clear()
	_night_frame_textures.clear()


func _fail(message: String) -> bool:
	error_message = message
	return false


static func _integer(value, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	return fallback


static func _point(value) -> Vector2i:
	if value is not Array or value.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(_integer(value[0], -1), _integer(value[1], -1))


static func _rect(value) -> Rect2i:
	if value is not Array or value.size() != 4:
		return Rect2i(0, 0, -1, -1)
	return Rect2i(
		_integer(value[0], -1), _integer(value[1], -1),
		_integer(value[2], -1), _integer(value[3], -1)
	)


static func _is_safe_png_path(path: String) -> bool:
	return not path.is_empty() and path.to_lower().ends_with(".png") and not path.begins_with("/") and not path.contains("\\") and ".." not in path.split("/", false)


static func _has_only_keys(data: Dictionary, allowed: Array[String]) -> bool:
	for key in data:
		if str(key) not in allowed:
			return false
	return true
