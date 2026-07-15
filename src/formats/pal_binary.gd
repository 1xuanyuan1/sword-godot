# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalBinary
extends RefCounted


static func can_read(data: PackedByteArray, offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= data.size() - length


static func u16_le(data: PackedByteArray, offset: int) -> int:
	if not can_read(data, offset, 2):
		return -1
	return data[offset] | (data[offset + 1] << 8)


static func i16_le(data: PackedByteArray, offset: int) -> int:
	var value := u16_le(data, offset)
	if value < 0:
		return value
	return value - 0x10000 if value >= 0x8000 else value


static func u32_le(data: PackedByteArray, offset: int) -> int:
	if not can_read(data, offset, 4):
		return -1
	return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)


static func append_u16_le(target: PackedByteArray, value: int) -> void:
	target.append(value & 0xff)
	target.append((value >> 8) & 0xff)


static func append_u32_le(target: PackedByteArray, value: int) -> void:
	target.append(value & 0xff)
	target.append((value >> 8) & 0xff)
	target.append((value >> 16) & 0xff)
	target.append((value >> 24) & 0xff)

