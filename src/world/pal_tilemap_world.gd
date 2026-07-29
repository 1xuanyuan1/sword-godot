# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c, scene.c and play.c rendering behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
## Godot 原生 PAL 世界渲染器：TileMapLayer 绘制地图，Sprite2D 绘制人物和特殊覆盖块。
## 世界位置、步态和覆盖候选仍以 SDLPal 为准；剧情与事件触发由 `MapExplorer` 负责。
class_name PalTileMapWorld
extends Node2D

const PALETTE_SHADER: Shader = preload("res://shaders/indexed_palette.gdshader")
const SCREEN_WAVE_SHADER: Shader = preload("res://shaders/pal_screen_wave_overlay.gdshader")
const COLLECTIBLE_MARKER_SHADER: Shader = preload("res://shaders/collectible_marker.gdshader")
const CollectibleClassifier := preload("res://src/game/pal_collectible_classifier.gd")
const PresentationMetrics := preload("res://src/presentation/pal_presentation_metrics.gd")
const PresentationBuilder := preload("res://src/presentation/pal_world_presentation_builder.gd")
const RemasterMapTileset := preload("res://src/presentation/pal_remaster_map_tileset.gd")
const RemasterSpriteAtlas := preload("res://src/presentation/pal_remaster_sprite_atlas.gd")
const COLLECTIBLE_MARKER_SIZE := 9
const SPRITELESS_COLLECTIBLE_HEIGHT := 10

const PRESENTATION_CLASSIC := 0
const PRESENTATION_REMASTER_2D := 1

## TileMap 正式路径完成一帧同步后发出经典与高清 2D 共用的展示快照。
signal presentation_snapshot_ready(snapshot: PalWorldPresentationSnapshot)

## 最近一次地图资源、节点结构或调色板同步失败原因。
var error_message: String = ""
## 当前成功载入的 PAL 地图编号，-1 表示尚未载入。
var loaded_map_number: int = -1
## 最近一次成功同步并已由 TileMap 正式路径消费的共享快照。
var latest_snapshot: PalWorldPresentationSnapshot

var _database: PalContentDatabase
var _map_data: PalMapData
var _tile_sprite: PalSprite
var _map_instance: Node2D
var _static_bottom: TileMapLayer
var _static_top: TileMapLayer
var _cover_bottom: TileMapLayer
var _cover_top: TileMapLayer
var _sort_root: Node2D
var _camera: Camera2D
var _effect_root: Node2D
var _wave_overlay: ColorRect
var _wave_material: ShaderMaterial
var _palette_material: ShaderMaterial
var _collectible_marker_material: ShaderMaterial
var _collectible_marker_frame: PalIndexedImage
var _collectible_classifier := CollectibleClassifier.new()
var _collectible_markers_enabled: bool = true
var _palette_key: String = ""
var _texture_cache: Dictionary = {}
var _event_sprites: Dictionary = {}
var _walk_phase: int = 0
var _showing_walk_frame: bool = false
var _reported_block_mismatches: Dictionary = {}
var _wave_amplitude: int = 0
var _wave_progression: int = 0
var _wave_phase: float = 0.0
var _wave_frame_accumulator: float = 0.0
var _presentation_mode: int = PRESENTATION_CLASSIC
var _logical_view_size: Vector2i = PresentationMetrics.CLASSIC_CONTENT_SIZE
var _classic_content_offset: Vector2i = Vector2i.ZERO
var _classic_tile_set: TileSet
var _remaster_resolver: PalRemasterAssetResolver
var _remaster_resolver_loaded: bool = false
var _remaster_map_tileset: RefCounted
var _remaster_map_active: bool = false
var _remaster_actor_atlases: Dictionary = {}


## 切换经典 320×200 或重制 384×216 视野；世界坐标、相机中心和选帧规则保持不变。
func set_presentation_mode(mode: int) -> void:
	_presentation_mode = PRESENTATION_REMASTER_2D if mode == PRESENTATION_REMASTER_2D else PRESENTATION_CLASSIC
	var remaster_enabled := _presentation_mode == PRESENTATION_REMASTER_2D
	_logical_view_size = PresentationMetrics.logical_size(remaster_enabled)
	_classic_content_offset = PresentationMetrics.REMASTER_CLASSIC_OFFSET if remaster_enabled else Vector2i.ZERO
	if _wave_overlay != null:
		_wave_overlay.size = Vector2(_logical_view_size)
	if loaded_map_number >= 0:
		_apply_map_presentation()


## 返回正式 TileMap 世界当前使用的经典或高清 2D 展示配置。
func presentation_mode() -> int:
	return _presentation_mode


## 返回当前 TileMap Camera2D 的 PAL 逻辑视野尺寸。
func logical_view_size() -> Vector2i:
	return _logical_view_size


## 返回 320×200 经典核心在当前逻辑视野中的左上偏移。
func classic_content_offset() -> Vector2i:
	return _classic_content_offset


## 返回当前地图是否已通过完整校验并启用私有高清 TileSet。
func remaster_map_active() -> bool:
	return _remaster_map_active


## 测试、MOD 预览或宿主可注入已配置解析器；正式运行默认按固定目录自动加载。
func set_remaster_asset_resolver(resolver: PalRemasterAssetResolver) -> void:
	_remaster_resolver = resolver
	_remaster_resolver_loaded = resolver != null
	_remaster_actor_atlases.clear()
	if loaded_map_number >= 0:
		_apply_map_presentation()


## 载入指定 `map_number` 的原始 MAP/GOP 和生成的 TileMapLayer PackedScene。
## 成功时替换旧地图并返回 `true`；失败时保持错误说明供探索场景展示。
func load_map(database: PalContentDatabase, map_number: int) -> bool:
	_ensure_runtime_nodes()
	error_message = ""
	_database = database
	_collectible_classifier.configure(database)
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
	_cover_bottom = _map_instance.get_node_or_null("CoverBottom") as TileMapLayer
	_cover_top = _map_instance.get_node_or_null("CoverTop") as TileMapLayer
	for cover in [_cover_bottom, _cover_top]:
		if cover != null:
			# 当前启用逐像素兼容 Sprite 覆盖层；节点保留给后续纯 TileMap Y 排序对照。
			cover.hide()
	_classic_tile_set = _static_bottom.tile_set
	_static_bottom.material = _palette_material
	_static_top.material = _palette_material
	_effect_root.add_child(_map_instance)
	_effect_root.move_child(_map_instance, 0)
	loaded_map_number = map_number
	latest_snapshot = null
	_event_sprites.clear()
	_reported_block_mismatches.clear()
	_clear_sort_items()
	_apply_map_presentation()
	return true


## 设置队伍普通步态的当前相位；`moving` 为假时显示站立或脚本动作帧。
func set_walk_animation(walk_phase: int, moving: bool) -> void:
	_walk_phase = posmod(walk_phase, 4)
	_showing_walk_frame = moving


## 根据会话和当前场景事件同步相机、调色板、队伍、NPC 与覆盖块。
## `camera_offset` 仅用于 `007F` 剧情镜头，不改变队伍世界位置。
## 只修改渲染节点，不修改 `GameSession` 或事件对象。
func sync_world(session: GameSession, events: Array[PalEventObject], camera_offset: Vector2i = Vector2i.ZERO) -> bool:
	if loaded_map_number < 0 or _map_instance == null or _database == null:
		error_message = "TileMap 世界尚未载入地图"
		return false
	if not _update_palette(session.palette_index, session.night_palette):
		return false
	if not session.party_roles.is_empty():
		var leader_role := session.party_roles[0]
		var leader_sprite := _player_sprite_for_role(leader_role)
		if not leader_sprite.is_valid():
			var sprite_number := _database.player_roles.scene_sprite_for(leader_role)
			error_message = "主角 MGO Sprite %d 加载失败：%s" % [sprite_number, leader_sprite.error_message]
			return false
	var classic_viewport := session.viewport_position + camera_offset
	var render_viewport := classic_viewport - _classic_content_offset
	# 即使逻辑视野扩大，PAL 的电影镜头中心仍由原 320×200 中心决定。
	_camera.position = Vector2(classic_viewport) + Vector2(PresentationMetrics.CLASSIC_CONTENT_SIZE) / 2.0
	_wave_overlay.position = Vector2(render_viewport)
	_clear_sort_items()
	latest_snapshot = PresentationBuilder.build(
		_database,
		session,
		events,
		loaded_map_number,
		_walk_phase,
		_showing_walk_frame,
		camera_offset,
		Callable(self, "is_map_blocked")
	)
	latest_snapshot.logical_view_size = _logical_view_size
	latest_snapshot.render_viewport_position = render_viewport
	latest_snapshot.classic_content_offset = _classic_content_offset
	var scene_items := _build_scene_items(latest_snapshot, session, events, render_viewport)
	var expanded := PalSceneLayout.expanded_draw_items(_map_data, _tile_sprite, render_viewport, scene_items)
	for item in expanded:
		_apply_remaster_cover(item, session.night_palette)
		_add_draw_item(item, render_viewport)
	presentation_snapshot_ready.emit(latest_snapshot)
	return true


## 查询一个 PAL 世界位置是否被地图 TileSet 的 `pal_blocked` 自定义数据阻挡。
## 坐标越界或缺失 TileData 时视为阻挡；迁移期会与原始 MAP 位进行一致性检查。
func is_map_blocked(world_position: Vector2i) -> bool:
	if _static_bottom == null or _map_data == null:
		return true
	var tile := PalMapCoordinates.world_to_tile(world_position)
	if not PalMapCoordinates.is_valid_tile(tile):
		return true
	var cell := PalTileSetBuilder.pal_half_to_map_cell(tile.x, tile.y, tile.z)
	var tile_data := _static_bottom.get_cell_tile_data(cell)
	if tile_data == null:
		return true
	var tilemap_blocked := bool(tile_data.get_custom_data("pal_blocked"))
	var raw_blocked := PalMapData.is_blocked(_map_data.tile_value(tile.x, tile.y, tile.z))
	if tilemap_blocked != raw_blocked and not _reported_block_mismatches.has(cell):
		_reported_block_mismatches[cell] = true
		push_warning("TileSet 阻挡与 MAP 不一致：地图 %d，cell %s" % [loaded_map_number, cell])
	return tilemap_blocked


## 清空依赖 Sprite 像素的运行时纹理缓存；PLAYERROLES 场景 Sprite 被脚本修改后调用。
func reset_sprite_cache() -> void:
	_event_sprites.clear()
	_texture_cache.clear()
	_remaster_actor_atlases.clear()


## 为高清 2D Sprite 提供与正式 TileMap 完全相同的经典 MGO 回退帧。
## 人物位置、方向和帧编号始终来自共享快照，不在表现层重复选择。
func classic_actor_texture(actor: PalPresentationActor, palette_index: int, night_palette: bool) -> Texture2D:
	if actor == null or actor.sprite_number <= 0 or actor.frame_index < 0 or _database == null:
		return null
	var key := "classic-rgba:%d:%d:%d:%d" % [actor.sprite_number, actor.frame_index, palette_index, 1 if night_palette else 0]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var frame := _decode_frame(_event_sprite(actor.sprite_number), actor.frame_index)
	if not frame.is_valid():
		return null
	var palette := _database.load_palette(palette_index, night_palette)
	if palette.size() < PaletteDecoder.PALETTE_BYTES:
		return null
	var texture := ImageTexture.create_from_image(frame.to_rgba_image(palette))
	_texture_cache[key] = texture
	return texture


## 像素基准测试可关闭新增辅助标识；正式游戏保持默认开启。
func set_collectible_markers_enabled(enabled: bool) -> void:
	_collectible_markers_enabled = enabled


## 设置正式 TileMap 画布的临时像素偏移，供 0035 屏幕震动复用。
func set_screen_effect_offset(offset: Vector2) -> void:
	_ensure_runtime_nodes()
	_effect_root.position = offset


## 设置 0071 的逐行波动强度和有符号推进量；零强度立即停用效果。
func set_screen_wave(amplitude: int, progression: int) -> void:
	_ensure_runtime_nodes()
	_wave_amplitude = amplitude
	_wave_progression = progression
	_wave_frame_accumulator = 0.0
	_wave_material.set_shader_parameter("wave_strength", float(amplitude))
	_wave_overlay.visible = amplitude > 0 and amplitude < 256
	if amplitude == 0:
		_wave_phase = 0.0
		_wave_material.set_shader_parameter("phase", 0.0)


func _process(delta: float) -> void:
	if _wave_amplitude == 0 or _wave_material == null:
		return
	_wave_frame_accumulator += delta
	while _wave_frame_accumulator >= 0.1:
		_wave_frame_accumulator -= 0.1
		# PAL_ApplyWave 在每个 10 FPS 场景帧先推进强度，再检查 0/256 边界。
		_wave_amplitude += _wave_progression
		if _wave_amplitude <= 0 or _wave_amplitude >= 256:
			_wave_amplitude = 0
			_wave_progression = 0
			_wave_phase = 0.0
			_wave_overlay.hide()
			_wave_material.set_shader_parameter("wave_strength", 0.0)
			_wave_material.set_shader_parameter("phase", 0.0)
			return
		_wave_phase = fmod(_wave_phase + 1.0, 32.0)
		_wave_material.set_shader_parameter("wave_strength", float(_wave_amplitude))
	_wave_material.set_shader_parameter("phase", _wave_phase)


func _ensure_runtime_nodes() -> void:
	if _palette_material == null:
		_palette_material = ShaderMaterial.new()
		_palette_material.shader = PALETTE_SHADER
		_palette_material.set_shader_parameter("palette_mix", 1.0)
		_palette_material.set_shader_parameter("global_alpha", 1.0)
	if _collectible_marker_material == null:
		_collectible_marker_material = ShaderMaterial.new()
		_collectible_marker_material.shader = COLLECTIBLE_MARKER_SHADER
	if _collectible_marker_frame == null:
		_collectible_marker_frame = _create_collectible_marker_frame()
	if _effect_root == null:
		_effect_root = Node2D.new()
		_effect_root.name = "ScreenEffectRoot"
		add_child(_effect_root)
	if _wave_overlay == null:
		_wave_overlay = ColorRect.new()
		_wave_overlay.name = "ScreenWaveOverlay"
		_wave_overlay.size = Vector2(_logical_view_size)
		_wave_overlay.color = Color.WHITE
		_wave_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wave_overlay.z_index = 1000
		_wave_material = ShaderMaterial.new()
		_wave_material.shader = SCREEN_WAVE_SHADER
		_wave_material.set_shader_parameter("wave_strength", 0.0)
		_wave_material.set_shader_parameter("phase", 0.0)
		_wave_overlay.material = _wave_material
		_wave_overlay.hide()
		add_child(_wave_overlay)
	if _sort_root == null:
		_sort_root = Node2D.new()
		_sort_root.name = "YSortRoot"
		_sort_root.y_sort_enabled = true
		_sort_root.z_index = 2
		_effect_root.add_child(_sort_root)
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
	_update_remaster_map_palette(night)
	return true


func _build_scene_items(snapshot: PalWorldPresentationSnapshot, session: GameSession, events: Array[PalEventObject], render_viewport: Vector2i) -> Array:
	var result: Array = []
	for raw_actor in snapshot.party:
		var actor: PalPresentationActor = raw_actor
		var sprite := _event_sprite(actor.sprite_number)
		var frame := _decode_frame(sprite, actor.frame_index)
		if not frame.is_valid():
			continue
		var item := PalSceneLayout.player_item(frame, actor.pal_world_position - render_viewport, actor.scene_layer)
		_apply_remaster_actor(item, actor, sprite, render_viewport)
		result.append(item)

	for raw_actor in snapshot.followers:
		var actor: PalPresentationActor = raw_actor
		var sprite := _event_sprite(actor.sprite_number)
		var frame := _decode_frame(sprite, actor.frame_index)
		if frame.is_valid():
			var item := PalSceneLayout.player_item(frame, actor.pal_world_position - render_viewport, actor.scene_layer)
			_apply_remaster_actor(item, actor, sprite, render_viewport)
			result.append(item)

	var events_by_id: Dictionary = {}
	for event in events:
		events_by_id[event.object_id] = event
	for raw_actor in snapshot.events:
		var actor: PalPresentationActor = raw_actor
		var frame := _decode_frame(_event_sprite(actor.sprite_number), actor.frame_index)
		var screen_position: Vector2i = actor.pal_world_position - render_viewport
		if frame.is_valid() and not _outside_viewport(screen_position, frame.width, frame.height):
			var item := PalSceneLayout.event_item(frame, screen_position, actor.scene_layer)
			_apply_remaster_actor(item, actor, _event_sprite(actor.sprite_number), render_viewport)
			result.append(item)
		var event: PalEventObject = events_by_id.get(actor.source_object_id)
		if event != null and _collectible_markers_enabled and _collectible_classifier.is_available(event, session):
			var source_height := frame.height if frame.is_valid() else SPRITELESS_COLLECTIBLE_HEIGHT
			var marker_position: Vector2i = screen_position + Vector2i(0, -source_height - 2)
			if not _outside_viewport(marker_position, COLLECTIBLE_MARKER_SIZE, COLLECTIBLE_MARKER_SIZE):
				result.append(PalSceneLayout.collectible_marker_item(_collectible_marker_frame, screen_position, actor.scene_layer, source_height, actor.source_object_id))
	return result


func _outside_viewport(screen_position: Vector2i, width: int, height: int) -> bool:
	return screen_position.x < -width or screen_position.x > _logical_view_size.x + width or screen_position.y < -height or screen_position.y > _logical_view_size.y + height


func _apply_map_presentation() -> void:
	_restore_classic_map_tileset()
	if _presentation_mode != PRESENTATION_REMASTER_2D or loaded_map_number < 0 or _map_data == null or _tile_sprite == null:
		return
	_ensure_remaster_resolver()
	if _remaster_resolver == null:
		return
	var resolved := _remaster_resolver.resolve("map/%03d/tileset" % loaded_map_number, "map_tileset")
	if resolved == null:
		return
	var candidate := RemasterMapTileset.new()
	if not candidate.load_manifest(resolved.path, loaded_map_number, _tile_sprite.frame_count(), _required_map_frame_indices()):
		_remaster_resolver.report_invalid_asset(resolved.path, candidate.error_message)
		return
	var tile_set := PalTileSetBuilder.build_remaster_tileset(_map_data, candidate.source_frame_count, candidate.active_atlas_texture(_palette_key.ends_with(":1")))
	if tile_set == null:
		_remaster_resolver.report_invalid_asset(resolved.path, "无法构建等价 5 倍 TileSet")
		return
	_remaster_map_tileset = candidate
	for layer in [_static_bottom, _static_top, _cover_bottom, _cover_top]:
		if layer != null:
			layer.tile_set = tile_set
			layer.scale = Vector2.ONE / float(RemasterMapTileset.SCALE)
	_static_bottom.material = null
	_static_top.material = null
	_remaster_map_active = true


func _restore_classic_map_tileset() -> void:
	_remaster_map_active = false
	_remaster_map_tileset = null
	if _classic_tile_set == null:
		return
	for layer in [_static_bottom, _static_top, _cover_bottom, _cover_top]:
		if layer != null:
			layer.tile_set = _classic_tile_set
			layer.scale = Vector2.ONE
	if _static_bottom != null:
		_static_bottom.material = _palette_material
	if _static_top != null:
		_static_top.material = _palette_material


func _required_map_frame_indices() -> PackedInt32Array:
	var indices: Dictionary = {}
	var frame_count := _tile_sprite.frame_count()
	var fallback_index := PalMapData.bottom_sprite_index(_map_data.tile_value(0, 0, 0))
	if fallback_index >= 0 and fallback_index < frame_count:
		indices[fallback_index] = true
	for map_y in range(PalMapData.HEIGHT):
		for map_x in range(PalMapData.WIDTH):
			for half in range(PalMapData.HALVES):
				var value := _map_data.tile_value(map_x, map_y, half)
				var bottom_index := PalMapData.bottom_sprite_index(value)
				if bottom_index >= 0 and bottom_index < frame_count:
					indices[bottom_index] = true
				elif fallback_index >= 0 and fallback_index < frame_count:
					indices[fallback_index] = true
				var top_index := PalMapData.top_sprite_index(value)
				if top_index >= 0 and top_index < frame_count:
					indices[top_index] = true
	var result := PackedInt32Array()
	for raw_index in indices:
		result.append(int(raw_index))
	result.sort()
	return result


func _ensure_remaster_resolver() -> void:
	if _remaster_resolver == null:
		_remaster_resolver = PalRemasterAssetResolver.new()
	if not _remaster_resolver_loaded:
		_remaster_resolver.reload()
		_remaster_resolver_loaded = true


func _apply_remaster_actor(item: PalSceneLayout.DrawItem, actor: PalPresentationActor, sprite: PalSprite, render_viewport: Vector2i) -> void:
	if _presentation_mode != PRESENTATION_REMASTER_2D or item == null or actor == null or sprite == null or not sprite.is_valid():
		return
	var atlas = _remaster_actor_atlas(actor, sprite.frame_count())
	if atlas == null:
		return
	var frame = atlas.frame(actor.frame_index)
	if frame == null or frame.texture == null:
		return
	var target_screen := Vector2(actor.pal_world_position - render_viewport)
	var item_anchor := Vector2(item.x, item.baseline_y)
	item.remaster_texture = frame.texture
	item.remaster_scale = 1.0 / float(RemasterSpriteAtlas.SCALE)
	item.remaster_position = target_screen - item_anchor - Vector2(frame.pivot) * item.remaster_scale


func _remaster_actor_atlas(actor: PalPresentationActor, frame_count: int):
	_ensure_remaster_resolver()
	if _remaster_resolver == null:
		return null
	var cache_key := "%s:%d:%d" % [actor.logical_id, actor.sprite_number, frame_count]
	if _remaster_actor_atlases.has(cache_key):
		var cached = _remaster_actor_atlases[cache_key]
		return cached if cached is RefCounted and cached.get_script() == RemasterSpriteAtlas else null
	var resolved := _remaster_resolver.resolve(actor.logical_id, "field_sprite")
	if resolved == null:
		_remaster_actor_atlases[cache_key] = false
		return null
	var atlas := RemasterSpriteAtlas.new()
	if not atlas.load_manifest(resolved.path, actor.sprite_number, frame_count):
		_remaster_resolver.report_invalid_asset(resolved.path, atlas.error_message)
		_remaster_actor_atlases[cache_key] = false
		return null
	_remaster_actor_atlases[cache_key] = atlas
	return atlas


func _apply_remaster_cover(item: PalSceneLayout.DrawItem, night: bool) -> void:
	if not _remaster_map_active or _remaster_map_tileset == null or item == null or item.map_sprite_index < 0:
		return
	var texture: Texture2D = _remaster_map_tileset.frame_texture(item.map_sprite_index, night)
	if texture == null:
		return
	item.remaster_texture = texture
	item.remaster_scale = 1.0 / float(RemasterMapTileset.SCALE)
	item.remaster_position = Vector2(0, -item.frame.height - item.logical_layer + item.draw_offset_y)


func _update_remaster_map_palette(night: bool) -> void:
	if not _remaster_map_active or _remaster_map_tileset == null or _static_bottom == null or _static_bottom.tile_set == null:
		return
	var source := _static_bottom.tile_set.get_source(PalTileSetBuilder.ATLAS_SOURCE_ID) as TileSetAtlasSource
	if source != null:
		source.texture = _remaster_map_tileset.active_atlas_texture(night)


func _player_sprite_for_role(role_index: int) -> PalSprite:
	# MGO 本体已经由内容数据库按 Sprite 编号缓存。这里不能再按角色编号缓存，
	# 否则读档直接恢复 scene_sprite_numbers 时会继续显示读档前的剧情造型。
	return _database.load_player_scene_sprite(role_index)


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


func _add_draw_item(item: PalSceneLayout.DrawItem, viewport_position: Vector2i) -> void:
	var texture := item.remaster_texture if item.remaster_texture != null else _texture_for_frame(item.frame)
	if texture == null:
		return
	var anchor := Node2D.new()
	anchor.position = Vector2(item.x + viewport_position.x, item.baseline_y + viewport_position.y)
	if item.draw_kind == PalSceneLayout.DRAW_KIND_COLLECTIBLE_MARKER:
		anchor.name = "CollectibleMarker_%d" % item.source_object_id
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = item.remaster_position if item.remaster_position.is_finite() else Vector2(0, -item.frame.height - item.logical_layer + item.draw_offset_y)
	sprite.scale = Vector2(item.remaster_scale, item.remaster_scale)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item.remaster_texture == null:
		sprite.material = _collectible_marker_material if item.draw_kind == PalSceneLayout.DRAW_KIND_COLLECTIBLE_MARKER else _palette_material
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


func _create_collectible_marker_frame() -> PalIndexedImage:
	var frame := PalIndexedImage.new()
	frame.width = COLLECTIBLE_MARKER_SIZE
	frame.height = COLLECTIBLE_MARKER_SIZE
	frame.indices.resize(COLLECTIBLE_MARKER_SIZE * COLLECTIBLE_MARKER_SIZE)
	frame.indices.fill(0)
	frame.opacity.resize(COLLECTIBLE_MARKER_SIZE * COLLECTIBLE_MARKER_SIZE)
	frame.opacity.fill(0)
	var rows := [
		"....a....",
		"....a....",
		"....g....",
		"...gwg...",
		"aagwwwgaa",
		"...gwg...",
		"....g....",
		"....a....",
		"....a....",
	]
	for y in range(COLLECTIBLE_MARKER_SIZE):
		for x in range(COLLECTIBLE_MARKER_SIZE):
			var pixel: String = str(rows[y]).substr(x, 1)
			var offset := y * COLLECTIBLE_MARKER_SIZE + x
			match pixel:
				"a":
					frame.indices[offset] = 64
					frame.opacity[offset] = 170
				"g":
					frame.indices[offset] = 176
					frame.opacity[offset] = 235
				"w":
					frame.indices[offset] = 255
					frame.opacity[offset] = 255
	return frame
