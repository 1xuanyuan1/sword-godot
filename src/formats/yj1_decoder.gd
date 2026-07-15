# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal yj1.c and PalLibrary by Lou Yihua.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Yj1Decoder
extends RefCounted

const SIGNATURE := 0x315f4a59 # "YJ_1" as a little-endian uint32.

var error_message: String = ""


class BitReader:
	var data: PackedByteArray
	var base_offset: int
	var bit_position: int = 0
	var failed: bool = false

	func _init(source: PackedByteArray, source_offset: int) -> void:
		data = source
		base_offset = source_offset

	func read(count: int) -> int:
		if failed or count < 0 or count > 16:
			failed = true
			return 0
		if count == 0:
			return 0
		var byte_offset := base_offset + ((bit_position >> 4) << 1)
		var bit_in_word := bit_position & 0x0f
		bit_position += count
		var first_word := PalBinary.u16_le(data, byte_offset)
		if first_word < 0:
			failed = true
			return 0
		if count > 16 - bit_in_word:
			var overflow_bits := count + bit_in_word - 16
			var second_word := PalBinary.u16_le(data, byte_offset + 2)
			if second_word < 0:
				failed = true
				return 0
			var mask := 0xffff >> bit_in_word
			return ((first_word & mask) << overflow_bits) | (second_word >> (16 - overflow_bits))
		return ((first_word << bit_in_word) & 0xffff) >> (16 - count)


func decompress(source: PackedByteArray, destination_limit: int = 64 * 1024 * 1024) -> PackedByteArray:
	error_message = ""
	if source.size() < 16:
		return _fail("YJ1 文件头不完整")
	if PalBinary.u32_le(source, 0) != SIGNATURE:
		return _fail("不是 YJ_1 数据")

	var uncompressed_length := PalBinary.u32_le(source, 4)
	var compressed_length := PalBinary.u32_le(source, 8)
	var block_count := PalBinary.u16_le(source, 12)
	var tree_length := source[15] * 2
	if uncompressed_length < 0 or uncompressed_length > destination_limit:
		return _fail("YJ1 解压尺寸超出限制：%d" % uncompressed_length)
	if compressed_length > 0 and compressed_length > source.size():
		return _fail("YJ1 声明的压缩长度越界")

	var leaves: Array[bool] = []
	leaves.resize(tree_length + 1)
	var values := PackedByteArray()
	values.resize(tree_length + 1)
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	left.resize(tree_length + 1)
	right.resize(tree_length + 1)
	leaves[0] = false
	if tree_length >= 2:
		left[0] = 1
		right[0] = 2

	var tree_bytes_offset := 16
	var flag_offset := tree_bytes_offset + tree_length
	var tree_reader := BitReader.new(source, flag_offset)
	for index in range(1, tree_length + 1):
		if not PalBinary.can_read(source, tree_bytes_offset + index - 1, 1):
			return _fail("YJ1 Huffman 值表越界")
		leaves[index] = tree_reader.read(1) == 0
		values[index] = source[tree_bytes_offset + index - 1]
		if leaves[index]:
			left[index] = -1
			right[index] = -1
		else:
			left[index] = (values[index] << 1) + 1
			right[index] = left[index] + 1
			if right[index] > tree_length:
				return _fail("YJ1 Huffman 子节点越界")
	if tree_reader.failed:
		return _fail("YJ1 Huffman 标志位不完整")

	var flag_storage_length := ((tree_length + 15) >> 4) << 1
	var source_offset := 16 + tree_length + flag_storage_length
	var output := PackedByteArray()
	output.resize(uncompressed_length)
	var destination_offset := 0

	for block_index in range(block_count):
		if not PalBinary.can_read(source, source_offset, 4):
			return _fail("YJ1 第 %d 块头不完整" % block_index)
		var header_offset := source_offset
		var block_uncompressed := PalBinary.u16_le(source, header_offset)
		var block_compressed := PalBinary.u16_le(source, header_offset + 2)
		if block_uncompressed < 0 or destination_offset + block_uncompressed > output.size():
			return _fail("YJ1 第 %d 块解压尺寸越界" % block_index)

		if block_compressed == 0:
			source_offset += 4
			if not PalBinary.can_read(source, source_offset, block_uncompressed):
				return _fail("YJ1 第 %d 个原样块数据不完整" % block_index)
			for index in range(block_uncompressed):
				output[destination_offset + index] = source[source_offset + index]
			destination_offset += block_uncompressed
			source_offset += block_uncompressed
			continue

		if block_compressed < 24 or not PalBinary.can_read(source, header_offset, block_compressed):
			return _fail("YJ1 第 %d 块压缩长度无效" % block_index)
		if tree_length < 2:
			return _fail("YJ1 压缩块缺少 Huffman 树")

		var repeat_table := PackedInt32Array()
		for index in range(4):
			repeat_table.append(PalBinary.u16_le(source, header_offset + 4 + index * 2))
		var offset_code_lengths := PackedInt32Array()
		for index in range(4):
			offset_code_lengths.append(source[header_offset + 12 + index])
		var repeat_code_lengths := PackedInt32Array()
		for index in range(3):
			repeat_code_lengths.append(source[header_offset + 16 + index])
		var count_code_lengths := PackedInt32Array()
		for index in range(3):
			count_code_lengths.append(source[header_offset + 19 + index])
		var count_table := PackedInt32Array([source[header_offset + 22], source[header_offset + 23]])
		var reader := BitReader.new(source, header_offset + 24)
		var block_destination_start := destination_offset

		while true:
			var literal_loop := _read_loop(reader, count_code_lengths, count_table)
			if reader.failed:
				return _fail("YJ1 第 %d 块字面量计数不完整" % block_index)
			if literal_loop == 0:
				break
			for _literal_index in range(literal_loop):
				var node := 0
				var guard := 0
				while not leaves[node]:
					node = right[node] if reader.read(1) != 0 else left[node]
					guard += 1
					if reader.failed or node < 0 or node > tree_length or guard > tree_length + 1:
						return _fail("YJ1 第 %d 块 Huffman 流损坏" % block_index)
				if destination_offset >= output.size():
					return _fail("YJ1 第 %d 块输出越界" % block_index)
				output[destination_offset] = values[node]
				destination_offset += 1

			var copy_loop := _read_loop(reader, count_code_lengths, count_table)
			if reader.failed:
				return _fail("YJ1 第 %d 块复制计数不完整" % block_index)
			if copy_loop == 0:
				break
			for _copy_index in range(copy_loop):
				var repeat_count := _read_repeat_count(reader, repeat_table, repeat_code_lengths)
				var offset_selector := reader.read(2)
				if offset_selector < 0 or offset_selector >= offset_code_lengths.size():
					return _fail("YJ1 第 %d 块偏移选择器无效" % block_index)
				var back_offset := reader.read(offset_code_lengths[offset_selector])
				if reader.failed or repeat_count < 0 or back_offset <= 0 or back_offset > destination_offset:
					return _fail("YJ1 第 %d 块 LZSS 引用无效" % block_index)
				if destination_offset + repeat_count > output.size():
					return _fail("YJ1 第 %d 块 LZSS 输出越界" % block_index)
				for _byte_index in range(repeat_count):
					output[destination_offset] = output[destination_offset - back_offset]
					destination_offset += 1

		if destination_offset - block_destination_start != block_uncompressed:
			return _fail("YJ1 第 %d 块长度不匹配：%d != %d" % [block_index, destination_offset - block_destination_start, block_uncompressed])
		source_offset = header_offset + block_compressed

	if destination_offset != uncompressed_length:
		return _fail("YJ1 总长度不匹配：%d != %d" % [destination_offset, uncompressed_length])
	return output


func _read_loop(reader: BitReader, code_lengths: PackedInt32Array, count_table: PackedInt32Array) -> int:
	if reader.read(1) != 0:
		return count_table[0]
	var selector := reader.read(2)
	if selector != 0:
		return reader.read(code_lengths[selector - 1])
	return count_table[1]


func _read_repeat_count(reader: BitReader, repeat_table: PackedInt32Array, code_lengths: PackedInt32Array) -> int:
	var selector := reader.read(2)
	if selector == 0:
		return repeat_table[0]
	if reader.read(1) != 0:
		return reader.read(code_lengths[selector - 1])
	return repeat_table[selector]


func _fail(message: String) -> PackedByteArray:
	error_message = message
	return PackedByteArray()

