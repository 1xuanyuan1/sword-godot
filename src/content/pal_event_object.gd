# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h EVENTOBJECT.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalEventObject
extends RefCounted

const BYTE_SIZE := 32

var vanish_time: int
var position: Vector2i
var layer: int
var trigger_script: int
var auto_script: int
var state: int
var trigger_mode: int
var sprite_number: int
var sprite_frames: int
var direction: int
var current_frame: int
var script_idle_frame: int
var sprite_pointer_offset: int
var sprite_frames_auto: int
var auto_script_idle_count: int


static func from_bytes(data: PackedByteArray, offset: int) -> PalEventObject:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var event := PalEventObject.new()
	event.vanish_time = PalBinary.i16_le(data, offset)
	event.position = Vector2i(PalBinary.u16_le(data, offset + 2), PalBinary.u16_le(data, offset + 4))
	event.layer = PalBinary.i16_le(data, offset + 6)
	event.trigger_script = PalBinary.u16_le(data, offset + 8)
	event.auto_script = PalBinary.u16_le(data, offset + 10)
	event.state = PalBinary.i16_le(data, offset + 12)
	event.trigger_mode = PalBinary.u16_le(data, offset + 14)
	event.sprite_number = PalBinary.u16_le(data, offset + 16)
	event.sprite_frames = PalBinary.u16_le(data, offset + 18)
	event.direction = PalBinary.u16_le(data, offset + 20)
	event.current_frame = PalBinary.u16_le(data, offset + 22)
	event.script_idle_frame = PalBinary.u16_le(data, offset + 24)
	event.sprite_pointer_offset = PalBinary.u16_le(data, offset + 26)
	event.sprite_frames_auto = PalBinary.u16_le(data, offset + 28)
	event.auto_script_idle_count = PalBinary.u16_le(data, offset + 30)
	return event


func is_visible() -> bool:
	return state > 0 and vanish_time == 0


func blocks_movement() -> bool:
	return state >= 2

