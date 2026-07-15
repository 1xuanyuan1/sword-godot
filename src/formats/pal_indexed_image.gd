# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 图像的中间表示：每像素保存 8 位调色板索引和独立透明度。
## 该类型避免在格式解析阶段丢失日夜调色板和透明像素语义。
class_name PalIndexedImage
extends RefCounted

## 图像宽度。
var width: int = 0
## 图像高度。
var height: int = 0
## 每像素的 PAL 调色板索引。
var indices: PackedByteArray = PackedByteArray()
## 每像素透明度，通常为 0 或 255。
var opacity: PackedByteArray = PackedByteArray()
## 解码失败原因。
var error_message: String = ""


## 判断尺寸、索引和透明度数组是否一致且没有错误。
func is_valid() -> bool:
	return error_message.is_empty() and width > 0 and height > 0 and indices.size() == width * height and opacity.size() == indices.size()


## 生成 RG8 Godot 图像：R 为颜色索引，G 为透明度，供调色板 Shader 使用。
func to_index_alpha_image() -> Image:
	if not is_valid():
		return Image.create_empty(1, 1, false, Image.FORMAT_RG8)
	var encoded := PackedByteArray()
	encoded.resize(indices.size() * 2)
	for index in range(indices.size()):
		encoded[index * 2] = indices[index]
		encoded[index * 2 + 1] = opacity[index]
	return Image.create_from_data(width, height, false, Image.FORMAT_RG8, encoded)


## 使用给定 256×RGB 调色板生成普通 RGBA8 图像；调色板不足时返回空图像。
func to_rgba_image(palette_rgb: PackedByteArray) -> Image:
	if not is_valid() or palette_rgb.size() < 256 * 3:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var rgba := PackedByteArray()
	rgba.resize(indices.size() * 4)
	for index in range(indices.size()):
		var color_index := indices[index] * 3
		var pixel_index := index * 4
		rgba[pixel_index] = palette_rgb[color_index]
		rgba[pixel_index + 1] = palette_rgb[color_index + 1]
		rgba[pixel_index + 2] = palette_rgb[color_index + 2]
		rgba[pixel_index + 3] = opacity[index]
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
