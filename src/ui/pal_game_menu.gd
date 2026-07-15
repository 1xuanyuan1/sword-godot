# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal ui.c, uigame.c and itemmenu.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用原版 UI Sprite、点阵字和物品图标重现经典主菜单与物品页。
## 菜单读取 `GameSession`，实际物品脚本仍交给探索控制器和 `ScriptVM` 执行。
class_name PalGameMenu
extends Control

const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")

## 玩家确认使用物品时发出；接收方负责运行脚本并决定是否消耗。
signal item_use_requested(item_id: int)
## 玩家在系统页调整音乐或音效音量时发出；播放层应立即应用两个百分比。
signal audio_settings_changed(music_volume: int, sound_volume: int)
## 菜单打开、移动或确认时请求播放集中配置的 UI 音效编号。
signal ui_sound_requested(sound_number: int)

enum Page {
	MAIN,
	INVENTORY_ACTION,
	INVENTORY,
	SYSTEM,
}

const MAIN_MENU_POSITION := Vector2i(3, 37)
const MAIN_ITEM_POSITIONS := [Vector2i(16, 50), Vector2i(16, 68), Vector2i(16, 86), Vector2i(16, 104)]
const INVENTORY_ACTION_POSITION := Vector2i(30, 60)
const SYSTEM_MENU_POSITION := Vector2i(40, 60)
const SYSTEM_ITEM_POSITIONS := [Vector2i(53, 72), Vector2i(53, 90), Vector2i(53, 108), Vector2i(53, 126), Vector2i(53, 144)]
const VOLUME_VALUE_X := 170
const VOLUME_STEP := 10
const INVENTORY_COLUMNS := 3
const INVENTORY_ROWS := 7
const INVENTORY_ITEM_WIDTH := 100
const INVENTORY_ROW_HEIGHT := 18
const COLOR_NORMAL := 0x4f
const COLOR_INACTIVE := 0x18
const COLOR_CONFIRMED := 0x2c
const COLOR_SELECTED_INACTIVE := 0x1c
const COLOR_SELECTED_FIRST := 0xf9
const COLOR_EQUIPPED := 0xc8
const UI_FRAME_CURSOR := 69
const UI_FRAME_ITEM_BOX := 70

## 菜单使用的静态文字、UI Sprite 和物品定义。
var database: PalContentDatabase
## 菜单读取的队伍、金钱和背包状态。
var session: GameSession
## 当前菜单页面。
var current_page: Page = Page.MAIN

var _main_selection: int = 2
var _action_selection: int = 1
var _system_selection: int = 2
var _inventory_selection: int = 0
var _inventory_return_page: Page = Page.MAIN
var _inventory_ids: Array[int] = []
var _last_feedback: String = ""
var _ui_sprite: PalSprite
var _palette: PackedByteArray = PackedByteArray()
var _ui_textures: Dictionary = {}
var _item_textures: Dictionary = {}
var _font_texture: Texture2D
var _font_glyphs: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	hide()


## 注入内容数据库和会话；调用后菜单仍保持关闭。
func configure(content_database: PalContentDatabase, game_session: GameSession) -> void:
	database = content_database
	session = game_session
	_load_classic_resources()


## 打开经典主菜单并重置选择位置。
func open_main() -> void:
	if database == null or session == null:
		return
	current_page = Page.MAIN
	show()
	ui_sound_requested.emit(AudioPlayer.SOUND_MENU_OPEN)
	queue_redraw()


## 直接打开物品选择页并重建可用物品列表。
func open_inventory() -> void:
	if database == null or session == null:
		return
	_inventory_return_page = Page.MAIN
	_open_item_selection()
	ui_sound_requested.emit(AudioPlayer.SOUND_MENU_OPEN)


## 关闭整个菜单，返回地图输入。
func close_menu() -> void:
	hide()


## 返回上一级页面；主菜单上调用时关闭菜单。
func go_back() -> void:
	match current_page:
		Page.INVENTORY:
			current_page = _inventory_return_page
			queue_redraw()
		Page.INVENTORY_ACTION:
			current_page = Page.MAIN
			queue_redraw()
		Page.SYSTEM:
			current_page = Page.MAIN
			queue_redraw()
		_:
			close_menu()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo() or event is not InputEventKey:
		return
	var handled := true
	match event.keycode:
		KEY_ESCAPE, KEY_M, KEY_TAB:
			go_back()
		KEY_UP:
			_move_selection(Vector2i(0, -1))
		KEY_DOWN:
			_move_selection(Vector2i(0, 1))
		KEY_LEFT:
			_move_selection(Vector2i(-1, 0))
		KEY_RIGHT:
			_move_selection(Vector2i(1, 0))
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_confirm_selection()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible or event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := Vector2i(event.position)
	match current_page:
		Page.MAIN:
			for index in range(MAIN_ITEM_POSITIONS.size()):
				if Rect2i(MAIN_ITEM_POSITIONS[index] - Vector2i(3, 2), Vector2i(46, 18)).has_point(point):
					_main_selection = index
					_confirm_selection()
					break
		Page.INVENTORY_ACTION:
			for index in range(2):
				if Rect2i(Vector2i(43, 73 + 18 * index) - Vector2i(3, 2), Vector2i(46, 18)).has_point(point):
					_action_selection = index
					_confirm_selection()
					break
		Page.INVENTORY:
			var start := _inventory_page_start()
			for slot in range(mini(INVENTORY_COLUMNS * INVENTORY_ROWS, _inventory_ids.size() - start)):
				var cell := Rect2i(Vector2i(12 + slot % INVENTORY_COLUMNS * INVENTORY_ITEM_WIDTH, 8 + slot / INVENTORY_COLUMNS * INVENTORY_ROW_HEIGHT), Vector2i(96, 18))
				if cell.has_point(point):
					_inventory_selection = start + slot
					_confirm_selection()
					break
		Page.SYSTEM:
			for index in range(SYSTEM_ITEM_POSITIONS.size()):
				if Rect2i(SYSTEM_ITEM_POSITIONS[index] - Vector2i(3, 2), Vector2i(140, 18)).has_point(point):
					_system_selection = index
					_confirm_selection()
					break
	accept_event()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible or database == null or session == null:
		return
	match current_page:
		Page.MAIN:
			_draw_main_menu()
		Page.INVENTORY_ACTION:
			_draw_main_menu()
			_draw_inventory_action()
		Page.INVENTORY:
			_draw_inventory_page()
		Page.SYSTEM:
			_draw_main_menu()
			_draw_system_menu()


func _draw_main_menu() -> void:
	_draw_single_line_box(Vector2i.ZERO, 5, 6)
	_draw_pal_text(database.get_word(21), Vector2i(10, 10), _palette_color(COLOR_NORMAL))
	_draw_number(session.cash, 6, Vector2i(49, 14), 19)
	_draw_classic_box(MAIN_MENU_POSITION, 3, 1, 0, 6)
	for index in range(4):
		var enabled := index in [2, 3]
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _main_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(3 + index), MAIN_ITEM_POSITIONS[index], _palette_color(color_index), true)


func _draw_inventory_action() -> void:
	_draw_classic_box(INVENTORY_ACTION_POSITION, 1, 1, 0, 6)
	for index in range(2):
		var enabled := index == 1
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _action_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(22 + index), Vector2i(43, 73 + 18 * index), _palette_color(color_index), true)


func _draw_inventory_page() -> void:
	_draw_classic_box(Vector2i(2, 0), INVENTORY_ROWS - 1, 17, 1, 0)
	if _inventory_ids.is_empty():
		return
	var start := _inventory_page_start()
	var cursor_position := Vector2i(40, 22)
	for slot in range(mini(INVENTORY_COLUMNS * INVENTORY_ROWS, _inventory_ids.size() - start)):
		var inventory_index := start + slot
		var item_id := _inventory_ids[inventory_index]
		var column := slot % INVENTORY_COLUMNS
		var row := slot / INVENTORY_COLUMNS
		var item := database.item_definition(item_id)
		var enabled := item != null and item.is_usable() and item.applies_to_all()
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if inventory_index == _inventory_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
			cursor_position = Vector2i(40 + column * INVENTORY_ITEM_WIDTH, 22 + row * INVENTORY_ROW_HEIGHT)
		var name := database.get_word(item_id)
		_draw_pal_text(name, Vector2i(15 + column * INVENTORY_ITEM_WIDTH, 12 + row * INVENTORY_ROW_HEIGHT), _palette_color(color_index), true)
		var amount := session.item_count(item_id)
		if amount > 1:
			_draw_number(amount, 2, Vector2i(96 + column * INVENTORY_ITEM_WIDTH, 17 + row * INVENTORY_ROW_HEIGHT), 56)
	_draw_ui_frame(UI_FRAME_CURSOR, cursor_position)
	_draw_ui_frame(UI_FRAME_ITEM_BOX, Vector2i(5, 145), Color(0, 0, 0, 0.7))
	_draw_ui_frame(UI_FRAME_ITEM_BOX, Vector2i(0, 140))
	var selected_item := database.item_definition(_inventory_ids[_inventory_selection])
	if selected_item != null:
		_draw_item_bitmap(selected_item.bitmap, Vector2i(8, 147))
		var description := database.get_item_description(selected_item.object_id)
		var description_y := 150
		for line in description.split("*", false):
			_draw_pal_text(line, Vector2i(75, description_y), _palette_color(0x3c), true)
			description_y += 16


func _draw_system_menu() -> void:
	# 官方系统菜单位于 (40,60)。本项目在原五行布局右侧追加百分比数字，
	# 保留经典窗口与点阵字，而不引入不协调的现代滑块控件。
	_draw_classic_box(SYSTEM_MENU_POSITION, 4, 8, 0, 6)
	for index in range(SYSTEM_ITEM_POSITIONS.size()):
		var enabled := index in [2, 3]
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _system_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(11 + index), SYSTEM_ITEM_POSITIONS[index], _palette_color(color_index), true)
	_draw_number(session.music_volume, 3, Vector2i(VOLUME_VALUE_X, SYSTEM_ITEM_POSITIONS[2].y + 4), 19)
	_draw_number(session.sound_volume, 3, Vector2i(VOLUME_VALUE_X, SYSTEM_ITEM_POSITIONS[3].y + 4), 19)


func _move_selection(direction: Vector2i) -> void:
	match current_page:
		Page.MAIN:
			_main_selection = posmod(_main_selection + (direction.y if direction.y != 0 else direction.x), 4)
		Page.INVENTORY_ACTION:
			_action_selection = posmod(_action_selection + (direction.y if direction.y != 0 else direction.x), 2)
		Page.INVENTORY:
			if _inventory_ids.is_empty():
				return
			var delta := direction.x if direction.x != 0 else direction.y * INVENTORY_COLUMNS
			_inventory_selection = clampi(_inventory_selection + delta, 0, _inventory_ids.size() - 1)
		Page.SYSTEM:
			if direction.x != 0 and _system_selection in [2, 3]:
				_change_selected_volume(direction.x * VOLUME_STEP)
			elif direction.y != 0:
				_system_selection = posmod(_system_selection + direction.y, SYSTEM_ITEM_POSITIONS.size())
	ui_sound_requested.emit(AudioPlayer.SOUND_MENU_MOVE)
	queue_redraw()


func _confirm_selection() -> void:
	ui_sound_requested.emit(AudioPlayer.SOUND_MENU_CONFIRM)
	match current_page:
		Page.MAIN:
			if _main_selection == 2:
				current_page = Page.INVENTORY_ACTION
				_action_selection = 1
			elif _main_selection == 3:
				current_page = Page.SYSTEM
				_system_selection = 2
		Page.INVENTORY_ACTION:
			if _action_selection == 1:
				_inventory_return_page = Page.INVENTORY_ACTION
				_open_item_selection()
		Page.INVENTORY:
			if not _inventory_ids.is_empty():
				var item_id := _inventory_ids[_inventory_selection]
				_request_item_use(item_id, database.item_definition(item_id))
		Page.SYSTEM:
			if _system_selection == 2:
				session.set_music_volume(GameSession.AUDIO_VOLUME_MAX if session.music_volume == 0 else 0)
				audio_settings_changed.emit(session.music_volume, session.sound_volume)
			elif _system_selection == 3:
				session.set_sound_volume(GameSession.AUDIO_VOLUME_MAX if session.sound_volume == 0 else 0)
				audio_settings_changed.emit(session.music_volume, session.sound_volume)
	queue_redraw()


func _change_selected_volume(delta: int) -> void:
	if _system_selection == 2:
		session.change_music_volume(delta)
	elif _system_selection == 3:
		session.change_sound_volume(delta)
	else:
		return
	audio_settings_changed.emit(session.music_volume, session.sound_volume)


func _open_item_selection() -> void:
	_refresh_inventory()
	current_page = Page.INVENTORY
	show()
	queue_redraw()


func _refresh_inventory() -> void:
	_inventory_ids.clear()
	for raw_id in session.inventory:
		var item_id := int(raw_id)
		if session.item_count(item_id) > 0:
			_inventory_ids.append(item_id)
	_inventory_ids.sort()
	_inventory_selection = clampi(_inventory_selection, 0, maxi(0, _inventory_ids.size() - 1))


func _inventory_page_start() -> int:
	var start := int(_inventory_selection / INVENTORY_COLUMNS) * INVENTORY_COLUMNS - INVENTORY_COLUMNS * 4
	return maxi(0, start)


func _request_item_use(item_id: int, item: PalItemDefinition) -> void:
	if item == null or not item.is_usable():
		_last_feedback = "这个物品目前不能使用。"
		return
	if not item.applies_to_all():
		_last_feedback = "这个物品需要先选择角色。"
		return
	item_use_requested.emit(item_id)


func _load_classic_resources() -> void:
	_ui_sprite = database.load_ui_sprite()
	_palette = database.load_palette(session.palette_index, session.night_palette)
	_ui_textures.clear()
	_item_textures.clear()
	_font_glyphs.clear()
	var metadata_path := database.root_path.path_join("text/font_glyphs.json")
	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file != null:
		var parsed = JSON.parse_string(metadata_file.get_as_text())
		if parsed is Dictionary:
			_font_glyphs = parsed.get("glyphs", {})
	var atlas_path := ProjectSettings.globalize_path(database.root_path.path_join("text/font_atlas.png"))
	var atlas_image := Image.load_from_file(atlas_path)
	if not atlas_image.is_empty():
		_font_texture = ImageTexture.create_from_image(atlas_image)


## 返回原版 UI Sprite、字库和调色板是否已成功载入。
func has_classic_resources() -> bool:
	return _ui_sprite != null and _ui_sprite.is_valid() and _ui_sprite.frame_count() > UI_FRAME_ITEM_BOX and _font_texture != null and not _font_glyphs.is_empty()


func _draw_classic_box(position: Vector2i, rows: int, columns: int, style: int, shadow_offset: int) -> void:
	if _ui_sprite == null or not _ui_sprite.is_valid():
		var size := Vector2i(45 + columns * 16, 40 + rows * 18)
		draw_rect(Rect2i(position, size), Color(0.04, 0.06, 0.16, 0.96))
		draw_rect(Rect2i(position, size), Color("b49a58"), false, 1.0)
		return
	var y := position.y
	for row in range(rows + 2):
		var frame_row := 0 if row == 0 else (2 if row == rows + 1 else 1)
		var x := position.x
		var row_height := 0
		for column in range(columns + 2):
			var frame_column := 0 if column == 0 else (2 if column == columns + 1 else 1)
			var texture := _ui_texture(style * 9 + frame_row * 3 + frame_column)
			if texture == null:
				continue
			if shadow_offset > 0:
				draw_texture(texture, Vector2(x + shadow_offset, y + shadow_offset), Color(0, 0, 0, 0.72))
			draw_texture(texture, Vector2(x, y))
			x += texture.get_width()
			row_height = maxi(row_height, texture.get_height())
		y += row_height


func _draw_single_line_box(position: Vector2i, length: int, shadow_offset: int) -> void:
	var x := position.x
	for part in range(length + 2):
		var frame := 44 if part == 0 else (46 if part == length + 1 else 45)
		var texture := _ui_texture(frame)
		if texture == null:
			continue
		if shadow_offset > 0:
			draw_texture(texture, Vector2(x + shadow_offset, position.y + shadow_offset), Color(0, 0, 0, 0.72))
		draw_texture(texture, Vector2(x, position.y))
		x += texture.get_width()


func _draw_ui_frame(frame_index: int, position: Vector2i, modulate: Color = Color.WHITE) -> void:
	var texture := _ui_texture(frame_index)
	if texture != null:
		draw_texture(texture, Vector2(position), modulate)


func _draw_item_bitmap(bitmap_number: int, position: Vector2i) -> void:
	if not _item_textures.has(bitmap_number):
		var indexed := database.load_item_bitmap(bitmap_number)
		_item_textures[bitmap_number] = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() and not _palette.is_empty() else null
	var texture: Texture2D = _item_textures.get(bitmap_number)
	if texture != null:
		draw_texture(texture, Vector2(position))


func _ui_texture(frame_index: int) -> Texture2D:
	if _ui_textures.has(frame_index):
		return _ui_textures[frame_index]
	if _ui_sprite == null or not _ui_sprite.is_valid() or frame_index < 0 or frame_index >= _ui_sprite.frame_count() or _palette.is_empty():
		return null
	var indexed := RleDecoder.decode(_ui_sprite.get_frame(frame_index))
	var texture: Texture2D = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() else null
	_ui_textures[frame_index] = texture
	return texture


func _draw_pal_text(text: String, position: Vector2i, color: Color, shadow: bool = false) -> void:
	if shadow:
		_draw_pal_glyphs(text, position + Vector2i(1, 1), Color(0, 0, 0, 0.9))
	_draw_pal_glyphs(text, position, color)


func _draw_pal_glyphs(text: String, position: Vector2i, color: Color) -> void:
	if _font_texture == null or _font_glyphs.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(position + Vector2i(0, 13)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		return
	var x := position.x
	for character in text:
		var key := str(character)
		if _font_glyphs.has(key):
			var values: Array = _font_glyphs[key]
			var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			draw_texture_rect_region(_font_texture, Rect2(Vector2(x, position.y), region.size), region, color)
			x += 16
		else:
			draw_string(ThemeDB.fallback_font, Vector2(x, position.y + 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			x += 8


func _draw_number(value: int, length: int, position: Vector2i, frame_start: int) -> void:
	var digits := str(maxi(0, value))
	if digits.length() > length:
		digits = digits.right(length)
	var x := position.x + 6 * (length - 1)
	for index in range(digits.length() - 1, -1, -1):
		_draw_ui_frame(frame_start + int(digits[index]), Vector2i(x, position.y))
		x -= 6


func _selected_color_index() -> int:
	return COLOR_SELECTED_FIRST + int(Time.get_ticks_msec() / 100) % 6


func _palette_color(index: int) -> Color:
	if index < 0 or _palette.size() < (index + 1) * 3:
		return Color.WHITE
	return Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2])
