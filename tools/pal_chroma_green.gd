# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 图片制作板的绿幕颜色判定。覆盖纯亮绿及图片模型生成的低亮度绿色渐变。
class_name PalChromaGreen
extends RefCounted


static func matches(color: Color) -> bool:
	var red_or_blue := maxf(color.r, color.b)
	return color.g >= 0.08 \
		and color.g - red_or_blue >= 0.08 \
		and color.g >= red_or_blue * 1.25
