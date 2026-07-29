# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 把指定 GOP 帧从私有五倍图集排成固定绿幕制作板；帧编号和槽位另存 JSON。
## 制作板只作为图片模型输入，不是运行时 TileSet，也不得进入公开仓库。
extends SceneTree

const CANVAS_SIZE := Vector2i(1536, 1024)
const SLOT_SIZE := Vector2i(160, 80)
const COLUMNS := 8
const ROWS := 8
const GAP := Vector2i(16, 16)
const GRID_SIZE := Vector2i(COLUMNS * SLOT_SIZE.x + (COLUMNS - 1) * GAP.x, ROWS * SLOT_SIZE.y + (ROWS - 1) * GAP.y)
const GRID_ORIGIN := Vector2i((CANVAS_SIZE.x - GRID_SIZE.x) / 2, (CANVAS_SIZE.y - GRID_SIZE.y) / 2)
const KEY_COLOR := Color("00ff00")


func _init() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var tileset_path := str(options.get("tileset", ""))
	var output_path := str(options.get("out", ""))
	var frame_indices := _parse_indices(str(options.get("frames", "")))
	if tileset_path.is_empty() or output_path.is_empty() or frame_indices.is_empty():
		_fail("用法：--tileset=/private/pal-map-tileset.json --frames=0,1,... --out=/private/batch.png")
		return
	if frame_indices.size() > COLUMNS * ROWS:
		_fail("单张制作板最多容纳 %d 帧" % (COLUMNS * ROWS))
		return
	var absolute_tileset := _absolute_path(tileset_path)
	var data = _read_json(absolute_tileset)
	if data is not Dictionary:
		_fail("无法读取 TileSet 清单：%s" % tileset_path)
		return
	var image_path := absolute_tileset.get_base_dir().path_join(str(data.get("image", "")))
	var atlas := Image.new()
	if atlas.load(image_path) != OK or atlas.is_empty():
		_fail("无法读取 TileSet 图集：%s" % image_path)
		return
	var frames_by_index := _frames_by_index(data.get("frames"))
	var canvas := Image.create_empty(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(KEY_COLOR)
	var slots: Array = []
	for position in range(frame_indices.size()):
		var frame_index: int = frame_indices[position]
		if not frames_by_index.has(frame_index):
			_fail("TileSet 清单缺少 GOP 帧 %d" % frame_index)
			return
		var source_rect := _rect(frames_by_index[frame_index].get("rect"))
		if source_rect.size != SLOT_SIZE:
			_fail("GOP 帧 %d 不是 160×80" % frame_index)
			return
		var slot_position := GRID_ORIGIN + Vector2i(position % COLUMNS, int(position / COLUMNS)) * (SLOT_SIZE + GAP)
		canvas.blend_rect(atlas, source_rect, slot_position)
		slots.append({
			"source_frame_index": frame_index,
			"rect": [slot_position.x, slot_position.y, SLOT_SIZE.x, SLOT_SIZE.y],
		})
	var absolute_output := _absolute_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("无法创建制作板目录：%s" % error_string(directory_error))
		return
	if canvas.save_png(absolute_output) != OK:
		_fail("无法保存制作板：%s" % output_path)
		return
	var mapping := {
		"schema_version": "1.0.0",
		"map_number": int(data.get("map_number", -1)),
		"canvas_size": [CANVAS_SIZE.x, CANVAS_SIZE.y],
		"slot_size": [SLOT_SIZE.x, SLOT_SIZE.y],
		"key_color": "#00FF00",
		"source_tileset": absolute_tileset.get_file(),
		"source_image_sha256": str(data.get("image_sha256", "")),
		"slots": slots,
	}
	var mapping_path := absolute_output.get_basename() + ".json"
	if not _write_json(mapping_path, mapping):
		return
	print("PASS: Map %03d 制作板包含 %d 帧：%s" % [int(data.get("map_number", -1)), frame_indices.size(), output_path])
	quit(0)


func _frames_by_index(raw_frames) -> Dictionary:
	var result := {}
	if raw_frames is not Array:
		return result
	for raw_frame in raw_frames:
		if raw_frame is Dictionary:
			result[int(raw_frame.get("source_frame_index", -1))] = raw_frame
	return result


func _parse_indices(value: String) -> Array[int]:
	var result: Array[int] = []
	for part in value.split(",", false):
		var stripped := part.strip_edges()
		if not stripped.is_valid_int():
			continue
		var frame_index := int(stripped)
		if frame_index >= 0 and frame_index not in result:
			result.append(frame_index)
	return result


func _rect(value) -> Rect2i:
	if value is not Array or value.size() != 4:
		return Rect2i(0, 0, -1, -1)
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("无法写入制作板映射：%s" % path)
		return false
	file.store_string(JSON.stringify(data, "  ") + "\n")
	return true


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {}
	for argument in arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var separator := argument.find("=")
		result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path.simplify_path()


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
