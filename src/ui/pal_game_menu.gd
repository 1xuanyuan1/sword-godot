# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalGameMenu
extends Control

signal item_use_requested(item_id: int)

enum Page {
	MAIN,
	INVENTORY,
}

var database: PalContentDatabase
var session: GameSession
var current_page: Page = Page.MAIN

var _panel: PanelContainer
var _content: VBoxContainer
var _hint: Label


func _ready() -> void:
	_build_shell()
	hide()


func configure(content_database: PalContentDatabase, game_session: GameSession) -> void:
	database = content_database
	session = game_session


func open_main() -> void:
	if database == null or session == null:
		return
	show()
	current_page = Page.MAIN
	_show_main_page()


func open_inventory() -> void:
	if database == null or session == null:
		return
	show()
	current_page = Page.INVENTORY
	_show_inventory_page()


func close_menu() -> void:
	hide()


func go_back() -> void:
	if current_page == Page.INVENTORY:
		current_page = Page.MAIN
		_show_main_page()
	else:
		close_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo() or event is not InputEventKey:
		return
	if event.keycode in [KEY_ESCAPE, KEY_M, KEY_TAB]:
		go_back()
		get_viewport().set_input_as_handled()


func _build_shell() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101827")
	panel_style.border_color = Color("c4a96a")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 7
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 7
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_panel.add_child(_content)


func _show_main_page() -> void:
	_prepare_page(Rect2(8, 28, 120, 152))
	_add_title("菜单")
	_add_info("金钱　%d 文" % session.cash, Color("fde68a"))
	_add_placeholder_button("状态")
	_add_placeholder_button("法术")
	var inventory_button := _add_button("物品", open_inventory)
	_add_placeholder_button("系统")
	_hint = _add_info("方向键选择　空格确认　Esc关闭", Color("94a3b8"), 7)
	inventory_button.call_deferred("grab_focus")


func _show_inventory_page() -> void:
	_prepare_page(Rect2(22, 14, 276, 172))
	_add_title("物品")
	_hint = _add_info("选择物品使用；Esc 返回", Color("94a3b8"), 8)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	var item_ids: Array[int] = []
	for raw_id in session.inventory:
		var item_id := int(raw_id)
		if session.item_count(item_id) > 0:
			item_ids.append(item_id)
	item_ids.sort()
	var first_button: Button
	for item_id in item_ids:
		var item := database.item_definition(item_id)
		var item_name := database.get_word(item_id)
		if item_name.is_empty():
			item_name = "物品 %d" % item_id
		var button := Button.new()
		button.text = "%s　×%d" % [item_name, session.item_count(item_id)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		_apply_compact_button_style(button)
		button.pressed.connect(_request_item_use.bind(item_id, item))
		list.add_child(button)
		if first_button == null:
			first_button = button
	if first_button == null:
		_add_info("背包里还没有物品。", Color("e2e8f0"), 10, list)
	else:
		first_button.call_deferred("grab_focus")
	_add_button("返回", go_back)


func _request_item_use(item_id: int, item: PalItemDefinition) -> void:
	if item == null or not item.is_usable():
		_hint.text = "这个物品目前不能使用。"
		return
	if not item.applies_to_all():
		_hint.text = "需要选择角色的物品将在下一阶段开放。"
		return
	item_use_requested.emit(item_id)


func _add_placeholder_button(label: String) -> Button:
	return _add_button(label + "（后续）", func() -> void: _hint.text = "%s系统将在后续里程碑补齐。" % label)


func _add_button(label: String, callback: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 9)
	_apply_compact_button_style(button)
	button.pressed.connect(callback)
	(parent if parent != null else _content).add_child(button)
	return button


func _add_title(text: String) -> Label:
	return _add_info(text, Color("fbbf24"), 13)


func _add_info(text: String, color: Color, font_size: int = 9, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	(parent if parent != null else _content).add_child(label)
	return label


func _apply_compact_button_style(button: Button) -> void:
	button.custom_minimum_size.y = 18
	var colors := {
		"normal": Color("172033"),
		"hover": Color("26344d"),
		"pressed": Color("3b4b68"),
		"focus": Color("26344d"),
	}
	for state in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = colors[state]
		style.border_color = Color("6f86a8") if state == "focus" else Color("334155")
		style.set_border_width_all(1)
		style.content_margin_left = 5
		style.content_margin_top = 1
		style.content_margin_right = 5
		style.content_margin_bottom = 1
		button.add_theme_stylebox_override(state, style)


func _prepare_page(bounds: Rect2) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_panel.position = bounds.position
	_panel.size = bounds.size
