# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h LEVELUPMAGIC_ALL and LEVELUPEXP.
# SPDX-License-Identifier: GPL-3.0-or-later
## 解析 DATA.MKF #6/#14 中的升级经验阈值和按角色学习仙术表。
## 本对象只保存只读成长规则；角色当前经验、等级和已学仙术由 `GameSession` 持有。
class_name PalLevelProgression
extends RefCounted

const ROLE_COUNT := PalPlayerRoles.ROLE_COUNT
const PLAYABLE_ROLE_COUNT := 5
const MAX_LEVEL := 99
const MAGIC_RECORD_SIZE := PLAYABLE_ROLE_COUNT * 4
const EXPERIENCE_ENTRY_SIZE := 2

## 一条“角色达到指定等级后习得仙术”的静态规则。
class MagicLearning extends RefCounted:
	## 从 0 开始的 PLAYERROLES 角色编号。
	var role_index: int = 0
	## 允许习得仙术的最低等级。
	var required_level: int = 0
	## OBJECT 表中的仙术对象编号。
	var magic_object_id: int = 0


## 索引为当前等级、值为升到下一级所需的主经验。
var experience_thresholds: PackedInt32Array = PackedInt32Array()
## 每名角色的升级习得规则，按 DATA.MKF 原始顺序保存。
var magic_learning_by_role: Array[Array] = []
## 解析失败原因；为空表示结构有效。
var error_message: String = ""


## 从完整 DATA.MKF #6 和 #14 分块建立成长规则。
## 结构长度错误时返回带 `error_message` 的对象，不会截断损坏记录。
static func from_bytes(magic_bytes: PackedByteArray, experience_bytes: PackedByteArray) -> PalLevelProgression:
	var progression := PalLevelProgression.new()
	for _role_index in range(ROLE_COUNT):
		progression.magic_learning_by_role.append([])
	if magic_bytes.size() % MAGIC_RECORD_SIZE != 0:
		progression.error_message = "升级仙术表长度必须是 %d 的倍数，实际为 %d" % [MAGIC_RECORD_SIZE, magic_bytes.size()]
		return progression
	if experience_bytes.size() < (MAX_LEVEL + 1) * EXPERIENCE_ENTRY_SIZE or experience_bytes.size() % EXPERIENCE_ENTRY_SIZE != 0:
		progression.error_message = "升级经验表至少需要 %d 字节且必须按 WORD 对齐，实际为 %d" % [(MAX_LEVEL + 1) * EXPERIENCE_ENTRY_SIZE, experience_bytes.size()]
		return progression
	for level in range(MAX_LEVEL + 1):
		progression.experience_thresholds.append(PalBinary.u16_le(experience_bytes, level * EXPERIENCE_ENTRY_SIZE))
	for record_index in range(int(magic_bytes.size() / MAGIC_RECORD_SIZE)):
		var record_offset := record_index * MAGIC_RECORD_SIZE
		for role_index in range(PLAYABLE_ROLE_COUNT):
			var offset := record_offset + role_index * 4
			var required_level := PalBinary.u16_le(magic_bytes, offset)
			var magic_object_id := PalBinary.u16_le(magic_bytes, offset + 2)
			if required_level <= 0 or magic_object_id <= 0:
				continue
			var learning := MagicLearning.new()
			learning.role_index = role_index
			learning.required_level = required_level
			learning.magic_object_id = magic_object_id
			progression.magic_learning_by_role[role_index].append(learning)
	return progression


## 返回结构是否完整可用。
func is_valid() -> bool:
	return error_message.is_empty() and experience_thresholds.size() == MAX_LEVEL + 1 and magic_learning_by_role.size() == ROLE_COUNT


## 返回当前等级升到下一级所需经验；等级越界或数据无效时返回 0。
func experience_for_level(level: int) -> int:
	return experience_thresholds[level] if level >= 0 and level < experience_thresholds.size() else 0


## 返回指定角色达到 `level` 后应拥有的仙术对象编号。
## 无效角色返回空数组；调用方仍需通过 `GameSession.add_magic()` 去重和限制槽位。
func magic_objects_for_level(role_index: int, level: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if role_index < 0 or role_index >= magic_learning_by_role.size():
		return result
	for learning: MagicLearning in magic_learning_by_role[role_index]:
		if learning.required_level <= level:
			result.append(learning.magic_object_id)
	return result
