# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal global.h EVENTOBJECT.
# SPDX-License-Identifier: GPL-3.0-or-later
## 场景中的 NPC、物件或触发点，对应 SDLPal 的 EVENTOBJECT 结构。
## 解析后对象会被 `ScriptVM` 原地修改，因此同时承载本次会话的事件状态。
class_name PalEventObject
extends RefCounted

const BYTE_SIZE := 32
const TRIGGER_SEARCH_NEAR := 1
const TRIGGER_TOUCH_NEAR := 4
const TRIGGER_TOUCH_NORMAL := 5
const TRIGGER_TOUCH_FAR := 6
const TRIGGER_TOUCH_FARTHER := 7
const TRIGGER_TOUCH_FARTHEST := 8

## 从 1 开始的全局事件对象编号，供脚本操作数引用。
var object_id: int = 0
## 临时消失或重现的原版计时字段。
var vanish_time: int
## PAL 世界像素坐标，不是 TileMap 单元坐标。
var position: Vector2i
## 逻辑高度层，影响人物遮挡与 Sprite 锚点。
var layer: int
## 搜索或接触时执行的脚本入口。
var trigger_script: int
## 每个脚本帧自动调度的入口。
var auto_script: int
## 可见、隐藏及阻挡语义使用的事件状态。
var state: int
## 搜索/接触触发模式及距离等级。
var trigger_mode: int
## `MGO.MKF` 中的场景 Sprite 编号。
var sprite_number: int
## 每个方向包含的动画帧数。
var sprite_frames: int
## SDLPal 的南、西、北、东方向枚举。
var direction: int
## 当前方向内的帧位置。
var current_frame: int
## 自动脚本等待帧计数。
var script_idle_frame: int
## 原版运行时 Sprite 指针偏移字段。
var sprite_pointer_offset: int
## 自动动画使用的帧数。
var sprite_frames_auto: int
## 自动脚本空闲计数。
var auto_script_idle_count: int


## 从指定偏移解析 EVENTOBJECT；范围不足时返回 `null`。
static func from_bytes(data: PackedByteArray, offset: int) -> PalEventObject:
	if not PalBinary.can_read(data, offset, BYTE_SIZE):
		return null
	var event := PalEventObject.new()
	event.vanish_time = PalBinary.i16_le(data, offset)
	event.position = Vector2i(PalBinary.u16_le(data, offset + 2), PalBinary.u16_le(data, offset + 4))
	event.layer = PalBinary.i16_le(data, offset + 6)
	event.trigger_script = PalBinary.u16_le(data, offset + 8)
	event.auto_script = PalBinary.u16_le(data, offset + 10)
	event.state = PalBinary.i16_le(data, offset + 12)
	event.trigger_mode = PalBinary.u16_le(data, offset + 14)
	event.sprite_number = PalBinary.u16_le(data, offset + 16)
	event.sprite_frames = PalBinary.u16_le(data, offset + 18)
	event.direction = PalBinary.u16_le(data, offset + 20)
	event.current_frame = PalBinary.u16_le(data, offset + 22)
	event.script_idle_frame = PalBinary.u16_le(data, offset + 24)
	event.sprite_pointer_offset = PalBinary.u16_le(data, offset + 26)
	event.sprite_frames_auto = PalBinary.u16_le(data, offset + 28)
	event.auto_script_idle_count = PalBinary.u16_le(data, offset + 30)
	return event


## 当前状态是否允许对象显示和参与事件。
func is_visible() -> bool:
	return state > 0 and vanish_time == 0


## 当前对象是否阻挡队伍 half 格移动。
func blocks_movement() -> bool:
	return state >= 2


## 是否需要玩家按空格/回车搜索触发。
func is_search_trigger() -> bool:
	return trigger_mode >= TRIGGER_SEARCH_NEAR and trigger_mode < TRIGGER_TOUCH_NEAR


## 返回手动搜索可检查的 13 点序列长度上限。
## 模式 1/2/3 分别允许索引 0–1、0–7、0–12，对应 SDLPal `mode * 6 - 4`。
func search_trigger_checkpoint_count() -> int:
	return mini(13, trigger_mode * 6 - 4) if is_search_trigger() else 0


## 是否在队伍接近后自动触发。
func is_touch_trigger() -> bool:
	return trigger_mode >= TRIGGER_TOUCH_NEAR and trigger_mode <= TRIGGER_TOUCH_FARTHEST


## 将原版触发模式 4–8 换算成 PAL 世界像素距离。
func touch_trigger_distance() -> int:
	return (trigger_mode - TRIGGER_TOUCH_NEAR) * 32 + 16 if is_touch_trigger() else 0
