# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h ENEMY.
# SPDX-License-Identifier: GPL-3.0-or-later
## `DATA.MKF #1` 的 70 字节敌人属性记录，保存经典战斗所需的动画、数值和奖励。
## 对象编号到本记录的映射由 `PalEnemyObjectDefinition` 提供。
class_name PalEnemyDefinition
extends RefCounted

const BYTE_SIZE := 70
const ELEMENT_COUNT := 5

## 属性表中的索引，同时对应 `ABC.MKF` Sprite 分块。
var enemy_id: int = 0
## 待机动画帧数。
var idle_frames: int = 0
## 施法动画帧数。
var magic_frames: int = 0
## 普攻动画帧数。
var attack_frames: int = 0
## 待机动画速度。
var idle_animation_speed: int = 0
## 行动结束等待帧数。
var action_wait_frames: int = 0
## 相对敌人站位的纵向像素偏移。
var y_position_offset: int = 0
## 普攻、行动、施法、死亡和入场音效编号；负值表示无音效。
var sounds: PackedInt32Array = PackedInt32Array()
## 最大体力。
var health: int = 0
## 胜利后获得经验。
var experience: int = 0
## 胜利后获得金钱。
var cash: int = 0
## 敌人等级。
var level: int = 0
## 敌人可能使用的仙术对象编号。
var magic: int = 0
## 使用仙术的概率参数。
var magic_rate: int = 0
## 普攻附带物品效果的对象编号。
var attack_equivalent_item: int = 0
## 普攻附带物品效果的概率参数。
var attack_equivalent_item_rate: int = 0
## 可偷物品对象编号。
var steal_item: int = 0
## 可偷物品数量。
var steal_item_count: int = 0
## 基础攻击力。
var attack_strength: int = 0
## 基础灵力。
var magic_strength: int = 0
## 基础防御。
var defense: int = 0
## 基础身法。
var dexterity: int = 0
## 基础逃跑值。
var flee_rate: int = 0
## 基础毒抗。
var poison_resistance: int = 0
## 五灵抗性。
var elemental_resistances: PackedInt32Array = PackedInt32Array()
## 物理抗性。
var physical_resistance: int = 0
## 非零时敌人每回合可行动两次。
var dual_move: int = 0
## 炼蛊收集值。
var collect_value: int = 0


## 从指定 70 字节记录解析敌人；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalEnemyDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var enemy := PalEnemyDefinition.new()
	enemy.enemy_id = id
	enemy.idle_frames = _word(data, offset, 0)
	enemy.magic_frames = _word(data, offset, 1)
	enemy.attack_frames = _word(data, offset, 2)
	enemy.idle_animation_speed = _word(data, offset, 3)
	enemy.action_wait_frames = _word(data, offset, 4)
	enemy.y_position_offset = _word(data, offset, 5)
	for word_index in range(6, 11):
		enemy.sounds.append(PalBinary.i16_le(data, offset + word_index * 2))
	enemy.health = _word(data, offset, 11)
	enemy.experience = _word(data, offset, 12)
	enemy.cash = _word(data, offset, 13)
	enemy.level = _word(data, offset, 14)
	enemy.magic = _word(data, offset, 15)
	enemy.magic_rate = _word(data, offset, 16)
	enemy.attack_equivalent_item = _word(data, offset, 17)
	enemy.attack_equivalent_item_rate = _word(data, offset, 18)
	enemy.steal_item = _word(data, offset, 19)
	enemy.steal_item_count = _word(data, offset, 20)
	enemy.attack_strength = _word(data, offset, 21)
	enemy.magic_strength = _word(data, offset, 22)
	enemy.defense = _word(data, offset, 23)
	enemy.dexterity = _word(data, offset, 24)
	enemy.flee_rate = _word(data, offset, 25)
	enemy.poison_resistance = _word(data, offset, 26)
	for word_index in range(27, 27 + ELEMENT_COUNT):
		enemy.elemental_resistances.append(_word(data, offset, word_index))
	enemy.physical_resistance = _word(data, offset, 32)
	enemy.dual_move = _word(data, offset, 33)
	enemy.collect_value = _word(data, offset, 34)
	return enemy


static func _word(data: PackedByteArray, offset: int, word_index: int) -> int:
	return PalBinary.u16_le(data, offset + word_index * 2)
