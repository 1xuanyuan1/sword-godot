# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal script.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ScriptVM
extends Node

signal instruction_started(index: int, operation: int, operands: PackedInt32Array)
signal unsupported_instruction(index: int, operation: int)
signal script_finished(next_entry: int)
signal redraw_requested(delay_units: int)
signal dialog_started(position: int, color: int, portrait: int)
signal dialog_message(message_index: int)
signal dialog_page_break
signal dialog_ended
signal music_requested(music_number: int)
signal sound_requested(sound_number: int)
signal scene_change_requested(scene_index: int)
signal player_sprites_changed

const MAX_INSTRUCTIONS_PER_RUN := 10000

var database: PalContentDatabase
var session: GameSession
var running: bool = false
var waiting_for_dialog: bool = false

var _cursor: int = 0
var _event_object_id: int = 0
var _last_event_object_id: int = 0
var _call_stack: Array[Dictionary] = []
var _dialog_has_body: bool = false


func configure(content_database: PalContentDatabase, game_session: GameSession = null) -> void:
	database = content_database
	session = game_session


func run_trigger(entry_index: int, event_object_id: int = 0) -> int:
	if database == null or entry_index <= 0 or entry_index >= database.scripts.size() or running or waiting_for_dialog:
		return entry_index
	if event_object_id == 0xffff:
		event_object_id = _last_event_object_id
	if event_object_id != 0:
		_last_event_object_id = event_object_id
	_call_stack.clear()
	_dialog_has_body = false
	_cursor = entry_index
	_event_object_id = event_object_id
	running = true
	return _continue_execution()


func advance_dialog() -> void:
	if not waiting_for_dialog:
		return
	waiting_for_dialog = false
	_dialog_has_body = false
	running = true
	_continue_execution()


func stop() -> void:
	running = false
	waiting_for_dialog = false
	_dialog_has_body = false
	_call_stack.clear()
	dialog_ended.emit()


func _continue_execution() -> int:
	var executed := 0
	while running and _cursor > 0 and _cursor < database.scripts.size() and executed < MAX_INSTRUCTIONS_PER_RUN:
		var entry := database.scripts[_cursor]
		instruction_started.emit(_cursor, entry.operation, entry.operands)
		var next_cursor := _cursor + 1
		match entry.operation:
			0x0000:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(0)
			0x0001:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(next_cursor)
			0x0002:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(entry.operands[0])
			0x0003:
				_cursor = entry.operands[0]
				continue
			0x0004:
				_call_stack.append({"cursor": next_cursor, "event_object_id": _event_object_id})
				_cursor = entry.operands[0]
				_event_object_id = _event_object_id if entry.operands[1] == 0 else entry.operands[1]
				continue
			0x0005:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_ended.emit()
				redraw_requested.emit(entry.operands[1])
			0x0009:
				redraw_requested.emit(entry.operands[0] if entry.operands[0] > 0 else 1)
			0x000f:
				var event := _event_by_id(_event_object_id)
				if event != null:
					if entry.operands[0] != 0xffff:
						event.direction = entry.operands[0]
					if entry.operands[1] != 0xffff:
						event.current_frame = entry.operands[1]
			0x0012:
				var event := _resolve_event(entry.operands[0])
				if event != null and session != null:
					event.position = session.party_world_position() + Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			0x0013:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position = Vector2i(entry.operands[1], entry.operands[2])
			0x0014:
				var event := _event_by_id(_event_object_id)
				if event != null:
					event.current_frame = entry.operands[0]
					event.direction = GameSession.DIR_SOUTH
			0x0015:
				if session != null:
					session.party_direction = entry.operands[0]
			0x0016:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.direction = entry.operands[1]
					event.current_frame = entry.operands[2]
			0x003b:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_started.emit(2, entry.operands[0], 0)
			0x003c:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_started.emit(0, entry.operands[1], entry.operands[0])
			0x003d:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_started.emit(1, entry.operands[1], entry.operands[0])
			0x003e:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_started.emit(3, entry.operands[0], 0)
			0x0040:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.trigger_mode = entry.operands[1]
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
			0x0049:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.state = _signed_word(entry.operands[1])
			0x0052:
				var event := _event_by_id(_event_object_id)
				if event != null:
					event.state *= -1
					event.vanish_time = entry.operands[0] if entry.operands[0] > 0 else 800
			0x0053:
				if session != null:
					session.night_palette = false
			0x0054:
				if session != null:
					session.night_palette = true
			0x0059:
				if session != null and entry.operands[0] > 0 and entry.operands[0] <= database.scenes.size():
					session.scene_index = entry.operands[0] - 1
					session.world_layer = 0
					scene_change_requested.emit(session.scene_index)
			0x0065:
				if database.player_roles != null and entry.operands[0] < database.player_roles.scene_sprite_numbers.size():
					database.player_roles.scene_sprite_numbers[entry.operands[0]] = entry.operands[1]
					player_sprites_changed.emit()
			0x006c:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
					event.current_frame = (event.current_frame + 1) % maxi(1, event.sprite_frames)
			0x006e:
				if session != null:
					var movement := Vector2i(_signed_word(entry.operands[0]), _signed_word(entry.operands[1]))
					session.record_party_step(session.party_direction, movement)
					session.world_layer = entry.operands[2] * 8
			0x0070:
				if session != null:
					var world_x := entry.operands[0] * 32 + entry.operands[2] * 16
					var world_y := entry.operands[1] * 16 + entry.operands[2] * 8
					session.set_party_world_position(Vector2i(world_x, world_y))
			0x0075:
				if session != null:
					session.party_roles = PackedInt32Array()
					for role in entry.operands:
						if role > 0:
							session.party_roles.append(role - 1)
					if session.party_roles.is_empty():
						session.party_roles.append(0)
					player_sprites_changed.emit()
			0x007d:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			0x007e:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.layer = _signed_word(entry.operands[1])
			0x008e:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_page_break.emit()
				redraw_requested.emit(0)
			0xffff:
				dialog_message.emit(entry.operands[0])
				_cursor = next_cursor
				if not _is_dialog_title(database.get_message(entry.operands[0])):
					_dialog_has_body = true
				executed += 1
				continue
			_:
				unsupported_instruction.emit(_cursor, entry.operation)
				return _finish(_cursor)
		_cursor = next_cursor
		executed += 1

	if executed >= MAX_INSTRUCTIONS_PER_RUN:
		unsupported_instruction.emit(_cursor, -1)
	return _finish(_cursor)


func _return_from_call() -> bool:
	if _call_stack.is_empty():
		return false
	var frame: Dictionary = _call_stack.pop_back()
	_cursor = int(frame["cursor"])
	_event_object_id = int(frame["event_object_id"])
	return true


func _finish(next_entry: int) -> int:
	running = false
	waiting_for_dialog = false
	_dialog_has_body = false
	dialog_ended.emit()
	script_finished.emit(next_entry)
	return next_entry


func _pause_at_dialog_boundary() -> int:
	running = false
	waiting_for_dialog = true
	return _cursor


func _event_by_id(event_object_id: int) -> PalEventObject:
	if database == null or event_object_id <= 0 or event_object_id > database.event_objects.size():
		return null
	return database.event_objects[event_object_id - 1]


func _resolve_event(operand: int) -> PalEventObject:
	return _event_by_id(_event_object_id if operand == 0 or operand == 0xffff else operand)


static func _signed_word(value: int) -> int:
	return value - 0x10000 if value >= 0x8000 else value


static func _is_dialog_title(text: String) -> bool:
	var content := text.strip_edges()
	return content.ends_with(":") or content.ends_with("：") or content.ends_with("∶")
