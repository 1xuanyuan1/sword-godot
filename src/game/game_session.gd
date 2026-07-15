# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 一次新游戏或读档后的可变运行时状态。
## 内容定义来自 `PalContentDatabase`；本对象只保存队伍、位置、背包和场景进度。
class_name GameSession
extends RefCounted

const PARTY_OFFSET := Vector2i(160, 112)
const TRAIL_SIZE := 5
const DIR_SOUTH := 0
const DIR_WEST := 1
const DIR_NORTH := 2
const DIR_EAST := 3

## 从 0 开始的当前剧情场景索引。
var scene_index: int = 0
## 320×200 PAL 视口左上角的世界像素坐标。
var viewport_position: Vector2i = Vector2i.ZERO
## SDLPal 的南、西、北、东方向枚举。
var party_direction: int = 0
## 当前金钱。
var cash: int = 0
## PAT.MKF 调色板编号。
var palette_index: int = 0
## 是否使用同编号调色板的夜间部分。
var night_palette: bool = false
## 当前场景音乐编号。
var music_number: int = 0
## 下一场战斗使用的音乐编号。
var battle_music_number: int = 0
## 脚本设置的队伍逻辑高度，以像素为单位。
var world_layer: int = 0
## 当前队伍中的 PLAYERROLES 索引。
var party_roles: PackedInt32Array = PackedInt32Array([0])
## 脚本临时指定的绝对人物帧，-1 表示使用普通步态。
var party_script_frames: PackedInt32Array = PackedInt32Array([-1, -1, -1])
## 物品对象编号到数量的映射。
var inventory: Dictionary = {}
## SDLPal 五格队伍轨迹的世界位置。
var trail_positions: Array[Vector2i] = []
## 与队伍轨迹位置对应的方向。
var trail_directions: PackedInt32Array = PackedInt32Array()


#region Position and party trail

## 返回队长脚底的 PAL 世界像素坐标。
func party_world_position() -> Vector2i:
	return viewport_position + PARTY_OFFSET


## 把 PAL 方向枚举换算为一个 half 格的等距移动量。
static func movement_for_direction(direction: int) -> Vector2i:
	match direction:
		DIR_SOUTH:
			return Vector2i(-16, 8)
		DIR_WEST:
			return Vector2i(-16, -8)
		DIR_NORTH:
			return Vector2i(16, -8)
		DIR_EAST:
			return Vector2i(16, 8)
	return Vector2i.ZERO


## 直接设置队长世界位置，并以该位置重新初始化队伍轨迹。
func set_party_world_position(world_position: Vector2i) -> void:
	viewport_position = world_position - PARTY_OFFSET
	_initialize_trail(world_position)


## 记录队长一步移动，把旧位置和方向依次推入五格轨迹。
func record_party_step(direction: int, movement: Vector2i) -> void:
	clear_party_gestures()
	if trail_positions.size() != TRAIL_SIZE or trail_directions.size() != TRAIL_SIZE:
		_initialize_trail(party_world_position())
	for index in range(TRAIL_SIZE - 1, 0, -1):
		trail_positions[index] = trail_positions[index - 1]
		trail_directions[index] = trail_directions[index - 1]
	trail_positions[0] = party_world_position()
	trail_directions[0] = direction
	party_direction = direction
	viewport_position += movement


## 根据 SDLPal 编队偏移返回指定队员的世界位置。
func party_member_world_position(member_index: int) -> Vector2i:
	if member_index <= 0 or trail_positions.size() < 2:
		return party_world_position()
	var base := trail_positions[1]
	var direction := trail_directions[1]
	if member_index == 2:
		base.x += -16 if direction in [DIR_WEST, DIR_EAST] else 16
		base.y += 8
	else:
		base.x += 16 if direction in [DIR_SOUTH, DIR_WEST] else -16
		base.y += 8 if direction in [DIR_WEST, DIR_NORTH] else -8
	return base


## 返回跟随队员使用的历史方向。
func party_member_direction(member_index: int) -> int:
	if member_index <= 0 or trail_directions.size() < 3:
		return party_direction
	return trail_directions[2]


## 设置脚本动作帧；后续正常移动会清除该动作。
func set_party_gesture(direction: int, gesture: int, member_index: int) -> void:
	if member_index < 0:
		return
	while party_script_frames.size() <= member_index:
		party_script_frames.append(-1)
	party_direction = direction
	party_script_frames[member_index] = direction * 3 + gesture


## 返回脚本指定的绝对帧，未设置或越界时为 -1。
func scripted_party_frame(member_index: int) -> int:
	return party_script_frames[member_index] if member_index >= 0 and member_index < party_script_frames.size() else -1


## 清空所有队员的脚本动作帧。
func clear_party_gestures() -> void:
	party_script_frames.resize(maxi(3, party_roles.size()))
	party_script_frames.fill(-1)


#endregion

#region Inventory and lifecycle

## 返回指定物品数量，背包中不存在时为 0。
func item_count(item_id: int) -> int:
	return int(inventory.get(item_id, 0))


## 把物品数量设置为非负值；零会从稀疏背包字典移除。
func set_item_count(item_id: int, amount: int) -> void:
	if item_id <= 0:
		return
	if amount <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = amount


## 增减物品并返回实际变化量；数量不会低于零。
func change_item_count(item_id: int, amount: int) -> int:
	if item_id <= 0:
		return 0
	var previous := item_count(item_id)
	set_item_count(item_id, maxi(0, previous + amount))
	return item_count(item_id) - previous


## 恢复当前复刻阶段的新游戏默认状态，并初始化队伍轨迹。
func reset_new_game() -> void:
	scene_index = 0
	viewport_position = Vector2i.ZERO
	party_direction = 0
	cash = 0
	palette_index = 0
	night_palette = false
	music_number = 0
	battle_music_number = 0
	world_layer = 0
	party_roles = PackedInt32Array([0])
	inventory.clear()
	clear_party_gestures()
	_initialize_trail(party_world_position())

#endregion


func _initialize_trail(world_position: Vector2i) -> void:
	trail_positions.resize(TRAIL_SIZE)
	trail_directions.resize(TRAIL_SIZE)
	var backward := Vector2i(
		16 if party_direction in [DIR_SOUTH, DIR_WEST] else -16,
		8 if party_direction in [DIR_WEST, DIR_NORTH] else -8
	)
	for index in range(TRAIL_SIZE):
		trail_positions[index] = world_position + backward * index
		trail_directions[index] = party_direction
