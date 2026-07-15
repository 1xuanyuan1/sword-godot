# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal palette.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PaletteDecoder
extends RefCounted

const COLOR_COUNT := 256
const PALETTE_BYTES := COLOR_COUNT * 3


static func decode_rgb(chunk: PackedByteArray, night: bool = false) -> PackedByteArray:
	if chunk.size() < PALETTE_BYTES:
		return PackedByteArray()
	var source_offset := PALETTE_BYTES if night and chunk.size() >= PALETTE_BYTES * 2 else 0
	var result := PackedByteArray()
	result.resize(PALETTE_BYTES)
	for index in range(PALETTE_BYTES):
		result[index] = mini(255, chunk[source_offset + index] << 2)
	return result


static func to_strip_image(palette_rgb: PackedByteArray, swatch_size: int = 8) -> Image:
	if palette_rgb.size() < PALETTE_BYTES:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	var width := 16 * swatch_size
	var height := 16 * swatch_size
	var pixels := PackedByteArray()
	pixels.resize(width * height * 3)
	for color_index in range(COLOR_COUNT):
		var cell_x := (color_index % 16) * swatch_size
		var cell_y := (color_index / 16) * swatch_size
		for y in range(swatch_size):
			for x in range(swatch_size):
				var destination := ((cell_y + y) * width + cell_x + x) * 3
				pixels[destination] = palette_rgb[color_index * 3]
				pixels[destination + 1] = palette_rgb[color_index * 3 + 1]
				pixels[destination + 2] = palette_rgb[color_index * 3 + 2]
	return Image.create_from_data(width, height, false, Image.FORMAT_RGB8, pixels)

