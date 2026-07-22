# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 从本地 RNG.MKF 按动画分块读取压缩帧，并在一张 320×200 索引画布上顺序应用增量。
## 跳到非零起始帧时会从第 0 帧预热；运行时不会保存完整 RGBA 帧数组。
class_name RngPlaybackStream
extends RefCounted

## 最近一次文件、动画、帧范围或增量解码失败原因。
var error_message: String = ""
## 当前动画的绝对帧编号；未打开时为 -1。
var frame_index: int = -1
## 当前动画实际可解码的总帧数。
var frame_count: int = 0
## 本次打开区间的最后一帧编号。
var end_frame: int = -1
## 本次打开后已经解压并应用的帧数，包含跳段预热帧。
var decoded_frame_count: int = 0

var _archive_path: String = ""
var _archive_size: int = 0
var _archive_offsets: PackedInt64Array = PackedInt64Array()
var _animation: RngAnimation
var _decoder := RngFrameDecoder.new()


## 读取并验证一份本地 RNG.MKF 的外层偏移表；不把动画分块或解码帧常驻内存。
func configure(path: String) -> bool:
	error_message = ""
	_archive_path = ""
	_archive_size = 0
	_archive_offsets = PackedInt64Array()
	close()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error_message = "RNG.MKF 无法读取：%s（错误 %s）" % [path, FileAccess.get_open_error()]
		return false
	_archive_size = file.get_length()
	if _archive_size < 8:
		error_message = "RNG.MKF 小于最小索引长度"
		return false
	var first_offset_bytes := file.get_buffer(4)
	if first_offset_bytes.size() != 4:
		error_message = "RNG.MKF 无法读取首偏移"
		return false
	var first_offset := PalBinary.u32_le(first_offset_bytes, 0)
	if first_offset < 8 or first_offset > _archive_size or first_offset % 4 != 0:
		error_message = "RNG.MKF 首偏移无效：%d（文件大小 %d）" % [first_offset, _archive_size]
		return false
	file.seek(0)
	var table := file.get_buffer(first_offset)
	if table.size() != first_offset:
		error_message = "RNG.MKF 偏移表读取不完整：%d/%d" % [table.size(), first_offset]
		return false
	var previous := -1
	for index in range(first_offset / 4):
		var offset := PalBinary.u32_le(table, index * 4)
		if offset < first_offset or offset > _archive_size:
			error_message = "RNG.MKF 索引 %d 越界：%d" % [index, offset]
			_archive_offsets = PackedInt64Array()
			return false
		if previous > offset:
			error_message = "RNG.MKF 索引没有按升序排列：%d > %d" % [previous, offset]
			_archive_offsets = PackedInt64Array()
			return false
		_archive_offsets.append(offset)
		previous = offset
	_archive_path = path
	return true


## 返回归档内动画分块数量；尚未配置时为 0。
func animation_count() -> int:
	return maxi(0, _archive_offsets.size() - 1)


## 返回指定动画末尾空分块之前的可播放帧数。
func animation_frame_count(animation_number: int) -> int:
	var animation := _animation_for(animation_number)
	return animation.playable_frame_count() if animation != null else 0


## 打开一段含首尾帧的播放区间；非零起始帧会顺序解码前序帧以恢复正确画布。
func open(animation_number: int, start_frame: int = 0, requested_end_frame: int = -1) -> bool:
	error_message = ""
	frame_index = -1
	frame_count = 0
	end_frame = -1
	decoded_frame_count = 0
	_decoder.reset()
	_animation = _animation_for(animation_number)
	if _animation == null:
		return false
	frame_count = _animation.playable_frame_count()
	if frame_count <= 0:
		error_message = "RNG 动画 %d 没有可播放帧" % animation_number
		return false
	if start_frame < 0 or start_frame >= frame_count:
		error_message = "RNG 动画 %d 起始帧越界：%d/%d" % [animation_number, start_frame, frame_count]
		return false
	end_frame = frame_count - 1 if requested_end_frame < 0 else mini(requested_end_frame, frame_count - 1)
	if end_frame < start_frame:
		error_message = "RNG 动画 %d 帧区间无效：%d..%d" % [animation_number, start_frame, requested_end_frame]
		return false
	for index in range(start_frame + 1):
		if not _apply_frame(index):
			return false
	frame_index = start_frame
	return true


## 当前区间是否还有下一帧。
func has_next() -> bool:
	return _animation != null and frame_index >= 0 and frame_index < end_frame


## 顺序应用下一帧；区间已结束或解码失败时返回 `false`。
func advance() -> bool:
	if not has_next():
		return false
	var next_frame := frame_index + 1
	if not _apply_frame(next_frame):
		return false
	frame_index = next_frame
	return true


## 释放当前动画分块和索引画布；已配置的外层偏移表仍可用于下一次 `open()`。
func close() -> void:
	frame_index = -1
	frame_count = 0
	end_frame = -1
	decoded_frame_count = 0
	_animation = null
	_decoder.reset()


## 返回当前 320×200 索引画面，供可更新 RG8 纹理上传。
func current_indexed_image() -> PalIndexedImage:
	return _decoder.to_indexed_image()


## 返回当前索引画布副本，供回归比较跳段预热结果。
func current_indices() -> PackedByteArray:
	return _decoder.indices.duplicate()


func _animation_for(animation_number: int) -> RngAnimation:
	if _archive_path.is_empty() or _archive_offsets.size() < 2:
		error_message = "RNG.MKF 尚未配置"
		return null
	if animation_number < 0 or animation_number >= animation_count():
		error_message = "RNG 动画编号越界：%d/%d" % [animation_number, animation_count()]
		return null
	var chunk_start := _archive_offsets[animation_number]
	var chunk_size := _archive_offsets[animation_number + 1] - chunk_start
	if chunk_size <= 0:
		error_message = "RNG 动画 %d 分块为空" % animation_number
		return null
	var file := FileAccess.open(_archive_path, FileAccess.READ)
	if file == null:
		error_message = "RNG.MKF 重新读取失败：%s（错误 %s）" % [_archive_path, FileAccess.get_open_error()]
		return null
	if file.get_length() != _archive_size:
		error_message = "RNG.MKF 大小在配置后发生变化：%d/%d" % [file.get_length(), _archive_size]
		return null
	file.seek(chunk_start)
	var chunk := file.get_buffer(chunk_size)
	if chunk.size() != chunk_size:
		error_message = "RNG 动画 %d 分块读取不完整：%d/%d" % [animation_number, chunk.size(), chunk_size]
		return null
	var animation := RngAnimation.from_mkf_chunk(chunk)
	if not animation.is_valid():
		error_message = "RNG 动画 %d 帧表无效：%s" % [animation_number, animation.error_message]
		return null
	return animation


func _apply_frame(index: int) -> bool:
	var delta := _animation.decompress_frame(index)
	if delta.is_empty():
		error_message = "RNG 帧 %d 解压失败：%s" % [index, _animation.error_message]
		return false
	if not _decoder.apply_delta(delta):
		error_message = "RNG 帧 %d 增量解码失败：%s" % [index, _decoder.error_message]
		return false
	decoded_frame_count += 1
	return true
