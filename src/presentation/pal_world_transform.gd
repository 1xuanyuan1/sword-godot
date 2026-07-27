# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## PAL 等距世界像素与 Godot 3D 地面坐标之间的唯一换算规则。
## X 轴表示东向，Z 轴表示北向；逻辑层只映射到 Y，不改变事件坐标。
class_name PalWorldTransform
extends RefCounted

const PAL_PIXELS_PER_WORLD_UNIT := 32.0
const LOGICAL_LAYER_PIXELS_PER_WORLD_UNIT := 16.0


## 把 PAL 世界脚底坐标和逻辑层转换为 Godot 3D 坐标。
static func pal_to_world_3d(pal_position: Vector2i, logical_layer: int = 0) -> Vector3:
	var east := (float(pal_position.x) + float(pal_position.y) * 2.0) / PAL_PIXELS_PER_WORLD_UNIT
	var north := (float(pal_position.x) - float(pal_position.y) * 2.0) / PAL_PIXELS_PER_WORLD_UNIT
	var height := float(logical_layer) / LOGICAL_LAYER_PIXELS_PER_WORLD_UNIT
	return Vector3(east, height, north)


## 把地面 X/Z 坐标逆变换为最近的 PAL 世界像素；Y 高度不参与事件坐标。
static func world_3d_to_pal(world_position: Vector3) -> Vector2i:
	return Vector2i(
		roundi((world_position.x + world_position.z) * 16.0),
		roundi((world_position.x - world_position.z) * 8.0)
	)


## 返回 PAL 视口中心在 3D 地面上的固定镜头焦点。
static func camera_focus(viewport_position: Vector2i, camera_offset: Vector2i = Vector2i.ZERO) -> Vector3:
	var pal_center := viewport_position + camera_offset + PalPresentationMetrics.CLASSIC_CONTENT_SIZE / 2
	return pal_to_world_3d(pal_center)
