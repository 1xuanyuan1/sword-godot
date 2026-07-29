# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从 GameSession 和 EventObject 构建经典与高清 2D 渲染共用的展示快照。
## 队员编队回退、方向、普通步态、剧情动作和事件帧只在这里选择一次。
class_name PalWorldPresentationBuilder
extends RefCounted


## 构建一帧共享展示快照；`map_blocked` 可由正式 PalTileMapWorld 提供地图阻挡查询。
static func build(
	database: PalContentDatabase,
	session: GameSession,
	events: Array[PalEventObject],
	map_number: int,
	walk_phase: int,
	moving: bool,
	camera_offset: Vector2i = Vector2i.ZERO,
	map_blocked: Callable = Callable()
) -> PalWorldPresentationSnapshot:
	var snapshot := PalWorldPresentationSnapshot.new()
	snapshot.scene_index = session.scene_index
	snapshot.map_number = map_number
	snapshot.palette_index = session.palette_index
	snapshot.night_palette = session.night_palette
	snapshot.viewport_position = session.viewport_position
	snapshot.camera_offset = camera_offset
	snapshot.camera_center_pal = session.viewport_position + camera_offset + PalPresentationMetrics.CLASSIC_CONTENT_SIZE / 2
	if database == null or database.player_roles == null:
		return snapshot

	for party_index in range(mini(session.party_roles.size(), 3)):
		var role_index := session.party_roles[party_index]
		var world_position := session.party_member_world_position(party_index)
		if party_index > 0 and _position_is_blocked(world_position, events, map_blocked):
			world_position = session.party_member_fallback_world_position()
		var actor := PalPresentationActor.new()
		actor.logical_id = "character/role_%02d/field" % role_index
		actor.kind = PalPresentationActor.KIND_PARTY
		actor.role_index = role_index
		actor.sprite_number = database.player_roles.scene_sprite_for(role_index)
		actor.pal_world_position = world_position
		actor.direction = session.party_member_direction(party_index)
		actor.frame_index = _party_frame_index(database, session, role_index, party_index, walk_phase, moving)
		actor.scene_layer = session.world_layer
		actor.logical_layer = session.world_layer + 6
		actor.is_party_member = true
		snapshot.party.append(actor)

	for follower_index in range(mini(2, session.follower_sprite_numbers.size())):
		var trail_index := 3 + follower_index
		if trail_index >= session.trail_positions.size() or trail_index >= session.trail_directions.size():
			continue
		var sprite_number := session.follower_sprite_numbers[follower_index]
		var sprite := database.load_mgo_sprite(sprite_number)
		var actor := PalPresentationActor.new()
		actor.logical_id = "character/mgo_%03d/field" % sprite_number
		actor.kind = PalPresentationActor.KIND_FOLLOWER
		actor.source_object_id = follower_index + 1
		actor.sprite_number = sprite_number
		actor.pal_world_position = session.trail_positions[trail_index]
		actor.direction = session.trail_directions[trail_index]
		actor.frame_index = PalSceneLayout.follower_frame_index(actor.direction, sprite.frame_count())
		actor.scene_layer = session.world_layer
		actor.logical_layer = session.world_layer + 6
		snapshot.followers.append(actor)

	for event in events:
		if not event.is_visible():
			continue
		var actor := PalPresentationActor.new()
		actor.logical_id = "character/mgo_%03d/field" % event.sprite_number
		actor.kind = PalPresentationActor.KIND_EVENT
		actor.source_object_id = event.object_id
		actor.sprite_number = event.sprite_number
		actor.pal_world_position = event.position
		actor.direction = event.direction
		actor.frame_index = _event_frame_index(event)
		actor.scene_layer = event.layer
		actor.logical_layer = event.layer * 8 + 2
		snapshot.events.append(actor)
	return snapshot


static func _party_frame_index(database: PalContentDatabase, session: GameSession, role_index: int, party_index: int, walk_phase: int, moving: bool) -> int:
	var scripted_frame := session.scripted_party_frame(party_index)
	if scripted_frame >= 0:
		return scripted_frame
	var walk_frames := database.player_roles.walk_frame_count_for(role_index)
	var frame_index := session.party_member_direction(party_index) * walk_frames
	if moving:
		if walk_frames == 4:
			frame_index += posmod(walk_phase, 4)
		elif (walk_phase & 1) != 0:
			# SDLPal 三帧人物使用 0→1→0→2，而不是简单的 0→1→2 循环。
			frame_index += int((posmod(walk_phase, 4) + 1) / 2.0)
	return frame_index


static func _event_frame_index(event: PalEventObject) -> int:
	if event.sprite_number <= 0:
		return -1
	var frame_index := event.current_frame
	if event.sprite_frames == 3:
		if frame_index == 2:
			frame_index = 0
		elif frame_index == 3:
			frame_index = 2
	return frame_index + event.direction * event.sprite_frames


static func _position_is_blocked(world_position: Vector2i, events: Array[PalEventObject], map_blocked: Callable) -> bool:
	if map_blocked.is_valid() and bool(map_blocked.call(world_position)):
		return true
	for event in events:
		if event.blocks_movement() and PalMapCoordinates.positions_collide(event.position, world_position):
			return true
	return false
