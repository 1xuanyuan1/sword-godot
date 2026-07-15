# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h PLAYERROLES.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalPlayerRoles
extends RefCounted

const ROLE_COUNT := 6
const BYTE_SIZE := 900
const SCENE_SPRITE_WORD_OFFSET := 12
const WALK_FRAMES_WORD_OFFSET := 384

var scene_sprite_numbers: PackedInt32Array = PackedInt32Array()
var walk_frames: PackedInt32Array = PackedInt32Array()
var error_message: String = ""


static func from_bytes(data: PackedByteArray) -> PalPlayerRoles:
	var roles := PalPlayerRoles.new()
	if data.size() != BYTE_SIZE:
		roles.error_message = "PLAYERROLES 数据应为 %d 字节，实际为 %d" % [BYTE_SIZE, data.size()]
		return roles
	for role_index in range(ROLE_COUNT):
		roles.scene_sprite_numbers.append(PalBinary.u16_le(data, (SCENE_SPRITE_WORD_OFFSET + role_index) * 2))
		roles.walk_frames.append(PalBinary.u16_le(data, (WALK_FRAMES_WORD_OFFSET + role_index) * 2))
	return roles


func is_valid() -> bool:
	return error_message.is_empty() and scene_sprite_numbers.size() == ROLE_COUNT and walk_frames.size() == ROLE_COUNT


func scene_sprite_for(role_index: int) -> int:
	return scene_sprite_numbers[role_index] if role_index >= 0 and role_index < scene_sprite_numbers.size() else 0


func walk_frame_count_for(role_index: int) -> int:
	if role_index < 0 or role_index >= walk_frames.size() or walk_frames[role_index] == 0:
		return 3
	return walk_frames[role_index]
