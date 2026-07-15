# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h PLAYERROLES.
# SPDX-License-Identifier: GPL-3.0-or-later
## 从 `DATA.MKF` PLAYERROLES 结构读取场景渲染所需的角色字段。
## 这里只保留肖像、场景 Sprite、名字和步态；战斗数值由后续系统扩展。
class_name PalPlayerRoles
extends RefCounted

const ROLE_COUNT := 6
const BYTE_SIZE := 900
const AVATAR_WORD_OFFSET := 0
const SCENE_SPRITE_WORD_OFFSET := 12
const NAME_WORD_OFFSET := 18
const WALK_FRAMES_WORD_OFFSET := 384

## 每名角色在 `RGM.MKF` 中的默认肖像编号。
var avatar_numbers: PackedInt32Array = PackedInt32Array()
## 每名角色在 `MGO.MKF` 中的普通场景 Sprite 编号。
var scene_sprite_numbers: PackedInt32Array = PackedInt32Array()
## 每名角色在 `WORD.DAT` 中的名字索引。
var name_word_indices: PackedInt32Array = PackedInt32Array()
## 每个方向的行走帧数；原版零值按三帧处理。
var walk_frames: PackedInt32Array = PackedInt32Array()
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
		roles.scene_sprite_numbers.append(PalBinary.u16_le(data, (SCENE_SPRITE_WORD_OFFSET + role_index) * 2))
		roles.name_word_indices.append(PalBinary.u16_le(data, (NAME_WORD_OFFSET + role_index) * 2))
		roles.walk_frames.append(PalBinary.u16_le(data, (WALK_FRAMES_WORD_OFFSET + role_index) * 2))
	return roles


## 返回结构是否通过长度和字段校验。
func is_valid() -> bool:
	return error_message.is_empty() and avatar_numbers.size() == ROLE_COUNT and scene_sprite_numbers.size() == ROLE_COUNT and name_word_indices.size() == ROLE_COUNT and walk_frames.size() == ROLE_COUNT


## 返回角色的默认 RGM 肖像编号，越界时返回 0。
func avatar_for(role_index: int) -> int:
	return avatar_numbers[role_index] if role_index >= 0 and role_index < avatar_numbers.size() else 0


## 返回角色的 MGO 场景 Sprite 编号，越界时返回 0。
func scene_sprite_for(role_index: int) -> int:
	return scene_sprite_numbers[role_index] if role_index >= 0 and role_index < scene_sprite_numbers.size() else 0


## 返回角色名字的 WORD 索引，越界时返回 0。
func name_word_for(role_index: int) -> int:
	return name_word_indices[role_index] if role_index >= 0 and role_index < name_word_indices.size() else 0


## 返回每方向步态帧数；缺失或为零时沿用 SDLPal 的三帧默认值。
func walk_frame_count_for(role_index: int) -> int:
	if role_index < 0 or role_index >= walk_frames.size() or walk_frames[role_index] == 0:
		return 3
	return walk_frames[role_index]
