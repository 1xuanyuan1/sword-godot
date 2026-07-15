# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal rngplay.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal RNG 增量帧解释器，持有一张持续更新的 320×200 索引画布。
## 每帧操作都基于上一帧，因此播放或导出时必须按原始顺序调用。
class_name RngFrameDecoder
extends RefCounted

const WIDTH := 320
const HEIGHT := 200
const PIXEL_COUNT := WIDTH * HEIGHT

## 当前完整画面的 64000 个调色板索引。
var indices: PackedByteArray = PackedByteArray()
## 最近一次画布设置或增量解析失败原因。
var error_message: String = ""


func _init() -> void:
	reset()


## 用单一颜色清空画布和错误状态。
func reset(color_index: int = 0) -> void:
	error_message = ""
	indices.resize(PIXEL_COUNT)
	indices.fill(clampi(color_index, 0, 255))


## 用完整 320×200 索引数据替换当前画布，长度不符时返回 `false`。
func set_canvas(source: PackedByteArray) -> bool:
	error_message = ""
	if source.size() != PIXEL_COUNT:
		return _fail("RNG 底图尺寸应为 %d 字节，实际为 %d" % [PIXEL_COUNT, source.size()])
	indices = source.duplicate()
	return true


## 按 SDLPal `PAL_RNGBlitToSurface` 操作码把一帧增量应用到当前画布。
func apply_delta(delta: PackedByteArray) -> bool:
	error_message = ""
	if indices.size() != PIXEL_COUNT:
		reset()
	var source_offset := 0
	var destination_offset := 0
	while source_offset < delta.size():
		var opcode := delta[source_offset]
		source_offset += 1
		match opcode:
			0x00, 0x13:
				return true
			0x02:
				destination_offset += 2
			0x03:
				if not PalBinary.can_read(delta, source_offset, 1):
					return _fail("RNG 0x03 跳过指令缺少长度")
				destination_offset += (delta[source_offset] + 1) * 2
				source_offset += 1
			0x04:
				if not PalBinary.can_read(delta, source_offset, 2):
					return _fail("RNG 0x04 跳过指令缺少长度")
				destination_offset += (PalBinary.u16_le(delta, source_offset) + 1) * 2
				source_offset += 2
			0x06, 0x07, 0x08, 0x09, 0x0a:
				var literal_pairs := opcode - 0x05
				var literal_bytes := literal_pairs * 2
				if not _can_transfer(delta, source_offset, destination_offset, literal_bytes):
					return false
				for index in range(literal_bytes):
					indices[destination_offset + index] = delta[source_offset + index]
				source_offset += literal_bytes
				destination_offset += literal_bytes
			0x0b:
				if not PalBinary.can_read(delta, source_offset, 1):
					return _fail("RNG 0x0B 写入指令缺少长度")
				var short_literal_bytes := (delta[source_offset] + 1) * 2
				source_offset += 1
				if not _can_transfer(delta, source_offset, destination_offset, short_literal_bytes):
					return false
				for index in range(short_literal_bytes):
					indices[destination_offset + index] = delta[source_offset + index]
				source_offset += short_literal_bytes
				destination_offset += short_literal_bytes
			0x0c:
				if not PalBinary.can_read(delta, source_offset, 2):
					return _fail("RNG 0x0C 写入指令缺少长度")
				var long_literal_bytes := (PalBinary.u16_le(delta, source_offset) + 1) * 2
				source_offset += 2
				if not _can_transfer(delta, source_offset, destination_offset, long_literal_bytes):
					return false
				for index in range(long_literal_bytes):
					indices[destination_offset + index] = delta[source_offset + index]
				source_offset += long_literal_bytes
				destination_offset += long_literal_bytes
			0x0d, 0x0e, 0x0f, 0x10:
				var fixed_repeat_count := opcode - 0x0b
				if not _write_repeated_pair(delta, source_offset, destination_offset, fixed_repeat_count):
					return false
				source_offset += 2
				destination_offset += fixed_repeat_count * 2
			0x11:
				if not PalBinary.can_read(delta, source_offset, 1):
					return _fail("RNG 0x11 重复指令缺少长度")
				var short_repeat_count := delta[source_offset] + 1
				source_offset += 1
				if not _write_repeated_pair(delta, source_offset, destination_offset, short_repeat_count):
					return false
				source_offset += 2
				destination_offset += short_repeat_count * 2
			0x12:
				if not PalBinary.can_read(delta, source_offset, 2):
					return _fail("RNG 0x12 重复指令缺少长度")
				var long_repeat_count := PalBinary.u16_le(delta, source_offset) + 1
				source_offset += 2
				if not _write_repeated_pair(delta, source_offset, destination_offset, long_repeat_count):
					return false
				source_offset += 2
				destination_offset += long_repeat_count * 2
			_:
				return _fail("RNG 未知操作码：0x%02X" % opcode)

		if destination_offset > PIXEL_COUNT:
			return _fail("RNG 目标位置越界：%d" % destination_offset)
	return true


## 返回当前画布副本，所有像素均视为不透明。
func to_indexed_image() -> PalIndexedImage:
	var image := PalIndexedImage.new()
	image.width = WIDTH
	image.height = HEIGHT
	image.indices = indices.duplicate()
	image.opacity.resize(PIXEL_COUNT)
	image.opacity.fill(255)
	if not error_message.is_empty():
		image.error_message = error_message
	return image


func _can_transfer(delta: PackedByteArray, source_offset: int, destination_offset: int, byte_count: int) -> bool:
	if not PalBinary.can_read(delta, source_offset, byte_count):
		return _fail("RNG 像素数据提前结束")
	if destination_offset < 0 or destination_offset > PIXEL_COUNT - byte_count:
		return _fail("RNG 像素写入越界：%d + %d" % [destination_offset, byte_count])
	return true


func _write_repeated_pair(delta: PackedByteArray, source_offset: int, destination_offset: int, repeat_count: int) -> bool:
	if not PalBinary.can_read(delta, source_offset, 2):
		return _fail("RNG 重复指令缺少像素对")
	var byte_count := repeat_count * 2
	if destination_offset < 0 or destination_offset > PIXEL_COUNT - byte_count:
		return _fail("RNG 重复像素写入越界：%d + %d" % [destination_offset, byte_count])
	var first := delta[source_offset]
	var second := delta[source_offset + 1]
	for index in range(repeat_count):
		indices[destination_offset + index * 2] = first
		indices[destination_offset + index * 2 + 1] = second
	return true


func _fail(message: String) -> bool:
	error_message = message
	return false
