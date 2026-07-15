# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 小端二进制的边界检查和整数读写辅助函数。
## 所有读取在越界时返回 -1，解析器应据此生成更具体的错误信息。
class_name PalBinary
extends RefCounted


## 判断从 `offset` 起是否还可安全读取 `length` 字节。
static func can_read(data: PackedByteArray, offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset <= data.size() - length


## 读取无符号 16 位小端整数，越界时返回 -1。
static func u16_le(data: PackedByteArray, offset: int) -> int:
	if not can_read(data, offset, 2):
		return -1
	return data[offset] | (data[offset + 1] << 8)


## 读取有符号 16 位小端整数，越界时返回 -1。
static func i16_le(data: PackedByteArray, offset: int) -> int:
	var value := u16_le(data, offset)
	if value < 0:
		return value
	return value - 0x10000 if value >= 0x8000 else value


## 读取无符号 32 位小端整数，越界时返回 -1。
static func u32_le(data: PackedByteArray, offset: int) -> int:
	if not can_read(data, offset, 4):
		return -1
	return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)


## 把数值的低 16 位以小端顺序追加到目标数组。
static func append_u16_le(target: PackedByteArray, value: int) -> void:
	target.append(value & 0xff)
	target.append((value >> 8) & 0xff)


## 把数值的低 32 位以小端顺序追加到目标数组。
static func append_u32_le(target: PackedByteArray, value: int) -> void:
	target.append(value & 0xff)
	target.append((value >> 8) & 0xff)
	target.append((value >> 16) & 0xff)
	target.append((value >> 24) & 0xff)
