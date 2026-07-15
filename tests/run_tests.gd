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
	_test_yj1_raw_block()
	_test_palette_decoder()
	_test_map_helpers()
	_test_voc_decoder()
	_test_content_structures()
	_test_script_vm_foundation()
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
