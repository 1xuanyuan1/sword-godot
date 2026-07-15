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
	_test_yj1_raw_block()
	_test_palette_decoder()
	_test_map_helpers()
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

