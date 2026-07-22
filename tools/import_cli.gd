# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	var source := ""
	var output := "res://generated/pal"
	var rng_previews := false
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		match arguments[index]:
			"--source":
				index += 1
				if index < arguments.size():
					source = arguments[index]
			"--output":
				index += 1
				if index < arguments.size():
					output = arguments[index]
			"--rng-previews":
				rng_previews = true
		index += 1

	if source.is_empty():
		printerr("Usage: --script res://tools/import_cli.gd -- --source /path/to/Data [--output res://generated/pal] [--rng-previews]")
		quit(2)
		return

	var report := PalDataImporter.import_from(source, output, rng_previews)
	print(report.summary())
	for warning in report.warnings:
		print("WARNING: %s" % warning)
	for error in report.errors:
		printerr("ERROR: %s" % error)
	quit(0 if report.success else 1)
