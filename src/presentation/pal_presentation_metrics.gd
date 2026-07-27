# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典 PAL 内容与高清输出画布之间的共享尺寸规则。
## 原始地图、RNG、FBP 与战斗仍以 320×200 为逻辑和像素基准；高清模式只改变最终展示画布。
class_name PalPresentationMetrics
extends RefCounted

const CLASSIC_CONTENT_SIZE := Vector2i(320, 200)
const DEFAULT_REMASTER_SCALE := 5
const DEFAULT_REMASTER_CANVAS_SIZE := Vector2i(1920, 1080)
const SAFE_MARGIN := 64
const DIALOG_HEIGHT := 300


## 返回能完整容纳经典画面的最大整数缩放；输出小于经典尺寸时保持 1 倍。
static func integer_scale_for_output(output_size: Vector2i) -> int:
	if output_size.x <= 0 or output_size.y <= 0:
		return 1
	return maxi(1, mini(
		output_size.x / CLASSIC_CONTENT_SIZE.x,
		output_size.y / CLASSIC_CONTENT_SIZE.y
	))


## 在任意高清输出画布中居中安放整数缩放后的经典内容，剩余区域留给高清 UI 或信箱边框。
static func classic_content_rect(output_size: Vector2i) -> Rect2i:
	var scale := integer_scale_for_output(output_size)
	var content_size := CLASSIC_CONTENT_SIZE * scale
	return Rect2i((output_size - content_size) / 2, content_size)


## 返回扣除 64px 四边安全距离后的高清 UI 区域；过小画布返回空矩形。
static func safe_ui_rect(output_size: Vector2i) -> Rect2i:
	if output_size.x <= SAFE_MARGIN * 2 or output_size.y <= SAFE_MARGIN * 2:
		return Rect2i()
	return Rect2i(Vector2i(SAFE_MARGIN, SAFE_MARGIN), output_size - Vector2i(SAFE_MARGIN * 2, SAFE_MARGIN * 2))


## 返回 1080p 基准下的底部水墨对话区域，并保持在 UI 安全区内。
static func dialog_rect(output_size: Vector2i) -> Rect2i:
	var safe_rect := safe_ui_rect(output_size)
	if safe_rect.size == Vector2i.ZERO:
		return Rect2i()
	var height := mini(DIALOG_HEIGHT, safe_rect.size.y)
	return Rect2i(Vector2i(safe_rect.position.x, safe_rect.end.y - height), Vector2i(safe_rect.size.x, height))
