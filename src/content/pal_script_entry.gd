# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h SCRIPTENTRY.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalScriptEntry
extends RefCounted

const BYTE_SIZE := 8

var operation: int
var operands: PackedInt32Array = PackedInt32Array()


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

