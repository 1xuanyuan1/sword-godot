# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h SCENE.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalSceneDefinition
extends RefCounted

const BYTE_SIZE := 8

var map_number: int
var script_on_enter: int
var script_on_teleport: int
var event_object_index: int


static func from_bytes(data: PackedByteArray, offset: int) -> PalSceneDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var scene := PalSceneDefinition.new()
	scene.map_number = PalBinary.u16_le(data, offset)
	scene.script_on_enter = PalBinary.u16_le(data, offset + 2)
	scene.script_on_teleport = PalBinary.u16_le(data, offset + 4)
	scene.event_object_index = PalBinary.u16_le(data, offset + 6)
	return scene

