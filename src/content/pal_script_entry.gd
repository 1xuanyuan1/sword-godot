# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h SCRIPTENTRY.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal 脚本表的一条 8 字节指令，由操作码和三个 16 位操作数组成。
## 指令含义由 `ScriptVM` 解释，本类型只负责无状态解析。
class_name PalScriptEntry
extends RefCounted

const BYTE_SIZE := 8

## 16 位 SDLPal 操作码。
var operation: int
## 三个保持原始无符号值的操作数。
var operands: PackedInt32Array = PackedInt32Array()


## 从指定偏移解析一条脚本指令；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int) -> PalScriptEntry:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var entry := PalScriptEntry.new()
	entry.operation = PalBinary.u16_le(data, offset)
	entry.operands = PackedInt32Array([
		PalBinary.u16_le(data, offset + 2),
		PalBinary.u16_le(data, offset + 4),
		PalBinary.u16_le(data, offset + 6),
	])
	return entry
