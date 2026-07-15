# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h OBJECT_ITEM_DOS.
# SPDX-License-Identifier: GPL-3.0-or-later
## DOS 版 PAL 的物品定义，保存图标、脚本入口、价格和用途标志。
## 物品数量属于 `GameSession`，不会写回这个静态内容对象。
class_name PalItemDefinition
extends RefCounted

const BYTE_SIZE := 12
const FLAG_USABLE := 1 << 0
const FLAG_EQUIPABLE := 1 << 1
const FLAG_THROWABLE := 1 << 2
const FLAG_CONSUMING := 1 << 3
const FLAG_APPLY_TO_ALL := 1 << 4
const FLAG_SELLABLE := 1 << 5

## 在 OBJECT 表和背包中使用的对象编号。
var object_id: int = 0
## `BALL.MKF` 中的物品图标分块编号。
var bitmap: int = 0
## 商店基础价格。
var price: int = 0
## 使用物品时执行的脚本入口。
var script_on_use: int = 0
## 装备物品时执行的脚本入口。
var script_on_equip: int = 0
## 投掷物品时执行的脚本入口。
var script_on_throw: int = 0
## SDLPal `kItemFlag*` 位集合。
var flags: int = 0


## 解析 DOS OBJECT 表的一项；结构越界时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalItemDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var item := PalItemDefinition.new()
	item.object_id = id
	item.bitmap = PalBinary.u16_le(data, offset)
	item.price = PalBinary.u16_le(data, offset + 2)
	item.script_on_use = PalBinary.u16_le(data, offset + 4)
	item.script_on_equip = PalBinary.u16_le(data, offset + 6)
	item.script_on_throw = PalBinary.u16_le(data, offset + 8)
	item.flags = PalBinary.u16_le(data, offset + 10)
	return item


## 是否允许从物品菜单主动使用。
func is_usable() -> bool:
	return (flags & FLAG_USABLE) != 0 and script_on_use > 0


## 使用成功后是否消耗一个物品。
func is_consuming() -> bool:
	return (flags & FLAG_CONSUMING) != 0


## 使用目标是否为全体队员。
func applies_to_all() -> bool:
	return (flags & FLAG_APPLY_TO_ALL) != 0
