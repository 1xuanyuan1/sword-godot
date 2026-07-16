# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")
const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")

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
	_test_tileset_builder()
	_test_voc_decoder()
	_test_music_reference_collection()
	_test_content_structures()
	_test_explorer_manual_search()
	_test_explorer_touch_scan()
	_test_item_definition()
	_test_player_roles_structure()
	_test_scene_draw_item_anchors()
	_test_scene_y_sorting()
	_test_pal_direction_mapping()
	_test_party_trail()
	_test_explorer_blocker_displacement()
	_test_audio_settings()
	_test_audio_player_foundation()
	_test_script_vm_foundation()
	_test_script_vm_audio_requests()
	_test_script_vm_scene_teleport()
	_test_script_vm_scene_runtime_mutations()
	_test_script_vm_dialog_pause()
	_test_script_vm_title_and_body()
	_test_script_vm_dialog_page_break()
	_test_script_vm_frame_delay_and_auto_walk()
	_test_script_vm_auto_event_lifecycle()
	_test_script_vm_inn_conversation_operations()
	_test_script_vm_inventory_and_party_walk()
	_test_script_vm_center_toast()
	_test_script_vm_quoted_narration_toast()
	_test_explorer_scene_enter_persistence()
	_test_explorer_hud_canvas_layer()
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
	_expect(PalMapCoordinates.world_to_tile(Vector2i(0, 0)) == Vector3i(0, 0, 0), "PAL collision maps the north diamond to half 0")
	_expect(PalMapCoordinates.world_to_tile(Vector2i(16, 8)) == Vector3i(0, 0, 1), "PAL collision maps a half-grid center to half 1")
	_expect(PalMapCoordinates.world_to_tile(Vector2i(24, 0)) == Vector3i(1, 0, 0), "PAL collision maps the east triangle to the next tile")
	_expect(PalMapCoordinates.world_to_tile(Vector2i(0, 8)) == Vector3i(0, 1, 0), "PAL collision maps the south triangle to the next row")
	_expect(PalMapCoordinates.world_to_tile(Vector2i(24, 12)) == Vector3i(1, 1, 0), "PAL collision maps the southeast triangle diagonally")
	_expect(PalMapCoordinates.is_within_player_walk_range(Vector2i(160, 112)), "party offset is the first valid manual walk coarse tile")
	_expect(not PalMapCoordinates.is_within_player_walk_range(Vector2i(159, 112)) and not PalMapCoordinates.is_within_player_walk_range(Vector2i(160, 111)), "manual walk range protects the viewport top and left edges")
	_expect(PalMapCoordinates.weighted_distance(Vector2i.ZERO, Vector2i(7, 4)) == 15, "PAL weighted distance doubles the vertical offset")
	_expect(PalMapCoordinates.positions_collide(Vector2i.ZERO, Vector2i(7, 4)), "EventObject collision accepts weighted distance 15")
	_expect(not PalMapCoordinates.positions_collide(Vector2i.ZERO, Vector2i(8, 4)), "EventObject collision rejects strict boundary 16")


func _test_tileset_builder() -> void:
	var map_bytes := PackedByteArray()
	map_bytes.resize(PalMapData.BYTE_SIZE)
	# 同一底层 Sprite 在相邻 half 上携带不同阻挡/高度，验证必须生成 alternative tile。
	map_bytes.encode_u32(4, 0x2000 | (3 << 8) | (2 << 16) | (4 << 24))
	# 损坏底层索引按 SDLPal 规则回退到 (0,0,0) 的图块，而不是阻止整张地图导入。
	map_bytes.encode_u32(8, 5)
	var map_data := PalMapData.from_bytes(map_bytes)
	var tile_sprite := _synthetic_map_tile_sprite()
	var tile_set := PalTileSetBuilder.build_tileset(map_data, tile_sprite)
	_expect(tile_set != null, "TileSet synthetic build")
	if tile_set == null:
		return

	var source := tile_set.get_source(PalTileSetBuilder.ATLAS_SOURCE_ID) as TileSetAtlasSource
	_expect(source != null and source.texture_region_size == Vector2i(32, 16), "TileSet atlas source and region")
	var atlas_image := source.texture.get_image()
	_expect(atlas_image.get_width() == PalTileSetBuilder.ATLAS_COLUMNS * 32, "TileSet deterministic atlas width")
	var encoded := atlas_image.get_pixel(0, 0)
	_expect(roundi(encoded.r * 255.0) == 7 and roundi(encoded.g * 255.0) == 255, "TileSet RG index and opacity")
	var transparent_padding := atlas_image.get_pixel(0, 15)
	_expect(roundi(transparent_padding.g * 255.0) == 0, "TileSet transparent sixteenth row")

	var original := Vector3i(3, 5, 1)
	var cell := PalTileSetBuilder.pal_half_to_map_cell(original.x, original.y, original.z)
	_expect(PalTileSetBuilder.map_cell_to_pal_half(cell) == original, "PAL half cell round trip")
	var coordinate_layer := TileMapLayer.new()
	coordinate_layer.tile_set = tile_set
	coordinate_layer.position = Vector2(-16, -8)
	var mapped_center := coordinate_layer.map_to_local(cell) + coordinate_layer.position
	_expect(mapped_center == Vector2(112, 88), "PAL half maps to exact Godot isometric center, actual %s" % mapped_center)
	coordinate_layer.free()

	var build := PalTileSetBuilder.build_map_resources(999, map_data, tile_sprite, "user://pal_tileset_test/content")
	_expect(bool(build.get("success", false)), "TileSet resource and PackedScene save")
	if not bool(build.get("success", false)):
		return
	var packed := ResourceLoader.load(str(build["tilemap_path"]), "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	_expect(packed != null, "TileMap PackedScene reload")
	if packed == null:
		return
	var instance := packed.instantiate()
	var bottom := instance.get_node("StaticBottom") as TileMapLayer
	var top := instance.get_node("StaticTop") as TileMapLayer
	var semantic_cell := PalTileSetBuilder.pal_half_to_map_cell(0, 0, 1)
	var bottom_data := bottom.get_cell_tile_data(semantic_cell)
	var top_data := top.get_cell_tile_data(semantic_cell)
	_expect(bottom_data != null and bool(bottom_data.get_custom_data("pal_blocked")), "TileSet blocked alternative metadata")
	_expect(bottom_data != null and int(bottom_data.get_custom_data("pal_height")) == 3, "TileSet bottom height metadata")
	_expect(top_data != null and int(top_data.get_custom_data("pal_sprite_index")) == 1 and int(top_data.get_custom_data("pal_height")) == 4, "TileSet top metadata")
	var fallback_data := bottom.get_cell_tile_data(PalTileSetBuilder.pal_half_to_map_cell(1, 0, 0))
	_expect(fallback_data != null and int(fallback_data.get_custom_data("pal_sprite_index")) == 0, "TileSet invalid bottom frame fallback")
	instance.free()


func _synthetic_map_tile_sprite() -> PalSprite:
	var frames: Array[PackedByteArray] = []
	for color_index in [7, 9]:
		var frame := PackedByteArray()
		PalBinary.append_u16_le(frame, 32)
		PalBinary.append_u16_le(frame, 15)
		for _row in range(15):
			frame.append(32)
			for _column in range(32):
				frame.append(color_index)
		# PAL Sprite 偏移以 16 位字计数，补齐到偶数字节。
		frame.append(0)
		frames.append(frame)
	var sprite_bytes := PackedByteArray()
	PalBinary.append_u16_le(sprite_bytes, 3)
	PalBinary.append_u16_le(sprite_bytes, int((6 + frames[0].size()) / 2.0))
	PalBinary.append_u16_le(sprite_bytes, 0)
	sprite_bytes.append_array(frames[0])
	sprite_bytes.append_array(frames[1])
	return PalSprite.from_bytes(sprite_bytes)


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


func _test_music_reference_collection() -> void:
	var bytes := PackedByteArray()
	for values in [[0x0043, 31, 0, 0], [0x0045, 37, 0, 0], [0x0043, 31, 1, 0], [0x0000, 0, 0, 0]]:
		for value in values:
			PalBinary.append_u16_le(bytes, value)
	_expect(PalDataImporter._music_track_numbers(bytes) == [4, 5, 31, 37], "RIX import collects unique scene/battle tracks plus preview music")


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


func _test_explorer_manual_search() -> void:
	var explorer = load("res://src/world/map_explorer.gd").new()
	var party := Vector2i(160, 112)
	var east_positions: Array[Vector2i] = explorer._search_trigger_positions(party, GameSession.DIR_EAST)
	var expected_east: Array[Vector2i] = [
		Vector2i(160, 112),
		Vector2i(176, 120), Vector2i(160, 128), Vector2i(192, 112),
		Vector2i(192, 128), Vector2i(176, 136), Vector2i(208, 120),
		Vector2i(208, 136), Vector2i(192, 144), Vector2i(224, 128),
		Vector2i(224, 144), Vector2i(208, 152), Vector2i(240, 136),
	]
	_expect(east_positions == expected_east, "manual search reproduces SDLPal's 13 east-facing checkpoints")

	var behind := _synthetic_search_event(Vector2i(144, 104), 3, 101)
	var events: Array[PalEventObject] = [behind]
	_expect(explorer._find_search_event(east_positions, events) == null, "manual search cannot trigger an event behind the party")

	var search_near_miss := _synthetic_search_event(east_positions[2], 1, 102)
	var search_near_hit := _synthetic_search_event(east_positions[1], 1, 103)
	events = [search_near_miss]
	_expect(explorer._find_search_event(east_positions, events) == null, "SearchNear checks only checkpoint indices 0-1")
	events = [search_near_hit]
	_expect(explorer._find_search_event(east_positions, events) == search_near_hit, "SearchNear accepts its forward checkpoint")

	var search_normal_hit := _synthetic_search_event(east_positions[7], 2, 104)
	var search_normal_miss := _synthetic_search_event(east_positions[8], 2, 105)
	events = [search_normal_hit]
	_expect(explorer._find_search_event(east_positions, events) == search_normal_hit, "SearchNormal accepts checkpoint index 7")
	events = [search_normal_miss]
	_expect(explorer._find_search_event(east_positions, events) == null, "SearchNormal rejects checkpoint index 8")

	var first := _synthetic_search_event(east_positions[1], 3, 106)
	var second := _synthetic_search_event(east_positions[1] + Vector2i(2, 1), 3, 107)
	events = [first, second]
	_expect(explorer._find_search_event(east_positions, events) == first, "same-half search keeps EventObject array order")
	first.trigger_script = 0
	_expect(explorer._find_search_event(east_positions, events) == first, "same-half search preserves SDLPal order even for an empty trigger entry")
	first.state = 0
	_expect(explorer._find_search_event(east_positions, events) == second, "manual search skips hidden events before applying array order")

	explorer._session.party_direction = GameSession.DIR_EAST
	explorer._session.set_party_gesture(GameSession.DIR_EAST, 2, 0)
	explorer._showing_walk_frame = true
	second.sprite_frames = 3
	second.current_frame = 4
	second.direction = GameSession.DIR_SOUTH
	_expect(explorer._prepare_search_event(second), "search prepares an event in its ordinary four-direction frame range")
	_expect(second.current_frame == 0 and second.direction == GameSession.DIR_WEST, "searched NPC stands and faces the party")
	_expect(explorer._session.scripted_party_frame(0) == -1 and not explorer._showing_walk_frame, "search clears forced party gestures before redraw")
	second.current_frame = second.sprite_frames * 4
	second.direction = GameSession.DIR_NORTH
	_expect(not explorer._prepare_search_event(second) and second.direction == GameSession.DIR_NORTH, "search preserves a special event animation frame")
	explorer.free()


func _synthetic_search_event(position: Vector2i, trigger_mode: int, object_id: int) -> PalEventObject:
	var event := PalEventObject.new()
	event.position = position
	event.state = 1
	event.trigger_mode = trigger_mode
	event.trigger_script = 1
	event.object_id = object_id
	return event


func _test_explorer_touch_scan() -> void:
	var explorer = load("res://src/world/map_explorer.gd").new()
	var party := Vector2i(160, 112)
	explorer._session.set_party_world_position(party)
	var boundary := _synthetic_touch_event(party + Vector2i(16, 0), PalEventObject.TRIGGER_TOUCH_NEAR, 201, 0)
	_expect(not explorer._is_touch_event_in_range(boundary, party), "TouchNear uses SDLPal's strict boundary and rejects distance 16")
	boundary.position.x -= 1
	_expect(explorer._is_touch_event_in_range(boundary, party), "TouchNear accepts a weighted distance below 16")
	boundary.vanish_time = 1
	_expect(not explorer._is_touch_event_in_range(boundary, party), "touch scan skips temporarily vanished events")

	var actor := _synthetic_touch_event(party + Vector2i(-16, -8), PalEventObject.TRIGGER_TOUCH_NORMAL, 202, 0)
	actor.sprite_frames = 3
	actor.current_frame = 7
	explorer._session.set_party_gesture(GameSession.DIR_EAST, 2, 0)
	explorer._showing_walk_frame = true
	_expect(explorer._prepare_touch_event(actor), "animated touch event requests a standing redraw")
	_expect(actor.current_frame == 0 and actor.direction == GameSession.DIR_EAST, "touch event faces an NPC toward the party")
	_expect(explorer._session.scripted_party_frame(0) == -1 and not explorer._showing_walk_frame, "touch event restores the party standing gesture")

	var database := PalContentDatabase.new()
	for operation in [0, 0, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	var first := _synthetic_touch_event(party, PalEventObject.TRIGGER_TOUCH_NORMAL, 203, 1)
	var empty := _synthetic_touch_event(party, PalEventObject.TRIGGER_TOUCH_NORMAL, 204, 0)
	var second := _synthetic_touch_event(party, PalEventObject.TRIGGER_TOUCH_NORMAL, 205, 2)
	explorer._database = database
	var touch_events: Array[PalEventObject] = [first, empty, second]
	explorer._scene_events = touch_events
	var vm := ScriptVM.new()
	vm.configure(database, explorer._session)
	explorer._script_vm = vm
	vm.script_finished.connect(explorer._on_script_finished)
	var invoked: Array[int] = []
	vm.instruction_started.connect(func(index: int, _operation: int, _operands: PackedInt32Array) -> void: invoked.append(index))
	_expect(explorer._trigger_touch_event(), "touch scan starts with the first in-range EventObject")
	_expect(explorer._touch_scan_active and explorer._touch_scan_next_index == 1, "touch scan saves its continuation index across an asynchronous script")
	_expect(explorer._continue_touch_scan(), "touch scan skips an empty entry and continues to the next EventObject")
	_expect(invoked == [1, 2], "overlapping touch scripts execute in EventObject order")
	explorer._continue_touch_scan()
	_expect(not explorer._touch_scan_active and explorer._touch_scan_next_index == 0, "touch scan resets after reaching the scene event boundary")
	explorer.free()
	vm.free()


func _synthetic_touch_event(position: Vector2i, trigger_mode: int, object_id: int, trigger_script: int) -> PalEventObject:
	var event := PalEventObject.new()
	event.position = position
	event.state = 1
	event.trigger_mode = trigger_mode
	event.trigger_script = trigger_script
	event.object_id = object_id
	return event


func _test_explorer_blocker_displacement() -> void:
	var explorer = load("res://src/world/map_explorer.gd").new()
	var map_bytes := PackedByteArray()
	map_bytes.resize(PalMapData.BYTE_SIZE)
	explorer._map_data = PalMapData.from_bytes(map_bytes)
	explorer._use_legacy_renderer = true
	var party := Vector2i(320, 160)
	explorer._session.set_party_world_position(party)
	var original_trail: Array[Vector2i] = []
	original_trail.assign(explorer._session.trail_positions)
	var overlapping := PalEventObject.new()
	overlapping.object_id = 301
	overlapping.position = party
	overlapping.state = 2
	overlapping.sprite_number = 1
	overlapping.direction = GameSession.DIR_SOUTH
	var events: Array[PalEventObject] = [overlapping]
	explorer._scene_events = events
	_expect(explorer._displace_party_from_blockers(), "blocking NPC overlap displaces the party")
	_expect(explorer._session.party_world_position() == party + GameSession.movement_for_direction(GameSession.DIR_WEST), "blocker displacement starts one direction after the NPC facing")
	_expect(explorer._session.trail_positions == original_trail and explorer._session.party_direction == GameSession.DIR_SOUTH, "blocker displacement preserves trail and party facing")

	explorer._session.set_party_world_position(party)
	var west_blocker := PalEventObject.new()
	west_blocker.object_id = 302
	west_blocker.position = party + GameSession.movement_for_direction(GameSession.DIR_WEST)
	west_blocker.state = 2
	west_blocker.sprite_number = 1
	events = [overlapping, west_blocker]
	explorer._scene_events = events
	_expect(explorer._displace_party_from_blockers(), "blocker displacement tries another direction when the first is occupied")
	_expect(explorer._session.party_world_position() == party + GameSession.movement_for_direction(GameSession.DIR_NORTH), "blocker displacement rotates candidates in PAL direction order")

	explorer._session.set_party_world_position(party)
	overlapping.sprite_number = 0
	events = [overlapping]
	explorer._scene_events = events
	_expect(not explorer._displace_party_from_blockers() and explorer._session.party_world_position() == party, "sprite-less blocker trigger does not push the party")

	var vanished_blocker := PalEventObject.new()
	vanished_blocker.position = party + Vector2i(7, 4)
	vanished_blocker.state = 2
	vanished_blocker.vanish_time = 5
	events = [vanished_blocker]
	explorer._scene_events = events
	_expect(explorer._is_blocked(party), "positive-state vanished EventObject keeps SDLPal movement blocking")
	vanished_blocker.position = party + Vector2i(8, 4)
	_expect(not explorer._is_blocked(party), "EventObject does not block at weighted boundary 16")
	explorer.free()


func _test_item_definition() -> void:
	var bytes := PackedByteArray()
	for value in [110, 0, 39660, 0, 0, 17]:
		PalBinary.append_u16_le(bytes, value)
	var item := PalItemDefinition.from_bytes(bytes, 0, 272)
	_expect(item != null and item.object_id == 272 and item.bitmap == 110, "DOS item object identity and bitmap parsing")
	_expect(item.script_on_use == 39660 and item.flags == 17, "DOS item use script and flags parsing")
	_expect(item.is_usable() and item.applies_to_all() and not item.is_consuming(), "story item usability flags")
	var database := PalContentDatabase.new()
	database.item_descriptions = {"272": "掺了水的酒。", "75": "糯稻的米*可解尸毒。"}
	_expect(database.get_item_description(272) == "掺了水的酒。" and database.get_item_description(75).split("*").size() == 2, "item descriptions preserve object ids and original line separators")


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
	session.party_roles = PackedInt32Array([0, 1])
	session.collapse_party_formation()
	_expect(session.party_formation_collapsed and session.party_member_world_position(1) == session.party_world_position() + Vector2i(0, -1), "opcode 00A1 formation collapse stacks followers behind the leader")
	session.record_party_step(GameSession.DIR_EAST, Vector2i(16, 8))
	_expect(not session.party_formation_collapsed, "normal movement restores the trail formation after collapse")


func _test_audio_settings() -> void:
	var session := GameSession.new()
	_expect(session.music_volume == 100 and session.sound_volume == 100, "new session audio volumes default to 100 percent")
	_expect(session.set_music_volume(-5) == 0 and session.set_sound_volume(125) == 100, "session audio settings clamp to 0-100")
	_expect(session.change_music_volume(30) == 30 and session.change_sound_volume(-20) == 80, "session audio settings support independent relative changes")
	session.reset_new_game()
	_expect(session.music_volume == 30 and session.sound_volume == 80, "new-game state reset preserves global-style audio settings")


func _test_audio_player_foundation() -> void:
	var session := GameSession.new()
	session.set_music_volume(50)
	session.set_sound_volume(25)
	var audio = AudioPlayer.new()
	audio.configure(PalContentDatabase.new(), session)
	_expect(audio._music_player != null and audio._sound_players.size() == AudioPlayer.SOUND_VOICE_COUNT, "audio player creates one music channel and a polyphonic sound pool")
	_expect(is_equal_approx(audio._music_player.volume_db, AudioPlayer.volume_percent_to_db(50)), "music channel applies session volume")
	_expect(is_equal_approx(audio._sound_players[0].volume_db, AudioPlayer.volume_percent_to_db(25)), "sound channels apply independent session volume")
	_expect(AudioPlayer.volume_percent_to_db(0) == AudioPlayer.SILENCE_DB and is_zero_approx(AudioPlayer.volume_percent_to_db(100)), "audio percent conversion handles mute and full volume")
	audio.free()


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


func _test_script_vm_audio_requests() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x0043, 0x0047, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands = PackedInt32Array([31, 3, 0])
	database.scripts[2].operands[0] = 98
	var session := GameSession.new()
	var music_requests: Array = []
	var sound_requests: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.sound_requested.connect(func(number: int) -> void: sound_requests.append(number))
	vm.run_trigger(1)
	_expect(session.music_number == 31 and music_requests == [[31, true, 3.0]], "opcode 0043 forwards music number, loop and fade semantics")
	_expect(sound_requests == [98], "opcode 0047 forwards the original VOC sound number")
	vm.free()


func _test_script_vm_scene_teleport() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x0038, 0x0047, 0x00a1, 0, 0x0046, 0x0059, 0, 0x0047, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands[0] = 8
	database.scripts[2].operands[0] = 45
	database.scripts[5].operands = PackedInt32Array([7, 86, 0])
	database.scripts[6].operands[0] = 2
	database.scripts[8].operands[0] = 99
	var source_scene := PalSceneDefinition.new()
	source_scene.script_on_teleport = 5
	database.scenes.append(source_scene)
	database.scenes.append(PalSceneDefinition.new())
	var session := GameSession.new()
	var requested_scenes: Array[int] = []
	var sounds: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(1)
	_expect(requested_scenes == [1] and session.scene_index == 1 and session.party_world_position() == Vector2i(224, 1376), "opcode 0038 executes the current scene teleport script before resuming")
	_expect(sounds == [45] and session.party_formation_collapsed and vm.script_success, "teleport caller resumes after the scene script and executes sound/formation cleanup")
	vm.free()
	source_scene.script_on_teleport = 0
	session.reset_new_game()
	sounds.clear()
	var failure_vm := ScriptVM.new()
	failure_vm.configure(database, session)
	failure_vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	failure_vm.run_trigger(1)
	_expect(not failure_vm.script_success and session.scene_index == 0 and sounds == [99], "opcode 0038 jumps to its failure entry when the scene has no teleport script")
	failure_vm.free()


func _test_script_vm_scene_runtime_mutations() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x006d, 0x009a, 0x0077, 0, 0x006d, 0x0077, 0, 0x006d, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands = PackedInt32Array([2, 41, 0])
	database.scripts[2].operands = PackedInt32Array([2, 4, 0xfffe])
	database.scripts[5].operands = PackedInt32Array([2, 0, 42])
	database.scripts[6].operands[0] = 4
	database.scripts[8].operands = PackedInt32Array([2, 0, 0])
	database.scenes.append(PalSceneDefinition.new())
	var changed_scene := PalSceneDefinition.new()
	changed_scene.script_on_enter = 7
	changed_scene.script_on_teleport = 9
	database.scenes.append(changed_scene)
	for object_id in range(1, 6):
		var event := PalEventObject.new()
		event.object_id = object_id
		event.state = object_id
		database.event_objects.append(event)
	var session := GameSession.new()
	session.music_number = 31
	var music_requests: Array = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))
	vm.run_trigger(1)
	_expect(changed_scene.script_on_enter == 41 and changed_scene.script_on_teleport == 9, "opcode 006D updates one scene script without clearing the other")
	_expect(database.event_objects.map(func(event: PalEventObject) -> int: return event.state) == [1, -2, -2, -2, 5], "opcode 009A applies a signed state to the inclusive event range")
	_expect(session.music_number == 0 and music_requests == [[0, false, 2.0]], "opcode 0077 stops BGM with the default two-second fade")
	vm.run_trigger(5)
	_expect(changed_scene.script_on_enter == 41 and changed_scene.script_on_teleport == 42, "opcode 006D can update only the teleport script")
	_expect(music_requests.back() == [0, false, 12.0], "opcode 0077 converts a nonzero operand to a three-second fade unit")
	vm.run_trigger(8)
	_expect(changed_scene.script_on_enter == 0 and changed_scene.script_on_teleport == 0, "opcode 006D clears both scene scripts when both new entries are zero")
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
	for operation in [0, 0x0004, 0x0000, 0x0000, 0x0000, 0x0049, 0x0014, 0x0024, 0x0025, 0x0047, 0x007d, 0x0000]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		call_database.scripts.append(entry)
	call_database.scripts[1].operands = PackedInt32Array([5, 2, 0])
	call_database.scripts[5].operands = PackedInt32Array([0xffff, 1, 0])
	call_database.scripts[6].operands[0] = 2
	call_database.scripts[7].operands = PackedInt32Array([3, 10, 0])
	call_database.scripts[8].operands = PackedInt32Array([3, 11, 0])
	call_database.scripts[9].operands[0] = 14
	call_database.scripts[10].operands = PackedInt32Array([3, 6, 0xfffd])
	var call_scene := PalSceneDefinition.new()
	call_scene.event_object_index = 0
	call_database.scenes.append(call_scene)
	for object_id in range(1, 4):
		var called_object := PalEventObject.new()
		called_object.object_id = object_id
		called_object.state = 0
		call_database.event_objects.append(called_object)
	call_database.event_objects[0].state = 2
	call_database.event_objects[0].auto_script = 1
	var call_session := GameSession.new()
	var instant_sounds: Array[int] = []
	var call_vm := ScriptVM.new()
	call_vm.configure(call_database, call_session)
	call_vm.sound_requested.connect(func(number: int) -> void: instant_sounds.append(number))
	call_vm.tick_frame()
	var called_event := call_database.event_objects[1]
	_expect(called_event.state == 1 and called_event.current_frame == 2, "event auto script executes an instant nested trigger call")
	var modified_event := call_database.event_objects[2]
	_expect(modified_event.auto_script == 10 and modified_event.trigger_script == 11, "instant auto subscript updates target auto/trigger entries")
	_expect(modified_event.position == Vector2i(6, -3) and instant_sounds == [14], "instant auto subscript moves targets and forwards sound effects")
	call_vm.free()


func _test_script_vm_auto_event_lifecycle() -> void:
	var database := PalContentDatabase.new()
	for operation in [0, 0x0003, 0, 0x0014, 0x0047, 0x0087, 0, 0x004c, 0, 0x0006, 0x0014, 0x0014, 0]:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	database.scripts[1].operands[0] = 3
	database.scripts[3].operands[0] = 2
	database.scripts[4].operands[0] = 98
	database.scripts[7].operands = PackedInt32Array([8, 4, 1])
	database.scripts[9].operands = PackedInt32Array([0, 11, 0])
	database.scripts[10].operands[0] = 1
	database.scripts[11].operands[0] = 3
	var scene := PalSceneDefinition.new()
	scene.event_object_index = 0
	database.scenes.append(scene)
	var jump_event := PalEventObject.new()
	jump_event.object_id = 1
	jump_event.state = 2
	jump_event.sprite_frames = 3
	jump_event.auto_script = 1
	database.event_objects.append(jump_event)
	var timed_event := PalEventObject.new()
	timed_event.object_id = 2
	timed_event.state = 1
	timed_event.vanish_time = -2
	database.event_objects.append(timed_event)
	var hidden_event := PalEventObject.new()
	hidden_event.object_id = 3
	hidden_event.state = -2
	hidden_event.vanish_time = 1
	hidden_event.current_frame = 3
	hidden_event.position = Vector2i(160, 112)
	database.event_objects.append(hidden_event)
	var chase_event := PalEventObject.new()
	chase_event.object_id = 4
	chase_event.state = 2
	chase_event.sprite_frames = 3
	chase_event.position = Vector2i(96, 80)
	chase_event.auto_script = 7
	database.event_objects.append(chase_event)
	var random_event := PalEventObject.new()
	random_event.object_id = 5
	random_event.state = 2
	random_event.auto_script = 9
	database.event_objects.append(random_event)
	var session := GameSession.new()
	session.scene_index = 0
	var sounds: Array[int] = []
	var vm := ScriptVM.new()
	vm.configure(database, session)
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.tick_frame()
	_expect(jump_event.current_frame == 2 and jump_event.auto_script == 4, "auto opcode 0003 continues its target instruction in the same frame")
	_expect(timed_event.vanish_time == -1 and not timed_event.is_visible(), "negative vanish timer keeps an event hidden while counting toward zero")
	_expect(hidden_event.vanish_time == 0 and hidden_event.state == -2, "positive hide timer does not pop a negative-state event back inside the viewport")
	_expect(chase_event.position == Vector2i(104, 84) and chase_event.direction == GameSession.DIR_EAST, "auto chase moves a floating event toward the party at the requested speed")
	_expect(random_event.current_frame == 3 and random_event.auto_script == 12, "deterministic auto random jump continues at its target in the same frame")
	vm.tick_frame()
	_expect(sounds == [98] and jump_event.auto_script == 5, "auto opcode 0047 forwards its VOC number and advances")
	_expect(timed_event.is_visible(), "negative vanish timer restores a positive-state event at zero")
	hidden_event.position = Vector2i(400, 400)
	vm.tick_frame()
	_expect(hidden_event.state == 2 and hidden_event.current_frame == 0, "negative-state event reactivates only after leaving the SDLPal viewport guard area")
	_expect(jump_event.auto_script == 6 and jump_event.current_frame == 3, "auto opcode 0087 advances animation without moving the event")
	vm.free()


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


func _test_explorer_hud_canvas_layer() -> void:
	var explorer_script: Script = load("res://src/world/map_explorer.gd")
	var explorer: Control = explorer_script.new()
	explorer._build_interface()
	_expect(explorer._ui_layer is CanvasLayer and explorer._ui_layer.layer > 0, "explorer HUD uses an independent foreground CanvasLayer")
	_expect(explorer._status.get_parent() == explorer._ui_layer, "status label stays outside the Camera2D world canvas")
	_expect(explorer._dialog_box.get_parent() == explorer._ui_layer, "dialog stays outside the Camera2D world canvas")
	_expect(explorer._game_menu.get_parent() == explorer._ui_layer, "game menu stays outside the Camera2D world canvas")
	_expect(explorer._tile_world.get_parent() == explorer, "TileMap world remains on the Camera2D world canvas")
	explorer.free()


func _test_debug_checkpoints() -> void:
	_expect(DebugCheckpoint.request("wine_dish_toast"), "current wine dish toast checkpoint is accepted")
	var checkpoint: Dictionary = DebugCheckpoint.consume()
	_expect(checkpoint.get("scene") == 0 and checkpoint.get("script") == 4995 and checkpoint.get("event") == 21 and checkpoint.get("music") == 31, "wine dish checkpoint runs the original table narration with the established scene BGM")
	_expect(DebugCheckpoint.request("meal_delivery"), "meal delivery checkpoint is accepted")
	checkpoint = DebugCheckpoint.consume()
	_expect(checkpoint.get("scene") == 0 and checkpoint.get("script") == 4885 and checkpoint.get("player_sprite") == 208 and checkpoint.get("music") == 31, "meal delivery checkpoint restores carrying state and scene BGM")
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
	menu.open_main()
	menu._main_selection = 3
	menu._confirm_selection()
	_expect(menu.current_page == PalGameMenu.Page.SYSTEM and menu._system_selection == 2, "classic system submenu opens from the fourth main item")
	var settings: Array = []
	menu.audio_settings_changed.connect(func(music: int, sound: int) -> void: settings.append([music, sound]))
	menu._move_selection(Vector2i(-1, 0))
	_expect(session.music_volume == 90 and session.sound_volume == 100 and settings.back() == [90, 100], "system menu adjusts music volume independently with left/right")
	menu._move_selection(Vector2i(0, 1))
	menu._move_selection(Vector2i(-1, 0))
	_expect(session.music_volume == 90 and session.sound_volume == 90 and settings.back() == [90, 90], "system menu adjusts sound volume independently with left/right")
	menu._confirm_selection()
	_expect(session.sound_volume == 0 and settings.back() == [90, 0], "confirm on an audio row retains classic quick on/off behavior")
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
