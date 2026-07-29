# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 某一游戏帧提供给经典与高清 TileMap 配置的共享只读展示快照。
## 快照复制坐标、方向和帧编号，不持有 GameSession 或可变 EventObject。
class_name PalWorldPresentationSnapshot
extends RefCounted

## 当前从零开始的剧情场景索引。
var scene_index: int = -1
## 当前 PAL 地图编号。
var map_number: int = -1
## 当前调色板编号。
var palette_index: int = 0
## 当前是否处于夜间调色板状态。
var night_palette: bool = false
## 经典世界视口左上角坐标。
var viewport_position: Vector2i = Vector2i.ZERO
## 007F 剧情镜头的附加 PAL 像素偏移。
var camera_offset: Vector2i = Vector2i.ZERO
## 经典与高清 Camera2D 共用的 PAL 世界中心。
var camera_center_pal: Vector2i = Vector2i.ZERO
## 当前 TileMap 配置实际绘制的逻辑视野大小。
var logical_view_size: Vector2i = PalPresentationMetrics.CLASSIC_CONTENT_SIZE
## 当前逻辑视野左上角对应的 PAL 世界坐标；重制模式比经典 viewport 向左上扩展 (32,8)。
var render_viewport_position: Vector2i = Vector2i.ZERO
## 320×200 经典 UI/画面核心在当前逻辑视野中的偏移。
var classic_content_offset: Vector2i = Vector2i.ZERO
## 最多三名玩家队员。
var party: Array = []
## 0098 设置的最多两名跟随者。
var followers: Array = []
## 当前所有可见 EventObject，包括没有 Sprite 的交互物。
var events: Array = []


## 返回按队伍、跟随者、EventObject 顺序合并的临时数组。
func all_actors() -> Array:
	var result: Array = []
	result.append_array(party)
	result.append_array(followers)
	result.append_array(events)
	return result
