# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal scene.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 地图人物、事件和特殊覆盖块共用的场景布局规则。
## 正式 TileMap 世界与测试用 CPU 像素基准都依赖这里的基准 Y、逻辑层和覆盖候选。
class_name PalSceneLayout
extends RefCounted

const DRAW_KIND_SCENE := 0
const DRAW_KIND_COLLECTIBLE_MARKER := 1


## 场景中的一个基准 Y 绘制项；渲染后端决定把它变成 Sprite2D 还是写入 CPU 画布。
class DrawItem:
	var frame: PalIndexedImage
	var x: int
	var baseline_y: int
	var logical_layer: int
	var insertion_order: int = 0
	var draw_offset_y: int = 0
	var draw_kind: int = DRAW_KIND_SCENE
	var source_object_id: int = 0

	func _init(source_frame: PalIndexedImage, source_x: int, source_baseline_y: int, source_layer: int, source_draw_offset_y: int = 0, source_draw_kind: int = DRAW_KIND_SCENE, source_id: int = 0) -> void:
		frame = source_frame
		x = source_x
		baseline_y = source_baseline_y
		logical_layer = source_layer
		draw_offset_y = source_draw_offset_y
		draw_kind = source_draw_kind
		source_object_id = source_id


## 按 SDLPal 队伍锚点把一帧角色图像转换为布局项。
static func player_item(frame: PalIndexedImage, screen_position: Vector2i, world_layer: int = 0) -> DrawItem:
	return DrawItem.new(frame, screen_position.x - int(frame.width / 2.0), screen_position.y + world_layer + 10, world_layer + 6)


## 0098 跟随者使用 MGO 的三帧四方向布局；损坏或特殊 Sprite 会限制到现有帧内。
static func follower_frame_index(direction: int, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	return clampi(posmod(direction, 4) * 3, 0, frame_count - 1)


## 按 EVENTOBJECT 逻辑层把一帧事件图像转换为布局项。
static func event_item(frame: PalIndexedImage, screen_position: Vector2i, event_layer: int) -> DrawItem:
	return DrawItem.new(frame, screen_position.x - int(frame.width / 2.0), screen_position.y + event_layer * 8 + 9, event_layer * 8 + 2)


## 把独立星芒放到采集物顶部，同时沿用 EventObject 的基准 Y 和逻辑层参与遮挡。
## `source_height` 为零 Sprite 暗格使用的虚拟高度，不能影响原事件交互或阻挡。
static func collectible_marker_item(marker_frame: PalIndexedImage, screen_position: Vector2i, event_layer: int, source_height: int, event_object_id: int) -> DrawItem:
	return DrawItem.new(
		marker_frame,
		screen_position.x - int(marker_frame.width / 2.0),
		screen_position.y + event_layer * 8 + 9,
		event_layer * 8 + 2,
		-source_height - 2,
		DRAW_KIND_COLLECTIBLE_MARKER,
		event_object_id
	)


## 按 SDLPal 顺序展开人物及其候选覆盖块，但不排序也不绘制。
static func expanded_draw_items(map_data: PalMapData, tile_sprite: PalSprite, viewport_position: Vector2i, scene_items: Array) -> Array:
	var draw_items: Array = []
	for item in scene_items:
		if item is DrawItem and item.frame != null and item.frame.is_valid():
			draw_items.append(item)
			_append_cover_tiles(draw_items, item, map_data, tile_sprite, viewport_position)
	return draw_items


static func _append_cover_tiles(draw_items: Array, source_item: DrawItem, map_data: PalMapData, tile_sprite: PalSprite, viewport_position: Vector2i) -> void:
	var sprite_x := viewport_position.x + source_item.x - int(source_item.logical_layer / 2.0)
	var sprite_y := viewport_position.y + source_item.baseline_y - source_item.logical_layer + source_item.draw_offset_y
	var half := 1 if posmod(sprite_x, 32) != 0 else 0
	var width := source_item.frame.width
	var height := source_item.frame.height
	var half_width := int(width / 2.0)
	var first_map_y := _trunc_div(sprite_y - height - 15, 16)
	var last_map_y := _trunc_div(sprite_y, 16)
	var first_map_x := _trunc_div(sprite_x - half_width, 32)
	var last_map_x := _trunc_div(sprite_x + half_width, 32)
	var tile_x := 0
	var tile_y := 0
	var tile_half := 0
	for map_y in range(first_map_y, last_map_y + 1):
		for map_x in range(first_map_x, last_map_x + 1):
			var first_pattern := 0 if map_x == first_map_x else 3
			for pattern in range(first_pattern, 5):
				match pattern:
					0:
						tile_x = map_x
						tile_y = map_y
						tile_half = half
					1:
						tile_x = map_x - 1
					2:
						tile_x = map_x if half != 0 else map_x - 1
						tile_y = map_y + 1 if half != 0 else map_y
						tile_half = 1 - half
					3:
						tile_x = map_x + 1
						tile_y = map_y
						tile_half = half
					4:
						tile_x = map_x + 1 if half != 0 else map_x
						tile_y = map_y + 1 if half != 0 else map_y
						tile_half = 1 - half
				for layer in range(2):
					if tile_x < 0 or tile_x >= PalMapData.WIDTH or tile_y < 0 or tile_y >= PalMapData.HEIGHT:
						continue
					var tile_value := map_data.tile_value(tile_x, tile_y, tile_half)
					var frame_index := PalMapData.bottom_sprite_index(tile_value) if layer == 0 else PalMapData.top_sprite_index(tile_value)
					var tile_height := PalMapData.tile_height(tile_value, layer == 1)
					if frame_index < 0 or frame_index >= tile_sprite.frame_count() or tile_height <= 0:
						continue
					if (tile_y + tile_height) * 16 + tile_half * 8 < sprite_y:
						continue
					var tile_frame := RleDecoder.decode(tile_sprite.get_frame(frame_index))
					if not tile_frame.is_valid():
						continue
					draw_items.append(DrawItem.new(
						tile_frame,
						tile_x * 32 + tile_half * 16 - 16 - viewport_position.x,
						tile_y * 16 + tile_half * 8 + 7 + layer + tile_height * 8 - viewport_position.y,
						tile_height * 8 + layer
					))


static func _trunc_div(numerator: int, denominator: int) -> int:
	return int(numerator / float(denominator))
