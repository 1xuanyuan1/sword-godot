# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 在探索 HUD 上播放导入器生成的 320×200 RNG 剧情动画帧。
## 播放完成后通知 ScriptVM 解除阻塞；原始 RNG 数据和生成帧仍只保留在本机。
class_name PalRngPlayer
extends Control

## 当前一段 RNG 动画已经播放到结束。
signal playback_finished

var _rng_root: String = "res://generated/pal/rng"
var _preview: TextureRect
var _textures: Array[Texture2D] = []
var _frame_index: int = 0
var _elapsed: float = 0.0
var _frames_per_second: int = 16
var _playing: bool = false
var _paused: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview = TextureRect.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	hide()


## 将帧目录绑定到内容数据库所在的 `generated/pal/` 根目录。
func configure(database: PalContentDatabase) -> void:
	if database != null:
		_rng_root = database.root_path.get_base_dir().path_join("rng")


## 播放指定动画的含首尾帧区间；`end_frame < 0` 表示播放到最后一帧。
## 目录或帧缺失时异步结束，避免剧情脚本永久卡住。
func play(animation_number: int, start_frame: int = 0, end_frame: int = -1, frames_per_second: int = 16) -> bool:
	stop_playback(false)
	_frames_per_second = maxi(1, frames_per_second)
	var directory_path := _rng_root.path_join("%03d" % animation_number)
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		call_deferred("_finish_playback")
		return false
	var file_names: Array[String] = []
	for file_name in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue
		var frame_number := file_name.get_basename().to_int()
		if frame_number < start_frame or (end_frame >= 0 and frame_number > end_frame):
			continue
		file_names.append(file_name)
	file_names.sort()
	for file_name in file_names:
		var image := Image.load_from_file(absolute_directory.path_join(file_name))
		if not image.is_empty():
			_textures.append(ImageTexture.create_from_image(image))
	if _textures.is_empty():
		call_deferred("_finish_playback")
		return false
	_frame_index = 0
	_elapsed = 0.0
	_playing = true
	_paused = false
	_preview.texture = _textures[0]
	show()
	return true


## 停止当前播放并清空帧；`notify_vm` 为真时发出完成信号。
func stop_playback(notify_vm: bool = true) -> void:
	_playing = false
	_paused = false
	_elapsed = 0.0
	_frame_index = 0
	_textures.clear()
	if _preview != null:
		_preview.texture = null
	hide()
	if notify_vm:
		playback_finished.emit()


## 暂停或恢复当前 RNG 的逐帧推进，但保持首帧纹理和 HUD 可见。
## 用于 SDLPal 在第一帧显示后同步执行调色板渐显；未播放时调用不会启动动画。
func set_playback_paused(paused: bool) -> void:
	_paused = paused if _playing else false


func _process(delta: float) -> void:
	if not _playing or _paused or _textures.is_empty():
		return
	_elapsed += delta
	var frame_duration := 1.0 / float(_frames_per_second)
	while _elapsed >= frame_duration and _playing:
		_elapsed -= frame_duration
		_frame_index += 1
		if _frame_index >= _textures.size():
			_finish_playback()
		else:
			_preview.texture = _textures[_frame_index]


func _finish_playback() -> void:
	if not _playing and _textures.is_empty() and not visible:
		# 缺失资源也必须只通知一次；deferred 调用在这里完成脚本解锁。
		playback_finished.emit()
		return
	stop_playback(true)
