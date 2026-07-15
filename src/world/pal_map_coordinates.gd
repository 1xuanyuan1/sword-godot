# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal scene.c PAL_CheckObstacleWithRange.
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 世界像素、菱形地图区域和 `(tile_x, tile_y, half)` 之间的碰撞坐标换算。
## 本模块只计算坐标和玩家活动边界，不读取地图数据或修改运行时状态。
class_name PalMapCoordinates
extends RefCounted

const PLAYER_MIN_COARSE_TILE := Vector2i(5, 7)


## 将任意 PAL 世界像素位置映射到碰撞所属的地图 half，以 `Vector3i(x,y,half)` 返回。
## 位置可以不在 half 格中心；菱形四区边界严格沿用 `PAL_CheckObstacleWithRange`。
static func world_to_tile(world_position: Vector2i) -> Vector3i:
	var tile_x := floori(world_position.x / 32.0)
	var tile_y := floori(world_position.y / 16.0)
	var half := 0
	var remainder_x := posmod(world_position.x, 32)
	var remainder_y := posmod(world_position.y, 16)
	var diagonal := remainder_x + remainder_y * 2
	if diagonal >= 16:
		if diagonal >= 48:
			tile_x += 1
			tile_y += 1
		elif 32 - remainder_x + remainder_y * 2 < 16:
			tile_x += 1
		elif 32 - remainder_x + remainder_y * 2 < 48:
			half = 1
		else:
			tile_y += 1
	return Vector3i(tile_x, tile_y, half)


## 返回地图 half 是否位于 PAL 固定的 64×128×2 数据范围内。
static func is_valid_tile(tile: Vector3i) -> bool:
	return tile.x >= 0 and tile.x < PalMapData.WIDTH and tile.y >= 0 and tile.y < PalMapData.HEIGHT and tile.z >= 0 and tile.z < PalMapData.HALVES


## 返回位置是否满足玩家主动移动的地图边界；脚本和 NPC 路径不使用左上视口限制。
## 最小粗格 `(5,7)` 来自 320×200 视口内固定队伍偏移 `(160,112)`。
static func is_within_player_walk_range(world_position: Vector2i) -> bool:
	var coarse_x := floori(world_position.x / 32.0)
	var coarse_y := floori(world_position.y / 16.0)
	if coarse_x < PLAYER_MIN_COARSE_TILE.x or coarse_y < PLAYER_MIN_COARSE_TILE.y:
		return false
	return is_valid_tile(world_to_tile(world_position))
