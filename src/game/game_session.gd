# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 一次新游戏或读档后的可变运行时状态。
## 内容定义来自 `PalContentDatabase`；本对象只保存队伍、位置、背包和场景进度。
class_name GameSession
extends RefCounted

const PARTY_OFFSET := Vector2i(160, 112)
const TRAIL_SIZE := 5
const AUDIO_VOLUME_MAX := 100
const EQUIPMENT_SLOT_COUNT := PalPlayerRoles.EQUIPMENT_SLOT_COUNT
const EQUIPMENT_EFFECT_SLOT_COUNT := EQUIPMENT_SLOT_COUNT + 1
const EQUIPMENT_EFFECT_BATTLE_SPRITE := 1
const EQUIPMENT_EFFECT_ATTACK_ALL := 4
const EQUIPMENT_EFFECT_ATTACK := 17
const EQUIPMENT_EFFECT_MAGIC := 18
const EQUIPMENT_EFFECT_DEFENSE := 19
const EQUIPMENT_EFFECT_DEXTERITY := 20
const EQUIPMENT_EFFECT_FLEE := 21
const EQUIPMENT_EFFECT_POISON_RESISTANCE := 22
const EQUIPMENT_EFFECT_ELEMENT_FIRST := 23
const EQUIPMENT_EFFECT_COOPERATIVE_MAGIC := 65
const DIR_SOUTH := 0
const DIR_WEST := 1
const DIR_NORTH := 2
const DIR_EAST := 3
const STATUS_CONFUSED := 0
const STATUS_PARALYZED := 1
const STATUS_SLEEP := 2
const STATUS_SILENCE := 3
const STATUS_PUPPET := 4
const STATUS_BRAVERY := 5
const STATUS_PROTECT := 6
const STATUS_HASTE := 7
const STATUS_DUAL_ATTACK := 8
const STATUS_COUNT := 9
const MAX_POISONS := 16

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
## `004A` 设置的当前战场背景与五灵修正编号。
var battlefield_number: int = 0
## 背景音乐音量百分比，范围 0–100；新游戏默认 100。
var music_volume: int = AUDIO_VOLUME_MAX
## 音效音量百分比，范围 0–100；新游戏默认 100。
var sound_volume: int = AUDIO_VOLUME_MAX
## 脚本设置的队伍逻辑高度，以像素为单位。
var world_layer: int = 0
## 当前队伍中的 PLAYERROLES 索引。
var party_roles: PackedInt32Array = PackedInt32Array([0])
## `0098` 设置的最多两名跟随者 MGO Sprite 编号；原版操作数不是 PLAYERROLES 索引。
var follower_sprite_numbers: PackedInt32Array = PackedInt32Array()
## 收妖类仙术积累的炼物值。
var collect_value: int = 0
## `0062/0063` 修改追逐范围的剩余场景更新周期。
var chase_speed_change_cycles: int = 0
## 临时追逐范围倍率：0 暂停、1 普通、3 加速。
var chase_range_multiplier: int = 1
## `008A` 只为紧随其后的战斗启用自动指令；战斗开始后立即消费。
var auto_battle_pending: bool = false
## 脚本临时指定的绝对人物帧，-1 表示使用普通步态。
var party_script_frames: PackedInt32Array = PackedInt32Array([-1, -1, -1])
## 物品对象编号到数量的映射。
var inventory: Dictionary = {}
## 每名角色当前等级；索引与 PLAYERROLES 一致。
var role_levels: PackedInt32Array = PackedInt32Array()
## 每名角色最大体力。
var role_max_hp: PackedInt32Array = PackedInt32Array()
## 每名角色最大真气。
var role_max_mp: PackedInt32Array = PackedInt32Array()
## 每名角色当前体力。
var role_hp: PackedInt32Array = PackedInt32Array()
## 每名角色当前真气。
var role_mp: PackedInt32Array = PackedInt32Array()
## 每名角色当前等级内尚未消耗的主经验。
var role_experience: PackedInt32Array = PackedInt32Array()
## 每名角色当前基础攻击力；升级会修改本数组，不改写只读 PLAYERROLES。
var role_attack_strength: PackedInt32Array = PackedInt32Array()
## 每名角色当前基础灵力。
var role_magic_strength: PackedInt32Array = PackedInt32Array()
## 每名角色当前基础防御。
var role_defense: PackedInt32Array = PackedInt32Array()
## 每名角色当前基础身法。
var role_dexterity: PackedInt32Array = PackedInt32Array()
## 每名角色当前基础逃跑值。
var role_flee_rate: PackedInt32Array = PackedInt32Array()
## 每名角色六个装备槽中的物品对象编号；外层索引与 PLAYERROLES 一致。
var role_equipments_by_role: Array[PackedInt32Array] = []
## 七个官方装备效果槽（六个部位加临时槽）的稀疏属性表。
## 每个字典以 PLAYERROLES 字段组编号为键，以六名角色的 16 位 WORD 值为值。
var equipment_effects_by_slot: Array[Dictionary] = []
## 装备脚本 `002D` 写入的持久状态；当前主要用于武器双击效果。
var equipment_statuses_by_slot: Array[Dictionary] = []
## 装备管理器是否已按当前装备完整重建脚本效果。
var equipment_effects_ready: bool = false
## 每名角色的基础毒抗性。
var role_poison_resistance: PackedInt32Array = PackedInt32Array()
## 每名角色的基础五灵抗性；装备加成另存于效果槽。
var role_elemental_resistances_by_role: Array[PackedInt32Array] = []
## 每名角色九种经典战斗状态的剩余回合数；大于 999 的装备效果不会被解咒清除。
var role_status_rounds_by_role: Array[PackedInt32Array] = []
## 每名角色当前毒对象编号到递进脚本游标的映射，最多同时保存 16 种毒。
var role_poisons_by_role: Array[Dictionary] = []
## 每名角色已学会的仙术对象编号。
var learned_magics_by_role: Array[PackedInt32Array] = []
## SDLPal 五格队伍轨迹的世界位置。
var trail_positions: Array[Vector2i] = []
## 与队伍轨迹位置对应的方向。
var trail_directions: PackedInt32Array = PackedInt32Array()
## `00A1` 是否把所有队员临时收拢到队长位置；下一次正常移动后恢复编队。
var party_formation_collapsed: bool = false


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
	party_formation_collapsed = false
	if trail_positions.size() != TRAIL_SIZE or trail_directions.size() != TRAIL_SIZE:
		_initialize_trail(party_world_position())
	for index in range(TRAIL_SIZE - 1, 0, -1):
		trail_positions[index] = trail_positions[index - 1]
		trail_directions[index] = trail_directions[index - 1]
	trail_positions[0] = party_world_position()
	trail_directions[0] = direction
	party_direction = direction
	viewport_position += movement


## 因阻挡型 EventObject 挤占队伍位置而平移视口，但不写入主动行走轨迹。
## `movement` 是一个 PAL half 格偏移；会清除动作和收拢状态，但保持队伍朝向。
func displace_party_from_blocker(movement: Vector2i) -> void:
	clear_party_gestures()
	party_formation_collapsed = false
	viewport_position += movement


## 根据 SDLPal 编队偏移返回指定队员的世界位置。
func party_member_world_position(member_index: int) -> Vector2i:
	if member_index <= 0 or trail_positions.size() < 2:
		return party_world_position()
	if party_formation_collapsed:
		return party_world_position() + Vector2i(0, -1)
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
	if party_formation_collapsed:
		return party_direction
	return trail_directions[2]


## 将所有队员和轨迹临时收拢到队长位置，对应 SDLPal 操作码 `00A1`。
## 下一次 `record_party_step()` 会自动恢复普通跟随编队。
func collapse_party_formation() -> void:
	var leader := party_world_position()
	trail_positions.resize(TRAIL_SIZE)
	trail_directions.resize(TRAIL_SIZE)
	for index in range(TRAIL_SIZE):
		trail_positions[index] = leader
		trail_directions[index] = party_direction
	party_formation_collapsed = true
	clear_party_gestures()


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


## 清除指定角色在当前队伍中的脚本动作帧，未入队时不修改状态。
## 场景 Sprite 切换后调用此方法，避免旧造型的绝对帧被错误套到新造型。
func clear_party_gestures_for_role(role_index: int) -> void:
	for member_index in range(party_roles.size()):
		if party_roles[member_index] == role_index and member_index < party_script_frames.size():
			party_script_frames[member_index] = -1


## 清空所有队员的脚本动作帧。
func clear_party_gestures() -> void:
	party_script_frames.resize(maxi(3, party_roles.size()))
	party_script_frames.fill(-1)


#endregion

#region Role state, inventory and lifecycle

## 从只读 PLAYERROLES 内容建立新游戏角色数值和初始仙术。
## 已初始化的会话不会被重复覆盖；`reset_new_game()` 后可重新调用。
func initialize_role_state(roles: PalPlayerRoles) -> bool:
	if roles == null or not roles.is_valid():
		return false
	if role_hp.size() == PalPlayerRoles.ROLE_COUNT and role_experience.size() == PalPlayerRoles.ROLE_COUNT and role_attack_strength.size() == PalPlayerRoles.ROLE_COUNT and role_equipments_by_role.size() == PalPlayerRoles.ROLE_COUNT and learned_magics_by_role.size() == PalPlayerRoles.ROLE_COUNT:
		_ensure_role_conditions()
		return true
	role_levels = roles.levels.duplicate()
	role_max_hp = roles.max_hp.duplicate()
	role_max_mp = roles.max_mp.duplicate()
	role_hp = roles.hp.duplicate()
	role_mp = roles.mp.duplicate()
	role_experience.resize(PalPlayerRoles.ROLE_COUNT)
	role_experience.fill(0)
	role_attack_strength = roles.attack_strengths.duplicate()
	role_magic_strength = roles.magic_strengths.duplicate()
	role_defense = roles.defenses.duplicate()
	role_dexterity = roles.dexterities.duplicate()
	role_flee_rate = roles.flee_rates.duplicate()
	role_equipments_by_role.clear()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		role_equipments_by_role.append(roles.equipments_for(role_index))
	role_poison_resistance = roles.poison_resistances.duplicate()
	role_elemental_resistances_by_role.clear()
	for elemental_resistances in roles.elemental_resistances_by_role:
		role_elemental_resistances_by_role.append(elemental_resistances.duplicate())
	_reset_equipment_effect_storage()
	learned_magics_by_role.clear()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		learned_magics_by_role.append(roles.magics_for(role_index))
	_ensure_role_conditions()
	return true


## 同时增减一名角色的体力和真气，并限制在 0 到最大值。
## 角色状态尚未初始化或索引越界时返回 `false`。
func increase_role_hp_mp(role_index: int, hp_delta: int, mp_delta: int) -> bool:
	if role_index < 0 or role_index >= role_hp.size() or role_index >= role_mp.size():
		return false
	var old_hp := role_hp[role_index]
	var old_mp := role_mp[role_index]
	role_hp[role_index] = clampi(old_hp + hp_delta, 0, role_max_hp[role_index])
	role_mp[role_index] = clampi(old_mp + mp_delta, 0, role_max_mp[role_index])
	return role_hp[role_index] != old_hp or role_mp[role_index] != old_mp


## 按最大 HP 的十分比复活一名倒下角色，并清除三级以下毒与临时状态。
## 角色仍存活、索引无效或内容数据库缺失时返回 `false`，且不修改状态。
func revive_role(role_index: int, tenths_of_max_hp: int, database: PalContentDatabase) -> bool:
	if role_index < 0 or role_index >= role_hp.size() or role_index >= role_max_hp.size() or database == null or role_hp[role_index] > 0:
		return false
	var restored_hp := int(role_max_hp[role_index] * tenths_of_max_hp / 10.0)
	role_hp[role_index] = mini(role_max_hp[role_index], maxi(0, restored_hp))
	cure_role_poisons_by_level(role_index, 3, database)
	for status_id in range(STATUS_COUNT):
		remove_role_status(role_index, status_id)
	return true


## 为指定角色加入一个仙术对象；已学会时保持不变并返回 `false`。
func add_magic(role_index: int, magic_id: int) -> bool:
	if role_index < 0 or role_index >= learned_magics_by_role.size() or magic_id <= 0:
		return false
	var magics := learned_magics_by_role[role_index]
	if magic_id in magics or magics.size() >= PalPlayerRoles.MAGIC_SLOT_COUNT:
		return false
	magics.append(magic_id)
	learned_magics_by_role[role_index] = magics
	return true


## 移除指定角色已经学会的仙术对象；未学会或索引无效时返回 `false`。
func remove_magic(role_index: int, magic_id: int) -> bool:
	if role_index < 0 or role_index >= learned_magics_by_role.size() or magic_id <= 0:
		return false
	var magics := learned_magics_by_role[role_index]
	var magic_index := magics.find(magic_id)
	if magic_index < 0:
		return false
	magics.remove_at(magic_index)
	learned_magics_by_role[role_index] = magics
	return true


## 按 PLAYERROLES 字段组编号增减一名角色的基础属性，对应 `0019`。
## 官方在 WORD 上叠加有符号增量，因此结果保留 16 位回绕语义。
func change_role_attribute(group_index: int, role_index: int, delta: int) -> bool:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return false
	var target: PackedInt32Array
	match group_index:
		6:
			target = role_levels
		7:
			target = role_max_hp
		8:
			target = role_max_mp
		9:
			target = role_hp
		10:
			target = role_mp
		17:
			target = role_attack_strength
		18:
			target = role_magic_strength
		19:
			target = role_defense
		20:
			target = role_dexterity
		21:
			target = role_flee_rate
		_:
			return false
	if role_index >= target.size():
		return false
	target[role_index] = (target[role_index] + delta) & 0xffff
	return true


## 按 PLAYERROLES 字段组直接设置基础属性，对应非装备上下文中的 001A。
func set_role_attribute(group_index: int, role_index: int, value: int) -> bool:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return false
	var target: PackedInt32Array
	match group_index:
		6:
			target = role_levels
		7:
			target = role_max_hp
		8:
			target = role_max_mp
		9:
			target = role_hp
		10:
			target = role_mp
		17:
			target = role_attack_strength
		18:
			target = role_magic_strength
		19:
			target = role_defense
		20:
			target = role_dexterity
		21:
			target = role_flee_rate
		_:
			return false
	if role_index >= target.size():
		return false
	target[role_index] = value & 0xffff
	return true


## 按官方随机成长直接提升剧情等级；默认清空该角色的主经验。
func level_up_role(role_index: int, level_count: int, random_int: Callable = Callable(), reset_experience: bool = true) -> bool:
	if role_index < 0 or role_index >= role_levels.size() or level_count <= 0:
		return false
	if role_index >= role_max_hp.size() or role_index >= role_max_mp.size() or role_index >= role_attack_strength.size() or role_index >= role_magic_strength.size() or role_index >= role_defense.size() or role_index >= role_dexterity.size() or role_index >= role_flee_rate.size():
		return false
	role_levels[role_index] = mini(PalLevelProgression.MAX_LEVEL, role_levels[role_index] + level_count)
	for _level in range(level_count):
		role_max_hp[role_index] = mini(999, role_max_hp[role_index] + 10 + _level_random_int(random_int, 0, 7))
		role_max_mp[role_index] = mini(999, role_max_mp[role_index] + 8 + _level_random_int(random_int, 0, 5))
		role_attack_strength[role_index] = mini(999, role_attack_strength[role_index] + 4 + _level_random_int(random_int, 0, 1))
		role_magic_strength[role_index] = mini(999, role_magic_strength[role_index] + 4 + _level_random_int(random_int, 0, 1))
		role_defense[role_index] = mini(999, role_defense[role_index] + 2 + _level_random_int(random_int, 0, 1))
		role_dexterity[role_index] = mini(999, role_dexterity[role_index] + 2 + _level_random_int(random_int, 0, 1))
		role_flee_rate[role_index] = mini(999, role_flee_rate[role_index] + 2)
	if reset_experience and role_index < role_experience.size():
		role_experience[role_index] = 0
	return true


## 返回当前队伍是否全部满血；空队伍或角色状态越界时返回 `false`。
func is_party_full_hp() -> bool:
	if party_roles.is_empty():
		return false
	for role_index in party_roles:
		if role_index < 0 or role_index >= role_hp.size() or role_index >= role_max_hp.size() or role_hp[role_index] < role_max_hp[role_index]:
			return false
	return true


## 返回指定角色是否已经学会该仙术对象。
func has_magic(role_index: int, magic_id: int) -> bool:
	return role_index >= 0 and role_index < learned_magics_by_role.size() and magic_id in learned_magics_by_role[role_index]


## 返回角色当前攻击力；状态未初始化或编号越界时返回 0。
func attack_strength_for(role_index: int) -> int:
	return _stat_with_equipment(role_attack_strength, role_index, EQUIPMENT_EFFECT_ATTACK)


## 返回角色当前灵力；状态未初始化或编号越界时返回 0。
func magic_strength_for(role_index: int) -> int:
	return _stat_with_equipment(role_magic_strength, role_index, EQUIPMENT_EFFECT_MAGIC)


## 返回角色当前防御；状态未初始化或编号越界时返回 0。
func defense_for(role_index: int) -> int:
	return _stat_with_equipment(role_defense, role_index, EQUIPMENT_EFFECT_DEFENSE)


## 返回角色当前身法；状态未初始化或编号越界时返回 0。
func dexterity_for(role_index: int) -> int:
	return _stat_with_equipment(role_dexterity, role_index, EQUIPMENT_EFFECT_DEXTERITY)


## 返回角色当前逃跑值；状态未初始化或编号越界时返回 0。
func flee_rate_for(role_index: int) -> int:
	return _stat_with_equipment(role_flee_rate, role_index, EQUIPMENT_EFFECT_FLEE)


## 返回角色六个当前装备对象编号的副本；角色越界时返回空数组。
func equipment_for_role(role_index: int) -> PackedInt32Array:
	return role_equipments_by_role[role_index].duplicate() if role_index >= 0 and role_index < role_equipments_by_role.size() else PackedInt32Array()


## 返回指定角色和部位的装备对象编号；任一索引越界时返回 0。
func equipped_item(role_index: int, slot_index: int) -> int:
	if role_index < 0 or role_index >= role_equipments_by_role.size():
		return 0
	var equipments := role_equipments_by_role[role_index]
	return equipments[slot_index] if slot_index >= 0 and slot_index < equipments.size() else 0


## 统计当前队伍装备槽中指定对象的数量；只用于原版会把已装备物品也计入的剧情移除操作。
func equipped_item_count(item_id: int) -> int:
	if item_id <= 0:
		return 0
	var count := 0
	for role_index in party_roles:
		if role_index < 0 or role_index >= role_equipments_by_role.size():
			continue
		for equipped_id in role_equipments_by_role[role_index]:
			if equipped_id == item_id:
				count += 1
	return count


## 替换指定装备槽并返回旧对象编号；索引无效时不修改状态并返回 0。
func replace_equipped_item(role_index: int, slot_index: int, item_id: int) -> int:
	if role_index < 0 or role_index >= role_equipments_by_role.size():
		return 0
	var equipments := role_equipments_by_role[role_index]
	if slot_index < 0 or slot_index >= equipments.size():
		return 0
	var previous := equipments[slot_index]
	equipments[slot_index] = maxi(0, item_id)
	role_equipments_by_role[role_index] = equipments
	return previous


## 清除一个角色在指定装备效果槽中的全部属性和装备状态。
func clear_equipment_effects(role_index: int, slot_index: int) -> void:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT or slot_index < 0 or slot_index >= equipment_effects_by_slot.size():
		return
	var effects := equipment_effects_by_slot[slot_index]
	for group_key in effects.keys():
		var values: PackedInt32Array = effects[group_key]
		if role_index < values.size():
			values[role_index] = 0
			effects[group_key] = values
	equipment_effects_by_slot[slot_index] = effects
	var statuses := equipment_statuses_by_slot[slot_index]
	for status_key in statuses.keys():
		var durations: PackedInt32Array = statuses[status_key]
		if role_index < durations.size():
			durations[role_index] = 0
			statuses[status_key] = durations
	equipment_statuses_by_slot[slot_index] = statuses


## 清空全部装备脚本效果，但保留六名角色当前穿戴的对象编号。
func clear_all_equipment_effects() -> void:
	_reset_equipment_effect_storage()


## 将装备效果写入指定槽、属性组和角色；值按 SDLPal 的无符号 16 位 WORD 保存。
func set_equipment_effect(slot_index: int, group_index: int, role_index: int, value: int) -> bool:
	if slot_index < 0 or slot_index >= equipment_effects_by_slot.size() or group_index < 0 or role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return false
	var effects := equipment_effects_by_slot[slot_index]
	var values: PackedInt32Array = effects.get(group_index, PackedInt32Array())
	if values.size() != PalPlayerRoles.ROLE_COUNT:
		values.resize(PalPlayerRoles.ROLE_COUNT)
		values.fill(0)
	values[role_index] = value & 0xffff
	effects[group_index] = values
	equipment_effects_by_slot[slot_index] = effects
	return true


## 返回指定角色在全部装备效果槽中的某一属性总和，结果保留 WORD 回绕语义。
func equipment_effect_total(role_index: int, group_index: int) -> int:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return 0
	var total := 0
	for effects in equipment_effects_by_slot:
		var values: PackedInt32Array = effects.get(group_index, PackedInt32Array())
		if role_index < values.size():
			total = (total + values[role_index]) & 0xffff
	return total


## 将装备脚本状态写入指定槽；持续值为零时表示该状态无效。
func set_equipment_status(slot_index: int, status_index: int, role_index: int, duration: int) -> bool:
	if slot_index < 0 or slot_index >= equipment_statuses_by_slot.size() or status_index < 0 or role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return false
	var statuses := equipment_statuses_by_slot[slot_index]
	var durations: PackedInt32Array = statuses.get(status_index, PackedInt32Array())
	if durations.size() != PalPlayerRoles.ROLE_COUNT:
		durations.resize(PalPlayerRoles.ROLE_COUNT)
		durations.fill(0)
	durations[role_index] = duration & 0xffff
	statuses[status_index] = durations
	equipment_statuses_by_slot[slot_index] = statuses
	return true


## 返回角色是否由任一装备槽维持指定状态。
func has_equipment_status(role_index: int, status_index: int) -> bool:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return false
	for statuses in equipment_statuses_by_slot:
		var durations: PackedInt32Array = statuses.get(status_index, PackedInt32Array())
		if role_index < durations.size() and durations[role_index] != 0:
			return true
	return false


## 返回角色是否因基础字段或装备效果能够普通攻击全体敌人。
func can_attack_all(role_index: int, roles: PalPlayerRoles) -> bool:
	var base_attack_all := roles != null and role_index >= 0 and role_index < roles.attack_all.size() and roles.attack_all[role_index] != 0
	return base_attack_all or equipment_effect_total(role_index, EQUIPMENT_EFFECT_ATTACK_ALL) != 0


## 返回应用装备覆盖后的战斗 Sprite 编号；没有覆盖时保留 `base_sprite`。
func battle_sprite_for(role_index: int, base_sprite: int) -> int:
	var result := base_sprite
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return result
	for effects in equipment_effects_by_slot:
		var values: PackedInt32Array = effects.get(EQUIPMENT_EFFECT_BATTLE_SPRITE, PackedInt32Array())
		if role_index < values.size() and values[role_index] != 0:
			result = values[role_index]
	return result


## 返回应用装备覆盖后的角色合击仙术对象编号；没有覆盖时读取 PLAYERROLES 基础字段。
func cooperative_magic_for(role_index: int, roles: PalPlayerRoles) -> int:
	var result := roles.cooperative_magic_for(role_index) if roles != null else 0
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return result
	for effects in equipment_effects_by_slot:
		var values: PackedInt32Array = effects.get(EQUIPMENT_EFFECT_COOPERATIVE_MAGIC, PackedInt32Array())
		if role_index < values.size() and values[role_index] != 0:
			result = values[role_index]
	return result


## 返回装备后的毒抗性，按官方规则最高限制为 100。
func poison_resistance_for(role_index: int) -> int:
	return mini(100, _stat_with_equipment(role_poison_resistance, role_index, EQUIPMENT_EFFECT_POISON_RESISTANCE))


## 返回装备后的指定五灵抗性，角色或属性越界时返回 0，最高限制为 100。
func elemental_resistance_for(role_index: int, element_index: int) -> int:
	if role_index < 0 or role_index >= role_elemental_resistances_by_role.size():
		return 0
	var resistances := role_elemental_resistances_by_role[role_index]
	if element_index < 0 or element_index >= resistances.size():
		return 0
	var total := (resistances[element_index] + equipment_effect_total(role_index, EQUIPMENT_EFFECT_ELEMENT_FIRST + element_index)) & 0xffff
	return mini(100, total)


## 返回角色指定经典状态的剩余回合数；角色或状态越界时返回 0。
func status_rounds_for(role_index: int, status_id: int) -> int:
	if role_index < 0 or role_index >= role_status_rounds_by_role.size() or status_id < 0 or status_id >= STATUS_COUNT:
		return 0
	var rounds := role_status_rounds_by_role[role_index][status_id]
	# 装备脚本 002D 的时长保存在独立槽中，避免普通回合递减或解咒误删持久效果。
	for statuses in equipment_statuses_by_slot:
		var durations: PackedInt32Array = statuses.get(status_id, PackedInt32Array())
		if role_index < durations.size():
			rounds = maxi(rounds, durations[role_index])
	return rounds


## 按 SDLPal `PAL_SetPlayerStatus()` 规则设置角色状态并返回是否允许施加。
## 负面状态不刷新已有时长；正面状态取较长时长；傀儡只允许施加给倒下角色。
func set_role_status(role_index: int, status_id: int, rounds: int) -> bool:
	if role_index < 0 or role_index >= role_status_rounds_by_role.size() or status_id < 0 or status_id >= STATUS_COUNT:
		return false
	var statuses := role_status_rounds_by_role[role_index]
	var duration := maxi(0, rounds)
	if status_id in [STATUS_CONFUSED, STATUS_PARALYZED, STATUS_SLEEP, STATUS_SILENCE]:
		if statuses[status_id] == 0:
			statuses[status_id] = duration
		return true
	if status_id == STATUS_PUPPET:
		if role_index >= role_hp.size() or role_hp[role_index] > 0:
			return false
		statuses[status_id] = maxi(statuses[status_id], duration)
		return true
	if status_id in [STATUS_BRAVERY, STATUS_PROTECT, STATUS_HASTE, STATUS_DUAL_ATTACK]:
		if role_index >= role_hp.size() or role_hp[role_index] <= 0:
			return false
		statuses[status_id] = maxi(statuses[status_id], duration)
		return true
	return false


## 清除角色指定状态；大于 999 的装备效果按官方规则保留。
func remove_role_status(role_index: int, status_id: int) -> void:
	if status_rounds_for(role_index, status_id) <= 999 and role_index >= 0 and role_index < role_status_rounds_by_role.size() and status_id >= 0 and status_id < STATUS_COUNT:
		role_status_rounds_by_role[role_index][status_id] = 0


## 战斗结束时清除全部非装备角色状态。
func clear_temporary_role_statuses() -> void:
	for role_index in range(role_status_rounds_by_role.size()):
		for status_id in range(STATUS_COUNT):
			remove_role_status(role_index, status_id)


## 经典回合结束时把角色所有非零状态时长减一。
func decrement_role_statuses(role_index: int) -> void:
	if role_index < 0 or role_index >= role_status_rounds_by_role.size():
		return
	for status_id in range(STATUS_COUNT):
		if role_status_rounds_by_role[role_index][status_id] > 0:
			role_status_rounds_by_role[role_index][status_id] -= 1


## 给角色加入一种毒及其下一回合脚本游标；重复毒或超过 16 种时返回 `false`。
func add_role_poison(role_index: int, poison_id: int, script_cursor: int) -> bool:
	if role_index < 0 or role_index >= role_poisons_by_role.size() or poison_id <= 0:
		return false
	var poisons := role_poisons_by_role[role_index]
	if poisons.has(poison_id) or poisons.size() >= MAX_POISONS:
		return false
	poisons[poison_id] = script_cursor
	return true


## 更新角色某种毒的递进脚本游标；未中该毒时不新增。
func set_role_poison_cursor(role_index: int, poison_id: int, script_cursor: int) -> void:
	if role_index >= 0 and role_index < role_poisons_by_role.size() and role_poisons_by_role[role_index].has(poison_id):
		role_poisons_by_role[role_index][poison_id] = script_cursor


## 清除角色指定毒并返回是否实际移除。
func cure_role_poison(role_index: int, poison_id: int) -> bool:
	if role_index < 0 or role_index >= role_poisons_by_role.size() or not role_poisons_by_role[role_index].has(poison_id):
		return false
	role_poisons_by_role[role_index].erase(poison_id)
	return true


## 返回角色是否中了指定对象编号的毒。
func role_has_poison(role_index: int, poison_id: int) -> bool:
	return role_index >= 0 and role_index < role_poisons_by_role.size() and role_poisons_by_role[role_index].has(poison_id)


## 清除角色所有等级不高于 `max_level` 的毒，并返回实际清除数量。
## 毒等级来自只读内容数据库；缺失定义不会被误删，99 级装备效果也不会被普通解毒清除。
func cure_role_poisons_by_level(role_index: int, max_level: int, database: PalContentDatabase) -> int:
	if role_index < 0 or role_index >= role_poisons_by_role.size() or database == null:
		return 0
	var removed := 0
	for poison_id in role_poisons_by_role[role_index].keys():
		var definition := database.poison_definition(int(poison_id))
		if definition != null and definition.poison_level <= max_level:
			role_poisons_by_role[role_index].erase(poison_id)
			removed += 1
	return removed


## 返回角色是否中了等级不低于 `min_level` 的普通毒。
## 与 SDLPal 一致，99 级装备持续效果不视为可触发“已中毒”分支的普通毒。
func role_has_poison_by_level(role_index: int, min_level: int, database: PalContentDatabase) -> bool:
	if role_index < 0 or role_index >= role_poisons_by_role.size() or database == null:
		return false
	for poison_id in role_poisons_by_role[role_index]:
		var definition := database.poison_definition(int(poison_id))
		if definition != null and definition.poison_level < 99 and definition.poison_level >= min_level:
			return true
	return false


## 返回角色当前毒对象及脚本游标的副本，供战斗回合安全遍历。
func poison_entries_for(role_index: int) -> Dictionary:
	return role_poisons_by_role[role_index].duplicate() if role_index >= 0 and role_index < role_poisons_by_role.size() else {}

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


## 从背包和当前队伍装备中移除指定对象；用于 0020 在探索与战斗效果间共享语义。
func remove_item_including_equipment(item_id: int, amount: int) -> int:
	if item_id <= 0 or amount <= 0:
		return 0
	var remaining := amount
	var inventory_removed := mini(remaining, item_count(item_id))
	if inventory_removed > 0:
		change_item_count(item_id, -inventory_removed)
		remaining -= inventory_removed
	for role_index in party_roles:
		if remaining <= 0:
			break
		for slot_index in range(EQUIPMENT_SLOT_COUNT):
			if equipped_item(role_index, slot_index) != item_id:
				continue
			clear_equipment_effects(role_index, slot_index)
			replace_equipped_item(role_index, slot_index, 0)
			remaining -= 1
			if remaining <= 0:
				break
	equipment_effects_ready = true
	return amount - remaining


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
	battlefield_number = 0
	world_layer = 0
	party_roles = PackedInt32Array([0])
	follower_sprite_numbers = PackedInt32Array()
	collect_value = 0
	chase_speed_change_cycles = 0
	chase_range_multiplier = 1
	auto_battle_pending = false
	inventory.clear()
	role_levels = PackedInt32Array()
	role_max_hp = PackedInt32Array()
	role_max_mp = PackedInt32Array()
	role_hp = PackedInt32Array()
	role_mp = PackedInt32Array()
	role_experience = PackedInt32Array()
	role_attack_strength = PackedInt32Array()
	role_magic_strength = PackedInt32Array()
	role_defense = PackedInt32Array()
	role_dexterity = PackedInt32Array()
	role_flee_rate = PackedInt32Array()
	role_equipments_by_role.clear()
	equipment_effects_by_slot.clear()
	equipment_statuses_by_slot.clear()
	equipment_effects_ready = false
	role_poison_resistance = PackedInt32Array()
	role_elemental_resistances_by_role.clear()
	role_status_rounds_by_role.clear()
	role_poisons_by_role.clear()
	learned_magics_by_role.clear()
	clear_party_gestures()
	_initialize_trail(party_world_position())

#endregion

#region Audio settings

## 将背景音乐音量限制在 0–100，并返回实际保存的值。
## 只修改会话设置；调用方负责通知运行时播放器立即应用。
func set_music_volume(value: int) -> int:
	music_volume = clampi(value, 0, AUDIO_VOLUME_MAX)
	return music_volume


## 将音效音量限制在 0–100，并返回实际保存的值。
## 只修改会话设置；调用方负责通知运行时播放器立即应用。
func set_sound_volume(value: int) -> int:
	sound_volume = clampi(value, 0, AUDIO_VOLUME_MAX)
	return sound_volume


## 按 `delta` 调整背景音乐音量，并返回限制后的新值。
func change_music_volume(delta: int) -> int:
	return set_music_volume(music_volume + delta)


## 按 `delta` 调整音效音量，并返回限制后的新值。
func change_sound_volume(delta: int) -> int:
	return set_sound_volume(sound_volume + delta)


#endregion


func _ensure_role_conditions() -> void:
	while role_status_rounds_by_role.size() < PalPlayerRoles.ROLE_COUNT:
		var statuses := PackedInt32Array()
		statuses.resize(STATUS_COUNT)
		statuses.fill(0)
		role_status_rounds_by_role.append(statuses)
	while role_poisons_by_role.size() < PalPlayerRoles.ROLE_COUNT:
		role_poisons_by_role.append({})


func _initialize_trail(world_position: Vector2i) -> void:
	party_formation_collapsed = false
	trail_positions.resize(TRAIL_SIZE)
	trail_directions.resize(TRAIL_SIZE)
	var backward := Vector2i(
		16 if party_direction in [DIR_SOUTH, DIR_WEST] else -16,
		8 if party_direction in [DIR_WEST, DIR_NORTH] else -8
	)
	for index in range(TRAIL_SIZE):
		trail_positions[index] = world_position + backward * index
		trail_directions[index] = party_direction


func _reset_equipment_effect_storage() -> void:
	equipment_effects_by_slot.clear()
	equipment_statuses_by_slot.clear()
	for _slot_index in range(EQUIPMENT_EFFECT_SLOT_COUNT):
		equipment_effects_by_slot.append({})
		equipment_statuses_by_slot.append({})
	equipment_effects_ready = false


func _stat_with_equipment(base_values: PackedInt32Array, role_index: int, group_index: int) -> int:
	if role_index < 0 or role_index >= base_values.size():
		return 0
	# SDLPal 在 WORD 上逐槽相加；负数效果以二补码保存，因此这里必须逐次回绕。
	return (base_values[role_index] + equipment_effect_total(role_index, group_index)) & 0xffff


static func _level_random_int(random_int: Callable, from_value: int, to_value: int) -> int:
	return int(random_int.call(from_value, to_value)) if random_int.is_valid() else randi_range(from_value, to_value)
