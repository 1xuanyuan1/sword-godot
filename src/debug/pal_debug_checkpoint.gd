# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 剧情测试场景与探索场景之间的一次性内存检查点邮箱。
## 检查点只修改下一次临时 `GameSession`，不会创建或覆盖正式存档。
class_name PalDebugCheckpoint
extends RefCounted

static var _pending: Dictionary = {}


## 根据稳定检查点编号准备下一次探索参数；未知编号返回 `false`。
static func request(checkpoint_id: String) -> bool:
	match checkpoint_id:
		"wine_dish_toast":
			_pending = {"id": checkpoint_id, "scene": 0, "script": 4995, "event": 21, "position": Vector2i(656, 1144), "music": 31, "hint": "酒菜环境描述应显示为居中 Toast"}
		"meal_delivery":
			_pending = {"id": checkpoint_id, "scene": 0, "script": 4885, "event": 16, "position": Vector2i(1248, 1040), "player_sprite": 208, "music": 31}
		"drunken_swordsman":
			_pending = {"id": checkpoint_id, "scene": 2, "script": 5079, "event": 63, "position": Vector2i(1088, 1648), "inventory": {272: 1}}
		"wine_menu":
			_pending = {"id": checkpoint_id, "scene": 2, "script": 0, "event": 0, "position": Vector2i(1040, 1672), "direction": GameSession.DIR_SOUTH, "inventory": {272: 1}, "hint": "按 M 打开菜单，选择物品并使用桂花酒"}
		_:
			_pending = {}
			return false
	return true


## 取走并清空待处理检查点，保证一次请求不会重复应用。
static func consume() -> Dictionary:
	var result := _pending.duplicate(true)
	_pending = {}
	return result
