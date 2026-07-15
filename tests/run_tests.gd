# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

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
	vm.run_trigger(1)
	_expect(session.viewport_position == Vector2i(1152, 176), "script VM party position opcode")
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
	dialog.free()
