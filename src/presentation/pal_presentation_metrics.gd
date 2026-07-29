# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典 PAL 内容、高清逻辑视野与最终输出画布之间的共享尺寸规则。
## 原始 UI、RNG、FBP 与战斗仍以 320×200 为基准；重制地图视野扩为 384×216。
class_name PalPresentationMetrics
extends RefCounted

const CLASSIC_CONTENT_SIZE := Vector2i(320, 200)
const REMASTER_LOGICAL_SIZE := Vector2i(384, 216)
const REMASTER_CLASSIC_OFFSET := Vector2i(32, 8)
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


## 在输出画布中居中安放最大整数倍的 384×216 重制逻辑视野。
static func remaster_content_rect(output_size: Vector2i) -> Rect2i:
	if output_size.x <= 0 or output_size.y <= 0:
		return Rect2i(Vector2i.ZERO, REMASTER_LOGICAL_SIZE)
	var scale := maxi(1, mini(
		output_size.x / REMASTER_LOGICAL_SIZE.x,
		output_size.y / REMASTER_LOGICAL_SIZE.y
	))
	var content_size := REMASTER_LOGICAL_SIZE * scale
	return Rect2i((output_size - content_size) / 2, content_size)


## 返回当前模式使用的逻辑视口大小。
static func logical_size(remaster_enabled: bool) -> Vector2i:
	return REMASTER_LOGICAL_SIZE if remaster_enabled else CLASSIC_CONTENT_SIZE


## 返回 320×200 经典 UI 在当前逻辑视口中的区域。
static func classic_ui_rect(remaster_enabled: bool) -> Rect2i:
	return Rect2i(REMASTER_CLASSIC_OFFSET if remaster_enabled else Vector2i.ZERO, CLASSIC_CONTENT_SIZE)


## 将 SubViewport 内的逻辑指针坐标映射到经典 UI；核心区外返回 Vector2.INF。
static func logical_to_classic_ui(point: Vector2, remaster_enabled: bool) -> Vector2:
	var rect := Rect2(classic_ui_rect(remaster_enabled))
	if not rect.has_point(point):
		return Vector2.INF
	return point - rect.position


## 将最终窗口坐标按整数缩放映射到经典 UI。信箱边与高清扩展区返回 Vector2.INF。
static func output_to_classic_ui(point: Vector2, output_size: Vector2i, remaster_enabled: bool) -> Vector2:
	var content_rect := remaster_content_rect(output_size) if remaster_enabled else classic_content_rect(output_size)
	if not Rect2(content_rect).has_point(point):
		return Vector2.INF
	var logical := point - Vector2(content_rect.position)
	var logical_size_value := logical_size(remaster_enabled)
	var scale := float(content_rect.size.x) / float(logical_size_value.x)
	if scale <= 0.0:
		return Vector2.INF
	return logical_to_classic_ui(logical / scale, remaster_enabled)


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
