# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h EVENTOBJECT.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalEventObject
extends RefCounted

const BYTE_SIZE := 32
const TRIGGER_SEARCH_NEAR := 1
const TRIGGER_TOUCH_NEAR := 4
const TRIGGER_TOUCH_FARTHEST := 8

var object_id: int = 0
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


func is_search_trigger() -> bool:
	return trigger_mode >= TRIGGER_SEARCH_NEAR and trigger_mode < TRIGGER_TOUCH_NEAR


func is_touch_trigger() -> bool:
	return trigger_mode >= TRIGGER_TOUCH_NEAR and trigger_mode <= TRIGGER_TOUCH_FARTHEST


func touch_trigger_distance() -> int:
	return (trigger_mode - TRIGGER_TOUCH_NEAR) * 32 + 16 if is_touch_trigger() else 0
