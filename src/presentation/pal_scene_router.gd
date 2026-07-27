# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 让经典场景在 1080p Presentation Shell 的 SubViewport 内切换，并保留无 Shell 测试回退。
class_name PalSceneRouter
extends RefCounted


## 从调用节点切换经典场景；存在 Shell 时替换其 SubViewport 内容，否则沿用 SceneTree。
static func change_scene(context: Node, scene_path: String) -> Error:
	var current := context
	while current != null:
		if current is PalPresentationShell:
			return current.open_classic_scene(scene_path)
		current = current.get_parent()
	var tree := context.get_tree() if context != null else Engine.get_main_loop() as SceneTree
	if tree == null:
		return ERR_UNCONFIGURED
	return tree.change_scene_to_file(scene_path)
