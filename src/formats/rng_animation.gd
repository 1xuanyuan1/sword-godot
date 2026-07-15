# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c and palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 一个 RNG 动画分块的帧容器；外层使用嵌套 MKF，单帧仍是 YJ1 压缩增量流。
## 解压后的增量需要依次交给 `RngFrameDecoder`，不能独立当作完整图片。
class_name RngAnimation
extends RefCounted

const MAX_DECOMPRESSED_FRAME_SIZE := 65000

## 外层帧表或单帧解压失败原因。
var error_message: String = ""
var _frames: MkfArchive


## 解析 RNG.MKF 中一个动画分块的嵌套帧表。
static func from_mkf_chunk(data: PackedByteArray) -> RngAnimation:
	var animation := RngAnimation.new()
	animation._frames = MkfArchive.from_bytes(data)
	if not animation._frames.is_valid():
		animation.error_message = "RNG 内层帧表无效：%s" % animation._frames.error_message
	return animation


## 返回嵌套 MKF 是否有效。
func is_valid() -> bool:
	return error_message.is_empty() and _frames != null and _frames.is_valid()


## 返回帧表数量，包括原版可能保留的末尾空帧。
func frame_count() -> int:
	return _frames.chunk_count() if is_valid() else 0


## 返回指定压缩帧大小，越界时为 0。
func frame_size(index: int) -> int:
	return _frames.chunk_size(index) if is_valid() else -1


## 返回指定帧的 YJ1 压缩字节。
func get_compressed_frame(index: int) -> PackedByteArray:
	if not is_valid() or index < 0 or index >= frame_count():
		return PackedByteArray()
	return _frames.get_chunk(index)


## 解压指定帧的 RNG 增量指令，失败时返回空数组并设置错误信息。
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
