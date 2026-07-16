# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal fight.c classic action queue and physical attack paths.
# SPDX-License-Identifier: GPL-3.0-or-later
## 单场经典回合制战斗的纯逻辑控制器。
## 静态定义来自 `PalContentDatabase`，敌人临时体力由本对象持有，玩家体力写回 `GameSession`。
class_name PalBattleController
extends RefCounted

enum BattleResult {
	ONGOING,
	VICTORY,
	DEFEAT,
}

enum ActionType {
	ATTACK,
	DEFEND,
	MAGIC,
}

## 单个敌人在本场战斗中的可变状态。
class EnemyState extends RefCounted:
	var slot_index: int = 0
	var object_id: int = 0
	var definition: PalEnemyDefinition
	var hp: int = 0
	var max_hp: int = 0

	## 返回敌人是否仍可行动和被选中。
	func is_alive() -> bool:
		return definition != null and hp > 0


## 一名队员在本场战斗中的指令和防御状态。
class PlayerState extends RefCounted:
	var party_index: int = 0
	var role_index: int = 0
	var action_type: int = -1
	var action_id: int = 0
	var target_index: int = -1
	var defending: bool = false


## 经典行动队列中的一个敌人或玩家行动。
class QueueEntry extends RefCounted:
	var is_enemy: bool = false
	var combatant_index: int = 0
	var dexterity: int = 0
	var is_second: bool = false


## 一次攻击对单个目标造成的结果。
class Hit extends RefCounted:
	var target_is_enemy: bool = false
	var target_index: int = -1
	var damage: int = 0
	var healing: int = 0
	var mp_restored: int = 0
	var critical: bool = false
	var auto_defended: bool = false
	var defeated: bool = false


## `execute_next_action()` 返回的可视化事件，不直接持有场景节点。
class ActionResult extends RefCounted:
	var actor_is_enemy: bool = false
	var actor_index: int = -1
	var action_type: int = ActionType.ATTACK
	var magic_object_id: int = 0
	var target_index: int = -1
	var mp_cost: int = 0
	var second_action: bool = false
	var skipped: bool = false
	var unsupported: bool = false
	var turn_finished: bool = false
	var battle_result: int = BattleResult.ONGOING
	var summary: String = ""
	var hits: Array[Hit] = []


## 本场使用的只读内容数据库。
var database: PalContentDatabase
## 玩家跨战斗状态的所有者。
var session: GameSession
## 当前敌队编号。
var enemy_team_id: int = 0
## 当前战场编号。
var battlefield_id: int = 0
## 当前回合，从 1 开始。
var turn_number: int = 1
## 当前胜负状态。
var battle_result: int = BattleResult.ONGOING
## 最近一次初始化失败原因。
var error_message: String = ""
## 按敌队有效槽位压紧后的单场敌人状态。
var enemies: Array[EnemyState] = []
## 按队伍顺序保存的玩家指令状态。
var players: Array[PlayerState] = []
## 当前回合按身法降序排列的行动队列。
var action_queue: Array[QueueEntry] = []

var _random := PalBattleRandom.new()
var _command_cursor: int = 0
var _queue_cursor: int = 0
var _accepting_commands: bool = false


#region Public lifecycle and commands

## 从指定敌队和战场创建一场战斗。
## `random_seed < 0` 时使用当前微秒时间；失败时返回 `false` 并设置 `error_message`。
func start_battle(content_database: PalContentDatabase, game_session: GameSession, team_id: int, field_id: int, random_seed: int = -1) -> bool:
	database = content_database
	session = game_session
	enemy_team_id = team_id
	battlefield_id = field_id
	turn_number = 1
	battle_result = BattleResult.ONGOING
	error_message = ""
	enemies.clear()
	players.clear()
	action_queue.clear()
	_command_cursor = 0
	_queue_cursor = 0
	_accepting_commands = false
	if database == null or session == null or database.player_roles == null:
		error_message = "战斗缺少内容数据库、会话或 PLAYERROLES"
		return false
	var team := database.enemy_team_definition(team_id)
	if team == null or database.battlefield_definition(field_id) == null:
		error_message = "敌队 %d 或战场 %d 不存在" % [team_id, field_id]
		return false
	if not session.initialize_role_state(database.player_roles):
		error_message = "玩家角色状态无法初始化"
		return false
	# PAL_StartBattle 会让体力为零的入队角色以 1 点体力参战，避免战斗在载入时直接失败。
	for role_index in session.party_roles:
		if role_index >= 0 and role_index < session.role_hp.size() and session.role_hp[role_index] == 0:
			session.increase_role_hp_mp(role_index, 1, 0)
	var active_objects := team.active_object_ids()
	for slot_index in range(active_objects.size()):
		var object_id := active_objects[slot_index]
		var definition := database.enemy_definition_for_object(object_id)
		if definition == null:
			error_message = "敌队 %d 的对象 %d 缺少敌人属性" % [team_id, object_id]
			enemies.clear()
			return false
		var enemy := EnemyState.new()
		enemy.slot_index = slot_index
		enemy.object_id = object_id
		enemy.definition = definition
		enemy.hp = definition.health
		enemy.max_hp = definition.health
		enemies.append(enemy)
	if enemies.is_empty():
		error_message = "敌队 %d 没有有效敌人" % team_id
		return false
	for party_index in range(mini(3, session.party_roles.size())):
		var role_index := session.party_roles[party_index]
		if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
			error_message = "队伍位置 %d 的角色编号 %d 无效" % [party_index, role_index]
			players.clear()
			return false
		var player := PlayerState.new()
		player.party_index = party_index
		player.role_index = role_index
		players.append(player)
	if players.is_empty():
		error_message = "战斗队伍为空"
		return false
	_random.set_seed(random_seed if random_seed >= 0 else Time.get_ticks_usec())
	_prepare_command_phase()
	_check_battle_result()
	return battle_result == BattleResult.ONGOING


## 重设后续随机序列，供截图复现和固定种子测试使用；不会重置当前战斗状态。
func set_random_seed(seed_value: int) -> void:
	_random.set_seed(seed_value)


## 返回当前是否正在等待玩家为队员提交指令。
func is_accepting_commands() -> bool:
	return _accepting_commands and battle_result == BattleResult.ONGOING


## 返回当前等待指令的队伍位置；不在指令阶段时返回 -1。
func pending_party_index() -> int:
	return _command_cursor if is_accepting_commands() and _command_cursor < players.size() else -1


## 返回当前等待指令的 PLAYERROLES 角色编号；不在指令阶段时返回 -1。
func pending_role_index() -> int:
	var party_index := pending_party_index()
	return players[party_index].role_index if party_index >= 0 else -1


## 返回所有仍存活的敌人索引，用于目标光标和 UI 列表。
func living_enemy_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for enemy_index in range(enemies.size()):
		if enemies[enemy_index].is_alive():
			result.append(enemy_index)
	return result


## 为当前队员提交普通攻击目标。
## 可攻击全体的角色会忽略目标并保存为 -1；目标无效或当前不接收指令时返回 `false`。
func submit_attack(target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0:
		return false
	var player := players[party_index]
	if database.player_roles.attack_all[player.role_index] != 0:
		target_index = -1
	elif target_index < 0 or target_index >= enemies.size() or not enemies[target_index].is_alive():
		return false
	player.action_type = ActionType.ATTACK
	player.target_index = target_index
	_advance_command_cursor()
	return true


## 为当前队员提交防御指令；防御在其行动执行后生效，并在本回合结束时清除。
func submit_defend() -> bool:
	var party_index := pending_party_index()
	if party_index < 0:
		return false
	players[party_index].action_type = ActionType.DEFEND
	players[party_index].target_index = party_index
	_advance_command_cursor()
	return true


## 返回当前等待指令的角色能否使用指定仙术。
## 会校验习得状态、战斗标志、MP、目标类型和本阶段已支持的成功脚本。
func can_pending_player_use_magic(magic_object_id: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0:
		return false
	var role_index := players[party_index].role_index
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	return object != null and definition != null and session.has_magic(role_index, magic_object_id) and object.is_usable_in_battle() and definition.mp_cost <= session.role_mp[role_index] and _magic_effect_is_supported(object, definition)


## 为当前队员提交仙术和目标；全体仙术会把目标规范化为 -1。
## 目标无效、MP 不足或成功脚本尚未支持时返回 `false`，不会消耗真气。
func submit_magic(magic_object_id: int, target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or not can_pending_player_use_magic(magic_object_id):
		return false
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	if object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PARTY, PalMagicDefinition.TYPE_SUMMON]:
		target_index = -1
	elif object.is_used_on_enemy():
		if target_index < 0 or target_index >= enemies.size() or not enemies[target_index].is_alive():
			return false
	elif target_index < 0 or target_index >= players.size() or _role_hp(players[target_index].role_index) <= 0:
		return false
	var player := players[party_index]
	player.action_type = ActionType.MAGIC
	player.action_id = magic_object_id
	player.target_index = target_index
	_advance_command_cursor()
	return true


## 在全队指令完成后按经典身法规则构造行动队列。
## 指令尚未完成、战斗已结束或队列已开始执行时返回 `false`。
func build_action_queue() -> bool:
	if battle_result != BattleResult.ONGOING or _command_cursor < players.size() or _queue_cursor > 0:
		return false
	action_queue.clear()
	_queue_cursor = 0
	for enemy_index in range(enemies.size()):
		var enemy := enemies[enemy_index]
		if not enemy.is_alive():
			continue
		var first := _enemy_queue_entry(enemy_index)
		action_queue.append(first)
		if enemy.definition.dual_move != 0:
			var second := _enemy_queue_entry(enemy_index)
			# 官方把身法较低的那一个标为第二动，供 Win95 双动音效等逻辑识别。
			if second.dexterity <= first.dexterity:
				second.is_second = true
			else:
				first.is_second = true
			action_queue.append(second)
	for party_index in range(players.size()):
		action_queue.append(_player_queue_entry(party_index))
	_sort_action_queue_like_sdlpal()
	_accepting_commands = false
	return not action_queue.is_empty()


## 执行行动队列中的下一项，并返回与画面解耦的结果。
## 不在行动阶段或战斗已结束时返回 `null`；目标死亡时会按 SDLPal 规则自动重选。
func execute_next_action() -> ActionResult:
	if battle_result != BattleResult.ONGOING or _accepting_commands or _queue_cursor >= action_queue.size():
		return null
	var entry := action_queue[_queue_cursor]
	_queue_cursor += 1
	var result := _execute_enemy_action(entry) if entry.is_enemy else _execute_player_action(entry)
	_check_battle_result()
	result.battle_result = battle_result
	if battle_result == BattleResult.ONGOING and _queue_cursor >= action_queue.size():
		_finish_turn()
		result.turn_finished = true
	return result


## 同步执行当前回合剩余行动，主要供无画面测试和调试工具使用。
## 最多执行 `max_actions` 项，防止损坏数据造成无限循环。
func execute_remaining_actions(max_actions: int = 32) -> Array[ActionResult]:
	var results: Array[ActionResult] = []
	for _index in range(maxi(0, max_actions)):
		var result := execute_next_action()
		if result == null:
			break
		results.append(result)
		if result.battle_result != BattleResult.ONGOING or result.turn_finished:
			break
	return results


## 计算 SDLPal 三段式基础伤害；结果可以为 0。
static func calculate_base_damage(attack_strength: int, defense: int) -> int:
	if attack_strength > defense:
		return floori(attack_strength * 2.0 - defense * 1.6 + 0.5)
	if attack_strength > defense * 0.6:
		return floori(attack_strength - defense * 0.6 + 0.5)
	return 0


## 计算扣除物理抗性后的基础物理伤害；最低 1 点规则由具体攻击动作应用。
static func calculate_physical_damage(attack_strength: int, defense: int, resistance: int) -> int:
	var damage := calculate_base_damage(attack_strength, defense)
	return damage / resistance if resistance != 0 else damage


#endregion

#region Queue construction

func _prepare_command_phase() -> void:
	action_queue.clear()
	_queue_cursor = 0
	_command_cursor = 0
	for player in players:
		player.action_type = -1
		player.action_id = 0
		player.target_index = -1
		player.defending = false
	_skip_players_without_commands()
	_accepting_commands = _command_cursor < players.size()
	if not _accepting_commands:
		build_action_queue()


func _advance_command_cursor() -> void:
	_command_cursor += 1
	_skip_players_without_commands()
	if _command_cursor >= players.size():
		build_action_queue()


func _skip_players_without_commands() -> void:
	while _command_cursor < players.size():
		var player := players[_command_cursor]
		if _role_hp(player.role_index) > 0:
			break
		player.action_type = ActionType.ATTACK
		player.target_index = 0
		_command_cursor += 1


func _enemy_queue_entry(enemy_index: int) -> QueueEntry:
	var entry := QueueEntry.new()
	entry.is_enemy = true
	entry.combatant_index = enemy_index
	var definition := enemies[enemy_index].definition
	var dexterity := (definition.level + 6) * 3 + _signed_word(definition.dexterity)
	entry.dexterity = int(dexterity * _random.next_float(0.9, 1.1))
	return entry


func _player_queue_entry(party_index: int) -> QueueEntry:
	var entry := QueueEntry.new()
	entry.combatant_index = party_index
	var player := players[party_index]
	if _role_hp(player.role_index) <= 0:
		entry.dexterity = 0
		return entry
	var dexterity := database.player_roles.dexterity_for(player.role_index)
	if player.action_type == ActionType.DEFEND:
		dexterity *= 5
	if _is_player_dying(player.role_index):
		dexterity /= 2
	entry.dexterity = int(dexterity * _random.next_float(0.9, 1.1))
	return entry


func _sort_action_queue_like_sdlpal() -> void:
	# fight.c 使用双层交换排序；只在严格小于时交换，因此相同身法保持入队顺序。
	for first_index in range(action_queue.size()):
		for candidate_index in range(first_index, action_queue.size()):
			if action_queue[first_index].dexterity < action_queue[candidate_index].dexterity:
				var temporary := action_queue[first_index]
				action_queue[first_index] = action_queue[candidate_index]
				action_queue[candidate_index] = temporary


#endregion

#region Action execution

func _execute_player_action(entry: QueueEntry) -> ActionResult:
	var result := ActionResult.new()
	result.actor_index = entry.combatant_index
	result.second_action = entry.is_second
	var player := players[entry.combatant_index]
	result.action_type = player.action_type
	if _role_hp(player.role_index) <= 0:
		result.skipped = true
		result.summary = "倒下的队员无法行动"
		return result
	if player.action_type == ActionType.DEFEND:
		player.defending = true
		result.summary = "%s进入防御" % _role_name(player.role_index)
		return result
	if player.action_type == ActionType.MAGIC:
		_execute_player_magic(player, result)
		return result
	if player.action_type != ActionType.ATTACK:
		result.skipped = true
		result.summary = "未支持的玩家指令"
		return result
	if database.player_roles.attack_all[player.role_index] != 0:
		_execute_player_attack_all(player, result)
	else:
		var target_index := _find_alive_enemy_from(player.target_index)
		if target_index < 0:
			result.skipped = true
			result.summary = "没有可攻击目标"
			return result
		var hit := _player_single_hit(player, target_index)
		result.hits.append(hit)
		result.summary = "%s攻击敌人，造成%d点伤害%s" % [
			_role_name(player.role_index),
			hit.damage,
			"（暴击）" if hit.critical else "",
		]
	return result


func _execute_player_magic(player: PlayerState, result: ActionResult) -> void:
	var object := database.magic_object_definition(player.action_id)
	var definition := database.magic_definition_for_object(player.action_id)
	result.magic_object_id = player.action_id
	result.target_index = player.target_index
	if object == null or definition == null or not _magic_effect_is_supported(object, definition):
		result.unsupported = true
		result.summary = "该仙术的状态或脚本效果尚未接入"
		return
	if definition.mp_cost > session.role_mp[player.role_index]:
		result.unsupported = true
		result.summary = "%s真气不足" % _role_name(player.role_index)
		return
	result.mp_cost = definition.mp_cost
	session.increase_role_hp_mp(player.role_index, 0, -definition.mp_cost)
	if object.is_used_on_enemy():
		var target_indices := living_enemy_indices() if player.target_index < 0 else PackedInt32Array([_find_alive_enemy_from(player.target_index)])
		for target_index in target_indices:
			if target_index < 0:
				continue
			var damage := _calculate_player_magic_damage(player.role_index, target_index, definition)
			result.hits.append(_apply_enemy_damage(target_index, maxi(1, damage), false))
	else:
		var event_role := player.role_index
		if player.target_index >= 0 and player.target_index < players.size():
			event_role = players[player.target_index].role_index
		_run_supported_magic_script(object.script_on_use, player.role_index, result)
		_run_supported_magic_script(object.script_on_success, event_role, result)
	result.summary = "%s施展%s" % [_role_name(player.role_index), database.get_word(player.action_id)]


func _calculate_player_magic_damage(role_index: int, target_index: int, definition: PalMagicDefinition) -> int:
	var enemy := enemies[target_index].definition
	var magic_strength := database.player_roles.magic_strength_for(role_index)
	magic_strength = int(magic_strength * _random.next_float(10.0, 11.0) / 10.0)
	var defense := enemy.defense + (enemy.level + 6) * 4
	var damage := calculate_base_damage(magic_strength, defense) / 4
	damage += _signed_word(definition.base_damage)
	if definition.elemental != 0:
		var resistance := enemy.poison_resistance if definition.elemental > PalBattlefield.ELEMENT_COUNT else enemy.elemental_resistances[definition.elemental - 1]
		damage = int(damage * (10.0 - float(resistance)))
		damage /= 5
		if definition.elemental <= PalBattlefield.ELEMENT_COUNT:
			var battlefield := database.battlefield_definition(battlefield_id)
			var field_effect := battlefield.magic_effects[definition.elemental - 1] if battlefield != null and battlefield.magic_effects.size() >= definition.elemental else 0
			damage = int(damage * (10.0 + field_effect) / 10.0)
	return damage


func _magic_effect_is_supported(object: PalMagicObjectDefinition, definition: PalMagicDefinition) -> bool:
	if object.is_used_on_enemy():
		return _signed_word(definition.base_damage) > 0 and object.script_on_use == 0 and object.script_on_success == 0 and definition.magic_type in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD]
	return definition.magic_type in [PalMagicDefinition.TYPE_APPLY_TO_PLAYER, PalMagicDefinition.TYPE_APPLY_TO_PARTY] and _magic_script_is_supported(object.script_on_use) and _magic_script_is_supported(object.script_on_success)


func _magic_script_is_supported(entry_index: int) -> bool:
	var cursor := entry_index
	for _step in range(64):
		if cursor == 0:
			return true
		if cursor < 0 or cursor >= database.scripts.size():
			return false
		var entry := database.scripts[cursor]
		match entry.operation:
			0x0000, 0x0001:
				return true
			0x0003:
				cursor = entry.operands[0]
			0x001b, 0x001c, 0x001d:
				cursor += 1
			_:
				return false
	return false


func _run_supported_magic_script(entry_index: int, event_role: int, result: ActionResult) -> void:
	var cursor := entry_index
	for _step in range(64):
		if cursor == 0 or cursor < 0 or cursor >= database.scripts.size():
			return
		var entry := database.scripts[cursor]
		match entry.operation:
			0x0000, 0x0001:
				return
			0x0003:
				cursor = entry.operands[0]
				continue
			0x001b, 0x001c, 0x001d:
				var hp_delta := _signed_word(entry.operands[1]) if entry.operation in [0x001b, 0x001d] else 0
				var mp_delta := _signed_word(entry.operands[1]) if entry.operation in [0x001c, 0x001d] else 0
				if entry.operands[0] != 0:
					for party_index in range(players.size()):
						_apply_player_stat_delta(party_index, hp_delta, mp_delta, result)
				else:
					var party_index := _party_index_for_role(event_role)
					if party_index >= 0:
						_apply_player_stat_delta(party_index, hp_delta, mp_delta, result)
				cursor += 1
			_:
				return


func _apply_player_stat_delta(party_index: int, hp_delta: int, mp_delta: int, result: ActionResult) -> void:
	if party_index < 0 or party_index >= players.size():
		return
	var role_index := players[party_index].role_index
	# PAL_IncreaseHPMP 不会让普通治疗复活已经倒下的角色。
	if _role_hp(role_index) <= 0:
		return
	var old_hp := session.role_hp[role_index]
	var old_mp := session.role_mp[role_index]
	session.increase_role_hp_mp(role_index, hp_delta, mp_delta)
	var hp_change := session.role_hp[role_index] - old_hp
	var mp_change := session.role_mp[role_index] - old_mp
	if hp_change == 0 and mp_change == 0:
		return
	var hit := _player_hit_for_result(result, party_index)
	hit.healing += maxi(0, hp_change)
	hit.damage += maxi(0, -hp_change)
	hit.mp_restored += maxi(0, mp_change)
	hit.defeated = session.role_hp[role_index] == 0


func _player_hit_for_result(result: ActionResult, party_index: int) -> Hit:
	for hit in result.hits:
		if not hit.target_is_enemy and hit.target_index == party_index:
			return hit
	var hit := Hit.new()
	hit.target_index = party_index
	result.hits.append(hit)
	return hit


func _party_index_for_role(role_index: int) -> int:
	for party_index in range(players.size()):
		if players[party_index].role_index == role_index:
			return party_index
	return -1


func _execute_player_attack_all(player: PlayerState, result: ActionResult) -> void:
	var critical := _random.next_int(0, 5) == 0
	var division := 1
	# SDLPal 固定按中、次前、最前、最后、次后的次序结算全体普攻。
	for enemy_index in [2, 1, 0, 4, 3]:
		if enemy_index >= enemies.size() or not enemies[enemy_index].is_alive():
			continue
		var enemy := enemies[enemy_index]
		var defense := enemy.definition.defense + (enemy.definition.level + 6) * 4
		var damage := calculate_physical_damage(
			database.player_roles.attack_strength_for(player.role_index),
			defense,
			enemy.definition.physical_resistance
		)
		if critical:
			damage *= 3
		damage = maxi(1, damage / division)
		var hit := _apply_enemy_damage(enemy_index, damage, critical)
		result.hits.append(hit)
		division *= 2
	result.summary = "%s攻击全体敌人" % _role_name(player.role_index)


func _player_single_hit(player: PlayerState, target_index: int) -> Hit:
	var enemy := enemies[target_index]
	var defense := enemy.definition.defense + (enemy.definition.level + 6) * 4
	var damage := calculate_physical_damage(
		database.player_roles.attack_strength_for(player.role_index),
		defense,
		enemy.definition.physical_resistance
	)
	damage += _random.next_int(1, 2)
	var critical := false
	if _random.next_int(0, 5) == 0:
		damage *= 3
		critical = true
	if player.role_index == 0 and _random.next_int(0, 11) == 0:
		damage *= 2
		critical = true
	damage = int(damage * _random.next_float(1.0, 1.125))
	return _apply_enemy_damage(target_index, maxi(1, damage), critical)


func _apply_enemy_damage(target_index: int, damage: int, critical: bool) -> Hit:
	var enemy := enemies[target_index]
	var hit := Hit.new()
	hit.target_is_enemy = true
	hit.target_index = target_index
	hit.damage = mini(enemy.hp, maxi(0, damage))
	hit.critical = critical
	enemy.hp = maxi(0, enemy.hp - damage)
	hit.defeated = enemy.hp == 0
	return hit


func _execute_enemy_action(entry: QueueEntry) -> ActionResult:
	var result := ActionResult.new()
	result.actor_is_enemy = true
	result.actor_index = entry.combatant_index
	result.second_action = entry.is_second
	var enemy := enemies[entry.combatant_index]
	if not enemy.is_alive():
		result.skipped = true
		result.summary = "已被击倒的敌人无法行动"
		return result
	var target_index := _select_random_living_player()
	if target_index < 0:
		result.skipped = true
		result.summary = "敌人没有可攻击目标"
		return result
	# 敌人会在选定目标后再判断施法。第一闭环尚未移植法术脚本，明确暂停该次动作，
	# 避免把本应施法的敌人静默改成物理攻击而造成难以发现的数值偏差。
	if enemy.definition.magic != 0 and _random.next_int(0, 9) < enemy.definition.magic_rate:
		result.unsupported = true
		result.summary = "敌人法术行动尚未接入"
		return result
	var hit := _enemy_physical_hit(entry.combatant_index, target_index)
	result.hits.append(hit)
	result.summary = "敌人攻击%s：%s" % [
		_role_name(players[target_index].role_index),
		"自动防御" if hit.auto_defended else "%d点伤害" % hit.damage,
	]
	return result


func _enemy_physical_hit(enemy_index: int, target_index: int) -> Hit:
	var enemy := enemies[enemy_index]
	var player := players[target_index]
	var hit := Hit.new()
	hit.target_index = target_index
	# 原版无异常状态的角色也有 7/17 自动格挡机会；格挡时本次物理攻击不扣体力。
	if _random.next_int(0, 16) >= 10:
		hit.auto_defended = true
		return hit
	var attack := _signed_word(enemy.definition.attack_strength) + (enemy.definition.level + 6) * 6
	attack = maxi(0, attack)
	var defense := database.player_roles.defense_for(player.role_index)
	if player.defending:
		defense *= 2
	var damage := calculate_physical_damage(attack + _random.next_int(0, 2), defense, 2)
	damage += _random.next_int(0, 1)
	damage = maxi(1, damage)
	var current_hp := _role_hp(player.role_index)
	hit.damage = mini(current_hp, damage)
	session.increase_role_hp_mp(player.role_index, -damage, 0)
	hit.defeated = _role_hp(player.role_index) == 0
	return hit


func _finish_turn() -> void:
	for player in players:
		player.defending = false
	turn_number += 1
	_prepare_command_phase()


#endregion

#region Helpers

func _check_battle_result() -> void:
	if living_enemy_indices().is_empty():
		battle_result = BattleResult.VICTORY
		_accepting_commands = false
		return
	for player in players:
		if _role_hp(player.role_index) > 0:
			battle_result = BattleResult.ONGOING
			return
	battle_result = BattleResult.DEFEAT
	_accepting_commands = false


func _find_alive_enemy_from(begin: int) -> int:
	if enemies.is_empty():
		return -1
	var index := maxi(0, begin)
	for _count in range(enemies.size()):
		index = posmod(index, enemies.size())
		if enemies[index].is_alive():
			return index
		index += 1
	return -1


func _select_random_living_player() -> int:
	var living_count := 0
	for player in players:
		if _role_hp(player.role_index) > 0:
			living_count += 1
	if living_count == 0:
		return -1
	for _attempt in range(players.size() * 8):
		var index := _random.next_int(0, players.size() - 1)
		if _role_hp(players[index].role_index) > 0:
			return index
	# 固定上限只保护损坏随机源；正常路径与 SDLPal 的随机重试结果相同。
	for index in range(players.size()):
		if _role_hp(players[index].role_index) > 0:
			return index
	return -1


func _is_player_dying(role_index: int) -> bool:
	if role_index < 0 or role_index >= session.role_max_hp.size():
		return false
	return _role_hp(role_index) < mini(100, session.role_max_hp[role_index] / 5)


func _role_hp(role_index: int) -> int:
	return session.role_hp[role_index] if role_index >= 0 and role_index < session.role_hp.size() else 0


func _role_name(role_index: int) -> String:
	var name := database.get_word(database.player_roles.name_word_for(role_index))
	return name if not name.is_empty() else "角色%d" % role_index


static func _signed_word(value: int) -> int:
	return value - 0x10000 if value >= 0x8000 else value


#endregion
