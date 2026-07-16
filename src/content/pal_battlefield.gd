# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h BATTLEFIELD and ENEMYPOS.
# SPDX-License-Identifier: GPL-3.0-or-later
## 战场效果与敌人站位数据；背景索引与战场编号相同，图像来自 `FBP.MKF`。
## 本类型只解析静态布局，不持有任何一场战斗的角色状态。
class_name PalBattlefield
extends RefCounted

const BYTE_SIZE := 12
const ELEMENT_COUNT := 5

## 战场表索引，也是 `FBP.MKF` 背景分块编号。
var battlefield_id: int = 0
## 原版屏幕波动强度。
var screen_wave: int = 0
## 五灵法术在本战场的有符号效果修正。
var magic_effects: PackedInt32Array = PackedInt32Array()


## 从 12 字节 `DATA.MKF #5` 记录解析战场；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalBattlefield:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var battlefield := PalBattlefield.new()
	battlefield.battlefield_id = id
	battlefield.screen_wave = PalBinary.u16_le(data, offset)
	for index in range(ELEMENT_COUNT):
		battlefield.magic_effects.append(PalBinary.i16_le(data, offset + 2 + index * 2))
	return battlefield


## `DATA.MKF #13` 的 5×5 敌人脚底位置矩阵。
## 第一维是压紧后的敌人索引，第二维是敌人总数减一。
class EnemyPositions extends RefCounted:
	const BYTE_SIZE := PalEnemyTeam.MAX_ENEMIES * PalEnemyTeam.MAX_ENEMIES * 4
	## 以 `[enemy_index * 5 + enemy_count - 1]` 展平保存的脚底坐标。
	var positions: Array[Vector2i] = []
	## 长度或解析失败原因；为空表示尚未发现错误。
	var error_message: String = ""

	## 解析完整 100 字节位置矩阵；长度不符时返回带错误信息的对象。
	static func from_bytes(data: PackedByteArray) -> EnemyPositions:
		var result := EnemyPositions.new()
		if data.size() != BYTE_SIZE:
			result.error_message = "敌人站位应为 %d 字节，实际为 %d" % [BYTE_SIZE, data.size()]
			return result
		for offset in range(0, data.size(), 4):
			result.positions.append(Vector2i(PalBinary.u16_le(data, offset), PalBinary.u16_le(data, offset + 2)))
		return result

	## 返回指定敌人在给定队伍人数下的脚底坐标；参数越界时返回零向量。
	func position_for(enemy_index: int, enemy_count: int) -> Vector2i:
		if enemy_index < 0 or enemy_index >= PalEnemyTeam.MAX_ENEMIES or enemy_count <= 0 or enemy_count > PalEnemyTeam.MAX_ENEMIES:
			return Vector2i.ZERO
		var index := enemy_index * PalEnemyTeam.MAX_ENEMIES + enemy_count - 1
		return positions[index] if index >= 0 and index < positions.size() else Vector2i.ZERO

	## 返回矩阵是否完整可用。
	func is_valid() -> bool:
		return error_message.is_empty() and positions.size() == PalEnemyTeam.MAX_ENEMIES * PalEnemyTeam.MAX_ENEMIES
