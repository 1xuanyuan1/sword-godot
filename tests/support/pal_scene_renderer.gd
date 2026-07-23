# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal scene.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal `PAL_MakeScene` 的测试用 CPU 参考渲染器。
## 像素对照通过 `PalSceneLayout` 复用正式 TileMap 世界的布局规则。
class_name PalSceneRenderer
extends RefCounted


## 先绘制完整地图，再加入角色及可能盖住角色的地图块并按基准 Y 排序。
static func render(map_data: PalMapData, tile_sprite: PalSprite, viewport: Rect2i, scene_items: Array) -> PalIndexedImage:
	var canvas := PalMapRenderer.render(map_data, tile_sprite, viewport, true)
	if not canvas.is_valid():
		return canvas
	var draw_items := PalSceneLayout.expanded_draw_items(map_data, tile_sprite, viewport.position, scene_items)
	for index in range(draw_items.size()):
		draw_items[index].insertion_order = index
	draw_items.sort_custom(func(left: PalSceneLayout.DrawItem, right: PalSceneLayout.DrawItem) -> bool:
		return left.baseline_y < right.baseline_y or (left.baseline_y == right.baseline_y and left.insertion_order < right.insertion_order)
	)
	for item: PalSceneLayout.DrawItem in draw_items:
		_blit(item.frame, canvas, item.x, item.baseline_y - item.frame.height - item.logical_layer + item.draw_offset_y)
	return canvas


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
