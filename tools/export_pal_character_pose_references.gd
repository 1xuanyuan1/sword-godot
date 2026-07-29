# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 将玩家本地 MGO 人物帧导出为 2DCS `p` 使用的中性几何参考。
## 输出只保留方向、步态、轮廓、重心和脚底位置，不携带原角色配色或运行时资源。
extends SceneTree

const CANVAS_SIZE := Vector2i(1536, 1024)
const FIGURE_SCALE := 14
const BASELINE_Y := 920
const BACKGROUND_COLOR := Color("e9e1d2")
const SHADOW_COLOR := Color("424956")
const MIDTONE_COLOR := Color("737b87")
const LIGHT_COLOR := Color("b7bdc6")
const DIRECTION_NAMES := ["south", "west", "north", "east"]
const PHASE_NAMES := ["idle", "step_a", "step_b"]


func _init() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var sprite_number := int(options.get("sprite", 0))
	var output_directory := str(options.get("out", ""))
	var frame_indices := _parse_indices(str(options.get("frames", "0,1,2,3,4,5,6,7,8,9,10,11")))
	if sprite_number <= 0 or output_directory.is_empty() or frame_indices.is_empty():
		_fail("用法：--sprite=N --frames=0,1,... --out=/private/pose-references")
		return
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail(database.error_message)
		return
	var palette := database.load_palette(0, false)
	var sprite := database.load_mgo_sprite(sprite_number)
	if not sprite.is_valid() or palette.size() < PaletteDecoder.PALETTE_BYTES:
		_fail("MGO Sprite %d 或调色板不可用" % sprite_number)
		return
	var absolute_output := _absolute_path(output_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("无法创建姿势参考目录：%s" % error_string(directory_error))
		return

	var records: Array = []
	for frame_index in frame_indices:
		if frame_index < 0 or frame_index >= sprite.frame_count():
			_fail("MGO Sprite %d 缺少第 %d 帧" % [sprite_number, frame_index])
			return
		var frame := RleDecoder.decode(sprite.get_frame(frame_index))
		if not frame.is_valid():
			_fail("MGO Sprite %d 第 %d 帧解码失败" % [sprite_number, frame_index])
			return
		var neutral := _neutral_geometry_image(frame, palette)
		neutral.resize(frame.width * FIGURE_SCALE, frame.height * FIGURE_SCALE, Image.INTERPOLATE_NEAREST)
		var canvas := Image.create_empty(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
		canvas.fill(BACKGROUND_COLOR)
		var figure_position := Vector2i(
			int((CANVAS_SIZE.x - neutral.get_width()) / 2.0),
			BASELINE_Y - neutral.get_height()
		)
		canvas.blend_rect(neutral, Rect2i(Vector2i.ZERO, neutral.get_size()), figure_position)
		var filename := "frame_%03d_pose.png" % frame_index
		var output_path := absolute_output.path_join(filename)
		if canvas.save_png(output_path) != OK:
			_fail("无法保存姿势参考：%s" % output_path)
			return
		records.append({
			"source_frame_index": frame_index,
			"direction": DIRECTION_NAMES[int(frame_index / 3) % DIRECTION_NAMES.size()],
			"walk_phase": PHASE_NAMES[frame_index % 3],
			"source_size": [frame.width, frame.height],
			"figure_rect": [figure_position.x, figure_position.y, neutral.get_width(), neutral.get_height()],
			"baseline_y": BASELINE_Y,
			"path": filename,
			"sha256": FileAccess.get_sha256(output_path),
		})
	var manifest := {
		"schema_version": "1.0.0",
		"sprite_number": sprite_number,
		"source_frame_count": sprite.frame_count(),
		"canvas_size": [CANVAS_SIZE.x, CANVAS_SIZE.y],
		"figure_scale": FIGURE_SCALE,
		"background": "#E9E1D2",
		"neutralization": "three_tone_grayscale_geometry_only",
		"frames": records,
	}
	if not _write_json(absolute_output.path_join("pose-reference-manifest.json"), manifest):
		return
	print("PASS: MGO %d 导出 %d 张中性姿势参考：%s" % [sprite_number, records.size(), output_directory])
	quit(0)


func _neutral_geometry_image(frame: PalIndexedImage, palette: PackedByteArray) -> Image:
	var image := Image.create_empty(frame.width, frame.height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(frame.height):
		for x in range(frame.width):
			var pixel_index := y * frame.width + x
			if frame.opacity[pixel_index] == 0:
				continue
			var palette_index := int(frame.indices[pixel_index]) * 3
			var luminance := (
				int(palette[palette_index]) * 54
				+ int(palette[palette_index + 1]) * 183
				+ int(palette[palette_index + 2]) * 19
			) / 256
			var neutral_color := SHADOW_COLOR if luminance < 72 else MIDTONE_COLOR if luminance < 144 else LIGHT_COLOR
			image.set_pixel(x, y, neutral_color)
	return image


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {}
	for argument in arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var separator := argument.find("=")
		result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result


func _parse_indices(value: String) -> Array[int]:
	var result: Array[int] = []
	for part in value.split(",", false):
		var stripped := part.strip_edges()
		if stripped.is_valid_int():
			var frame_index := int(stripped)
			if frame_index >= 0 and frame_index not in result:
				result.append(frame_index)
	return result


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path.simplify_path()


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("无法写入姿势参考清单：%s" % path)
		return false
	file.store_string(JSON.stringify(data, "  ") + "\n")
	return true


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
