# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalDialogBox
extends Control

var _panel: PanelContainer
var _portrait_column: VBoxContainer
var _portrait: TextureRect
var _speaker: Label
var _inline_speaker: Label
var _message: Label
var _separator: ColorRect
var _hint: Label
var _position_mode: int = 1
var _lines: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	hide_dialog()


func begin(position_mode: int, _color_index: int = 0, portrait_texture: Texture2D = null) -> void:
	_position_mode = position_mode
	_apply_position()
	_lines.clear()
	_speaker.text = ""
	_inline_speaker.text = ""
	_message.text = ""
	_portrait.texture = portrait_texture
	_portrait_column.visible = portrait_texture != null
	_inline_speaker.visible = portrait_texture == null
	_separator.visible = false
	_hint.visible = false
	visible = true


func show_message(text: String) -> void:
	if not visible:
		begin(_position_mode)
	var content := text.strip_edges()
	if _is_speaker_title(content):
		content = content.trim_suffix(":").trim_suffix("：").trim_suffix("∶")
		_speaker.text = content
		_inline_speaker.text = content
		_separator.visible = not content.is_empty()
		return
	_lines.append(content)
	while _lines.size() > 3:
		_lines.pop_front()
	_message.text = "\n".join(_lines)
	_hint.visible = true


func hide_dialog() -> void:
	visible = false
	_lines.clear()
	if _message != null:
		_message.text = ""


func _build_interface() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.038, 0.025, 0.95)
	style.border_color = Color("d6a85f")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", style)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	_panel.add_child(layout)

	_portrait_column = VBoxContainer.new()
	_portrait_column.custom_minimum_size.x = 70
	_portrait_column.add_theme_constant_override("separation", 1)
	layout.add_child(_portrait_column)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(70, 62)
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color("17120d")
	portrait_style.border_color = Color("8f6d3a")
	portrait_style.set_border_width_all(1)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	_portrait_column.add_child(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(_portrait)

	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speaker.add_theme_font_size_override("font_size", 8)
	_speaker.add_theme_color_override("font_color", Color("f3c76f"))
	_portrait_column.add_child(_speaker)

	var content_column := VBoxContainer.new()
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 2)
	layout.add_child(content_column)

	_inline_speaker = Label.new()
	_inline_speaker.add_theme_font_size_override("font_size", 9)
	_inline_speaker.add_theme_color_override("font_color", Color("f3c76f"))
	content_column.add_child(_inline_speaker)

	_separator = ColorRect.new()
	_separator.color = Color("8f6d3a")
	_separator.custom_minimum_size.y = 1
	content_column.add_child(_separator)

	_message = Label.new()
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 10)
	_message.add_theme_color_override("font_color", Color("fff7e8"))
	content_column.add_child(_message)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color("f3c76f"))
	add_child(_hint)
	_apply_position()


func _apply_position() -> void:
	if _panel == null:
		return
	var rect := Rect2(6, 104, 308, 90)
	match _position_mode:
		0:
			rect = Rect2(6, 6, 308, 90)
		1:
			rect = Rect2(6, 104, 308, 90)
		2:
			rect = Rect2(16, 55, 288, 90)
		3:
			rect = Rect2(34, 65, 252, 70)
	_panel.position = rect.position
	_panel.size = rect.size
	_hint.position = rect.position + rect.size - Vector2(17, 16)


static func _is_speaker_title(text: String) -> bool:
	return text.ends_with(":") or text.ends_with("：") or text.ends_with("∶")
