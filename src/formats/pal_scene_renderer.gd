# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal scene.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal `PAL_MakeScene` 的 CPU 参考渲染器，把地图、人物、事件和覆盖块合成。
## Godot 原生渲染必须与这里的基准 Y 和逻辑层公式保持像素一致。
class_name PalSceneRenderer
extends RefCounted


## CPU 队列中的一个基准 Y 绘制项。
class DrawItem:
	var frame: PalIndexedImage
	var x: int
	var baseline_y: int
	var logical_layer: int
	var insertion_order: int = 0

	func _init(source_frame: PalIndexedImage, source_x: int, source_baseline_y: int, source_layer: int) -> void:
		frame = source_frame
		x = source_x
		baseline_y = source_baseline_y
		logical_layer = source_layer


## 按 SDLPal 队伍锚点把一帧角色图像转换为 CPU 绘制项。
static func player_item(frame: PalIndexedImage, screen_position: Vector2i, world_layer: int = 0) -> DrawItem:
	return DrawItem.new(frame, screen_position.x - int(frame.width / 2.0), screen_position.y + world_layer + 10, world_layer + 6)


## 按 EVENTOBJECT 逻辑层把一帧事件图像转换为 CPU 绘制项。
static func event_item(frame: PalIndexedImage, screen_position: Vector2i, event_layer: int) -> DrawItem:
	return DrawItem.new(frame, screen_position.x - int(frame.width / 2.0), screen_position.y + event_layer * 8 + 9, event_layer * 8 + 2)


## 先绘制完整地图，再加入角色及可能盖住角色的地图块并按基准 Y 排序。
static func render(map_data: PalMapData, tile_sprite: PalSprite, viewport: Rect2i, scene_items: Array) -> PalIndexedImage:
	var canvas := PalMapRenderer.render(map_data, tile_sprite, viewport, true)
	if not canvas.is_valid():
		return canvas
	var draw_items: Array = []
	for item in scene_items:
		if item is DrawItem and item.frame != null and item.frame.is_valid():
			draw_items.append(item)
			_append_cover_tiles(draw_items, item, map_data, tile_sprite, viewport.position)
	for index in range(draw_items.size()):
		draw_items[index].insertion_order = index
	draw_items.sort_custom(func(left: DrawItem, right: DrawItem) -> bool:
		return left.baseline_y < right.baseline_y or (left.baseline_y == right.baseline_y and left.insertion_order < right.insertion_order)
	)
	for item: DrawItem in draw_items:
		_blit(item.frame, canvas, item.x, item.baseline_y - item.frame.height - item.logical_layer)
	return canvas


static func _append_cover_tiles(draw_items: Array, source_item: DrawItem, map_data: PalMapData, tile_sprite: PalSprite, viewport_position: Vector2i) -> void:
	var sprite_x := viewport_position.x + source_item.x - int(source_item.logical_layer / 2.0)
	var sprite_y := viewport_position.y + source_item.baseline_y - source_item.logical_layer
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


static func _blit(source: PalIndexedImage, destination: PalIndexedImage, x_offset: int, y_offset: int) -> void:
	for source_y in range(source.height):
		var destination_y := y_offset + source_y
		if destination_y < 0 or destination_y >= destination.height:
			continue
		for source_x in range(source.width):
			var destination_x := x_offset + source_x
			if destination_x < 0 or destination_x >= destination.width:
				continue
			var source_index := source_y * source.width + source_x
			if source.opacity[source_index] == 0:
				continue
			var destination_index := destination_y * destination.width + destination_x
			destination.indices[destination_index] = source.indices[source_index]
			destination.opacity[destination_index] = source.opacity[source_index]


static func _trunc_div(numerator: int, denominator: int) -> int:
	return int(numerator / float(denominator))
