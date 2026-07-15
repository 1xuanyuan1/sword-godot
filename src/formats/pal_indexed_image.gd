# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalIndexedImage
extends RefCounted

var width: int = 0
var height: int = 0
var indices: PackedByteArray = PackedByteArray()
var opacity: PackedByteArray = PackedByteArray()
var error_message: String = ""


func is_valid() -> bool:
	return error_message.is_empty() and width > 0 and height > 0 and indices.size() == width * height and opacity.size() == indices.size()


func to_index_alpha_image() -> Image:
	if not is_valid():
		return Image.create_empty(1, 1, false, Image.FORMAT_RG8)
	var encoded := PackedByteArray()
	encoded.resize(indices.size() * 2)
	for index in range(indices.size()):
		encoded[index * 2] = indices[index]
		encoded[index * 2 + 1] = opacity[index]
	return Image.create_from_data(width, height, false, Image.FORMAT_RG8, encoded)


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

