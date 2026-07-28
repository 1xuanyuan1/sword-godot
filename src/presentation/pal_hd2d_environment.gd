# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 私有高清包中单张地图环境场景的公开契约。
## 场景只描述展示节点和镜头，不拥有碰撞、入口、事件或剧情状态。
class_name PalHd2DEnvironment
extends Node3D

## 本场景局部原点对应的 PAL 世界脚底坐标。
@export var pal_anchor: Vector2i = Vector2i.ZERO
## 固定镜头相对共享快照焦点的位置。
@export var camera_offset: Vector3 = Vector3(10.5, 8.0, 12.0)
## 固定镜头注视点相对共享快照焦点的偏移。
@export var camera_look_offset: Vector3 = Vector3(0.0, 0.45, 0.0)
@export_range(18.0, 70.0, 0.1) var camera_fov: float = 32.0


## 把模块化场景局部原点对齐到共享 PAL→3D 坐标系。
func align_to_pal_world() -> void:
	position = PalWorldTransform.pal_to_world_3d(pal_anchor)
