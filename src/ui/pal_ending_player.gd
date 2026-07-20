# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal ending.c DOS paths.
# SPDX-License-Identifier: GPL-3.0-or-later
## DOS 结局专用的 FBP 滚动、MGO 合成与双背景动画播放器。
## 本控件只承载结局画面，不参与正式地图渲染；地图仍由 PalTileMapWorld 绘制。
class_name PalEndingPlayer
extends Control

## 结局动画完整播放或安全结束后发出。
signal playback_finished

const SCREEN_WAVE_SHADER: Shader = preload("res://shaders/pal_screen_wave_overlay.gdshader")

var _database: PalContentDatabase
var _session: GameSession
var _composition: Node2D
var _background: TextureRect
var _previous: TextureRect
var _effect: Sprite2D
var _effect_sprite: PalSprite
var _effect_sprite_number: int = 0
var _effect_frame_time: float = 0.0
var _effect_frame: int = 0
var _beast_first: Sprite2D
var _beast_second: Sprite2D
var _girl: Sprite2D
var _girl_sprite: PalSprite
var _girl_frame_time: float = 0.0
var _girl_frame: int = 0
var _ending_animation_active: bool = false
var _wave_material: ShaderMaterial
var _wave_overlay: ColorRect
var _wave_phase: float = 0.0
var _active_tween: Tween
var _palette: PackedByteArray = PackedByteArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_composition = Node2D.new()
	_composition.name = "Composition"
	add_child(_composition)
	_wave_overlay = ColorRect.new()
	_wave_overlay.name = "WaveOverlay"
	_wave_overlay.size = Vector2(320, 200)
	_wave_overlay.color = Color.WHITE
	_wave_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_material = ShaderMaterial.new()
	_wave_material.shader = SCREEN_WAVE_SHADER
	_wave_material.set_shader_parameter("wave_strength", 0.0)
	_wave_material.set_shader_parameter("phase", 0.0)
	_wave_overlay.material = _wave_material
	_wave_overlay.hide()
	_previous = _make_texture_rect("Previous")
	_composition.add_child(_previous)
	_background = _make_texture_rect("Background")
	_composition.add_child(_background)
	_beast_first = _make_sprite("BeastFirst")
	_composition.add_child(_beast_first)
	_beast_second = _make_sprite("BeastSecond")
	_composition.add_child(_beast_second)
	_girl = _make_sprite("Girl")
	_composition.add_child(_girl)
	_effect = _make_sprite("EffectSprite")
	_composition.add_child(_effect)
	add_child(_wave_overlay)
	hide()


## 注入只读内容与当前会话，并装载结局使用的调色板。
func configure(database: PalContentDatabase, session: GameSession) -> void:
	_database = database
	_session = session
	_palette = database.load_palette(session.palette_index, session.night_palette) if database != null and session != null else PackedByteArray()


## 保存 00A6 要求的当前画面；后续滚动从这张备份开始。
func backup_image(image: Image) -> void:
	if image == null or image.is_empty():
		return
	_previous.texture = ImageTexture.create_from_image(image)
	_previous.position = Vector2.ZERO
	_previous.show()


## 执行 ScriptVM 的 ENDING_* 动作；完成后保留最终 FBP 并发出 playback_finished。
func play(kind: int, first: int, second: int, third: int) -> void:
	if _database == null or _session == null:
		playback_finished.emit()
		return
	_palette = _database.load_palette(_session.palette_index, _session.night_palette)
	_ending_animation_active = false
	_beast_first.hide()
	_beast_second.hide()
	_girl.hide()
	_wave_material.set_shader_parameter("wave_strength", 0.0)
	_wave_material.set_shader_parameter("phase", 0.0)
	_wave_overlay.hide()
	show()
	match kind:
		ScriptVM.ENDING_ANIMATION:
			_play_ending_animation()
		ScriptVM.ENDING_SCROLL_FBP:
			_play_scroll_fbp(first, third)
		ScriptVM.ENDING_SHOW_FBP_EFFECT:
			_play_effect_fbp(first, second, third)
		_:
			playback_finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	if _ending_animation_active:
		_wave_phase += delta * 10.0
		_wave_material.set_shader_parameter("phase", _wave_phase)
		if _girl_sprite != null and _girl_sprite.is_valid() and _girl_sprite.frame_count() > 0:
			_girl_frame_time += delta
			if _girl_frame_time >= 0.05:
				_girl_frame_time = fmod(_girl_frame_time, 0.05)
				_girl_frame = (_girl_frame + 1) % mini(4, _girl_sprite.frame_count())
				_set_sprite_frame(_girl, _girl_sprite, _girl_frame)
	if _effect_sprite != null and _effect_sprite.is_valid() and _effect_sprite.frame_count() > 0:
		_effect_frame_time += delta
		if _effect_frame_time >= 0.15:
			_effect_frame_time = fmod(_effect_frame_time, 0.15)
			_effect_frame = (_effect_frame + 1) % _effect_sprite.frame_count()
			_update_effect_frame()


func _play_scroll_fbp(image_number: int, speed: int) -> void:
	var texture := _fbp_texture(image_number)
	if texture == null:
		playback_finished.emit()
		return
	if _previous.texture == null:
		_previous.texture = _background.texture
	_previous.position = Vector2.ZERO
	_previous.show()
	_background.texture = texture
	_background.position = Vector2(0, -200)
	_background.show()
	var duration := 176.0 / float(maxi(1, speed))
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_previous, "position:y", 200.0, duration)
	_active_tween.tween_property(_background, "position:y", 0.0, duration)
	_active_tween.chain().tween_callback(_finish_playback)


func _play_effect_fbp(image_number: int, effect_sprite_number: int, fade_speed: int) -> void:
	if effect_sprite_number != 0xffff:
		_set_effect_sprite(effect_sprite_number)
	var texture := _fbp_texture(image_number)
	if texture == null:
		playback_finished.emit()
		return
	_previous.texture = _background.texture if _background.texture != null else _previous.texture
	_previous.position = Vector2.ZERO
	_background.texture = texture
	_background.position = Vector2.ZERO
	_background.modulate.a = 0.0 if fade_speed > 0 else 1.0
	_background.show()
	if fade_speed <= 0:
		_finish_playback()
		return
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(_background, "modulate:a", 1.0, float(fade_speed + 1) * 0.96)
	_active_tween.tween_callback(_finish_playback)


func _play_ending_animation() -> void:
	# DOS ending.c 的 400×50ms 循环：FBP 62 下移、61 从上方补入，MGO 571
	# 的两帧兽形相隔 200 像素上升，MGO 572 少女以四帧动画从 y=180 升到 80。
	var upper := _fbp_texture(61)
	var lower := _fbp_texture(62)
	if upper == null or lower == null:
		playback_finished.emit()
		return
	var beast := _database.load_mgo_sprite(571)
	_girl_sprite = _database.load_mgo_sprite(572)
	_previous.texture = upper
	_previous.position = Vector2(0, -200)
	_previous.show()
	_background.texture = lower
	_background.position = Vector2.ZERO
	_background.show()
	_effect.hide()
	_effect_sprite = null
	_set_sprite_frame(_beast_first, beast, 0)
	_set_sprite_frame(_beast_second, beast, 1)
	_beast_first.position = Vector2(0, -400)
	_beast_second.position = Vector2(0, -200)
	_beast_first.show()
	_beast_second.show()
	_girl_frame = 0
	_girl_frame_time = 0.0
	_set_sprite_frame(_girl, _girl_sprite, 0)
	_girl.position = Vector2(220, 180)
	_girl.show()
	_ending_animation_active = true
	_wave_phase = 0.0
	_wave_material.set_shader_parameter("wave_strength", 2.0)
	_wave_material.set_shader_parameter("phase", 0.0)
	_wave_overlay.show()
	_kill_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_previous, "position:y", 0.0, 20.0)
	_active_tween.tween_property(_background, "position:y", 200.0, 20.0)
	_active_tween.tween_property(_beast_first, "position:y", 0.0, 20.0)
	_active_tween.tween_property(_beast_second, "position:y", 200.0, 20.0)
	_active_tween.tween_property(_girl, "position:y", 80.0, 10.0)
	_active_tween.chain().tween_callback(_finish_ending_animation)


func _set_effect_sprite(sprite_number: int) -> void:
	_effect_sprite_number = sprite_number
	_effect_sprite = _database.load_mgo_sprite(sprite_number) if sprite_number > 0 else null
	_effect_frame = 0
	_effect_frame_time = 0.0
	_effect.visible = _effect_sprite != null and _effect_sprite.is_valid()
	_update_effect_frame()


func _update_effect_frame() -> void:
	_set_sprite_frame(_effect, _effect_sprite, _effect_frame)


func _fbp_texture(image_number: int) -> Texture2D:
	var indexed := _database.load_battle_background(image_number)
	return ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() and not _palette.is_empty() else null


func _finish_playback() -> void:
	_active_tween = null
	_previous.hide()
	_previous.position = Vector2.ZERO
	_background.position = Vector2.ZERO
	_background.modulate.a = 1.0
	playback_finished.emit()


func _finish_ending_animation() -> void:
	# 第 399 帧几乎完全由上方 FBP 61 覆盖；结束后固定为该图，避免把已移出
	# 视口的 FBP 62 错误复位成最终画面。
	_background.texture = _previous.texture
	_background.position = Vector2.ZERO
	_background.modulate.a = 1.0
	_background.show()
	_previous.hide()
	_beast_first.hide()
	_beast_second.hide()
	_girl.hide()
	_ending_animation_active = false
	_wave_material.set_shader_parameter("wave_strength", 0.0)
	_wave_material.set_shader_parameter("phase", 0.0)
	_wave_overlay.hide()
	_active_tween = null
	playback_finished.emit()


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _make_texture_rect(node_name: String) -> TextureRect:
	var view := TextureRect.new()
	view.name = node_name
	view.size = Vector2(320, 200)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _make_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hide()
	return sprite


func _set_sprite_frame(node: Sprite2D, sprite: PalSprite, frame_index: int) -> void:
	if sprite == null or not sprite.is_valid() or sprite.frame_count() <= 0 or _palette.is_empty():
		node.texture = null
		return
	var indexed := RleDecoder.decode(sprite.get_frame(clampi(frame_index, 0, sprite.frame_count() - 1)))
	node.texture = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() else null
