# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")

var _toast: PalDialogBox


func _ready() -> void:
	_build_interface()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("111827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 5)
	margin.add_child(page)

	var title := Label.new()
	title.text = "剧情与交互测试"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("fbbf24"))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "直接进入检查点；不会修改正式存档，也不会提交本地素材。"
	subtitle.add_theme_font_size_override("font_size", 8)
	subtitle.add_theme_color_override("font_color", Color("cbd5e1"))
	page.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	page.add_child(grid)

	_add_checkpoint_button(grid, "开场对话与动作", "intro")
	_add_checkpoint_button(grid, "嘿嘿／李大娘回应", "secret_passage")
	_add_checkpoint_button(grid, "黑苗人客栈对话", "miao_inn")
	_add_checkpoint_button(grid, "楼梯八步动画", "stairs")
	_add_checkpoint_button(grid, "500 文 Toast", "toast")

	var back_button := Button.new()
	back_button.text = "返回资源实验室（Esc）"
	back_button.add_theme_font_size_override("font_size", 9)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	page.add_child(back_button)

	_toast = PalDialogBox.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_toast)


func _add_checkpoint_button(parent: Control, label: String, checkpoint_id: String) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(_open_checkpoint.bind(checkpoint_id))
	parent.add_child(button)


func _open_checkpoint(checkpoint_id: String) -> void:
	if checkpoint_id == "toast":
		_toast.begin(3)
		_toast.show_message("获得500文钱")
		await get_tree().create_timer(1.4).timeout
		_toast.hide_dialog()
		return
	if DebugCheckpoint.request(checkpoint_id):
		get_tree().change_scene_to_file("res://scenes/map_explorer.tscn")
