# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal util.c lsrand/lrand/RandomLong/RandomFloat.
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典战斗专用的可复现伪随机数生成器，保持 SDLPal 32 位 LCG 的调用顺序。
## 战斗测试可固定种子，正式运行则由 `PalBattleController` 注入当前时间种子。
class_name PalBattleRandom
extends RefCounted

const UINT32_MASK := 0xffffffff
const UINT32_MODULUS := 0x100000000
const INT32_SIGN_BIT := 0x80000000
const INT32_MAX_VALUE := 0x7fffffff

var _state: int = 0


## 按 SDLPal `lsrand()` 初始化 32 位状态；相同种子会产生相同序列。
func set_seed(seed_value: int) -> void:
	_state = _advance_raw(seed_value & UINT32_MASK)


## 返回闭区间 `[from_value, to_value]` 内的整数。
## 上界不大于下界时沿用 SDLPal 行为，直接返回下界。
func next_int(from_value: int, to_value: int) -> int:
	if to_value <= from_value:
		return from_value
	var width := to_value - from_value + 1
	var divisor := maxi(1, INT32_MAX_VALUE / width)
	# 原版用整数除法缩放 31 位随机数；极端最大值可能因整除余数越过一格，
	# 这里限制回闭区间，避免损坏目标索引。
	return mini(to_value, from_value + _next_31() / divisor)


## 返回闭区间 `[from_value, to_value]` 内的浮点数。
## 上界不大于下界时直接返回下界。
func next_float(from_value: float, to_value: float) -> float:
	if to_value <= from_value:
		return from_value
	return from_value + float(_next_31()) / (float(INT32_MAX_VALUE) / (to_value - from_value))


func _next_31() -> int:
	if _state == 0:
		set_seed(1)
	_state = _advance_raw(_state)
	# C 版 glSeed 是有符号 32 位整数，负值右移后再加 2^30，得到 0..INT_MAX。
	var signed_state := _state if _state < INT32_SIGN_BIT else _state - UINT32_MODULUS
	return (signed_state >> 1) + 0x40000000


static func _advance_raw(value: int) -> int:
	return (1664525 * value + 1013904223) & UINT32_MASK
