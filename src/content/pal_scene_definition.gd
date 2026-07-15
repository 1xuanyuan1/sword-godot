# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h SCENE.
# SPDX-License-Identifier: GPL-3.0-or-later
## 一条 PAL 场景定义，保存地图编号、进入/传送脚本和事件对象区间起点。
## 对象来自 `SSS.MKF` 的 SCENE 结构，本身不持有玩家运行时状态。
class_name PalSceneDefinition
extends RefCounted

const BYTE_SIZE := 8

## 该剧情场景复用的 GOP/MAP 地图编号。
var map_number: int
## 进入场景时执行的脚本入口；一次性脚本完成后可能被运行时改写。
var script_on_enter: int
## 传送离开时执行的脚本入口。
var script_on_teleport: int
## 当前场景在全局 EVENTOBJECT 数组中的起始索引。
var event_object_index: int


## 从指定偏移解析 8 字节 SCENE；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int) -> PalSceneDefinition:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var scene := PalSceneDefinition.new()
	scene.map_number = PalBinary.u16_le(data, offset)
	scene.script_on_enter = PalBinary.u16_le(data, offset + 2)
	scene.script_on_teleport = PalBinary.u16_le(data, offset + 4)
	scene.event_object_index = PalBinary.u16_le(data, offset + 6)
	return scene
