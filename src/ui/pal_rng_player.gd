# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 在探索 HUD 上从本地 RNG.MKF 流式播放 320×200 增量动画。
## 播放器只维护当前索引画布与一个可更新 RG8 纹理，完成后通知 ScriptVM 解除阻塞。
class_name PalRngPlayer
extends Control

const PALETTE_SHADER: Shader = preload("res://shaders/indexed_palette.gdshader")

## 当前一段 RNG 动画已经播放到结束。
signal playback_finished

## 最近一次归档、帧范围或增量解码失败原因。
var error_message: String = ""

var _database: PalContentDatabase
var _session: GameSession
var _preview: TextureRect
var _stream := RngPlaybackStream.new()
var _texture: ImageTexture
var _palette_material: ShaderMaterial
var _frame_index: int = 0
var _selected_frame_count: int = 0
var _elapsed: float = 0.0
var _frames_per_second: int = 16
var _playing: bool = false
var _paused: bool = false
var _failed_notification_pending: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview = TextureRect.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette_material = ShaderMaterial.new()
	_palette_material.shader = PALETTE_SHADER
	_palette_material.set_shader_parameter("palette_mix", 1.0)
	_palette_material.set_shader_parameter("global_alpha", 1.0)
	_preview.material = _palette_material
	add_child(_preview)
	hide()


## 绑定内容数据库、可选会话调色板和导入器保存的压缩 RNG.MKF。
func configure(database: PalContentDatabase, session: GameSession = null) -> bool:
	_database = database
	_session = session
	error_message = ""
	if database == null:
		error_message = "RNG 播放器缺少内容数据库"
		return false
	if not _stream.configure(database.root_path.path_join("archives/rng.mkf")):
		error_message = _stream.error_message
		return false
	# 允许父节点在播放器进入场景树前先绑定数据库；材质会在 `_ready()` 或首次播放时建立。
	return true if _palette_material == null else _update_palette()


## 播放指定动画的含首尾帧区间；`end_frame < 0` 表示播放到最后一帧。
## 资源或帧损坏时异步结束，避免剧情脚本永久卡住。
func play(animation_number: int, start_frame: int = 0, end_frame: int = -1, frames_per_second: int = 16) -> bool:
	stop_playback(false)
	error_message = ""
	_frames_per_second = maxi(1, frames_per_second)
	if _database == null or not _update_palette() or not _stream.open(animation_number, start_frame, end_frame):
		if error_message.is_empty():
			error_message = _stream.error_message if not _stream.error_message.is_empty() else "RNG 播放器尚未配置"
		_schedule_failed_notification()
		return false
	if not _upload_current_frame():
		_schedule_failed_notification()
		return false
	_frame_index = start_frame
	_selected_frame_count = _stream.end_frame - start_frame + 1
	_elapsed = 0.0
	_playing = true
	_paused = false
	show()
	return true


## 停止当前播放并释放动画分块；`notify_vm` 为真时发出完成信号。
func stop_playback(notify_vm: bool = true) -> void:
	_playing = false
	_paused = false
	_elapsed = 0.0
	_frame_index = 0
	_selected_frame_count = 0
	_failed_notification_pending = false
	_stream.close()
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
	if not _playing or _paused:
		return
	_elapsed += delta
	var frame_duration := 1.0 / float(_frames_per_second)
	while _elapsed >= frame_duration and _playing:
		_elapsed -= frame_duration
		if not _stream.has_next():
			_finish_playback()
			continue
		if not _stream.advance():
			error_message = _stream.error_message
			_finish_playback()
			continue
		_frame_index = _stream.frame_index
		if not _upload_current_frame():
			_finish_playback()


func _update_palette() -> bool:
	if _database == null or _palette_material == null:
		return false
	var palette_index := _session.palette_index if _session != null else 0
	var night := _session.night_palette if _session != null else false
	var palette := _database.load_palette(palette_index, night)
	if palette.size() < PaletteDecoder.PALETTE_BYTES:
		error_message = "RNG 调色板 %d %s 缺失" % [palette_index, "night" if night else "day"]
		return false
	var image := Image.create_from_data(256, 1, false, Image.FORMAT_RGB8, palette)
	_palette_material.set_shader_parameter("palette_texture", ImageTexture.create_from_image(image))
	return true


func _upload_current_frame() -> bool:
	var indexed := _stream.current_indexed_image()
	if not indexed.is_valid():
		error_message = indexed.error_message if not indexed.error_message.is_empty() else "RNG 当前索引帧无效"
		return false
	var image := indexed.to_index_alpha_image()
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
	else:
		_texture.update(image)
	_preview.texture = _texture
	return true


func _schedule_failed_notification() -> void:
	_failed_notification_pending = true
	call_deferred("_notify_failed_playback")


func _notify_failed_playback() -> void:
	if not _failed_notification_pending:
		return
	_failed_notification_pending = false
	playback_finished.emit()


func _finish_playback() -> void:
	stop_playback(true)
