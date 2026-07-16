# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h OBJECT_ENEMY.
# SPDX-License-Identifier: GPL-3.0-or-later
## DOS OBJECT 表中的敌人对象入口，把剧情使用的对象编号映射到敌人属性与战斗脚本。
## 这里只保存静态定义；战斗中的当前体力、状态和位置由战斗会话持有。
class_name PalEnemyObjectDefinition
extends RefCounted

const BYTE_SIZE := 12

## OBJECT 表中的对象编号，也是敌队数组保存的编号。
var object_id: int = 0
## `DATA.MKF #1` 中的敌人属性索引，同时也是 `ABC.MKF` Sprite 编号。
var enemy_id: int = 0
## 法术与毒抗性，原版范围通常为 0–10。
var resistance_to_sorcery: int = 0
## 每回合开始时执行的脚本入口。
var script_on_turn_start: int = 0
## 战斗结束时执行的脚本入口。
var script_on_battle_end: int = 0
## 敌人准备行动时执行的脚本入口。
var script_on_ready: int = 0


## 从 12 字节 DOS OBJECT 项解析敌人视图；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalEnemyObjectDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var definition := PalEnemyObjectDefinition.new()
	definition.object_id = id
	definition.enemy_id = PalBinary.u16_le(data, offset)
	definition.resistance_to_sorcery = PalBinary.u16_le(data, offset + 2)
	definition.script_on_turn_start = PalBinary.u16_le(data, offset + 4)
	definition.script_on_battle_end = PalBinary.u16_le(data, offset + 6)
	definition.script_on_ready = PalBinary.u16_le(data, offset + 8)
	return definition
