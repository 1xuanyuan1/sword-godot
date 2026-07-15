# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal sound.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 解码经典 Creative Voice VOC 的 8 位 PCM type 01 数据并封装成 WAV。
## 当前只覆盖目标 PAL 数据实际使用的格式，其他块会返回明确错误。
class_name VocDecoder
extends RefCounted

const SIGNATURE := "Creative Voice File\u001a"

## VOC 头、块类型或 PCM 参数错误。
var error_message: String = ""
## 从 VOC 时间常数换算出的采样率。
var sample_rate: int = 0
## 无符号 8 位单声道 PCM 样本。
var samples: PackedByteArray = PackedByteArray()


## 解码完整 VOC 文件；不支持或损坏时返回 `false` 并设置错误信息。
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


## 将已解码样本封装为 RIFF/WAVE 字节；没有有效样本时返回空数组。
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
