# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c, scene.c and play.c movement behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
extends Control

const MOVE_REPEAT_SECONDS := 0.10

var _database := PalContentDatabase.new()
var _session := GameSession.new()
var _map_data: PalMapData
var _tile_sprite: PalSprite
var _scene_events: Array[PalEventObject] = []
var _map_view: TextureRect
var _status: Label
var _move_cooldown: float = 0.0
var _script_vm: ScriptVM
var _player_sprites: Dictionary = {}
var _event_sprites: Dictionary = {}
var _walk_phase: int = 0
var _showing_walk_frame: bool = false


func _ready() -> void:
	_build_interface()
	if not _database.load_generated():
		_set_error(_database.error_message + "。请返回资源实验室重新导入。")
		return
	_session.reset_new_game()
	var scene := _database.scenes[_session.scene_index]
	_map_data = _database.load_map(scene.map_number)
	_tile_sprite = _database.load_map_tiles(scene.map_number)
	_scene_events = _database.events_for_scene(_session.scene_index)
	if not _map_data.is_valid() or not _tile_sprite.is_valid():
		_set_error("首场景地图加载失败：%s %s" % [_map_data.error_message, _tile_sprite.error_message])
		return
	if not _load_scene_sprites():
		return
	_script_vm = ScriptVM.new()
	_script_vm.configure(_database, _session)
	_script_vm.unsupported_instruction.connect(_on_unsupported_instruction)
	_script_vm.redraw_requested.connect(_on_script_redraw)
	_script_vm.dialog_message.connect(_on_dialog_message)
	add_child(_script_vm)
	if scene.script_on_enter > 0:
		_script_vm.run_trigger(scene.script_on_enter)
	_refresh_world()
	_status.text = "方向键移动｜空格/回车查看附近事件｜Esc 返回｜场景 %d / 地图 %d / 事件 %d" % [_session.scene_index + 1, scene.map_number, _scene_events.size()]


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_map_view = TextureRect.new()
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_view.stretch_mode = TextureRect.STRETCH_SCALE
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_map_view)

	var status_background := ColorRect.new()
	status_background.color = Color(0.02, 0.03, 0.06, 0.82)
	status_background.position = Vector2(3, 3)
	status_background.size = Vector2(314, 20)
	add_child(status_background)
	_status = Label.new()
	_status.position = Vector2(6, 5)
	_status.size = Vector2(308, 17)
	_status.add_theme_font_size_override("font_size", 8)
	_status.add_theme_color_override("font_color", Color("f8fafc"))
	add_child(_status)


func _process(delta: float) -> void:
	if _map_data == null or not _map_data.is_valid():
		return
	_move_cooldown = maxf(0.0, _move_cooldown - delta)
	var movement := Vector2i.ZERO
	var direction := _session.party_direction
	if Input.is_key_pressed(KEY_UP):
		movement = Vector2i(16, -8)
		direction = 0 # North
	elif Input.is_key_pressed(KEY_DOWN):
		movement = Vector2i(-16, 8)
		direction = 2 # South
	elif Input.is_key_pressed(KEY_LEFT):
		movement = Vector2i(-16, -8)
		direction = 3 # West
	elif Input.is_key_pressed(KEY_RIGHT):
		movement = Vector2i(16, 8)
		direction = 1 # East
	if movement != Vector2i.ZERO:
		if _move_cooldown > 0.0:
			return
		_session.party_direction = direction
		_showing_walk_frame = true
		_walk_phase = (_walk_phase + 1) % 4
		_try_move(movement)
		_refresh_world()
		_move_cooldown = MOVE_REPEAT_SECONDS
	elif _showing_walk_frame and _move_cooldown <= 0.0:
		_showing_walk_frame = false
		_refresh_world()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_inspect_nearby_event()


func _try_move(delta: Vector2i) -> void:
	var target := _session.party_world_position() + delta
	if _is_blocked(target):
		_status.text = "前方被阻挡｜世界坐标 %s" % target
		return
	_session.record_party_step(_session.party_direction, delta)


func _is_blocked(world_position: Vector2i) -> bool:
	var half := 0 if posmod(world_position.x, 32) == 0 else 1
	var tile_x := floori(world_position.x / 32.0)
	var tile_y := floori(world_position.y / 16.0)
	if tile_x < 0 or tile_x >= PalMapData.WIDTH or tile_y < 0 or tile_y >= PalMapData.HEIGHT:
		return true
	if PalMapData.is_blocked(_map_data.tile_value(tile_x, tile_y, half)):
		return true
	for event in _scene_events:
		if not event.is_visible() or not event.blocks_movement():
			continue
		if absi(event.position.x - world_position.x) + absi(event.position.y - world_position.y) * 2 <= 12:
			return true
	return false


func _inspect_nearby_event() -> void:
	var party := _session.party_world_position()
	var closest: PalEventObject
	var closest_distance := 999999
	for event in _scene_events:
		if not event.is_visible() or event.trigger_mode == 0:
			continue
		var distance := absi(event.position.x - party.x) + absi(event.position.y - party.y) * 2
		if distance < closest_distance:
			closest_distance = distance
			closest = event
	if closest == null or closest_distance > 64:
		_status.text = "附近没有可交互事件｜世界坐标 %s" % party
		return
	_status.text = "事件：脚本 0x%04X，自动脚本 0x%04X，Sprite %d（VM 基础阶段）" % [closest.trigger_script, closest.auto_script, closest.sprite_number]
	if closest.trigger_script > 0:
		_script_vm.run_trigger(closest.trigger_script)


func _refresh_world() -> void:
	var palette := _database.load_palette(_session.palette_index, _session.night_palette)
	var scene_items := _build_scene_draw_items()
	var rendered := PalSceneRenderer.render(
		_map_data,
		_tile_sprite,
		Rect2i(_session.viewport_position, Vector2i(320, 200)),
		scene_items
	)
	if not rendered.is_valid() or palette.is_empty():
		_set_error("地图渲染失败：%s" % rendered.error_message)
		return
	_map_view.texture = ImageTexture.create_from_image(rendered.to_rgba_image(palette))


func _load_scene_sprites() -> bool:
	var leader_role := _session.party_roles[0] if not _session.party_roles.is_empty() else 0
	var leader_sprite_number := _database.player_roles.scene_sprite_for(leader_role)
	var leader_sprite := _player_sprite_for_role(leader_role)
	if not leader_sprite.is_valid():
		_set_error("主角 MGO Sprite %d 加载失败：%s。请重新导入资源。" % [leader_sprite_number, leader_sprite.error_message])
		return false
	_event_sprites.clear()
	for event in _scene_events:
		if event.sprite_number <= 0 or _event_sprites.has(event.sprite_number):
			continue
		var sprite := _database.load_mgo_sprite(event.sprite_number)
		if sprite.is_valid():
			_event_sprites[event.sprite_number] = sprite
	return true


func _build_scene_draw_items() -> Array:
	var result: Array = []
	for party_index in range(mini(_session.party_roles.size(), 3)):
		var role_index := _session.party_roles[party_index]
		var player_sprite := _player_sprite_for_role(role_index)
		var player_frame := _party_frame(player_sprite, role_index, party_index)
		if not player_frame.is_valid():
			continue
		var member_world_position := _session.party_member_world_position(party_index)
		if party_index > 0 and _is_blocked(member_world_position):
			member_world_position = _session.trail_positions[1]
		result.append(PalSceneRenderer.player_item(player_frame, member_world_position - _session.viewport_position))
	for event in _scene_events:
		if not event.is_visible() or not _event_sprites.has(event.sprite_number):
			continue
		var sprite: PalSprite = _event_sprites[event.sprite_number]
		var frame_index := event.current_frame
		if event.sprite_frames == 3:
			if frame_index == 2:
				frame_index = 0
			elif frame_index == 3:
				frame_index = 2
		frame_index += event.direction * event.sprite_frames
		var frame := _decode_sprite_frame(sprite, frame_index)
		if not frame.is_valid():
			continue
		var screen_position := event.position - _session.viewport_position
		if screen_position.x < -frame.width or screen_position.x > 320 + frame.width or screen_position.y < -frame.height or screen_position.y > 200 + frame.height:
			continue
		result.append(PalSceneRenderer.event_item(frame, screen_position, event.layer))
	return result


func _player_sprite_for_role(role_index: int) -> PalSprite:
	if _player_sprites.has(role_index):
		return _player_sprites[role_index]
	var sprite_number := _database.player_roles.scene_sprite_for(role_index)
	var sprite := _database.load_mgo_sprite(sprite_number)
	_player_sprites[role_index] = sprite
	return sprite


func _party_frame(sprite: PalSprite, role_index: int, party_index: int) -> PalIndexedImage:
	if sprite == null or not sprite.is_valid():
		return PalIndexedImage.new()
	var walk_frames := _database.player_roles.walk_frame_count_for(role_index)
	var direction := _session.party_member_direction(party_index)
	var frame_index := direction * walk_frames
	if _showing_walk_frame:
		if walk_frames == 4:
			frame_index += _walk_phase
		elif (_walk_phase & 1) != 0:
			frame_index += int((_walk_phase + 1) / 2.0)
	return _decode_sprite_frame(sprite, frame_index)


func _decode_sprite_frame(sprite: PalSprite, frame_index: int) -> PalIndexedImage:
	if sprite == null or not sprite.is_valid() or frame_index < 0 or frame_index >= sprite.frame_count():
		return PalIndexedImage.new()
	return RleDecoder.decode(sprite.get_frame(frame_index))


func _on_unsupported_instruction(index: int, operation: int) -> void:
	_status.text = "事件脚本 0x%04X：操作码 0x%04X 尚未移植" % [index, operation]


func _on_script_redraw(_delay_units: int) -> void:
	_refresh_world()


func _on_dialog_message(message_index: int) -> void:
	var message := _database.get_message(message_index)
	_status.text = "消息 #%d：%s" % [message_index, message if not message.is_empty() else "（文本未导入）"]


func _set_error(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", Color("fca5a5"))
