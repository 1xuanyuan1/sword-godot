# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalDebugCheckpoint
extends RefCounted

static var _pending: Dictionary = {}


static func request(checkpoint_id: String) -> bool:
	match checkpoint_id:
		"intro":
			_pending = {"id": checkpoint_id, "scene": 0, "script": 7952, "event": 0}
		"secret_passage":
			_pending = {"id": checkpoint_id, "scene": 0, "script": 4479, "event": 10}
		"miao_inn":
			_pending = {"id": checkpoint_id, "scene": 2, "script": 4701, "event": 57, "position": Vector2i(1264, 1352)}
		"stairs":
			_pending = {"id": checkpoint_id, "scene": 2, "script": 42, "event": 47, "position": Vector2i(1248, 1456)}
		_:
			_pending = {}
			return false
	return true


static func consume() -> Dictionary:
	var result := _pending.duplicate(true)
	_pending = {}
	return result
