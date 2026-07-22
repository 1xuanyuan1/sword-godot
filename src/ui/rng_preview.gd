# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式运行时流循环播放 RNG.MKF 第 0 段，验证增量帧序和 16 FPS 时序。
extends Control

const ANIMATION_NUMBER := 0
const FRAME_RATE := 16

var _player: PalRngPlayer
var _frame_label: Label
var _play_button: Button
var _playing := true


func _ready() -> void:
	_build_interface()
	_start_stream()


func _process(_delta: float) -> void:
	if _player != null and _player._selected_frame_count > 0:
		_frame_label.text = "%d / %d" % [_player._frame_index + 1, _player._stream.frame_count]


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

	_player = PalRngPlayer.new()
	_player.name = "RuntimeRngPreview"
	_player.playback_finished.connect(_on_playback_finished)
	add_child(_player)

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
	title.text = "RNG.MKF 运行时流（调色板 0）"
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


func _start_stream() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated() or not _player.configure(database) or not _player.play(ANIMATION_NUMBER, 0, -1, FRAME_RATE):
		_frame_label.text = "RNG 运行时流不可用：%s" % _player.error_message
		_playing = false
		_play_button.disabled = true


func _on_playback_finished() -> void:
	if _playing and is_inside_tree():
		call_deferred("_restart_stream")


func _restart_stream() -> void:
	if _playing and not _player.play(ANIMATION_NUMBER, 0, -1, FRAME_RATE):
		_frame_label.text = "RNG 重播失败：%s" % _player.error_message
		_playing = false
		_play_button.disabled = true


func _toggle_playback() -> void:
	if _player == null or _play_button.disabled:
		return
	_playing = not _playing
	_player.set_playback_paused(not _playing)
	_play_button.text = "暂停" if _playing else "播放"


func _return_to_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/import_lab.tscn")
