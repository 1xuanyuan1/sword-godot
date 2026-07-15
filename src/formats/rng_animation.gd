# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c and palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name RngAnimation
extends RefCounted

const MAX_DECOMPRESSED_FRAME_SIZE := 65000

var error_message: String = ""
var _frames: MkfArchive


static func from_mkf_chunk(data: PackedByteArray) -> RngAnimation:
	var animation := RngAnimation.new()
	animation._frames = MkfArchive.from_bytes(data)
	if not animation._frames.is_valid():
		animation.error_message = "RNG 内层帧表无效：%s" % animation._frames.error_message
	return animation


func is_valid() -> bool:
	return error_message.is_empty() and _frames != null and _frames.is_valid()


func frame_count() -> int:
	return _frames.chunk_count() if is_valid() else 0


func frame_size(index: int) -> int:
	return _frames.chunk_size(index) if is_valid() else -1


func get_compressed_frame(index: int) -> PackedByteArray:
	if not is_valid() or index < 0 or index >= frame_count():
		return PackedByteArray()
	return _frames.get_chunk(index)


func decompress_frame(index: int) -> PackedByteArray:
	error_message = ""
	if _frames == null or not _frames.is_valid():
		error_message = "RNG 动画尚未载入"
		return PackedByteArray()
	if index < 0 or index >= _frames.chunk_count():
		error_message = "RNG 帧索引越界：%d" % index
		return PackedByteArray()
	var compressed := _frames.get_chunk(index)
	if compressed.is_empty():
		error_message = "RNG 帧 %d 为空" % index
		return PackedByteArray()
	var decoder := Yj1Decoder.new()
	var result := decoder.decompress(compressed, MAX_DECOMPRESSED_FRAME_SIZE)
	if result.is_empty():
		error_message = "RNG 帧 %d 解压失败：%s" % [index, decoder.error_message]
	return result
