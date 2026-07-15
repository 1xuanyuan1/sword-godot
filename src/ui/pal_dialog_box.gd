# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalDialogBox
extends Control

var _panel: PanelContainer
var _message: Label
var _hint: Label
var _position_mode: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	hide_dialog()


func begin(position_mode: int, _color_index: int = 0, _portrait: int = 0) -> void:
	_position_mode = position_mode
	_apply_position()
	_message.text = ""
	visible = true


func show_message(text: String) -> void:
	if not visible:
		begin(_position_mode)
	_message.text = text
	_hint.visible = true


func hide_dialog() -> void:
	visible = false
	if _message != null:
		_message.text = ""


func _build_interface() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.055, 0.94)
	style.border_color = Color("93c5fd")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 10)
	_message.add_theme_color_override("font_color", Color("f8fafc"))
	_panel.add_child(_message)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color("fbbf24"))
	add_child(_hint)
	_apply_position()


func _apply_position() -> void:
	if _panel == null:
		return
	var rect := Rect2(8, 130, 304, 62)
	match _position_mode:
		0:
			rect = Rect2(8, 8, 304, 62)
		1:
			rect = Rect2(8, 130, 304, 62)
		2:
			rect = Rect2(20, 66, 280, 68)
		3:
			rect = Rect2(35, 70, 250, 60)
	_panel.position = rect.position
	_panel.size = rect.size
	_hint.position = rect.position + rect.size - Vector2(18, 17)
