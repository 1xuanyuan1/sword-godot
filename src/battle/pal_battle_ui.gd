# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal uibattle.c, magicmenu.c and ui.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用 DATA.MKF #9 原版 UI Sprite 绘制经典战斗状态框、四向指令、目标生命和仙术列表。
## 本节点只读取战斗状态并绘图；输入状态和战斗结算仍由 `PalBattlePreview` 与控制器持有。
class_name PalBattleUI
extends Control

enum Mode {
	WAITING,
	COMMAND,
	ENEMY_TARGET,
	PLAYER_TARGET,
	MAGIC_LIST,
	MISC_MENU,
	ITEM_ACTION,
	ITEM_LIST,
	REWARD,
	RESULT,
}

const UI_FRAME_PLAYER_INFO := 18
const UI_FRAME_NUMBER_YELLOW := 19
const UI_FRAME_NUMBER_BLUE := 29
const UI_FRAME_SLASH := 39
const UI_FRAME_ACTION_FIRST := 40
const UI_FRAME_PLAYER_FACE_FIRST := 48
const UI_FRAME_NUMBER_CYAN := 56
const UI_FRAME_CURRENT_ARROW_RED := 68
const UI_FRAME_CURRENT_ARROW := 69
const UI_FRAME_SELECTED_ARROW_RED := 66
const UI_FRAME_SELECTED_ARROW := 67
const UI_FRAME_MAGIC_CURSOR := 69
const UI_FRAME_ITEM_BOX := 70
const ACTION_POSITIONS: Array[Vector2i] = [
	Vector2i(27, 140),
	Vector2i(0, 155),
	Vector2i(54, 155),
	Vector2i(27, 170),
]
const PLAYER_INFO_POSITION := Vector2i(91, 165)
const PLAYER_INFO_SPACING := 77
const MAGIC_COLUMNS := 3
const MAGIC_ROWS := 5
const MAGIC_COLUMN_WIDTH := 87
const MAGIC_ROW_HEIGHT := 18
const MISC_ITEM_POSITIONS: Array[Vector2i] = [
	Vector2i(16, 32),
	Vector2i(16, 50),
	Vector2i(16, 68),
	Vector2i(16, 86),
	Vector2i(16, 104),
]
const ITEM_ACTION_POSITIONS: Array[Vector2i] = [Vector2i(44, 62), Vector2i(44, 80)]
const ITEM_COLUMNS := 3
const ITEM_ROWS := 7
const ITEM_COLUMN_WIDTH := 100
const ITEM_ROW_HEIGHT := 18
const COLOR_MENU_NORMAL := 0x4f
const COLOR_MENU_INACTIVE := 0x18
const COLOR_MENU_CONFIRMED := 0x2c
const COLOR_MENU_SELECTED_INACTIVE := 0x1c
const COLOR_MENU_SELECTED_FIRST := 0xf9
const ENEMY_VITALS_RECT := Rect2(8, 8, 82, 40)
const ENEMY_VITALS_BAR_RECT := Rect2(14, 38, 70, 5)

## 战斗使用的只读内容数据库。
var database: PalContentDatabase
## 保存角色 HP、MP、金钱和已学仙术的会话。
var session: GameSession
## 提供当前队伍、指令游标和胜负状态的战斗控制器。
var controller: PalBattleController
## 当前经典战斗 UI 页面。
var mode: Mode = Mode.WAITING
## 四向主行动中的当前选择，依次为攻击、仙术、合击、其他。
var selected_action: int = 0
## 当前选择的敌人索引；敌人本体闪烁由战斗画面处理。
var selected_enemy: int = -1
## 当前选择的队伍位置；我方单体仙术用箭头指示该角色。
var selected_party_index: int = 0
## 当前仙术列表的选择索引。
var selected_magic_index: int = 0
## “其他”菜单当前选择：自动、物品、防御、逃跑、状态。
var selected_misc_index: int = 1
## 物品子菜单当前选择：使用或投掷。
var selected_item_action: int = 0
## 战斗物品列表当前选择索引。
var selected_item_index: int = 0
## 玩家战斗 Sprite 的脚底坐标，用来绘制当前角色箭头。
var player_foot_positions: Array[Vector2i] = []

var _ui_sprite: PalSprite
var _palette: PackedByteArray = PackedByteArray()
var _ui_textures: Dictionary = {}
var _font_texture: Texture2D
var _font_glyphs: Dictionary = {}
var _magic_entries: Array[Dictionary] = []
var _battle_item_ids: Array[int] = []
var _item_list_throwable: bool = false
var _item_textures: Dictionary = {}
var _floating_numbers: Array[Dictionary] = []
var _message: String = ""
var _message_until: int = 0
var _reward: PalBattleController.RewardResult
var _reward_page: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 注入战斗数据和角色脚底坐标，并加载本地生成的官方 UI 与点阵字资源。
## 只读取参数，不修改 `GameSession` 或 `PalBattleController`。
func configure(content_database: PalContentDatabase, game_session: GameSession, battle_controller: PalBattleController, foot_positions: Array[Vector2i]) -> void:
	database = content_database
	session = game_session
	controller = battle_controller
	player_foot_positions = foot_positions.duplicate()
	_load_classic_resources()
	queue_redraw()


## 切换战斗 UI 页面；不会提交任何战斗指令。
func set_mode(next_mode: Mode) -> void:
	mode = next_mode
	queue_redraw()


## 更新四向主行动选择，范围会限制在 0–3。
func set_action_selection(action_index: int) -> void:
	selected_action = clampi(action_index, 0, 3)
	queue_redraw()


## 更新敌人选择索引；目标模式会据此读取本场敌人的名称和当前体力。
func set_enemy_selection(enemy_index: int) -> void:
	selected_enemy = enemy_index
	queue_redraw()


## 返回当前目标选择阶段显示的敌人信息；其他阶段或索引无效时返回空字典。
## 只读取控制器内的本场状态，不修改敌人体力或战斗进度。
func selected_enemy_vitals() -> Dictionary:
	if mode != Mode.ENEMY_TARGET or controller == null or database == null or selected_enemy < 0 or selected_enemy >= controller.enemies.size():
		return {}
	var enemy := controller.enemies[selected_enemy]
	if enemy == null or not enemy.is_alive():
		return {}
	return {
		"object_id": enemy.object_id,
		"name": database.get_word(enemy.object_id),
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
	}


## 根据指定角色的已学仙术重建经典 3×5 列表，并切换到仙术页面。
## 无效对象仍会被跳过；列表按 OBJECT 对象编号升序排列，与 SDLPal 一致。
func open_magic_list(role_index: int) -> void:
	_magic_entries.clear()
	selected_magic_index = 0
	if database != null and session != null and role_index >= 0 and role_index < session.learned_magics_by_role.size():
		var object_ids := session.learned_magics_by_role[role_index].duplicate()
		object_ids.sort()
		var current_mp := session.role_mp[role_index] if role_index < session.role_mp.size() else 0
		for object_id in object_ids:
			var object := database.magic_object_definition(object_id)
			var definition := database.magic_definition_for_object(object_id)
			if object == null or definition == null:
				continue
			_magic_entries.append({
				"object_id": object_id,
				"mp_cost": definition.mp_cost,
				"enabled": object.is_usable_in_battle() and definition.mp_cost <= current_mp and controller != null and controller.can_pending_player_use_magic(object_id),
			})
	mode = Mode.MAGIC_LIST
	queue_redraw()


## 按经典 3 列网格移动仙术光标；空列表保持在零。
func move_magic_selection(column_delta: int, row_delta: int) -> void:
	if _magic_entries.is_empty():
		selected_magic_index = 0
		return
	var candidate := selected_magic_index + column_delta + row_delta * MAGIC_COLUMNS
	selected_magic_index = clampi(candidate, 0, _magic_entries.size() - 1)
	queue_redraw()


## 返回当前仙术对象编号；列表为空时返回 0。
func selected_magic_object() -> int:
	return int(_magic_entries[selected_magic_index].get("object_id", 0)) if selected_magic_index >= 0 and selected_magic_index < _magic_entries.size() else 0


## 返回当前仙术是否同时满足战斗标志和 MP 消耗；列表为空时为 `false`。
func selected_magic_enabled() -> bool:
	return bool(_magic_entries[selected_magic_index].get("enabled", false)) if selected_magic_index >= 0 and selected_magic_index < _magic_entries.size() else false


## 打开经典“其他”菜单，保留上一次选择位置。
func open_misc_menu() -> void:
	selected_misc_index = clampi(selected_misc_index, 0, MISC_ITEM_POSITIONS.size() - 1)
	mode = Mode.MISC_MENU
	queue_redraw()


## 循环移动“其他”菜单光标。
func move_misc_selection(step: int) -> void:
	selected_misc_index = posmod(selected_misc_index + step, MISC_ITEM_POSITIONS.size())
	queue_redraw()


## 打开“使用／投掷”物品子菜单。
func open_item_action_menu() -> void:
	selected_item_action = clampi(selected_item_action, 0, 1)
	mode = Mode.ITEM_ACTION
	queue_redraw()


## 在“使用／投掷”之间移动选择。
func move_item_action_selection(step: int) -> void:
	selected_item_action = posmod(selected_item_action + step, 2)
	queue_redraw()


## 打开战斗物品列表；`throwable` 为真时按投掷脚本判断可用状态。
func open_item_list(throwable: bool) -> void:
	_item_list_throwable = throwable
	_refresh_battle_items()
	mode = Mode.ITEM_LIST
	queue_redraw()


## 按经典 3×7 网格移动战斗物品光标。
func move_item_selection(column_delta: int, row_delta: int) -> void:
	if _battle_item_ids.is_empty():
		selected_item_index = 0
		return
	selected_item_index = clampi(selected_item_index + column_delta + row_delta * ITEM_COLUMNS, 0, _battle_item_ids.size() - 1)
	queue_redraw()


## 返回当前战斗物品对象编号；列表为空时返回 0。
func selected_item_object() -> int:
	return _battle_item_ids[selected_item_index] if selected_item_index >= 0 and selected_item_index < _battle_item_ids.size() else 0


## 返回当前物品在本回合剩余数量与已支持脚本下是否可提交。
func selected_item_enabled() -> bool:
	var item_id := selected_item_object()
	if item_id <= 0 or controller == null:
		return false
	return controller.can_pending_player_throw_item(item_id) if _item_list_throwable else controller.can_pending_player_use_item(item_id)


## 更新我方单体目标的队伍位置，并重绘选中箭头。
func set_player_selection(party_index: int) -> void:
	selected_party_index = clampi(party_index, 0, maxi(0, player_foot_positions.size() - 1))
	queue_redraw()


## 在指定 PAL 坐标显示一个上浮数字；`frame_start` 应为 19、29 或 56。
func show_number(value: int, position: Vector2i, frame_start: int = UI_FRAME_NUMBER_BLUE) -> void:
	if value <= 0:
		return
	_floating_numbers.append({
		"value": value,
		"position": position,
		"frame_start": frame_start,
		"started": Time.get_ticks_msec(),
	})
	queue_redraw()


## 显示经典单行提示窗；`duration_ms <= 0` 时保留到下一次清除。
func show_message(text: String, duration_ms: int = 0) -> void:
	_message = text
	_message_until = Time.get_ticks_msec() + duration_ms if duration_ms > 0 else 0
	queue_redraw()


## 清除当前单行提示窗。
func clear_message() -> void:
	_message = ""
	_message_until = 0
	queue_redraw()


## 打开经典战后结算页；第 0 页为总经验/金钱，之后依次显示升级和习得仙术。
## 只读取已由控制器结算的报告，不会再次修改 `GameSession`。
func show_reward(reward: PalBattleController.RewardResult) -> void:
	_reward = reward
	_reward_page = 0
	mode = Mode.REWARD
	clear_message()
	queue_redraw()


## 推进一个战后结算页面；已越过最后一页时返回 `true`，调用方可以退出战斗。
func advance_reward_page() -> bool:
	if _reward == null:
		return true
	_reward_page += 1
	var page_count := 1 + _reward.level_ups.size() + _reward.learned_magics.size()
	queue_redraw()
	return _reward_page >= page_count


## 返回官方 UI Sprite、点阵字和调色板是否全部成功载入。
func has_classic_resources() -> bool:
	return _ui_sprite != null and _ui_sprite.is_valid() and _ui_sprite.frame_count() > UI_FRAME_ITEM_BOX and _font_texture != null and not _font_glyphs.is_empty()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _message_until > 0 and now >= _message_until:
		_message = ""
		_message_until = 0
	for index in range(_floating_numbers.size() - 1, -1, -1):
		if now - int(_floating_numbers[index].get("started", now)) > 440:
			_floating_numbers.remove_at(index)
	queue_redraw()


func _draw() -> void:
	if database == null or session == null or controller == null:
		return
	# 物品页的说明区占用屏幕底部；经典 ItemSelectMenu 打开时不叠加角色状态框。
	if controller.is_accepting_commands() and mode != Mode.ITEM_LIST:
		_draw_player_status_boxes()
		_draw_current_player_arrow()
		if mode == Mode.PLAYER_TARGET:
			_draw_selected_player_arrow()
	if mode == Mode.COMMAND:
		_draw_action_icons()
	elif mode == Mode.ENEMY_TARGET:
		_draw_enemy_vitals()
	elif mode == Mode.MAGIC_LIST:
		_draw_magic_menu()
	elif mode == Mode.MISC_MENU:
		_draw_misc_menu()
	elif mode == Mode.ITEM_ACTION:
		_draw_misc_menu(1)
		_draw_item_action_menu()
	elif mode == Mode.ITEM_LIST:
		_draw_item_list()
	elif mode == Mode.REWARD:
		_draw_reward_page()
	_draw_floating_numbers()
	if not _message.is_empty():
		_draw_message_box(_message)


func _draw_player_status_boxes() -> void:
	for player in controller.players:
		var role_index: int = player.role_index
		var position := PLAYER_INFO_POSITION + Vector2i(PLAYER_INFO_SPACING * player.party_index, 0)
		_draw_ui_frame(UI_FRAME_PLAYER_INFO, position)
		_draw_ui_frame(UI_FRAME_PLAYER_FACE_FIRST + role_index, position + Vector2i(-2, -4))
		_draw_ui_frame(UI_FRAME_SLASH, position + Vector2i(49, 6))
		_draw_number(session.role_max_hp[role_index], 4, position + Vector2i(47, 8), UI_FRAME_NUMBER_YELLOW)
		_draw_number(session.role_hp[role_index], 4, position + Vector2i(26, 5), UI_FRAME_NUMBER_YELLOW)
		_draw_ui_frame(UI_FRAME_SLASH, position + Vector2i(49, 22))
		_draw_number(session.role_max_mp[role_index], 4, position + Vector2i(47, 24), UI_FRAME_NUMBER_CYAN)
		_draw_number(session.role_mp[role_index], 4, position + Vector2i(26, 21), UI_FRAME_NUMBER_CYAN)


func _draw_current_player_arrow() -> void:
	var party_index := controller.pending_party_index()
	if party_index < 0 or party_index >= player_foot_positions.size():
		return
	var frame := UI_FRAME_CURRENT_ARROW_RED if int(Time.get_ticks_msec() / 80) % 2 == 0 else UI_FRAME_CURRENT_ARROW
	_draw_ui_frame(frame, player_foot_positions[party_index] + Vector2i(-8, -74))


func _draw_selected_player_arrow() -> void:
	if selected_party_index < 0 or selected_party_index >= player_foot_positions.size():
		return
	var frame := UI_FRAME_SELECTED_ARROW_RED if int(Time.get_ticks_msec() / 80) % 2 == 0 else UI_FRAME_SELECTED_ARROW
	_draw_ui_frame(frame, player_foot_positions[selected_party_index] + Vector2i(-8, -67))


func _draw_action_icons() -> void:
	var valid := [true, not _magic_entries_for_pending_role().is_empty(), controller != null and controller.can_pending_player_use_cooperative_magic(), true]
	for index in range(4):
		if index == selected_action:
			_draw_ui_frame(UI_FRAME_ACTION_FIRST + index, ACTION_POSITIONS[index])
		elif valid[index]:
			_draw_ui_frame(UI_FRAME_ACTION_FIRST + index, ACTION_POSITIONS[index], 0x00, -4)
		else:
			_draw_ui_frame(UI_FRAME_ACTION_FIRST + index, ACTION_POSITIONS[index], 0x10, -4)


func _draw_enemy_vitals() -> void:
	var vitals := selected_enemy_vitals()
	if vitals.is_empty():
		return
	var hp := maxi(0, int(vitals.get("hp", 0)))
	var max_hp := maxi(1, int(vitals.get("max_hp", 1)))
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	# 原版不显示敌人体力；这里使用不依赖外部素材的像素面板，并限制在目标闪烁阶段，
	# 避免覆盖行动动画或改变经典状态框的布局。
	draw_rect(ENEMY_VITALS_RECT, Color(0.015, 0.025, 0.055, 0.9), true)
	draw_rect(ENEMY_VITALS_RECT, _palette_color(COLOR_MENU_NORMAL), false, 1.0)
	var enemy_name := str(vitals.get("name", ""))
	_draw_pal_text(enemy_name if not enemy_name.is_empty() else "敌人", Vector2i(14, 13), _palette_color(COLOR_MENU_NORMAL), true)
	_draw_number(hp, 5, Vector2i(14, 28), UI_FRAME_NUMBER_YELLOW)
	_draw_ui_frame(UI_FRAME_SLASH, Vector2i(45, 27))
	_draw_number(max_hp, 5, Vector2i(52, 30), UI_FRAME_NUMBER_BLUE)
	draw_rect(ENEMY_VITALS_BAR_RECT, Color(0, 0, 0, 0.92), true)
	var inner := Rect2(ENEMY_VITALS_BAR_RECT.position + Vector2(1, 1), ENEMY_VITALS_BAR_RECT.size - Vector2(2, 2))
	draw_rect(inner, Color(0.14, 0.14, 0.16, 1.0), true)
	if hp > 0:
		draw_rect(Rect2(inner.position, Vector2(maxf(1.0, floorf(inner.size.x * ratio)), inner.size.y)), Color8(224, 64, 64), true)


func _draw_magic_menu() -> void:
	_draw_single_line_box(Vector2i.ZERO, 5, 0)
	_draw_pal_text(database.get_word(21), Vector2i(10, 10), _palette_color(COLOR_MENU_NORMAL))
	_draw_number(session.cash, 6, Vector2i(49, 14), UI_FRAME_NUMBER_YELLOW)
	_draw_single_line_box(Vector2i(215, 0), 5, 0)
	var party_index := controller.pending_party_index()
	var role_index := controller.pending_role_index()
	var current_mp := session.role_mp[role_index] if role_index >= 0 and role_index < session.role_mp.size() else 0
	var needed_mp := int(_magic_entries[selected_magic_index].get("mp_cost", 0)) if selected_magic_index >= 0 and selected_magic_index < _magic_entries.size() else 0
	_draw_ui_frame(UI_FRAME_SLASH, Vector2i(260, 14))
	_draw_number(needed_mp, 4, Vector2i(230, 14), UI_FRAME_NUMBER_YELLOW)
	_draw_number(current_mp, 4, Vector2i(265, 14), UI_FRAME_NUMBER_CYAN)
	_draw_classic_box(Vector2i(10, 42), MAGIC_ROWS - 1, 16, 1)
	for index in range(mini(MAGIC_ROWS * MAGIC_COLUMNS, _magic_entries.size())):
		var entry := _magic_entries[index]
		var enabled := bool(entry.get("enabled", false))
		var color_index := COLOR_MENU_NORMAL if enabled else COLOR_MENU_INACTIVE
		if index == selected_magic_index:
			color_index = _selected_color_index() if enabled else COLOR_MENU_SELECTED_INACTIVE
		var column := index % MAGIC_COLUMNS
		var row := index / MAGIC_COLUMNS
		var position := Vector2i(35 + column * MAGIC_COLUMN_WIDTH, 54 + row * MAGIC_ROW_HEIGHT)
		_draw_pal_text(database.get_word(int(entry.get("object_id", 0))), position, _palette_color(color_index), true)
		if index == selected_magic_index:
			_draw_ui_frame(UI_FRAME_MAGIC_CURSOR, position + Vector2i(25, 10))
	if _magic_entries.is_empty():
		_draw_pal_text("没有可用仙术", Vector2i(35, 54), _palette_color(COLOR_MENU_INACTIVE), true)


func _draw_misc_menu(confirmed_index: int = -1) -> void:
	_draw_classic_box(Vector2i(2, 20), 4, 1, 0)
	var word_ids := [56, 57, 58, 59, 60]
	var enabled := [false, true, true, true, false]
	for index in range(word_ids.size()):
		var color_index := COLOR_MENU_NORMAL if enabled[index] else COLOR_MENU_INACTIVE
		if index == confirmed_index:
			color_index = COLOR_MENU_CONFIRMED
		elif index == selected_misc_index:
			color_index = _selected_color_index() if enabled[index] else COLOR_MENU_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(word_ids[index]), MISC_ITEM_POSITIONS[index], _palette_color(color_index), true)


func _draw_item_action_menu() -> void:
	_draw_classic_box(Vector2i(30, 50), 1, 1, 0)
	for index in range(2):
		var color_index := _selected_color_index() if index == selected_item_action else COLOR_MENU_NORMAL
		_draw_pal_text(database.get_word(23 + index), ITEM_ACTION_POSITIONS[index], _palette_color(color_index), true)


func _draw_item_list() -> void:
	_draw_classic_box(Vector2i(2, 0), ITEM_ROWS - 1, 17, 1)
	if _battle_item_ids.is_empty():
		_draw_pal_text("没有可用物品", Vector2i(15, 12), _palette_color(COLOR_MENU_INACTIVE), true)
		return
	var start := _item_page_start()
	var cursor_position := Vector2i(40, 22)
	for slot in range(mini(ITEM_COLUMNS * ITEM_ROWS, _battle_item_ids.size() - start)):
		var inventory_index := start + slot
		var item_id := _battle_item_ids[inventory_index]
		var column := slot % ITEM_COLUMNS
		var row := slot / ITEM_COLUMNS
		var enabled := controller.can_pending_player_throw_item(item_id) if _item_list_throwable else controller.can_pending_player_use_item(item_id)
		var color_index := COLOR_MENU_NORMAL if enabled else COLOR_MENU_INACTIVE
		if inventory_index == selected_item_index:
			color_index = _selected_color_index() if enabled else COLOR_MENU_SELECTED_INACTIVE
			cursor_position = Vector2i(40 + column * ITEM_COLUMN_WIDTH, 22 + row * ITEM_ROW_HEIGHT)
		_draw_pal_text(database.get_word(item_id), Vector2i(15 + column * ITEM_COLUMN_WIDTH, 12 + row * ITEM_ROW_HEIGHT), _palette_color(color_index), true)
		var amount := controller.available_item_count(item_id)
		if amount > 1:
			_draw_number(amount, 2, Vector2i(96 + column * ITEM_COLUMN_WIDTH, 17 + row * ITEM_ROW_HEIGHT), UI_FRAME_NUMBER_CYAN)
	_draw_ui_frame(UI_FRAME_MAGIC_CURSOR, cursor_position)
	_draw_ui_frame(UI_FRAME_ITEM_BOX, Vector2i(5, 145), -1, 0)
	var selected_item := database.item_definition(selected_item_object())
	if selected_item == null:
		return
	_draw_item_bitmap(selected_item.bitmap, Vector2i(8, 147))
	var description_y := 150
	for line in database.get_item_description(selected_item.object_id).split("*", false):
		_draw_pal_text(line, Vector2i(75, description_y), _palette_color(0x3c), true)
		description_y += 16


func _draw_reward_page() -> void:
	if _reward == null:
		return
	if _reward_page == 0:
		_draw_reward_summary()
		return
	var detail_index := _reward_page - 1
	if detail_index < _reward.level_ups.size():
		_draw_level_up(_reward.level_ups[detail_index])
		return
	detail_index -= _reward.level_ups.size()
	if detail_index >= 0 and detail_index < _reward.learned_magics.size():
		_draw_learned_magic(_reward.learned_magics[detail_index])


func _draw_reward_summary() -> void:
	var experience_label := database.get_word(30)
	var label_width := _pal_text_width(experience_label)
	var box_length := maxi(6, ceili((label_width + 54) / 16.0))
	var box_x := 160 - (box_length * 16 + 16) / 2
	_draw_single_line_box(Vector2i(box_x, 60), box_length, 0)
	_draw_pal_text(experience_label, Vector2i(box_x + 10, 70), _palette_color(COLOR_MENU_NORMAL), true)
	_draw_number(_reward.experience, 5, Vector2i(box_x + box_length * 16 - 34, 74), UI_FRAME_NUMBER_YELLOW)
	_draw_single_line_box(Vector2i(65, 105), 10, 0)
	_draw_pal_text(database.get_word(9), Vector2i(77, 115), _palette_color(COLOR_MENU_NORMAL), true)
	_draw_number(_reward.cash, 5, Vector2i(132, 119), UI_FRAME_NUMBER_YELLOW)
	_draw_pal_text(database.get_word(10), Vector2i(197, 115), _palette_color(COLOR_MENU_NORMAL), true)


func _draw_level_up(level_up: PalBattleController.LevelUpResult) -> void:
	var role_name := database.get_word(database.player_roles.name_word_for(level_up.role_index))
	var title := role_name + database.get_word(48) + database.get_word(32)
	_draw_single_line_box(Vector2i(50, 0), 13, 0)
	_draw_pal_text(title, Vector2i(160 - _pal_text_width(title) / 2, 10), _palette_color(COLOR_MENU_NORMAL), true)
	_draw_classic_box(Vector2i(50, 32), 7, 12, 1)
	var labels := [48, 49, 50, 51, 52, 53, 54, 55]
	for stat_index in range(labels.size()):
		var y := 44 + stat_index * 18
		_draw_pal_text(database.get_word(labels[stat_index]), Vector2i(62, y), _palette_color(0xbb), true)
		_draw_ui_frame(47, Vector2i(174, y + 4))
		if stat_index in [PalBattleController.REWARD_STAT_MAX_HP, PalBattleController.REWARD_STAT_MAX_MP]:
			var old_current := level_up.old_hp if stat_index == PalBattleController.REWARD_STAT_MAX_HP else level_up.old_mp
			var new_current := level_up.new_hp if stat_index == PalBattleController.REWARD_STAT_MAX_HP else level_up.new_mp
			_draw_number(old_current, 4, Vector2i(112, y + 3), UI_FRAME_NUMBER_YELLOW)
			_draw_ui_frame(UI_FRAME_SLASH, Vector2i(134, y + 5))
			_draw_number(level_up.old_stats[stat_index], 4, Vector2i(142, y + 7), UI_FRAME_NUMBER_BLUE)
			_draw_number(new_current, 4, Vector2i(194, y + 3), UI_FRAME_NUMBER_YELLOW)
			_draw_ui_frame(UI_FRAME_SLASH, Vector2i(216, y + 5))
			_draw_number(level_up.new_stats[stat_index], 4, Vector2i(226, y + 7), UI_FRAME_NUMBER_BLUE)
		else:
			_draw_number(level_up.old_stats[stat_index], 4, Vector2i(132, y + 3), UI_FRAME_NUMBER_YELLOW)
			_draw_number(level_up.new_stats[stat_index], 4, Vector2i(212, y + 3), UI_FRAME_NUMBER_YELLOW)


func _draw_learned_magic(learned: PalBattleController.LearnedMagicResult) -> void:
	var role_name := database.get_word(database.player_roles.name_word_for(learned.role_index))
	var message := role_name + database.get_word(33) + database.get_word(learned.magic_object_id)
	var width := _pal_text_width(message)
	var box_length := maxi(8, ceili(width / 16.0))
	var box_x := 160 - (box_length * 16 + 16) / 2
	_draw_single_line_box(Vector2i(box_x, 105), box_length, 0)
	_draw_pal_text(message, Vector2i(box_x + 10, 115), _palette_color(COLOR_MENU_NORMAL), true)


func _draw_floating_numbers() -> void:
	var now := Time.get_ticks_msec()
	for number in _floating_numbers:
		var elapsed_frames := int((now - int(number.get("started", now))) / 40)
		var position: Vector2i = number.get("position", Vector2i.ZERO)
		position.y -= elapsed_frames
		_draw_number(int(number.get("value", 0)), 5, position, int(number.get("frame_start", UI_FRAME_NUMBER_BLUE)))


func _draw_message_box(text: String) -> void:
	var width := _pal_text_width(text)
	var interior := maxi(1, ceili(width / 16.0))
	var position := Vector2i(160 - (interior * 16 + 16) / 2, 40)
	_draw_single_line_box(position, interior, 0)
	_draw_pal_text(text, position + Vector2i(8 + maxi(0, (interior * 16 - width) / 2), 10), _palette_color(COLOR_MENU_NORMAL), true)


func _magic_entries_for_pending_role() -> PackedInt32Array:
	var role_index := controller.pending_role_index()
	if role_index < 0 or role_index >= session.learned_magics_by_role.size():
		return PackedInt32Array()
	return session.learned_magics_by_role[role_index]


func _refresh_battle_items() -> void:
	_battle_item_ids.clear()
	for raw_id in session.inventory:
		var item_id := int(raw_id)
		if session.item_count(item_id) > 0:
			_battle_item_ids.append(item_id)
	_battle_item_ids.sort()
	selected_item_index = clampi(selected_item_index, 0, maxi(0, _battle_item_ids.size() - 1))


func _item_page_start() -> int:
	var start := int(selected_item_index / ITEM_COLUMNS) * ITEM_COLUMNS - ITEM_COLUMNS * 4
	return maxi(0, start)


func _load_classic_resources() -> void:
	_ui_sprite = database.load_ui_sprite()
	_palette = database.load_palette(session.palette_index, session.night_palette)
	_ui_textures.clear()
	_item_textures.clear()
	_font_glyphs.clear()
	var metadata_file := FileAccess.open(database.root_path.path_join("text/font_glyphs.json"), FileAccess.READ)
	if metadata_file != null:
		var parsed = JSON.parse_string(metadata_file.get_as_text())
		if parsed is Dictionary:
			_font_glyphs = parsed.get("glyphs", {})
	var atlas_image := Image.load_from_file(ProjectSettings.globalize_path(database.root_path.path_join("text/font_atlas.png")))
	if not atlas_image.is_empty():
		_font_texture = ImageTexture.create_from_image(atlas_image)


func _draw_classic_box(position: Vector2i, rows: int, columns: int, style: int) -> void:
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


func _draw_ui_frame(frame_index: int, position: Vector2i, mono_high_nibble: int = -1, low_shift: int = 0) -> void:
	var texture := _ui_texture(frame_index, mono_high_nibble, low_shift)
	if texture != null:
		draw_texture(texture, Vector2(position))


func _draw_item_bitmap(bitmap_number: int, position: Vector2i) -> void:
	if not _item_textures.has(bitmap_number):
		var indexed := database.load_item_bitmap(bitmap_number)
		_item_textures[bitmap_number] = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() and not _palette.is_empty() else null
	var texture: Texture2D = _item_textures.get(bitmap_number)
	if texture != null:
		draw_texture(texture, Vector2(position))


func _ui_texture(frame_index: int, mono_high_nibble: int = -1, low_shift: int = 0) -> Texture2D:
	var cache_key := "%d:%d:%d" % [frame_index, mono_high_nibble, low_shift]
	if _ui_textures.has(cache_key):
		return _ui_textures[cache_key]
	if _ui_sprite == null or not _ui_sprite.is_valid() or frame_index < 0 or frame_index >= _ui_sprite.frame_count() or _palette.is_empty():
		return null
	var indexed := RleDecoder.decode(_ui_sprite.get_frame(frame_index))
	if mono_high_nibble >= 0 and indexed.is_valid():
		indexed = _mono_color_image(indexed, mono_high_nibble, low_shift)
	var texture: Texture2D = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() else null
	_ui_textures[cache_key] = texture
	return texture


func _mono_color_image(source: PalIndexedImage, high_nibble: int, low_shift: int) -> PalIndexedImage:
	var result := PalIndexedImage.new()
	result.width = source.width
	result.height = source.height
	result.indices = source.indices.duplicate()
	result.opacity = source.opacity.duplicate()
	for index in range(result.indices.size()):
		if result.opacity[index] == 0:
			continue
		var low := clampi((result.indices[index] & 0x0f) + low_shift, 0, 15)
		result.indices[index] = (high_nibble & 0xf0) | low
	return result


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


func _pal_text_width(text: String) -> int:
	var width := 0
	for character in text:
		width += 16 if _font_glyphs.has(str(character)) else 8
	return width


func _selected_color_index() -> int:
	return COLOR_MENU_SELECTED_FIRST + int(Time.get_ticks_msec() / 100) % 6


func _palette_color(index: int) -> Color:
	if index < 0 or _palette.size() < (index + 1) * 3:
		return Color.WHITE
	return Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2])
