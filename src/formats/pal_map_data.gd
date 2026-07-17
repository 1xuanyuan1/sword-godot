# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c/map.h.
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 固定 64×128、每格两个 half 的地图数据和位字段解码器。
## 每个 half 使用 32 位记录，同时保存底/上层 Sprite、阻挡标志和逻辑高度。
class_name PalMapData
extends RefCounted

const WIDTH := 64
const HEIGHT := 128
const HALVES := 2
const BYTE_SIZE := WIDTH * HEIGHT * HALVES * 4

## 按 `Tiles[y][x][half]` 顺序保存的无符号 32 位记录。
var tiles: PackedInt64Array = PackedInt64Array()
## 长度或结构校验失败原因。
var error_message: String = ""


## 解析完整解压地图；字节数不是 `BYTE_SIZE` 时返回无效对象。
static func from_bytes(data: PackedByteArray) -> PalMapData:
	var map := PalMapData.new()
	if data.size() != BYTE_SIZE:
		map.error_message = "地图数据应为 %d 字节，实际为 %d" % [BYTE_SIZE, data.size()]
		return map
	map.tiles.resize(WIDTH * HEIGHT * HALVES)
	for index in range(map.tiles.size()):
		map.tiles[index] = PalBinary.u32_le(data, index * 4)
	return map


## 返回地图是否包含全部 64×128×2 条记录。
func is_valid() -> bool:
	return error_message.is_empty() and tiles.size() == WIDTH * HEIGHT * HALVES


## 读取一个 half 的原始 32 位值；坐标越界时返回 0。
func tile_value(x: int, y: int, half: int) -> int:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT or half < 0 or half >= HALVES:
		return 0
	# SDLPal lays the packed C array out as Tiles[y][x][half].
	return tiles[(y * WIDTH + x) * HALVES + half]


## 从低 16 位提取 9 位底层 GOP Sprite 编号。
static func bottom_sprite_index(value: int) -> int:
	return (value & 0xff) | ((value >> 4) & 0x100)


## 从高 16 位提取上层 GOP Sprite 编号；原版零值表示空图块并返回 -1。
static func top_sprite_index(value: int) -> int:
	var upper := value >> 16
	return ((upper & 0xff) | ((upper >> 4) & 0x100)) - 1


## 返回低 16 位的移动阻挡标志。
static func is_blocked(value: int) -> bool:
	return (value & 0x2000) != 0


## 提取底层或上层 4 位逻辑高度，用于 SDLPal 覆盖块排序。
static func tile_height(value: int, top_layer: bool = false) -> int:
	var packed := value >> 16 if top_layer else value
	return (packed >> 8) & 0x0f
