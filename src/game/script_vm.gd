# Copyright (C) 2026 sword-godot contributors
# Adapted conceptually from SDLPal script.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ScriptVM
extends Node

signal instruction_started(index: int, operation: int, operands: PackedInt32Array)
signal unsupported_instruction(index: int, operation: int)
signal script_finished(next_entry: int)
signal redraw_requested(delay_units: int)
signal dialog_started(position: int, color: int, portrait: int)
signal dialog_message(message_index: int)
signal music_requested(music_number: int)
signal sound_requested(sound_number: int)

const MAX_INSTRUCTIONS_PER_RUN := 10000

var database: PalContentDatabase
var session: GameSession
var running: bool = false


func configure(content_database: PalContentDatabase, game_session: GameSession = null) -> void:
	database = content_database
	session = game_session


func run_trigger(entry_index: int, _event_object_id: int = 0) -> int:
	if database == null or entry_index <= 0 or entry_index >= database.scripts.size():
		return entry_index
	running = true
	var cursor := entry_index
	var executed := 0
	while running and cursor > 0 and cursor < database.scripts.size() and executed < MAX_INSTRUCTIONS_PER_RUN:
		var entry := database.scripts[cursor]
		instruction_started.emit(cursor, entry.operation, entry.operands)
		match entry.operation:
			0x0000:
				break
			0x0001:
				cursor += 1
				break
			0x0002:
				cursor = entry.operands[0]
				break
			0x0003:
				cursor = entry.operands[0]
				continue
			0x0004:
				run_trigger(entry.operands[0], _event_object_id if entry.operands[1] == 0 else entry.operands[1])
			0x0005:
				redraw_requested.emit(entry.operands[1])
			0x0015:
				if session != null:
					session.party_direction = entry.operands[0]
			0x003C:
				dialog_started.emit(0, entry.operands[1], entry.operands[0]) # Upper
			0x003D:
				dialog_started.emit(1, entry.operands[1], entry.operands[0]) # Lower
			0x003E:
				dialog_started.emit(2, entry.operands[0], 0) # Center
			0x0043:
				if session != null:
					session.music_number = entry.operands[0]
				music_requested.emit(entry.operands[0])
			0x0045:
				if session != null:
					session.battle_music_number = entry.operands[0]
			0x0046:
				if session != null:
					var world_x := entry.operands[0] * 32 + entry.operands[2] * 16
					var world_y := entry.operands[1] * 16 + entry.operands[2] * 8
					session.set_party_world_position(Vector2i(world_x, world_y))
			0x0047:
				sound_requested.emit(entry.operands[0])
			0x0065:
				pass # Player sprite selection is stored once PlayerRoles is imported.
			0x0075:
				if session != null:
					session.party_roles = PackedInt32Array()
					for role in entry.operands:
						if role > 0:
							session.party_roles.append(role - 1)
			0xFFFF:
				dialog_message.emit(entry.operands[0])
			_:
				unsupported_instruction.emit(cursor, entry.operation)
				break
		cursor += 1
		executed += 1
	running = false
	script_finished.emit(cursor)
	return cursor


func stop() -> void:
	running = false
