# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name WorldOverlay
extends Control

var events: Array[PalEventObject] = []
var viewport_position: Vector2i = Vector2i.ZERO


func set_world_state(scene_events: Array[PalEventObject], new_viewport: Vector2i) -> void:
	events = scene_events
	viewport_position = new_viewport
	queue_redraw()


func _draw() -> void:
	for event in events:
		if not event.is_visible():
			continue
		var screen_position := event.position - viewport_position
		if screen_position.x < -8 or screen_position.x > size.x + 8 or screen_position.y < -8 or screen_position.y > size.y + 8:
			continue
		var color := Color("fb7185") if event.blocks_movement() else Color("c084fc")
		draw_circle(Vector2(screen_position), 2.5, color)
		draw_line(Vector2(screen_position) + Vector2(-3, 3), Vector2(screen_position) + Vector2(3, 3), color, 1.0)

	# Placeholder until MGO player sprites are wired into the scene renderer.
	var hero := Vector2(GameSession.PARTY_OFFSET)
	draw_rect(Rect2(hero.x - 2, hero.y - 7, 5, 8), Color("fde047"), true)
	draw_pixel(hero + Vector2(0, -5), Color("111827"))


func draw_pixel(position: Vector2, color: Color) -> void:
	draw_rect(Rect2(position, Vector2.ONE), color, true)

