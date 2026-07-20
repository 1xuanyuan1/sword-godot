# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal fight.c classic action queue, physical attack and magic paths.
# SPDX-License-Identifier: GPL-3.0-or-later
## 单场经典回合制战斗的纯逻辑控制器。
## 静态定义来自 `PalContentDatabase`，敌人临时体力由本对象持有，玩家体力和成长写回 `GameSession`。
class_name PalBattleController
extends RefCounted

const REWARD_STAT_LEVEL := 0
const REWARD_STAT_MAX_HP := 1
const REWARD_STAT_MAX_MP := 2
const REWARD_STAT_ATTACK := 3
const REWARD_STAT_MAGIC := 4
const REWARD_STAT_DEFENSE := 5
const REWARD_STAT_DEXTERITY := 6
const REWARD_STAT_FLEE := 7

enum BattleResult {
	ONGOING,
	VICTORY,
	DEFEAT,
	FLED,
	TERMINATED,
}

enum ActionType {
	ATTACK,
	DEFEND,
	MAGIC,
	COOPERATIVE_MAGIC,
	USE_ITEM,
	THROW_ITEM,
	FLEE,
	PASS,
	ATTACK_MATE,
	POISON,
	SCRIPT,
}

enum ScriptEventType {
	DIALOG_START,
	DIALOG_MESSAGE,
	CLEAR_DIALOG,
	SOUND,
	MUSIC,
	DELAY,
	SUMMON,
	TRANSFORM,
	ENEMY_ESCAPE,
	ITEM_GAIN,
	SCREEN_SHAKE,
	PLAYER_SPRITE,
	HIDING,
	STEAL,
	BLOW,
	PRE_MAGIC,
}

## 单个敌人在本场战斗中的可变状态。
class EnemyState extends RefCounted:
	var slot_index: int = 0
	var object_id: int = 0
	var definition: PalEnemyDefinition
	var hp: int = 0
	var max_hp: int = 0
	var magic: int = 0
	var magic_rate: int = 0
	var script_on_turn_start: int = 0
	var script_on_battle_end: int = 0
	var script_on_ready: int = 0
	var status_rounds: PackedInt32Array = PackedInt32Array()
	var poisons: Dictionary = {}
	var steal_item: int = 0
	var steal_item_count: int = 0

	## 返回敌人是否仍可行动和被选中。
	func is_alive() -> bool:
		return definition != null and hp > 0


## 战斗脚本产生的一项可视副作用；逻辑控制器只记录，画面层负责播放。
class ScriptEvent extends RefCounted:
	var type: int = ScriptEventType.CLEAR_DIALOG
	var value: int = 0
	var secondary: int = 0
	var tertiary: int = 0


## 一名队员在本场战斗中的指令和防御状态。
class PlayerState extends RefCounted:
	var party_index: int = 0
	var role_index: int = 0
	var action_type: int = -1
	var action_id: int = 0
	var target_index: int = -1
	# 对齐 fight.c 的 prevAction：重复回合的降级动作不能覆盖这份缓存。
	var previous_action_type: int = -1
	var previous_action_id: int = 0
	var previous_target_index: int = -1
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
	# 同一次物理行动中的第几击；双剑状态用 0/1 区分两轮动画与伤害数字。
	var attack_sequence: int = 0
	var damage: int = 0
	var healing: int = 0
	var mp_restored: int = 0
	var critical: bool = false
	var auto_defended: bool = false
	var covering_index: int = -1
	var defeated: bool = false


## `execute_next_action()` 返回的可视化事件，不直接持有场景节点。
class ActionResult extends RefCounted:
	var actor_is_enemy: bool = false
	var actor_index: int = -1
	var action_type: int = ActionType.ATTACK
	var magic_object_id: int = 0
	var item_object_id: int = 0
	var target_index: int = -1
	var mp_cost: int = 0
	var cooperative_hp_cost: int = 0
	var contributor_indices: PackedInt32Array = PackedInt32Array()
	var flee_succeeded: bool = false
	var second_action: bool = false
	var skipped: bool = false
	var unsupported: bool = false
	var poison_tick: bool = false
	var turn_finished: bool = false
	var battle_result: int = BattleResult.ONGOING
	var summary: String = ""
	var hits: Array[Hit] = []
	var script_hits: Array[Hit] = []
	var script_events: Array[ScriptEvent] = []


## 一名角色在本次战斗结算中的升级前后数值。
class LevelUpResult extends RefCounted:
	var role_index: int = 0
	var old_hp: int = 0
	var old_mp: int = 0
	var new_hp: int = 0
	var new_mp: int = 0
	var old_stats: PackedInt32Array = PackedInt32Array()
	var new_stats: PackedInt32Array = PackedInt32Array()


## 一名角色因升级规则新习得的仙术。
class LearnedMagicResult extends RefCounted:
	var role_index: int = 0
	var magic_object_id: int = 0


## 胜利后只允许领取一次的经验、金钱、升级和习得仙术报告。
class RewardResult extends RefCounted:
	var experience: int = 0
	var cash: int = 0
	var level_ups: Array[LevelUpResult] = []
	var learned_magics: Array[LearnedMagicResult] = []
	var post_battle_scripts: PackedInt32Array = PackedInt32Array()
	var script_events: Array[ScriptEvent] = []


## 本场使用的只读内容数据库。
var database: PalContentDatabase
## 玩家跨战斗状态的所有者。
var session: GameSession
## 当前敌队编号。
var enemy_team_id: int = 0
## 当前战场编号。
var battlefield_id: int = 0
## 当前是否为禁止逃跑的 Boss 战。
var is_boss_battle: bool = false
## 当前回合，从 1 开始。
var turn_number: int = 1
## 当前胜负状态。
var battle_result: int = BattleResult.ONGOING
## 本场已击倒敌人累计的主经验。
var experience_gained: int = 0
## 本场已击倒敌人累计的金钱。
var cash_gained: int = 0
## 已领取的胜利结算；尚未胜利或未领取时为 `null`。
var reward_result: RewardResult
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
var _reserved_items: Dictionary = {}
var _repeating_previous_commands: bool = false
var _end_turn_pending: bool = false
var _battle_cleanup_applied: bool = false
var _cooperative_magic_executed: bool = false
var _cooperative_contributors: PackedInt32Array = PackedInt32Array()
var _pending_script_results: Array[ActionResult] = []
var _resume_commands_after_scripts: bool = false
var _enemy_object_script_overrides: Dictionary = {}
var _auto_battle: bool = false
var _hiding_turns: int = 0
var _blow_displacement: int = 0


#region Public lifecycle and commands

## 从指定敌队和战场创建一场战斗。
## `random_seed < 0` 时使用当前微秒时间；`boss_battle` 为真时逃跑必定失败。
## 初始化失败时返回 `false` 并设置 `error_message`。
func start_battle(content_database: PalContentDatabase, game_session: GameSession, team_id: int, field_id: int, random_seed: int = -1, boss_battle: bool = false) -> bool:
	database = content_database
	session = game_session
	enemy_team_id = team_id
	battlefield_id = field_id
	is_boss_battle = boss_battle
	turn_number = 1
	battle_result = BattleResult.ONGOING
	experience_gained = 0
	cash_gained = 0
	reward_result = null
	error_message = ""
	enemies.clear()
	players.clear()
	action_queue.clear()
	_command_cursor = 0
	_queue_cursor = 0
	_accepting_commands = false
	_reserved_items.clear()
	_repeating_previous_commands = false
	_end_turn_pending = false
	_battle_cleanup_applied = false
	_cooperative_magic_executed = false
	_cooperative_contributors = PackedInt32Array()
	_pending_script_results.clear()
	_resume_commands_after_scripts = false
	_enemy_object_script_overrides.clear()
	_auto_battle = false
	_hiding_turns = 0
	_blow_displacement = 0
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
	if not session.equipment_effects_ready:
		var equipment_manager := PalEquipmentManager.new()
		if not equipment_manager.configure(database, session):
			error_message = equipment_manager.error_message
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
		enemies.append(_create_enemy_state(object_id, slot_index))
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
	# 008A 是一次性入口标志：只有真正建立的下一场战斗消费它，之后不随存档保留。
	_auto_battle = session.auto_battle_pending
	session.auto_battle_pending = false
	_random.set_seed(random_seed if random_seed >= 0 else Time.get_ticks_usec())
	_queue_enemy_turn_start_scripts()
	if _pending_script_results.is_empty() and battle_result == BattleResult.ONGOING:
		_prepare_command_phase()
	_check_battle_result()
	return true


## 重设后续随机序列，供截图复现和固定种子测试使用；不会重置当前战斗状态。
func set_random_seed(seed_value: int) -> void:
	_random.set_seed(seed_value)


## 返回当前是否正在等待玩家为队员提交指令。
func is_accepting_commands() -> bool:
	return _accepting_commands and battle_result == BattleResult.ONGOING


## 返回本场是否由 008A 启用了全程自动指令。
func is_auto_battle() -> bool:
	return _auto_battle and battle_result == BattleResult.ONGOING


## 返回是否还有战斗脚本产生的对白、召唤或其他可视事件等待播放。
func has_pending_script_results() -> bool:
	return not _pending_script_results.is_empty()


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


## 返回队员指定经典状态的剩余回合数；索引越界时返回 0。
func player_status_rounds(party_index: int, status_id: int) -> int:
	if party_index < 0 or party_index >= players.size():
		return 0
	return session.status_rounds_for(players[party_index].role_index, status_id)


## 返回敌人指定经典状态的剩余回合数；索引越界时返回 0。
func enemy_status_rounds(enemy_index: int, status_id: int) -> int:
	if enemy_index < 0 or enemy_index >= enemies.size() or status_id < 0 or status_id >= GameSession.STATUS_COUNT:
		return 0
	return enemies[enemy_index].status_rounds[status_id]


## 返回队员当前所中毒对象编号，顺序保持施加顺序。
func player_poison_ids(party_index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if party_index < 0 or party_index >= players.size():
		return result
	for poison_id in session.poison_entries_for(players[party_index].role_index):
		result.append(int(poison_id))
	return result


## 返回敌人当前所中毒对象编号，顺序保持施加顺序。
func enemy_poison_ids(enemy_index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if enemy_index < 0 or enemy_index >= enemies.size():
		return result
	for poison_id in enemies[enemy_index].poisons:
		result.append(int(poison_id))
	return result


## 为当前队员提交普通攻击目标。
## 可攻击全体的角色会忽略目标并保存为 -1；目标无效或当前不接收指令时返回 `false`。
func submit_attack(target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0:
		return false
	var player := players[party_index]
	if session.can_attack_all(player.role_index, database.player_roles):
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
	return object != null and definition != null and session.has_magic(role_index, magic_object_id) and object.is_usable_in_battle() and session.status_rounds_for(role_index, GameSession.STATUS_SILENCE) == 0 and definition.mp_cost <= session.role_mp[role_index] and _magic_effect_is_supported(object, definition)


## 为当前队员提交仙术和目标；全体仙术会把目标规范化为 -1。
## 目标无效、MP 不足或成功脚本尚未支持时返回 `false`，不会消耗真气。
func submit_magic(magic_object_id: int, target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or not can_pending_player_use_magic(magic_object_id):
		return false
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	if definition.magic_type == PalMagicDefinition.TYPE_TRANCE:
		# 经典模式的梦蛇不打开队员选择，始终作用于施法者自己。
		target_index = party_index
	elif object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PARTY, PalMagicDefinition.TYPE_SUMMON]:
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


## 返回当前等待指令的角色所配置的合击仙术对象编号；无有效合击时返回 0。
func pending_cooperative_magic_object_id() -> int:
	var role_index := pending_role_index()
	return session.cooperative_magic_for(role_index, database.player_roles) if role_index >= 0 else 0


## 返回当前角色是否能发动经典合击。
## 至少需要两名健康队员，发动者也必须健康，且其合击对象需是已接入的攻击仙术。
func can_pending_player_use_cooperative_magic() -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or players.size() <= 1 or not _is_player_healthy_for_cooperation(party_index):
		return false
	var healthy_count := 0
	for candidate_index in range(players.size()):
		if _is_player_healthy_for_cooperation(candidate_index):
			healthy_count += 1
	if healthy_count <= 1:
		return false
	var magic_object_id := pending_cooperative_magic_object_id()
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	return object != null and definition != null and object.is_used_on_enemy() and definition.magic_type in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_SUMMON] and _signed_word(definition.base_damage) > 0


## 为当前角色提交合击；群体合击会把目标规范化为 -1，并立即结束本回合余下指令选择。
## 不健康队员不会成为贡献者；目标或合击定义无效时返回 `false`。
func submit_cooperative_magic(target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or not can_pending_player_use_cooperative_magic():
		return false
	var magic_object_id := pending_cooperative_magic_object_id()
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	if object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_SUMMON]:
		target_index = -1
	elif target_index < 0 or target_index >= enemies.size() or not enemies[target_index].is_alive():
		return false
	_cooperative_contributors = PackedInt32Array()
	for candidate_index in range(players.size()):
		if _is_player_healthy_for_cooperation(candidate_index):
			_cooperative_contributors.append(candidate_index)
	var player := players[party_index]
	player.action_type = ActionType.COOPERATIVE_MAGIC
	player.action_id = magic_object_id
	player.target_index = target_index
	# 经典选择阶段一旦有人提交合击就不再询问后续队员；队列中的其他玩家会在合击后跳过。
	for remaining_index in range(party_index + 1, players.size()):
		players[remaining_index].action_type = ActionType.PASS
		players[remaining_index].target_index = -1
	_command_cursor = players.size()
	return build_action_queue()


## 返回当前角色能否在本回合使用指定物品。
## 会检查背包可用数量、战斗使用标志及已支持的 HP/MP 脚本，不预扣库存。
func can_pending_player_use_item(item_object_id: int) -> bool:
	if pending_party_index() < 0 or available_item_count(item_object_id) <= 0:
		return false
	var item := database.item_definition(item_object_id)
	return item != null and item.is_usable() and _battle_effect_script_is_supported(item.script_on_use)


## 返回当前角色能否投掷指定物品。
## 第一阶段支持以 `0042` 模拟仙术或以 `0066` 计算武器伤害的经典投掷脚本。
func can_pending_player_throw_item(item_object_id: int) -> bool:
	if pending_party_index() < 0 or available_item_count(item_object_id) <= 0:
		return false
	var item := database.item_definition(item_object_id)
	return item != null and item.is_throwable() and _throw_script_is_supported(item.script_on_throw)


## 返回扣除本回合其他队员已选用数量后仍可提交的物品数。
func available_item_count(item_object_id: int) -> int:
	if session == null:
		return 0
	return maxi(0, session.item_count(item_object_id) - int(_reserved_items.get(item_object_id, 0)))


## 为当前角色提交战斗使用物品；单体物品目标为队伍位置，全体物品会规范化为 -1。
func submit_use_item(item_object_id: int, target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or not can_pending_player_use_item(item_object_id):
		return false
	var item := database.item_definition(item_object_id)
	if item.applies_to_all():
		target_index = -1
	elif target_index < 0 or target_index >= players.size() or _role_hp(players[target_index].role_index) <= 0:
		return false
	var player := players[party_index]
	player.action_type = ActionType.USE_ITEM
	player.action_id = item_object_id
	player.target_index = target_index
	if item.is_consuming():
		_reserve_item(item_object_id)
	_advance_command_cursor()
	return true


## 为当前角色提交投掷物品；投掷物一定预留并在行动执行时消耗一个。
func submit_throw_item(item_object_id: int, target_index: int) -> bool:
	var party_index := pending_party_index()
	if party_index < 0 or not can_pending_player_throw_item(item_object_id):
		return false
	var item := database.item_definition(item_object_id)
	if item.applies_to_all():
		target_index = -1
	elif target_index < 0 or target_index >= enemies.size() or not enemies[target_index].is_alive():
		return false
	var player := players[party_index]
	player.action_type = ActionType.THROW_ITEM
	player.action_id = item_object_id
	player.target_index = target_index
	_reserve_item(item_object_id)
	_advance_command_cursor()
	return true


## 为当前角色及尚未选指令的队员统一提交逃跑，符合经典模式的全队逃跑键行为。
func submit_flee() -> bool:
	var party_index := pending_party_index()
	if party_index < 0:
		return false
	for index in range(party_index, players.size()):
		var player := players[index]
		player.action_type = ActionType.FLEE if _role_hp(player.role_index) > 0 else ActionType.ATTACK
		player.target_index = -1
	_command_cursor = players.size()
	build_action_queue()
	return true


## 为当前及尚未选择指令的队员重复上一回合指令，对应 SDLPal 的 `R / kKeyRepeat`。
## 第一回合尚无缓存时退化为普通攻击；MP 不足、物品耗尽或目标失效时按官方规则改为攻击或防御。
## 成功时直接结束本回合指令阶段并构建行动队列；失败时不修改当前指令。
func repeat_previous_commands() -> bool:
	if pending_party_index() < 0:
		return false
	_repeating_previous_commands = true
	while _command_cursor < players.size():
		var party_index := _command_cursor
		_assign_repeated_command(party_index)
		if players[party_index].action_type == ActionType.COOPERATIVE_MAGIC:
			for remaining_index in range(party_index + 1, players.size()):
				players[remaining_index].action_type = ActionType.PASS
				players[remaining_index].target_index = -1
			_command_cursor = players.size()
			break
		_command_cursor += 1
		_skip_players_without_commands()
	var built := build_action_queue()
	if not built:
		_repeating_previous_commands = false
	return built


## 在全队指令完成后按经典身法规则构造行动队列。
## 指令尚未完成、战斗已结束或队列已开始执行时返回 `false`。
func build_action_queue() -> bool:
	if battle_result != BattleResult.ONGOING or _command_cursor < players.size() or _queue_cursor > 0:
		return false
	# fight.c 只在普通选择回合备份 action；重复回合即使因资源不足降级，
	# 也必须保留原始 prevAction，方便资源恢复后再次按 R。
	if not _repeating_previous_commands:
		for player in players:
			player.previous_action_type = player.action_type
			player.previous_action_id = player.action_id
			player.previous_target_index = player.target_index
	_repeating_previous_commands = false
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
	if _accepting_commands:
		return null
	if not _pending_script_results.is_empty():
		var script_result: ActionResult = _pending_script_results.pop_front()
		if _pending_script_results.is_empty() and _resume_commands_after_scripts and battle_result == BattleResult.ONGOING:
			_resume_commands_after_scripts = false
			_prepare_command_phase()
		script_result.battle_result = battle_result
		_apply_battle_cleanup_if_needed()
		return script_result
	if battle_result != BattleResult.ONGOING:
		return null
	# 普通队列最后一项先交给画面播放；下一次调用才真实结算毒与状态，避免数值提前一帧变化。
	if _end_turn_pending:
		_end_turn_pending = false
		var end_turn_result := _finish_turn()
		end_turn_result.battle_result = battle_result
		_apply_battle_cleanup_if_needed()
		return end_turn_result
	if _queue_cursor >= action_queue.size():
		return null
	var entry := action_queue[_queue_cursor]
	_queue_cursor += 1
	# fight.c 在每个玩家/敌人行动开始前清空 iBlow；006B 只影响当前动作的
	# 仙术演出，不能泄漏到下一名战斗者。
	_blow_displacement = 0
	var result := _execute_enemy_action(entry) if entry.is_enemy else _execute_player_action(entry)
	_check_battle_result()
	result.battle_result = battle_result
	if battle_result == BattleResult.ONGOING and _queue_cursor >= action_queue.size():
		_end_turn_pending = true
	_apply_battle_cleanup_if_needed()
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


## 按 SDLPal `PAL_BattleWon()` 领取一次胜利奖励并修改正式会话。
## 只有胜利后可调用；重复调用返回同一报告，不会重复增加金钱、经验或恢复数值。
func claim_victory_rewards() -> RewardResult:
	if battle_result != BattleResult.VICTORY:
		return null
	_apply_battle_cleanup_if_needed()
	if reward_result != null:
		return reward_result
	var reward := RewardResult.new()
	reward.experience = experience_gained
	reward.cash = cash_gained
	session.cash += cash_gained
	for enemy in enemies:
		if enemy.script_on_battle_end > 0:
			reward.post_battle_scripts.append(enemy.script_on_battle_end)
	for player in players:
		var role_index := player.role_index
		# PAL_BattleWon 不给战斗结束时仍倒下的角色经验、升级仙术或隐藏成长。
		if _role_hp(role_index) <= 0:
			continue
		var old_hp := session.role_hp[role_index]
		var old_mp := session.role_mp[role_index]
		var old_stats := _role_stats_snapshot(role_index)
		session.role_experience[role_index] += experience_gained
		_apply_primary_level_ups(role_index)
		var new_stats := _role_stats_snapshot(role_index)
		if old_stats[0] != new_stats[0]:
			var level_up := LevelUpResult.new()
			level_up.role_index = role_index
			level_up.old_hp = old_hp
			level_up.old_mp = old_mp
			level_up.new_hp = session.role_hp[role_index]
			level_up.new_mp = session.role_mp[role_index]
			level_up.old_stats = old_stats
			level_up.new_stats = new_stats
			reward.level_ups.append(level_up)
		if database.level_progression != null:
			for magic_object_id in database.level_progression.magic_objects_for_level(role_index, session.role_levels[role_index]):
				if not session.add_magic(role_index, magic_object_id):
					continue
				var learned := LearnedMagicResult.new()
				learned.role_index = role_index
				learned.magic_object_id = magic_object_id
				reward.learned_magics.append(learned)
	for enemy_index in range(enemies.size()):
		var enemy := enemies[enemy_index]
		if enemy.script_on_battle_end <= 0:
			continue
		var script_result := ActionResult.new()
		script_result.action_type = ActionType.SCRIPT
		script_result.actor_is_enemy = true
		script_result.actor_index = enemy_index
		var outcome := _run_enemy_battle_script(enemy.script_on_battle_end, enemy_index, script_result)
		enemy.script_on_battle_end = int(outcome.get("cursor", enemy.script_on_battle_end))
		reward.script_events.append_array(script_result.script_events)
	_recover_party_after_victory()
	reward_result = reward
	return reward


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
	_reserved_items.clear()
	_cooperative_magic_executed = false
	_cooperative_contributors = PackedInt32Array()
	for player in players:
		player.action_type = -1
		player.action_id = 0
		player.target_index = -1
		player.defending = false
	_skip_players_without_commands()
	if _auto_battle:
		_assign_auto_battle_commands()
		return
	_accepting_commands = _command_cursor < players.size()
	if not _accepting_commands:
		build_action_queue()


func _assign_auto_battle_commands() -> void:
	while _command_cursor < players.size():
		var party_index := _command_cursor
		var player := players[party_index]
		if player.action_type < 0:
			var magic_object_id := _pick_auto_magic(player.role_index)
			if magic_object_id > 0:
				var object := database.magic_object_definition(magic_object_id)
				var definition := database.magic_definition_for_object(magic_object_id)
				player.action_type = ActionType.MAGIC
				player.action_id = magic_object_id
				player.target_index = -1 if object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD] else _find_alive_enemy_from(player.previous_target_index)
			else:
				_assign_attack(player, player.previous_target_index)
		_command_cursor += 1
		_skip_players_without_commands()
	build_action_queue()


func _pick_auto_magic(role_index: int) -> int:
	if role_index < 0 or role_index >= session.learned_magics_by_role.size() or session.status_rounds_for(role_index, GameSession.STATUS_SILENCE) > 0:
		return 0
	var selected_object_id := 0
	var max_power := 0
	for magic_object_id in session.learned_magics_by_role[role_index]:
		var object := database.magic_object_definition(magic_object_id)
		var definition := database.magic_definition_for_object(magic_object_id)
		if object == null or definition == null or not object.is_used_on_enemy() or not object.is_usable_in_battle():
			continue
		var base_damage := _signed_word(definition.base_damage)
		if definition.mp_cost == 1 or definition.mp_cost > session.role_mp[role_index] or base_damage <= 0 or not _magic_effect_is_supported(object, definition):
			continue
		var power := base_damage + _random.next_int(0, 9999)
		if power > max_power:
			max_power = power
			selected_object_id = magic_object_id
	return selected_object_id


func _advance_command_cursor() -> void:
	_command_cursor += 1
	_skip_players_without_commands()
	if _command_cursor >= players.size():
		build_action_queue()


func _assign_repeated_command(party_index: int) -> void:
	var player := players[party_index]
	match player.previous_action_type:
		ActionType.DEFEND:
			_assign_defend(player, party_index)
		ActionType.MAGIC:
			_assign_repeated_magic(player, party_index)
		ActionType.COOPERATIVE_MAGIC:
			_assign_repeated_cooperative_magic(player)
		ActionType.USE_ITEM:
			_assign_repeated_use_item(player, party_index)
		ActionType.THROW_ITEM:
			_assign_repeated_throw_item(player)
		ActionType.FLEE:
			player.action_type = ActionType.FLEE
			player.action_id = 0
			player.target_index = -1
		_:
			# 官方 prevAction 初始为 Pass；重复第一回合时会转成普通攻击。
			_assign_attack(player, player.previous_target_index)


func _assign_repeated_magic(player: PlayerState, party_index: int) -> void:
	var object := database.magic_object_definition(player.previous_action_id)
	var definition := database.magic_definition_for_object(player.previous_action_id)
	if object == null or definition == null or not can_pending_player_use_magic(player.previous_action_id):
		# fight.c::PAL_BattleCommitAction：攻击仙术无效时普攻，恢复/辅助仙术无效时防御。
		if object != null and not object.is_used_on_enemy():
			_assign_defend(player, party_index)
		else:
			_assign_attack(player, player.previous_target_index)
		return
	player.action_type = ActionType.MAGIC
	player.action_id = player.previous_action_id
	if definition.magic_type == PalMagicDefinition.TYPE_TRANCE:
		player.target_index = party_index
	elif object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PARTY, PalMagicDefinition.TYPE_SUMMON]:
		player.target_index = -1
	elif object.is_used_on_enemy():
		player.target_index = _find_alive_enemy_from(player.previous_target_index)
	else:
		player.target_index = player.previous_target_index if player.previous_target_index >= 0 and player.previous_target_index < players.size() else party_index


func _assign_repeated_cooperative_magic(player: PlayerState) -> void:
	if not can_pending_player_use_cooperative_magic() or pending_cooperative_magic_object_id() != player.previous_action_id:
		_assign_attack(player, player.previous_target_index)
		return
	var object := database.magic_object_definition(player.previous_action_id)
	var definition := database.magic_definition_for_object(player.previous_action_id)
	player.action_type = ActionType.COOPERATIVE_MAGIC
	player.action_id = player.previous_action_id
	if object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_SUMMON]:
		player.target_index = -1
	else:
		player.target_index = _find_alive_enemy_from(player.previous_target_index)
	_cooperative_contributors = PackedInt32Array()
	for candidate_index in range(players.size()):
		if _is_player_healthy_for_cooperation(candidate_index):
			_cooperative_contributors.append(candidate_index)


func _assign_repeated_use_item(player: PlayerState, party_index: int) -> void:
	var item := database.item_definition(player.previous_action_id)
	if item == null or not can_pending_player_use_item(player.previous_action_id):
		# 官方把已耗尽的使用物品降级为防御。
		_assign_defend(player, party_index)
		return
	player.action_type = ActionType.USE_ITEM
	player.action_id = player.previous_action_id
	player.target_index = -1 if item.applies_to_all() else (player.previous_target_index if player.previous_target_index >= 0 and player.previous_target_index < players.size() else party_index)
	if item.is_consuming():
		_reserve_item(player.action_id)


func _assign_repeated_throw_item(player: PlayerState) -> void:
	var item := database.item_definition(player.previous_action_id)
	if item == null or not can_pending_player_throw_item(player.previous_action_id):
		# 官方把已耗尽的投掷物品降级为普通攻击。
		_assign_attack(player, player.previous_target_index)
		return
	player.action_type = ActionType.THROW_ITEM
	player.action_id = player.previous_action_id
	player.target_index = -1 if item.applies_to_all() else _find_alive_enemy_from(player.previous_target_index)
	_reserve_item(player.action_id)


func _assign_attack(player: PlayerState, preferred_target: int) -> void:
	player.action_type = ActionType.ATTACK
	player.action_id = 0
	player.target_index = -1 if session.can_attack_all(player.role_index, database.player_roles) else _find_alive_enemy_from(preferred_target)


func _assign_defend(player: PlayerState, party_index: int) -> void:
	player.action_type = ActionType.DEFEND
	player.action_id = 0
	player.target_index = party_index


func _skip_players_without_commands() -> void:
	while _command_cursor < players.size():
		var player := players[_command_cursor]
		if _role_hp(player.role_index) <= 0:
			if session.status_rounds_for(player.role_index, GameSession.STATUS_PUPPET) > 0:
				player.action_type = ActionType.ATTACK
				player.target_index = -1 if session.can_attack_all(player.role_index, database.player_roles) else _find_alive_enemy_from(0)
			else:
				player.action_type = ActionType.PASS
				player.target_index = -1
		elif session.status_rounds_for(player.role_index, GameSession.STATUS_SLEEP) > 0 or session.status_rounds_for(player.role_index, GameSession.STATUS_PARALYZED) > 0:
			player.action_type = ActionType.PASS
			player.target_index = -1
		elif session.status_rounds_for(player.role_index, GameSession.STATUS_CONFUSED) > 0:
			player.action_type = ActionType.PASS if _is_player_dying(player.role_index) else ActionType.ATTACK_MATE
			player.target_index = -1
		else:
			break
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
	if player.action_type == ActionType.PASS:
		entry.dexterity = 0
		return entry
	var dexterity := session.dexterity_for(player.role_index)
	if session.status_rounds_for(player.role_index, GameSession.STATUS_HASTE) > 0:
		dexterity = mini(999, dexterity * 3)
	if player.action_type == ActionType.COOPERATIVE_MAGIC:
		dexterity *= 10
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
	if _cooperative_magic_executed:
		result.skipped = true
		result.summary = "%s已参与本回合合击" % _role_name(player.role_index)
		return result
	if _role_hp(player.role_index) <= 0 and session.status_rounds_for(player.role_index, GameSession.STATUS_PUPPET) == 0:
		_release_player_item_reservation(player)
		result.skipped = true
		result.summary = "倒下的队员无法行动"
		return result
	if player.action_type == ActionType.PASS:
		result.skipped = true
		result.summary = "%s本回合无法行动" % _role_name(player.role_index)
		return result
	if player.action_type == ActionType.ATTACK_MATE:
		_execute_player_attack_mate(entry.combatant_index, result)
		return result
	if player.action_type == ActionType.DEFEND:
		player.defending = true
		result.summary = "%s进入防御" % _role_name(player.role_index)
		return result
	if player.action_type == ActionType.MAGIC:
		_execute_player_magic(player, result)
		return result
	if player.action_type == ActionType.COOPERATIVE_MAGIC:
		_execute_player_cooperative_magic(player, result)
		return result
	if player.action_type == ActionType.USE_ITEM:
		_execute_player_use_item(player, result)
		return result
	if player.action_type == ActionType.THROW_ITEM:
		_execute_player_throw_item(player, result)
		return result
	if player.action_type == ActionType.FLEE:
		_execute_player_flee(player, result)
		return result
	if player.action_type != ActionType.ATTACK:
		result.skipped = true
		result.summary = "未支持的玩家指令"
		return result
	if session.can_attack_all(player.role_index, database.player_roles):
		_execute_player_attack_all(player, result)
	else:
		var target_index := _find_alive_enemy_from(player.target_index)
		if target_index < 0:
			result.skipped = true
			result.summary = "没有可攻击目标"
			return result
		var attack_times := 2 if session.status_rounds_for(player.role_index, GameSession.STATUS_DUAL_ATTACK) > 0 else 1
		for attack_index in range(attack_times):
			if not enemies[target_index].is_alive():
				break
			var hit := _player_single_hit(player, target_index)
			hit.attack_sequence = attack_index
			result.hits.append(hit)
		var total_damage := 0
		var critical := false
		for hit in result.hits:
			total_damage += hit.damage
			critical = critical or hit.critical
		result.summary = "%s攻击敌人，造成%d点伤害%s" % [_role_name(player.role_index), total_damage, "（暴击）" if critical else ""]
	return result


func _execute_player_magic(player: PlayerState, result: ActionResult) -> void:
	var object := database.magic_object_definition(player.action_id)
	var definition := database.magic_definition_for_object(player.action_id)
	result.magic_object_id = player.action_id
	var actor_party_index := player.party_index
	result.target_index = actor_party_index if definition != null and definition.magic_type == PalMagicDefinition.TYPE_TRANCE else player.target_index
	if object == null or definition == null or not _magic_effect_is_supported(object, definition):
		result.unsupported = true
		result.summary = "该仙术的状态或脚本效果尚未接入"
		return
	if definition.mp_cost > session.role_mp[player.role_index]:
		result.unsupported = true
		result.summary = "%s真气不足" % _role_name(player.role_index)
		return
	result.mp_cost = definition.mp_cost
	# 原版自动战斗仍检查当前 MP 是否足够，但执行时不扣除 MP。
	if not _auto_battle:
		session.increase_role_hp_mp(player.role_index, 0, -definition.mp_cost)
	var use_outcome: Dictionary = _run_battle_effect_script(object.script_on_use, false, false, actor_party_index, result)
	if not bool(use_outcome.get("success", true)):
		result.summary = "%s施展%s失败" % [_role_name(player.role_index), database.get_word(player.action_id)]
		return
	if object.is_used_on_enemy():
		_run_battle_effect_script(object.script_on_success, false, true, result.target_index, result)
		var target_indices := living_enemy_indices() if result.target_index < 0 else PackedInt32Array([_find_alive_enemy_from(result.target_index)])
		if _signed_word(definition.base_damage) > 0:
			for target_index in target_indices:
				if target_index < 0:
					continue
				var damage := _calculate_player_magic_damage(player.role_index, target_index, definition)
				result.hits.append(_apply_enemy_damage(target_index, maxi(1, damage), false))
	else:
		_run_battle_effect_script(object.script_on_success, false, false, result.target_index, result)
	result.summary = "%s施展%s" % [_role_name(player.role_index), database.get_word(player.action_id)]


func _execute_player_cooperative_magic(player: PlayerState, result: ActionResult) -> void:
	var object := database.magic_object_definition(player.action_id)
	var definition := database.magic_definition_for_object(player.action_id)
	result.magic_object_id = player.action_id
	result.target_index = player.target_index
	result.contributor_indices = _cooperative_contributors.duplicate()
	_cooperative_magic_executed = true
	if object == null or definition == null or result.contributor_indices.size() <= 1:
		result.unsupported = true
		result.summary = "合击条件已经失效"
		return
	# PAL_CLASSIC 合击消耗的是每名贡献者的 HP，而非发动者 MP；最低保留 1 点体力。
	result.cooperative_hp_cost = definition.mp_cost
	var combined_strength := 0
	for party_index in result.contributor_indices:
		if party_index < 0 or party_index >= players.size():
			continue
		var role_index := players[party_index].role_index
		combined_strength += session.attack_strength_for(role_index)
		combined_strength += session.magic_strength_for(role_index)
		session.role_hp[role_index] = maxi(1, session.role_hp[role_index] - definition.mp_cost)
	combined_strength /= 4
	var target_indices := living_enemy_indices()
	if player.target_index >= 0:
		var resolved_target := _find_alive_enemy_from(player.target_index)
		result.target_index = resolved_target
		target_indices = PackedInt32Array([resolved_target])
	for target_index in target_indices:
		if target_index < 0:
			continue
		var damage := _calculate_cooperative_magic_damage(combined_strength, target_index, definition)
		result.hits.append(_apply_enemy_damage(target_index, maxi(1, damage), false))
	result.summary = "%s发动%s合击" % [_role_name(player.role_index), database.get_word(player.action_id)]


func _calculate_cooperative_magic_damage(combined_strength: int, target_index: int, definition: PalMagicDefinition) -> int:
	var enemy := enemies[target_index].definition
	var damage := calculate_base_damage(combined_strength, _effective_enemy_defense(enemy)) / 4
	damage += _signed_word(definition.base_damage)
	if definition.elemental != 0:
		var resistance := enemy.poison_resistance if definition.elemental > PalBattlefield.ELEMENT_COUNT else enemy.elemental_resistances[definition.elemental - 1]
		damage = int(damage * (10.0 - float(resistance))) / 5
		if definition.elemental <= PalBattlefield.ELEMENT_COUNT:
			var battlefield := database.battlefield_definition(battlefield_id)
			var field_effect := battlefield.magic_effects[definition.elemental - 1] if battlefield != null and battlefield.magic_effects.size() >= definition.elemental else 0
			damage = int(damage * (10.0 + field_effect) / 10.0)
	return damage


func _calculate_player_magic_damage(role_index: int, target_index: int, definition: PalMagicDefinition) -> int:
	var enemy := enemies[target_index].definition
	var magic_strength := session.magic_strength_for(role_index)
	magic_strength = int(magic_strength * _random.next_float(10.0, 11.0) / 10.0)
	var defense := _effective_enemy_defense(enemy)
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
	if not _battle_effect_script_is_supported(object.script_on_use) or not _battle_effect_script_is_supported(object.script_on_success):
		return false
	if object.is_used_on_enemy():
		return definition.magic_type in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_SUMMON] and (_signed_word(definition.base_damage) > 0 or object.script_on_use > 0 or object.script_on_success > 0)
	return definition.magic_type in [PalMagicDefinition.TYPE_APPLY_TO_PLAYER, PalMagicDefinition.TYPE_APPLY_TO_PARTY, PalMagicDefinition.TYPE_TRANCE] and (object.script_on_use > 0 or object.script_on_success > 0)


func _battle_effect_script_is_supported(entry_index: int) -> bool:
	if entry_index == 0:
		return true
	var pending: Array[int] = [entry_index]
	var visited: Dictionary = {}
	var inspected := 0
	while not pending.is_empty():
		var cursor: int = pending.pop_back()
		while cursor != 0:
			if cursor < 0 or cursor >= database.scripts.size():
				return false
			if visited.has(cursor):
				break
			visited[cursor] = true
			inspected += 1
			if inspected > 512:
				return false
			var entry := database.scripts[cursor]
			match entry.operation:
				0x0000, 0x0001:
					break
				0x0003:
					cursor = entry.operands[0]
				0x0006:
					pending.append(cursor + 1)
					cursor = entry.operands[1]
				0x002e:
					pending.append(cursor + 1)
					cursor = entry.operands[2]
				0x005d, 0x005e:
					pending.append(cursor + 1)
					cursor = entry.operands[1]
				0x0061, 0x0068:
					pending.append(cursor + 1)
					cursor = entry.operands[0]
				0x0033, 0x0034, 0x003a, 0x0074:
					pending.append(cursor + 1)
					cursor = entry.operands[0]
				0x0058, 0x0086:
					pending.append(cursor + 1)
					cursor = entry.operands[2]
				0x001e, 0x0064:
					pending.append(cursor + 1)
					cursor = entry.operands[1]
				0x0020:
					pending.append(cursor + 1)
					cursor = entry.operands[2]
				0x0005, 0x0019, 0x001b, 0x001c, 0x001d, 0x001f, 0x0021, 0x0022, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002f, 0x0030, 0x0031, 0x0035, 0x0039, 0x003b, 0x003c, 0x003d, 0x003e, 0x0041, 0x0047, 0x0055, 0x0056, 0x0057, 0x005a, 0x005b, 0x005c, 0x005f, 0x0060, 0x006a, 0x006b, 0x0088, 0x008a, 0x008d, 0x008f, 0x0092, 0xffff:
					cursor += 1
				_:
					return false
	return true


func _run_battle_effect_script(entry_index: int, actor_is_enemy: bool, _target_is_enemy: bool, target_index: int, result: ActionResult) -> Dictionary:
	if entry_index == 0:
		return {"cursor": 0, "success": true}
	if not _battle_effect_script_is_supported(entry_index):
		return {"cursor": entry_index, "success": false}
	var cursor := entry_index
	var success := true
	var dialog_position := 1
	var dialog_color := 0
	var dialog_portrait := 0
	for _step in range(256):
		if cursor == 0 or cursor < 0 or cursor >= database.scripts.size():
			return {"cursor": cursor, "success": success}
		var entry := database.scripts[cursor]
		match entry.operation:
			# PAL_RunTriggerScript 的 0000 保留原入口；0001 则把持久入口替换成下一行。
			0x0000:
				return {"cursor": entry_index, "success": success}
			0x0001:
				return {"cursor": cursor + 1, "success": success}
			0x0005:
				result.script_events.append(_script_event(ScriptEventType.CLEAR_DIALOG))
				cursor += 1
			# 无条件跳转与概率跳转；0006 在随机值大于等于阈值时走 operand[1]。
			0x0003:
				cursor = entry.operands[0]
			0x0006:
				cursor = entry.operands[1] if _random.next_int(1, 100) >= entry.operands[0] else cursor + 1
			# 按 PLAYERROLES 字段组增减基础属性；显式角色操作数从 1 开始。
			0x0019:
				var role_index := _battle_role_index(target_index, entry.operands[2])
				success = session.change_role_attribute(entry.operands[0], role_index, _signed_word(entry.operands[1]))
				cursor += 1
			0x001e:
				var delta := _signed_word(entry.operands[0])
				if delta < 0 and session.cash < -delta:
					cursor = entry.operands[1]
				else:
					session.cash += delta
					cursor += 1
			0x001f:
				var amount := _signed_word(entry.operands[1])
				amount = 1 if amount == 0 else amount
				var before := session.item_count(entry.operands[0])
				session.set_item_count(entry.operands[0], clampi(before + amount, 0, 99))
				var changed := session.item_count(entry.operands[0]) - before
				if changed > 0:
					result.script_events.append(_script_event(ScriptEventType.ITEM_GAIN, entry.operands[0], changed))
				cursor += 1
			0x0020:
				var amount := entry.operands[1] if entry.operands[1] > 0 else 1
				if session.item_count(entry.operands[0]) + session.equipped_item_count(entry.operands[0]) < amount:
					cursor = entry.operands[2]
				else:
					session.remove_item_including_equipment(entry.operands[0], amount)
					cursor += 1
			# 增减玩家 HP、MP 或两者；operand[0] 非零表示全队。
			0x001b, 0x001c, 0x001d:
				var hp_delta := _signed_word(entry.operands[1]) if entry.operation in [0x001b, 0x001d] else 0
				var mp_delta := _signed_word(entry.operands[1]) if entry.operation in [0x001c, 0x001d] else 0
				var changed := false
				for party_index in _battle_player_targets(target_index, entry.operands[0] != 0):
					changed = _apply_player_stat_delta(party_index, hp_delta, mp_delta, result) or changed
				if entry.operands[0] == 0 or entry.operation == 0x001b:
					success = changed
				cursor += 1
			# 对单个或全部敌人造成固定伤害。
			0x0021:
				var damaged := false
				for enemy_index in _battle_enemy_targets(target_index, entry.operands[0] != 0):
					result.hits.append(_apply_enemy_damage(enemy_index, entry.operands[1], false))
					damaged = true
				success = damaged
				cursor += 1
			# 按最大 HP 的十分比复活，并清除三级以下毒与临时状态。
			0x0022:
				var revived := false
				for party_index in _battle_player_targets(target_index, entry.operands[0] != 0):
					revived = _revive_player(party_index, entry.operands[1], result) or revived
				success = revived
				cursor += 1
			# 敌我下毒；加入毒槽时立即执行一次毒脚本，后续在回合末重复或推进。
			0x0028:
				for enemy_index in _battle_enemy_targets(target_index, entry.operands[0] != 0):
					_apply_poison_to_enemy(enemy_index, entry.operands[1], actor_is_enemy, result)
				cursor += 1
			0x0029:
				for party_index in _battle_player_targets(target_index, entry.operands[0] != 0):
					_apply_poison_to_player(party_index, entry.operands[1], actor_is_enemy, result)
				cursor += 1
			# 按毒对象或等级清除敌我毒槽。
			0x002a:
				for enemy_index in _battle_enemy_targets(target_index, entry.operands[0] != 0):
					enemies[enemy_index].poisons.erase(entry.operands[1])
				cursor += 1
			0x002b:
				for party_index in _battle_player_targets(target_index, entry.operands[0] != 0):
					session.cure_role_poison(players[party_index].role_index, entry.operands[1])
				cursor += 1
			0x002c:
				for party_index in _battle_player_targets(target_index, entry.operands[0] != 0):
					session.cure_role_poisons_by_level(players[party_index].role_index, entry.operands[1], database)
				cursor += 1
			# 设置玩家/敌人状态；敌人抵抗时按 operand[2] 跳转。
			0x002d:
				var party_index := _battle_player_target(target_index)
				success = party_index >= 0 and session.set_role_status(players[party_index].role_index, entry.operands[0], entry.operands[1])
				cursor += 1
			0x002e:
				var enemy_index := _battle_enemy_target(target_index)
				if enemy_index >= 0 and _random.next_int(0, 9) > enemies[enemy_index].definition.poison_resistance:
					if entry.operands[0] >= 0 and entry.operands[0] < GameSession.STATUS_COUNT:
						enemies[enemy_index].status_rounds[entry.operands[0]] = entry.operands[1]
					cursor += 1
				else:
					cursor = entry.operands[2]
			0x002f:
				var party_index := _battle_player_target(target_index)
				if party_index >= 0:
					session.remove_role_status(players[party_index].role_index, entry.operands[0])
				cursor += 1
			# 临时属性与战斗 Sprite 都写入第七个装备效果槽，战斗结束由统一清理恢复。
			0x0030:
				var role_index := _battle_role_index(target_index, entry.operands[2])
				var base_value := _base_role_attribute(entry.operands[0], role_index)
				var temporary_value := int(float(base_value * _signed_word(entry.operands[1])) / 100.0)
				success = session.set_equipment_effect(GameSession.EQUIPMENT_SLOT_COUNT, entry.operands[0], role_index, temporary_value)
				cursor += 1
			0x0031:
				var role_index := _battle_role_index(target_index, 0)
				success = session.set_equipment_effect(GameSession.EQUIPMENT_SLOT_COUNT, GameSession.EQUIPMENT_EFFECT_BATTLE_SPRITE, role_index, entry.operands[0])
				if success:
					result.script_events.append(_script_event(ScriptEventType.PLAYER_SPRITE, role_index, entry.operands[0]))
				cursor += 1
			# 收妖与炼物：经典版从 1..收妖值随机后限制到商店 0 的九个物品。
			0x0033:
				var enemy_index := _battle_enemy_target(target_index)
				if enemy_index >= 0 and enemies[enemy_index].definition.collect_value != 0:
					session.collect_value += enemies[enemy_index].definition.collect_value
					cursor += 1
				else:
					cursor = entry.operands[0]
			0x0034:
				var store := database.store_definition(0)
				if session.collect_value <= 0 or store == null:
					cursor = entry.operands[0]
				else:
					var consumed := mini(9, _random.next_int(1, session.collect_value))
					var item_id := store.item_ids[consumed - 1] if consumed <= store.item_ids.size() else 0
					if item_id <= 0:
						cursor = entry.operands[0]
					else:
						session.collect_value -= consumed
						var before := session.item_count(item_id)
						session.set_item_count(item_id, mini(99, before + 1))
						result.script_events.append(_script_event(ScriptEventType.ITEM_GAIN, item_id, session.item_count(item_id) - before))
						cursor += 1
			0x0035:
				result.script_events.append(_script_event(ScriptEventType.SCREEN_SHAKE, entry.operands[0], entry.operands[1] if entry.operands[1] > 0 else 4))
				cursor += 1
			0x003b, 0x003c, 0x003d, 0x003e:
				if entry.operation == 0x003b:
					dialog_position = 2
					dialog_color = entry.operands[0]
					dialog_portrait = 0
				else:
					dialog_position = entry.operation - 0x003c
					dialog_portrait = entry.operands[0] if entry.operation != 0x003e else 0
					dialog_color = entry.operands[1] if entry.operation != 0x003e else entry.operands[0]
				result.script_events.append(_script_event(ScriptEventType.DIALOG_START, dialog_position, dialog_color, dialog_portrait))
				cursor += 1
			0x0047:
				result.script_events.append(_script_event(ScriptEventType.SOUND, entry.operands[0]))
				cursor += 1
			# 从目标敌人吸取固定 HP 给当前施法玩家。
			0x0039:
				var enemy_index := _battle_enemy_target(target_index)
				if enemy_index >= 0:
					result.hits.append(_apply_enemy_damage(enemy_index, entry.operands[0], false))
					if not actor_is_enemy and result.actor_index >= 0 and result.actor_index < players.size():
						_apply_player_stat_delta(result.actor_index, entry.operands[0], 0, result)
				cursor += 1
			0x003a:
				if is_boss_battle:
					cursor = entry.operands[0]
				else:
					battle_result = BattleResult.FLED
					_accepting_commands = false
					cursor += 1
			0x0041:
				success = false
				cursor += 1
			0x0056:
				var role_index := _battle_role_index(target_index, entry.operands[1])
				session.remove_magic(role_index, entry.operands[0])
				cursor += 1
			0x0055:
				var role_index := _battle_role_index(target_index, entry.operands[1])
				session.add_magic(role_index, entry.operands[0])
				cursor += 1
			0x0057:
				var role_index := _battle_role_index(target_index, 0)
				var magic := database.magic_definition_for_object(entry.operands[0])
				if magic != null and role_index >= 0 and role_index < session.role_mp.size():
					magic.base_damage = session.role_mp[role_index] * (entry.operands[1] if entry.operands[1] > 0 else 8)
					session.role_mp[role_index] = 0
				else:
					success = false
				cursor += 1
			0x0058:
				cursor = entry.operands[2] if session.item_count(entry.operands[0]) < _signed_word(entry.operands[1]) else cursor + 1
			0x005a:
				var role_index := _battle_role_index(target_index, 0)
				if role_index >= 0 and role_index < session.role_hp.size():
					session.role_hp[role_index] /= 2
				else:
					success = false
				cursor += 1
			0x005b:
				var enemy_index := _battle_enemy_target(target_index)
				if enemy_index >= 0:
					var damage := mini(enemies[enemy_index].hp / 2 + 1, entry.operands[0])
					result.hits.append(_apply_enemy_damage(enemy_index, damage, false))
				cursor += 1
			0x005c:
				_hiding_turns = entry.operands[0]
				result.script_events.append(_script_event(ScriptEventType.HIDING, _hiding_turns))
				cursor += 1
			# 指定毒不存在时跳转；005D 检查玩家，005E 检查敌人。
			0x005d:
				var party_index := _battle_player_target(target_index)
				cursor = entry.operands[1] if party_index < 0 or not session.role_has_poison(players[party_index].role_index, entry.operands[0]) else cursor + 1
			0x005e:
				var enemy_index := _battle_enemy_target(target_index)
				cursor = entry.operands[1] if enemy_index < 0 or not enemies[enemy_index].poisons.has(entry.operands[0]) else cursor + 1
			# 立即击倒玩家或敌人。
			0x005f:
				var party_index := _battle_player_target(target_index)
				if party_index >= 0:
					_apply_player_stat_delta(party_index, -_role_hp(players[party_index].role_index), 0, result)
				cursor += 1
			0x0060:
				var enemy_index := _battle_enemy_target(target_index)
				if enemy_index >= 0:
					result.hits.append(_apply_enemy_damage(enemy_index, enemies[enemy_index].hp, false))
				cursor += 1
			# 玩家没有普通毒时跳转；99 级装备持续效果不计入。
			0x0061:
				var party_index := _battle_player_target(target_index)
				cursor = entry.operands[0] if party_index < 0 or not session.role_has_poison_by_level(players[party_index].role_index, 0, database) else cursor + 1
			0x0064:
				var enemy_index := _battle_enemy_target(target_index)
				cursor = entry.operands[1] if enemy_index < 0 or enemies[enemy_index].hp * 100 > enemies[enemy_index].max_hp * entry.operands[0] else cursor + 1
			# 当前效果由敌方行动触发时跳转，用于敌我共用的成功脚本。
			0x0068:
				cursor = entry.operands[0] if actor_is_enemy else cursor + 1
			0x006a:
				var enemy_index := _battle_enemy_target(target_index)
				# 官方偷窃没有修改 g_fScriptSuccess；没有可偷物或概率失败仍会正常
				# 结束本段使用脚本，不能反向取消动作或后续指令。
				_steal_from_enemy(enemy_index, entry.operands[0], result)
				cursor += 1
			0x006b:
				_blow_displacement = _signed_word(entry.operands[0])
				result.script_events.append(_script_event(ScriptEventType.BLOW, _blow_displacement))
				cursor += 1
			0x0074:
				cursor = entry.operands[0] if not session.is_party_full_hp() else cursor + 1
			0x0086:
				cursor = entry.operands[2] if not session.meets_equipped_item_requirement(entry.operands[0], entry.operands[1]) else cursor + 1
			0x0088:
				var spent := mini(5000, session.cash)
				session.cash -= spent
				var magic := database.magic_definition_for_object(entry.operands[0])
				if magic != null:
					magic.base_damage = spent * 2 / 5
				else:
					success = false
				cursor += 1
			0x008a:
				# 若数据在战斗效果中触发，本场从下一轮起也立即进入官方自动选择。
				_auto_battle = true
				cursor += 1
			0x008d:
				var role_index := _battle_role_index(target_index, 0)
				success = session.level_up_role(role_index, entry.operands[0], Callable(_random, "next_int"))
				cursor += 1
			0x008f:
				session.cash /= 2
				cursor += 1
			0x0092:
				result.script_events.append(_script_event(ScriptEventType.PRE_MAGIC, entry.operands[0] - 1 if entry.operands[0] > 0 else -1))
				cursor += 1
			0xffff:
				result.script_events.append(_script_event(ScriptEventType.DIALOG_MESSAGE, entry.operands[0], dialog_position, dialog_color))
				cursor += 1
			_:
				return {"cursor": entry_index, "success": false}
	return {"cursor": cursor, "success": false}


func _battle_role_index(target_index: int, explicit_one_based_role: int) -> int:
	if explicit_one_based_role > 0:
		return explicit_one_based_role - 1
	var party_index := _battle_player_target(target_index)
	return players[party_index].role_index if party_index >= 0 else -1


func _base_role_attribute(group_index: int, role_index: int) -> int:
	if role_index < 0 or role_index >= PalPlayerRoles.ROLE_COUNT:
		return 0
	match group_index:
		6:
			return session.role_levels[role_index]
		7:
			return session.role_max_hp[role_index]
		8:
			return session.role_max_mp[role_index]
		9:
			return session.role_hp[role_index]
		10:
			return session.role_mp[role_index]
		17:
			return session.role_attack_strength[role_index]
		18:
			return session.role_magic_strength[role_index]
		19:
			return session.role_defense[role_index]
		20:
			return session.role_dexterity[role_index]
		21:
			return session.role_flee_rate[role_index]
		_:
			return 0


func _steal_from_enemy(enemy_index: int, steal_rate: int, result: ActionResult) -> bool:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return false
	var enemy := enemies[enemy_index]
	var stolen_object_id := 0
	var amount := 0
	if enemy.steal_item_count > 0 and (steal_rate == 0 or _random.next_int(0, 10) <= steal_rate):
		stolen_object_id = enemy.steal_item
		if enemy.steal_item == 0:
			amount = enemy.steal_item_count / _random.next_int(2, 3)
			enemy.steal_item_count -= amount
			session.cash += amount
		else:
			var before := session.item_count(enemy.steal_item)
			enemy.steal_item_count -= 1
			session.set_item_count(enemy.steal_item, mini(99, before + 1))
			amount = session.item_count(enemy.steal_item) - before
	# 006A 的专用掠过动作无论是否偷到东西都会播放；第三个字段保留目标敌人。
	result.script_events.append(_script_event(ScriptEventType.STEAL, stolen_object_id, amount, enemy_index))
	return amount > 0


func _battle_player_target(target_index: int) -> int:
	if target_index >= 0 and target_index < players.size():
		return target_index
	return 0 if not players.is_empty() else -1


func _battle_enemy_target(target_index: int) -> int:
	return target_index if target_index >= 0 and target_index < enemies.size() and enemies[target_index].is_alive() else -1


func _battle_player_targets(target_index: int, apply_all: bool) -> PackedInt32Array:
	if apply_all:
		var all_targets := PackedInt32Array()
		for party_index in range(players.size()):
			all_targets.append(party_index)
		return all_targets
	var target := _battle_player_target(target_index)
	return PackedInt32Array([target]) if target >= 0 else PackedInt32Array()


func _battle_enemy_targets(target_index: int, apply_all: bool) -> PackedInt32Array:
	if apply_all:
		return living_enemy_indices()
	var target := _battle_enemy_target(target_index)
	return PackedInt32Array([target]) if target >= 0 else PackedInt32Array()


func _revive_player(party_index: int, tenths_of_max_hp: int, result: ActionResult) -> bool:
	if party_index < 0 or party_index >= players.size():
		return false
	var role_index := players[party_index].role_index
	if not session.revive_role(role_index, tenths_of_max_hp, database):
		return false
	var hit := _player_hit_for_result(result, party_index)
	hit.healing += session.role_hp[role_index]
	return true


func _apply_poison_to_player(party_index: int, poison_id: int, actor_is_enemy: bool, result: ActionResult) -> bool:
	if party_index < 0 or party_index >= players.size():
		return false
	var role_index := players[party_index].role_index
	var definition := database.poison_definition(poison_id)
	if definition == null or session.role_has_poison(role_index, poison_id) or _random.next_int(1, 100) <= session.poison_resistance_for(role_index):
		return false
	if not _battle_effect_script_is_supported(definition.player_script) or not session.add_role_poison(role_index, poison_id, definition.player_script):
		return false
	var outcome := _run_battle_effect_script(definition.player_script, actor_is_enemy, false, party_index, result)
	session.set_role_poison_cursor(role_index, poison_id, int(outcome.get("cursor", definition.player_script)))
	return bool(outcome.get("success", true))


func _apply_poison_to_enemy(enemy_index: int, poison_id: int, actor_is_enemy: bool, result: ActionResult) -> bool:
	if enemy_index < 0 or enemy_index >= enemies.size() or not enemies[enemy_index].is_alive():
		return false
	var enemy := enemies[enemy_index]
	var definition := database.poison_definition(poison_id)
	if definition == null or enemy.poisons.has(poison_id) or enemy.poisons.size() >= GameSession.MAX_POISONS or _random.next_int(0, 9) < enemy.definition.poison_resistance:
		return false
	if not _battle_effect_script_is_supported(definition.enemy_script):
		return false
	enemy.poisons[poison_id] = definition.enemy_script
	var outcome := _run_battle_effect_script(definition.enemy_script, actor_is_enemy, true, enemy_index, result)
	if enemy.poisons.has(poison_id):
		enemy.poisons[poison_id] = int(outcome.get("cursor", definition.enemy_script))
	return bool(outcome.get("success", true))


func _execute_player_use_item(player: PlayerState, result: ActionResult) -> void:
	var item := database.item_definition(player.action_id)
	result.item_object_id = player.action_id
	result.target_index = player.target_index
	_release_player_item_reservation(player)
	if item == null or session.item_count(player.action_id) <= 0 or not _battle_effect_script_is_supported(item.script_on_use):
		result.unsupported = true
		result.summary = "该物品已用完或效果尚未接入"
		return
	_run_battle_effect_script(item.script_on_use, false, false, player.target_index, result)
	if item.is_consuming():
		session.change_item_count(player.action_id, -1)
	result.summary = "%s使用%s" % [_role_name(player.role_index), database.get_word(player.action_id)]


func _execute_player_throw_item(player: PlayerState, result: ActionResult) -> void:
	var item := database.item_definition(player.action_id)
	result.item_object_id = player.action_id
	result.target_index = player.target_index
	_release_player_item_reservation(player)
	if item == null or session.item_count(player.action_id) <= 0 or not _throw_script_is_supported(item.script_on_throw):
		result.unsupported = true
		result.summary = "该投掷物已用完或效果尚未接入"
		return
	_run_supported_throw_script(item.script_on_throw, player, result)
	session.change_item_count(player.action_id, -1)
	result.summary = "%s投掷%s" % [_role_name(player.role_index), database.get_word(player.action_id)]


func _execute_player_flee(player: PlayerState, result: ActionResult) -> void:
	var enemy_strength := 0
	for enemy in enemies:
		if enemy.is_alive():
			enemy_strength += _signed_word(enemy.definition.dexterity) + (enemy.definition.level + 6) * 4
	enemy_strength = maxi(0, enemy_strength)
	result.flee_succeeded = not is_boss_battle and session.flee_rate_for(player.role_index) >= _random.next_int(0, enemy_strength)
	if result.flee_succeeded:
		battle_result = BattleResult.FLED
		_accepting_commands = false
		result.summary = "%s成功逃跑" % _role_name(player.role_index)
	else:
		result.summary = database.get_word(31)


func _throw_script_is_supported(entry_index: int) -> bool:
	var cursor := entry_index
	for _step in range(16):
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
				continue
			0x0042, 0x0066:
				var object := database.magic_object_definition(entry.operands[0])
				var definition := database.magic_definition_for_object(entry.operands[0])
				# 0042/0066 把仙术对象仅当作 FIRE 特效和伤害属性使用；部分暗器引用的
				# 对象没有“对敌使用”菜单标志，官方 PAL_BattleSimulateMagic 仍会正常伤敌。
				if object == null or definition == null or definition.magic_type not in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD]:
					return false
				cursor += 1
			0x0021:
				cursor += 1
			_:
				return false
	return false


func _run_supported_throw_script(entry_index: int, player: PlayerState, result: ActionResult) -> void:
	var cursor := entry_index
	for _step in range(16):
		if cursor == 0 or cursor < 0 or cursor >= database.scripts.size():
			return
		var entry := database.scripts[cursor]
		match entry.operation:
			0x0000, 0x0001:
				return
			0x0003:
				cursor = entry.operands[0]
				continue
			0x0042, 0x0066:
				var magic_object_id := entry.operands[0]
				var object := database.magic_object_definition(magic_object_id)
				var definition := database.magic_definition_for_object(magic_object_id)
				if object == null or definition == null:
					return
				var base_damage := entry.operands[1]
				if entry.operation == 0x0066:
					base_damage = entry.operands[1] * 5 + session.attack_strength_for(player.role_index) * _random.next_int(0, 3)
				var target_all := object.applies_to_all() or player.target_index < 0
				result.magic_object_id = magic_object_id
				result.target_index = -1 if target_all else player.target_index
				var target_indices := living_enemy_indices() if target_all else PackedInt32Array([_find_alive_enemy_from(player.target_index)])
				for target_index in target_indices:
					if target_index < 0:
						continue
					var damage := _calculate_simulated_magic_damage(base_damage, target_index, definition)
					if damage > 0:
						result.hits.append(_apply_enemy_damage(target_index, damage, false))
				cursor += 1
			0x0021:
				var target_indices := living_enemy_indices() if entry.operands[0] != 0 or player.target_index < 0 else PackedInt32Array([_find_alive_enemy_from(player.target_index)])
				for target_index in target_indices:
					if target_index >= 0:
						result.hits.append(_apply_enemy_damage(target_index, entry.operands[1], false))
				cursor += 1
			_:
				return


func _calculate_simulated_magic_damage(base_damage: int, target_index: int, definition: PalMagicDefinition) -> int:
	var enemy := enemies[target_index].definition
	var defense := maxi(0, _signed_word(enemy.defense) + (enemy.level + 6) * 4)
	var damage := calculate_base_damage(base_damage, defense) / 4 + _signed_word(definition.base_damage)
	if definition.elemental != 0:
		var resistance := enemy.poison_resistance if definition.elemental > PalBattlefield.ELEMENT_COUNT else enemy.elemental_resistances[definition.elemental - 1]
		damage = int(damage * (10.0 - float(resistance))) / 5
		if definition.elemental <= PalBattlefield.ELEMENT_COUNT:
			var battlefield := database.battlefield_definition(battlefield_id)
			var field_effect := battlefield.magic_effects[definition.elemental - 1] if battlefield != null and battlefield.magic_effects.size() >= definition.elemental else 0
			damage = int(damage * (10.0 + field_effect) / 10.0)
	return maxi(0, damage)


func _apply_player_stat_delta(party_index: int, hp_delta: int, mp_delta: int, result: ActionResult) -> bool:
	if party_index < 0 or party_index >= players.size():
		return false
	var role_index := players[party_index].role_index
	# PAL_IncreaseHPMP 不会让普通治疗复活已经倒下的角色。
	if _role_hp(role_index) <= 0:
		return false
	var old_hp := session.role_hp[role_index]
	var old_mp := session.role_mp[role_index]
	session.increase_role_hp_mp(role_index, hp_delta, mp_delta)
	var hp_change := session.role_hp[role_index] - old_hp
	var mp_change := session.role_mp[role_index] - old_mp
	if hp_change == 0 and mp_change == 0:
		return false
	var hit := _player_hit_for_result(result, party_index)
	hit.healing += maxi(0, hp_change)
	hit.damage += maxi(0, -hp_change)
	hit.mp_restored += maxi(0, mp_change)
	hit.defeated = session.role_hp[role_index] == 0
	return true


func _player_hit_for_result(result: ActionResult, party_index: int) -> Hit:
	for hit in result.hits:
		if not hit.target_is_enemy and hit.target_index == party_index:
			return hit
	var hit := Hit.new()
	hit.target_index = party_index
	result.hits.append(hit)
	return hit


func _execute_player_attack_mate(actor_index: int, result: ActionResult) -> void:
	var candidates := PackedInt32Array()
	for party_index in range(players.size()):
		if party_index != actor_index and _role_hp(players[party_index].role_index) > 0:
			candidates.append(party_index)
	if candidates.is_empty():
		result.skipped = true
		result.summary = "混乱角色没有可攻击的队友"
		return
	var target_index := candidates[_random.next_int(0, candidates.size() - 1)]
	var actor := players[actor_index]
	var target := players[target_index]
	var defense := session.defense_for(target.role_index)
	if target.defending:
		defense *= 2
	var damage := calculate_physical_damage(session.attack_strength_for(actor.role_index), defense, 2)
	if session.status_rounds_for(target.role_index, GameSession.STATUS_PROTECT) > 0:
		damage /= 2
	damage = maxi(1, damage)
	var hit := Hit.new()
	hit.target_index = target_index
	hit.damage = mini(_role_hp(target.role_index), damage)
	session.increase_role_hp_mp(target.role_index, -hit.damage, 0)
	hit.defeated = _role_hp(target.role_index) == 0
	result.target_index = target_index
	result.hits.append(hit)
	result.summary = "%s混乱中攻击%s" % [_role_name(actor.role_index), _role_name(target.role_index)]


func _execute_player_attack_all(player: PlayerState, result: ActionResult) -> void:
	var attack_times := 2 if session.status_rounds_for(player.role_index, GameSession.STATUS_DUAL_ATTACK) > 0 else 1
	for attack_index in range(attack_times):
		var critical := session.status_rounds_for(player.role_index, GameSession.STATUS_BRAVERY) > 0 or _random.next_int(0, 5) == 0
		var division := 1
		# SDLPal 固定按中、次前、最前、最后、次后的次序结算全体普攻。
		for enemy_index in [2, 1, 0, 4, 3]:
			if enemy_index >= enemies.size() or not enemies[enemy_index].is_alive():
				continue
			var enemy := enemies[enemy_index]
			var defense := _effective_enemy_defense(enemy.definition)
			var damage := calculate_physical_damage(session.attack_strength_for(player.role_index), defense, enemy.definition.physical_resistance)
			if critical:
				damage *= 3
			damage = maxi(1, damage / division)
			var hit := _apply_enemy_damage(enemy_index, damage, critical)
			hit.attack_sequence = attack_index
			result.hits.append(hit)
			division *= 2
	result.summary = "%s攻击全体敌人" % _role_name(player.role_index)


func _player_single_hit(player: PlayerState, target_index: int) -> Hit:
	var enemy := enemies[target_index]
	var defense := _effective_enemy_defense(enemy.definition)
	var damage := calculate_physical_damage(
		session.attack_strength_for(player.role_index),
		defense,
		enemy.definition.physical_resistance
	)
	damage += _random.next_int(1, 2)
	var critical := false
	if session.status_rounds_for(player.role_index, GameSession.STATUS_BRAVERY) > 0 or _random.next_int(0, 5) == 0:
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
	var was_alive := enemy.hp > 0
	enemy.hp = maxi(0, enemy.hp - damage)
	hit.defeated = enemy.hp == 0
	if was_alive and hit.defeated:
		experience_gained += enemy.definition.experience
		cash_gained += enemy.definition.cash
	return hit


func _effective_enemy_defense(definition: PalEnemyDefinition) -> int:
	if definition == null:
		return 0
	# fight.c 先把 16 位 WORD 防御加上等级修正，再以 WORD 保存结果；0xFFFA + 24 会回绕为 18。
	# GDScript 整数不会自动回绕，若直接相加会把绿叶小妖等负基础防御误读成六万多。
	return (definition.defense + (definition.level + 6) * 4) & 0xffff


func _execute_enemy_action(entry: QueueEntry) -> ActionResult:
	var result := ActionResult.new()
	result.actor_is_enemy = true
	result.actor_index = entry.combatant_index
	result.second_action = entry.is_second
	var enemy := enemies[entry.combatant_index]
	if _hiding_turns > 0:
		result.skipped = true
		result.summary = "队伍隐身，敌人无法行动"
		return result
	if enemy.script_on_ready > 0:
		var outcome := _run_enemy_battle_script(enemy.script_on_ready, entry.combatant_index, result)
		enemy.script_on_ready = int(outcome.get("cursor", enemy.script_on_ready))
		_check_battle_result()
		if battle_result != BattleResult.ONGOING:
			result.action_type = ActionType.SCRIPT
			result.summary = "敌人战斗脚本结束战斗"
			return result
	if not enemy.is_alive():
		result.skipped = true
		result.summary = "已被击倒的敌人无法行动"
		return result
	if enemy_status_rounds(entry.combatant_index, GameSession.STATUS_SLEEP) > 0 or enemy_status_rounds(entry.combatant_index, GameSession.STATUS_PARALYZED) > 0:
		result.skipped = true
		result.summary = "敌人因异常状态无法行动"
		return result
	if enemy_status_rounds(entry.combatant_index, GameSession.STATUS_CONFUSED) > 0:
		_execute_confused_enemy_attack(entry.combatant_index, result)
		return result
	var target_index := _select_random_living_player()
	if target_index < 0:
		result.skipped = true
		result.summary = "敌人没有可攻击目标"
		return result
	if enemy.magic != 0 and enemy_status_rounds(entry.combatant_index, GameSession.STATUS_SILENCE) == 0 and _random.next_int(0, 9) < enemy.magic_rate:
		_execute_enemy_magic(entry.combatant_index, target_index, result)
		return result
	var hit := _enemy_physical_hit(entry.combatant_index, target_index)
	result.hits.append(hit)
	# fight.c 在普通攻击未被自动防御或代挡后，按敌人 DATA 概率执行附带物品脚本。
	# 原版在进入脚本前还会额外做一次玩家毒抗检查，脚本中的 0029 会继续保留自身检查。
	if not hit.auto_defended and enemy.definition.attack_equivalent_item > 0 and enemy.definition.attack_equivalent_item_rate >= _random.next_int(1, 10) and session.poison_resistance_for(players[target_index].role_index) < _random.next_int(1, 100):
		var equivalent_item := database.item_definition(enemy.definition.attack_equivalent_item)
		if equivalent_item != null and _battle_effect_script_is_supported(equivalent_item.script_on_use):
			_run_battle_effect_script(equivalent_item.script_on_use, true, false, target_index, result)
	result.summary = "敌人攻击%s：%s" % [
		_role_name(players[target_index].role_index),
		("%s保护" % _role_name(players[hit.covering_index].role_index) if hit.covering_index >= 0 else "自动防御") if hit.auto_defended else "%d点伤害" % hit.damage,
	]
	return result


func _execute_confused_enemy_attack(enemy_index: int, result: ActionResult) -> void:
	var candidates := living_enemy_indices()
	if candidates.size() <= 1:
		result.skipped = true
		result.summary = "混乱敌人没有可攻击的同伴"
		return
	var target_index := enemy_index
	for _attempt in range(enemies.size() * 4):
		target_index = candidates[_random.next_int(0, candidates.size() - 1)]
		if target_index != enemy_index:
			break
	if target_index == enemy_index:
		result.skipped = true
		return
	var actor := enemies[enemy_index].definition
	var target := enemies[target_index].definition
	var attack := _signed_word(actor.attack_strength) + (actor.level + 6) * 6
	var defense := _signed_word(target.defense) + (target.level + 6) * 4
	var damage := calculate_base_damage(maxi(0, attack), maxi(0, defense)) * 2
	damage /= target.physical_resistance if target.physical_resistance != 0 else 1
	result.action_type = ActionType.ATTACK_MATE
	result.target_index = target_index
	result.hits.append(_apply_enemy_damage(target_index, maxi(1, damage), false))
	result.summary = "混乱敌人攻击同伴"


func _execute_enemy_magic(enemy_index: int, selected_target_index: int, result: ActionResult) -> void:
	var enemy := enemies[enemy_index]
	var magic_object_id := enemy.magic
	var object := database.magic_object_definition(magic_object_id)
	var definition := database.magic_definition_for_object(magic_object_id)
	result.action_type = ActionType.MAGIC
	result.magic_object_id = magic_object_id
	if magic_object_id == 0xffff:
		result.skipped = true
		result.summary = "敌人本轮法术为空"
		return
	if object == null or definition == null or not _enemy_magic_effect_is_supported(object, definition):
		result.unsupported = true
		result.summary = "该敌人仙术的状态或脚本效果尚未接入"
		return
	var target_all := definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PARTY]
	result.target_index = -1 if target_all else selected_target_index
	var use_outcome := _run_battle_effect_script(object.script_on_use, true, false, selected_target_index, result)
	if not bool(use_outcome.get("success", true)):
		result.summary = "敌人施展%s失败" % database.get_word(magic_object_id)
		return
	_run_battle_effect_script(object.script_on_success, true, false, selected_target_index, result)
	var target_indices := PackedInt32Array()
	if target_all:
		for party_index in range(players.size()):
			if _role_hp(players[party_index].role_index) > 0:
				target_indices.append(party_index)
	elif selected_target_index >= 0:
		target_indices.append(selected_target_index)
	if _signed_word(definition.base_damage) > 0:
		for party_index in target_indices:
			var auto_defended := _random.next_int(0, 2) == 0
			var damage := _calculate_enemy_magic_damage(enemy_index, party_index, definition)
			var role_index := players[party_index].role_index
			var divisor := (2 if players[party_index].defending else 1) * (2 if session.status_rounds_for(role_index, GameSession.STATUS_PROTECT) > 0 else 1) + (1 if auto_defended else 0)
			damage = maxi(0, int(damage / maxi(1, divisor)))
			result.hits.append(_apply_player_magic_damage(party_index, damage, auto_defended))
	result.summary = "敌人施展%s" % database.get_word(magic_object_id)


func _enemy_magic_effect_is_supported(object: PalMagicObjectDefinition, definition: PalMagicDefinition) -> bool:
	if not _battle_effect_script_is_supported(object.script_on_use) or not _battle_effect_script_is_supported(object.script_on_success):
		return false
	var supported_type := definition.magic_type in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PLAYER, PalMagicDefinition.TYPE_APPLY_TO_PARTY]
	return supported_type and (_signed_word(definition.base_damage) > 0 or object.script_on_use > 0 or object.script_on_success > 0)


func _calculate_enemy_magic_damage(enemy_index: int, party_index: int, definition: PalMagicDefinition) -> int:
	var enemy := enemies[enemy_index].definition
	var role_index := players[party_index].role_index
	var magic_strength := _signed_word(enemy.magic_strength) + (enemy.level + 6) * 6
	magic_strength = maxi(0, int(magic_strength * _random.next_float(10.0, 11.0) / 10.0))
	var damage := calculate_base_damage(magic_strength, session.defense_for(role_index)) / 4
	damage += _signed_word(definition.base_damage)
	if definition.elemental != 0:
		var resistance := session.poison_resistance_for(role_index) if definition.elemental > PalBattlefield.ELEMENT_COUNT else session.elemental_resistance_for(role_index, definition.elemental - 1)
		# 敌方法术调用 PAL_CalcMagicDamage 时传入 100 + 玩家抗性，并使用倍率 20。
		damage = int(damage * (10.0 - float(100 + resistance) / 20.0))
		damage /= 5
		if definition.elemental <= PalBattlefield.ELEMENT_COUNT:
			var battlefield := database.battlefield_definition(battlefield_id)
			var field_effect := battlefield.magic_effects[definition.elemental - 1] if battlefield != null and battlefield.magic_effects.size() >= definition.elemental else 0
			damage = int(damage * (10.0 + field_effect) / 10.0)
	return damage


func _apply_player_magic_damage(party_index: int, damage: int, auto_defended: bool) -> Hit:
	var hit := Hit.new()
	hit.target_index = party_index
	hit.auto_defended = auto_defended
	var role_index := players[party_index].role_index
	var current_hp := _role_hp(role_index)
	hit.damage = mini(current_hp, maxi(0, damage))
	session.increase_role_hp_mp(role_index, -hit.damage, 0)
	hit.defeated = _role_hp(role_index) == 0
	return hit


func _enemy_physical_hit(enemy_index: int, target_index: int) -> Hit:
	var enemy := enemies[enemy_index]
	var player := players[target_index]
	var hit := Hit.new()
	hit.target_index = target_index
	# 原版无异常状态的角色有 7/17 自动格挡机会；濒死/异常目标可由 PLAYERROLES 指定队友保护。
	hit.auto_defended = _random.next_int(0, 16) >= 10
	if hit.auto_defended and (_is_player_dying(player.role_index) or _role_has_coverable_bad_status(player.role_index)):
		hit.covering_index = _covering_party_index(target_index)
	# 混乱、睡眠或定身者找不到健康保护人时不能自行闪避；仅濒死仍保留自己的格挡机会。
	if hit.covering_index < 0 and _role_has_coverable_bad_status(player.role_index):
		hit.auto_defended = false
	if hit.auto_defended:
		return hit
	var attack := _signed_word(enemy.definition.attack_strength) + (enemy.definition.level + 6) * 6
	attack = maxi(0, attack)
	var defense := session.defense_for(player.role_index)
	if player.defending:
		defense *= 2
	var damage := calculate_physical_damage(attack + _random.next_int(0, 2), defense, 2)
	damage += _random.next_int(0, 1)
	if session.status_rounds_for(player.role_index, GameSession.STATUS_PROTECT) > 0:
		damage /= 2
	damage = maxi(1, damage)
	var current_hp := _role_hp(player.role_index)
	hit.damage = mini(current_hp, damage)
	session.increase_role_hp_mp(player.role_index, -damage, 0)
	hit.defeated = _role_hp(player.role_index) == 0
	return hit


func _role_has_coverable_bad_status(role_index: int) -> bool:
	return session.status_rounds_for(role_index, GameSession.STATUS_CONFUSED) > 0 or session.status_rounds_for(role_index, GameSession.STATUS_SLEEP) > 0 or session.status_rounds_for(role_index, GameSession.STATUS_PARALYZED) > 0


func _covering_party_index(target_index: int) -> int:
	if target_index < 0 or target_index >= players.size() or database.player_roles == null:
		return -1
	var cover_role := database.player_roles.covered_by_role(players[target_index].role_index)
	for party_index in range(players.size()):
		var role_index := players[party_index].role_index
		if role_index != cover_role:
			continue
		if _role_hp(role_index) > 0 and not _is_player_dying(role_index) and not _role_has_coverable_bad_status(role_index):
			return party_index
	return -1


func _finish_turn() -> ActionResult:
	var result := ActionResult.new()
	result.action_type = ActionType.POISON
	result.poison_tick = true
	result.summary = "回合结束"
	for player in players:
		player.defending = false
	if _hiding_turns > 0:
		_hiding_turns -= 1
		if _hiding_turns == 0:
			result.script_events.append(_script_event(ScriptEventType.HIDING, 0))
	# fight.c 经典模式固定按“玩家毒/玩家状态/敌人毒/敌人状态”的次序结算。
	for party_index in range(players.size()):
		var role_index := players[party_index].role_index
		var player_poisons := session.poison_entries_for(role_index)
		for poison_id in player_poisons:
			var cursor := int(player_poisons.get(poison_id, 0))
			var outcome := _run_battle_effect_script(cursor, false, false, party_index, result)
			session.set_role_poison_cursor(role_index, int(poison_id), int(outcome.get("cursor", cursor)))
		session.decrement_role_statuses(role_index)
	for enemy_index in range(enemies.size()):
		for poison_id in enemies[enemy_index].poisons.keys():
			var cursor := int(enemies[enemy_index].poisons.get(poison_id, 0))
			var outcome := _run_battle_effect_script(cursor, true, true, enemy_index, result)
			if enemies[enemy_index].poisons.has(poison_id):
				enemies[enemy_index].poisons[poison_id] = int(outcome.get("cursor", cursor))
		for status_id in range(GameSession.STATUS_COUNT):
			if enemies[enemy_index].status_rounds[status_id] > 0:
				enemies[enemy_index].status_rounds[status_id] -= 1
	_check_battle_result()
	if not result.hits.is_empty():
		result.summary = "毒性发作"
	else:
		result.skipped = true
	if battle_result == BattleResult.ONGOING:
		turn_number += 1
		_queue_enemy_turn_start_scripts()
		if _pending_script_results.is_empty() and battle_result == BattleResult.ONGOING:
			_prepare_command_phase()
	result.turn_finished = true
	return result


#endregion

#region Enemy battle scripts

func _create_enemy_state(object_id: int, slot_index: int) -> EnemyState:
	var object := database.enemy_object_definition(object_id)
	var definition := database.enemy_definition_for_object(object_id)
	if object == null or definition == null:
		return null
	var enemy := EnemyState.new()
	enemy.slot_index = slot_index
	enemy.object_id = object_id
	enemy.definition = definition
	enemy.hp = definition.health
	enemy.max_hp = definition.health
	enemy.magic = definition.magic
	enemy.magic_rate = definition.magic_rate
	enemy.steal_item = definition.steal_item
	enemy.steal_item_count = definition.steal_item_count
	enemy.script_on_turn_start = object.script_on_turn_start
	enemy.script_on_battle_end = object.script_on_battle_end
	enemy.script_on_ready = object.script_on_ready
	var script_overrides: Dictionary = _enemy_object_script_overrides.get(object_id, {})
	enemy.script_on_turn_start = int(script_overrides.get(0, enemy.script_on_turn_start))
	enemy.script_on_battle_end = int(script_overrides.get(1, enemy.script_on_battle_end))
	enemy.script_on_ready = int(script_overrides.get(2, enemy.script_on_ready))
	enemy.status_rounds.resize(GameSession.STATUS_COUNT)
	enemy.status_rounds.fill(0)
	return enemy


func _queue_enemy_turn_start_scripts() -> void:
	_resume_commands_after_scripts = false
	var enemy_index := 0
	# 009E 可能在脚本中扩充敌队；和 SDLPal 一样重新读取当前长度。
	while enemy_index < enemies.size():
		var enemy := enemies[enemy_index]
		if enemy != null and enemy.is_alive() and enemy.script_on_turn_start > 0:
			var result := ActionResult.new()
			result.action_type = ActionType.SCRIPT
			result.actor_is_enemy = true
			result.actor_index = enemy_index
			var outcome := _run_enemy_battle_script(enemy.script_on_turn_start, enemy_index, result)
			enemy.script_on_turn_start = int(outcome.get("cursor", enemy.script_on_turn_start))
			_check_battle_result()
			result.battle_result = battle_result
			if not result.script_events.is_empty() or not result.script_hits.is_empty() or result.unsupported or battle_result != BattleResult.ONGOING:
				_pending_script_results.append(result)
		if battle_result != BattleResult.ONGOING:
			break
		enemy_index += 1
	_resume_commands_after_scripts = not _pending_script_results.is_empty() and battle_result == BattleResult.ONGOING


func _run_enemy_battle_script(entry_index: int, enemy_index: int, result: ActionResult, depth: int = 0) -> Dictionary:
	if entry_index <= 0 or database == null or enemy_index < 0 or enemy_index >= enemies.size():
		return {"cursor": entry_index, "success": false}
	if depth > 16:
		result.unsupported = true
		result.summary = "敌人战斗脚本调用层级过深"
		return {"cursor": entry_index, "success": false}
	var cursor := entry_index
	var dialog_position := 1
	var dialog_color := 0
	var dialog_portrait := 0
	for _step in range(512):
		if cursor <= 0 or cursor >= database.scripts.size():
			return {"cursor": cursor, "success": true}
		var entry := database.scripts[cursor]
		match entry.operation:
			# PAL_RunTriggerScript 使用 0000 保留入口，0001/0002 则推进持久脚本游标。
			0x0000:
				return {"cursor": entry_index, "success": true}
			0x0001:
				return {"cursor": cursor + 1, "success": true}
			0x0002:
				return {"cursor": entry.operands[0], "success": true}
			0x0003:
				cursor = entry.operands[0]
				continue
			0x0004:
				_run_enemy_battle_script(entry.operands[0], enemy_index, result, depth + 1)
				cursor += 1
			0x0005:
				result.script_events.append(_script_event(ScriptEventType.CLEAR_DIALOG))
				cursor += 1
			0x0006:
				cursor = entry.operands[1] if _random.next_int(1, 100) >= entry.operands[0] else cursor + 1
			0x0019:
				var role_index := enemy_index if entry.operands[2] == 0 else entry.operands[2] - 1
				if not session.change_role_attribute(entry.operands[0], role_index, _signed_word(entry.operands[1])):
					result.unsupported = true
					result.summary = "敌人脚本 0019 的角色属性组无效"
					return {"cursor": entry_index, "success": false}
				cursor += 1
			# 明王等分轮敌人脚本会在剧情成长段直接恢复全队 HP/MP。
			0x001d:
				var changed := false
				var targets := range(players.size()) if entry.operands[0] != 0 else [_battle_player_target(enemy_index)]
				for party_index in targets:
					if party_index >= 0:
						changed = _apply_player_stat_delta(party_index, _signed_word(entry.operands[1]), _signed_word(entry.operands[1]), result) or changed
				# 官方全体 001D 不以“无人变化”标记失败；保持进入本段前的成功状态。
				cursor += 1
			0x0022:
				var targets := range(players.size()) if entry.operands[0] != 0 else [_battle_player_target(enemy_index)]
				for party_index in targets:
					if party_index >= 0:
						_revive_player(party_index, entry.operands[1], result)
				cursor += 1
			# 战后随机掉落；数量 0 在 PAL_AddItemToInventory 中按 1 处理并限制为 99。
			0x001f:
				var amount := _signed_word(entry.operands[1])
				amount = 1 if amount == 0 else amount
				var before := session.item_count(entry.operands[0])
				session.set_item_count(entry.operands[0], clampi(before + amount, 0, 99))
				var changed := session.item_count(entry.operands[0]) - before
				if changed > 0:
					result.script_events.append(_script_event(ScriptEventType.ITEM_GAIN, entry.operands[0], changed))
				cursor += 1
			# 敌人自身中毒/异常脚本使用当前敌人槽位作为事件对象编号。
			0x0028:
				var previous_hit_count := result.hits.size()
				_apply_poison_to_enemy(enemy_index, entry.operands[1], true, result)
				while result.hits.size() > previous_hit_count:
					result.script_hits.append(result.hits.pop_back())
				cursor += 1
			0x002e:
				var enemy := enemies[enemy_index]
				if _random.next_int(0, 9) > enemy.definition.poison_resistance:
					if entry.operands[0] < GameSession.STATUS_COUNT:
						enemy.status_rounds[entry.operands[0]] = entry.operands[1]
					cursor += 1
				else:
					cursor = entry.operands[2]
			# 003B–003E 只改变随后 FFFF 文本的位置；画面层复用同一经典对话控件。
			0x003b, 0x003c, 0x003d, 0x003e:
				if entry.operation == 0x003b:
					dialog_position = 2
					dialog_portrait = 0
					dialog_color = entry.operands[0]
				else:
					dialog_position = entry.operation - 0x003c
					dialog_portrait = entry.operands[0] if entry.operation != 0x003e else 0
					dialog_color = entry.operands[1] if entry.operation != 0x003e else entry.operands[0]
				result.script_events.append(_script_event(ScriptEventType.DIALOG_START, dialog_position, dialog_color, dialog_portrait))
				cursor += 1
			0x0043:
				session.music_number = entry.operands[0]
				var fade_milliseconds := 3000 if entry.operands[1] == 3 and entry.operands[0] != 9 else 0
				result.script_events.append(_script_event(ScriptEventType.MUSIC, entry.operands[0], 0 if entry.operands[1] == 1 else 1, fade_milliseconds))
				cursor += 1
			0x0047:
				result.script_events.append(_script_event(ScriptEventType.SOUND, entry.operands[0]))
				cursor += 1
			0x0092:
				result.script_events.append(_script_event(ScriptEventType.PRE_MAGIC, entry.operands[0] - 1 if entry.operands[0] > 0 else -1))
				cursor += 1
			# 对应 script.c 005B/0064：按当前基础最大体力进行 Boss 阶段判断。
			0x005b:
				var damage := mini(enemies[enemy_index].hp / 2 + 1, entry.operands[0])
				result.script_hits.append(_apply_enemy_damage(enemy_index, damage, false))
				cursor += 1
			0x005e:
				cursor = entry.operands[1] if not enemies[enemy_index].poisons.has(entry.operands[0]) else cursor + 1
			0x0060:
				result.script_hits.append(_apply_enemy_damage(enemy_index, enemies[enemy_index].hp, false))
				cursor += 1
			0x0064:
				var enemy := enemies[enemy_index]
				cursor = entry.operands[1] if enemy.hp * 100 > enemy.max_hp * entry.operands[0] else cursor + 1
			0x0067:
				enemies[enemy_index].magic = entry.operands[0]
				enemies[enemy_index].magic_rate = entry.operands[1] if entry.operands[1] > 0 else 10
				cursor += 1
			0x0068:
				# 回合开始/行动准备脚本执行时 fEnemyMoving 尚未置位，因此不跳转。
				cursor += 1
			0x0069:
				battle_result = BattleResult.TERMINATED
				_accepting_commands = false
				result.script_events.append(_script_event(ScriptEventType.ENEMY_ESCAPE))
				cursor += 1
			0x0077:
				session.music_number = 0
				var fade_milliseconds := 2000 if entry.operands[0] == 0 else entry.operands[0] * 3000
				result.script_events.append(_script_event(ScriptEventType.MUSIC, 0, 0, fade_milliseconds))
				cursor += 1
			0x0079:
				var in_party := false
				for role_index in session.party_roles:
					if database.player_roles.name_word_for(role_index) == entry.operands[0]:
						in_party = true
						break
				cursor = entry.operands[1] if in_party else cursor + 1
			0x0085:
				result.script_events.append(_script_event(ScriptEventType.DELAY, entry.operands[0]))
				cursor += 1
			0x0089:
				_set_scripted_battle_result(entry.operands[0])
				cursor += 1
			0x008e:
				result.script_events.append(_script_event(ScriptEventType.CLEAR_DIALOG))
				cursor += 1
			0x0090:
				_set_enemy_object_script(entry.operands[0], entry.operands[2], entry.operands[1])
				cursor += 1
			0x0091:
				var same_kind_position := 0
				for candidate_index in range(enemies.size()):
					if enemies[candidate_index].object_id == enemies[enemy_index].object_id:
						same_kind_position += 1
						if candidate_index == enemy_index:
							break
				cursor = entry.operands[0] if same_kind_position > 1 else cursor + 1
			0x009c:
				if not _divide_enemy(enemy_index, entry.operands[0], result):
					cursor = entry.operands[1] if entry.operands[1] > 0 else cursor + 1
				else:
					cursor += 1
			0x009e:
				var summon_count := maxi(1, _signed_word(entry.operands[1]))
				var object_id := entry.operands[0] if entry.operands[0] not in [0, 0xffff] else enemies[enemy_index].object_id
				var summoner_disabled := enemy_status_rounds(enemy_index, GameSession.STATUS_SLEEP) > 0 or enemy_status_rounds(enemy_index, GameSession.STATUS_PARALYZED) > 0 or enemy_status_rounds(enemy_index, GameSession.STATUS_CONFUSED) > 0
				if summoner_disabled or not _summon_enemies(object_id, summon_count, result):
					cursor = entry.operands[2] if entry.operands[2] > 0 else cursor + 1
				else:
					cursor += 1
			0x009f:
				var transformer_disabled := enemy_status_rounds(enemy_index, GameSession.STATUS_SLEEP) > 0 or enemy_status_rounds(enemy_index, GameSession.STATUS_PARALYZED) > 0 or enemy_status_rounds(enemy_index, GameSession.STATUS_CONFUSED) > 0
				if transformer_disabled:
					cursor += 1
				elif _transform_enemy(enemy_index, entry.operands[0], result):
					cursor += 1
				else:
					result.unsupported = true
					result.summary = "敌人变身对象 %d 不存在" % entry.operands[0]
					return {"cursor": entry_index, "success": false}
			0x00a2:
				cursor += _random.next_int(1, maxi(1, entry.operands[0]))
			0xffff:
				result.script_events.append(_script_event(ScriptEventType.DIALOG_MESSAGE, entry.operands[0], dialog_position, dialog_color))
				cursor += 1
			_:
				result.unsupported = true
				result.summary = "敌人战斗脚本操作码 %04X 尚未接入" % entry.operation
				return {"cursor": entry_index, "success": false}
	return {"cursor": cursor, "success": false}


func _script_event(type: int, value: int = 0, secondary: int = 0, tertiary: int = 0) -> ScriptEvent:
	var event := ScriptEvent.new()
	event.type = type
	event.value = value
	event.secondary = secondary
	event.tertiary = tertiary
	return event


func _set_enemy_object_script(object_id: int, script_field: int, cursor: int) -> void:
	var script_overrides: Dictionary = _enemy_object_script_overrides.get(object_id, {})
	script_overrides[script_field] = cursor
	_enemy_object_script_overrides[object_id] = script_overrides
	for enemy in enemies:
		if enemy.object_id != object_id:
			continue
		match script_field:
			0:
				enemy.script_on_turn_start = cursor
			1:
				enemy.script_on_battle_end = cursor
			2:
				enemy.script_on_ready = cursor


func _set_scripted_battle_result(value: int) -> void:
	match value:
		1:
			battle_result = BattleResult.DEFEAT
		3:
			battle_result = BattleResult.VICTORY
		0xffff:
			battle_result = BattleResult.FLED
		_:
			battle_result = BattleResult.TERMINATED
	_accepting_commands = false


func _summon_enemies(object_id: int, count: int, result: ActionResult) -> bool:
	var definition := database.enemy_definition_for_object(object_id)
	if definition == null or database.enemy_object_definition(object_id) == null:
		return false
	var available := 5 - enemies.size()
	for enemy in enemies:
		if not enemy.is_alive():
			available += 1
	if available < count:
		return false
	var summoned := 0
	for enemy_index in range(enemies.size()):
		if summoned >= count:
			break
		if not enemies[enemy_index].is_alive():
			enemies[enemy_index] = _create_enemy_state(object_id, enemy_index)
			summoned += 1
	while summoned < count and enemies.size() < 5:
		enemies.append(_create_enemy_state(object_id, enemies.size()))
		summoned += 1
	if summoned > 0:
		result.script_events.append(_script_event(ScriptEventType.SUMMON, object_id, summoned))
	return summoned == count


func _divide_enemy(enemy_index: int, requested_count: int, result: ActionResult) -> bool:
	if living_enemy_indices().size() != 1 or enemies[enemy_index].hp <= 1:
		return false
	var count := maxi(1, requested_count)
	var available := 5 - enemies.size()
	for enemy in enemies:
		if not enemy.is_alive():
			available += 1
	if available < count:
		return false
	var source := enemies[enemy_index]
	var split_hp := ceili(float(source.hp) / float(count + 1))
	source.hp = split_hp
	var created := 0
	for candidate_index in range(enemies.size()):
		if created >= count:
			break
		if enemies[candidate_index].is_alive():
			continue
		var clone := _create_enemy_state(source.object_id, candidate_index)
		clone.hp = split_hp
		clone.magic = source.magic
		clone.magic_rate = source.magic_rate
		clone.script_on_turn_start = source.script_on_turn_start
		clone.script_on_battle_end = source.script_on_battle_end
		clone.script_on_ready = source.script_on_ready
		enemies[candidate_index] = clone
		created += 1
	while created < count and enemies.size() < 5:
		var clone := _create_enemy_state(source.object_id, enemies.size())
		clone.hp = split_hp
		clone.magic = source.magic
		clone.magic_rate = source.magic_rate
		clone.script_on_turn_start = source.script_on_turn_start
		clone.script_on_battle_end = source.script_on_battle_end
		clone.script_on_ready = source.script_on_ready
		enemies.append(clone)
		created += 1
	result.script_events.append(_script_event(ScriptEventType.SUMMON, source.object_id, count))
	return true


func _transform_enemy(enemy_index: int, object_id: int, result: ActionResult) -> bool:
	var replacement := _create_enemy_state(object_id, enemy_index)
	if replacement == null:
		return false
	var enemy := enemies[enemy_index]
	var preserved_hp := enemy.hp
	replacement.hp = preserved_hp
	# 原版变身只替换 OBJECT/ENEMY 数据，三个脚本游标仍沿用变身前的当前值。
	replacement.script_on_turn_start = enemy.script_on_turn_start
	replacement.script_on_battle_end = enemy.script_on_battle_end
	replacement.script_on_ready = enemy.script_on_ready
	replacement.status_rounds = enemy.status_rounds.duplicate()
	replacement.poisons = enemy.poisons.duplicate()
	enemies[enemy_index] = replacement
	result.script_events.append(_script_event(ScriptEventType.TRANSFORM, enemy_index, object_id))
	return true


## 静态判断一个操作码是否属于当前敌人战斗脚本解释器的支持集合。
## 供真实资源审计使用，不执行脚本也不修改战斗状态。
static func is_battle_effect_opcode_supported(operation: int) -> bool:
	# 0042/0066 由投掷物专用执行器实际处理，但在六类审计中归入“战斗效果”。
	return operation in [
		0x0000, 0x0001, 0x0003, 0x0005, 0x0006, 0x0019, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
		0x0020, 0x0021, 0x0022, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
		0x0030, 0x0031, 0x0033, 0x0034, 0x0035, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e,
		0x0041, 0x0042, 0x0047, 0x0055, 0x0056, 0x0057, 0x0058, 0x005a, 0x005b, 0x005c,
		0x005d, 0x005e, 0x005f, 0x0060, 0x0061, 0x0064, 0x0066, 0x0068, 0x006a, 0x006b,
		0x0074, 0x0086, 0x0088, 0x008a, 0x008d, 0x008f, 0x0092, 0xffff,
	]


## 返回指定操作码是否可由敌人回合/就绪/战后脚本上下文执行。
static func is_enemy_script_opcode_supported(operation: int) -> bool:
	return operation in [
		0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006,
		0x0019, 0x001d, 0x001f, 0x0022, 0x0028, 0x002e, 0x003b, 0x003c, 0x003d, 0x003e, 0x0043, 0x0047,
		0x005b, 0x005e, 0x0060, 0x0064, 0x0067, 0x0068, 0x0069,
		0x0077, 0x0079, 0x0085, 0x0089, 0x008e, 0x0090, 0x0091, 0x0092,
		0x009c, 0x009e, 0x009f, 0x00a2, 0xffff,
	]


#endregion

#region Helpers

func _apply_primary_level_ups(role_index: int) -> void:
	var progression := database.level_progression
	if progression == null or not progression.is_valid() or role_index < 0 or role_index >= session.role_levels.size():
		return
	session.role_levels[role_index] = clampi(session.role_levels[role_index], 0, PalLevelProgression.MAX_LEVEL)
	var leveled_up := false
	# 正常数据最多跨越少量等级；固定上限只防止损坏阈值造成无限循环。
	for _step in range(256):
		var level := session.role_levels[role_index]
		var threshold := progression.experience_for_level(level)
		if threshold <= 0 or session.role_experience[role_index] < threshold:
			break
		session.role_experience[role_index] -= threshold
		if level >= PalLevelProgression.MAX_LEVEL:
			continue
		_level_up_role_once(role_index)
		leveled_up = true
	if leveled_up:
		# 原版每次主等级提升后会把当前 HP/MP 恢复到新的上限。
		session.role_hp[role_index] = session.role_max_hp[role_index]
		session.role_mp[role_index] = session.role_max_mp[role_index]


func _level_up_role_once(role_index: int) -> void:
	session.role_levels[role_index] = mini(PalLevelProgression.MAX_LEVEL, session.role_levels[role_index] + 1)
	session.role_max_hp[role_index] = mini(999, session.role_max_hp[role_index] + 10 + _random.next_int(0, 7))
	session.role_max_mp[role_index] = mini(999, session.role_max_mp[role_index] + 8 + _random.next_int(0, 5))
	session.role_attack_strength[role_index] = mini(999, session.role_attack_strength[role_index] + 4 + _random.next_int(0, 1))
	session.role_magic_strength[role_index] = mini(999, session.role_magic_strength[role_index] + 4 + _random.next_int(0, 1))
	session.role_defense[role_index] = mini(999, session.role_defense[role_index] + 2 + _random.next_int(0, 1))
	session.role_dexterity[role_index] = mini(999, session.role_dexterity[role_index] + 2 + _random.next_int(0, 1))
	session.role_flee_rate[role_index] = mini(999, session.role_flee_rate[role_index] + 2)


func _recover_party_after_victory() -> void:
	# PAL_CLASSIC 在战后把当前值与上限的差额恢复一半；倒下角色也会因此恢复。
	for player in players:
		var role_index := player.role_index
		var hp_delta := int((session.role_max_hp[role_index] - session.role_hp[role_index]) / 2.0)
		var mp_delta := int((session.role_max_mp[role_index] - session.role_mp[role_index]) / 2.0)
		session.increase_role_hp_mp(role_index, hp_delta, mp_delta)


func _role_stats_snapshot(role_index: int) -> PackedInt32Array:
	return PackedInt32Array([
		session.role_levels[role_index],
		session.role_max_hp[role_index],
		session.role_max_mp[role_index],
		session.role_attack_strength[role_index],
		session.role_magic_strength[role_index],
		session.role_defense[role_index],
		session.role_dexterity[role_index],
		session.role_flee_rate[role_index],
	])

func _check_battle_result() -> void:
	if battle_result != BattleResult.ONGOING:
		return
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


func _apply_battle_cleanup_if_needed() -> void:
	if _battle_cleanup_applied or battle_result == BattleResult.ONGOING:
		return
	# SDLPal 在任意战斗结果后清除临时状态，并为全部角色移除三级及以下毒；
	# 四级特殊附着和 99 级装备效果继续保留，不能把所有毒都无条件跨战斗保存。
	session.clear_temporary_role_statuses()
	for role_index in range(session.role_poisons_by_role.size()):
		session.cure_role_poisons_by_level(role_index, 3, database)
	for player in players:
		session.clear_equipment_effects(player.role_index, GameSession.EQUIPMENT_SLOT_COUNT)
	_auto_battle = false
	_hiding_turns = 0
	_blow_displacement = 0
	_battle_cleanup_applied = true


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


func _is_player_healthy_for_cooperation(party_index: int) -> bool:
	if party_index < 0 or party_index >= players.size():
		return false
	var role_index := players[party_index].role_index
	if _role_hp(role_index) <= 0 or _is_player_dying(role_index):
		return false
	for status_id in [GameSession.STATUS_SLEEP, GameSession.STATUS_CONFUSED, GameSession.STATUS_SILENCE, GameSession.STATUS_PARALYZED, GameSession.STATUS_PUPPET]:
		if session.status_rounds_for(role_index, status_id) > 0:
			return false
	return true


func _role_hp(role_index: int) -> int:
	return session.role_hp[role_index] if role_index >= 0 and role_index < session.role_hp.size() else 0


func _role_name(role_index: int) -> String:
	var name := database.get_word(database.player_roles.name_word_for(role_index))
	return name if not name.is_empty() else "角色%d" % role_index


func _reserve_item(item_object_id: int) -> void:
	_reserved_items[item_object_id] = int(_reserved_items.get(item_object_id, 0)) + 1


func _release_item_reservation(item_object_id: int) -> void:
	var remaining := int(_reserved_items.get(item_object_id, 0)) - 1
	if remaining > 0:
		_reserved_items[item_object_id] = remaining
	else:
		_reserved_items.erase(item_object_id)


func _release_player_item_reservation(player: PlayerState) -> void:
	if player == null or player.action_id <= 0:
		return
	if player.action_type == ActionType.THROW_ITEM:
		_release_item_reservation(player.action_id)
	elif player.action_type == ActionType.USE_ITEM:
		var item := database.item_definition(player.action_id)
		if item != null and item.is_consuming():
			_release_item_reservation(player.action_id)


static func _signed_word(value: int) -> int:
	return value - 0x10000 if value >= 0x8000 else value


#endregion
