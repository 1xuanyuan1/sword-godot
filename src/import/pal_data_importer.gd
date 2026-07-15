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
	_generate_fbp_preview(files_by_lowercase["fbp.mkf"], files_by_lowercase["pat.mkf"], absolute_output, report)
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


static func _write_manifest(absolute_output: String, report: PalImportReport) -> void:
	var path := absolute_output.path_join("manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		report.errors.append("无法写入本地清单：%s" % path)
		return
	file.store_string(JSON.stringify(report.to_dictionary(), "  ", false))
	report.manifest_path = path

