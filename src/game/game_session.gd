# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameSession
extends RefCounted

const PARTY_OFFSET := Vector2i(160, 112)
const TRAIL_SIZE := 5
const DIR_SOUTH := 0
const DIR_WEST := 1
const DIR_NORTH := 2
const DIR_EAST := 3

var scene_index: int = 0
var viewport_position: Vector2i = Vector2i.ZERO
var party_direction: int = 0
var cash: int = 0
var palette_index: int = 0
var night_palette: bool = false
var music_number: int = 0
var battle_music_number: int = 0
var world_layer: int = 0
var party_roles: PackedInt32Array = PackedInt32Array([0])
var party_script_frames: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var trail_positions: Array[Vector2i] = []
var trail_directions: PackedInt32Array = PackedInt32Array()


func party_world_position() -> Vector2i:
	return viewport_position + PARTY_OFFSET


static func movement_for_direction(direction: int) -> Vector2i:
	match direction:
		DIR_SOUTH:
			return Vector2i(-16, 8)
		DIR_WEST:
			return Vector2i(-16, -8)
		DIR_NORTH:
			return Vector2i(16, -8)
		DIR_EAST:
			return Vector2i(16, 8)
	return Vector2i.ZERO


func set_party_world_position(world_position: Vector2i) -> void:
	viewport_position = world_position - PARTY_OFFSET
	_initialize_trail(world_position)


func record_party_step(direction: int, movement: Vector2i) -> void:
	clear_party_gestures()
	if trail_positions.size() != TRAIL_SIZE or trail_directions.size() != TRAIL_SIZE:
		_initialize_trail(party_world_position())
	for index in range(TRAIL_SIZE - 1, 0, -1):
		trail_positions[index] = trail_positions[index - 1]
		trail_directions[index] = trail_directions[index - 1]
	trail_positions[0] = party_world_position()
	trail_directions[0] = direction
	party_direction = direction
	viewport_position += movement


func party_member_world_position(member_index: int) -> Vector2i:
	if member_index <= 0 or trail_positions.size() < 2:
		return party_world_position()
	var base := trail_positions[1]
	var direction := trail_directions[1]
	if member_index == 2:
		base.x += -16 if direction in [DIR_WEST, DIR_EAST] else 16
		base.y += 8
	else:
		base.x += 16 if direction in [DIR_SOUTH, DIR_WEST] else -16
		base.y += 8 if direction in [DIR_WEST, DIR_NORTH] else -8
	return base


func party_member_direction(member_index: int) -> int:
	if member_index <= 0 or trail_directions.size() < 3:
		return party_direction
	return trail_directions[2]


func set_party_gesture(direction: int, gesture: int, member_index: int) -> void:
	if member_index < 0:
		return
	while party_script_frames.size() <= member_index:
		party_script_frames.append(-1)
	party_direction = direction
	party_script_frames[member_index] = direction * 3 + gesture


func scripted_party_frame(member_index: int) -> int:
	return party_script_frames[member_index] if member_index >= 0 and member_index < party_script_frames.size() else -1


func clear_party_gestures() -> void:
	party_script_frames.resize(maxi(3, party_roles.size()))
	party_script_frames.fill(-1)


func reset_new_game() -> void:
	scene_index = 0
	viewport_position = Vector2i.ZERO
	party_direction = 0
	cash = 0
	palette_index = 0
	night_palette = false
	music_number = 0
	battle_music_number = 0
	world_layer = 0
	party_roles = PackedInt32Array([0])
	clear_party_gestures()
	_initialize_trail(party_world_position())


func _initialize_trail(world_position: Vector2i) -> void:
	trail_positions.resize(TRAIL_SIZE)
	trail_directions.resize(TRAIL_SIZE)
	var backward := Vector2i(
		16 if party_direction in [DIR_SOUTH, DIR_WEST] else -16,
		8 if party_direction in [DIR_WEST, DIR_NORTH] else -8
	)
	for index in range(TRAIL_SIZE):
		trail_positions[index] = world_position + backward * index
		trail_directions[index] = party_direction
