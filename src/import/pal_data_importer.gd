# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal resource loading and format implementations.
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 本地资源的只读校验与离线转换入口。
## 只从 `source_dir` 读取，把运行时内容写入被 Git 忽略的 `output_dir`。
class_name PalDataImporter
extends RefCounted

const REQUIRED_FILES: PackedStringArray = [
	"abc.mkf", "ball.mkf", "data.mkf", "f.mkf", "fbp.mkf", "fire.mkf",
	"gop.mkf", "map.mkf", "mgo.mkf", "mus.mkf", "pat.mkf", "rgm.mkf",
	"rng.mkf", "sss.mkf", "voc.mkf", "m.msg", "word.dat", "wor16.fon",
	"wor16.asc",
]
const ARCHIVE_FILES: PackedStringArray = [
	"abc.mkf", "ball.mkf", "data.mkf", "f.mkf", "fbp.mkf", "fire.mkf",
	"gop.mkf", "map.mkf", "mgo.mkf", "mus.mkf", "pat.mkf", "rgm.mkf",
	"rng.mkf", "sss.mkf", "voc.mkf",
]


## 校验必需文件并生成内容数据库、预览、音频和地图资源。
## 返回报告包含全部错误和警告；原始目录不会被修改。
static func import_from(source_dir: String, output_dir: String = "res://generated/pal") -> PalImportReport:
	var report := PalImportReport.new()
	report.source_directory = source_dir.simplify_path()
	report.output_directory = output_dir
	var files_by_lowercase := _index_directory(report.source_directory, report)
	if not report.errors.is_empty():
		return report

	for required_name in REQUIRED_FILES:
		if not files_by_lowercase.has(required_name):
			report.errors.append("缺少必需资源：%s" % required_name)
	if not report.errors.is_empty():
		return report

	for archive_name in ARCHIVE_FILES:
		var actual_path: String = files_by_lowercase[archive_name]
		var archive := MkfArchive.load_file(actual_path)
		if not archive.is_valid():
			report.errors.append("%s：%s" % [archive_name, archive.error_message])
			continue
		report.files[archive_name] = {
			"actual_name": actual_path.get_file(),
			"size": archive.total_size(),
			"chunks": archive.chunk_count(),
			"nonempty_chunks": archive.nonempty_chunk_count(),
		}

	for plain_name in REQUIRED_FILES:
		if report.files.has(plain_name):
			continue
		var actual_path: String = files_by_lowercase[plain_name]
		var file := FileAccess.open(actual_path, FileAccess.READ)
		if file == null:
			report.errors.append("无法读取：%s" % actual_path)
		else:
			report.files[plain_name] = {"actual_name": actual_path.get_file(), "size": file.get_length()}

	if not report.errors.is_empty():
		return report

	var absolute_output := ProjectSettings.globalize_path(output_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		report.errors.append("无法创建本地生成目录：%s" % absolute_output)
		return report

	_generate_palette_previews(files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_content_database(files_by_lowercase, absolute_output, report)
	_generate_tileset_maps(absolute_output, report)
	_convert_item_bitmaps(files_by_lowercase["ball.mkf"], absolute_output, report)
	_convert_mgo_sprites(files_by_lowercase["mgo.mkf"], absolute_output, report)
	_convert_rgm_portraits(files_by_lowercase["rgm.mkf"], absolute_output, report)
	_convert_text_and_font(files_by_lowercase, absolute_output, report)
	_generate_fbp_preview(files_by_lowercase["fbp.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_rng_preview(files_by_lowercase["rng.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_sprite_preview(files_by_lowercase["ball.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_map_preview(files_by_lowercase["map.mkf"], files_by_lowercase["gop.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_convert_voc_audio(files_by_lowercase["voc.mkf"], absolute_output, report)
	_convert_rix_audio(files_by_lowercase["mus.mkf"], absolute_output, report)
	_write_manifest(absolute_output, report)
	report.success = report.errors.is_empty()
	return report


## 在 `user://pal_validation` 执行完整校验，避免污染项目正式生成目录。
static func validate(source_dir: String) -> PalImportReport:
	return import_from(source_dir, "user://pal_validation")


static func _index_directory(source_dir: String, report: PalImportReport) -> Dictionary:
	var result: Dictionary = {}
	var directory := DirAccess.open(source_dir)
	if directory == null:
		report.errors.append("无法打开资源目录：%s" % source_dir)
		return result
	for file_name in directory.get_files():
		result[file_name.to_lower()] = source_dir.path_join(file_name)
	return result


static func _generate_palette_previews(palette_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(palette_path)
	var palette_dir := absolute_output.path_join("palettes")
	DirAccess.make_dir_recursive_absolute(palette_dir)
	for index in range(archive.chunk_count()):
		var chunk := archive.get_chunk(index)
		var day_rgb := PaletteDecoder.decode_rgb(chunk, false)
		if day_rgb.is_empty():
			report.warnings.append("pat.mkf 调色板 %d 长度不足" % index)
			continue
		var day_path := palette_dir.path_join("palette_%02d_day.png" % index)
		var save_error := PaletteDecoder.to_strip_image(day_rgb).save_png(day_path)
		if save_error != OK:
			report.warnings.append("无法写入调色板预览：%s" % day_path)
		elif report.preview_path.is_empty():
			report.preview_path = day_path
		if chunk.size() >= PaletteDecoder.PALETTE_BYTES * 2:
			var night_path := palette_dir.path_join("palette_%02d_night.png" % index)
			PaletteDecoder.to_strip_image(PaletteDecoder.decode_rgb(chunk, true)).save_png(night_path)


static func _generate_content_database(files_by_lowercase: Dictionary, absolute_output: String, report: PalImportReport) -> void:
	var content_root := absolute_output.path_join("content")
	var core_dir := content_root.path_join("core")
	var data_dir := content_root.path_join("data")
	var map_dir := content_root.path_join("world/maps")
	var tile_dir := content_root.path_join("world/tiles")
	var palette_dir := content_root.path_join("palettes")
	for path in [core_dir, data_dir, map_dir, tile_dir, palette_dir]:
		DirAccess.make_dir_recursive_absolute(path)

	var sss := MkfArchive.load_file(files_by_lowercase["sss.mkf"])
	var core_names := ["event_objects.bin", "scenes.bin", "objects_dos.bin", "message_offsets.bin", "scripts.bin"]
	for index in range(mini(core_names.size(), sss.chunk_count())):
		if not _write_bytes(core_dir.path_join(core_names[index]), sss.get_chunk(index)):
			report.errors.append("无法写入核心数据：%s" % core_names[index])

	var data_archive := MkfArchive.load_file(files_by_lowercase["data.mkf"])
	for index in range(data_archive.chunk_count()):
		if not _write_bytes(data_dir.path_join("%02d.bin" % index), data_archive.get_chunk(index)):
			report.errors.append("无法写入 DATA.MKF 分块 %d" % index)

	var palette_archive := MkfArchive.load_file(files_by_lowercase["pat.mkf"])
	for index in range(palette_archive.chunk_count()):
		var chunk := palette_archive.get_chunk(index)
		var day := PaletteDecoder.decode_rgb(chunk, false)
		if not day.is_empty():
			_write_bytes(palette_dir.path_join("%02d_day.rgb" % index), day)
		if chunk.size() >= PaletteDecoder.PALETTE_BYTES * 2:
			_write_bytes(palette_dir.path_join("%02d_night.rgb" % index), PaletteDecoder.decode_rgb(chunk, true))

	var map_archive := MkfArchive.load_file(files_by_lowercase["map.mkf"])
	var gop_archive := MkfArchive.load_file(files_by_lowercase["gop.mkf"])
	var imported_maps := 0
	for index in range(1, mini(map_archive.chunk_count(), gop_archive.chunk_count())):
		var compressed := map_archive.get_chunk(index)
		var tiles := gop_archive.get_chunk(index)
		if compressed.is_empty() or tiles.is_empty():
			continue
		var decoder := Yj1Decoder.new()
		var map_bytes := decoder.decompress(compressed, PalMapData.BYTE_SIZE)
		if map_bytes.size() != PalMapData.BYTE_SIZE:
			report.warnings.append("地图 %d 解压失败：%s" % [index, decoder.error_message])
			continue
		if _write_bytes(map_dir.path_join("%03d.map" % index), map_bytes) and _write_bytes(tile_dir.path_join("%03d.gop" % index), tiles):
			imported_maps += 1
	report.files["content_database"] = {
		"scenes": sss.chunk_size(1) / PalSceneDefinition.BYTE_SIZE,
		"events": sss.chunk_size(0) / PalEventObject.BYTE_SIZE,
		"scripts": sss.chunk_size(4) / PalScriptEntry.BYTE_SIZE,
		"maps": imported_maps,
		"output": content_root,
	}


static func _generate_tileset_maps(absolute_output: String, report: PalImportReport) -> void:
	var content_root := absolute_output.path_join("content")
	var map_directory := content_root.path_join("world/maps")
	var tile_directory := content_root.path_join("world/tiles")
	var directory := DirAccess.open(map_directory)
	if directory == null:
		report.errors.append("无法读取已生成的地图目录：%s" % map_directory)
		return

	# 每次完整重建，避免用户切换 Data 版本后残留已经不存在的旧地图资源。
	_clear_generated_resources(content_root.path_join("world/tilesets"), ".tres")
	_clear_generated_resources(content_root.path_join("world/tilesets"), ".res")
	_clear_generated_resources(content_root.path_join("world/tilemaps"), ".tscn")
	var map_files := Array(directory.get_files())
	map_files.sort()
	var generated := 0
	var map_reports: Dictionary = {}
	for file_name in map_files:
		if not file_name.ends_with(".map"):
			continue
		var map_number: int = str(file_name).get_basename().to_int()
		var map_path := map_directory.path_join(file_name)
		var tile_path := tile_directory.path_join("%03d.gop" % map_number)
		var map_bytes := _read_bytes(map_path)
		var tile_bytes := _read_bytes(tile_path)
		var map_data := PalMapData.from_bytes(map_bytes)
		var tile_sprite := PalSprite.from_bytes(tile_bytes)
		var build := PalTileSetBuilder.build_map_resources(map_number, map_data, tile_sprite, content_root)
		if not bool(build.get("success", false)):
			report.errors.append("地图 %d TileSet 生成失败：%s" % [map_number, build.get("error", "未知错误")])
			continue
		generated += 1
		map_reports[str(map_number)] = {
			"map_sha256": _sha256(map_bytes),
			"gop_sha256": _sha256(tile_bytes),
			"tile_frames": build["tile_frames"],
			"alternative_tiles": build["alternative_tiles"],
			"fallback_bottom_tiles": build["fallback_bottom_tiles"],
			"ignored_top_tiles": build["ignored_top_tiles"],
			"tileset_path": build["tileset_path"],
			"tilemap_path": build["tilemap_path"],
		}
		if int(build["fallback_bottom_tiles"]) > 0 or int(build["ignored_top_tiles"]) > 0:
			report.warnings.append("地图 %d 含 %d 个缺失底层帧和 %d 个缺失上层帧，已按 SDLPal 规则兼容" % [map_number, build["fallback_bottom_tiles"], build["ignored_top_tiles"]])
	report.files["tileset_maps"] = {
		"format_version": 1,
		"generated": generated,
		"maps": map_reports,
		"output": content_root.path_join("world"),
	}
	if generated == 0:
		report.errors.append("没有成功生成任何 TileSet 地图")


static func _clear_generated_resources(path: String, extension: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(extension):
			directory.remove(file_name)


static func _convert_mgo_sprites(mgo_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(mgo_path)
	if not archive.is_valid():
		return
	var output_dir := absolute_output.path_join("content/sprites/mgo")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var previous_output := DirAccess.open(output_dir)
	if previous_output != null:
		for file_name in previous_output.get_files():
			if file_name.ends_with(".spr") or file_name.ends_with(".invalid"):
				previous_output.remove(file_name)
	var converted := 0
	var decode_failures: Array[Dictionary] = []
	var invalid_sprites: Array[Dictionary] = []
	for sprite_index in range(archive.chunk_count()):
		var compressed := archive.get_chunk(sprite_index)
		if compressed.is_empty():
			continue
		var decoder := Yj1Decoder.new()
		var sprite_bytes := decoder.decompress(compressed, 8 * 1024 * 1024)
		if sprite_bytes.is_empty():
			decode_failures.append({"index": sprite_index, "error": decoder.error_message})
			continue
		var sprite := PalSprite.from_bytes(sprite_bytes)
		if not sprite.is_valid():
			invalid_sprites.append({"index": sprite_index, "error": sprite.error_message})
			continue
		if _write_bytes(output_dir.path_join("%03d.spr" % sprite_index), sprite_bytes):
			converted += 1
		else:
			report.warnings.append("无法写入 MGO Sprite %d" % sprite_index)
	report.files["mgo_conversion"] = {
		"converted": converted,
		"decode_failures": decode_failures,
		"invalid_sprites": invalid_sprites,
		"output": output_dir,
	}
	if converted == 0:
		report.warnings.append("mgo.mkf 中没有成功转换的场景 Sprite")
	if not decode_failures.is_empty() or not invalid_sprites.is_empty():
		report.errors.append("MGO 场景 Sprite 校验失败：%d 个解压失败，%d 个帧表无效" % [decode_failures.size(), invalid_sprites.size()])


static func _convert_item_bitmaps(ball_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(ball_path)
	if not archive.is_valid():
		return
	var output_dir := absolute_output.path_join("content/items/ball")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var directory := DirAccess.open(output_dir)
	if directory != null:
		for file_name in directory.get_files():
			if file_name.ends_with(".rle"):
				directory.remove(file_name)
	var converted := 0
	for bitmap_index in range(archive.chunk_count()):
		var bytes := archive.get_chunk(bitmap_index)
		if bytes.is_empty() or not RleDecoder.decode(bytes).is_valid():
			continue
		if _write_bytes(output_dir.path_join("%03d.rle" % bitmap_index), bytes):
			converted += 1
	report.files["item_bitmaps"] = {"converted": converted, "output": output_dir}


static func _convert_rgm_portraits(rgm_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(rgm_path)
	if not archive.is_valid():
		return
	var output_dir := absolute_output.path_join("content/portraits/rgm")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var previous_output := DirAccess.open(output_dir)
	if previous_output != null:
		for file_name in previous_output.get_files():
			if file_name.ends_with(".rle"):
				previous_output.remove(file_name)
	var converted := 0
	var invalid: Array[int] = []
	for portrait_index in range(archive.chunk_count()):
		var portrait_bytes := archive.get_chunk(portrait_index)
		if portrait_bytes.is_empty():
			continue
		var portrait := RleDecoder.decode(portrait_bytes)
		if not portrait.is_valid():
			invalid.append(portrait_index)
			continue
		if _write_bytes(output_dir.path_join("%03d.rle" % portrait_index), portrait_bytes):
			converted += 1
	report.files["rgm_conversion"] = {
		"converted": converted,
		"invalid_indices": invalid,
		"output": output_dir,
	}
	if not invalid.is_empty():
		report.errors.append("RGM 对话肖像校验失败：%d 个 RLE 图像无效" % invalid.size())


static func _convert_text_and_font(files_by_lowercase: Dictionary, absolute_output: String, report: PalImportReport) -> void:
	var output_dir := absolute_output.path_join("content/text")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var helper := ProjectSettings.globalize_path("res://tools/pal_text_convert.py")
	var offsets := absolute_output.path_join("content/core/message_offsets.bin")
	var arguments := [
		helper,
		"--word", files_by_lowercase["word.dat"],
		"--message", files_by_lowercase["m.msg"],
		"--offsets", offsets,
		"--font", files_by_lowercase["wor16.fon"],
		"--characters", files_by_lowercase["wor16.asc"],
		"--output", output_dir,
	]
	if files_by_lowercase.has("desc.dat"):
		arguments.append_array(["--description", files_by_lowercase["desc.dat"]])
	var output: Array = []
	var exit_code := -1
	var command_used := ""
	for command in ["python3", "python", "py"]:
		output.clear()
		exit_code = OS.execute(command, arguments, output, true)
		if exit_code == 0:
			command_used = command
			break
	if exit_code != 0:
		report.warnings.append("文本/字库转换辅助工具失败；需要 Python 3：%s" % "\n".join(output))
		return
	var metadata: Dictionary = {}
	if not output.is_empty():
		var parsed = JSON.parse_string(str(output[-1]).strip_edges())
		if parsed is Dictionary:
			metadata = parsed
	metadata["helper"] = command_used
	metadata["output"] = output_dir
	report.files["text_conversion"] = metadata
	var encoding := str(metadata.get("encoding", "unknown"))
	report.source_edition = "DOS Traditional Chinese (CP950/Big5)" if encoding == "cp950" else "DOS Simplified Chinese (GBK/GB18030)"


static func _generate_fbp_preview(fbp_path: String, palette_path: String, absolute_output: String, report: PalImportReport) -> void:
	var fbp_archive := MkfArchive.load_file(fbp_path)
	var palette_archive := MkfArchive.load_file(palette_path)
	if not fbp_archive.is_valid() or not palette_archive.is_valid():
		return
	var palette_rgb := PaletteDecoder.decode_rgb(palette_archive.get_chunk(0), false)
	var decoder := Yj1Decoder.new()
	for index in range(fbp_archive.chunk_count()):
		var decompressed := decoder.decompress(fbp_archive.get_chunk(index), 320 * 200)
		if decompressed.size() != 320 * 200:
			continue
		var indexed := PalIndexedImage.new()
		indexed.width = 320
		indexed.height = 200
		indexed.indices = decompressed
		indexed.opacity.resize(decompressed.size())
		indexed.opacity.fill(255)
		var preview_path := absolute_output.path_join("fbp_%03d_preview.png" % index)
		if indexed.to_rgba_image(palette_rgb).save_png(preview_path) == OK:
			report.files["fbp_preview"] = {"chunk": index, "path": preview_path}
			return
	report.warnings.append("未能生成 FBP 预览；YJ1 数据将由格式测试继续核对")


static func _generate_rng_preview(rng_path: String, palette_path: String, absolute_output: String, report: PalImportReport) -> void:
	var rng_archive := MkfArchive.load_file(rng_path)
	var palette_archive := MkfArchive.load_file(palette_path)
	if not rng_archive.is_valid() or not palette_archive.is_valid():
		return
	var palette_rgb := PaletteDecoder.decode_rgb(palette_archive.get_chunk(0), false)
	if palette_rgb.is_empty():
		return
	for animation_index in range(rng_archive.chunk_count()):
		var animation_chunk := rng_archive.get_chunk(animation_index)
		if animation_chunk.is_empty():
			continue
		var animation := RngAnimation.from_mkf_chunk(animation_chunk)
		if not animation.is_valid():
			continue
		var output_dir := absolute_output.path_join("rng/%03d" % animation_index)
		DirAccess.make_dir_recursive_absolute(output_dir)
		var frame_decoder := RngFrameDecoder.new()
		var rendered_frames := 0
		var last_preview_path := ""
		for frame_index in range(animation.frame_count()):
			# SDLPal 数据通常在帧表末尾保留一个零长度分块。
			if animation.frame_size(frame_index) <= 0:
				break
			var delta := animation.decompress_frame(frame_index)
			if delta.is_empty():
				report.warnings.append("RNG 动画 %d 帧 %d 解压失败：%s" % [animation_index, frame_index, animation.error_message])
				break
			if not frame_decoder.apply_delta(delta):
				report.warnings.append("RNG 动画 %d 帧 %d 增量解码失败：%s" % [animation_index, frame_index, frame_decoder.error_message])
				break
			var output_path := output_dir.path_join("%03d.png" % frame_index)
			if frame_decoder.to_indexed_image().to_rgba_image(palette_rgb).save_png(output_path) != OK:
				report.warnings.append("无法写入 RNG 动画预览：%s" % output_path)
				break
			rendered_frames += 1
			last_preview_path = output_path
		if rendered_frames > 0:
			report.files["rng_preview"] = {
				"animation": animation_index,
				"frames": rendered_frames,
				"frame_rate": 16,
				"palette": 0,
				"output": output_dir,
				"path": last_preview_path,
			}
			report.preview_path = last_preview_path
			return
	report.warnings.append("未能从 rng.mkf 生成动画预览")


static func _generate_sprite_preview(sprite_path: String, palette_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(sprite_path)
	var palette_archive := MkfArchive.load_file(palette_path)
	if not archive.is_valid() or not palette_archive.is_valid():
		return
	var palette_rgb := PaletteDecoder.decode_rgb(palette_archive.get_chunk(0), false)
	for chunk_index in range(archive.chunk_count()):
		var frame_data := archive.get_chunk(chunk_index)
		if frame_data.is_empty():
			continue
		# BALL.MKF stores one direct RLE bitmap per chunk rather than a sprite table.
		var frame := RleDecoder.decode(frame_data)
		if not frame.is_valid():
			continue
		var preview_path := absolute_output.path_join("sprite_%03d_preview.png" % chunk_index)
		if frame.to_rgba_image(palette_rgb).save_png(preview_path) == OK:
			report.files["sprite_preview"] = {"chunk": chunk_index, "kind": "item_rle", "path": preview_path}
			return
	report.warnings.append("未能从 ball.mkf 生成 Sprite/RLE 预览")


static func _generate_map_preview(map_path: String, gop_path: String, palette_path: String, absolute_output: String, report: PalImportReport) -> void:
	var map_archive := MkfArchive.load_file(map_path)
	var gop_archive := MkfArchive.load_file(gop_path)
	var palette_archive := MkfArchive.load_file(palette_path)
	if not map_archive.is_valid() or not gop_archive.is_valid() or not palette_archive.is_valid():
		return
	var palette_rgb := PaletteDecoder.decode_rgb(palette_archive.get_chunk(0), false)
	for map_index in range(1, mini(map_archive.chunk_count(), gop_archive.chunk_count())):
		var decoder := Yj1Decoder.new()
		var unpacked := decoder.decompress(map_archive.get_chunk(map_index), PalMapData.BYTE_SIZE)
		if unpacked.size() != PalMapData.BYTE_SIZE:
			continue
		var map_data := PalMapData.from_bytes(unpacked)
		var tile_sprite := PalSprite.from_bytes(gop_archive.get_chunk(map_index))
		if not map_data.is_valid() or not tile_sprite.is_valid():
			continue
		var rendered := PalMapRenderer.render(map_data, tile_sprite, Rect2i(0, 0, 320, 200), true)
		if not rendered.is_valid():
			continue
		var preview_path := absolute_output.path_join("map_%03d_preview.png" % map_index)
		if rendered.to_rgba_image(palette_rgb).save_png(preview_path) == OK:
			report.files["map_preview"] = {"map": map_index, "tile_frames": tile_sprite.frame_count(), "path": preview_path}
			return
	report.warnings.append("未能从 map.mkf/gop.mkf 生成地图预览")


static func _convert_voc_audio(voc_path: String, absolute_output: String, report: PalImportReport) -> void:
	var archive := MkfArchive.load_file(voc_path)
	if not archive.is_valid():
		return
	var audio_dir := absolute_output.path_join("audio/voc")
	DirAccess.make_dir_recursive_absolute(audio_dir)
	var converted := 0
	var unsupported := 0
	for chunk_index in range(archive.chunk_count()):
		var chunk := archive.get_chunk(chunk_index)
		if chunk.is_empty():
			continue
		var decoder := VocDecoder.new()
		if not decoder.decode(chunk):
			unsupported += 1
			continue
		var output_path := audio_dir.path_join("%03d.wav" % chunk_index)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			report.warnings.append("无法写入 VOC 转换结果：%s" % output_path)
			continue
		file.store_buffer(decoder.to_wav())
		converted += 1
	report.files["voc_conversion"] = {"converted": converted, "unsupported": unsupported, "output": audio_dir}
	if converted == 0:
		report.warnings.append("voc.mkf 中没有成功转换的 8-bit type 01 音效")


static func _convert_rix_audio(mus_path: String, absolute_output: String, report: PalImportReport) -> void:
	if OS.get_name() not in ["macOS", "Linux"]:
		report.warnings.append("当前平台暂不自动构建 RIX 离线转换器")
		return
	var archive := MkfArchive.load_file(mus_path)
	if not archive.is_valid():
		report.warnings.append("MUS.MKF 无法读取，跳过 RIX 离线转换")
		return
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var upstream := project_root.get_base_dir().path_join("sdlpal-official")
	var executable := project_root.path_join("tools/rix_renderer/build/rix_renderer")
	if not FileAccess.file_exists(executable):
		var build_output: Array = []
		var build_script := project_root.path_join("tools/rix_renderer/build.py")
		var build_exit := OS.execute("python3", [build_script, "--upstream", upstream, "--output", executable], build_output, true)
		if build_exit != 0:
			report.warnings.append("RIX 离线转换器构建失败：%s" % "\n".join(build_output))
			return
	var output_dir := absolute_output.path_join("audio/rix")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var rendered: Array[int] = []
	var cached: Array[int] = []
	var failed: Array[int] = []
	var script_bytes := _read_bytes(absolute_output.path_join("content/core/scripts.bin"))
	var requested := _music_track_numbers(script_bytes)
	for song_index in requested:
		if song_index >= archive.chunk_count() or archive.get_chunk(song_index).is_empty():
			failed.append(song_index)
			report.warnings.append("RIX 曲目 %d 在 MUS.MKF 中不存在或为空" % song_index)
			continue
		var output_path := output_dir.path_join("%03d.wav" % song_index)
		if FileAccess.file_exists(output_path):
			cached.append(song_index)
			continue
		var render_output: Array = []
		var render_exit := OS.execute(executable, [mus_path, str(song_index), output_path, "300"], render_output, true)
		if render_exit == 0:
			rendered.append(song_index)
		else:
			failed.append(song_index)
			report.warnings.append("RIX 曲目 %d 转换失败：%s" % [song_index, "\n".join(render_output)])
	report.files["rix_conversion"] = {
		"requested_songs": requested,
		"rendered_songs": rendered,
		"cached_songs": cached,
		"failed_songs": failed,
		"output": output_dir,
		"sample_rate": 44100,
	}


static func _music_track_numbers(script_bytes: PackedByteArray) -> Array[int]:
	# 曲目 4/5 供启动与资源预览；其余只导出 ScriptVM 真正引用的场景/战斗音乐。
	var numbers: Dictionary = {4: true, 5: true}
	for offset in range(0, script_bytes.size() - PalScriptEntry.BYTE_SIZE + 1, PalScriptEntry.BYTE_SIZE):
		var entry := PalScriptEntry.from_bytes(script_bytes, offset)
		if entry != null and entry.operation in [0x0043, 0x0045] and entry.operands[0] > 0:
			numbers[entry.operands[0]] = true
	var result: Array[int] = []
	for raw_number in numbers:
		result.append(int(raw_number))
	result.sort()
	return result


static func _write_manifest(absolute_output: String, report: PalImportReport) -> void:
	var path := absolute_output.path_join("manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		report.errors.append("无法写入本地清单：%s" % path)
		return
	file.store_string(JSON.stringify(report.to_dictionary(), "  ", false))
	report.manifest_path = path


static func _write_bytes(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	return true


static func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


static func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()
