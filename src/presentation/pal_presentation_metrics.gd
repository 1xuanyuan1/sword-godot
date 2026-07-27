# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典 PAL 内容与高清输出画布之间的共享尺寸规则。
## 原始地图、RNG、FBP 与战斗仍以 320×200 为逻辑和像素基准；高清模式只改变最终展示画布。
class_name PalPresentationMetrics
extends RefCounted

const CLASSIC_CONTENT_SIZE := Vector2i(320, 200)
const DEFAULT_REMASTER_SCALE := 4
const DEFAULT_REMASTER_CANVAS_SIZE := CLASSIC_CONTENT_SIZE * DEFAULT_REMASTER_SCALE


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
