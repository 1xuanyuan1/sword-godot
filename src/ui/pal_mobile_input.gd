# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 统一识别触屏与主鼠标指针，供 320×200 PAL 界面复用同一套命中逻辑。
class_name PalMobileInput
extends RefCounted

const FORCE_TOUCH_UI_ARGUMENT := "--pal-mobile-controls"


## Android/iOS 自动启用；桌面可用隐藏参数强制显示，供带窗口回归和鼠标模拟。
static func touch_ui_enabled() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or DisplayServer.is_touchscreen_available() or FORCE_TOUCH_UI_ARGUMENT in OS.get_cmdline_user_args()


## 主触摸按下或鼠标左键按下均视为一次直接确认。
static func is_primary_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed


## 返回主触摸或鼠标左键是否刚刚释放。
static func is_primary_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.pressed
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed


## 读取触摸、拖动或鼠标事件在 320×200 Viewport 中的逻辑坐标。
static func pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		return event.position
	return Vector2.INF


## 全局输入回调使用：384×216 时减去 (32,8)，核心区外不允许命中旧 UI。
## Control._gui_input 已经收到本地坐标，不应调用此函数重复换算。
static func classic_pointer_position(event: InputEvent, viewport_size: Vector2i, reject_outside: bool = true) -> Vector2:
	var point := pointer_position(event)
	if not point.is_finite():
		return Vector2.INF
	var remaster_enabled := viewport_size == PalPresentationMetrics.REMASTER_LOGICAL_SIZE
	if remaster_enabled and not reject_outside:
		return point - Vector2(PalPresentationMetrics.REMASTER_CLASSIC_OFFSET)
	return PalPresentationMetrics.logical_to_classic_ui(point, remaster_enabled)


## 多点触摸保留 Godot 指针编号；鼠标固定使用零号指针。
static func pointer_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.index
	return 0


## 判断事件是否为屏幕拖动或按住左键的鼠标移动。
static func is_primary_drag(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		return true
	return event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
