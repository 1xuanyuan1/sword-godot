# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 固定电影化 Camera3D、环境节点与像素 Sprite3D 人物的 HD-2D 展示根。
## 它只消费 PalWorldPresentationSnapshot，不创建碰撞，也不修改剧情状态。
class_name PalHd2DWorld
extends Node3D

const CAMERA_OFFSET := Vector3(10.5, 8.0, 12.0)
const ACTOR_PIXEL_SIZE := 0.04
const ACTOR_HEIGHT := 0.96

var _camera: Camera3D
var _actor_root: Node3D
var _environment_root: Node3D
var _ground: MeshInstance3D
var _actor_nodes: Dictionary = {}
var _placeholder_texture: Texture2D
var _asset_resolver: PalRemasterAssetResolver
var _texture_cache: Dictionary = {}


func _ready() -> void:
	_ensure_runtime_nodes()


## 配置可回退的高清资源解析器；未找到资源时继续使用合成占位人物。
func configure_asset_resolver(resolver: PalRemasterAssetResolver) -> void:
	_asset_resolver = resolver
	_texture_cache.clear()


## 把共享快照同步到固定镜头与 Sprite3D 节点；缺失高清素材时显示合成占位人物。
func sync_snapshot(snapshot: PalWorldPresentationSnapshot) -> void:
	if snapshot == null:
		return
	_ensure_runtime_nodes()
	var active_keys: Dictionary = {}
	for raw_actor in snapshot.all_actors():
		var actor: PalPresentationActor = raw_actor
		if not actor.visible or actor.sprite_number <= 0:
			continue
		var key: String = actor.stable_key()
		active_keys[key] = true
		var sprite := _actor_nodes.get(key) as Sprite3D
		if sprite == null:
			sprite = _create_actor_sprite(actor)
			_actor_nodes[key] = sprite
			_actor_root.add_child(sprite)
		sprite.position = actor.world_position_3d + Vector3(0.0, ACTOR_HEIGHT * 0.5, 0.0)
		_apply_actor_texture(sprite, actor)
		sprite.set_meta("logical_id", actor.logical_id)
		sprite.set_meta("frame_index", actor.frame_index)
		sprite.set_meta("direction", actor.direction)
	for key in _actor_nodes.keys():
		if active_keys.has(key):
			continue
		var stale := _actor_nodes[key] as Node
		if stale != null:
			stale.queue_free()
		_actor_nodes.erase(key)

	_ground.position = Vector3(snapshot.camera_focus_3d.x, 0.0, snapshot.camera_focus_3d.z)
	_camera.position = snapshot.camera_focus_3d + CAMERA_OFFSET
	_camera.look_at(snapshot.camera_focus_3d + Vector3(0.0, 0.45, 0.0), Vector3.UP)


## 清空当前高清人物节点；经典 TileMap 状态不受影响。
func clear_world() -> void:
	for node in _actor_nodes.values():
		if node is Node:
			node.queue_free()
	_actor_nodes.clear()


func _ensure_runtime_nodes() -> void:
	if _environment_root != null:
		return
	_environment_root = Node3D.new()
	_environment_root.name = "EnvironmentRoot"
	add_child(_environment_root)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17212a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aeb8bd")
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color("9aa7a6")
	environment.fog_density = 0.012
	world_environment.environment = environment
	_environment_root.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "InkWashKeyLight"
	key_light.light_color = Color("ffe0b1")
	key_light.light_energy = 1.15
	key_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	key_light.shadow_enabled = true
	_environment_root.add_child(key_light)

	_ground = MeshInstance3D.new()
	_ground.name = "SyntheticFallbackGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("26362f")
	ground_material.roughness = 0.92
	plane.material = ground_material
	_ground.mesh = plane
	_environment_root.add_child(_ground)

	_actor_root = Node3D.new()
	_actor_root.name = "ActorRoot"
	add_child(_actor_root)

	_camera = Camera3D.new()
	_camera.name = "FixedCinematicCamera"
	_camera.fov = 32.0
	_camera.near = 0.1
	_camera.far = 180.0
	_camera.current = true
	add_child(_camera)


func _create_actor_sprite(actor: PalPresentationActor) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "Actor_%s" % actor.stable_key().replace(":", "_")
	sprite.texture = _placeholder_actor_texture()
	sprite.pixel_size = ACTOR_PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return sprite


func _placeholder_actor_texture() -> Texture2D:
	if _placeholder_texture != null:
		return _placeholder_texture
	var image := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(3, 23):
		var half_width := 3 if y < 9 else mini(6, 3 + int((y - 9) / 3.0))
		for x in range(8 - half_width, 9 + half_width):
			if x >= 0 and x < image.get_width():
				image.set_pixel(x, y, Color.WHITE)
	_placeholder_texture = ImageTexture.create_from_image(image)
	return _placeholder_texture


func _placeholder_color(kind: int) -> Color:
	match kind:
		PalPresentationActor.KIND_PARTY:
			return Color("f2d28b")
		PalPresentationActor.KIND_FOLLOWER:
			return Color("b6d4c8")
	return Color("c5b7a7")


func _apply_actor_texture(sprite: Sprite3D, actor: PalPresentationActor) -> void:
	var resolved := _asset_resolver.resolve(actor.logical_id, "field_sprite") if _asset_resolver != null else null
	var texture: Texture2D
	if resolved != null:
		texture = _load_runtime_texture(resolved.path)
	if texture == null:
		sprite.texture = _placeholder_actor_texture()
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.modulate = _placeholder_color(actor.kind)
		sprite.set_meta("asset_path", "")
		return
	sprite.texture = texture
	sprite.hframes = maxi(1, int(texture.get_width() / 128.0))
	sprite.vframes = maxi(1, int(texture.get_height() / 128.0))
	sprite.frame = clampi(actor.frame_index, 0, sprite.hframes * sprite.vframes - 1)
	sprite.modulate = Color.WHITE
	sprite.set_meta("asset_path", resolved.path)


func _load_runtime_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D if path.begins_with("res://") else null
	if texture == null:
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture
