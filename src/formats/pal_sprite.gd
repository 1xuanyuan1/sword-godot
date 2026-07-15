# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalSprite
extends RefCounted

var error_message: String = ""
var _data: PackedByteArray = PackedByteArray()
var _frame_offsets: PackedInt64Array = PackedInt64Array()


static func from_bytes(data: PackedByteArray) -> PalSprite:
	var sprite := PalSprite.new()
	sprite._parse(data)
	return sprite


func is_valid() -> bool:
	return error_message.is_empty() and _frame_offsets.size() >= 2


func frame_count() -> int:
	return maxi(0, _frame_offsets.size() - 1) if is_valid() else 0


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
	var previous := -1
	for index in range(table_words):
		var offset := PalBinary.u16_le(data, index * 2) * 2
		if offset < table_words * 2 or offset > data.size() or previous > offset:
			error_message = "Sprite 帧偏移无效：%d" % offset
			_frame_offsets = PackedInt64Array()
			return
		_frame_offsets.append(offset)
		previous = offset
	_data = data

