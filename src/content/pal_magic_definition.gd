# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h MAGIC.
# SPDX-License-Identifier: GPL-3.0-or-later
## `DATA.MKF #4` 的 32 字节仙术属性记录，保存特效、类型、消耗和基础伤害。
## 仙术名称与脚本位于 OBJECT 表，实际战斗结算由战斗控制器负责。
class_name PalMagicDefinition
extends RefCounted

const BYTE_SIZE := 32

## DATA.MKF 仙术表中的记录编号。
var magic_number: int = 0
## `FIRE.MKF` 中的特效 Sprite 编号。
var effect_sprite: int = 0
## SDLPal `MAGIC_TYPE` 类型编号。
var magic_type: int = 0
## 特效相对目标的横向偏移。
var x_offset: int = 0
## 特效相对目标的纵向偏移。
var y_offset: int = 0
## 召唤特效编号或普通仙术的图层偏移原始值。
var specific: int = 0
## 特效播放速度；按有符号 16 位读取。
var speed: int = 0
## 是否保留最后一帧特效的原始标志。
var keep_effect: int = 0
## 特效开始造成作用的帧编号。
var fire_delay: int = 0
## 特效重复次数。
var effect_times: int = 0
## 屏幕震动强度。
var shake: int = 0
## 屏幕波动强度。
var wave: int = 0
## 原版尚未命名的兼容字段。
var unknown: int = 0
## 使用仙术需要消耗的真气。
var mp_cost: int = 0
## 仙术基础伤害；治疗和脚本仙术可能使用不同语义。
var base_damage: int = 0
## 五灵属性编号，零表示无属性。
var elemental: int = 0
## 使用仙术时播放的音效编号；按有符号 16 位读取。
var sound: int = 0


## 从 DATA.MKF 仙术分块解析一项；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalMagicDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var definition := PalMagicDefinition.new()
	definition.magic_number = id
	definition.effect_sprite = PalBinary.u16_le(data, offset)
	definition.magic_type = PalBinary.u16_le(data, offset + 2)
	definition.x_offset = PalBinary.u16_le(data, offset + 4)
	definition.y_offset = PalBinary.u16_le(data, offset + 6)
	definition.specific = PalBinary.u16_le(data, offset + 8)
	definition.speed = PalBinary.i16_le(data, offset + 10)
	definition.keep_effect = PalBinary.u16_le(data, offset + 12)
	definition.fire_delay = PalBinary.u16_le(data, offset + 14)
	definition.effect_times = PalBinary.u16_le(data, offset + 16)
	definition.shake = PalBinary.u16_le(data, offset + 18)
	definition.wave = PalBinary.u16_le(data, offset + 20)
	definition.unknown = PalBinary.u16_le(data, offset + 22)
	definition.mp_cost = PalBinary.u16_le(data, offset + 24)
	definition.base_damage = PalBinary.u16_le(data, offset + 26)
	definition.elemental = PalBinary.u16_le(data, offset + 28)
	definition.sound = PalBinary.i16_le(data, offset + 30)
	return definition
