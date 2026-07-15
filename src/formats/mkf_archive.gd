# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name MkfArchive
extends RefCounted

var source_path: String = ""
var error_message: String = ""
var _data: PackedByteArray = PackedByteArray()
var _offsets: PackedInt64Array = PackedInt64Array()


static func load_file(path: String) -> MkfArchive:
	var archive := MkfArchive.new()
	archive.source_path = path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		archive.error_message = "无法读取文件：%s（错误 %s）" % [path, FileAccess.get_open_error()]
		return archive
	archive._parse(file.get_buffer(file.get_length()))
	return archive


static func from_bytes(data: PackedByteArray) -> MkfArchive:
	var archive := MkfArchive.new()
	archive._parse(data)
	return archive


func is_valid() -> bool:
	return error_message.is_empty() and _offsets.size() >= 2


func chunk_count() -> int:
	return maxi(0, _offsets.size() - 1) if is_valid() else 0


func nonempty_chunk_count() -> int:
	var count := 0
	for index in range(chunk_count()):
		if _offsets[index + 1] > _offsets[index]:
			count += 1
	return count


func chunk_size(index: int) -> int:
	if index < 0 or index >= chunk_count():
		return -1
	return _offsets[index + 1] - _offsets[index]


func get_chunk(index: int) -> PackedByteArray:
	if index < 0 or index >= chunk_count():
		return PackedByteArray()
	return _data.slice(_offsets[index], _offsets[index + 1])


func total_size() -> int:
	return _data.size()


func _parse(data: PackedByteArray) -> void:
	_data = PackedByteArray()
	_offsets = PackedInt64Array()
	error_message = ""
	if data.size() < 8:
		error_message = "MKF 文件小于最小索引长度"
		return

	var first_offset := PalBinary.u32_le(data, 0)
	if first_offset < 8 or first_offset > data.size() or first_offset % 4 != 0:
		error_message = "MKF 首偏移无效：%d（文件大小 %d）" % [first_offset, data.size()]
		return

	var offset_count := first_offset / 4
	var previous := -1
	for index in range(offset_count):
		var offset := PalBinary.u32_le(data, index * 4)
		if offset < first_offset or offset > data.size():
			error_message = "MKF 索引 %d 越界：%d" % [index, offset]
			_offsets = PackedInt64Array()
			return
		if previous > offset:
			error_message = "MKF 索引没有按升序排列：%d > %d" % [previous, offset]
			_offsets = PackedInt64Array()
			return
		_offsets.append(offset)
		previous = offset

	_data = data

