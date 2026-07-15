# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL Sprite 帧表读取器；每帧仍保持原始 RLE 字节，按需交给 `RleDecoder`。
## 解析保留 SDLPal 对损坏末尾哨兵和 17 位偏移回绕的兼容行为。
class_name PalSprite
extends RefCounted

## 帧表长度、偏移顺序或边界错误。
var error_message: String = ""
var _data: PackedByteArray = PackedByteArray()
var _frame_offsets: PackedInt64Array = PackedInt64Array()


## 从完整 Sprite 分块解析帧偏移表。
static func from_bytes(data: PackedByteArray) -> PalSprite:
	var sprite := PalSprite.new()
	sprite._parse(data)
	return sprite


## 返回帧表是否至少包含一个合法帧。
func is_valid() -> bool:
	return error_message.is_empty() and _frame_offsets.size() >= 2


## 返回可读取帧数，无效 Sprite 返回 0。
func frame_count() -> int:
	return maxi(0, _frame_offsets.size() - 1) if is_valid() else 0


## 返回指定帧的原始 RLE 字节，越界时返回空数组。
func get_frame(index: int) -> PackedByteArray:
	if index < 0 or index >= frame_count():
		return PackedByteArray()
	return _data.slice(_frame_offsets[index], _frame_offsets[index + 1])


func _parse(data: PackedByteArray) -> void:
	if data.size() < 4:
		error_message = "Sprite 索引太短"
		return
	var table_words := PalBinary.u16_le(data, 0)
	if table_words < 2 or table_words * 2 > data.size():
		error_message = "Sprite 帧表无效"
		return
	# The first word is the offset-table length in words. The final table word is
	# an unused/broken sentinel in several original GOP archives, so frame count
	# is table_words - 1 and the chunk boundary is the reliable final end offset.
	var frame_count_value := table_words - 1
	var previous := -1
	for index in range(frame_count_value):
		var offset := PalBinary.u16_le(data, index * 2) * 2
		# SDLPal preserves this original data quirk: one MGO Sprite stores the
		# 17-bit offset 0x18444 in a 16-bit table and expects it to wrap to 0x8444.
		if offset == 0x18444:
			offset &= 0xffff
		if offset < table_words * 2 or offset > data.size() or previous > offset:
			error_message = "Sprite 帧偏移无效：%d" % offset
			_frame_offsets = PackedInt64Array()
			return
		_frame_offsets.append(offset)
		previous = offset
	_frame_offsets.append(data.size())
	_data = data
