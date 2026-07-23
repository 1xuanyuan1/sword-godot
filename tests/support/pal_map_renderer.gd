# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal `PAL_MapBlitToSurface` 的测试用 CPU 索引画布实现。
## 只供合成与本地像素对照，不属于正式游戏或资源导入能力。
class_name PalMapRenderer
extends RefCounted


## 把指定 PAL 世界视口的底层和可选上层合成为索引图像。
## 地图或 GOP Sprite 无效时返回带错误信息的图像。
static func render(map_data: PalMapData, tile_sprite: PalSprite, viewport: Rect2i, include_top_layer: bool = true) -> PalIndexedImage:
	var canvas := PalIndexedImage.new()
	canvas.width = viewport.size.x
	canvas.height = viewport.size.y
	if not map_data.is_valid():
		canvas.error_message = map_data.error_message
		return canvas
	if not tile_sprite.is_valid():
		canvas.error_message = tile_sprite.error_message
		return canvas
	if canvas.width <= 0 or canvas.height <= 0:
		canvas.error_message = "地图视口尺寸无效"
		return canvas
	canvas.indices.resize(canvas.width * canvas.height)
	canvas.indices.fill(0)
	canvas.opacity.resize(canvas.indices.size())
	canvas.opacity.fill(255)
	_draw_layer(canvas, map_data, tile_sprite, viewport, 0)
	if include_top_layer:
		_draw_layer(canvas, map_data, tile_sprite, viewport, 1)
	return canvas


static func _draw_layer(canvas: PalIndexedImage, map_data: PalMapData, tile_sprite: PalSprite, viewport: Rect2i, layer: int) -> void:
	var source_start_y := floori(viewport.position.y / 16.0) - 1
	var source_end_y := floori((viewport.position.y + viewport.size.y) / 16.0) + 2
	var source_start_x := floori(viewport.position.x / 32.0) - 1
	var source_end_x := floori((viewport.position.x + viewport.size.x) / 32.0) + 2
	var screen_y := source_start_y * 16 - 8 - viewport.position.y

	for map_y in range(source_start_y, source_end_y):
		for half in range(2):
			var screen_x := source_start_x * 32 + half * 16 - 16 - viewport.position.x
			for map_x in range(source_start_x, source_end_x):
				var frame_index := -1
				if map_x >= 0 and map_x < PalMapData.WIDTH and map_y >= 0 and map_y < PalMapData.HEIGHT:
					var tile := map_data.tile_value(map_x, map_y, half)
					frame_index = PalMapData.bottom_sprite_index(tile) if layer == 0 else PalMapData.top_sprite_index(tile)
				elif layer == 0:
					frame_index = PalMapData.bottom_sprite_index(map_data.tile_value(0, 0, 0))
				# SDLPal 对缺失底层帧回退到 (0,0,0)，缺失上层帧则保持透明。
				if layer == 0 and (frame_index < 0 or frame_index >= tile_sprite.frame_count()):
					frame_index = PalMapData.bottom_sprite_index(map_data.tile_value(0, 0, 0))
				if frame_index >= 0 and frame_index < tile_sprite.frame_count():
					var tile_image := RleDecoder.decode(tile_sprite.get_frame(frame_index))
					if tile_image.is_valid():
						_blit(tile_image, canvas, screen_x, screen_y)
				screen_x += 32
			screen_y += 8


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
