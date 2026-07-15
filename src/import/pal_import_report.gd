# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalImportReport
extends RefCounted

var source_directory: String = ""
var output_directory: String = ""
var success: bool = false
var errors: Array[String] = []
var warnings: Array[String] = []
var files: Dictionary = {}
var preview_path: String = ""
var manifest_path: String = ""


func summary() -> String:
	if success:
		return "校验完成：%d 个文件，%d 条警告" % [files.size(), warnings.size()]
	return "校验失败：%d 个错误，%d 条警告" % [errors.size(), warnings.size()]


func to_dictionary() -> Dictionary:
	return {
		"format_version": 1,
		"source_edition": "DOS Simplified Chinese candidate",
		"source_directory": source_directory,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"files": files,
		"warnings": warnings,
	}

