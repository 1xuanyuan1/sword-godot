# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h OBJECT_MAGIC_DOS.
# SPDX-License-Identifier: GPL-3.0-or-later
## DOS OBJECT 表中的仙术对象入口，把词条对象编号映射到 DATA.MKF 仙术记录。
## 本对象只保存静态脚本与目标标志；角色是否学会仙术由 `GameSession` 持有。
class_name PalMagicObjectDefinition
extends RefCounted

const BYTE_SIZE := 12
const FLAG_USABLE_OUTSIDE_BATTLE := 1 << 0
const FLAG_USABLE_IN_BATTLE := 1 << 1
const FLAG_USABLE_TO_ENEMY := 1 << 3
const FLAG_APPLY_TO_ALL := 1 << 4

## OBJECT 表中的对象编号，也是 WORD.DAT 中仙术名称的索引。
var object_id: int = 0
## `DATA.MKF #4` 中的仙术属性记录编号。
var magic_number: int = 0
## 仙术成功后执行的脚本入口。
var script_on_success: int = 0
## 使用仙术时执行的脚本入口。
var script_on_use: int = 0
## SDLPal `kMagicFlag*` 位集合。
var flags: int = 0


## 从 12 字节 DOS OBJECT 项解析仙术视图；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalMagicObjectDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var definition := PalMagicObjectDefinition.new()
	definition.object_id = id
	definition.magic_number = PalBinary.u16_le(data, offset)
	definition.script_on_success = PalBinary.u16_le(data, offset + 4)
	definition.script_on_use = PalBinary.u16_le(data, offset + 6)
	definition.flags = PalBinary.u16_le(data, offset + 10)
	return definition


## 返回仙术是否允许在战斗指令菜单中选择。
func is_usable_in_battle() -> bool:
	return (flags & FLAG_USABLE_IN_BATTLE) != 0


## 返回仙术目标是否为敌方；为假时目标是我方队员。
func is_used_on_enemy() -> bool:
	return (flags & FLAG_USABLE_TO_ENEMY) != 0


## 返回仙术是否作用于目标一方的全体单位。
func applies_to_all() -> bool:
	return (flags & FLAG_APPLY_TO_ALL) != 0
