# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")

var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	_test_binary_helpers()
	_test_mkf_archive()
	_test_mkf_rejects_bad_offsets()
	_test_rle_decoder()
	_test_sprite_offsets()
	_test_sprite_wrapped_offset()
	_test_yj1_raw_block()
	_test_palette_decoder()
	_test_rng_animation_table()
	_test_rng_frame_decoder()
	_test_rng_rejects_malformed_delta()
	_test_map_helpers()
	_test_voc_decoder()
	_test_content_structures()
	_test_item_definition()
	_test_player_roles_structure()
	_test_scene_draw_item_anchors()
	_test_scene_y_sorting()
	_test_pal_direction_mapping()
	_test_party_trail()
	_test_script_vm_foundation()
	_test_script_vm_dialog_pause()
	_test_script_vm_title_and_body()
	_test_script_vm_dialog_page_break()
	_test_script_vm_frame_delay_and_auto_walk()
	_test_script_vm_inn_conversation_operations()
	_test_script_vm_inventory_and_party_walk()
	_test_script_vm_center_toast()
	_test_script_vm_quoted_narration_toast()
	_test_explorer_scene_enter_persistence()
	_test_debug_checkpoints()
	_test_game_menu_inventory()
	_test_explorer_input_keys()
	_test_dialog_box_typewriter()
	if _failures.is_empty():
		print("PASS: %d synthetic checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("%d/%d checks failed" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _test_binary_helpers() -> void:
	var bytes := PackedByteArray([0x34, 0x12, 0x78, 0x56])
	_expect(PalBinary.u16_le(bytes, 0) == 0x1234, "u16 little-endian")
	_expect(PalBinary.u32_le(bytes, 0) == 0x56781234, "u32 little-endian")
	_expect(PalBinary.u32_le(bytes, 1) == -1, "binary bounds")


func _test_mkf_archive() -> void:
	var data := PackedByteArray()
	for value in [12, 15, 15]:
		PalBinary.append_u32_le(data, value)
	data.append_array(PackedByteArray([1, 2, 3]))
	var archive := MkfArchive.from_bytes(data)
	_expect(archive.is_valid(), "valid synthetic MKF")
	_expect(archive.chunk_count() == 2, "MKF chunk count")
	_expect(archive.nonempty_chunk_count() == 1, "MKF empty chunk")
	_expect(archive.get_chunk(0) == PackedByteArray([1, 2, 3]), "MKF chunk bytes")
	_expect(archive.get_chunk(1).is_empty(), "MKF zero-length chunk")


func _test_mkf_rejects_bad_offsets() -> void:
	var data := PackedByteArray()
	for value in [12, 11, 12]:
		PalBinary.append_u32_le(data, value)
	var archive := MkfArchive.from_bytes(data)
	_expect(not archive.is_valid(), "MKF descending offset rejection")


func _test_rle_decoder() -> void:
	# 4×2 image: [transparent, 3, 4, transparent] / [5, 6, 7, 8]
	var rle := PackedByteArray([4, 0, 2, 0, 0x81, 2, 3, 4, 0x81, 4, 5, 6, 7, 8])
	var image := RleDecoder.decode(rle)
	_expect(image.is_valid(), "valid synthetic RLE")
	_expect(image.width == 4 and image.height == 2, "RLE dimensions")
	_expect(image.indices == PackedByteArray([0, 3, 4, 0, 5, 6, 7, 8]), "RLE indices")
	_expect(image.opacity == PackedByteArray([0, 255, 255, 0, 255, 255, 255, 255]), "RLE opacity")


func _test_sprite_offsets() -> void:
	# 2 frames: table length 3 words, starts at 6 and 8, broken zero sentinel.
	var data := PackedByteArray([3, 0, 4, 0, 0, 0, 0xaa, 0xbb, 0xcc, 0xdd])
	var sprite := PalSprite.from_bytes(data)
	_expect(sprite.is_valid(), "sprite broken sentinel compatibility")
	_expect(sprite.frame_count() == 2, "sprite frame count")
	_expect(sprite.get_frame(0) == PackedByteArray([0xaa, 0xbb]), "sprite first frame")
	_expect(sprite.get_frame(1) == PackedByteArray([0xcc, 0xdd]), "sprite last frame uses chunk end")


func _test_sprite_wrapped_offset() -> void:
	var data := PackedByteArray()
	data.resize(0x8446)
	data[0] = 3
	data[2] = 0x22
	data[3] = 0xc2
	var sprite := PalSprite.from_bytes(data)
	_expect(sprite.is_valid(), "sprite original 0x18444 wrapped offset")
	_expect(sprite.frame_count() == 2 and sprite.get_frame(1).size() == 2, "sprite wrapped frame boundary")


func _test_yj1_raw_block() -> void:
	var source := PackedByteArray()
	PalBinary.append_u32_le(source, Yj1Decoder.SIGNATURE)
	PalBinary.append_u32_le(source, 3)
	PalBinary.append_u32_le(source, 23)
	PalBinary.append_u16_le(source, 1)
	source.append(0)
	source.append(0) # Empty tree is valid for a raw block.
	PalBinary.append_u16_le(source, 3)
	PalBinary.append_u16_le(source, 0)
	source.append_array("PAL".to_ascii_buffer())
	var decoder := Yj1Decoder.new()
	var result := decoder.decompress(source, 16)
	_expect(result == "PAL".to_ascii_buffer(), "YJ1 raw block")
	_expect(decoder.error_message.is_empty(), "YJ1 raw block error state")


func _test_palette_decoder() -> void:
	var chunk := PackedByteArray()
	chunk.resize(PaletteDecoder.PALETTE_BYTES)
	chunk[0] = 63
	chunk[1] = 32
	chunk[2] = 1
	var rgb := PaletteDecoder.decode_rgb(chunk)
	_expect(rgb.size() == PaletteDecoder.PALETTE_BYTES, "palette length")
	_expect(rgb[0] == 252 and rgb[1] == 128 and rgb[2] == 4, "palette 6-bit scaling")


func _test_rng_animation_table() -> void:
	var data := PackedByteArray()
	for value in [12, 16, 16]:
		PalBinary.append_u32_le(data, value)
	data.append_array("YJ_1".to_ascii_buffer())
	var animation := RngAnimation.from_mkf_chunk(data)
	_expect(animation.is_valid(), "RNG nested MKF table")
	_expect(animation.frame_count() == 2, "RNG nested frame count")
	_expect(animation.get_compressed_frame(0) == "YJ_1".to_ascii_buffer(), "RNG compressed frame access")
	_expect(animation.frame_size(1) == 0, "RNG trailing empty frame")


func _test_rng_frame_decoder() -> void:
	var delta := PackedByteArray([
		0x06, 1, 2,
		0x02,
		0x07, 3, 4, 5, 6,
		0x03, 0,
		0x0b, 0, 7, 8,
		0x0d, 9, 10,
		0x11, 0, 11, 12,
		0x12, 0, 0, 13, 14,
		0x13,
	])
	var decoder := RngFrameDecoder.new()
	_expect(decoder.apply_delta(delta), "RNG synthetic delta decode")
	_expect(decoder.indices.slice(0, 20) == PackedByteArray([
		1, 2, 0, 0, 3, 4, 5, 6, 0, 0, 7, 8, 9, 10, 9, 10, 11, 12, 13, 14,
	]), "RNG skip/literal/repeat semantics")
	var second_delta := PackedByteArray([0x03, 0, 0x06, 21, 22, 0x00])
	_expect(decoder.apply_delta(second_delta), "RNG second incremental frame")
	_expect(decoder.indices.slice(0, 6) == PackedByteArray([1, 2, 21, 22, 3, 4]), "RNG preserves previous frame")


func _test_rng_rejects_malformed_delta() -> void:
	var decoder := RngFrameDecoder.new()
	_expect(not decoder.apply_delta(PackedByteArray([0x0c, 1, 0, 7, 8])), "RNG truncated literal rejection")
	_expect(not decoder.error_message.is_empty(), "RNG malformed error state")
	_expect(not decoder.apply_delta(PackedByteArray([0x05])), "RNG unknown opcode rejection")


func _test_map_helpers() -> void:
	var value := 0x01232145
	_expect(PalMapData.bottom_sprite_index(value) == ((value & 0xff) | ((value >> 4) & 0x100)), "map bottom index")
	_expect(PalMapData.top_sprite_index(value) == ((((value >> 16) & 0xff) | (((value >> 16) >> 4) & 0x100)) - 1), "map top index")
	_expect(PalMapData.is_blocked(0x2000), "map blocked flag")


func _test_voc_decoder() -> void:
	var voc := PackedByteArray()
	voc.append_array("Creative Voice File\u001a".to_ascii_buffer())
	PalBinary.append_u16_le(voc, 26)
	PalBinary.append_u16_le(voc, 0x0114)
	PalBinary.append_u16_le(voc, 0x111f)
	voc.append(1)
	voc.append_array(PackedByteArray([5, 0, 0])) # 2 metadata + 3 samples.
	voc.append(156) # 10 kHz time constant.
	voc.append(0) # 8-bit PCM codec.
	voc.append_array(PackedByteArray([128, 129, 130]))
	voc.append(0)
	var decoder := VocDecoder.new()
	_expect(decoder.decode(voc), "VOC type 01 decode")
	_expect(decoder.sample_rate == 10000, "VOC sample rate")
	_expect(decoder.samples == PackedByteArray([128, 129, 130]), "VOC samples")
	var wav := decoder.to_wav()
	_expect(wav.slice(0, 4).get_string_from_ascii() == "RIFF", "VOC WAV RIFF header")
	_expect(wav.size() == 48, "VOC WAV padded length")


func _test_content_structures() -> void:
	var scene_bytes := PackedByteArray([12, 0, 0x10, 0, 0x20, 0, 3, 0])
	var scene := PalSceneDefinition.from_bytes(scene_bytes, 0)
	_expect(scene != null and scene.map_number == 12, "scene map parsing")
	_expect(scene.script_on_enter == 0x10 and scene.event_object_index == 3, "scene script/index parsing")
	var script_bytes := PackedByteArray([0x46, 0, 41, 0, 18, 0, 0, 0])
	var script := PalScriptEntry.from_bytes(script_bytes, 0)
	_expect(script != null and script.operation == 0x46, "script operation parsing")
	_expect(script.operands == PackedInt32Array([41, 18, 0]), "script operand parsing")
	_expect(PalContentDatabase.speaker_role_for_message(585) == 0 and PalContentDatabase.speaker_role_for_message(584) == -1, "explicit speaker metadata only applies to confirmed untitled dialog")
	var event_bytes := PackedByteArray()
	event_bytes.resize(PalEventObject.BYTE_SIZE)
	event_bytes[14] = PalEventObject.TRIGGER_TOUCH_NEAR + 1
	var event := PalEventObject.from_bytes(event_bytes, 0)
	_expect(event.is_touch_trigger() and event.touch_trigger_distance() == 48, "touch event trigger distance follows SDLPal mode")
	var dialog_database := PalContentDatabase.new()
	dialog_database.messages.append("李大娘：")
	for operation in [0x003c, 0xffff, 0x0000]:
		var dialog_entry := PalScriptEntry.new()
		dialog_entry.operation = operation
		dialog_entry.operands = PackedInt32Array([0, 0, 0])
		dialog_database.scripts.append(dialog_entry)
	dialog_database.scripts[0].operands[0] = 55
	dialog_database._build_speaker_portrait_defaults()
	_expect(dialog_database.portrait_for_speaker("李大娘") == 55 and dialog_database.portrait_for_speaker("旁白") == 0, "speaker portrait metadata fills only known character portraits")


func _test_item_definition() -> void:
	var bytes := PackedByteArray()
	for value in [110, 0, 39660, 0, 0, 17]:
		PalBinary.append_u16_le(bytes, value)
	var item := PalItemDefinition.from_bytes(bytes, 0, 272)
	_expect(item != null and item.object_id == 272 and item.bitmap == 110, "DOS item object identity and bitmap parsing")
	_expect(item.script_on_use == 39660 and item.flags == 17, "DOS item use script and flags parsing")
	_expect(item.is_usable() and item.applies_to_all() and not item.is_consuming(), "story item usability flags")


func _test_player_roles_structure() -> void:
	var role_bytes := PackedByteArray()
	role_bytes.resize(PalPlayerRoles.BYTE_SIZE)
	role_bytes[PalPlayerRoles.AVATAR_WORD_OFFSET * 2] = 11
	var sprite_offset := PalPlayerRoles.SCENE_SPRITE_WORD_OFFSET * 2
	role_bytes[sprite_offset] = 2
	role_bytes[sprite_offset + 2] = 7
	role_bytes[PalPlayerRoles.NAME_WORD_OFFSET * 2] = 36
	var walk_offset := PalPlayerRoles.WALK_FRAMES_WORD_OFFSET * 2
	role_bytes[walk_offset] = 4
	var roles := PalPlayerRoles.from_bytes(role_bytes)
	_expect(roles.is_valid(), "PLAYERROLES structure length")
	_expect(roles.avatar_for(0) == 11 and roles.name_word_for(0) == 36, "PLAYERROLES avatar and name word")
	_expect(roles.scene_sprite_for(0) == 2 and roles.scene_sprite_for(1) == 7, "PLAYERROLES scene sprite numbers")
	_expect(roles.walk_frame_count_for(0) == 4 and roles.walk_frame_count_for(1) == 3, "PLAYERROLES walk frame fallback")


func _test_scene_draw_item_anchors() -> void:
	var frame := PalIndexedImage.new()
	frame.width = 10
	frame.height = 20
	frame.indices.resize(200)
	frame.opacity.resize(200)
	frame.opacity.fill(255)
	var player := PalSceneRenderer.player_item(frame, Vector2i(160, 112))
	_expect(player.x == 155 and player.baseline_y == 122 and player.logical_layer == 6, "scene player anchor")
	var event := PalSceneRenderer.event_item(frame, Vector2i(40, 50), 2)
	_expect(event.x == 35 and event.baseline_y == 75 and event.logical_layer == 18, "scene event layer anchor")


func _test_scene_y_sorting() -> void:
	var map_bytes := PackedByteArray()
	map_bytes.resize(PalMapData.BYTE_SIZE)
	var map_data := PalMapData.from_bytes(map_bytes)
	var tile_sprite := PalSprite.from_bytes(PackedByteArray([2, 0, 0, 0, 1, 0, 1, 0, 1, 1]))
	var first := PalIndexedImage.new()
	first.width = 1
	first.height = 1
	first.indices = PackedByteArray([7])
	first.opacity = PackedByteArray([255])
	var second := PalIndexedImage.new()
	second.width = 1
	second.height = 1
	second.indices = PackedByteArray([8])
	second.opacity = PackedByteArray([255])
	var items: Array = [
		PalSceneRenderer.DrawItem.new(second, 0, 2, 1),
		PalSceneRenderer.DrawItem.new(first, 0, 1, 0),
	]
	var rendered := PalSceneRenderer.render(map_data, tile_sprite, Rect2i(0, 0, 4, 4), items)
	_expect(rendered.is_valid(), "scene synthetic render")
	_expect(rendered.indices[0] == 8, "scene sprites sorted by baseline Y")


func _test_party_trail() -> void:
	var session := GameSession.new()
	session.reset_new_game()
	session.set_party_world_position(Vector2i(320, 160))
	session.record_party_step(GameSession.DIR_EAST, Vector2i(16, 8))
	_expect(session.party_world_position() == Vector2i(336, 168), "party leader trail movement")
	_expect(session.trail_positions[0] == Vector2i(320, 160) and session.trail_directions[0] == GameSession.DIR_EAST, "party trail records previous leader")
	_expect(session.party_member_world_position(1) == Vector2i(336, 152), "party second member formation")
	_expect(session.party_member_world_position(2) == Vector2i(336, 168), "party third member formation")
	session.set_party_gesture(GameSession.DIR_EAST, 2, 0)
	_expect(session.scripted_party_frame(0) == 11, "party script gesture stores the absolute PAL sprite frame")
	session.record_party_step(GameSession.DIR_EAST, Vector2i(16, 8))
	_expect(session.scripted_party_frame(0) == -1, "party movement clears scripted gestures")


func _test_pal_direction_mapping() -> void:
	_expect(GameSession.DIR_SOUTH == 0 and GameSession.DIR_WEST == 1, "PAL south/west direction enum")
	_expect(GameSession.DIR_NORTH == 2 and GameSession.DIR_EAST == 3, "PAL north/east direction enum")
	_expect(GameSession.movement_for_direction(GameSession.DIR_NORTH) == Vector2i(16, -8), "PAL north movement")
	_expect(GameSession.movement_for_direction(GameSession.DIR_EAST) == Vector2i(16, 8), "PAL east movement")
	_expect(GameSession.movement_for_direction(GameSession.DIR_SOUTH) == Vector2i(-16, 8), "PAL south movement")
	_expect(GameSession.movement_for_direction(GameSession.DIR_WEST) == Vector2i(-16, -8), "PAL west movement")


func _test_script_vm_foundation() -> void:
	var database := PalContentDatabase.new()
	database.scripts.append(PalScriptEntry.new()) # Entry zero is unused by PAL trigger scripts.
	var set_position := PalScriptEntry.new()
	set_position.operation = 0x46
	set_position.operands = PackedInt32Array([41, 18, 0])
	database.scripts.append(set_position)
	var stop := PalScriptEntry.new()
	stop.operation = 0
	stop.operands = PackedInt32Array([0, 0, 0])
	database.scripts.append(stop)
	var session := GameSession.new()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var next_entry := vm.run_trigger(1)
	_expect(session.viewport_position == Vector2i(1152, 176), "script VM party position opcode")
	_expect(next_entry == 1, "opcode 0000 preserves a repeatable trigger entry")
	vm.free()


func _test_script_vm_dialog_pause() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x003d, 0xffff, 0xffff, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[2].operands[0] = 12
	database.scripts[3].operands[0] = 13
	var messages: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database)
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.run_trigger(1)
	_expect(vm.waiting_for_dialog and messages == [12, 13], "script VM combines consecutive dialog body messages")
	vm.advance_dialog()
	_expect(not vm.waiting_for_dialog and not vm.running, "script VM finishes after one dialog round")
	vm.free()


func _test_script_vm_title_and_body() -> void:
	var database := PalContentDatabase.new()
	database.messages.resize(14)
	database.messages[12] = "测试人："
	database.messages[13] = "正文"
	for operation in [0, 0x003c, 0xffff, 0xffff, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[2].operands[0] = 12
	database.scripts[3].operands[0] = 13
	var messages: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database)
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.run_trigger(1)
	_expect(vm.waiting_for_dialog and messages == [12, 13], "script VM combines speaker title with first body line")
	vm.advance_dialog()
	_expect(not vm.waiting_for_dialog, "script VM title does not require a separate key press")
	vm.free()


func _test_script_vm_dialog_page_break() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x003d, 0xffff, 0xffff, 0x008e, 0xffff, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.messages.resize(15)
	database.messages[12] = "李大娘："
	database.messages[13] = "上一页"
	database.messages[14] = "下一页"
	database.scripts[2].operands[0] = 12
	database.scripts[3].operands[0] = 13
	database.scripts[5].operands[0] = 14
	var messages: Array[int] = []
	var page_breaks: Array[int] = [0]
	var vm := ScriptVM.new()
	vm.configure(database)
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.dialog_page_break.connect(func() -> void: page_breaks[0] += 1)
	vm.run_trigger(1)
	_expect(vm.waiting_for_dialog and messages == [12, 13], "script VM pauses before a dialog page break")
	vm.advance_dialog()
	_expect(vm.waiting_for_dialog and page_breaks[0] == 1 and messages == [12, 13, 14], "script VM continues dialog after a page break")
	vm.advance_dialog()
	vm.free()


func _test_script_vm_frame_delay_and_auto_walk() -> void:
	var database := PalContentDatabase.new()
	database.scripts.append(PalScriptEntry.new())
	for operation in [0x0009, 0x0049, 0x0000, 0x0010, 0x0049, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands[0] = 3
	database.scripts[2].operands = PackedInt32Array([0xffff, 0, 0])
	database.scripts[4].operands = PackedInt32Array([1, 1, 0])
	database.scripts[5].operands = PackedInt32Array([0xffff, 0, 0])
	var scene := PalSceneDefinition.new()
	scene.event_object_index = 0
	database.scenes.append(scene)
	var event := PalEventObject.new()
	event.object_id = 1
	event.position = Vector2i.ZERO
	event.state = 2
	event.sprite_frames = 3
	event.auto_script = 4
	database.event_objects.append(event)
	var session := GameSession.new()
	session.scene_index = 0
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.run_trigger(1, 1)
	_expect(vm.running and vm.waiting_for_frames, "script VM preserves trigger execution during frame delay")
	vm.tick_frame()
	vm.tick_frame()
	_expect(event.state == 2, "script VM does not execute post-delay action early")
	vm.tick_frame()
	_expect(not vm.running and event.state == 0, "script VM resumes post-delay action on the requested frame")
	event.state = 2
	for frame in range(10):
		vm.tick_frame()
	_expect(event.position == Vector2i(32, 16) and event.state == 0, "event auto script walks to its target and exits")
	vm.free()
	var gesture_database := PalContentDatabase.new()
	gesture_database.scripts.append(PalScriptEntry.new())
	for operation in [0x0015, 0x0009, 0x0015, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		gesture_database.scripts.append(entry)
	gesture_database.scripts[1].operands = PackedInt32Array([3, 2, 0])
	gesture_database.scripts[2].operands[0] = 2
	var gesture_session := GameSession.new()
	var gesture_vm := ScriptVM.new()
	gesture_vm.configure(gesture_database, gesture_session)
	gesture_vm.run_trigger(1)
	_expect(gesture_session.scripted_party_frame(0) == 11 and gesture_vm.waiting_for_frames, "script VM keeps a party gesture during its frame delay")
	gesture_vm.tick_frame()
	gesture_vm.tick_frame()
	_expect(gesture_session.scripted_party_frame(0) == 0 and not gesture_vm.running, "script VM advances to the next party gesture after its delay")
	gesture_vm.free()
	var step_database := PalContentDatabase.new()
	step_database.scripts.append(PalScriptEntry.new())
	for operation in [0x006e, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		step_database.scripts.append(entry)
	step_database.scripts[1].operands = PackedInt32Array([10, 5, 1])
	var step_session := GameSession.new()
	var step_signals: Array[int] = []
	var step_vm := ScriptVM.new()
	step_vm.configure(step_database, step_session)
	step_vm.party_step_performed.connect(func() -> void: step_signals.append(1))
	step_vm.run_trigger(1)
	_expect(step_signals.size() == 1 and step_session.party_world_position() == Vector2i(170, 117), "scripted party step emits an animation signal")
	step_vm.free()
	var call_database := PalContentDatabase.new()
	for operation in [0, 0x0004, 0x0000, 0x0000, 0x0000, 0x0049, 0x0014, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		call_database.scripts.append(entry)
	call_database.scripts[1].operands = PackedInt32Array([5, 2, 0])
	call_database.scripts[5].operands = PackedInt32Array([0xffff, 1, 0])
	call_database.scripts[6].operands[0] = 2
	var call_scene := PalSceneDefinition.new()
	call_scene.event_object_index = 0
	call_database.scenes.append(call_scene)
	for object_id in range(1, 3):
		var called_object := PalEventObject.new()
		called_object.object_id = object_id
		called_object.state = 0
		call_database.event_objects.append(called_object)
	call_database.event_objects[0].state = 2
	call_database.event_objects[0].auto_script = 1
	var call_session := GameSession.new()
	var call_vm := ScriptVM.new()
	call_vm.configure(call_database, call_session)
	call_vm.tick_frame()
	var called_event := call_database.event_objects[1]
	_expect(called_event.state == 1 and called_event.current_frame == 2, "event auto script executes an instant nested trigger call")
	call_vm.free()


func _test_script_vm_inn_conversation_operations() -> void:
	var database := PalContentDatabase.new()
	database.scripts.append(PalScriptEntry.new())
	for operation in [0x0085, 0x0024, 0x0025, 0x001e, 0x0000, 0x0000, 0x0000, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands[0] = 4
	database.scripts[2].operands = PackedInt32Array([2, 6, 0])
	database.scripts[3].operands = PackedInt32Array([2, 7, 0])
	database.scripts[4].operands[0] = 500
	var scene := PalSceneDefinition.new()
	scene.event_object_index = 0
	database.scenes.append(scene)
	for object_id in range(1, 3):
		var event := PalEventObject.new()
		event.object_id = object_id
		event.state = 2
		database.event_objects.append(event)
	var session := GameSession.new()
	session.scene_index = 0
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_frames, "opcode 0085 starts a timed script delay")
	for frame in range(4):
		vm.tick_frame()
	var target := database.event_objects[1]
	_expect(not vm.running and target.auto_script == 6 and target.trigger_script == 7, "opcodes 0024 and 0025 update event scripts")
	_expect(session.cash == 500, "opcode 001E updates party cash")
	vm.free()


func _test_script_vm_inventory_and_party_walk() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x001f, 0x006f, 0x0070, 0x0020, 0x0073, 0x0008, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands = PackedInt32Array([272, 0, 0])
	database.scripts[2].operands = PackedInt32Array([2, 0, 0])
	database.scripts[3].operands = PackedInt32Array([6, 8, 0])
	database.scripts[4].operands = PackedInt32Array([272, 0, 0])
	for object_id in range(1, 3):
		var event := PalEventObject.new()
		event.object_id = object_id
		event.state = 2 if object_id == 1 else 0
		database.event_objects.append(event)
	var session := GameSession.new()
	session.reset_new_game()
	var steps: Array[int] = []
	var walk_finishes: Array[int] = []
	var next_entries: Array[int] = []
	var redraws: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.party_step_performed.connect(func() -> void: steps.append(1))
	vm.party_walk_finished.connect(func() -> void: walk_finishes.append(1))
	vm.script_finished.connect(func(next_entry: int) -> void: next_entries.append(next_entry))
	vm.redraw_requested.connect(func(delay: int) -> void: redraws.append(delay))
	vm.run_trigger(1, 1)
	_expect(vm.running and vm.waiting_for_party_walk and session.item_count(272) == 1, "inventory add runs before scripted party walk")
	for frame in range(8):
		vm.tick_frame()
	_expect(session.party_world_position() == Vector2i(192, 128) and steps.size() == 8 and walk_finishes.size() == 1, "opcode 0070 walks the party over visible script frames and finishes its gait")
	_expect(not vm.running and session.item_count(272) == 0, "inventory remove completes after scripted party walk")
	_expect(database.event_objects[0].state == 0, "opcode 006F synchronizes the invoking event state")
	_expect(redraws == [0] and next_entries == [7], "fade placeholder and opcode 0008 preserve the future trigger entry")
	vm.free()


func _test_script_vm_center_toast() -> void:
	var database := PalContentDatabase.new()
	database.messages.append("获得500文钱")
	for operation in [0, 0x003e, 0xffff, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	var messages: Array[int] = []
	var ended: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database)
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.dialog_ended.connect(func() -> void: ended.append(1))
	vm.run_trigger(1)
	_expect(vm.running and vm.waiting_for_frames and not vm.waiting_for_dialog and messages == [0], "center toast waits without requiring dialog input")
	for frame in range(14):
		vm.tick_frame()
	_expect(not vm.running and ended.size() >= 1, "center toast closes automatically after 1.4 seconds")
	vm.free()


func _test_script_vm_quoted_narration_toast() -> void:
	var database := PalContentDatabase.new()
	database.messages = ["\"桌上摆着一份丰盛的酒菜", "嗯～看起来很好吃的样子\"", "普通中央对白"]
	for operation in [0, 0x003b, 0xffff, 0xffff, 0, 0x003b, 0xffff, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[2].operands[0] = 0
	database.scripts[3].operands[0] = 1
	database.scripts[6].operands[0] = 2
	var positions: Array[int] = []
	var messages: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database)
	vm.dialog_started.connect(func(position: int, _color: int, _portrait: int) -> void: positions.append(position))
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.run_trigger(1)
	_expect(positions == [3] and messages == [0, 1], "quoted center narration uses one toast round and keeps consecutive lines together")
	_expect(vm.waiting_for_frames and not vm.waiting_for_dialog, "quoted narration toast closes on a timer without dialog input")
	for frame in range(14):
		vm.tick_frame()
	positions.clear()
	messages.clear()
	vm.run_trigger(5)
	_expect(positions == [2] and messages == [2] and vm.waiting_for_dialog, "unquoted center dialog keeps the normal interactive presentation")
	vm.free()


func _test_explorer_scene_enter_persistence() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 1, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	var scene := PalSceneDefinition.new()
	scene.script_on_enter = 1
	database.scenes.append(scene)
	var vm := ScriptVM.new()
	vm.configure(database, GameSession.new())
	var explorer_script: Script = load("res://src/world/map_explorer.gd")
	var explorer: Control = explorer_script.new()
	explorer._database = database
	explorer._script_vm = vm
	vm.script_finished.connect(explorer._on_script_finished)
	var executed_entries: Array[int] = []
	vm.instruction_started.connect(func(index: int, _operation: int, _operands: PackedInt32Array) -> void: executed_entries.append(index))
	explorer._run_scene_enter_script(0)
	_expect(scene.script_on_enter == 2 and explorer._active_scene_enter_index == -1, "scene enter script persists its returned entry")
	explorer._run_scene_enter_script(0)
	_expect(executed_entries == [1, 2], "re-entering a scene resumes from the persisted entry instead of replaying the intro")
	explorer.free()
	vm.free()


func _test_debug_checkpoints() -> void:
	_expect(DebugCheckpoint.request("wine_dish_toast"), "current wine dish toast checkpoint is accepted")
	var checkpoint: Dictionary = DebugCheckpoint.consume()
	_expect(checkpoint.get("scene") == 0 and checkpoint.get("script") == 4995 and checkpoint.get("event") == 21, "wine dish checkpoint runs the original table narration")
	_expect(DebugCheckpoint.request("meal_delivery"), "meal delivery checkpoint is accepted")
	checkpoint = DebugCheckpoint.consume()
	_expect(checkpoint.get("scene") == 0 and checkpoint.get("script") == 4885 and checkpoint.get("player_sprite") == 208, "meal delivery checkpoint restores carrying state")
	_expect(DebugCheckpoint.request("drunken_swordsman"), "drunken swordsman checkpoint is accepted")
	checkpoint = DebugCheckpoint.consume()
	_expect(checkpoint.get("script") == 5079 and checkpoint.get("inventory", {}).get(272) == 1, "drunken swordsman checkpoint restores osmanthus wine")
	_expect(not DebugCheckpoint.request("kitchen_entry") and not DebugCheckpoint.request("stairs"), "completed non-wine manual checkpoints are archived from the test lab")
	_expect(DebugCheckpoint.consume().is_empty() and not DebugCheckpoint.request("missing"), "debug story checkpoint is consumed once and rejects unknown ids")


func _test_game_menu_inventory() -> void:
	var database := PalContentDatabase.new()
	database.words.resize(273)
	database.words[272] = "桂花酒"
	database.items.resize(273)
	var wine := PalItemDefinition.new()
	wine.object_id = 272
	wine.script_on_use = 39660
	wine.flags = PalItemDefinition.FLAG_USABLE | PalItemDefinition.FLAG_APPLY_TO_ALL
	database.items[272] = wine
	var session := GameSession.new()
	session.set_item_count(272, 1)
	var menu := PalGameMenu.new()
	menu._ready()
	menu.configure(database, session)
	menu.open_main()
	_expect(menu.current_page == PalGameMenu.Page.MAIN and menu._main_selection == 2, "classic main menu opens with inventory selected")
	menu._confirm_selection()
	_expect(menu.current_page == PalGameMenu.Page.INVENTORY_ACTION, "classic inventory command submenu opens from the main menu")
	menu._confirm_selection()
	_expect(menu.current_page == PalGameMenu.Page.INVENTORY and menu._inventory_ids == [272], "classic item grid contains the current inventory")
	var requested: Array[int] = []
	menu.item_use_requested.connect(func(item_id: int) -> void: requested.append(item_id))
	_expect(menu.visible and menu.current_page == PalGameMenu.Page.INVENTORY, "game menu opens the inventory page")
	menu._request_item_use(272, wine)
	_expect(requested == [272], "usable story item can be selected from the inventory menu")
	menu.free()


func _test_explorer_input_keys() -> void:
	var explorer_script: Script = load("res://src/world/map_explorer.gd")
	var constants := explorer_script.get_script_constant_map()
	var menu_keys: Array = constants.get("MENU_KEYCODES", [])
	_expect(KEY_ESCAPE in menu_keys and KEY_M in menu_keys and KEY_I in menu_keys, "explorer Escape/M/I keys open the game menu")
	_expect(constants.get("RETURN_TO_LAB_KEYCODE") == KEY_F10 and KEY_F10 not in menu_keys, "explorer F10 returns to the lab without overloading Escape")


func _test_dialog_box_typewriter() -> void:
	var dialog := PalDialogBox.new()
	dialog._ready()
	dialog.begin(1)
	dialog.show_message("李逍遥：")
	dialog.show_message("行侠仗义")
	dialog.show_message("丢下我不管！")
	_expect(dialog._full_text == "行侠仗义丢下我不管！", "dialog body fragments concatenate without forced line breaks")
	_expect(dialog._message.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "dialog body aligns to the top")
	_expect(dialog._message.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY and dialog._message.clip_contents, "dialog body wraps within its content width")
	_expect(dialog._message.get_theme_font_size("normal_font_size") == 10, "dialog body uses the intended RichTextLabel font size")
	dialog._process(0.2)
	_expect(dialog.is_typing() and dialog._message.visible_characters > 0, "dialog body reveals characters progressively")
	dialog.reveal_all()
	_expect(not dialog.is_typing() and dialog._message.visible_characters == dialog._full_text.length(), "dialog reveal shows the whole current round")
	var portrait := GradientTexture2D.new()
	dialog.begin(1, 0, portrait)
	dialog.show_message("李大娘：")
	dialog.show_message("上一页")
	dialog.next_page()
	_expect(dialog.has_portrait() and dialog._speaker.text == "李大娘" and dialog._full_text.is_empty(), "dialog page break preserves speaker context")
	var restored_portrait := GradientTexture1D.new()
	dialog.hide_dialog()
	dialog.show_speaker_title("李大娘：", restored_portrait)
	dialog.show_message("各位客倌．．裡邊兒請．．")
	_expect(dialog.has_portrait() and dialog._portrait.texture == restored_portrait and dialog._portrait_column.visible, "implicit dialog round restores the fallback speaker portrait after hiding")
	dialog.begin(3)
	dialog.show_message("获得500文钱")
	_expect(dialog._panel.size == Vector2(176, 32) and dialog._message.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and not dialog._hint.visible, "center toast uses compact centered presentation")
	_expect(dialog._message.get_theme_font_size("normal_font_size") == 8, "center toast uses a smaller font than character dialogue")
	dialog.free()
