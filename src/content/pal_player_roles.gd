# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h PLAYERROLES.
# SPDX-License-Identifier: GPL-3.0-or-later
## 从 `DATA.MKF #3` PLAYERROLES 结构读取探索与经典战斗所需的角色字段。
## 装备加成和战斗中的临时状态不写回本静态内容对象。
class_name PalPlayerRoles
extends RefCounted

const ROLE_COUNT := 6
const BYTE_SIZE := 900
const AVATAR_WORD_OFFSET := 0
const BATTLE_SPRITE_WORD_OFFSET := 6
const SCENE_SPRITE_WORD_OFFSET := 12
const NAME_WORD_OFFSET := 18
const ATTACK_ALL_WORD_OFFSET := 24
const LEVEL_WORD_OFFSET := 36
const MAX_HP_WORD_OFFSET := 42
const MAX_MP_WORD_OFFSET := 48
const HP_WORD_OFFSET := 54
const MP_WORD_OFFSET := 60
const ATTACK_STRENGTH_WORD_OFFSET := 102
const MAGIC_STRENGTH_WORD_OFFSET := 108
const DEFENSE_WORD_OFFSET := 114
const DEXTERITY_WORD_OFFSET := 120
const FLEE_RATE_WORD_OFFSET := 126
const POISON_RESISTANCE_WORD_OFFSET := 132
const ELEMENT_RESISTANCE_WORD_OFFSET := 138
const ELEMENT_COUNT := 5
const MAGIC_WORD_OFFSET := 192
const MAGIC_SLOT_COUNT := 32
const WALK_FRAMES_WORD_OFFSET := 384

## 每名角色在 `RGM.MKF` 中的默认肖像编号。
var avatar_numbers: PackedInt32Array = PackedInt32Array()
## 每名角色在 `F.MKF` 中的基础战斗 Sprite 编号。
var battle_sprite_numbers: PackedInt32Array = PackedInt32Array()
## 每名角色在 `MGO.MKF` 中的普通场景 Sprite 编号。
var scene_sprite_numbers: PackedInt32Array = PackedInt32Array()
## 每名角色在 `WORD.DAT` 中的名字索引。
var name_word_indices: PackedInt32Array = PackedInt32Array()
## 每个方向的行走帧数；原版零值按三帧处理。
var walk_frames: PackedInt32Array = PackedInt32Array()
## 每名角色的新游戏初始等级。
var levels: PackedInt32Array = PackedInt32Array()
## 每名角色的最大体力。
var max_hp: PackedInt32Array = PackedInt32Array()
## 每名角色的最大真气。
var max_mp: PackedInt32Array = PackedInt32Array()
## 每名角色的新游戏当前体力。
var hp: PackedInt32Array = PackedInt32Array()
## 每名角色的新游戏当前真气。
var mp: PackedInt32Array = PackedInt32Array()
## 每名角色是否用普通攻击命中全体敌人。
var attack_all: PackedInt32Array = PackedInt32Array()
## 每名角色的基础攻击力。
var attack_strengths: PackedInt32Array = PackedInt32Array()
## 每名角色的基础灵力。
var magic_strengths: PackedInt32Array = PackedInt32Array()
## 每名角色的基础防御。
var defenses: PackedInt32Array = PackedInt32Array()
## 每名角色的基础身法。
var dexterities: PackedInt32Array = PackedInt32Array()
## 每名角色的基础逃跑值。
var flee_rates: PackedInt32Array = PackedInt32Array()
## 每名角色的基础毒抗性。
var poison_resistances: PackedInt32Array = PackedInt32Array()
## 每名角色的五灵抗性表。
var elemental_resistances_by_role: Array[PackedInt32Array] = []
## 每名角色初始拥有的非零仙术对象编号。
var magics_by_role: Array[PackedInt32Array] = []
## 解析失败原因；为空且数组长度正确时对象有效。
var error_message: String = ""


## 解析完整 PLAYERROLES 分块；长度不符时返回带错误信息的对象。
static func from_bytes(data: PackedByteArray) -> PalPlayerRoles:
	var roles := PalPlayerRoles.new()
	if data.size() != BYTE_SIZE:
		roles.error_message = "PLAYERROLES 数据应为 %d 字节，实际为 %d" % [BYTE_SIZE, data.size()]
		return roles
	for role_index in range(ROLE_COUNT):
		roles.avatar_numbers.append(PalBinary.u16_le(data, (AVATAR_WORD_OFFSET + role_index) * 2))
		roles.battle_sprite_numbers.append(PalBinary.u16_le(data, (BATTLE_SPRITE_WORD_OFFSET + role_index) * 2))
		roles.scene_sprite_numbers.append(PalBinary.u16_le(data, (SCENE_SPRITE_WORD_OFFSET + role_index) * 2))
		roles.name_word_indices.append(PalBinary.u16_le(data, (NAME_WORD_OFFSET + role_index) * 2))
		roles.attack_all.append(PalBinary.u16_le(data, (ATTACK_ALL_WORD_OFFSET + role_index) * 2))
		roles.levels.append(PalBinary.u16_le(data, (LEVEL_WORD_OFFSET + role_index) * 2))
		roles.max_hp.append(PalBinary.u16_le(data, (MAX_HP_WORD_OFFSET + role_index) * 2))
		roles.max_mp.append(PalBinary.u16_le(data, (MAX_MP_WORD_OFFSET + role_index) * 2))
		roles.hp.append(PalBinary.u16_le(data, (HP_WORD_OFFSET + role_index) * 2))
		roles.mp.append(PalBinary.u16_le(data, (MP_WORD_OFFSET + role_index) * 2))
		roles.attack_strengths.append(PalBinary.u16_le(data, (ATTACK_STRENGTH_WORD_OFFSET + role_index) * 2))
		roles.magic_strengths.append(PalBinary.u16_le(data, (MAGIC_STRENGTH_WORD_OFFSET + role_index) * 2))
		roles.defenses.append(PalBinary.u16_le(data, (DEFENSE_WORD_OFFSET + role_index) * 2))
		roles.dexterities.append(PalBinary.u16_le(data, (DEXTERITY_WORD_OFFSET + role_index) * 2))
		roles.flee_rates.append(PalBinary.u16_le(data, (FLEE_RATE_WORD_OFFSET + role_index) * 2))
		roles.poison_resistances.append(PalBinary.u16_le(data, (POISON_RESISTANCE_WORD_OFFSET + role_index) * 2))
		var elemental_resistances := PackedInt32Array()
		for element_index in range(ELEMENT_COUNT):
			elemental_resistances.append(PalBinary.u16_le(data, (ELEMENT_RESISTANCE_WORD_OFFSET + element_index * ROLE_COUNT + role_index) * 2))
		roles.elemental_resistances_by_role.append(elemental_resistances)
		roles.walk_frames.append(PalBinary.u16_le(data, (WALK_FRAMES_WORD_OFFSET + role_index) * 2))
		var role_magics := PackedInt32Array()
		for slot in range(MAGIC_SLOT_COUNT):
			var magic := PalBinary.u16_le(data, (MAGIC_WORD_OFFSET + slot * ROLE_COUNT + role_index) * 2)
			if magic > 0:
				role_magics.append(magic)
		roles.magics_by_role.append(role_magics)
	return roles


## 返回结构是否通过长度和字段校验。
func is_valid() -> bool:
	return error_message.is_empty() and avatar_numbers.size() == ROLE_COUNT and battle_sprite_numbers.size() == ROLE_COUNT and scene_sprite_numbers.size() == ROLE_COUNT and name_word_indices.size() == ROLE_COUNT and attack_all.size() == ROLE_COUNT and levels.size() == ROLE_COUNT and max_hp.size() == ROLE_COUNT and max_mp.size() == ROLE_COUNT and hp.size() == ROLE_COUNT and mp.size() == ROLE_COUNT and attack_strengths.size() == ROLE_COUNT and magic_strengths.size() == ROLE_COUNT and defenses.size() == ROLE_COUNT and dexterities.size() == ROLE_COUNT and flee_rates.size() == ROLE_COUNT and poison_resistances.size() == ROLE_COUNT and elemental_resistances_by_role.size() == ROLE_COUNT and magics_by_role.size() == ROLE_COUNT and walk_frames.size() == ROLE_COUNT


## 返回角色的默认 RGM 肖像编号，越界时返回 0。
func avatar_for(role_index: int) -> int:
	return avatar_numbers[role_index] if role_index >= 0 and role_index < avatar_numbers.size() else 0


## 返回角色的基础 F.MKF 战斗 Sprite 编号，越界时返回 0。
func battle_sprite_for(role_index: int) -> int:
	return battle_sprite_numbers[role_index] if role_index >= 0 and role_index < battle_sprite_numbers.size() else 0


## 返回角色的 MGO 场景 Sprite 编号，越界时返回 0。
func scene_sprite_for(role_index: int) -> int:
	return scene_sprite_numbers[role_index] if role_index >= 0 and role_index < scene_sprite_numbers.size() else 0


## 返回角色名字的 WORD 索引，越界时返回 0。
func name_word_for(role_index: int) -> int:
	return name_word_indices[role_index] if role_index >= 0 and role_index < name_word_indices.size() else 0


## 返回角色的新游戏初始等级，越界时返回 0。
func level_for(role_index: int) -> int:
	return levels[role_index] if role_index >= 0 and role_index < levels.size() else 0


## 返回角色最大体力，越界时返回 0。
func max_hp_for(role_index: int) -> int:
	return max_hp[role_index] if role_index >= 0 and role_index < max_hp.size() else 0


## 返回角色最大真气，越界时返回 0。
func max_mp_for(role_index: int) -> int:
	return max_mp[role_index] if role_index >= 0 and role_index < max_mp.size() else 0


## 返回角色新游戏当前体力，越界时返回 0。
func hp_for(role_index: int) -> int:
	return hp[role_index] if role_index >= 0 and role_index < hp.size() else 0


## 返回角色新游戏当前真气，越界时返回 0。
func mp_for(role_index: int) -> int:
	return mp[role_index] if role_index >= 0 and role_index < mp.size() else 0


## 返回角色基础攻击力，越界时返回 0。
func attack_strength_for(role_index: int) -> int:
	return attack_strengths[role_index] if role_index >= 0 and role_index < attack_strengths.size() else 0


## 返回角色基础灵力，越界时返回 0。
func magic_strength_for(role_index: int) -> int:
	return magic_strengths[role_index] if role_index >= 0 and role_index < magic_strengths.size() else 0


## 返回角色基础防御，越界时返回 0。
func defense_for(role_index: int) -> int:
	return defenses[role_index] if role_index >= 0 and role_index < defenses.size() else 0


## 返回角色基础身法，越界时返回 0。
func dexterity_for(role_index: int) -> int:
	return dexterities[role_index] if role_index >= 0 and role_index < dexterities.size() else 0


## 返回角色基础逃跑值，越界时返回 0。
func flee_rate_for(role_index: int) -> int:
	return flee_rates[role_index] if role_index >= 0 and role_index < flee_rates.size() else 0


## 返回角色初始仙术列表的副本，调用方修改它不会污染内容定义。
func magics_for(role_index: int) -> PackedInt32Array:
	return magics_by_role[role_index].duplicate() if role_index >= 0 and role_index < magics_by_role.size() else PackedInt32Array()


## 返回每方向步态帧数；缺失或为零时沿用 SDLPal 的三帧默认值。
func walk_frame_count_for(role_index: int) -> int:
	if role_index < 0 or role_index >= walk_frames.size() or walk_frames[role_index] == 0:
		return 3
	return walk_frames[role_index]
