# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h ENEMYTEAM.
# SPDX-License-Identifier: GPL-3.0-or-later
## `DATA.MKF #2` 的五槽敌队定义；槽位保存 OBJECT 表敌人对象编号。
## `0xFFFF` 是空洞，零值不生成可战斗敌人，但原始槽位会完整保留用于诊断。
class_name PalEnemyTeam
extends RefCounted

const MAX_ENEMIES := 5
const BYTE_SIZE := MAX_ENEMIES * 2

## 敌队表索引，即脚本操作码 `0007` 的第一个操作数。
var team_id: int = 0
## 五个原始敌人对象槽位。
var object_ids: PackedInt32Array = PackedInt32Array()


## 从 10 字节记录解析敌队；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalEnemyTeam:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var team := PalEnemyTeam.new()
	team.team_id = id
	for index in range(MAX_ENEMIES):
		team.object_ids.append(PalBinary.u16_le(data, offset + index * 2))
	return team


## 返回按原版顺序压紧后的非零、非 `0xFFFF` 敌人对象编号。
func active_object_ids() -> PackedInt32Array:
	var result := PackedInt32Array()
	for object_id in object_ids:
		if object_id != 0 and object_id != 0xffff:
			result.append(object_id)
	return result
