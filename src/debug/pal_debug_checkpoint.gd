# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 剧情测试场景与探索场景之间的一次性内存检查点邮箱。
## 检查点只修改下一次临时 `GameSession`，不会创建或覆盖正式存档。
class_name PalDebugCheckpoint
extends RefCounted

static var _pending: Dictionary = {}

const INN_SCENE_INDEX := 0
const INN_STABLE_INTRO_ENTRY := 8145
const POST_MEDICINE_INN_ENTRY := 6225
const INN_STAIRS_EVENT_ID := 4
const AUNT_EXIT_EVENT_ID := 11
const AUNT_WAKE_POSE_EVENT_ID := 12


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
		"fairy_island_boat":
			# 首次赴岛前的原版剧情状态：开场客栈已经完成，张四已移到码头，
			# 并准备执行乘船脚本 0x16F9。检查点可能被继续试玩，因此不能只补船只。
			_pending = {
				"id": checkpoint_id,
				"scene": 4,
				"script": 0,
				"event": 0,
				"position": Vector2i(1136, 1368),
				"direction": GameSession.DIR_EAST,
				"music": 87,
				"scene_enter_scripts": {0: INN_STABLE_INTRO_ENTRY, 4: 0x14c7},
				"event_overrides": {
					# 开场李大娘离开房间后的楼梯、普通行走对象和叫醒专用姿势。
					4: {"state": 1},
					11: {"position": Vector2i(1152, 384), "auto_script": 4458, "state": 0, "direction": GameSession.DIR_SOUTH},
					12: {"state": 0},
					25: {"trigger_script": 0x15cb},
					60: {"auto_script": 0x15d0, "trigger_mode": 2},
					124: {"position": Vector2i(1152, 1376), "trigger_script": 0x16f9, "direction": GameSession.DIR_EAST},
					125: {"trigger_script": 0x1755},
				},
				"hint": "向右面对张四并按空格，验证上船移动与后续剧情",
			}
		"fairy_island_bath":
			# 从发现衣服前的镜头移动开始，覆盖两次 0050 渐隐、花树下洗澡画面、
			# 上岸发现衣服不见以及李逍遥用树枝晃衣服的完整过场。
			_pending = {
				"id": checkpoint_id,
				"scene": 13,
				"script": 9649,
				"event": 204,
				"position": Vector2i(1104, 1432),
				"music": 61,
				"hint": "验证花树背景、洗澡画面与晃衣服动作不再异常黑屏",
			}
		_:
			_pending = {}
			return false
	return true


## 修复旧版“码头乘船”检查点继续游玩后保存的客栈开场残留状态。
## 仅在喂药剧情已稳定结束且三个 EventObject 仍精确保持开场默认组合时修改数据库；正常主线返回 `false`。
static func repair_legacy_checkpoint_runtime(database: PalContentDatabase) -> bool:
	if database == null or database.scenes.size() <= INN_SCENE_INDEX or database.event_objects.size() < AUNT_WAKE_POSE_EVENT_ID:
		return false
	if database.scenes[INN_SCENE_INDEX].script_on_enter != POST_MEDICINE_INN_ENTRY:
		return false
	var stairs: PalEventObject = database.event_objects[INN_STAIRS_EVENT_ID - 1]
	var aunt_exit: PalEventObject = database.event_objects[AUNT_EXIT_EVENT_ID - 1]
	var aunt_wake_pose: PalEventObject = database.event_objects[AUNT_WAKE_POSE_EVENT_ID - 1]
	var matches_incomplete_checkpoint := (
		stairs.state == 0
		and stairs.trigger_script == 4475
		and aunt_exit.position == Vector2i(1328, 296)
		and aunt_exit.auto_script == 4455
		and aunt_exit.state == 0
		and aunt_exit.sprite_number == 21
		and aunt_wake_pose.state == 1
		and aunt_wake_pose.sprite_number == 628
	)
	if not matches_incomplete_checkpoint:
		return false
	stairs.state = 1
	aunt_exit.position = Vector2i(1152, 384)
	aunt_exit.auto_script = 4458
	aunt_exit.direction = GameSession.DIR_SOUTH
	aunt_wake_pose.state = 0
	return true


## 取走并清空待处理检查点，保证一次请求不会重复应用。
static func consume() -> Dictionary:
	var result := _pending.duplicate(true)
	_pending = {}
	return result
