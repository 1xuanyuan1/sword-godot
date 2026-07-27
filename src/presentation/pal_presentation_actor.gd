# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 共享世界快照中的单个人物或 EventObject 展示状态。
## 本对象只保存一帧只读语义数据，不持有场景节点，也不修改 GameSession。
class_name PalPresentationActor
extends RefCounted

const KIND_PARTY := 0
const KIND_FOLLOWER := 1
const KIND_EVENT := 2

## 高清资源解析使用的稳定逻辑 ID。
var logical_id: String = ""
## 队员、跟随者或 EventObject 类型。
var kind: int = KIND_EVENT
## EventObject 全局编号；非事件人物为零。
var source_object_id: int = 0
## 当前 MGO Sprite 编号。
var sprite_number: int = 0
## PLAYERROLES 角色编号；非队员为 -1。
var role_index: int = -1
## 当前 PAL 世界脚底坐标。
var pal_world_position: Vector2i = Vector2i.ZERO
## 由 PalWorldTransform 统一换算的 Godot 3D 坐标。
var world_position_3d: Vector3 = Vector3.ZERO
## SDLPal 的南、西、北、东方向枚举。
var direction: int = 0
## 已经选定的当前 MGO 帧编号。
var frame_index: int = -1
## 传给经典 PalSceneLayout 的原始场景层。
var scene_layer: int = 0
## 排序和 3D 高度共用的归一化逻辑层。
var logical_layer: int = 0
## 当前对象是否应被表现层显示。
var visible: bool = true
## 是否属于当前玩家队伍。
var is_party_member: bool = false


## 返回跨渲染后端稳定的节点键。
func stable_key() -> String:
	return "%d:%d:%d:%d" % [kind, source_object_id, role_index, sprite_number]
