# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c/map.h.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalMapData
extends RefCounted

const WIDTH := 64
const HEIGHT := 128
const HALVES := 2
const BYTE_SIZE := WIDTH * HEIGHT * HALVES * 4

var tiles: PackedInt64Array = PackedInt64Array()
var error_message: String = ""


static func from_bytes(data: PackedByteArray) -> PalMapData:
	var map := PalMapData.new()
	if data.size() != BYTE_SIZE:
		map.error_message = "地图数据应为 %d 字节，实际为 %d" % [BYTE_SIZE, data.size()]
		return map
	map.tiles.resize(WIDTH * HEIGHT * HALVES)
	for index in range(map.tiles.size()):
		map.tiles[index] = PalBinary.u32_le(data, index * 4)
	return map


func is_valid() -> bool:
	return error_message.is_empty() and tiles.size() == WIDTH * HEIGHT * HALVES


func tile_value(x: int, y: int, half: int) -> int:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT or half < 0 or half >= HALVES:
		return 0
	# SDLPal lays the packed C array out as Tiles[y][x][half].
	return tiles[(y * WIDTH + x) * HALVES + half]


static func bottom_sprite_index(value: int) -> int:
	return (value & 0xff) | ((value >> 4) & 0x100)


static func top_sprite_index(value: int) -> int:
	var upper := value >> 16
	return ((upper & 0xff) | ((upper >> 4) & 0x100)) - 1


static func is_blocked(value: int) -> bool:
	return (value & 0x2000) != 0


static func tile_height(value: int, top_layer: bool = false) -> int:
	var packed := value >> 16 if top_layer else value
	return (packed >> 8) & 0x0f

