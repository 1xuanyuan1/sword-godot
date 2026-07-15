# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

var _source_path: LineEdit
var _status: RichTextLabel
var _details: Tree
var _preview: TextureRect
var _import_button: Button
var _explore_button: Button
var _rng_button: Button
var _story_test_button: Button
var _dialog: FileDialog


func _ready() -> void:
	_build_interface()
	_show_idle_state()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("111827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	margin.add_child(page)

	var title := Label.new()
	title.text = "仙剑奇侠传 · Godot 学习复刻"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("fbbf24"))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "M1 资源实验室｜只读取本机合法资源，生成内容不会提交到 Git"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color("cbd5e1"))
	page.add_child(subtitle)

	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 4)
	page.add_child(picker)

	_source_path = LineEdit.new()
	_source_path.placeholder_text = "选择包含 fbp.mkf、sss.mkf、M.MSG 等文件的 Data 目录"
	_source_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_child(_source_path)

	var browse_button := Button.new()
	browse_button.text = "选择…"
	browse_button.pressed.connect(_open_dialog)
	picker.add_child(browse_button)

	_import_button = Button.new()
	_import_button.text = "校验并导入"
	_import_button.pressed.connect(_run_import)
	picker.add_child(_import_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	page.add_child(actions)

	var actions_label := Label.new()
	actions_label.text = "可玩入口"
	actions_label.add_theme_font_size_override("font_size", 9)
	actions_label.add_theme_color_override("font_color", Color("93c5fd"))
	actions.add_child(actions_label)

	_explore_button = Button.new()
	_explore_button.text = "探索样板"
	_explore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_button.add_theme_font_size_override("font_size", 9)
	_explore_button.disabled = true
	_explore_button.pressed.connect(_open_explorer)
	actions.add_child(_explore_button)

	_rng_button = Button.new()
	_rng_button.text = "RNG 动画"
	_rng_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rng_button.add_theme_font_size_override("font_size", 9)
	_rng_button.disabled = true
	_rng_button.pressed.connect(_open_rng_preview)
	actions.add_child(_rng_button)

	_story_test_button = Button.new()
	_story_test_button.text = "剧情测试"
	_story_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_test_button.add_theme_font_size_override("font_size", 9)
	_story_test_button.disabled = true
	_story_test_button.pressed.connect(_open_story_test)
	actions.add_child(_story_test_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 205
	page.add_child(split)

	_details = Tree.new()
	_details.columns = 3
	_details.column_titles_visible = true
	_details.set_column_title(0, "文件")
	_details.set_column_title(1, "分块")
	_details.set_column_title(2, "大小")
	_details.set_column_expand(0, true)
	_details.set_column_expand(1, false)
	_details.set_column_custom_minimum_width(1, 42)
	_details.set_column_expand(2, false)
	_details.set_column_custom_minimum_width(2, 64)
	split.add_child(_details)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(90, 0)
	split.add_child(preview_panel)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_panel.add_child(_preview)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = false
	_status.custom_minimum_size.y = 28
	_status.add_theme_font_size_override("normal_font_size", 9)
	page.add_child(_status)

	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.title = "选择合法取得的 PAL Data 目录"
	_dialog.use_native_dialog = true
	_dialog.dir_selected.connect(_on_directory_selected)
	add_child(_dialog)


func _show_idle_state() -> void:
	var has_generated_content := FileAccess.file_exists("res://generated/pal/content/core/scenes.bin")
	_explore_button.disabled = not has_generated_content
	_story_test_button.disabled = not has_generated_content
	_rng_button.disabled = not FileAccess.file_exists("res://generated/pal/rng/000/000.png")
	_status.text = "[color=#93c5fd]%s[/color] 本仓库不会复制或上传原版数据。" % ("已发现本地生成内容，可以打开预览。" if has_generated_content else "等待资源目录。")
	var root := _details.create_item()
	var item := _details.create_item(root)
	item.set_text(0, "尚未校验")


func _open_dialog() -> void:
	_dialog.popup_centered_ratio(0.8)


func _on_directory_selected(path: String) -> void:
	_source_path.text = path


func _run_import() -> void:
	var source := _source_path.text.strip_edges()
	if source.is_empty():
		_status.text = "[color=#fca5a5]请先选择 Data 目录。[/color]"
		return
	_import_button.disabled = true
	_status.text = "[color=#fde68a]正在校验资源索引并生成本地预览…[/color]"
	await get_tree().process_frame
	var report := PalDataImporter.import_from(source)
	_show_report(report)
	_import_button.disabled = false


func _show_report(report: PalImportReport) -> void:
	_details.clear()
	var root := _details.create_item()
	for file_name: String in report.files.keys():
		if file_name in ["fbp_preview", "sprite_preview", "map_preview", "rng_preview", "voc_conversion", "rix_conversion", "mgo_conversion", "rgm_conversion", "content_database", "text_conversion"]:
			continue
		var metadata: Dictionary = report.files[file_name]
		var item := _details.create_item(root)
		item.set_text(0, metadata.get("actual_name", file_name))
		item.set_text(1, str(metadata.get("chunks", "—")))
		item.set_text(2, _format_size(int(metadata.get("size", 0))))

	var lines: Array[String] = []
	lines.append("[color=%s]%s[/color]" % ["#86efac" if report.success else "#fca5a5", report.summary()])
	for error in report.errors:
		lines.append("[color=#fca5a5]错误：%s[/color]" % error)
	for warning in report.warnings:
		lines.append("[color=#fde68a]提示：%s[/color]" % warning)
	if report.success:
		lines.append("本地清单：%s" % report.manifest_path)
		_explore_button.disabled = false
		_story_test_button.disabled = false
		_rng_button.disabled = not report.files.has("rng_preview")
	_status.text = "\n".join(lines)

	_preview.texture = null
	if not report.preview_path.is_empty() and FileAccess.file_exists(report.preview_path):
		var image := Image.load_from_file(report.preview_path)
		if not image.is_empty():
			_preview.texture = ImageTexture.create_from_image(image)


func _open_explorer() -> void:
	get_tree().change_scene_to_file("res://scenes/map_explorer.tscn")


func _open_rng_preview() -> void:
	get_tree().change_scene_to_file("res://scenes/rng_preview.tscn")


func _open_story_test() -> void:
	get_tree().change_scene_to_file("res://scenes/story_test_lab.tscn")


func _format_size(bytes: int) -> String:
	if bytes >= 1024 * 1024:
		return "%.1f MiB" % (bytes / 1048576.0)
	if bytes >= 1024:
		return "%.1f KiB" % (bytes / 1024.0)
	return "%d B" % bytes
