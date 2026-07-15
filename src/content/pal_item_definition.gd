# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h OBJECT_ITEM_DOS.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalItemDefinition
extends RefCounted

const BYTE_SIZE := 12
const FLAG_USABLE := 1 << 0
const FLAG_EQUIPABLE := 1 << 1
const FLAG_THROWABLE := 1 << 2
const FLAG_CONSUMING := 1 << 3
const FLAG_APPLY_TO_ALL := 1 << 4
const FLAG_SELLABLE := 1 << 5

var object_id: int = 0
var bitmap: int = 0
var price: int = 0
var script_on_use: int = 0
var script_on_equip: int = 0
var script_on_throw: int = 0
var flags: int = 0


static func from_bytes(data: PackedByteArray, offset: int, id: int) -> PalItemDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var item := PalItemDefinition.new()
	item.object_id = id
	item.bitmap = PalBinary.u16_le(data, offset)
	item.price = PalBinary.u16_le(data, offset + 2)
	item.script_on_use = PalBinary.u16_le(data, offset + 4)
	item.script_on_equip = PalBinary.u16_le(data, offset + 6)
	item.script_on_throw = PalBinary.u16_le(data, offset + 8)
	item.flags = PalBinary.u16_le(data, offset + 10)
	return item


func is_usable() -> bool:
	return (flags & FLAG_USABLE) != 0 and script_on_use > 0


func is_consuming() -> bool:
	return (flags & FLAG_CONSUMING) != 0


func applies_to_all() -> bool:
	return (flags & FLAG_APPLY_TO_ALL) != 0
