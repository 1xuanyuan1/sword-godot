# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 严格加载 `pal-sprite-atlas.json`；任何帧缺失或尺寸错误都会让整个人物回退经典 MGO。
class_name PalRemasterSpriteAtlas
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const SCALE := 5


class FrameData:
	var source_frame_index: int = -1
	var rect: Rect2i
	var pivot: Vector2i
	var alpha_bounds: Rect2i
	var duration_ms: int = 100
	var texture: AtlasTexture


var error_message: String = ""
var source_sprite_number: int = 0
var source_frame_count: int = 0
var canvas_size: Vector2i = Vector2i.ZERO
var image_path: String = ""
var texture: Texture2D
var _frames: Dictionary = {}


func load_manifest(path: String, expected_sprite_number: int, expected_frame_count: int) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("人物 Atlas 清单无法读取：%s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return _fail("人物 Atlas 清单不是 JSON 对象：%s" % path)
	return load_data(parsed, path.get_base_dir(), expected_sprite_number, expected_frame_count)


func load_data(data: Dictionary, base_path: String, expected_sprite_number: int, expected_frame_count: int) -> bool:
	_reset()
	if not _has_only_keys(data, ["schema_version", "source_sprite_number", "source_frame_count", "scale", "image", "canvas_size", "frames"]):
		return _fail("人物 Atlas 包含未声明字段")
	if str(data.get("schema_version", "")) != SCHEMA_VERSION:
		return _fail("人物 Atlas schema_version 必须为 %s" % SCHEMA_VERSION)
	source_sprite_number = _integer(data.get("source_sprite_number"), -1)
	source_frame_count = _integer(data.get("source_frame_count"), -1)
	if source_sprite_number != expected_sprite_number:
		return _fail("人物 Atlas Sprite 编号应为 %d，实际为 %d" % [expected_sprite_number, source_sprite_number])
	if source_frame_count != expected_frame_count or source_frame_count <= 0:
		return _fail("人物 Atlas 原帧数应为 %d，实际为 %d" % [expected_frame_count, source_frame_count])
	if _integer(data.get("scale"), -1) != SCALE:
		return _fail("人物 Atlas scale 必须为 5")
	canvas_size = _size(data.get("canvas_size"))
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return _fail("人物 Atlas canvas_size 无效")
	var relative_image := str(data.get("image", ""))
	if not _is_safe_png_path(relative_image):
		return _fail("人物 Atlas image 必须是安全的相对 PNG 路径")
	image_path = base_path.path_join(relative_image)
	var image := Image.new()
	var image_error := image.load(image_path)
	if image_error != OK or image.is_empty():
		return _fail("人物 Atlas 图片无法读取：%s" % image_path)
	texture = ImageTexture.create_from_image(image)

	var raw_frames = data.get("frames")
	if raw_frames is not Array or raw_frames.size() != source_frame_count:
		return _fail("人物 Atlas 必须一一覆盖 %d 个原始帧" % source_frame_count)
	for raw_frame in raw_frames:
		if raw_frame is not Dictionary or not _has_only_keys(raw_frame, ["source_frame_index", "rect", "pivot", "alpha_bounds", "duration_ms"]):
			return _fail("人物 Atlas 帧包含未声明字段")
		var frame_index := _integer(raw_frame.get("source_frame_index"), -1)
		if frame_index < 0 or frame_index >= source_frame_count or _frames.has(frame_index):
			return _fail("人物 Atlas 帧编号重复或越界：%d" % frame_index)
		var rect := _rect(raw_frame.get("rect"))
		if rect.size != canvas_size or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect):
			return _fail("人物 Atlas 帧 %d 必须使用统一画布且位于图片内" % frame_index)
		var pivot := _point(raw_frame.get("pivot"))
		if pivot.x < 0 or pivot.y < 0 or pivot.x > canvas_size.x or pivot.y > canvas_size.y:
			return _fail("人物 Atlas 帧 %d pivot 越界" % frame_index)
		var alpha_bounds := _rect(raw_frame.get("alpha_bounds"))
		if not Rect2i(Vector2i.ZERO, canvas_size).encloses(alpha_bounds):
			return _fail("人物 Atlas 帧 %d alpha_bounds 越界" % frame_index)
		var duration_ms := _integer(raw_frame.get("duration_ms"), -1)
		if duration_ms < 1 or duration_ms > 5000:
			return _fail("人物 Atlas 帧 %d duration_ms 越界" % frame_index)
		var frame := FrameData.new()
		frame.source_frame_index = frame_index
		frame.rect = rect
		frame.pivot = pivot
		frame.alpha_bounds = alpha_bounds
		frame.duration_ms = duration_ms
		frame.texture = AtlasTexture.new()
		frame.texture.atlas = texture
		frame.texture.region = Rect2(rect)
		frame.texture.filter_clip = true
		_frames[frame_index] = frame
	for frame_index in range(source_frame_count):
		if not _frames.has(frame_index):
			return _fail("人物 Atlas 缺少原始帧 %d" % frame_index)
	return true


func frame(frame_index: int) -> FrameData:
	return _frames.get(frame_index) as FrameData


func _reset() -> void:
	error_message = ""
	source_sprite_number = 0
	source_frame_count = 0
	canvas_size = Vector2i.ZERO
	image_path = ""
	texture = null
	_frames.clear()


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


static func _size(value) -> Vector2i:
	return _point(value)


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
