# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 将图片模型制作板中的指定槽位写回新版本地图图集；透明轮廓始终复用原 GOP Alpha。
## 该步骤只替换颜色与内部像素细节，不允许模型改变图块占位、遮挡轮廓或 MAP 语义。
extends SceneTree


func _init() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var tileset_path := str(options.get("tileset", ""))
	var mapping_path := str(options.get("mapping", ""))
	var generated_path := str(options.get("generated", ""))
	var output_directory := str(options.get("out", ""))
	if tileset_path.is_empty() or mapping_path.is_empty() or generated_path.is_empty() or output_directory.is_empty():
		_fail("用法：--tileset=pal-map-tileset.json --mapping=batch.json --generated=batch.png --out=/private/v002")
		return
	var absolute_tileset := _absolute_path(tileset_path)
	var tileset = _read_json(absolute_tileset)
	var mapping = _read_json(_absolute_path(mapping_path))
	if tileset is not Dictionary or mapping is not Dictionary:
		_fail("TileSet 清单或制作板映射无法读取")
		return
	var source_image_path := absolute_tileset.get_base_dir().path_join(str(tileset.get("image", "")))
	var source := Image.new()
	var generated := Image.new()
	if source.load(source_image_path) != OK or source.is_empty():
		_fail("源图集无法读取：%s" % source_image_path)
		return
	if generated.load(_absolute_path(generated_path)) != OK or generated.is_empty():
		_fail("生成制作板无法读取：%s" % generated_path)
		return
	var expected_canvas := _point(mapping.get("canvas_size"))
	if generated.get_size() != expected_canvas:
		_fail("生成制作板尺寸应为 %s，实际为 %s" % [expected_canvas, generated.get_size()])
		return
	if str(mapping.get("source_image_sha256", "")) != str(tileset.get("image_sha256", "")):
		_fail("制作板映射与源图集 SHA-256 不一致")
		return
	var source_frames := _frames_by_index(tileset.get("frames"))
	var replaced: Array[int] = []
	for raw_slot in mapping.get("slots", []):
		if raw_slot is not Dictionary:
			_fail("制作板映射包含无效槽位")
			return
		var frame_index := int(raw_slot.get("source_frame_index", -1))
		if not source_frames.has(frame_index):
			_fail("源图集缺少 GOP 帧 %d" % frame_index)
			return
		var source_rect := _rect(source_frames[frame_index].get("rect"))
		var generated_rect := _rect(raw_slot.get("rect"))
		if source_rect.size != generated_rect.size or not Rect2i(Vector2i.ZERO, generated.get_size()).encloses(generated_rect):
			_fail("GOP 帧 %d 的制作槽位尺寸或边界无效" % frame_index)
			return
		_replace_frame_rgb(source, source_rect, generated, generated_rect)
		replaced.append(frame_index)
	var absolute_output := _absolute_path(output_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("无法创建输出目录：%s" % error_string(directory_error))
		return
	var output_image_name := "map_%03d_refined_atlas.png" % int(tileset.get("map_number", -1))
	var output_image_path := absolute_output.path_join(output_image_name)
	if source.save_png(output_image_path) != OK:
		_fail("无法保存精修图集：%s" % output_image_path)
		return
	tileset["image"] = output_image_name
	tileset["image_sha256"] = _file_sha256(output_image_path)
	_normalize_tileset_numbers(tileset)
	if str(tileset["image_sha256"]).is_empty() or not _write_json(absolute_output.path_join("pal-map-tileset.json"), tileset):
		return
	var report := {
		"schema_version": "1.0.0",
		"map_number": int(tileset.get("map_number", -1)),
		"source_tileset": absolute_tileset,
		"mapping": _absolute_path(mapping_path),
		"generated_sheet": _absolute_path(generated_path),
		"replaced_frame_indices": replaced,
		"output_image_sha256": tileset["image_sha256"],
		"alpha_policy": "preserve_source_gop_alpha",
	}
	if not _write_json(absolute_output.path_join("tile-batch-application.json"), report):
		return
	print("PASS: Map %03d 写回 %d 帧：%s" % [int(tileset.get("map_number", -1)), replaced.size(), output_directory])
	quit(0)


func _replace_frame_rgb(target: Image, target_rect: Rect2i, source: Image, source_rect: Rect2i) -> void:
	for y in range(target_rect.size.y):
		for x in range(target_rect.size.x):
			var original := target.get_pixelv(target_rect.position + Vector2i(x, y))
			if original.a <= 0.0:
				continue
			var generated_color := source.get_pixelv(source_rect.position + Vector2i(x, y))
			# 图片模型可能把严格槽位中的轮廓画窄；这些仍为绿幕的像素保留原图，
			# 避免将 #00FF00 写成不透明接缝，同时不扩大原 GOP Alpha。
			if _is_chroma_green(generated_color):
				continue
			generated_color.a = 1.0
			target.set_pixelv(target_rect.position + Vector2i(x, y), generated_color)


func _is_chroma_green(color: Color) -> bool:
	return color.g >= 0.75 and color.g - maxf(color.r, color.b) >= 0.35


func _frames_by_index(raw_frames) -> Dictionary:
	var result := {}
	if raw_frames is Array:
		for raw_frame in raw_frames:
			if raw_frame is Dictionary:
				result[int(raw_frame.get("source_frame_index", -1))] = raw_frame
	return result


func _normalize_tileset_numbers(tileset: Dictionary) -> void:
	for key in ["map_number", "source_frame_count", "scale"]:
		tileset[key] = int(tileset.get(key, 0))
	for key in ["tile_cell_px", "content_px"]:
		var point := _point(tileset.get(key))
		tileset[key] = [point.x, point.y]
	var normalized_frames: Array = []
	for raw_frame in tileset.get("frames", []):
		if raw_frame is not Dictionary:
			continue
		var rect := _rect(raw_frame.get("rect"))
		normalized_frames.append({
			"source_frame_index": int(raw_frame.get("source_frame_index", -1)),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		})
	tileset["frames"] = normalized_frames


func _point(value) -> Vector2i:
	if value is not Array or value.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(value[0]), int(value[1]))


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
		_fail("无法写入 JSON：%s" % path)
		return false
	file.store_string(JSON.stringify(data, "  ") + "\n")
	return true


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while file.get_position() < file.get_length():
		if context.update(file.get_buffer(mini(1024 * 1024, file.get_length() - file.get_position()))) != OK:
			return ""
	return context.finish().hex_encode()


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
