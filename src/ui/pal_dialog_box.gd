# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典 PAL 对话框与系统 Toast 控件，支持肖像、说话人、分页和逐字显示。
## 文本轮次由 `ScriptVM` 控制；本控件只维护当前页面的视觉状态。
class_name PalDialogBox
extends Control

const MobileInput := preload("res://src/ui/pal_mobile_input.gd")

## 本轮文字已经完整显示后，玩家点击对话区域请求控制器继续下一轮。
signal advance_requested

const TYPEWRITER_CHARACTERS_PER_SECOND := 28.0
# SDLPal `text.c::TEXT_DisplayText` 把 `$NN` 换算为每字 `NN × 80 / 7` 毫秒。
const PAL_DELAY_SECONDS_PER_UNIT := 0.08 / 7.0
const DEFAULT_CHARACTER_DELAY_SECONDS := 1.0 / TYPEWRITER_CHARACTERS_PER_SECOND

var _panel: PanelContainer
var _dialog_panel: PanelContainer
var _toast_panel: PanelContainer
var _panel_style: StyleBoxFlat
var _portrait_column: VBoxContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _inline_speaker: Label
var _message: RichTextLabel
var _dialog_message: RichTextLabel
var _toast_message: RichTextLabel
var _separator: ColorRect
var _hint: Label
var _position_mode: int = 1
var _full_text: String = ""
var _visible_characters: int = 0
var _character_delays: PackedFloat32Array = PackedFloat32Array()
var _typing_time_budget: float = 0.0
var _current_character_delay: float = DEFAULT_CHARACTER_DELAY_SECONDS
var _pending_pause_seconds: float = 0.0
var _typing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide_dialog()
	set_process(false)


func _process(delta: float) -> void:
	if not _typing:
		return
	var remaining := maxf(0.0, delta)
	while _visible_characters < _full_text.length():
		var character_delay := (
			float(_character_delays[_visible_characters])
			if _visible_characters < _character_delays.size()
			else DEFAULT_CHARACTER_DELAY_SECONDS
		)
		var needed := maxf(0.0, character_delay - _typing_time_budget)
		if remaining < needed:
			_typing_time_budget += remaining
			return
		remaining -= needed
		_typing_time_budget = 0.0
		_set_visible_characters(_visible_characters + 1)
	if _pending_pause_seconds > 0.0:
		_pending_pause_seconds = maxf(0.0, _pending_pause_seconds - remaining)
	if _pending_pause_seconds <= 0.0:
		_typing = false
		set_process(false)
		_hint.text = "▼"


func _input(event: InputEvent) -> void:
	if not visible or not MobileInput.is_primary_press(event):
		return
	handle_primary_press()
	var input_viewport := get_viewport()
	if input_viewport != null:
		input_viewport.set_input_as_handled()


## 第一次点击补完逐字文字；文字完整时发出继续请求。
func handle_primary_press() -> bool:
	if not visible:
		return false
	if is_typing():
		reveal_all()
	else:
		advance_requested.emit()
	return true


## 开始新的对话上下文并清空旧页面；位置模式与 SDLPal 对话操作码一致。
func begin(position_mode: int, _color_index: int = 0, portrait_texture: Texture2D = null) -> void:
	_position_mode = position_mode
	var is_toast := _position_mode == 3
	_panel = _toast_panel if is_toast else _dialog_panel
	_message = _toast_message if is_toast else _dialog_message
	_dialog_panel.visible = not is_toast
	_toast_panel.visible = is_toast
	_full_text = ""
	_visible_characters = 0
	_character_delays.clear()
	_typing_time_budget = 0.0
	_current_character_delay = DEFAULT_CHARACTER_DELAY_SECONDS
	_pending_pause_seconds = 0.0
	_typing = false
	set_process(false)
	_speaker.text = ""
	_inline_speaker.text = ""
	_message.text = ""
	_message.visible_characters = 0
	_portrait.texture = portrait_texture
	_apply_mode_style()
	_apply_position()
	_separator.visible = false
	_hint.visible = false
	visible = true


## 把一行正文追加到当前轮次，按可用像素宽度自动换行并启动逐字显示。
func show_message(text: String) -> void:
	if not visible:
		begin(_position_mode)
	var decoded := _decode_pal_dialog_text(text.strip_edges())
	var content := str(decoded.get("text", ""))
	_current_character_delay = float(decoded.get("character_delay", _current_character_delay))
	_pending_pause_seconds = float(decoded.get("trailing_pause", _pending_pause_seconds))
	if _is_speaker_title(content):
		content = content.trim_suffix(":").trim_suffix("：").trim_suffix("∶")
		_speaker.text = content
		_inline_speaker.text = content
		_separator.visible = not content.is_empty()
		return
	if content.is_empty():
		return
	_full_text += content
	var decoded_delays: PackedFloat32Array = decoded.get("character_delays", PackedFloat32Array())
	_character_delays.append_array(decoded_delays)
	_message.text = _full_text
	_typing = _visible_characters < _full_text.length() or _pending_pause_seconds > 0.0
	set_process(_typing)
	_hint.text = "▶" if _typing else "▼"
	_hint.visible = _position_mode != 3


## 设置说话人标题，并在原脚本缺少肖像时使用推断得到的后备肖像。
func show_speaker_title(text: String, fallback_portrait: Texture2D = null) -> void:
	# A redraw or wait may hide the previous dialog while leaving its texture cached.
	# Start the implicit round first so fallback portrait selection sees the real state.
	if not visible:
		begin(_position_mode)
	if not has_portrait() and fallback_portrait != null:
		set_portrait(fallback_portrait)
	show_message(text)


## 返回当前页面是否仍在逐字显示。
func is_typing() -> bool:
	return _typing


## 立即显示本轮已收到的全部文字，不跳过下一轮角色对话。
func reveal_all() -> void:
	if _full_text.is_empty():
		return
	_typing_time_budget = 0.0
	_pending_pause_seconds = 0.0
	_set_visible_characters(_full_text.length())


## 保留对话上下文和肖像，清空正文并开始下一页。
func next_page() -> void:
	if not visible:
		return
	_reset_body()


## 返回当前对话上下文是否拥有有效肖像。
func has_portrait() -> bool:
	return _portrait != null and _portrait.texture != null


## 替换当前肖像纹理；传入 `null` 时隐藏肖像区域。
func set_portrait(portrait_texture: Texture2D) -> void:
	_portrait.texture = portrait_texture
	_portrait_column.visible = _position_mode != 3 and portrait_texture != null
	_inline_speaker.visible = _position_mode != 3 and portrait_texture == null


## 结束对话并清空标题、正文、肖像和逐字状态。
func hide_dialog() -> void:
	visible = false
	if _dialog_panel != null:
		_dialog_panel.visible = false
	if _toast_panel != null:
		_toast_panel.visible = false
	_reset_body()


func _reset_body() -> void:
	_full_text = ""
	_visible_characters = 0
	_character_delays.clear()
	_typing_time_budget = 0.0
	_pending_pause_seconds = 0.0
	_typing = false
	set_process(false)
	if _message != null:
		_message.text = ""
		_message.visible_characters = 0


func _build_interface() -> void:
	_dialog_panel = PanelContainer.new()
	_panel = _dialog_panel
	add_child(_dialog_panel)
	_panel_style = StyleBoxFlat.new()
	_panel_style.corner_radius_top_left = 3
	_panel_style.corner_radius_top_right = 3
	_panel_style.corner_radius_bottom_left = 3
	_panel_style.corner_radius_bottom_right = 3
	_panel_style.content_margin_left = 6
	_panel_style.content_margin_top = 5
	_panel_style.content_margin_right = 6
	_panel_style.content_margin_bottom = 5
	_dialog_panel.add_theme_stylebox_override("panel", _panel_style)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	_dialog_panel.add_child(layout)

	_portrait_column = VBoxContainer.new()
	_portrait_column.custom_minimum_size.x = 70
	_portrait_column.add_theme_constant_override("separation", 1)
	layout.add_child(_portrait_column)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(70, 62)
	_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color("17120d")
	portrait_style.border_color = Color("8f6d3a")
	portrait_style.set_border_width_all(1)
	_portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	_portrait_column.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)

	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_speaker.add_theme_font_size_override("font_size", 8)
	_speaker.add_theme_color_override("font_color", Color("f3c76f"))
	_portrait_column.add_child(_speaker)

	var content_column := VBoxContainer.new()
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 2)
	layout.add_child(content_column)

	_inline_speaker = Label.new()
	_inline_speaker.add_theme_font_size_override("font_size", 9)
	_inline_speaker.add_theme_color_override("font_color", Color("f3c76f"))
	content_column.add_child(_inline_speaker)

	_separator = ColorRect.new()
	_separator.color = Color("8f6d3a")
	_separator.custom_minimum_size.y = 1
	content_column.add_child(_separator)

	_dialog_message = _create_message_label(false)
	_message = _dialog_message
	content_column.add_child(_dialog_message)

	_toast_panel = PanelContainer.new()
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0, 0, 0, 0.94)
	toast_style.corner_radius_top_left = 2
	toast_style.corner_radius_top_right = 2
	toast_style.corner_radius_bottom_left = 2
	toast_style.corner_radius_bottom_right = 2
	toast_style.content_margin_left = 6
	toast_style.content_margin_top = 4
	toast_style.content_margin_right = 6
	toast_style.content_margin_bottom = 4
	_toast_panel.add_theme_stylebox_override("panel", toast_style)
	add_child(_toast_panel)
	_toast_message = _create_message_label(true)
	_toast_panel.add_child(_toast_message)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color("f3c76f"))
	add_child(_hint)
	_apply_position()


func _create_message_label(centered: bool) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if centered else VERTICAL_ALIGNMENT_TOP
	label.scroll_active = false
	label.bbcode_enabled = false
	label.clip_contents = true
	label.add_theme_font_size_override("normal_font_size", 8 if centered else 10)
	label.add_theme_color_override("default_color", Color.WHITE if centered else Color("fff7e8"))
	return label


func _apply_position() -> void:
	if _panel == null:
		return
	var rect := Rect2(6, 104, 308, 90)
	match _position_mode:
		0:
			rect = Rect2(6, 6, 308, 90)
		1:
			rect = Rect2(6, 104, 308, 90)
		2:
			rect = Rect2(16, 55, 288, 90)
		3:
			rect = Rect2(72, 84, 176, 32)
	_panel.position = rect.position
	_panel.size = rect.size
	_hint.position = rect.position + rect.size - Vector2(17, 16)


func _apply_mode_style() -> void:
	var is_toast := _position_mode == 3
	_panel_style.bg_color = Color(0.055, 0.038, 0.025, 0.95)
	_panel_style.border_color = Color("d6a85f")
	_panel_style.set_border_width_all(1)
	_portrait_column.visible = not is_toast and _portrait.texture != null
	_inline_speaker.visible = not is_toast and _portrait.texture == null


func _set_visible_characters(count: int) -> void:
	_visible_characters = clampi(count, 0, _full_text.length())
	_message.visible_characters = _visible_characters
	if _visible_characters >= _full_text.length() and _pending_pause_seconds <= 0.0:
		_typing = false
		set_process(false)
		_hint.text = "▼"


func _decode_pal_dialog_text(text: String) -> Dictionary:
	# M.MSG 内的 `$NN` 和 `~NN` 是显示控制码，不属于正文。前者改变后续
	# 逐字速度，后者在句末短暂停顿；换算公式来自 SDLPal `text.c`。
	var content := ""
	var delays := PackedFloat32Array()
	var character_delay := _current_character_delay
	var pending_pause := _pending_pause_seconds
	var index := 0
	while index < text.length():
		var character := text.substr(index, 1)
		if character in ["$", "~"] and index + 2 < text.length():
			var digits := text.substr(index + 1, 2)
			if digits.is_valid_int():
				var units := digits.to_int()
				if character == "$":
					character_delay = float(units) * PAL_DELAY_SECONDS_PER_UNIT
				else:
					pending_pause += float(units) * PAL_DELAY_SECONDS_PER_UNIT
				index += 3
				continue
		content += character
		delays.append(character_delay + pending_pause)
		pending_pause = 0.0
		index += 1
	return {
		"text": content,
		"character_delays": delays,
		"character_delay": character_delay,
		"trailing_pause": pending_pause,
	}


static func _is_speaker_title(text: String) -> bool:
	return text.ends_with(":") or text.ends_with("：") or text.ends_with("∶")


## 从带中文或英文冒号的标题行提取说话人名字。
static func speaker_name_from_title(text: String) -> String:
	return text.strip_edges().trim_suffix(":").trim_suffix("：").trim_suffix("∶")
