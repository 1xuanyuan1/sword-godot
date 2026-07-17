# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal map.c, scene.c and play.c movement behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
## 可玩探索场景的编排控制器，连接输入、会话、ScriptVM、地图世界、对话和菜单。
## 它决定何时触发或同步各模块，但不直接定义 PAL 内容和剧情规则。
extends Control

const MOVE_REPEAT_SECONDS := 0.10
const SCRIPT_FRAME_SECONDS := 0.10
const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")
const StartupRequest := preload("res://src/game/pal_startup_request.gd")
const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")
const MENU_KEYCODES := [KEY_ESCAPE, KEY_M, KEY_TAB, KEY_I]
const RETURN_TO_LAB_KEYCODE := KEY_F10
const FIELD_MAGIC_STAGE_USE := 0
const FIELD_MAGIC_STAGE_SUCCESS := 1

var _database := PalContentDatabase.new()
var _session := GameSession.new()
var _save_manager := PalSaveManager.new()
var _map_data: PalMapData
var _tile_sprite: PalSprite
var _scene_events: Array[PalEventObject] = []
var _map_view: TextureRect
var _tile_world: PalTileMapWorld
var _ui_layer: CanvasLayer
var _status: Label
var _location_toast: PanelContainer
var _location_toast_label: Label
var _fbp_layer: ColorRect
var _fbp_view: TextureRect
var _dialog_box: PalDialogBox
var _game_menu: PalGameMenu
var _equipment_manager := PalEquipmentManager.new()
var _rng_player: PalRngPlayer
var _battle_view: PalBattlePreview
var _audio_player: Node
var _fade_overlay: ColorRect
var _fade_tween: Tween
var _fbp_tween: Tween
var _screen_fade_active: bool = false
var _fade_in_after_scene_change: bool = false
var _automatic_fade_in_duration: float = 0.6
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
var _pending_magic_object_id: int = 0
var _pending_magic_caster_role: int = -1
var _pending_magic_target_role: int = -1
var _pending_magic_stage: int = 0
var _use_legacy_renderer: bool = false
var _touch_scan_active: bool = false
var _touch_scan_next_index: int = 0
var _save_system_available: bool = false
var _system_toast_serial: int = 0
var _location_toast_serial: int = 0
var _loaded_scene_index: int = -1
var _pending_location_toast: String = ""
var _script_camera_offset: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_use_legacy_renderer = "--pal-map-backend=legacy" in OS.get_cmdline_user_args()
	_build_interface()
	if not _database.load_generated():
		_set_error(_database.error_message + "。请返回资源实验室重新导入。")
		return
	_save_system_available = _save_manager.configure(_database)
	_session.reset_new_game()
	if not _equipment_manager.configure(_database, _session):
		_set_error(_equipment_manager.error_message)
		return
	_game_menu.configure(_database, _session)
	_refresh_save_slot_summaries()
	_game_menu.audio_settings_changed.connect(_on_audio_settings_changed)
	_rng_player.configure(_database)
	_audio_player = AudioPlayer.new()
	_audio_player.name = "PalAudioPlayer"
	add_child(_audio_player)
	_audio_player.configure(_database, _session)
	_audio_player.audio_missing.connect(_on_audio_missing)
	_battle_view.configure_audio_player(_audio_player)
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
	_script_vm.camera_offset_requested.connect(_on_camera_offset_requested)
	_script_vm.music_requested.connect(_on_music_requested)
	_script_vm.sound_requested.connect(_on_sound_requested)
	_script_vm.fbp_requested.connect(_on_fbp_requested)
	_script_vm.screen_fade_requested.connect(_on_screen_fade_requested)
	_script_vm.rng_animation_requested.connect(_on_rng_animation_requested)
	_script_vm.battle_requested.connect(_on_battle_requested)
	add_child(_script_vm)
	var requested_load_slot := StartupRequest.consume_load_slot()
	var checkpoint: Dictionary = DebugCheckpoint.consume()
	if requested_load_slot > 0:
		if not _on_load_slot_requested(requested_load_slot):
			_load_scene(_session.scene_index, true)
	elif checkpoint.is_empty():
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

	# 地点提示独立于 PalDialogBox，避免场景进入脚本立刻播放对话时互相覆盖。
	_location_toast = PanelContainer.new()
	_location_toast.name = "LocationToast"
	_location_toast.position = Vector2(104, 28)
	_location_toast.size = Vector2(112, 24)
	_location_toast.custom_minimum_size = Vector2(112, 24)
	_location_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var location_style := StyleBoxFlat.new()
	location_style.bg_color = Color(0, 0, 0, 0.88)
	location_style.border_color = Color("d6a85f")
	location_style.set_border_width_all(1)
	location_style.corner_radius_top_left = 2
	location_style.corner_radius_top_right = 2
	location_style.corner_radius_bottom_left = 2
	location_style.corner_radius_bottom_right = 2
	_location_toast.add_theme_stylebox_override("panel", location_style)
	_location_toast_label = Label.new()
	_location_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_location_toast_label.add_theme_font_size_override("font_size", 10)
	_location_toast_label.add_theme_color_override("font_color", Color.WHITE)
	_location_toast.add_child(_location_toast_label)
	_location_toast.hide()
	_ui_layer.add_child(_location_toast)

	# FBP 过场图位于世界和普通 HUD 之上、剧情对话框之下；这样黑屏叙述仍可显示文字。
	_fbp_layer = ColorRect.new()
	_fbp_layer.name = "FbpLayer"
	_fbp_layer.color = Color.BLACK
	_fbp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fbp_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fbp_view = TextureRect.new()
	_fbp_view.name = "FbpView"
	_fbp_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fbp_view.stretch_mode = TextureRect.STRETCH_SCALE
	_fbp_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fbp_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fbp_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fbp_layer.add_child(_fbp_view)
	_fbp_layer.hide()
	_ui_layer.add_child(_fbp_layer)

	_dialog_box = PalDialogBox.new()
	_dialog_box.name = "DialogBox"
	_dialog_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_dialog_box)

	_game_menu = PalGameMenu.new()
	_game_menu.name = "GameMenu"
	_game_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_menu.item_use_requested.connect(_on_item_use_requested)
	_game_menu.item_equip_requested.connect(_on_item_equip_requested)
	_game_menu.magic_use_requested.connect(_on_magic_use_requested)
	_game_menu.save_slot_requested.connect(_on_save_slot_requested)
	_game_menu.load_slot_requested.connect(_on_load_slot_requested)
	_ui_layer.add_child(_game_menu)

	_rng_player = PalRngPlayer.new()
	_rng_player.name = "RngPlayer"
	_rng_player.playback_finished.connect(_on_rng_playback_finished)
	_ui_layer.add_child(_rng_player)

	_battle_view = PalBattlePreview.new()
	_battle_view.name = "BattleView"
	_battle_view.lab_mode = false
	_battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_view.battle_finished.connect(_on_battle_finished)
	_ui_layer.add_child(_battle_view)

	# PAL 的调色板渐隐应覆盖地图、人物和 HUD；放在 HUD 最后保证转场期间不会露出对话框。
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "ScreenFade"
	_fade_overlay.color = Color.BLACK
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.modulate.a = 0.0
	_fade_overlay.visible = false
	_ui_layer.add_child(_fade_overlay)


func _process(delta: float) -> void:
	if _map_data == null or not _map_data.is_valid():
		return
	if _battle_view != null and _battle_view.visible:
		return
	if _game_menu != null and _game_menu.visible:
		return
	if _screen_fade_active:
		return
	_show_pending_location_toast()
	_script_frame_accumulator += minf(delta, 0.5)
	var auto_world_changed := false
	while _script_frame_accumulator >= SCRIPT_FRAME_SECONDS:
		_script_frame_accumulator -= SCRIPT_FRAME_SECONDS
		if _script_vm != null:
			auto_world_changed = _script_vm.tick_frame() or auto_world_changed
	if auto_world_changed:
		_displace_party_from_blockers()
		_refresh_world()
		# 自动脚本可能让 NPC 主动走入接触范围；官方会在同一游戏更新周期检查触发。
		if _script_vm != null and not _script_vm.running and not _script_vm.waiting_for_dialog and not _script_vm.waiting_for_screen_fade and not _script_vm.waiting_for_rng and not _script_vm.waiting_for_battle:
			_trigger_touch_event()
	if _script_vm != null and (_script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle):
		return
	if _pending_magic_object_id > 0:
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
		_try_move(movement)
		_refresh_world()
		_trigger_touch_event()
		_move_cooldown = MOVE_REPEAT_SECONDS
	elif _showing_walk_frame and _move_cooldown <= 0.0:
		_showing_walk_frame = false
		_refresh_world()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _screen_fade_active:
		return
	if _battle_view != null and _battle_view.visible:
		return
	if _game_menu != null and _game_menu.visible:
		if event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_M, KEY_TAB]:
			_game_menu.go_back()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode in MENU_KEYCODES:
		if _script_vm != null and not _script_vm.running and not _script_vm.waiting_for_dialog and not _script_vm.waiting_for_screen_fade and not _script_vm.waiting_for_rng and not _script_vm.waiting_for_battle and not _touch_scan_active and _pending_magic_object_id <= 0:
			if event.keycode == KEY_I:
				_game_menu.open_inventory()
			else:
				_refresh_save_slot_summaries()
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
		if _script_vm != null and _script_vm.waiting_for_screen_fade:
			return
		if _script_vm != null and _script_vm.waiting_for_rng:
			return
		if _script_vm != null and _script_vm.waiting_for_battle:
			return
		if _touch_scan_active:
			return
		if _pending_magic_object_id > 0:
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
	if not PalMapCoordinates.is_within_player_walk_range(world_position):
		return true
	var tile := PalMapCoordinates.world_to_tile(world_position)
	var map_blocked := PalMapData.is_blocked(_map_data.tile_value(tile.x, tile.y, tile.z))
	if not _use_legacy_renderer and _tile_world != null and _tile_world.loaded_map_number >= 0:
		map_blocked = _tile_world.is_map_blocked(world_position)
	if map_blocked:
		return true
	for event in _scene_events:
		# PAL_CheckObstacle 只检查 state；正 vanish_time 会暂时隐藏对象，但不会解除阻挡。
		if not event.blocks_movement():
			continue
		if PalMapCoordinates.positions_collide(event.position, world_position):
			return true
	return false


func _displace_party_from_blockers() -> bool:
	# SDLPal `PAL_GameUpdate` 会在每个 EventObject 自动脚本之后检查 NPC 是否挤到
	# 队伍脚下；候选方向从 NPC 朝向的下一个方向开始，依次旋转一圈寻找可走 half 格。
	var displaced := false
	for event in _scene_events:
		if not event.is_visible() or not event.blocks_movement() or event.sprite_number <= 0:
			continue
		var party := _session.party_world_position()
		if PalMapCoordinates.weighted_distance(event.position, party) > PalMapCoordinates.PARTY_OVERLAP_DISTANCE:
			continue
		var direction := (event.direction + 1) % 4
		for _attempt in range(4):
			var movement := GameSession.movement_for_direction(direction)
			if not _is_blocked(party + movement):
				_session.displace_party_from_blocker(movement)
				_showing_walk_frame = false
				displaced = true
				break
			direction = (direction + 1) % 4
	return displaced


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
	if _touch_scan_active or _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle:
		return false
	_touch_scan_active = true
	_touch_scan_next_index = 0
	return _continue_touch_scan()


func _continue_touch_scan() -> bool:
	if not _touch_scan_active or _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle:
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
	var distance := PalMapCoordinates.weighted_distance(event.position, party_position)
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
	_hide_fbp_view()
	_script_camera_offset = Vector2i.ZERO
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
		_pending_location_toast = PalSceneCatalog.toast_name_for_transition(_loaded_scene_index, scene_index)
	_loaded_scene_index = scene_index
	if run_enter_script:
		_run_scene_enter_script(scene_index)


func _run_scene_enter_script(scene_index: int) -> void:
	if _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle:
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
	_apply_debug_event_overrides(checkpoint.get("event_overrides", {}))
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
	# 人工检查点会跳过场景进入脚本；显式恢复该剧情时点已经由脚本确定的 BGM。
	# 曲目仍由检查点剧情状态指定，不能按复用的 map_number 猜测。
	if checkpoint.has("music"):
		_session.music_number = int(checkpoint["music"])
		_on_music_requested(_session.music_number, true, 0.0)
	var script_entry := int(checkpoint.get("script", 0))
	var event_object_id := int(checkpoint.get("event", 0))
	_status.text = "剧情测试：%s｜%s" % [checkpoint.get("id", ""), checkpoint.get("hint", "场景 %d｜脚本 0x%04X" % [scene_index + 1, script_entry])]
	if script_entry > 0:
		_script_vm.run_trigger(script_entry, event_object_id)


func _apply_debug_event_overrides(overrides: Dictionary) -> void:
	# 人工检查点只写入明确列出的 PAL 运行时字段；不接受任意属性名，避免测试数据误改内容定义。
	for raw_object_id in overrides:
		var object_id := int(raw_object_id)
		if object_id <= 0 or object_id > _database.event_objects.size():
			continue
		var event: PalEventObject = _database.event_objects[object_id - 1]
		var values: Dictionary = overrides[raw_object_id]
		if values.has("position"):
			event.position = values["position"]
		if values.has("trigger_script"):
			event.trigger_script = int(values["trigger_script"])
		if values.has("auto_script"):
			event.auto_script = int(values["auto_script"])
		if values.has("state"):
			event.state = int(values["state"])
		if values.has("trigger_mode"):
			event.trigger_mode = int(values["trigger_mode"])
		if values.has("direction"):
			event.direction = int(values["direction"])


func _refresh_world() -> void:
	var render_viewport := _session.viewport_position + _script_camera_offset
	if not _use_legacy_renderer:
		_tile_world.set_walk_animation(_walk_phase, _showing_walk_frame)
		if not _tile_world.sync_world(_session, _scene_events, _script_camera_offset):
			_set_error("Godot 原生地图渲染失败：%s" % _tile_world.error_message)
		return
	var palette := _database.load_palette(_session.palette_index, _session.night_palette)
	var scene_items := _build_scene_draw_items(render_viewport)
	var rendered := PalSceneRenderer.render(
		_map_data,
		_tile_sprite,
		Rect2i(render_viewport, Vector2i(320, 200)),
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


func _build_scene_draw_items(render_viewport: Vector2i) -> Array:
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
		result.append(PalSceneRenderer.player_item(player_frame, member_world_position - render_viewport, _session.world_layer))
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
		var screen_position := event.position - render_viewport
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
	# record_party_step() 会在真正移动时清除旧剧情动作；若脚本随后再次执行 0015，
	# 新动作必须覆盖残留的步态标志。仙灵岛剧情依赖这一顺序显示李逍遥倒地帧。
	if scripted_frame >= 0:
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
	_hide_fbp_view()
	_refresh_world()
	_start_pending_fade_in_after_world_draw()


func _on_music_requested(music_number: int, loop: bool, fade_seconds: float) -> void:
	if _audio_player != null:
		_audio_player.play_music(music_number, loop, fade_seconds)


func _on_sound_requested(sound_number: int) -> void:
	if _audio_player != null:
		_audio_player.play_sound(sound_number)


func _on_fbp_requested(image_number: int, fade_seconds: float) -> void:
	if _fbp_layer == null or _fbp_view == null:
		if fade_seconds > 0.0 and _script_vm != null:
			_script_vm.call_deferred("complete_screen_fade")
		return
	if _fbp_tween != null and _fbp_tween.is_valid():
		_fbp_tween.kill()
	_fbp_tween = null
	_fbp_view.texture = null
	if image_number != 0xffff:
		var indexed := _database.load_battle_background(image_number)
		var palette := _database.load_palette(_session.palette_index, _session.night_palette)
		if indexed.is_valid() and not palette.is_empty():
			_fbp_view.texture = ImageTexture.create_from_image(indexed.to_rgba_image(palette))
	_fbp_layer.modulate.a = 0.0 if fade_seconds > 0.0 else 1.0
	_fbp_layer.show()
	if fade_seconds > 0.0:
		_fbp_tween = create_tween()
		_fbp_tween.tween_property(_fbp_layer, "modulate:a", 1.0, fade_seconds)
		_fbp_tween.finished.connect(func() -> void:
			_fbp_tween = null
			if _script_vm != null and _script_vm.waiting_for_screen_fade:
				_script_vm.complete_screen_fade()
		)


func _hide_fbp_view() -> void:
	if _fbp_tween != null and _fbp_tween.is_valid():
		_fbp_tween.kill()
	_fbp_tween = null
	if _fbp_layer != null:
		_fbp_layer.hide()
		_fbp_layer.modulate.a = 1.0
	if _fbp_view != null:
		_fbp_view.texture = null


func _on_screen_fade_requested(fade_out: bool, duration_seconds: float) -> void:
	if fade_out:
		_fade_in_after_scene_change = true
		_automatic_fade_in_duration = duration_seconds
	else:
		_fade_in_after_scene_change = false
	_start_screen_fade(fade_out, duration_seconds, true)


func _start_screen_fade(fade_out: bool, duration_seconds: float, complete_vm: bool) -> void:
	if _fade_overlay == null:
		if complete_vm and _script_vm != null:
			_script_vm.complete_screen_fade()
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_screen_fade_active = true
	_fade_overlay.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 1.0 if fade_out else 0.0, maxf(0.01, duration_seconds))
	_fade_tween.finished.connect(_on_screen_fade_finished.bind(fade_out, complete_vm))


func _start_pending_fade_in_after_world_draw() -> bool:
	if not _fade_in_after_scene_change or _screen_fade_active or _pending_scene_index >= 0:
		return false
	_fade_in_after_scene_change = false
	_start_screen_fade(false, _automatic_fade_in_duration, false)
	return true


func _on_screen_fade_finished(fade_out: bool, complete_vm: bool) -> void:
	_screen_fade_active = false
	# 清除已经结束的 Tween，再允许脚本回调启动下一段渐变；否则后续渐变会把
	# 正在派发 finished 的旧 Tween 当作活动对象杀掉，丢失 VM 完成通知。
	_fade_tween = null
	if not fade_out and _fade_overlay != null:
		_fade_overlay.visible = false
	if complete_vm and _script_vm != null:
		_script_vm.complete_screen_fade()
	# 部分原版脚本先执行 0059 切换场景，再执行 0050 渐隐。此时必须等渐隐的
	# VM 回调完成后才加载新场景，否则自动渐显会提前杀掉渐隐 Tween，并让
	# waiting_for_screen_fade 永久保持为 true。
	if _pending_scene_index >= 0 and not _screen_fade_active:
		_apply_pending_scene()


func _on_rng_animation_requested(animation_number: int, start_frame: int, end_frame: int, frames_per_second: int) -> void:
	if _rng_player == null:
		_script_vm.complete_rng_animation()
		return
	_rng_player.play(animation_number, start_frame, end_frame, frames_per_second)


func _on_rng_playback_finished() -> void:
	if _script_vm != null:
		_script_vm.complete_rng_animation()


func _on_battle_requested(enemy_team_id: int, battlefield_id: int, is_boss: bool) -> void:
	_game_menu.close_menu()
	_dialog_box.hide_dialog()
	if _audio_player != null and _session.battle_music_number > 0:
		_audio_player.play_music(_session.battle_music_number, true, 0.0)
	if _battle_view == null or not _battle_view.begin_battle(_database, _session, enemy_team_id, battlefield_id, is_boss):
		var reason := _battle_view.error_message if _battle_view != null and not _battle_view.error_message.is_empty() else "战斗覆盖层不可用"
		_status.text = "敌队 %d / 战场 %d 无法开始：%s" % [enemy_team_id, battlefield_id, reason]
		if _battle_view != null:
			_battle_view.hide()
		# 信号由 VM 的指令循环同步发出；失败分支延后恢复，避免重入同一个解释循环。
		_script_vm.call_deferred("complete_battle", ScriptVM.BATTLE_RESULT_DEFEAT)


func _on_battle_finished(result: int) -> void:
	if _audio_player != null:
		_audio_player.play_music(_session.music_number, true, 0.0)
	if _script_vm != null:
		_script_vm.complete_battle(result)


func _on_audio_settings_changed(_music_volume: int, _sound_volume: int) -> void:
	if _audio_player != null:
		_audio_player.apply_session_volumes()


func _on_save_slot_requested(slot: int) -> void:
	if not _save_system_available:
		_game_menu.close_menu()
		_show_system_toast("存档不可用：%s" % _save_manager.error_message)
		return
	if not _save_manager.save_slot(slot, _session):
		_game_menu.close_menu()
		_show_system_toast("保存失败：%s" % _save_manager.error_message)
		return
	_refresh_save_slot_summaries()
	_game_menu.close_menu()
	_show_system_toast("已保存到存档 %03d" % slot)


func _on_load_slot_requested(slot: int) -> bool:
	if not _save_system_available:
		_game_menu.close_menu()
		_show_system_toast("读档不可用：%s" % _save_manager.error_message)
		return false
	if not _save_manager.load_slot(slot, _session):
		_game_menu.close_menu()
		_show_system_toast("读取失败：%s" % _save_manager.error_message)
		return false
	_reset_transient_state_for_load()
	if not _equipment_manager.configure(_database, _session):
		_set_error("读档后无法重建装备效果：%s" % _equipment_manager.error_message)
		return false
	_script_vm.configure(_database, _session)
	_game_menu.configure(_database, _session)
	_refresh_save_slot_summaries()
	if _audio_player != null:
		_audio_player.configure(_database, _session)
	_load_scene(_session.scene_index, false)
	if _audio_player != null:
		_audio_player.play_music(_session.music_number, true, 0.0)
	_show_system_toast("已读取存档 %03d" % slot)
	return true


func _reset_transient_state_for_load() -> void:
	_game_menu.close_menu()
	_dialog_box.hide_dialog()
	_rng_player.stop_playback(false)
	_battle_view.hide()
	_script_vm.stop()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	_screen_fade_active = false
	_fade_in_after_scene_change = false
	_fade_overlay.visible = false
	_fade_overlay.modulate.a = 0.0
	_pending_scene_index = -1
	_active_trigger_event = null
	_active_scene_enter_index = -1
	_pending_used_item_id = 0
	_pending_magic_object_id = 0
	_pending_magic_caster_role = -1
	_pending_magic_target_role = -1
	_pending_magic_stage = FIELD_MAGIC_STAGE_USE
	_pending_location_toast = ""
	_script_camera_offset = Vector2i.ZERO
	_hide_fbp_view()
	_location_toast_serial += 1
	if _location_toast != null:
		_location_toast.hide()
	_reset_touch_scan()
	_player_sprites.clear()
	_event_sprites.clear()
	_move_cooldown = 0.0
	_showing_walk_frame = false
	if _audio_player != null:
		_audio_player.stop_all()


func _refresh_save_slot_summaries() -> void:
	_game_menu.configure_save_slots(_save_manager.slot_summaries() if _save_system_available else [], _save_manager.current_slot)


func _show_system_toast(message: String) -> void:
	_system_toast_serial += 1
	var serial := _system_toast_serial
	_dialog_box.begin(3)
	_dialog_box.show_message(message)
	_dialog_box.reveal_all()
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if serial == _system_toast_serial and _script_vm != null and not _script_vm.waiting_for_dialog:
			_dialog_box.hide_dialog()
	)


func _show_pending_location_toast() -> void:
	if _pending_location_toast.is_empty() or _location_toast == null or _location_toast_label == null:
		return
	var location_name := _pending_location_toast
	_pending_location_toast = ""
	_location_toast_serial += 1
	var serial := _location_toast_serial
	_location_toast_label.text = location_name
	_location_toast.show()
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if serial == _location_toast_serial and _location_toast != null:
			_location_toast.hide()
	)


func _on_audio_missing(kind: String, number: int, _path: String) -> void:
	_status.text = "%s %d 尚未生成｜请返回资源实验室重新导入 Data" % [kind, number]


func _on_dialog_message(message_index: int) -> void:
	var message := _database.get_message(message_index)
	var displayed_message := message if not message.is_empty() else "（文本未导入）"
	var overridden_role := PalContentDatabase.speaker_role_for_message(message_index)
	# 部分原版脚本用零肖像 003C/003D 输出无标题角色台词；显式开始的空对话框
	# 已经 visible，仍应按已确认的消息归属补回角色上下文。
	if overridden_role >= 0 and not _dialog_box.has_portrait():
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
		# 0081 会按原版把匹配对象改为接触触发；它与脚本最终成功标志不是同一状态。
		# 破天锤会先顺序检查前面的石像，因此面对第二座以后时 script_success 仍可能为 false。
		var should_trigger_touch := _script_vm.touch_trigger_armed
		_pending_used_item_id = 0
		if should_trigger_touch:
			call_deferred("_trigger_touch_event")
	if _pending_magic_object_id > 0:
		_finish_pending_magic_stage(next_entry, _script_vm.script_success)
	if _fade_in_after_scene_change and _pending_scene_index < 0 and not _screen_fade_active:
		_fade_in_after_scene_change = false
		_start_screen_fade(false, _automatic_fade_in_duration, false)


func _apply_pending_scene() -> void:
	if _pending_scene_index < 0:
		return
	# 场景请求可能出现在紧随其后的渐隐指令之前。延后到当前渐变结束，保证
	# VM 的完成回调不会被新场景的自动渐显覆盖。
	if _screen_fade_active:
		return
	var scene_index := _pending_scene_index
	_pending_scene_index = -1
	_load_scene(scene_index, true)
	if _fade_in_after_scene_change:
		_fade_in_after_scene_change = false
		_start_screen_fade(false, _automatic_fade_in_duration, false)


func _on_player_sprites_changed() -> void:
	_player_sprites.clear()
	if _tile_world != null:
		_tile_world.reset_sprite_cache()


func _on_script_party_step() -> void:
	_showing_walk_frame = true
	_walk_phase = (_walk_phase + 1) % 4
	_move_cooldown = SCRIPT_FRAME_SECONDS


func _on_script_party_walk_finished() -> void:
	_showing_walk_frame = false
	_move_cooldown = 0.0


func _on_camera_offset_requested(offset: Vector2i) -> void:
	_script_camera_offset = offset
	if _map_data != null and _map_data.is_valid():
		_refresh_world()
		# 官方 007F 每次镜头移动后调用 PAL_MakeScene；0050 留下的
		# fNeedToFadeIn 应在这次画面完成后消费，不能等到稍后的 0005。
		_start_pending_fade_in_after_world_draw()


func _on_magic_use_requested(magic_object_id: int, caster_role_index: int, target_role_index: int) -> void:
	if _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle or _pending_magic_object_id > 0 or _pending_used_item_id > 0:
		return
	var object := _database.magic_object_definition(magic_object_id)
	var definition := _database.magic_definition_for_object(magic_object_id)
	var caster_in_party := caster_role_index in _session.party_roles
	var target_is_valid := target_role_index < 0 or target_role_index in _session.party_roles
	if object == null or definition == null or not caster_in_party or not target_is_valid or not _session.has_magic(caster_role_index, magic_object_id) or not object.is_usable_outside_battle():
		_game_menu.notify_magic_result(false, "这个仙术目前不能使用。")
		return
	if target_role_index < 0 and not object.applies_to_all():
		_game_menu.notify_magic_result(false, "请选择一名队员作为目标。")
		return
	if caster_role_index < 0 or caster_role_index >= _session.role_mp.size() or _session.role_hp[caster_role_index] <= 0 or _session.role_mp[caster_role_index] < definition.mp_cost:
		_game_menu.notify_magic_result(false, "真气不足，或施法者当前无法行动。")
		return
	_game_menu.close_menu()
	_pending_magic_object_id = magic_object_id
	_pending_magic_caster_role = caster_role_index
	_pending_magic_target_role = target_role_index
	_pending_magic_stage = FIELD_MAGIC_STAGE_USE
	_status.text = "施展：%s" % _database.get_word(magic_object_id)
	_run_pending_magic_stage()


func _run_pending_magic_stage() -> void:
	if _pending_magic_object_id <= 0 or _script_vm == null:
		return
	var object := _database.magic_object_definition(_pending_magic_object_id)
	if object == null:
		_complete_pending_magic(false)
		return
	var entry := object.script_on_use if _pending_magic_stage == FIELD_MAGIC_STAGE_USE else object.script_on_success
	if entry <= 0:
		_finish_pending_magic_stage(entry, true)
		return
	# 全体仙术沿用官方事件参数 0；单体仙术传入 PLAYERROLES 角色编号。
	_script_vm.run_trigger(entry, 0 if _pending_magic_target_role < 0 else _pending_magic_target_role)


func _finish_pending_magic_stage(next_entry: int, success: bool) -> void:
	if _pending_magic_object_id <= 0:
		return
	var object := _database.magic_object_definition(_pending_magic_object_id)
	if object == null:
		_complete_pending_magic(false)
		return
	if _pending_magic_stage == FIELD_MAGIC_STAGE_USE:
		object.script_on_use = next_entry
		if not success:
			_complete_pending_magic(false)
			return
		_pending_magic_stage = FIELD_MAGIC_STAGE_SUCCESS
		# script_finished 从 VM 的解释循环内发出；延后一帧避免嵌套启动第二段脚本。
		if is_inside_tree():
			call_deferred("_run_pending_magic_stage")
		return
	object.script_on_success = next_entry
	_complete_pending_magic(success)


func _complete_pending_magic(success: bool) -> void:
	var magic_object_id := _pending_magic_object_id
	var caster_role_index := _pending_magic_caster_role
	var definition := _database.magic_definition_for_object(magic_object_id)
	if success and definition != null and caster_role_index >= 0 and caster_role_index < _session.role_mp.size():
		_session.role_mp[caster_role_index] = maxi(0, _session.role_mp[caster_role_index] - definition.mp_cost)
	_pending_magic_object_id = 0
	_pending_magic_caster_role = -1
	_pending_magic_target_role = -1
	_pending_magic_stage = FIELD_MAGIC_STAGE_USE
	var magic_name := _database.get_word(magic_object_id)
	var feedback := "施展：%s" % magic_name if success else "%s没有生效" % magic_name
	_status.text = feedback
	_game_menu.notify_magic_result(success, feedback)


func _on_item_use_requested(item_id: int) -> void:
	if _script_vm == null or _script_vm.running or _script_vm.waiting_for_dialog or _script_vm.waiting_for_screen_fade or _script_vm.waiting_for_rng or _script_vm.waiting_for_battle or _session.item_count(item_id) <= 0 or _pending_magic_object_id > 0:
		return
	var item := _database.item_definition(item_id)
	if item == null or not item.is_usable():
		return
	_game_menu.close_menu()
	_pending_used_item_id = item_id
	_status.text = "使用：%s" % _database.get_word(item_id)
	_script_vm.run_trigger(item.script_on_use, 0xffff)


func _on_item_equip_requested(item_id: int, role_index: int) -> void:
	var success := _equipment_manager.equip_item(item_id, role_index)
	var item_name := _database.get_word(item_id)
	var feedback := "装备：%s" % item_name if success else _equipment_manager.error_message
	_status.text = feedback
	_game_menu.notify_equipment_result(success, _equipment_manager.last_unequipped_item, feedback)


func _set_error(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", Color("fca5a5"))
