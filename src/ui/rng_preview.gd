# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 播放导入器生成的首个 RNG 增量动画预览，用于验证帧序和 16 FPS 时序。
## 最终剧情过场将由 ScriptVM 和专用播放器接管，本界面仅属资源实验室。
extends Control

const FRAME_DIRECTORY := "res://generated/pal/rng/000"
const FRAME_DURATION := 1.0 / 16.0

var _preview: TextureRect
var _frame_label: Label
var _play_button: Button
var _textures: Array[Texture2D] = []
var _frame_index := 0
var _elapsed := 0.0
var _playing := true


func _ready() -> void:
	_build_interface()
	_load_frames()
	_show_frame()


func _process(delta: float) -> void:
	if not _playing or _textures.size() < 2:
		return
	_elapsed += delta
	while _elapsed >= FRAME_DURATION:
		_elapsed -= FRAME_DURATION
		_frame_index = (_frame_index + 1) % _textures.size()
		_show_frame()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_lab()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_toggle_playback()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_preview = TextureRect.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_preview)

	var toolbar := PanelContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = 25
	add_child(toolbar)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	toolbar.add_child(controls)

	var back_button := Button.new()
	back_button.text = "返回"
	back_button.pressed.connect(_return_to_lab)
	controls.add_child(back_button)

	var title := Label.new()
	title.text = "RNG 增量动画预览（调色板 0）"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(title)

	_frame_label = Label.new()
	controls.add_child(_frame_label)

	_play_button = Button.new()
	_play_button.text = "暂停"
	_play_button.pressed.connect(_toggle_playback)
	controls.add_child(_play_button)

	var hint := Label.new()
	hint.text = "Enter：播放/暂停　Esc：返回"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -18
	hint.add_theme_color_override("font_color", Color("e5e7eb"))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(hint)


func _load_frames() -> void:
	var directory := DirAccess.open(FRAME_DIRECTORY)
	if directory == null:
		_frame_label.text = "没有本地预览，请先导入资源"
		_playing = false
		_play_button.disabled = true
		return
	var file_names: Array[String] = []
	for file_name in directory.get_files():
		if file_name.to_lower().ends_with(".png"):
			file_names.append(file_name)
	file_names.sort()
	for file_name in file_names:
		var image := Image.load_from_file(FRAME_DIRECTORY.path_join(file_name))
		if not image.is_empty():
			_textures.append(ImageTexture.create_from_image(image))
	if _textures.is_empty():
		_frame_label.text = "预览帧读取失败"
		_playing = false
		_play_button.disabled = true


func _show_frame() -> void:
	if _textures.is_empty():
		return
	_preview.texture = _textures[_frame_index]
	_frame_label.text = "%d / %d" % [_frame_index + 1, _textures.size()]


func _toggle_playback() -> void:
	if _textures.size() < 2:
		return
	_playing = not _playing
	_play_button.text = "暂停" if _playing else "播放"


func _return_to_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
