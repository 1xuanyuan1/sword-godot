# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c, scene.c and play.c movement behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
## 可玩探索场景的编排控制器，连接输入、会话、ScriptVM、地图世界、对话和菜单。
## 它决定何时触发或同步各模块，但不直接定义 PAL 内容和剧情规则。
extends Control

const MOVE_REPEAT_SECONDS := 0.10
const SCRIPT_FRAME_SECONDS := 0.10
const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")
const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")
const MENU_KEYCODES := [KEY_ESCAPE, KEY_M, KEY_TAB, KEY_I]
const RETURN_TO_LAB_KEYCODE := KEY_F10

var _database := PalContentDatabase.new()
var _session := GameSession.new()
var _map_data: PalMapData
var _tile_sprite: PalSprite
var _scene_events: Array[PalEventObject] = []
var _map_view: TextureRect
var _tile_world: PalTileMapWorld
var _ui_layer: CanvasLayer
var _status: Label
var _dialog_box: PalDialogBox
var _game_menu: PalGameMenu
var _audio_player: Node
var _move_cooldown: float = 0.0
var _script_vm: ScriptVM
var _player_sprites: Dictionary = {}
var _event_sprites: Dictionary = {}
var _walk_phase: int = 0
var _showing_walk_frame: bool = false
var _pending_scene_index: int = -1
var _script_frame_accumulator: float = 0.0
var _active_trigger_event: PalEventObject
var _active_scene_enter_index: int = -1
var _pending_used_item_id: int = 0
var _use_legacy_renderer: bool = false
var _touch_scan_active: bool = false
var _touch_scan_next_index: int = 0


func _ready() -> void:
	_use_legacy_renderer = "--pal-map-backend=legacy" in OS.get_cmdline_user_args()
	_build_interface()
	if not _database.load_generated():
		_set_error(_database.error_message + "。请返回资源实验室重新导入。")
		return
	_session.reset_new_game()
	_game_menu.configure(_database, _session)
	_game_menu.audio_settings_changed.connect(_on_audio_settings_changed)
	_game_menu.ui_sound_requested.connect(_on_ui_sound_requested)
	_audio_player = AudioPlayer.new()
	_audio_player.name = "PalAudioPlayer"
	add_child(_audio_player)
	_audio_player.configure(_database, _session)
	_audio_player.audio_missing.connect(_on_audio_missing)
	_script_vm = ScriptVM.new()
	_script_vm.configure(_database, _session)
	_script_vm.unsupported_instruction.connect(_on_unsupported_instruction)
	_script_vm.redraw_requested.connect(_on_script_redraw)
	_script_vm.dialog_started.connect(_on_dialog_started)
	_script_vm.dialog_message.connect(_on_dialog_message)
	_script_vm.dialog_page_break.connect(_on_dialog_page_break)
	_script_vm.dialog_ended.connect(_on_dialog_ended)
	_script_vm.script_finished.connect(_on_script_finished)
	_script_vm.scene_change_requested.connect(_on_scene_change_requested)
	_script_vm.player_sprites_changed.connect(_on_player_sprites_changed)
	_script_vm.party_step_performed.connect(_on_script_party_step)
	_script_vm.party_walk_finished.connect(_on_script_party_walk_finished)
	_script_vm.music_requested.connect(_on_music_requested)
	_script_vm.sound_requested.connect(_on_sound_requested)
	add_child(_script_vm)
	var checkpoint: Dictionary = DebugCheckpoint.consume()
	if checkpoint.is_empty():
		_load_scene(_session.scene_index, true)
	else:
		_load_debug_checkpoint(checkpoint)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_tile_world = PalTileMapWorld.new()
	_tile_world.name = "PalTileMapWorld"
	_tile_world.visible = not _use_legacy_renderer
	add_child(_tile_world)

	_map_view = TextureRect.new()
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_view.stretch_mode = TextureRect.STRETCH_SCALE
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_view.visible = _use_legacy_renderer
	add_child(_map_view)

	# Camera2D 会变换默认世界画布。HUD 必须放在独立 CanvasLayer 中，
	# 否则相机跟随队伍时，状态栏、对话框和菜单也会一起移出 320×200 视口。
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "HudLayer"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var status_background := ColorRect.new()
	status_background.name = "StatusBackground"
	status_background.color = Color(0.02, 0.03, 0.06, 0.82)
	status_background.position = Vector2(3, 3)
	status_background.size = Vector2(314, 20)
	_ui_layer.add_child(status_background)
	_status = Label.new()
	_status.name = "StatusLabel"
	_status.position = Vector2(6, 5)
	_status.size = Vector2(308, 17)
	_status.add_theme_font_size_override("font_size", 8)
	_status.add_theme_color_override("font_color", Color("f8fafc"))
	_ui_layer.add_child(_status)

	_dialog_box = PalDialogBox.new()
	_dialog_box.name = "DialogBox"
	_dialog_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_dialog_box)

	_game_menu = PalGameMenu.new()
	_game_menu.name = "GameMenu"
	_game_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_menu.item_use_requested.connect(_on_item_use_requested)
	_ui_layer.add_child(_game_menu)


func _process(delta: float) -> void:
	if _map_data == null or not _map_data.is_valid():
		return
	if _game_menu != null and _game_menu.visible:
		return
	_script_frame_accumulator += minf(delta, 0.5)
	var auto_world_changed := false
	while _script_frame_accumulator >= SCRIPT_FRAME_SECONDS:
		_script_frame_accumulator -= SCRIPT_FRAME_SECONDS
		if _script_vm != null:
			auto_world_changed = _script_vm.tick_frame() or auto_world_changed
	if auto_world_changed:
		_refresh_world()
		# 自动脚本可能让 NPC 主动走入接触范围；官方会在同一游戏更新周期检查触发。
		if _script_vm != null and not _script_vm.running and not _script_vm.waiting_for_dialog:
			_trigger_touch_event()
	if _script_vm != null and (_script_vm.running or _script_vm.waiting_for_dialog):
		return
	# 同一轮接触扫描中的同步短脚本会在帧末续跑；期间不能夹入一次玩家移动。
	if _touch_scan_active:
		return
	_move_cooldown = maxf(0.0, _move_cooldown - delta)
	var movement := Vector2i.ZERO
	var direction := _session.party_direction
	var has_direction_input := false
	if Input.is_key_pressed(KEY_UP):
		direction = GameSession.DIR_NORTH
		has_direction_input = true
	elif Input.is_key_pressed(KEY_DOWN):
		direction = GameSession.DIR_SOUTH
		has_direction_input = true
	elif Input.is_key_pressed(KEY_LEFT):
		direction = GameSession.DIR_WEST
		has_direction_input = true
	elif Input.is_key_pressed(KEY_RIGHT):
		direction = GameSession.DIR_EAST
		has_direction_input = true
	if has_direction_input:
		movement = GameSession.movement_for_direction(direction)
	if movement != Vector2i.ZERO:
		if _move_cooldown > 0.0:
			return
		_session.party_direction = direction
		_showing_walk_frame = true
		_walk_phase = (_walk_phase + 1) % 4
		if _try_move(movement):
			_play_footstep_if_due()
		_refresh_world()
		_trigger_touch_event()
		_move_cooldown = MOVE_REPEAT_SECONDS
	elif _showing_walk_frame and _move_cooldown <= 0.0:
		_showing_walk_frame = false
		_refresh_world()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _game_menu != null and _game_menu.visible:
		if event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_M, KEY_TAB]:
			_game_menu.go_back()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode in MENU_KEYCODES:
		if _script_vm != null and not _script_vm.running and not _script_vm.waiting_for_dialog and not _touch_scan_active:
			if event.keycode == KEY_I:
				_game_menu.open_inventory()
			else:
				_game_menu.open_main()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if _dialog_box != null and _dialog_box.is_typing():
			_dialog_box.reveal_all()
			return
		if _script_vm != null and _script_vm.waiting_for_dialog:
			_script_vm.advance_dialog()
			return
		if _script_vm != null and _script_vm.running:
			return
		if _touch_scan_active:
			return
	if event is InputEventKey and event.keycode == RETURN_TO_LAB_KEYCODE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_inspect_nearby_event()


func _try_move(delta: Vector2i) -> bool:
	var target := _session.party_world_position() + delta
	if _is_blocked(target):
		_status.text = "前方被阻挡｜世界坐标 %s" % target
		return false
	_session.record_party_step(_session.party_direction, delta)
	return true


func _is_blocked(world_position: Vector2i) -> bool:
	var half := 0 if posmod(world_position.x, 32) == 0 else 1
	var tile_x := floori(world_position.x / 32.0)
	var tile_y := floori(world_position.y / 16.0)
	if tile_x < 0 or tile_x >= PalMapData.WIDTH or tile_y < 0 or tile_y >= PalMapData.HEIGHT:
		return true
	var map_blocked := PalMapData.is_blocked(_map_data.tile_value(tile_x, tile_y, half))
	if not _use_legacy_renderer and _tile_world != null and _tile_world.loaded_map_number >= 0:
		map_blocked = _tile_world.is_map_blocked(world_position)
	if map_blocked:
		return true
	for event in _scene_events:
		if not event.is_visible() or not event.blocks_movement():
			continue
		if absi(event.position.x - world_position.x) + absi(event.position.y - world_position.y) * 2 <= 12:
			return true
	return false


func _inspect_nearby_event() -> void:
	var party := _session.party_world_position()
	var checkpoints := _search_trigger_positions(party, _session.party_direction)
	var found := _find_search_event(checkpoints, _scene_events)
	if found == null:
		_status.text = "附近没有可交互事件｜世界坐标 %s" % party
		return

	if _prepare_search_event(found):
		_refresh_world()
	_status.text = "事件：脚本 0x%04X，自动脚本 0x%04X，Sprite %d" % [found.trigger_script, found.auto_script, found.sprite_number]
	_run_event_trigger(found)


func _search_trigger_positions(party_position: Vector2i, party_direction: int) -> Array[Vector2i]:
	# SDLPal `PAL_GetSearchTriggerRange` 会沿人物朝向生成中线和两侧共 13 个检查点。
	# 这里保留 PAL 世界像素坐标，匹配时再转成 (tile_x, tile_y, half)，避免把菱形邻接
	# 错当成普通直角坐标距离。
	var x_offset := 16 if party_direction in [GameSession.DIR_NORTH, GameSession.DIR_EAST] else -16
	var y_offset := 8 if party_direction in [GameSession.DIR_EAST, GameSession.DIR_SOUTH] else -8
	var x := party_position.x
	var y := party_position.y
	var result: Array[Vector2i] = [party_position]
	for _step in range(4):
		result.append(Vector2i(x + x_offset, y + y_offset))
		result.append(Vector2i(x, y + y_offset * 2))
		result.append(Vector2i(x + x_offset * 2, y))
		x += x_offset
		y += y_offset
	return result


func _find_search_event(checkpoints: Array[Vector2i], events: Array[PalEventObject]) -> PalEventObject:
	# 官方优先级是“检查点顺序 → EventObject 全局顺序”，不是按像素距离排序。
	# 坐标比较也只比较 PAL 的 tile_x、tile_y 和 half，允许同一 half 格内的细微像素偏移。
	for checkpoint_index in range(mini(13, checkpoints.size())):
		var checkpoint_half := _pal_world_to_half(checkpoints[checkpoint_index])
		for event in events:
			if not event.is_visible() or not event.is_search_trigger():
				continue
			if checkpoint_index >= event.search_trigger_checkpoint_count():
				continue
			if _pal_world_to_half(event.position) == checkpoint_half:
				return event
	return null


func _pal_world_to_half(world_position: Vector2i) -> Vector3i:
	return Vector3i(
		floori(world_position.x / 32.0),
		floori(world_position.y / 16.0),
		0 if posmod(world_position.x, 32) == 0 else 1
	)


func _prepare_search_event(event: PalEventObject) -> bool:
	# PAL_Search 只让处于普通四方向动画范围内的对象转身；特殊剧情帧不应被搜索覆盖。
	if event == null or event.sprite_frames * 4 <= event.current_frame:
		return false
	event.current_frame = 0
	event.direction = (_session.party_direction + 2) % 4
	# 普通站立帧由角色方向自然选出，不保留前一段剧情强制指定的动作帧。
	_session.clear_party_gestures()
	_showing_walk_frame = false
	return true


func _trigger_touch_event() -> bool:
	if _touch_scan_active or _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog:
		return false
	_touch_scan_active = true
	_touch_scan_next_index = 0
	return _continue_touch_scan()


func _continue_touch_scan() -> bool:
	if not _touch_scan_active or _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog:
		return false
	if _pending_scene_index >= 0:
		_reset_touch_scan()
		return false
	var party := _session.party_world_position()
	while _touch_scan_next_index < _scene_events.size():
		var event := _scene_events[_touch_scan_next_index]
		_touch_scan_next_index += 1
		if not _is_touch_event_in_range(event, party):
			continue
		if _prepare_touch_event(event):
			_refresh_world()
		# 官方即使遇到空触发入口也会继续扫描后续对象；不要让它阻断同格传送点。
		if event.trigger_script <= 0:
			continue
		_run_event_trigger(event)
		return true
	_reset_touch_scan()
	return false


func _is_touch_event_in_range(event: PalEventObject, party_position: Vector2i) -> bool:
	if event == null or not event.is_visible() or not event.is_touch_trigger():
		return false
	var distance := absi(event.position.x - party_position.x) + absi(event.position.y - party_position.y) * 2
	return distance < event.touch_trigger_distance()


func _prepare_touch_event(event: PalEventObject) -> bool:
	if event == null or event.sprite_frames <= 0:
		return false
	event.current_frame = 0
	var offset := _session.party_world_position() - event.position
	if offset.x > 0:
		event.direction = GameSession.DIR_EAST if offset.y > 0 else GameSession.DIR_NORTH
	else:
		event.direction = GameSession.DIR_SOUTH if offset.y > 0 else GameSession.DIR_WEST
	# 对应 PAL_UpdatePartyGestures(FALSE)：触碰 NPC 后队伍恢复普通站立帧。
	_session.clear_party_gestures()
	_showing_walk_frame = false
	return true


func _reset_touch_scan() -> void:
	_touch_scan_active = false
	_touch_scan_next_index = 0


func _run_event_trigger(event: PalEventObject) -> void:
	if event == null or event.trigger_script <= 0 or _script_vm == null:
		return
	_active_trigger_event = event
	_script_vm.run_trigger(event.trigger_script, event.object_id)


func _load_scene(scene_index: int, run_enter_script: bool) -> void:
	if scene_index < 0 or scene_index >= _database.scenes.size():
		_set_error("场景索引越界：%d" % scene_index)
		return
	_session.scene_index = scene_index
	_reset_touch_scan()
	_script_frame_accumulator = 0.0
	var scene := _database.scenes[scene_index]
	_map_data = _database.load_map(scene.map_number)
	_tile_sprite = _database.load_map_tiles(scene.map_number)
	_script_vm.set_scene_map(_map_data)
	_scene_events = _database.events_for_scene(scene_index)
	_event_sprites.clear()
	if not _map_data.is_valid() or not _tile_sprite.is_valid():
		_set_error("场景 %d 地图加载失败：%s %s" % [scene_index + 1, _map_data.error_message, _tile_sprite.error_message])
		return
	if not _use_legacy_renderer and not _tile_world.load_map(_database, scene.map_number):
		_set_error("地图 %d Godot TileMapLayer 加载失败：%s" % [scene.map_number, _tile_world.error_message])
		return
	if not _load_scene_sprites():
		return
	_refresh_world()
	_status.text = "方向键｜空格交互｜Esc 菜单｜F10 返回｜场景%d/地图%d｜%s" % [scene_index + 1, scene.map_number, "CPU 基准" if _use_legacy_renderer else "TileMapLayer"]
	if run_enter_script:
		_run_scene_enter_script(scene_index)


func _run_scene_enter_script(scene_index: int) -> void:
	if _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog:
		return
	if scene_index < 0 or scene_index >= _database.scenes.size():
		return
	var entry := _database.scenes[scene_index].script_on_enter
	if entry <= 0 or entry >= _database.scripts.size():
		return
	# SDLPal 会把触发脚本返回的新入口写回 rgScene，避免再次进入时重跑一次性剧情。
	_active_scene_enter_index = scene_index
	_script_vm.run_trigger(entry)


func _load_debug_checkpoint(checkpoint: Dictionary) -> void:
	var scene_index := int(checkpoint.get("scene", 0))
	_session.scene_index = scene_index
	var scene_enter_scripts: Dictionary = checkpoint.get("scene_enter_scripts", {})
	for overridden_scene_index in scene_enter_scripts:
		var index := int(overridden_scene_index)
		if index >= 0 and index < _database.scenes.size():
			_database.scenes[index].script_on_enter = int(scene_enter_scripts[overridden_scene_index])
	if checkpoint.has("direction"):
		_session.party_direction = int(checkpoint["direction"])
	if checkpoint.has("position"):
		_session.set_party_world_position(checkpoint["position"])
	var checkpoint_inventory: Dictionary = checkpoint.get("inventory", {})
	for item_id in checkpoint_inventory:
		_session.set_item_count(int(item_id), int(checkpoint_inventory[item_id]))
	if checkpoint.has("player_sprite") and _database.player_roles != null:
		_database.player_roles.scene_sprite_numbers[0] = int(checkpoint["player_sprite"])
	_load_scene(scene_index, false)
	var script_entry := int(checkpoint.get("script", 0))
	var event_object_id := int(checkpoint.get("event", 0))
	_status.text = "剧情测试：%s｜%s" % [checkpoint.get("id", ""), checkpoint.get("hint", "场景 %d｜脚本 0x%04X" % [scene_index + 1, script_entry])]
	if script_entry > 0:
		_script_vm.run_trigger(script_entry, event_object_id)


func _refresh_world() -> void:
	if not _use_legacy_renderer:
		_tile_world.set_walk_animation(_walk_phase, _showing_walk_frame)
		if not _tile_world.sync_world(_session, _scene_events):
			_set_error("Godot 原生地图渲染失败：%s" % _tile_world.error_message)
		return
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
		result.append(PalSceneRenderer.player_item(player_frame, member_world_position - _session.viewport_position, _session.world_layer))
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
	var scripted_frame := _session.scripted_party_frame(party_index)
	if scripted_frame >= 0 and not _showing_walk_frame:
		return _decode_sprite_frame(sprite, scripted_frame)
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


func _on_music_requested(music_number: int, loop: bool, fade_seconds: float) -> void:
	if _audio_player != null:
		_audio_player.play_music(music_number, loop, fade_seconds)


func _on_sound_requested(sound_number: int) -> void:
	if _audio_player != null:
		_audio_player.play_sound(sound_number)


func _on_ui_sound_requested(sound_number: int) -> void:
	_on_sound_requested(sound_number)


func _on_audio_settings_changed(_music_volume: int, _sound_volume: int) -> void:
	if _audio_player != null:
		_audio_player.apply_session_volumes()


func _on_audio_missing(kind: String, number: int, _path: String) -> void:
	_status.text = "%s %d 尚未生成｜请返回资源实验室重新导入 Data" % [kind, number]


func _on_dialog_message(message_index: int) -> void:
	var message := _database.get_message(message_index)
	var displayed_message := message if not message.is_empty() else "（文本未导入）"
	var overridden_role := PalContentDatabase.speaker_role_for_message(message_index)
	if overridden_role >= 0 and not _dialog_box.visible:
		var speaker := _database.get_word(_database.player_roles.name_word_for(overridden_role))
		var portrait := _database.player_roles.avatar_for(overridden_role)
		_dialog_box.show_speaker_title(speaker + "：", _load_portrait_texture(portrait))
	if PalDialogBox._is_speaker_title(displayed_message):
		var speaker := PalDialogBox.speaker_name_from_title(displayed_message)
		var fallback_portrait := _portrait_number_for_player(speaker)
		if fallback_portrait <= 0:
			fallback_portrait = _database.portrait_for_speaker(speaker)
		_dialog_box.show_speaker_title(displayed_message, _load_portrait_texture(fallback_portrait))
		return
	_dialog_box.show_message(displayed_message)


func _on_dialog_started(position: int, color: int, portrait: int) -> void:
	_dialog_box.begin(position, color, _load_portrait_texture(portrait))


func _on_dialog_page_break() -> void:
	_dialog_box.next_page()


func _on_dialog_ended() -> void:
	_dialog_box.hide_dialog()


func _portrait_number_for_player(speaker: String) -> int:
	if _database.player_roles == null:
		return 0
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		if _database.get_word(_database.player_roles.name_word_for(role_index)) == speaker:
			return _database.player_roles.avatar_for(role_index)
	return 0


func _load_portrait_texture(portrait_number: int) -> Texture2D:
	if portrait_number <= 0:
		return null
	var portrait_image := _database.load_rgm_portrait(portrait_number)
	var palette := _database.load_palette(_session.palette_index, _session.night_palette)
	if not portrait_image.is_valid() or palette.is_empty():
		return null
	return ImageTexture.create_from_image(portrait_image.to_rgba_image(palette))


func _on_scene_change_requested(scene_index: int) -> void:
	_pending_scene_index = scene_index
	call_deferred("_apply_pending_scene")


func _on_script_finished(next_entry: int) -> void:
	if _active_scene_enter_index >= 0:
		if _active_scene_enter_index < _database.scenes.size():
			_database.scenes[_active_scene_enter_index].script_on_enter = next_entry
		_active_scene_enter_index = -1
	if _active_trigger_event != null:
		_active_trigger_event.trigger_script = next_entry
		_active_trigger_event = null
	if _touch_scan_active:
		if _pending_scene_index >= 0:
			_reset_touch_scan()
		else:
			# PAL_GameUpdate 会在前一个接触脚本同步结束后继续扫描后续对象。
			# VM 可能等待对话，因此在脚本真正结束后从保存的数组索引异步续跑。
			call_deferred("_continue_touch_scan")
	if _pending_used_item_id > 0:
		var item := _database.item_definition(_pending_used_item_id)
		if item != null:
			item.script_on_use = next_entry
			if _script_vm.script_success and item.is_consuming():
				_session.change_item_count(_pending_used_item_id, -1)
		var should_trigger_touch := _script_vm.script_success
		_pending_used_item_id = 0
		if should_trigger_touch:
			call_deferred("_trigger_touch_event")


func _apply_pending_scene() -> void:
	if _pending_scene_index < 0:
		return
	var scene_index := _pending_scene_index
	_pending_scene_index = -1
	_load_scene(scene_index, true)


func _on_player_sprites_changed() -> void:
	_player_sprites.clear()
	if _tile_world != null:
		_tile_world.reset_sprite_cache()


func _on_script_party_step() -> void:
	_showing_walk_frame = true
	_walk_phase = (_walk_phase + 1) % 4
	_play_footstep_if_due()
	_move_cooldown = SCRIPT_FRAME_SECONDS


func _on_script_party_walk_finished() -> void:
	_showing_walk_frame = false
	_move_cooldown = 0.0


func _play_footstep_if_due() -> void:
	# 10 Hz 移动逻辑每两步播放一次短音效，避免连续重启同一个 VOC 形成爆音。
	if _audio_player != null and (_walk_phase & 1) == 0:
		_audio_player.play_sound(AudioPlayer.SOUND_FOOTSTEP)


func _on_item_use_requested(item_id: int) -> void:
	if _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _session.item_count(item_id) <= 0:
		return
	var item := _database.item_definition(item_id)
	if item == null or not item.is_usable():
		return
	_game_menu.close_menu()
	_pending_used_item_id = item_id
	_status.text = "使用：%s" % _database.get_word(item_id)
	_script_vm.run_trigger(item.script_on_use, 0xffff)


func _set_error(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", Color("fca5a5"))
