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
var _overlay: WorldOverlay
var _status: Label
var _move_cooldown: float = 0.0
var _script_vm: ScriptVM


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

	_overlay = WorldOverlay.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

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
	if _move_cooldown > 0.0:
		return
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
		_session.party_direction = direction
		_try_move(movement)
		_move_cooldown = MOVE_REPEAT_SECONDS


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
	_session.viewport_position += delta
	_refresh_world()


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
	var rendered := PalMapRenderer.render(_map_data, _tile_sprite, Rect2i(_session.viewport_position, Vector2i(320, 200)), true)
	var palette := _database.load_palette(_session.palette_index, _session.night_palette)
	if not rendered.is_valid() or palette.is_empty():
		_set_error("地图渲染失败：%s" % rendered.error_message)
		return
	_map_view.texture = ImageTexture.create_from_image(rendered.to_rgba_image(palette))
	_overlay.set_world_state(_scene_events, _session.viewport_position)


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
