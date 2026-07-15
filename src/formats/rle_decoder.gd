# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal palcommon.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 解码 PAL RLE 索引图像，完整保留透明跨度和调色板索引。
## 格式错误不会抛异常，而是返回带 `error_message` 的 `PalIndexedImage`。
class_name RleDecoder
extends RefCounted


## 解码一帧直接 RLE 数据；支持原版可选的 `02 00 00 00` 前缀。
static func decode(data: PackedByteArray) -> PalIndexedImage:
	var result := PalIndexedImage.new()
	var offset := 0
	if data.size() >= 4 and data[0] == 0x02 and data[1] == 0 and data[2] == 0 and data[3] == 0:
		offset = 4
	if not PalBinary.can_read(data, offset, 4):
		result.error_message = "RLE 头不完整"
		return result

	result.width = PalBinary.u16_le(data, offset)
	result.height = PalBinary.u16_le(data, offset + 2)
	offset += 4
	if result.width <= 0 or result.height <= 0 or result.width > 4096 or result.height > 4096:
		result.error_message = "RLE 尺寸无效：%d×%d" % [result.width, result.height]
		return result

	var pixel_count := result.width * result.height
	result.indices.resize(pixel_count)
	result.indices.fill(0)
	result.opacity.resize(pixel_count)
	result.opacity.fill(0)
	var cursor := 0
	while cursor < pixel_count:
		if offset >= data.size():
			result.error_message = "RLE 像素流提前结束（%d/%d）" % [cursor, pixel_count]
			return result
		var control := data[offset]
		offset += 1
		if (control & 0x80) != 0 and control <= 0x80 + result.width:
			var skip_count := control - 0x80
			if skip_count <= 0 or cursor + skip_count > pixel_count:
				result.error_message = "RLE 透明跨度越界"
				return result
			cursor += skip_count
		else:
			var literal_count := control
			if literal_count <= 0 or not PalBinary.can_read(data, offset, literal_count) or cursor + literal_count > pixel_count:
				result.error_message = "RLE 实像素跨度越界"
				return result
			for index in range(literal_count):
				result.indices[cursor + index] = data[offset + index]
				result.opacity[cursor + index] = 255
			offset += literal_count
			cursor += literal_count
	return result
