# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h OBJECT_POISON.
# SPDX-License-Identifier: GPL-3.0-or-later
## DOS OBJECT 表中的毒定义，保存毒等级、头像色和敌我每回合脚本入口。
## 当前中毒对象和递进脚本游标属于 GameSession 或单场 EnemyState，不写回本静态定义。
extends RefCounted

const BYTE_SIZE := 12

## 一条解析后的毒静态记录。
class PoisonData extends RefCounted:
	## OBJECT 表中的对象编号，也是 WORD.DAT 中毒名称的索引。
	var object_id: int = 0
	## 解毒脚本用于比较的毒等级；99 通常表示装备产生的持久效果。
	var poison_level: int = 0
	## 原版状态页绘制角色头像时使用的调色板颜色索引。
	var color: int = 0
	## 玩家中毒后立即执行并在经典回合末继续执行的脚本入口。
	var player_script: int = 0
	## 敌人中毒后立即执行并在经典回合末继续执行的脚本入口。
	var enemy_script: int = 0


## 从 12 字节 DOS OBJECT 项解析毒视图；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PoisonData:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var definition := PoisonData.new()
	definition.object_id = id
	definition.poison_level = PalBinary.u16_le(data, offset)
	definition.color = PalBinary.u16_le(data, offset + 2)
	definition.player_script = PalBinary.u16_le(data, offset + 4)
	definition.enemy_script = PalBinary.u16_le(data, offset + 8)
	return definition
