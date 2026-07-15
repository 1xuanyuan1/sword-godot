# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameSession
extends RefCounted

const PARTY_OFFSET := Vector2i(160, 112)

var scene_index: int = 0
var viewport_position: Vector2i = Vector2i.ZERO
var party_direction: int = 0
var cash: int = 0
var palette_index: int = 0
var night_palette: bool = false
var music_number: int = 0
var battle_music_number: int = 0
var party_roles: PackedInt32Array = PackedInt32Array([0])


func party_world_position() -> Vector2i:
	return viewport_position + PARTY_OFFSET


func reset_new_game() -> void:
	scene_index = 0
	viewport_position = Vector2i.ZERO
	party_direction = 0
	cash = 0
	palette_index = 0
	night_palette = false
	music_number = 0
	battle_music_number = 0
	party_roles = PackedInt32Array([0])
