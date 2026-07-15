# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal sound.c.
# SPDX-License-Identifier: GPL-3.0-or-later
class_name VocDecoder
extends RefCounted

const SIGNATURE := "Creative Voice File\u001a"

var error_message: String = ""
var sample_rate: int = 0
var samples: PackedByteArray = PackedByteArray()


func decode(source: PackedByteArray) -> bool:
	error_message = ""
	sample_rate = 0
	samples = PackedByteArray()
	if source.size() < 26 or source.slice(0, 20).get_string_from_ascii() != SIGNATURE:
		error_message = "VOC 文件头无效"
		return false
	var offset := PalBinary.u16_le(source, 20)
	if offset < 26 or offset >= source.size():
		error_message = "VOC 数据偏移无效"
		return false

	while offset < source.size():
		var block_type := source[offset]
		if block_type == 0:
			break
		if not PalBinary.can_read(source, offset, 4):
			error_message = "VOC 块头不完整"
			return false
		var block_length := source[offset + 1] | (source[offset + 2] << 8) | (source[offset + 3] << 16)
		if block_length < 0 or not PalBinary.can_read(source, offset + 4, block_length):
			error_message = "VOC 块数据越界"
			return false
		if block_type == 0x01:
			if block_length < 2 or source[offset + 5] != 0:
				error_message = "只支持 VOC 8-bit 单声道块"
				return false
			var time_constant := source[offset + 4]
			if time_constant >= 256:
				error_message = "VOC 采样率常量无效"
				return false
			sample_rate = int(round((1000000.0 / (256 - time_constant)) / 100.0)) * 100
			samples = source.slice(offset + 6, offset + 4 + block_length)
			return not samples.is_empty()
		offset += block_length + 4

	error_message = "VOC 中没有可播放的 type 01 块"
	return false


func to_wav() -> PackedByteArray:
	if samples.is_empty() or sample_rate <= 0:
		return PackedByteArray()
	var wav := PackedByteArray()
	var padding := samples.size() & 1
	wav.append_array("RIFF".to_ascii_buffer())
	PalBinary.append_u32_le(wav, 36 + samples.size() + padding)
	wav.append_array("WAVE".to_ascii_buffer())
	wav.append_array("fmt ".to_ascii_buffer())
	PalBinary.append_u32_le(wav, 16)
	PalBinary.append_u16_le(wav, 1) # PCM
	PalBinary.append_u16_le(wav, 1) # Mono
	PalBinary.append_u32_le(wav, sample_rate)
	PalBinary.append_u32_le(wav, sample_rate) # 8-bit mono byte rate
	PalBinary.append_u16_le(wav, 1)
	PalBinary.append_u16_le(wav, 8)
	wav.append_array("data".to_ascii_buffer())
	PalBinary.append_u32_le(wav, samples.size())
	wav.append_array(samples)
	if padding != 0:
		wav.append(0)
	return wav
