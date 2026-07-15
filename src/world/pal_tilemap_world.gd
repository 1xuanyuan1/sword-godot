# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c, scene.c and play.c rendering behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
## Godot 原生 PAL 世界渲染器：TileMapLayer 绘制地图，Sprite2D 绘制人物和特殊覆盖块。
## 世界位置、步态和覆盖候选仍以 SDLPal 为准；剧情与事件触发由 `MapExplorer` 负责。
class_name PalTileMapWorld
extends Node2D

const PALETTE_SHADER: Shader = preload("res://shaders/indexed_palette.gdshader")
const VIEWPORT_SIZE := Vector2i(320, 200)

## 最近一次地图资源、节点结构或调色板同步失败原因。
var error_message: String = ""
## 当前成功载入的 PAL 地图编号，-1 表示尚未载入。
var loaded_map_number: int = -1

var _database: PalContentDatabase
var _map_data: PalMapData
var _tile_sprite: PalSprite
var _map_instance: Node2D
var _static_bottom: TileMapLayer
var _static_top: TileMapLayer
var _sort_root: Node2D
var _camera: Camera2D
var _palette_material: ShaderMaterial
var _palette_key: String = ""
var _texture_cache: Dictionary = {}
var _player_sprites: Dictionary = {}
var _event_sprites: Dictionary = {}
var _walk_phase: int = 0
var _showing_walk_frame: bool = false
var _reported_block_mismatches: Dictionary = {}


## 载入指定 `map_number` 的原始 MAP/GOP 和生成的 TileMapLayer PackedScene。
## 成功时替换旧地图并返回 `true`；失败时保持错误说明供探索场景展示。
func load_map(database: PalContentDatabase, map_number: int) -> bool:
	_ensure_runtime_nodes()
	error_message = ""
	_database = database
	_map_data = database.load_map(map_number)
	_tile_sprite = database.load_map_tiles(map_number)
	if _map_data == null or not _map_data.is_valid() or _tile_sprite == null or not _tile_sprite.is_valid():
		error_message = "地图 %d 原始 MAP/GOP 无效：%s %s" % [map_number, _map_data.error_message if _map_data != null else "MAP 缺失", _tile_sprite.error_message if _tile_sprite != null else "GOP 缺失"]
		return false
	var packed := database.load_tilemap_scene(map_number)
	if packed == null:
		error_message = database.error_message
		return false
	var instance := packed.instantiate() as Node2D
	if instance == null:
		error_message = "地图 %d TileMapLayer 场景无法实例化" % map_number
		return false
	var bottom := instance.get_node_or_null("StaticBottom") as TileMapLayer
	var top := instance.get_node_or_null("StaticTop") as TileMapLayer
	if bottom == null or top == null:
		instance.free()
		error_message = "地图 %d TileMapLayer 场景缺少 StaticBottom/StaticTop" % map_number
		return false

	if _map_instance != null:
		_map_instance.free()
	_map_instance = instance
	_static_bottom = bottom
	_static_top = top
	for cover_name in ["CoverBottom", "CoverTop"]:
		var cover := _map_instance.get_node_or_null(cover_name) as TileMapLayer
		if cover != null:
			# 当前启用逐像素兼容 Sprite 覆盖层；节点保留给后续纯 TileMap Y 排序对照。
			cover.hide()
	_static_bottom.material = _palette_material
	_static_top.material = _palette_material
	add_child(_map_instance)
	move_child(_map_instance, 0)
	loaded_map_number = map_number
	_event_sprites.clear()
	_reported_block_mismatches.clear()
	_clear_sort_items()
	return true


## 设置队伍普通步态的当前相位；`moving` 为假时显示站立或脚本动作帧。
func set_walk_animation(walk_phase: int, moving: bool) -> void:
	_walk_phase = posmod(walk_phase, 4)
	_showing_walk_frame = moving


## 根据会话和当前场景事件同步相机、调色板、队伍、NPC 与覆盖块。
## 只修改渲染节点，不修改 `GameSession` 或事件对象。
func sync_world(session: GameSession, events: Array[PalEventObject]) -> bool:
	if loaded_map_number < 0 or _map_instance == null or _database == null:
		error_message = "TileMap 世界尚未载入地图"
		return false
	if not _update_palette(session.palette_index, session.night_palette):
		return false
	_camera.position = Vector2(session.viewport_position) + Vector2(VIEWPORT_SIZE) / 2.0
	_clear_sort_items()
	var scene_items := _build_scene_items(session, events)
	var expanded := PalSceneRenderer.expanded_draw_items(_map_data, _tile_sprite, session.viewport_position, scene_items)
	for item in expanded:
		_add_draw_item(item, session.viewport_position)
	return true


## 查询一个 PAL 世界位置是否被地图 TileSet 的 `pal_blocked` 自定义数据阻挡。
## 坐标越界或缺失 TileData 时视为阻挡；迁移期会与原始 MAP 位进行一致性检查。
func is_map_blocked(world_position: Vector2i) -> bool:
	if _static_bottom == null or _map_data == null:
		return true
	var half := 0 if posmod(world_position.x, 32) == 0 else 1
	var map_x := floori(world_position.x / 32.0)
	var map_y := floori(world_position.y / 16.0)
	if map_x < 0 or map_x >= PalMapData.WIDTH or map_y < 0 or map_y >= PalMapData.HEIGHT:
		return true
	var cell := PalTileSetBuilder.pal_half_to_map_cell(map_x, map_y, half)
	var tile_data := _static_bottom.get_cell_tile_data(cell)
	if tile_data == null:
		return true
	var tilemap_blocked := bool(tile_data.get_custom_data("pal_blocked"))
	var raw_blocked := PalMapData.is_blocked(_map_data.tile_value(map_x, map_y, half))
	if tilemap_blocked != raw_blocked and not _reported_block_mismatches.has(cell):
		_reported_block_mismatches[cell] = true
		push_warning("TileSet 阻挡与 MAP 不一致：地图 %d，cell %s" % [loaded_map_number, cell])
	return tilemap_blocked


## 清空角色 Sprite 缓存；PLAYERROLES 场景 Sprite 被脚本修改后必须调用。
func reset_sprite_cache() -> void:
	_player_sprites.clear()
	_event_sprites.clear()
	_texture_cache.clear()


func _ensure_runtime_nodes() -> void:
	if _palette_material == null:
		_palette_material = ShaderMaterial.new()
		_palette_material.shader = PALETTE_SHADER
		_palette_material.set_shader_parameter("palette_mix", 1.0)
		_palette_material.set_shader_parameter("global_alpha", 1.0)
	if _sort_root == null:
		_sort_root = Node2D.new()
		_sort_root.name = "YSortRoot"
		_sort_root.y_sort_enabled = true
		_sort_root.z_index = 2
		add_child(_sort_root)
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "PalCamera"
		_camera.position_smoothing_enabled = false
		_camera.enabled = true
		add_child(_camera)


func _update_palette(index: int, night: bool) -> bool:
	var key := "%d:%d" % [index, 1 if night else 0]
	if key == _palette_key:
		return true
	var palette := _database.load_palette(index, night)
	if palette.size() < PaletteDecoder.PALETTE_BYTES:
		error_message = "调色板 %d %s 缺失或长度不足" % [index, "night" if night else "day"]
		return false
	var image := Image.create_from_data(256, 1, false, Image.FORMAT_RGB8, palette)
	var texture := ImageTexture.create_from_image(image)
	_palette_material.set_shader_parameter("palette_texture", texture)
	_palette_key = key
	return true


func _build_scene_items(session: GameSession, events: Array[PalEventObject]) -> Array:
	var result: Array = []
	for party_index in range(mini(session.party_roles.size(), 3)):
		var role_index := session.party_roles[party_index]
		var sprite := _player_sprite_for_role(role_index)
		var frame := _party_frame(sprite, role_index, party_index, session)
		if not frame.is_valid():
			continue
		var world_position := session.party_member_world_position(party_index)
		if party_index > 0 and _is_blocked_with_events(world_position, events):
			world_position = session.trail_positions[1]
		result.append(PalSceneRenderer.player_item(frame, world_position - session.viewport_position, session.world_layer))

	for event in events:
		if not event.is_visible() or event.sprite_number <= 0:
			continue
		var sprite := _event_sprite(event.sprite_number)
		if not sprite.is_valid():
			continue
		var frame_index := event.current_frame
		if event.sprite_frames == 3:
			if frame_index == 2:
				frame_index = 0
			elif frame_index == 3:
				frame_index = 2
		frame_index += event.direction * event.sprite_frames
		var frame := _decode_frame(sprite, frame_index)
		if not frame.is_valid():
			continue
		var screen_position := event.position - session.viewport_position
		if screen_position.x < -frame.width or screen_position.x > VIEWPORT_SIZE.x + frame.width or screen_position.y < -frame.height or screen_position.y > VIEWPORT_SIZE.y + frame.height:
			continue
		result.append(PalSceneRenderer.event_item(frame, screen_position, event.layer))
	return result


func _party_frame(sprite: PalSprite, role_index: int, party_index: int, session: GameSession) -> PalIndexedImage:
	if sprite == null or not sprite.is_valid():
		return PalIndexedImage.new()
	var scripted_frame := session.scripted_party_frame(party_index)
	if scripted_frame >= 0 and not _showing_walk_frame:
		return _decode_frame(sprite, scripted_frame)
	var walk_frames := _database.player_roles.walk_frame_count_for(role_index)
	var direction := session.party_member_direction(party_index)
	var frame_index := direction * walk_frames
	if _showing_walk_frame:
		if walk_frames == 4:
			frame_index += _walk_phase
		elif (_walk_phase & 1) != 0:
			# SDLPal 三帧人物使用 0→1→0→2，而不是简单的 0→1→2 循环。
			frame_index += int((_walk_phase + 1) / 2.0)
	return _decode_frame(sprite, frame_index)


func _player_sprite_for_role(role_index: int) -> PalSprite:
	if _player_sprites.has(role_index):
		return _player_sprites[role_index]
	var sprite := _database.load_mgo_sprite(_database.player_roles.scene_sprite_for(role_index))
	_player_sprites[role_index] = sprite
	return sprite


func _event_sprite(sprite_number: int) -> PalSprite:
	if _event_sprites.has(sprite_number):
		return _event_sprites[sprite_number]
	var sprite := _database.load_mgo_sprite(sprite_number)
	_event_sprites[sprite_number] = sprite
	return sprite


func _decode_frame(sprite: PalSprite, frame_index: int) -> PalIndexedImage:
	if sprite == null or not sprite.is_valid() or frame_index < 0 or frame_index >= sprite.frame_count():
		return PalIndexedImage.new()
	return RleDecoder.decode(sprite.get_frame(frame_index))


func _is_blocked_with_events(world_position: Vector2i, events: Array[PalEventObject]) -> bool:
	if is_map_blocked(world_position):
		return true
	for event in events:
		if event.is_visible() and event.blocks_movement() and absi(event.position.x - world_position.x) + absi(event.position.y - world_position.y) * 2 <= 12:
			return true
	return false


func _add_draw_item(item: PalSceneRenderer.DrawItem, viewport_position: Vector2i) -> void:
	var texture := _texture_for_frame(item.frame)
	if texture == null:
		return
	var anchor := Node2D.new()
	anchor.position = Vector2(item.x + viewport_position.x, item.baseline_y + viewport_position.y)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = Vector2(0, -item.frame.height - item.logical_layer)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = _palette_material
	anchor.add_child(sprite)
	_sort_root.add_child(anchor)


func _texture_for_frame(frame: PalIndexedImage) -> Texture2D:
	if frame == null or not frame.is_valid():
		return null
	var key := "%d:%d:%d:%d" % [frame.width, frame.height, hash(frame.indices), hash(frame.opacity)]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var texture := ImageTexture.create_from_image(frame.to_index_alpha_image())
	_texture_cache[key] = texture
	return texture


func _clear_sort_items() -> void:
	if _sort_root == null:
		return
	for child in _sort_root.get_children():
		child.free()
