# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal resource loading and format implementations.
# SPDX-License-Identifier: GPL-3.0-or-later
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
	_convert_text_and_font(files_by_lowercase, absolute_output, report)
	_generate_fbp_preview(files_by_lowercase["fbp.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_sprite_preview(files_by_lowercase["ball.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_generate_map_preview(files_by_lowercase["map.mkf"], files_by_lowercase["gop.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
	_convert_voc_audio(files_by_lowercase["voc.mkf"], absolute_output, report)
	_write_manifest(absolute_output, report)
	report.success = report.errors.is_empty()
	return report


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
