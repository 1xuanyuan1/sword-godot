# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 把角色当前毒与九种经典状态整理成战斗、场外界面共用的只读展示项。
## 战斗规则仍由 GameSession / PalBattleController 持有，本对象不修改任何状态。
class_name PalRoleConditionDisplay
extends RefCounted

const KIND_POISON := "poison"
const KIND_STATUS := "status"

const ICON_SIZE := 16
const ICON_COUNT := 10
const ICON_ATLAS: Texture2D = preload("res://assets/ui/status_condition_icons.png")

const NEGATIVE_STATUS_COLOR := 0x1b
const POSITIVE_STATUS_COLOR := 0x3c
const STATUS_NAMES := ["混乱", "定身", "昏睡", "封咒", "傀儡", "勇气", "防护", "加速", "双击"]
const STATUS_COMPACT_NAMES := ["乱", "定", "眠", "封", "傀", "勇", "护", "速", "双"]


## 返回指定角色当前应显示的状态。毒按对象编号稳定排序，99 级装备内部效果不冒充中毒。
## 毒排在状态前，保证战斗状态框空间不足时仍优先提示需要解毒的原因。
static func entries_for_role(session: GameSession, database: PalContentDatabase, role_index: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if session == null or database == null or role_index < 0:
		return entries
	var poison_ids: Array[int] = []
	if role_index < session.role_poisons_by_role.size():
		for raw_poison_id in session.role_poisons_by_role[role_index].keys():
			var poison_id := int(raw_poison_id)
			var poison := database.poison_definition(poison_id)
			if poison != null and poison.poison_level < 99:
				poison_ids.append(poison_id)
	poison_ids.sort()
	for poison_id in poison_ids:
		var poison := database.poison_definition(poison_id)
		var poison_name := database.get_word(poison_id)
		if poison_name.is_empty():
			poison_name = "中毒"
		entries.append({
			"kind": KIND_POISON,
			"id": poison_id,
			"icon_index": 0,
			"name": poison_name,
			"compact_name": _compact_poison_name(poison_name),
			"rounds": 0,
			"color_index": poison.color + 10,
			"negative": true,
		})
	for status_id in range(mini(GameSession.STATUS_COUNT, STATUS_NAMES.size())):
		var rounds := session.status_rounds_for(role_index, status_id)
		if rounds <= 0:
			continue
		var negative := status_id <= GameSession.STATUS_PUPPET
		entries.append({
			"kind": KIND_STATUS,
			"id": status_id,
			"icon_index": status_id + 1,
			"name": STATUS_NAMES[status_id],
			"compact_name": STATUS_COMPACT_NAMES[status_id],
			"rounds": rounds,
			"color_index": NEGATIVE_STATUS_COLOR if negative else POSITIVE_STATUS_COLOR,
			"negative": negative,
		})
	return entries


## 场外状态页使用完整名称；普通临时状态附带剩余回合，装备持久状态不显示巨大时长。
static func detailed_text(entry: Dictionary) -> String:
	var name := str(entry.get("name", ""))
	var rounds := int(entry.get("rounds", 0))
	return "%s%d" % [name, rounds] if rounds > 0 and rounds <= 999 else name


## 战斗状态框使用单字状态名和剩余回合；毒保留可辨认的对象名称。
static func compact_text(entry: Dictionary) -> String:
	var name := str(entry.get("compact_name", entry.get("name", "")))
	var rounds := int(entry.get("rounds", 0))
	return "%s%d" % [name, rounds] if rounds > 0 and rounds <= 99 else name


static func _compact_poison_name(poison_name: String) -> String:
	if poison_name.length() <= 4:
		return poison_name
	return poison_name.substr(0, 3) + "毒"
