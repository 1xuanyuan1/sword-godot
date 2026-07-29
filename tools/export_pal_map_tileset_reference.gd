# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从玩家本地导入的 MAP/GOP 生成五倍兼容图集、运行时清单和逐帧覆盖台账。
## 输出只能进入私有素材仓或被忽略目录，不能提交到公开代码仓。
extends SceneTree

const TILE_CELL_PX := Vector2i(160, 80)
const CONTENT_PX := Vector2i(160, 75)
const SOURCE_FRAME_PX := Vector2i(32, 15)
const ATLAS_COLUMNS := 32
const DEFAULT_FOCUS_SIZE := Vector2i(384, 216)
const FOCUS_X_PADDING := 32
const FOCUS_TOP_PADDING := 80
const FOCUS_BOTTOM_PADDING := 16


func _init() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var map_number := int(options.get("map", 0))
	var output_directory := str(options.get("out", ""))
	if map_number <= 0 or output_directory.is_empty():
		_fail("用法：--map=N --out=/private/output [--palette=0 --focus-x=N --focus-y=N --focus-width=384 --focus-height=216]")
		return
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail(database.error_message)
		return
	var map_data := database.load_map(map_number)
	var tile_sprite := database.load_map_tiles(map_number)
	var palette_index := int(options.get("palette", 0))
	var palette := database.load_palette(palette_index, false)
	if not map_data.is_valid() or not tile_sprite.is_valid():
		_fail("地图 %03d 的 MAP/GOP 不可用" % map_number)
		return
	if palette.size() < PaletteDecoder.PALETTE_BYTES:
		_fail("调色板 %d 不可用" % palette_index)
		return

	var absolute_output := _absolute_path(output_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("无法创建输出目录：%s" % error_string(directory_error))
		return
	var focus := _focus_rect(options)
	var coverage := _build_coverage(map_number, map_data, tile_sprite.frame_count(), focus)
	var atlas_result := _build_atlas(tile_sprite, palette)
	if atlas_result.get("image") == null:
		_fail(str(atlas_result.get("error", "图集生成失败")))
		return
	var atlas: Image = atlas_result["image"]
	var atlas_path := absolute_output.path_join("map_%03d_classic_5x_atlas.png" % map_number)
	if atlas.save_png(atlas_path) != OK:
		_fail("无法保存五倍图集：%s" % atlas_path)
		return
	var manifest := _build_tileset_manifest(map_number, tile_sprite.frame_count(), atlas_path.get_file())
	if not _write_json(absolute_output.path_join("pal-map-tileset.json"), manifest):
		return
	if not _write_json(absolute_output.path_join("map_%03d_coverage.json" % map_number), coverage):
		return
	print(
		"PASS: Map %03d 导出 %d 帧；全图引用 %d 帧，焦点视野引用 %d 帧：%s"
		% [
			map_number,
			tile_sprite.frame_count(),
			coverage["required_frame_indices"].size(),
			coverage["focus_frame_indices"].size(),
			output_directory,
		]
	)
	quit(0)


func _build_atlas(tile_sprite: PalSprite, palette: PackedByteArray) -> Dictionary:
	var frame_count := tile_sprite.frame_count()
	var rows := ceili(frame_count / float(ATLAS_COLUMNS))
	var atlas := Image.create_empty(ATLAS_COLUMNS * TILE_CELL_PX.x, rows * TILE_CELL_PX.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame_index in range(frame_count):
		var frame := RleDecoder.decode(tile_sprite.get_frame(frame_index))
		if not frame.is_valid() or Vector2i(frame.width, frame.height) != SOURCE_FRAME_PX:
			return {"image": null, "error": "GOP 帧 %d 不是有效的 32×15 图块" % frame_index}
		var image := frame.to_rgba_image(palette)
		image.resize(CONTENT_PX.x, CONTENT_PX.y, Image.INTERPOLATE_NEAREST)
		var target := Vector2i(frame_index % ATLAS_COLUMNS, int(frame_index / ATLAS_COLUMNS)) * TILE_CELL_PX
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, CONTENT_PX), target)
	return {"image": atlas, "error": ""}


func _build_tileset_manifest(map_number: int, frame_count: int, image_name: String) -> Dictionary:
	var frames: Array = []
	for frame_index in range(frame_count):
		var position := Vector2i(frame_index % ATLAS_COLUMNS, int(frame_index / ATLAS_COLUMNS)) * TILE_CELL_PX
		frames.append({
			"source_frame_index": frame_index,
			"rect": [position.x, position.y, TILE_CELL_PX.x, TILE_CELL_PX.y],
		})
	return {
		"schema_version": "1.0.0",
		"map_number": map_number,
		"source_frame_count": frame_count,
		"scale": 5,
		"tile_cell_px": [TILE_CELL_PX.x, TILE_CELL_PX.y],
		"content_px": [CONTENT_PX.x, CONTENT_PX.y],
		"image": image_name,
		"frames": frames,
	}


func _build_coverage(map_number: int, map_data: PalMapData, frame_count: int, focus: Rect2i) -> Dictionary:
	var bottom_counts: Dictionary = {}
	var top_counts: Dictionary = {}
	var focus_counts: Dictionary = {}
	for map_y in range(PalMapData.HEIGHT):
		for map_x in range(PalMapData.WIDTH):
			for half in range(PalMapData.HALVES):
				var value := map_data.tile_value(map_x, map_y, half)
				var bottom_index := PalMapData.bottom_sprite_index(value)
				var top_index := PalMapData.top_sprite_index(value)
				_increment_valid(bottom_counts, bottom_index, frame_count)
				_increment_valid(top_counts, top_index, frame_count)
				if focus.has_area() and _tile_intersects_focus(map_x, map_y, half, focus):
					_increment_valid(focus_counts, bottom_index, frame_count)
					_increment_valid(focus_counts, top_index, frame_count)
	var required := _sorted_union(bottom_counts, top_counts)
	var focus_indices := _sorted_keys(focus_counts)
	var frame_usage: Array = []
	for frame_index in required:
		frame_usage.append({
			"source_frame_index": frame_index,
			"bottom_occurrences": int(bottom_counts.get(frame_index, 0)),
			"top_occurrences": int(top_counts.get(frame_index, 0)),
			"focus_occurrences": int(focus_counts.get(frame_index, 0)),
		})
	return {
		"schema_version": "1.0.0",
		"map_number": map_number,
		"source_frame_count": frame_count,
		"required_frame_indices": required,
		"focus_viewport": [focus.position.x, focus.position.y, focus.size.x, focus.size.y],
		"focus_frame_indices": focus_indices,
		"frame_usage": frame_usage,
	}


func _tile_intersects_focus(map_x: int, map_y: int, half: int, focus: Rect2i) -> bool:
	var center := Vector2i(map_x * 32 + half * 16, map_y * 16 + half * 8)
	return (
		center.x >= focus.position.x - FOCUS_X_PADDING
		and center.x <= focus.end.x + FOCUS_X_PADDING
		and center.y >= focus.position.y - FOCUS_TOP_PADDING
		and center.y <= focus.end.y + FOCUS_BOTTOM_PADDING
	)


func _increment_valid(counts: Dictionary, frame_index: int, frame_count: int) -> void:
	if frame_index < 0 or frame_index >= frame_count:
		return
	counts[frame_index] = int(counts.get(frame_index, 0)) + 1


func _sorted_union(left: Dictionary, right: Dictionary) -> Array:
	var union: Dictionary = left.duplicate()
	for key in right:
		union[key] = true
	return _sorted_keys(union)


func _sorted_keys(values: Dictionary) -> Array:
	var result: Array = []
	for key in values:
		result.append(int(key))
	result.sort()
	return result


func _focus_rect(options: Dictionary) -> Rect2i:
	var has_focus := options.has("focus-x") and options.has("focus-y")
	if not has_focus:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(
		int(options["focus-x"]),
		int(options["focus-y"]),
		int(options.get("focus-width", DEFAULT_FOCUS_SIZE.x)),
		int(options.get("focus-height", DEFAULT_FOCUS_SIZE.y))
	)


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("无法写入 JSON：%s" % path)
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
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path.simplify_path()


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
