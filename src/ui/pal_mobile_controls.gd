# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 移动端探索 HUD：按下地图才出现的浮动摇杆、左上菜单键和右下互动键。
class_name PalMobileControls
extends Control

const MobileInput := preload("res://src/ui/pal_mobile_input.gd")

## 玩家点击左上角固定菜单入口。
signal menu_requested
## 玩家点击右下角互动键。
signal interact_requested

const MENU_RECT := Rect2(4, 4, 38, 22)
const INTERACT_RECT := Rect2(270, 154, 46, 42)
const JOYSTICK_RADIUS := 30.0
const JOYSTICK_DEAD_ZONE := 7.0

## 测试可在加入场景树前强制显示；正式运行仍由平台或命令行参数决定。
var force_touch_ui: bool = false

var _touch_ui_enabled: bool = false
var _exploration_available: bool = false
var _joystick_active: bool = false
var _joystick_pointer_id: int = -1
var _joystick_center := Vector2.ZERO
var _joystick_knob := Vector2.ZERO
var _movement_vector := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_ui_enabled = force_touch_ui or MobileInput.touch_ui_enabled()
	visible = false
	set_process_input(true)


## 只在没有剧情、菜单、战斗或转场阻塞的自由探索阶段显示并接收输入。
func set_exploration_available(available: bool) -> void:
	var next_visible := _touch_ui_enabled and available
	if _exploration_available == available and visible == next_visible:
		return
	_exploration_available = available
	visible = next_visible
	if not visible:
		_clear_joystick()
	queue_redraw()


## 返回当前摇杆的归一化拖动方向和强度。
func movement_vector() -> Vector2:
	return _movement_vector


## 返回浮动摇杆是否已经由某个指针按下并显示。
func joystick_active() -> bool:
	return _joystick_active


func _input(event: InputEvent) -> void:
	if not visible or not _exploration_available:
		return
	var handled := false
	if MobileInput.is_primary_press(event):
		handled = handle_pointer_press(MobileInput.pointer_position(event), MobileInput.pointer_index(event))
	elif MobileInput.is_primary_drag(event):
		handled = handle_pointer_drag(MobileInput.pointer_position(event), MobileInput.pointer_index(event))
	elif MobileInput.is_primary_release(event):
		handled = handle_pointer_release(MobileInput.pointer_index(event))
	if handled:
		var input_viewport := get_viewport()
		if input_viewport != null:
			input_viewport.set_input_as_handled()


## 返回是否消费该指针；公开这些小入口便于合成触摸回归，不依赖物理设备。
func handle_pointer_press(point: Vector2, pointer_id: int) -> bool:
	if not _exploration_available:
		return false
	if MENU_RECT.has_point(point):
		_clear_joystick()
		menu_requested.emit()
		return true
	if INTERACT_RECT.has_point(point):
		interact_requested.emit()
		return true
	if _joystick_active:
		return false
	_joystick_active = true
	_joystick_pointer_id = pointer_id
	_joystick_center = point
	_joystick_knob = point
	_movement_vector = Vector2.ZERO
	queue_redraw()
	return true


## 更新当前摇杆指针；其他手指的拖动不会抢占移动。
func handle_pointer_drag(point: Vector2, pointer_id: int) -> bool:
	if not _joystick_active or pointer_id != _joystick_pointer_id:
		return false
	var offset := point - _joystick_center
	var distance := offset.length()
	_joystick_knob = _joystick_center + offset.limit_length(JOYSTICK_RADIUS)
	if distance <= JOYSTICK_DEAD_ZONE:
		_movement_vector = Vector2.ZERO
	else:
		var strength := clampf((distance - JOYSTICK_DEAD_ZONE) / (JOYSTICK_RADIUS - JOYSTICK_DEAD_ZONE), 0.0, 1.0)
		_movement_vector = offset.normalized() * strength
	queue_redraw()
	return true


## 仅活动指针松手时隐藏摇杆并把移动归零。
func handle_pointer_release(pointer_id: int) -> bool:
	if not _joystick_active or pointer_id != _joystick_pointer_id:
		return false
	_clear_joystick()
	return true


func _clear_joystick() -> void:
	_joystick_active = false
	_joystick_pointer_id = -1
	_movement_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	_draw_touch_button(MENU_RECT, "菜单")
	_draw_touch_button(INTERACT_RECT, "互动")
	if _joystick_active:
		draw_circle(_joystick_center, JOYSTICK_RADIUS, Color(0.02, 0.03, 0.06, 0.36))
		draw_arc(_joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.93, 0.82, 0.58, 0.8), 1.2, true)
		draw_circle(_joystick_knob, 11.0, Color(0.93, 0.82, 0.58, 0.72))
		draw_arc(_joystick_knob, 11.0, 0.0, TAU, 32, Color.WHITE, 1.0, true)


func _draw_touch_button(rect: Rect2, label: String) -> void:
	draw_rect(rect, Color(0.02, 0.03, 0.06, 0.72), true)
	draw_rect(rect, Color(0.93, 0.82, 0.58, 0.9), false, 1.0)
	var font := ThemeDB.fallback_font
	var font_size := 9
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5 - 1.0)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
