# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal ui.c, uigame.c and itemmenu.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用原版 UI Sprite、点阵字和物品图标重现经典主菜单与物品页。
## 菜单读取 `GameSession`，实际物品脚本仍交给探索控制器和 `ScriptVM` 执行。
class_name PalGameMenu
extends Control

const RoleConditionDisplay := preload("res://src/ui/pal_role_condition_display.gd")
const MobileInput := preload("res://src/ui/pal_mobile_input.gd")
const MOBILE_BACK_ICON: Texture2D = preload("res://assets/ui/mobile/back.png")

## 玩家确认使用物品时发出；接收方负责运行脚本并决定是否消耗。
signal item_use_requested(item_id: int)
## 玩家在装备页确认角色时发出；接收方负责运行装备脚本和交换背包物品。
signal item_equip_requested(item_id: int, role_index: int)
## 玩家确认场外仙术及目标时发出；接收方负责执行使用/成功脚本并扣除真气。
## `target_role_index` 为 -1 表示仙术作用于全队。
signal magic_use_requested(magic_object_id: int, caster_role_index: int, target_role_index: int)
## 玩家在 100 槽分页菜单确认保存时发出；接收方负责写入用户目录。
signal save_slot_requested(slot: int)
## 玩家在 100 槽分页菜单确认有效存档时发出；接收方负责恢复场景和运行时状态。
signal load_slot_requested(slot: int)
## 直接打开的读档页被取消（用于 004E 无活动槽回退）。
signal load_menu_cancelled
## 000A 经典“是/否”选择结果。
signal confirmation_completed(accepted: bool)
## 0026/0027 商店关闭后通知 ScriptVM 恢复。
signal shop_closed
## 玩家在系统页调整音乐或音效音量时发出；播放层应立即应用两个百分比。
signal audio_settings_changed(music_volume: int, sound_volume: int)

enum Page {
	MAIN,
	INVENTORY_ACTION,
	INVENTORY,
	EQUIPMENT,
	SYSTEM,
	STATUS,
	MAGIC_CASTER,
	MAGIC_LIST,
	MAGIC_TARGET,
	SAVE_SLOTS,
	LOAD_SLOTS,
	CONFIRM,
	SHOP_BUY,
	SHOP_SELL,
}

const MAIN_MENU_POSITION := Vector2i(3, 37)
const MOBILE_BACK_RECT := Rect2(276, 2, 40, 30)
const MAIN_ITEM_POSITIONS := [Vector2i(16, 50), Vector2i(16, 68), Vector2i(16, 86), Vector2i(16, 104)]
const INVENTORY_ACTION_POSITION := Vector2i(30, 60)
const SYSTEM_MENU_POSITION := Vector2i(40, 60)
const SYSTEM_ITEM_POSITIONS := [Vector2i(53, 72), Vector2i(53, 90), Vector2i(53, 108), Vector2i(53, 126), Vector2i(53, 144)]
const VOLUME_VALUE_X := 170
const VOLUME_STEP := 10
const SAVE_SLOT_BOX_POSITION := Vector2i(184, 7)
const SAVE_SLOT_TEXT_POSITION := Vector2i(195, 17)
const SAVE_SLOT_ROW_HEIGHT := 38
const SAVE_SLOT_COUNT_POSITION_X := 276
const SAVE_DETAIL_TEXT_WIDTH := 136
const SAVE_DETAIL_PARTY_POSITION := Vector2i(12, 92)
const SAVE_DETAIL_PARTY_SPACING := 28
const INVENTORY_COLUMNS := 3
const INVENTORY_ROWS := 7
const INVENTORY_ITEM_WIDTH := 100
const INVENTORY_ROW_HEIGHT := 18
const EQUIPMENT_IMAGE_POSITION := Vector2i(16, 16)
const EQUIPMENT_ROLE_LIST_POSITION := Vector2i(2, 95)
const EQUIPMENT_ITEM_NAME_POSITION := Vector2i(5, 70)
const EQUIPMENT_ITEM_AMOUNT_POSITION := Vector2i(51, 57)
const EQUIPMENT_LABEL_POSITIONS := [Vector2i(92, 11), Vector2i(92, 33), Vector2i(92, 55), Vector2i(92, 77), Vector2i(92, 99), Vector2i(92, 121)]
const EQUIPMENT_NAME_POSITIONS := [Vector2i(130, 11), Vector2i(130, 33), Vector2i(130, 55), Vector2i(130, 77), Vector2i(130, 99), Vector2i(130, 121)]
const EQUIPMENT_STATUS_LABEL_POSITIONS := [Vector2i(226, 10), Vector2i(226, 32), Vector2i(226, 54), Vector2i(226, 76), Vector2i(226, 98)]
const EQUIPMENT_STATUS_VALUE_POSITIONS := [Vector2i(260, 14), Vector2i(260, 36), Vector2i(260, 58), Vector2i(260, 80), Vector2i(260, 102)]
const EQUIPMENT_LABEL_WORDS := [600, 602, 601, 603, 604, 605]
const EQUIPMENT_STATUS_WORDS := [51, 52, 53, 54, 55]
const STATUS_LABEL_WORDS := [2, 48, 49, 50]
const STATUS_LABEL_POSITIONS := [Vector2i(6, 6), Vector2i(6, 32), Vector2i(6, 54), Vector2i(6, 76)]
const STATUS_STAT_POSITIONS := [Vector2i(42, 102), Vector2i(42, 122), Vector2i(42, 142), Vector2i(42, 162), Vector2i(42, 182)]
const STATUS_EQUIPMENT_IMAGE_POSITIONS := [Vector2i(189, -1), Vector2i(247, 39), Vector2i(251, 101), Vector2i(201, 133), Vector2i(141, 141), Vector2i(81, 125)]
const STATUS_EQUIPMENT_NAME_POSITIONS := [Vector2i(195, 38), Vector2i(253, 78), Vector2i(257, 140), Vector2i(207, 172), Vector2i(147, 180), Vector2i(87, 164)]
const STATUS_POISON_POSITIONS := [Vector2i(185, 58), Vector2i(185, 76), Vector2i(185, 94), Vector2i(185, 112), Vector2i(185, 130), Vector2i(185, 148), Vector2i(185, 166), Vector2i(185, 184)]
const MAGIC_COLUMNS := 3
const MAGIC_ROWS := 5
const MAGIC_COLUMN_WIDTH := 87
const MAGIC_ROW_HEIGHT := 18
const MAGIC_CASTER_BOX_POSITION := Vector2i(35, 62)
const MAGIC_CASTER_NAME_POSITION := Vector2i(48, 75)
const MAGIC_PLAYER_INFO_POSITION := Vector2i(45, 165)
const MAGIC_PLAYER_INFO_SPACING := 78
const SHOP_BOX_POSITION := Vector2i(122, 8)
const SHOP_BOX_ROWS := 8
const SHOP_BOX_COLUMNS := 8
const SHOP_ITEM_NAME_POSITION := Vector2i(136, 21)
const SHOP_PRICE_POSITION := Vector2i(238, 26)
const SHOP_ROW_HEIGHT := 18
const SHOP_PRICE_DIGITS := 6
const SHOP_NUMBER_DIGIT_WIDTH := 6
const SHOP_CONTENT_RIGHT := 276
const SHOP_ITEM_HITBOX_POSITION := Vector2i(128, 14)
const SHOP_COMPARISON_BOX_ROWS := 5
const SHOP_COMPARISON_VISIBLE_ROWS := 6
const SHOP_COMPARISON_OWNED_BOX_POSITION := Vector2i(20, 76)
const SHOP_COMPARISON_OWNED_TEXT_POSITION := Vector2i(30, 86)
const SHOP_COMPARISON_OWNED_NUMBER_POSITION := Vector2i(69, 91)
const SHOP_COMPARISON_CASH_BOX_POSITION := Vector2i(20, 112)
const SHOP_COMPARISON_CASH_TEXT_POSITION := Vector2i(30, 122)
const SHOP_COMPARISON_CASH_NUMBER_POSITION := Vector2i(69, 127)
const SHOP_PARTY_INFO_POSITION := Vector2i(45, 160)
const SHOP_PARTY_INFO_SPACING := 78
const SHOP_STAT_LABELS := ["攻", "灵", "防", "身", "逃"]
const COLOR_NORMAL := 0x4f
const COLOR_INACTIVE := 0x18
const COLOR_CONFIRMED := 0x2c
const COLOR_SELECTED_INACTIVE := 0x1c
const COLOR_SELECTED_FIRST := 0xf9
const COLOR_EQUIPPED := 0xc8
const UI_FRAME_CURSOR := 69
const UI_FRAME_ITEM_BOX := 70
const UI_FRAME_PLAYER_INFO := 18
const UI_FRAME_NUMBER_YELLOW := 19
const UI_FRAME_NUMBER_BLUE := 29
const UI_FRAME_SLASH := 39
const UI_FRAME_PLAYER_FACE_FIRST := 48
const UI_FRAME_NUMBER_CYAN := 56
const UI_FRAME_TARGET_CURSOR_RED := 66
const UI_FRAME_TARGET_CURSOR := 67

## 菜单使用的静态文字、UI Sprite 和物品定义。
var database: PalContentDatabase
## 菜单读取的队伍、金钱和背包状态。
var session: GameSession
## 当前菜单页面。
var current_page: Page = Page.MAIN

var _main_selection: int = 2
var _action_selection: int = 1
# 对齐 SDLPal 的 iCurSystemMenuItem：首次从第一项“储存进度”开始，之后保留玩家游标。
var _system_selection: int = 0
var _inventory_selection: int = 0
var _inventory_return_page: Page = Page.MAIN
var _inventory_ids: Array[int] = []
var _inventory_for_equipment: bool = false
var _equipment_item_id: int = 0
var _equipment_party_selection: int = 0
var _status_party_selection: int = 0
var _magic_caster_selection: int = 0
var _magic_selection: int = 0
var _magic_target_selection: int = 0
var _magic_entries: Array[Dictionary] = []
var _save_slots: Array[Dictionary] = []
var _save_slot_selection: int = 0
var _close_load_slots_on_cancel: bool = false
var _last_feedback: String = ""
var _confirmation_selection: int = 0
var _shop_ids: Array[int] = []
var _shop_selection: int = 0
var _shop_confirming: bool = false
var _shop_confirmation_selection: int = 0
var _shop_preview_item_id: int = -1
var _shop_equipment_previews: Array[Dictionary] = []
var _ui_sprite: PalSprite
var _palette: PackedByteArray = PackedByteArray()
var _ui_textures: Dictionary = {}
var _item_textures: Dictionary = {}
var _font_texture: Texture2D
var _font_glyphs: Dictionary = {}
var _equipment_background_texture: Texture2D
var _status_background_texture: Texture2D
var _portrait_textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	hide()


## 注入内容数据库和会话；调用后菜单仍保持关闭。
func configure(content_database: PalContentDatabase, game_session: GameSession) -> void:
	database = content_database
	session = game_session
	_load_classic_resources()


## 更新 100 个存档槽的摘要，并让下次打开时默认选中 `current_slot`。
## 摘要只用于绘制，不会在菜单层读取或写入存档文件。
func configure_save_slots(summaries: Array[Dictionary], current_slot: int = 1) -> void:
	_save_slots = summaries.duplicate(true)
	_save_slot_selection = clampi(current_slot - 1, 0, PalSaveManager.SLOT_COUNT - 1)
	queue_redraw()


## 打开经典主菜单并重置选择位置。
func open_main() -> void:
	if database == null or session == null:
		return
	_close_load_slots_on_cancel = false
	current_page = Page.MAIN
	show()
	queue_redraw()


## 直接打开 100 槽读取页；`close_on_cancel` 为 `true` 时 Esc 关闭菜单而不返回系统页。
## 资源实验室使用独立取消模式，探索场景内的系统菜单保持原有返回层级。
func open_load_slots(close_on_cancel: bool = false) -> void:
	if database == null or session == null:
		return
	_close_load_slots_on_cancel = close_on_cancel
	current_page = Page.LOAD_SLOTS
	show()
	queue_redraw()


## 打开脚本 000A 使用的经典“是/否”窗口。
func open_confirmation() -> void:
	if database == null or session == null:
		return
	_confirmation_selection = 0
	current_page = Page.CONFIRM
	show()
	queue_redraw()


## 打开经典买入或卖出页；卖出页只列出有 sellable 标志且数量大于零的物品。
func open_shop(store_id: int, buying: bool) -> void:
	if database == null or session == null:
		shop_closed.emit()
		return
	_shop_ids.clear()
	if buying:
		var store := database.store_definition(store_id)
		if store != null:
			for item_id in store.item_ids:
				if item_id > 0 and database.item_definition(item_id) != null:
					_shop_ids.append(item_id)
	else:
		for raw_item_id in session.inventory:
			var item_id := int(raw_item_id)
			var item := database.item_definition(item_id)
			if session.item_count(item_id) > 0 and item != null and item.is_sellable():
				_shop_ids.append(item_id)
		_shop_ids.sort()
	_shop_selection = clampi(_shop_selection, 0, maxi(0, _shop_ids.size() - 1))
	_shop_confirming = false
	_shop_confirmation_selection = 0
	_shop_preview_item_id = -1
	_shop_equipment_previews.clear()
	current_page = Page.SHOP_BUY if buying else Page.SHOP_SELL
	show()
	queue_redraw()


## 直接打开物品选择页并重建可用物品列表。
func open_inventory() -> void:
	if database == null or session == null:
		return
	_close_load_slots_on_cancel = false
	_inventory_return_page = Page.MAIN
	_inventory_for_equipment = false
	_open_item_selection()


## 把装备脚本执行结果回传给菜单。
## `next_item_id` 是刚换下、可继续装备给其他角色的物品；为 0 时返回装备物品列表。
func notify_equipment_result(success: bool, next_item_id: int, feedback: String = "") -> void:
	_last_feedback = feedback
	if not success:
		queue_redraw()
		return
	if next_item_id > 0 and session.item_count(next_item_id) > 0:
		_equipment_item_id = next_item_id
	else:
		_refresh_inventory()
		current_page = Page.INVENTORY
	queue_redraw()


## 把场外仙术脚本结果回传给菜单，并回到同一施法者的仙术列表。
## 成功与否只影响提示；列表始终按最新 MP 和已学仙术重新计算可用状态。
func notify_magic_result(success: bool, feedback: String = "") -> void:
	_last_feedback = feedback
	if session == null or session.party_roles.is_empty():
		close_menu()
		return
	_magic_caster_selection = clampi(_magic_caster_selection, 0, session.party_roles.size() - 1)
	_refresh_magic_entries()
	current_page = Page.MAGIC_LIST
	show()
	queue_redraw()


## 关闭整个菜单，返回地图输入。
func close_menu() -> void:
	_close_load_slots_on_cancel = false
	hide()


## 返回上一级页面；主菜单上调用时关闭菜单。
func go_back() -> void:
	match current_page:
		Page.CONFIRM:
			close_menu()
			confirmation_completed.emit(false)
		Page.SHOP_BUY, Page.SHOP_SELL:
			if _shop_confirming:
				_shop_confirming = false
				queue_redraw()
			else:
				close_menu()
				shop_closed.emit()
		Page.INVENTORY:
			current_page = _inventory_return_page
			queue_redraw()
		Page.EQUIPMENT:
			_refresh_inventory()
			current_page = Page.INVENTORY
			queue_redraw()
		Page.INVENTORY_ACTION:
			current_page = Page.MAIN
			queue_redraw()
		Page.SYSTEM:
			current_page = Page.MAIN
			queue_redraw()
		Page.STATUS, Page.MAGIC_CASTER:
			current_page = Page.MAIN
			queue_redraw()
		Page.MAGIC_LIST:
			current_page = Page.MAGIC_CASTER if session != null and session.party_roles.size() > 1 else Page.MAIN
			queue_redraw()
		Page.MAGIC_TARGET:
			current_page = Page.MAGIC_LIST
			queue_redraw()
		Page.SAVE_SLOTS:
			current_page = Page.SYSTEM
			queue_redraw()
		Page.LOAD_SLOTS:
			if _close_load_slots_on_cancel:
				close_menu()
				load_menu_cancelled.emit()
			else:
				current_page = Page.SYSTEM
				queue_redraw()
		_:
			close_menu()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo() or event is not InputEventKey:
		return
	# 读取存档或关闭上层场景可能让菜单在同一输入回调中离开 SceneTree。
	# 与战斗界面采用同一生命周期保护：动作前保存仍有效的 Viewport。
	var input_viewport := get_viewport()
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
	if handled and input_viewport != null:
		input_viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible or not MobileInput.is_primary_press(event):
		return
	var point := Vector2i(MobileInput.pointer_position(event))
	if MobileInput.touch_ui_enabled() and MOBILE_BACK_RECT.has_point(point):
		go_back()
		accept_event()
		return
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
		Page.EQUIPMENT:
			for party_index in range(session.party_roles.size()):
				if Rect2i(EQUIPMENT_ROLE_LIST_POSITION + Vector2i(10, 10 + party_index * 18), Vector2i(72, 18)).has_point(point):
					_equipment_party_selection = party_index
					_confirm_selection()
					break
		Page.SYSTEM:
			for index in range(SYSTEM_ITEM_POSITIONS.size()):
				if Rect2i(SYSTEM_ITEM_POSITIONS[index] - Vector2i(3, 2), Vector2i(140, 18)).has_point(point):
					_system_selection = index
					_confirm_selection()
					break
		Page.STATUS:
			_status_party_selection = posmod(_status_party_selection + (1 if point.x >= 160 else -1), maxi(1, session.party_roles.size()))
		Page.MAGIC_CASTER:
			for party_index in range(session.party_roles.size()):
				if Rect2i(MAGIC_CASTER_NAME_POSITION + Vector2i(-3, party_index * 18 - 2), Vector2i(72, 18)).has_point(point):
					_magic_caster_selection = party_index
					_confirm_selection()
					break
		Page.MAGIC_LIST:
			var start := _magic_page_start()
			for slot in range(mini(MAGIC_COLUMNS * MAGIC_ROWS, _magic_entries.size() - start)):
				var position := Vector2i(35 + slot % MAGIC_COLUMNS * MAGIC_COLUMN_WIDTH, 54 + slot / MAGIC_COLUMNS * MAGIC_ROW_HEIGHT)
				if Rect2i(position - Vector2i(3, 2), Vector2i(MAGIC_COLUMN_WIDTH, 18)).has_point(point):
					_magic_selection = start + slot
					_confirm_selection()
					break
		Page.MAGIC_TARGET:
			for party_index in range(session.party_roles.size()):
				if Rect2i(MAGIC_PLAYER_INFO_POSITION + Vector2i(party_index * MAGIC_PLAYER_INFO_SPACING, -8), Vector2i(76, 43)).has_point(point):
					_magic_target_selection = party_index
					_confirm_selection()
					break
		Page.SAVE_SLOTS, Page.LOAD_SLOTS:
			for row in range(PalSaveManager.SLOTS_PER_PAGE):
				var position := SAVE_SLOT_BOX_POSITION + Vector2i(0, row * SAVE_SLOT_ROW_HEIGHT)
				if Rect2i(position, Vector2i(136, 32)).has_point(point):
					_save_slot_selection = _save_slot_page_start() + row
					_confirm_selection()
					break
		Page.CONFIRM:
			_confirmation_selection = 0 if point.y < 110 else 1
			_confirm_selection()
		Page.SHOP_BUY, Page.SHOP_SELL:
			if _shop_confirming:
				_shop_confirmation_selection = 0 if point.y < 128 else 1
				_confirm_selection()
			else:
				var start := _shop_list_start()
				for slot in range(mini(_shop_visible_rows(), _shop_ids.size() - start)):
					var index := start + slot
					if _shop_item_hitbox(slot).has_point(point):
						_shop_selection = index
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
	if current_page == Page.LOAD_SLOTS and _close_load_slots_on_cancel:
		# 启动页没有游戏画面可作为菜单底图；纯黑遮住实验室文字，保留原版窗口本身的透明边界。
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	match current_page:
		Page.MAIN:
			_draw_main_menu()
		Page.INVENTORY_ACTION:
			_draw_main_menu()
			_draw_inventory_action()
		Page.INVENTORY:
			_draw_inventory_page()
		Page.EQUIPMENT:
			_draw_equipment_page()
		Page.SYSTEM:
			_draw_main_menu()
			_draw_system_menu()
		Page.STATUS:
			_draw_status_page()
		Page.MAGIC_CASTER:
			_draw_magic_caster_page()
		Page.MAGIC_LIST:
			_draw_magic_list_page()
		Page.MAGIC_TARGET:
			_draw_magic_target_page()
		Page.SAVE_SLOTS, Page.LOAD_SLOTS:
			_draw_save_slot_page()
		Page.CONFIRM:
			_draw_confirmation()
		Page.SHOP_BUY, Page.SHOP_SELL:
			_draw_shop_page()
	if MobileInput.touch_ui_enabled():
		_draw_mobile_back_button()


func _draw_mobile_back_button() -> void:
	var size := Vector2(26, 26)
	draw_texture_rect(MOBILE_BACK_ICON, Rect2(MOBILE_BACK_RECT.get_center() - size * 0.5, size), false)


func _draw_main_menu() -> void:
	_draw_single_line_box(Vector2i.ZERO, 5, 6)
	_draw_pal_text(database.get_word(21), Vector2i(10, 10), _palette_color(COLOR_NORMAL))
	_draw_number(session.cash, 6, Vector2i(49, 14), 19)
	_draw_classic_box(MAIN_MENU_POSITION, 3, 1, 0, 6)
	for index in range(4):
		var enabled := true
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _main_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(3 + index), MAIN_ITEM_POSITIONS[index], _palette_color(color_index), true)


func _draw_inventory_action() -> void:
	_draw_classic_box(INVENTORY_ACTION_POSITION, 1, 1, 0, 6)
	for index in range(2):
		var enabled := true
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
		var enabled := item != null and (item.is_equipable() if _inventory_for_equipment else (item.is_usable() and item.applies_to_all()))
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


func _draw_equipment_page() -> void:
	if _equipment_background_texture != null:
		draw_texture(_equipment_background_texture, Vector2.ZERO)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(320, 200)), Color(0.025, 0.035, 0.08, 1.0))
		for index in range(EQUIPMENT_LABEL_WORDS.size()):
			_draw_pal_text(database.get_word(EQUIPMENT_LABEL_WORDS[index]), EQUIPMENT_LABEL_POSITIONS[index], _palette_color(COLOR_NORMAL), true)
		for index in range(EQUIPMENT_STATUS_WORDS.size()):
			_draw_pal_text(database.get_word(EQUIPMENT_STATUS_WORDS[index]), EQUIPMENT_STATUS_LABEL_POSITIONS[index], _palette_color(COLOR_NORMAL), true)
	if _equipment_item_id <= 0:
		return
	var item := database.item_definition(_equipment_item_id)
	if item != null:
		_draw_item_bitmap(item.bitmap, EQUIPMENT_IMAGE_POSITION)
	_draw_pal_text(database.get_word(_equipment_item_id), EQUIPMENT_ITEM_NAME_POSITION, _palette_color(COLOR_CONFIRMED), true)
	_draw_number(session.item_count(_equipment_item_id), 2, EQUIPMENT_ITEM_AMOUNT_POSITION, 56)
	if session.party_roles.is_empty():
		return
	_equipment_party_selection = clampi(_equipment_party_selection, 0, session.party_roles.size() - 1)
	var role_index := session.party_roles[_equipment_party_selection]
	var equipments := session.equipment_for_role(role_index)
	for slot_index in range(mini(equipments.size(), EQUIPMENT_NAME_POSITIONS.size())):
		if equipments[slot_index] > 0:
			_draw_pal_text(database.get_word(equipments[slot_index]), EQUIPMENT_NAME_POSITIONS[slot_index], _palette_color(COLOR_NORMAL), true)
	var stats := [
		session.attack_strength_for(role_index),
		session.magic_strength_for(role_index),
		session.defense_for(role_index),
		session.dexterity_for(role_index),
		session.flee_rate_for(role_index),
	]
	for stat_index in range(stats.size()):
		_draw_number(stats[stat_index], 4, EQUIPMENT_STATUS_VALUE_POSITIONS[stat_index], 19)
	_draw_classic_box(EQUIPMENT_ROLE_LIST_POSITION, maxi(0, session.party_roles.size() - 1), 3, 0, 0)
	for party_index in range(session.party_roles.size()):
		var candidate_role := session.party_roles[party_index]
		var can_equip := item != null and item.can_equip_by_role(candidate_role)
		var color_index := COLOR_NORMAL if can_equip else COLOR_INACTIVE
		if party_index == _equipment_party_selection:
			color_index = _selected_color_index() if can_equip else COLOR_SELECTED_INACTIVE
		_draw_pal_text(
			database.get_word(database.player_roles.name_word_for(candidate_role)),
			EQUIPMENT_ROLE_LIST_POSITION + Vector2i(13, 13 + 18 * party_index),
			_palette_color(color_index),
			true
		)


func _draw_status_page() -> void:
	if _status_background_texture != null:
		draw_texture(_status_background_texture, Vector2.ZERO)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(320, 200)), Color(0.025, 0.035, 0.08, 1.0))
	if session.party_roles.is_empty() or database.player_roles == null:
		return
	_status_party_selection = clampi(_status_party_selection, 0, session.party_roles.size() - 1)
	var role_index := session.party_roles[_status_party_selection]
	for index in range(STATUS_LABEL_WORDS.size()):
		_draw_pal_text(database.get_word(STATUS_LABEL_WORDS[index]), STATUS_LABEL_POSITIONS[index], _palette_color(COLOR_NORMAL), true)
	for index in range(EQUIPMENT_STATUS_WORDS.size()):
		_draw_pal_text(database.get_word(EQUIPMENT_STATUS_WORDS[index]), Vector2i(6, 98 + index * 20), _palette_color(COLOR_NORMAL), true)
	_draw_pal_text(database.get_word(database.player_roles.name_word_for(role_index)), Vector2i(110, 8), _palette_color(COLOR_CONFIRMED), true)
	_draw_portrait(database.player_roles.avatar_for(role_index), Vector2i(110, 30))
	var level := _role_value(session.role_levels, role_index)
	var current_exp := _role_value(session.role_experience, role_index)
	var next_exp := database.level_progression.experience_for_level(level) if database.level_progression != null else 0
	_draw_number(current_exp, 5, Vector2i(58, 6), UI_FRAME_NUMBER_YELLOW)
	_draw_number(next_exp, 5, Vector2i(58, 15), UI_FRAME_NUMBER_CYAN)
	_draw_number(level, 2, Vector2i(54, 35), UI_FRAME_NUMBER_YELLOW)
	_draw_ui_frame(UI_FRAME_SLASH, Vector2i(65, 58))
	_draw_number(_role_value(session.role_hp, role_index), 4, Vector2i(42, 56), UI_FRAME_NUMBER_YELLOW)
	_draw_number(_role_value(session.role_max_hp, role_index), 4, Vector2i(63, 61), UI_FRAME_NUMBER_BLUE)
	_draw_ui_frame(UI_FRAME_SLASH, Vector2i(65, 80))
	_draw_number(_role_value(session.role_mp, role_index), 4, Vector2i(42, 78), UI_FRAME_NUMBER_YELLOW)
	_draw_number(_role_value(session.role_max_mp, role_index), 4, Vector2i(63, 83), UI_FRAME_NUMBER_BLUE)
	var stats := [
		session.attack_strength_for(role_index),
		session.magic_strength_for(role_index),
		session.defense_for(role_index),
		session.dexterity_for(role_index),
		session.flee_rate_for(role_index),
	]
	for index in range(stats.size()):
		_draw_number(stats[index], 4, STATUS_STAT_POSITIONS[index], UI_FRAME_NUMBER_YELLOW)
	var equipments := session.equipment_for_role(role_index)
	for slot_index in range(mini(equipments.size(), STATUS_EQUIPMENT_IMAGE_POSITIONS.size())):
		var item_id := equipments[slot_index]
		var item := database.item_definition(item_id)
		if item == null or item_id <= 0:
			continue
		_draw_item_bitmap(item.bitmap, STATUS_EQUIPMENT_IMAGE_POSITIONS[slot_index] + Vector2i.ONE)
		_draw_pal_text(database.get_word(item_id), STATUS_EQUIPMENT_NAME_POSITIONS[slot_index], _palette_color(COLOR_EQUIPPED), true)
	var conditions := RoleConditionDisplay.entries_for_role(session, database, role_index)
	for condition_index in range(mini(conditions.size(), STATUS_POISON_POSITIONS.size())):
		var condition := conditions[condition_index]
		_draw_role_condition_icon(condition, STATUS_POISON_POSITIONS[condition_index] + Vector2i(-18, -1))
		_draw_pal_text(
			RoleConditionDisplay.detailed_text(condition),
			STATUS_POISON_POSITIONS[condition_index],
			_palette_color(int(condition.get("color_index", COLOR_NORMAL))),
			true
		)


func _draw_magic_caster_page() -> void:
	_draw_party_info_boxes()
	if session.party_roles.is_empty():
		return
	_draw_classic_box(MAGIC_CASTER_BOX_POSITION, maxi(0, session.party_roles.size() - 1), 3, 0, 0)
	_magic_caster_selection = clampi(_magic_caster_selection, 0, session.party_roles.size() - 1)
	for party_index in range(session.party_roles.size()):
		var role_index := session.party_roles[party_index]
		var enabled := _role_value(session.role_hp, role_index) > 0
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if party_index == _magic_caster_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(database.player_roles.name_word_for(role_index)), MAGIC_CASTER_NAME_POSITION + Vector2i(0, party_index * 18), _palette_color(color_index), true)
	_draw_party_condition_strips()


func _draw_magic_list_page() -> void:
	_draw_party_info_boxes()
	_draw_single_line_box(Vector2i.ZERO, 5, 0)
	var role_index := _selected_magic_caster_role()
	var entry := _selected_magic_entry()
	var needed_mp := int(entry.get("mp_cost", 0))
	var current_mp := _role_value(session.role_mp, role_index)
	var description := database.get_item_description(int(entry.get("object_id", 0)))
	if description.is_empty():
		_draw_pal_text(database.get_word(21), Vector2i(10, 10), _palette_color(COLOR_NORMAL))
		_draw_number(session.cash, 6, Vector2i(49, 14), UI_FRAME_NUMBER_YELLOW)
		_draw_single_line_box(Vector2i(215, 0), 5, 0)
		_draw_ui_frame(UI_FRAME_SLASH, Vector2i(260, 14))
		_draw_number(needed_mp, 4, Vector2i(230, 14), UI_FRAME_NUMBER_YELLOW)
		_draw_number(current_mp, 4, Vector2i(265, 14), UI_FRAME_NUMBER_CYAN)
	else:
		_draw_ui_frame(UI_FRAME_SLASH, Vector2i(45, 14))
		_draw_number(needed_mp, 4, Vector2i(15, 14), UI_FRAME_NUMBER_YELLOW)
		_draw_number(current_mp, 4, Vector2i(50, 14), UI_FRAME_NUMBER_CYAN)
		var description_y := 3
		for line in description.split("*", false):
			_draw_pal_text(line, Vector2i(102, description_y), _palette_color(0x3c), true)
			description_y += 16
	_draw_classic_box(Vector2i(10, 42), MAGIC_ROWS - 1, 16, 1, 0)
	var start := _magic_page_start()
	for slot in range(mini(MAGIC_COLUMNS * MAGIC_ROWS, _magic_entries.size() - start)):
		var index := start + slot
		var magic_entry := _magic_entries[index]
		var enabled := bool(magic_entry.get("enabled", false))
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _magic_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		var position := Vector2i(35 + slot % MAGIC_COLUMNS * MAGIC_COLUMN_WIDTH, 54 + slot / MAGIC_COLUMNS * MAGIC_ROW_HEIGHT)
		_draw_pal_text(database.get_word(int(magic_entry.get("object_id", 0))), position, _palette_color(color_index), true)
		if index == _magic_selection:
			_draw_ui_frame(UI_FRAME_CURSOR, position + Vector2i(25, 10))
	if _magic_entries.is_empty():
		_draw_pal_text("没有可用仙术", Vector2i(35, 54), _palette_color(COLOR_INACTIVE), true)
	_draw_party_condition_strips()


func _draw_magic_target_page() -> void:
	_draw_party_info_boxes()
	if session.party_roles.is_empty():
		return
	_magic_target_selection = clampi(_magic_target_selection, 0, session.party_roles.size() - 1)
	var frame := UI_FRAME_TARGET_CURSOR_RED if int(Time.get_ticks_msec() / 80) % 2 == 0 else UI_FRAME_TARGET_CURSOR
	_draw_party_condition_strips()
	_draw_ui_frame(frame, Vector2i(75 + MAGIC_PLAYER_INFO_SPACING * _magic_target_selection, 158))


func _draw_party_info_boxes() -> void:
	for party_index in range(session.party_roles.size()):
		var role_index := session.party_roles[party_index]
		var position := MAGIC_PLAYER_INFO_POSITION + Vector2i(MAGIC_PLAYER_INFO_SPACING * party_index, 0)
		_draw_ui_frame(UI_FRAME_PLAYER_INFO, position)
		_draw_ui_frame(UI_FRAME_PLAYER_FACE_FIRST + role_index, position + Vector2i(-2, -4))
		_draw_ui_frame(UI_FRAME_SLASH, position + Vector2i(49, 6))
		_draw_number(_role_value(session.role_max_hp, role_index), 4, position + Vector2i(47, 8), UI_FRAME_NUMBER_YELLOW)
		_draw_number(_role_value(session.role_hp, role_index), 4, position + Vector2i(26, 5), UI_FRAME_NUMBER_YELLOW)
		_draw_ui_frame(UI_FRAME_SLASH, position + Vector2i(49, 22))
		_draw_number(_role_value(session.role_max_mp, role_index), 4, position + Vector2i(47, 24), UI_FRAME_NUMBER_CYAN)
		_draw_number(_role_value(session.role_mp, role_index), 4, position + Vector2i(26, 21), UI_FRAME_NUMBER_CYAN)


func _draw_party_condition_strips() -> void:
	for party_index in range(session.party_roles.size()):
		var role_index := session.party_roles[party_index]
		var position := MAGIC_PLAYER_INFO_POSITION + Vector2i(MAGIC_PLAYER_INFO_SPACING * party_index, -24)
		_draw_role_condition_strip(role_index, position)


func _draw_role_condition_strip(role_index: int, position: Vector2i) -> void:
	var conditions := RoleConditionDisplay.entries_for_role(session, database, role_index)
	if conditions.is_empty():
		return
	if RoleConditionDisplay.ICON_ATLAS == null:
		_draw_pal_text(RoleConditionDisplay.compact_text(conditions[0]), position, _palette_color(int(conditions[0].get("color_index", COLOR_NORMAL))), true)
		return
	var overflow := conditions.size() > 4
	var visible_count := mini(3 if overflow else 4, conditions.size())
	for condition_index in range(visible_count):
		var icon_position := position + Vector2i(condition_index * (RoleConditionDisplay.ICON_SIZE + 2), 0)
		var condition := conditions[condition_index]
		_draw_role_condition_icon(condition, icon_position)
		var rounds := int(condition.get("rounds", 0))
		if rounds > 0 and rounds <= 9:
			_draw_number(rounds, 1, icon_position + Vector2i(10, 9), UI_FRAME_NUMBER_YELLOW)
	if overflow:
		_draw_pal_text("+", position + Vector2i(visible_count * (RoleConditionDisplay.ICON_SIZE + 2), 0), _palette_color(COLOR_NORMAL), true)


func _draw_role_condition_icon(condition: Dictionary, position: Vector2i) -> void:
	if RoleConditionDisplay.ICON_ATLAS == null:
		return
	var icon_index := clampi(int(condition.get("icon_index", 0)), 0, RoleConditionDisplay.ICON_COUNT - 1)
	var source := Rect2(Vector2(icon_index * RoleConditionDisplay.ICON_SIZE, 0), Vector2(RoleConditionDisplay.ICON_SIZE, RoleConditionDisplay.ICON_SIZE))
	draw_texture_rect_region(RoleConditionDisplay.ICON_ATLAS, Rect2(Vector2(position), source.size), source)


func _draw_system_menu() -> void:
	# 官方系统菜单位于 (40,60)。本项目在原五行布局右侧追加百分比数字，
	# 保留经典窗口与点阵字，而不引入不协调的现代滑块控件。
	_draw_classic_box(SYSTEM_MENU_POSITION, 4, 8, 0, 6)
	for index in range(SYSTEM_ITEM_POSITIONS.size()):
		var enabled := index in [0, 1, 2, 3]
		var color_index := COLOR_NORMAL if enabled else COLOR_INACTIVE
		if index == _system_selection:
			color_index = _selected_color_index() if enabled else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(11 + index), SYSTEM_ITEM_POSITIONS[index], _palette_color(color_index), true)
	_draw_number(session.music_volume, 3, Vector2i(VOLUME_VALUE_X, SYSTEM_ITEM_POSITIONS[2].y + 4), 19)
	_draw_number(session.sound_volume, 3, Vector2i(VOLUME_VALUE_X, SYSTEM_ITEM_POSITIONS[3].y + 4), 19)


func _move_selection(direction: Vector2i) -> void:
	match current_page:
		Page.CONFIRM:
			var delta := direction.y if direction.y != 0 else direction.x
			_confirmation_selection = posmod(_confirmation_selection + delta, 2)
		Page.SHOP_BUY, Page.SHOP_SELL:
			var delta := direction.y if direction.y != 0 else direction.x
			if _shop_confirming:
				_shop_confirmation_selection = posmod(_shop_confirmation_selection + delta, 2)
			elif not _shop_ids.is_empty():
				_shop_selection = posmod(_shop_selection + delta, _shop_ids.size())
		Page.MAIN:
			_main_selection = posmod(_main_selection + (direction.y if direction.y != 0 else direction.x), 4)
		Page.INVENTORY_ACTION:
			_action_selection = posmod(_action_selection + (direction.y if direction.y != 0 else direction.x), 2)
		Page.INVENTORY:
			if _inventory_ids.is_empty():
				return
			var delta := direction.x if direction.x != 0 else direction.y * INVENTORY_COLUMNS
			_inventory_selection = clampi(_inventory_selection + delta, 0, _inventory_ids.size() - 1)
		Page.EQUIPMENT:
			if not session.party_roles.is_empty():
				var delta := direction.y if direction.y != 0 else direction.x
				_equipment_party_selection = posmod(_equipment_party_selection + delta, session.party_roles.size())
		Page.SYSTEM:
			if direction.x != 0 and _system_selection in [2, 3]:
				_change_selected_volume(direction.x * VOLUME_STEP)
			elif direction.y != 0:
				_system_selection = posmod(_system_selection + direction.y, SYSTEM_ITEM_POSITIONS.size())
		Page.STATUS:
			if not session.party_roles.is_empty():
				var delta := direction.x if direction.x != 0 else direction.y
				_status_party_selection = posmod(_status_party_selection + delta, session.party_roles.size())
		Page.MAGIC_CASTER:
			if not session.party_roles.is_empty():
				var delta := direction.y if direction.y != 0 else direction.x
				_magic_caster_selection = posmod(_magic_caster_selection + delta, session.party_roles.size())
		Page.MAGIC_LIST:
			if not _magic_entries.is_empty():
				var delta := direction.x if direction.x != 0 else direction.y * MAGIC_COLUMNS
				_magic_selection = clampi(_magic_selection + delta, 0, _magic_entries.size() - 1)
		Page.MAGIC_TARGET:
			if not session.party_roles.is_empty():
				var delta := direction.x if direction.x != 0 else direction.y
				_magic_target_selection = posmod(_magic_target_selection + delta, session.party_roles.size())
		Page.SAVE_SLOTS, Page.LOAD_SLOTS:
			if direction.x != 0:
				_save_slot_selection = posmod(_save_slot_selection + direction.x * PalSaveManager.SLOTS_PER_PAGE, PalSaveManager.SLOT_COUNT)
			elif direction.y != 0:
				# 上下键按 1–100 连续移动，让第 5 槽向下自然进入第 6 槽；
				# 左右键仍按五槽整页移动并保留当前行。
				_save_slot_selection = posmod(_save_slot_selection + direction.y, PalSaveManager.SLOT_COUNT)
	queue_redraw()


func _confirm_selection() -> void:
	match current_page:
		Page.CONFIRM:
			var accepted := _confirmation_selection == 1
			close_menu()
			confirmation_completed.emit(accepted)
		Page.SHOP_BUY, Page.SHOP_SELL:
			_confirm_shop_selection()
		Page.MAIN:
			if _main_selection == 0:
				_status_party_selection = clampi(_status_party_selection, 0, maxi(0, session.party_roles.size() - 1))
				current_page = Page.STATUS
			elif _main_selection == 1:
				_open_magic_menu()
			elif _main_selection == 2:
				current_page = Page.INVENTORY_ACTION
				_action_selection = 1
			elif _main_selection == 3:
				current_page = Page.SYSTEM
		Page.INVENTORY_ACTION:
			_inventory_for_equipment = _action_selection == 0
			_inventory_return_page = Page.INVENTORY_ACTION
			_open_item_selection()
		Page.INVENTORY:
			if not _inventory_ids.is_empty():
				var item_id := _inventory_ids[_inventory_selection]
				if _inventory_for_equipment:
					_open_equipment_page(item_id)
				else:
					_request_item_use(item_id, database.item_definition(item_id))
		Page.EQUIPMENT:
			_request_item_equip()
		Page.SYSTEM:
			if _system_selection == 0:
				current_page = Page.SAVE_SLOTS
			elif _system_selection == 1:
				current_page = Page.LOAD_SLOTS
			elif _system_selection == 2:
				session.set_music_volume(GameSession.AUDIO_VOLUME_MAX if session.music_volume == 0 else 0)
				audio_settings_changed.emit(session.music_volume, session.sound_volume)
			elif _system_selection == 3:
				session.set_sound_volume(GameSession.AUDIO_VOLUME_MAX if session.sound_volume == 0 else 0)
				audio_settings_changed.emit(session.music_volume, session.sound_volume)
		Page.STATUS:
			if not session.party_roles.is_empty():
				_status_party_selection = posmod(_status_party_selection + 1, session.party_roles.size())
		Page.MAGIC_CASTER:
			_open_selected_caster_magic_list()
		Page.MAGIC_LIST:
			_confirm_magic_selection()
		Page.MAGIC_TARGET:
			_request_selected_magic(_selected_magic_target_role())
		Page.SAVE_SLOTS:
			save_slot_requested.emit(_save_slot_selection + 1)
		Page.LOAD_SLOTS:
			var metadata := _selected_save_slot_metadata()
			if bool(metadata.get("can_load", false)):
				load_slot_requested.emit(_save_slot_selection + 1)
			else:
				_last_feedback = str(metadata.get("error", "这个槽位没有可读取的存档。"))
	queue_redraw()


func _draw_confirmation() -> void:
	_draw_classic_box(Vector2i(118, 76), 1, 3, 0, 6)
	for index in range(2):
		var color_index := _selected_color_index() if index == _confirmation_selection else COLOR_NORMAL
		_draw_pal_text(database.get_word(19 + index), Vector2i(136, 89 + index * 18), _palette_color(color_index), true)


func _draw_shop_page() -> void:
	var buying := current_page == Page.SHOP_BUY
	var show_comparison := _shop_shows_equipment_comparison()
	_draw_classic_box(SHOP_BOX_POSITION, SHOP_COMPARISON_BOX_ROWS if show_comparison else SHOP_BOX_ROWS, SHOP_BOX_COLUMNS, 1, 0)
	var cash_box_position := SHOP_COMPARISON_CASH_BOX_POSITION if show_comparison else Vector2i(20, 141)
	var cash_text_position := SHOP_COMPARISON_CASH_TEXT_POSITION if show_comparison else Vector2i(30, 151)
	var cash_number_position := SHOP_COMPARISON_CASH_NUMBER_POSITION if show_comparison else Vector2i(69, 156)
	_draw_single_line_box(cash_box_position, 5, 6)
	_draw_pal_text(database.get_word(21), cash_text_position, _palette_color(COLOR_NORMAL), true)
	_draw_number(session.cash, 6, cash_number_position, UI_FRAME_NUMBER_YELLOW)
	if _shop_ids.is_empty():
		_draw_pal_text("没有可出售物品" if not buying else "商店没有商品", SHOP_ITEM_NAME_POSITION + Vector2i(0, 3), _palette_color(COLOR_INACTIVE), true)
		return
	_shop_selection = clampi(_shop_selection, 0, _shop_ids.size() - 1)
	var selected_id := _shop_ids[_shop_selection]
	var selected_item := database.item_definition(selected_id)
	var start := _shop_list_start()
	for slot in range(mini(_shop_visible_rows(), _shop_ids.size() - start)):
		var index := start + slot
		var item_id := _shop_ids[index]
		var item := database.item_definition(item_id)
		if item == null:
			continue
		var can_trade := session.cash >= item.price and session.item_count(item_id) < 99 if buying else session.item_count(item_id) > 0
		var color_index := COLOR_NORMAL if can_trade else COLOR_INACTIVE
		if index == _shop_selection:
			color_index = _selected_color_index() if can_trade else COLOR_SELECTED_INACTIVE
		_draw_pal_text(database.get_word(item_id), SHOP_ITEM_NAME_POSITION + Vector2i(0, slot * SHOP_ROW_HEIGHT), _palette_color(color_index), true)
		_draw_number(item.price if buying else item.price / 2, SHOP_PRICE_DIGITS, SHOP_PRICE_POSITION + Vector2i(0, slot * SHOP_ROW_HEIGHT), UI_FRAME_NUMBER_YELLOW)
	if selected_item != null:
		_draw_ui_frame(UI_FRAME_ITEM_BOX, Vector2i(40, 8))
		_draw_item_bitmap(selected_item.bitmap, Vector2i(48, 15))
		var owned_box_position := SHOP_COMPARISON_OWNED_BOX_POSITION if show_comparison else Vector2i(20, 100)
		var owned_text_position := SHOP_COMPARISON_OWNED_TEXT_POSITION if show_comparison else Vector2i(30, 110)
		var owned_number_position := SHOP_COMPARISON_OWNED_NUMBER_POSITION if show_comparison else Vector2i(69, 115)
		_draw_single_line_box(owned_box_position, 5, 6)
		_draw_pal_text(database.get_word(35), owned_text_position, _palette_color(COLOR_NORMAL), true)
		_draw_number(session.item_count(selected_id) + session.equipped_item_count(selected_id), 6, owned_number_position, UI_FRAME_NUMBER_YELLOW)
		if show_comparison:
			_draw_shop_equipment_comparison(selected_item)
	if _shop_confirming:
		_draw_classic_box(Vector2i(92, 92), 1, 3, 0, 6)
		for index in range(2):
			var color_index := _selected_color_index() if index == _shop_confirmation_selection else COLOR_NORMAL
			_draw_pal_text(database.get_word(19 + index), Vector2i(110, 105 + index * 18), _palette_color(color_index), true)


## 返回商店价格列占用的完整六位数字区域，用于布局边界回归。
static func shop_price_bounds() -> Rect2i:
	return Rect2i(SHOP_PRICE_POSITION, Vector2i(SHOP_PRICE_DIGITS * SHOP_NUMBER_DIGIT_WIDTH, 8))


func _shop_item_hitbox(index: int) -> Rect2i:
	return Rect2i(
		SHOP_ITEM_HITBOX_POSITION + Vector2i(0, index * SHOP_ROW_HEIGHT),
		Vector2i(SHOP_CONTENT_RIGHT - SHOP_ITEM_HITBOX_POSITION.x, SHOP_ROW_HEIGHT)
	)


func _shop_visible_rows() -> int:
	return SHOP_COMPARISON_VISIBLE_ROWS if _shop_shows_equipment_comparison() else PalStoreDefinition.ITEM_COUNT


func _shop_list_start() -> int:
	if _shop_ids.is_empty():
		return 0
	var visible_rows := _shop_visible_rows()
	return clampi(_shop_selection - visible_rows + 1, 0, maxi(0, _shop_ids.size() - visible_rows))


func _shop_shows_equipment_comparison() -> bool:
	if current_page != Page.SHOP_BUY or session == null or session.party_roles.is_empty() or _shop_ids.is_empty():
		return false
	var item := database.item_definition(_shop_ids[clampi(_shop_selection, 0, _shop_ids.size() - 1)])
	return item != null and item.is_equipable()


func _draw_shop_equipment_comparison(item: PalItemDefinition) -> void:
	_refresh_shop_equipment_previews(item.object_id)
	var party_count := mini(session.party_roles.size(), 3)
	var comparison_left := SHOP_PARTY_INFO_POSITION.x + int((3 - party_count) * SHOP_PARTY_INFO_SPACING / 2.0)
	for party_index in range(party_count):
		var role_index := session.party_roles[party_index]
		var preview: Dictionary = _shop_equipment_previews[party_index]
		var can_equip := bool(preview.get("can_equip", false))
		var position := Vector2i(comparison_left + party_index * SHOP_PARTY_INFO_SPACING, SHOP_PARTY_INFO_POSITION.y)
		_draw_ui_frame(UI_FRAME_PLAYER_INFO, position)
		_draw_ui_frame(
			UI_FRAME_PLAYER_FACE_FIRST + role_index,
			position + Vector2i(-2, -4),
			Color.WHITE if can_equip else Color(0.38, 0.38, 0.38, 0.9)
		)
		if not can_equip:
			_draw_pal_text("不可用", position + Vector2i(28, 9), _palette_color(COLOR_INACTIVE), true)
			continue
		if not bool(preview.get("valid", false)):
			_draw_pal_text("无比较", position + Vector2i(28, 9), _palette_color(COLOR_INACTIVE), true)
			continue
		var differences := _shop_stat_difference_indices(preview.get("deltas", PackedInt32Array()), 2)
		if differences.is_empty():
			_draw_pal_text("无变化", position + Vector2i(28, 9), _palette_color(COLOR_NORMAL), true)
			continue
		for difference_row in range(differences.size()):
			var stat_index: int = differences[difference_row]
			var delta: int = preview.deltas[stat_index]
			var label := "%s%d%s" % ["+" if delta > 0 else "", delta, SHOP_STAT_LABELS[stat_index]]
			var color_index := COLOR_EQUIPPED if delta > 0 else COLOR_INACTIVE
			_draw_pal_text(label, position + Vector2i(28, 1 + difference_row * 16), _palette_color(color_index), true)


func _refresh_shop_equipment_previews(item_id: int) -> void:
	if _shop_preview_item_id == item_id and _shop_equipment_previews.size() == session.party_roles.size():
		return
	_shop_preview_item_id = item_id
	_shop_equipment_previews.clear()
	var equipment_manager := PalEquipmentManager.new()
	equipment_manager.database = database
	equipment_manager.session = session
	for role_index in session.party_roles:
		_shop_equipment_previews.append(equipment_manager.preview_stat_differences(item_id, role_index))


func _shop_stat_difference_indices(deltas: PackedInt32Array, limit: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for _slot in range(limit):
		var strongest := -1
		for stat_index in range(mini(deltas.size(), SHOP_STAT_LABELS.size())):
			if deltas[stat_index] == 0 or stat_index in result:
				continue
			if strongest < 0 or absi(deltas[stat_index]) > absi(deltas[strongest]):
				strongest = stat_index
		if strongest < 0:
			break
		result.append(strongest)
	return result


func _confirm_shop_selection() -> void:
	if _shop_ids.is_empty():
		return
	if not _shop_confirming:
		_shop_confirming = true
		_shop_confirmation_selection = 0
		return
	var accepted := _shop_confirmation_selection == 1
	_shop_confirming = false
	if not accepted:
		return
	var item_id := _shop_ids[_shop_selection]
	var item := database.item_definition(item_id)
	if item == null:
		return
	if current_page == Page.SHOP_BUY:
		if session.cash < item.price:
			_last_feedback = "金钱不足。"
			return
		if session.item_count(item_id) >= 99:
			_last_feedback = "这个物品已经达到 99 个。"
			return
		session.cash -= item.price
		session.set_item_count(item_id, session.item_count(item_id) + 1)
	else:
		if session.item_count(item_id) <= 0 or not item.is_sellable():
			return
		session.change_item_count(item_id, -1)
		session.cash += item.price / 2
		if session.item_count(item_id) <= 0:
			_shop_ids.remove_at(_shop_selection)
			_shop_selection = clampi(_shop_selection, 0, maxi(0, _shop_ids.size() - 1))


func _draw_save_slot_page() -> void:
	# SDLPal 原版一次显示五个槽位；扩展到 100 槽时保持相同密度，用左右键翻 20 页。
	_draw_classic_box(Vector2i(2, 7), 8, 7, 0, 0)
	var is_loading := current_page == Page.LOAD_SLOTS
	_draw_pal_text("读取存档" if is_loading else "保存游戏", Vector2i(15, 17), _palette_color(COLOR_CONFIRMED), true)
	var selected := _selected_save_slot_metadata()
	if not bool(selected.get("exists", false)):
		_draw_pal_text("空存档", Vector2i(15, 43), _palette_color(COLOR_INACTIVE), true)
	elif not bool(selected.get("can_load", false)):
		_draw_pal_text(_save_slot_error_label(str(selected.get("error", ""))), Vector2i(15, 43), _palette_color(COLOR_INACTIVE), true)
	else:
		var location := PalSceneCatalog.name_for_scene_index(int(selected.get("scene_index", -1)))
		var location_lines := _wrap_pal_text(location, 145, 2)
		for line_index in range(location_lines.size()):
			_draw_pal_text(location_lines[line_index], Vector2i(15, 38 + line_index * 16), _palette_color(COLOR_NORMAL), true)
		var save_time := _fit_pal_text(_format_save_time(str(selected.get("saved_at", ""))), SAVE_DETAIL_TEXT_WIDTH)
		_draw_pal_text(save_time, Vector2i(15, 72), _palette_color(0x3c), true)
		var party: Array = selected.get("party", [])
		for member_index in range(mini(3, party.size())):
			var member: Dictionary = party[member_index]
			var role_index := int(member.get("role_index", -1))
			var position := SAVE_DETAIL_PARTY_POSITION + Vector2i(0, member_index * SAVE_DETAIL_PARTY_SPACING)
			if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
				continue
			_draw_ui_frame(UI_FRAME_PLAYER_FACE_FIRST + role_index, position)
			_draw_pal_text(database.get_word(database.player_roles.name_word_for(role_index)), position + Vector2i(34, -2), _palette_color(COLOR_NORMAL), true)
			_draw_pal_text("Lv.%d" % int(member.get("level", 0)), position + Vector2i(34, 13), _palette_color(COLOR_CONFIRMED), true)
	var start := _save_slot_page_start()
	for row in range(PalSaveManager.SLOTS_PER_PAGE):
		var slot_index := start + row
		var slot := slot_index + 1
		var metadata := _save_slots[slot_index] if slot_index >= 0 and slot_index < _save_slots.size() else {}
		var can_select := not is_loading or bool(metadata.get("can_load", false))
		var color_index := COLOR_NORMAL if can_select else COLOR_INACTIVE
		if slot_index == _save_slot_selection:
			color_index = _selected_color_index() if can_select else COLOR_SELECTED_INACTIVE
		var box_position := SAVE_SLOT_BOX_POSITION + Vector2i(0, row * SAVE_SLOT_ROW_HEIGHT)
		_draw_single_line_box(box_position, 7, 0)
		_draw_pal_text("存档 %03d" % slot, SAVE_SLOT_TEXT_POSITION + Vector2i(0, row * SAVE_SLOT_ROW_HEIGHT), _palette_color(color_index), true)
		if bool(metadata.get("can_load", false)):
			# 数字按四位数右对齐；基准点预留右侧内边距，避免个位覆盖窗口边框。
			_draw_number(int(metadata.get("save_count", 0)), 4, Vector2i(SAVE_SLOT_COUNT_POSITION_X, 21 + row * SAVE_SLOT_ROW_HEIGHT), UI_FRAME_NUMBER_YELLOW)


func _save_slot_page_start() -> int:
	return int(_save_slot_selection / PalSaveManager.SLOTS_PER_PAGE) * PalSaveManager.SLOTS_PER_PAGE


func _selected_save_slot_metadata() -> Dictionary:
	return _save_slots[_save_slot_selection] if _save_slot_selection >= 0 and _save_slot_selection < _save_slots.size() else {}


func _save_slot_error_label(error: String) -> String:
	if "资源版本" in error:
		return "资源版本不匹配"
	if "版本不兼容" in error:
		return "存档版本不兼容"
	return "存档文件已损坏"


func _format_save_time(saved_at: String) -> String:
	# 文件保留完整本地时间，320×200 菜单只显示“月-日 时:分”以免越过边框。
	return saved_at.substr(5, 11) if saved_at.length() >= 16 else saved_at


func _fit_pal_text(text: String, maximum_width: int) -> String:
	# 存档可能来自较新的格式；即使时间字段变长，也必须限制在经典窗口的内边界内。
	if _pal_text_width(text) <= maximum_width:
		return text
	var fitted := text
	var suffix := "…"
	while not fitted.is_empty() and _pal_text_width(fitted + suffix) > maximum_width:
		fitted = fitted.substr(0, fitted.length() - 1)
	return fitted + suffix


func _wrap_pal_text(text: String, maximum_width: int, maximum_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	var current_width := 0
	var consumed := 0
	for character in text:
		var width := 16 if _font_glyphs.has(str(character)) else 8
		if not current.is_empty() and current_width + width > maximum_width:
			lines.append(current)
			current = ""
			current_width = 0
			if lines.size() >= maximum_lines:
				break
		current += character
		current_width += width
		consumed += 1
	if lines.size() < maximum_lines and not current.is_empty():
		lines.append(current)
	if consumed < text.length() and not lines.is_empty():
		var suffix := "…"
		while not lines[-1].is_empty() and _pal_text_width(lines[-1] + suffix) > maximum_width:
			lines[-1] = lines[-1].substr(0, lines[-1].length() - 1)
		lines[-1] += suffix
	return lines


func _pal_text_width(text: String) -> int:
	var width := 0
	for character in text:
		width += 16 if _font_glyphs.has(str(character)) else 8
	return width


func _change_selected_volume(delta: int) -> void:
	if _system_selection == 2:
		session.change_music_volume(delta)
	elif _system_selection == 3:
		session.change_sound_volume(delta)
	else:
		return
	audio_settings_changed.emit(session.music_volume, session.sound_volume)


func _open_magic_menu() -> void:
	if session.party_roles.is_empty():
		_last_feedback = "当前没有可以施展仙术的队员。"
		return
	_magic_caster_selection = clampi(_magic_caster_selection, 0, session.party_roles.size() - 1)
	if session.party_roles.size() == 1:
		_open_selected_caster_magic_list()
	else:
		current_page = Page.MAGIC_CASTER


func _open_selected_caster_magic_list() -> void:
	var role_index := _selected_magic_caster_role()
	if role_index < 0 or _role_value(session.role_hp, role_index) <= 0:
		_last_feedback = "这名队员目前无法施展仙术。"
		return
	_refresh_magic_entries()
	current_page = Page.MAGIC_LIST


func _refresh_magic_entries() -> void:
	_magic_entries.clear()
	_magic_selection = 0
	var role_index := _selected_magic_caster_role()
	if role_index < 0 or role_index >= session.learned_magics_by_role.size():
		return
	var object_ids := session.learned_magics_by_role[role_index].duplicate()
	object_ids.sort()
	var current_mp := _role_value(session.role_mp, role_index)
	for object_id in object_ids:
		var object := database.magic_object_definition(object_id)
		var definition := database.magic_definition_for_object(object_id)
		if object == null or definition == null:
			continue
		_magic_entries.append({
			"object_id": object_id,
			"mp_cost": definition.mp_cost,
			"enabled": object.is_usable_outside_battle() and definition.mp_cost <= current_mp,
		})


func _confirm_magic_selection() -> void:
	var entry := _selected_magic_entry()
	if entry.is_empty() or not bool(entry.get("enabled", false)):
		_last_feedback = "真气不足，或该仙术不能在战斗外使用。"
		return
	var object := database.magic_object_definition(int(entry.get("object_id", 0)))
	if object == null:
		return
	if object.applies_to_all():
		_request_selected_magic(-1)
	else:
		_magic_target_selection = clampi(_magic_target_selection, 0, maxi(0, session.party_roles.size() - 1))
		current_page = Page.MAGIC_TARGET


func _request_selected_magic(target_role_index: int) -> void:
	var entry := _selected_magic_entry()
	var caster_role_index := _selected_magic_caster_role()
	if entry.is_empty() or caster_role_index < 0 or not bool(entry.get("enabled", false)):
		return
	magic_use_requested.emit(int(entry.get("object_id", 0)), caster_role_index, target_role_index)


func _selected_magic_caster_role() -> int:
	if session == null or session.party_roles.is_empty():
		return -1
	_magic_caster_selection = clampi(_magic_caster_selection, 0, session.party_roles.size() - 1)
	return session.party_roles[_magic_caster_selection]


func _selected_magic_target_role() -> int:
	if session == null or session.party_roles.is_empty():
		return -1
	_magic_target_selection = clampi(_magic_target_selection, 0, session.party_roles.size() - 1)
	return session.party_roles[_magic_target_selection]


func _selected_magic_entry() -> Dictionary:
	return _magic_entries[_magic_selection] if _magic_selection >= 0 and _magic_selection < _magic_entries.size() else {}


func _magic_page_start() -> int:
	var start := int(_magic_selection / MAGIC_COLUMNS) * MAGIC_COLUMNS - MAGIC_COLUMNS * 2
	return maxi(0, start)


func _open_item_selection() -> void:
	_refresh_inventory()
	current_page = Page.INVENTORY
	show()
	queue_redraw()


func _refresh_inventory() -> void:
	_inventory_ids.clear()
	for raw_id in session.inventory:
		var item_id := int(raw_id)
		var item := database.item_definition(item_id)
		var matches_mode := item != null and (item.is_equipable() if _inventory_for_equipment else true)
		if session.item_count(item_id) > 0 and matches_mode:
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


func _open_equipment_page(item_id: int) -> void:
	var item := database.item_definition(item_id)
	if item == null or not item.is_equipable() or session.item_count(item_id) <= 0:
		_last_feedback = "这个物品目前不能装备。"
		return
	_equipment_item_id = item_id
	_equipment_party_selection = clampi(_equipment_party_selection, 0, maxi(0, session.party_roles.size() - 1))
	current_page = Page.EQUIPMENT


func _request_item_equip() -> void:
	if _equipment_item_id <= 0 or session.party_roles.is_empty():
		return
	var role_index := session.party_roles[_equipment_party_selection]
	var item := database.item_definition(_equipment_item_id)
	if item == null or not item.can_equip_by_role(role_index):
		_last_feedback = "%s不能装备%s" % [database.get_word(database.player_roles.name_word_for(role_index)), database.get_word(_equipment_item_id)]
		return
	item_equip_requested.emit(_equipment_item_id, role_index)


func _load_classic_resources() -> void:
	_ui_sprite = database.load_ui_sprite()
	_palette = database.load_palette(session.palette_index, session.night_palette)
	_ui_textures.clear()
	_item_textures.clear()
	_equipment_background_texture = null
	_status_background_texture = null
	_portrait_textures.clear()
	_font_texture = null
	_font_glyphs.clear()
	var metadata_path := database.root_path.path_join("text/font_glyphs.json")
	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file != null:
		var parsed = JSON.parse_string(metadata_file.get_as_text())
		if parsed is Dictionary:
			_font_glyphs = PalClassicFont.with_compatibility_aliases(parsed.get("glyphs", {}))
	_font_texture = PalClassicFont.load_atlas_texture(database.root_path.path_join("text/font_atlas.png"))
	var equipment_background := database.load_battle_background(1)
	if equipment_background.is_valid() and not _palette.is_empty():
		_equipment_background_texture = ImageTexture.create_from_image(equipment_background.to_rgba_image(_palette))
	var status_background := database.load_battle_background(0)
	if status_background.is_valid() and not _palette.is_empty():
		_status_background_texture = ImageTexture.create_from_image(status_background.to_rgba_image(_palette))


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


func _draw_portrait(portrait_number: int, position: Vector2i) -> void:
	if not _portrait_textures.has(portrait_number):
		var indexed := database.load_rgm_portrait(portrait_number)
		_portrait_textures[portrait_number] = ImageTexture.create_from_image(indexed.to_rgba_image(_palette)) if indexed.is_valid() and not _palette.is_empty() else null
	var texture: Texture2D = _portrait_textures.get(portrait_number)
	if texture != null:
		draw_texture(texture, Vector2(position))


func _role_value(values: PackedInt32Array, role_index: int) -> int:
	return values[role_index] if role_index >= 0 and role_index < values.size() else 0


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
