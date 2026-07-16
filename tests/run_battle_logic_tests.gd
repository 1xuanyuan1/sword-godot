# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用完全合成的角色和敌人数据验证经典行动队列、物理伤害、重选目标与胜负。
## 本测试不读取 `Data/` 或 `generated/`，可直接在 GitHub CI 运行。
extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	_test_random_reproducibility()
	_test_damage_formula()
	_test_defend_and_dual_move_queue()
	_test_minimum_damage()
	_test_dead_party_member_revives_for_battle()
	_test_dead_target_reselection_and_victory()
	_test_victory_rewards_and_level_up()
	_test_single_target_healing_magic()
	_test_offensive_magic_damage()
	_test_unsupported_status_magic_is_disabled()
	_test_enemy_offensive_magic()
	_test_enemy_attack_all_magic()
	_test_unsupported_enemy_status_magic()
	_test_consuming_healing_item()
	_test_throw_item_magic_damage()
	_test_flee_success_and_boss_failure()
	_test_repeat_previous_magic_commands()
	_test_repeat_exhausted_items()
	_test_defeat()
	if _failures.is_empty():
		print("PASS: %d classic battle logic checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("%d/%d checks failed" % [_failures.size(), _checks])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _test_random_reproducibility() -> void:
	var first := PalBattleRandom.new()
	var second := PalBattleRandom.new()
	first.set_seed(12345)
	second.set_seed(12345)
	var first_values := PackedInt32Array()
	var second_values := PackedInt32Array()
	for _index in range(8):
		first_values.append(first.next_int(0, 1000))
		second_values.append(second.next_int(0, 1000))
	_expect(first_values == second_values, "battle LCG repeats the same integer sequence for a fixed seed")
	var values_in_bounds := true
	for value in first_values:
		values_in_bounds = values_in_bounds and value >= 0 and value <= 1000
	_expect(values_in_bounds, "battle LCG respects inclusive integer bounds")
	_expect(first_values == PackedInt32Array([517, 43, 135, 410, 613, 996, 48, 96]), "battle LCG matches SDLPal util.c sequence")


func _test_damage_formula() -> void:
	_expect(PalBattleController.calculate_base_damage(100, 50) == 120, "base damage uses attack*2-defense*1.6 above defense")
	_expect(PalBattleController.calculate_base_damage(50, 60) == 14, "base damage uses attack-defense*0.6 in the middle band")
	_expect(PalBattleController.calculate_base_damage(20, 50) == 0, "base damage becomes zero below sixty percent defense")
	_expect(PalBattleController.calculate_physical_damage(100, 50, 3) == 40, "physical resistance divides base damage")
	var wrapped_enemy := _enemy_definition(40, 0, 0, 0xfffa, 0, false)
	_expect(PalBattleController.new()._effective_enemy_defense(wrapped_enemy) == 18, "enemy defense preserves SDLPal WORD wraparound after the level bonus")


func _test_defend_and_dual_move_queue() -> void:
	var database := _synthetic_database([
		_enemy_definition(999, 1, 30, 5, 1, true),
	])
	var session := _session_for(database, PackedInt32Array([0, 1]))
	var controller := PalBattleController.new()
	_expect(controller.start_battle(database, session, 0, 0, 7), "synthetic dual-move battle starts")
	_expect(controller.submit_defend() and controller.submit_attack(0), "two player commands are accepted")
	_expect(controller.action_queue.size() == 4, "dual-move enemy appears twice beside two players")
	if controller.action_queue.size() == 4:
		var enemy_actions := controller.action_queue.filter(func(entry: PalBattleController.QueueEntry) -> bool: return entry.is_enemy)
		var second_actions := enemy_actions.filter(func(entry: PalBattleController.QueueEntry) -> bool: return entry.is_second)
		_expect(not controller.action_queue[0].is_enemy and controller.action_queue[0].combatant_index == 0, "defense dexterity multiplier lets the defender act first")
		_expect(enemy_actions.size() == 2 and second_actions.size() == 1, "exactly one dual-move entry is marked as the second action")
	var first_result := controller.execute_next_action()
	_expect(first_result != null and first_result.action_type == PalBattleController.ActionType.DEFEND and controller.players[0].defending, "defense becomes active when its queued action executes")
	_expect(PalBattleController.calculate_physical_damage(80, 40, 2) < PalBattleController.calculate_physical_damage(80, 20, 2), "doubling defense lowers enemy physical damage")


func _test_minimum_damage() -> void:
	var database := _synthetic_database([
		_enemy_definition(10, 1, 1, 999, 0, false),
	])
	database.player_roles.attack_strengths[0] = 1
	database.player_roles.dexterities[0] = 999
	var session := _session_for(database, PackedInt32Array([0]))
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 11)
	controller.submit_attack(0)
	var result := controller.execute_next_action()
	_expect(result != null and not result.hits.is_empty() and result.hits[0].damage >= 1, "player physical attack always deals at least one damage")


func _test_dead_party_member_revives_for_battle() -> void:
	var database := _synthetic_database([_enemy_definition(10, 1, 1, 0, 0, false)])
	var session := _session_for(database, PackedInt32Array([0]))
	session.role_hp[0] = 0
	var controller := PalBattleController.new()
	_expect(controller.start_battle(database, session, 0, 0, 13), "battle can start when every party member was down")
	_expect(session.role_hp[0] == 1, "PAL_StartBattle behavior revives a down party member to one HP")


func _test_dead_target_reselection_and_victory() -> void:
	var database := _synthetic_database([
		_enemy_definition(1, 1, 1, 0, 0, false),
		_enemy_definition(1, 1, 1, 0, 0, false),
	])
	for role_index in [0, 1]:
		database.player_roles.attack_strengths[role_index] = 200
		database.player_roles.dexterities[role_index] = 999
	var session := _session_for(database, PackedInt32Array([0, 1]))
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 19)
	controller.submit_attack(0)
	controller.submit_attack(0)
	var resolved_targets := PackedInt32Array()
	for _index in range(2):
		var result := controller.execute_next_action()
		if result != null and not result.hits.is_empty():
			resolved_targets.append(result.hits[0].target_index)
	_expect(resolved_targets == PackedInt32Array([0, 1]), "later player retargets from a defeated enemy to the next living slot")
	_expect(controller.battle_result == PalBattleController.BattleResult.VICTORY, "defeating the last enemy ends the battle in victory")


func _test_victory_rewards_and_level_up() -> void:
	var enemy := _enemy_definition(1, 1, 1, 0, 0, false)
	enemy.experience = 2
	enemy.cash = 7
	var database := _synthetic_database([enemy])
	database.player_roles.attack_strengths[0] = 200
	database.player_roles.dexterities[0] = 999
	database.level_progression = _synthetic_progression(10)
	var learning := PalLevelProgression.MagicLearning.new()
	learning.role_index = 0
	learning.required_level = 2
	learning.magic_object_id = 100
	database.level_progression.magic_learning_by_role[0].append(learning)
	database.enemy_objects[1].script_on_battle_end = 88
	var session := _session_for(database, PackedInt32Array([0, 1]))
	session.role_experience[0] = 9
	session.role_hp[0] = 20
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 37)
	# 战斗结束时倒下的队员不获得经验，但经典战后半恢复仍会让其恢复。
	session.role_hp[1] = 0
	controller.submit_attack(0)
	var action := controller.execute_next_action()
	_expect(action != null and controller.battle_result == PalBattleController.BattleResult.VICTORY and controller.experience_gained == 2 and controller.cash_gained == 7, "defeated enemies contribute their DATA experience and cash exactly once")
	var reward := controller.claim_victory_rewards()
	_expect(reward != null and reward.experience == 2 and reward.cash == 7 and session.cash == 7, "victory reward adds total cash to the persistent session")
	_expect(session.role_levels[0] == 2 and session.role_experience[0] == 1 and reward.level_ups.size() == 1, "primary experience consumes the current-level threshold and reports level up")
	_expect(session.role_max_hp[0] >= 110 and session.role_max_hp[0] <= 117 and session.role_attack_strength[0] >= 204 and session.role_attack_strength[0] <= 205, "level up applies SDLPal random HP and attack growth ranges")
	_expect(session.role_hp[0] == session.role_max_hp[0] and session.role_mp[0] == session.role_max_mp[0], "main level up fully restores HP and MP")
	_expect(session.role_experience[1] == 0 and session.role_hp[1] == 50, "down party member skips experience then receives classic half recovery")
	_expect(session.has_magic(0, 100) and reward.learned_magics.size() == 1, "level-up magic table teaches newly eligible magic")
	_expect(reward.post_battle_scripts == PackedInt32Array([88]), "reward report preserves enemy post-battle scripts for the battle-context VM")
	_expect(controller.claim_victory_rewards() == reward and session.cash == 7, "victory rewards are idempotent")


func _test_single_target_healing_magic() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 0, 0, false)])
	database.player_roles.dexterities[0] = 999
	var heal := PalScriptEntry.new()
	heal.operation = 0x001b
	heal.operands = PackedInt32Array([0, 75, 0])
	var stop := PalScriptEntry.new()
	stop.operation = 0
	stop.operands = PackedInt32Array([0, 0, 0])
	database.scripts = [PalScriptEntry.new(), heal, stop]
	_add_magic(database, 100, PalMagicDefinition.TYPE_APPLY_TO_PLAYER, 6, 0, PalMagicObjectDefinition.FLAG_USABLE_IN_BATTLE, 1)
	var session := _session_for(database, PackedInt32Array([0, 1]))
	session.learned_magics_by_role[0] = PackedInt32Array([100])
	session.role_hp[1] = 20
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 23)
	_expect(controller.can_pending_player_use_magic(100) and controller.submit_magic(100, 1), "healing magic validates learned state, MP and ally target")
	controller.submit_defend()
	var result := controller.execute_next_action()
	_expect(result != null and result.action_type == PalBattleController.ActionType.MAGIC and result.magic_object_id == 100 and result.target_index == 1, "magic action preserves object and target for animation")
	_expect(session.role_mp[0] == 44 and session.role_hp[1] == 95, "healing magic consumes MP and runs opcode 001B on selected role")
	_expect(result != null and result.hits.size() == 1 and result.hits[0].healing == 75, "healing result exposes the restored HP for yellow battle numbers")


func _test_offensive_magic_damage() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 0, 0, false)])
	database.player_roles.dexterities[0] = 999
	database.player_roles.magic_strengths[0] = 80
	_add_magic(database, 101, PalMagicDefinition.TYPE_NORMAL, 5, 50, PalMagicObjectDefinition.FLAG_USABLE_IN_BATTLE | PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY, 0)
	var session := _session_for(database, PackedInt32Array([0]))
	session.learned_magics_by_role[0] = PackedInt32Array([101])
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 29)
	_expect(controller.submit_magic(101, 0), "offensive single-target magic command is accepted")
	var result := controller.execute_next_action()
	_expect(result != null and not result.hits.is_empty() and result.hits[0].target_is_enemy and result.hits[0].damage >= 50, "offensive magic uses base damage and returns an enemy hit")
	_expect(session.role_mp[0] == 45 and controller.enemies[0].hp == 999 - result.hits[0].damage, "offensive magic consumes MP and updates enemy HP")


func _test_unsupported_status_magic_is_disabled() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 0, 0, false)])
	var status_script := PalScriptEntry.new()
	status_script.operation = 0x002d
	status_script.operands = PackedInt32Array([6, 7, 0])
	database.scripts = [PalScriptEntry.new(), status_script]
	_add_magic(database, 102, PalMagicDefinition.TYPE_APPLY_TO_PLAYER, 5, 0, PalMagicObjectDefinition.FLAG_USABLE_IN_BATTLE, 1)
	var session := _session_for(database, PackedInt32Array([0]))
	session.learned_magics_by_role[0] = PackedInt32Array([102])
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 31)
	_expect(not controller.can_pending_player_use_magic(102) and not controller.submit_magic(102, 0), "status magic stays disabled until its success opcode is implemented")
	_expect(session.role_mp[0] == 50, "rejecting an unsupported status magic does not consume MP")


func _test_enemy_offensive_magic() -> void:
	var enemy := _enemy_definition(999, 5, 1, 0, 999, false)
	enemy.magic = 101
	enemy.magic_rate = 10
	enemy.magic_strength = 80
	var database := _synthetic_database([enemy])
	database.player_roles.dexterities[0] = 0
	_add_magic(database, 101, PalMagicDefinition.TYPE_NORMAL, 0, 60, PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY, 0)
	var session := _session_for(database, PackedInt32Array([0]))
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 41)
	controller.submit_attack(0)
	var result := controller.execute_next_action()
	_expect(result != null and result.actor_is_enemy and result.action_type == PalBattleController.ActionType.MAGIC and result.magic_object_id == 101 and result.target_index == 0, "enemy selects and reports a supported single-target offensive magic")
	_expect(result != null and result.hits.size() == 1 and result.hits[0].damage > 0 and session.role_hp[0] == 100 - result.hits[0].damage, "enemy magic applies defense, resistance and HP damage to its selected player")


func _test_enemy_attack_all_magic() -> void:
	var enemy := _enemy_definition(999, 5, 1, 0, 999, false)
	enemy.magic = 102
	enemy.magic_rate = 10
	enemy.magic_strength = 80
	var database := _synthetic_database([enemy])
	for role_index in [0, 1]:
		database.player_roles.dexterities[role_index] = 0
	_add_magic(database, 102, PalMagicDefinition.TYPE_ATTACK_ALL, 0, 50, PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY | PalMagicObjectDefinition.FLAG_APPLY_TO_ALL, 0)
	var session := _session_for(database, PackedInt32Array([0, 1]))
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 43)
	controller.submit_defend()
	controller.submit_attack(0)
	var result := controller.execute_next_action()
	_expect(result != null and result.action_type == PalBattleController.ActionType.MAGIC and result.target_index == -1 and result.hits.size() == 2, "non-normal enemy magic targets every living party member")
	_expect(result != null and result.hits.all(func(hit: PalBattleController.Hit) -> bool: return hit.damage > 0), "enemy attack-all magic exposes one positive damage hit per living player")


func _test_unsupported_enemy_status_magic() -> void:
	var enemy := _enemy_definition(999, 5, 1, 0, 999, false)
	enemy.magic = 103
	enemy.magic_rate = 10
	var database := _synthetic_database([enemy])
	database.player_roles.dexterities[0] = 0
	_add_magic(database, 103, PalMagicDefinition.TYPE_APPLY_TO_PLAYER, 0, 0, 0, 0)
	var session := _session_for(database, PackedInt32Array([0]))
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 47)
	controller.submit_attack(0)
	var result := controller.execute_next_action()
	_expect(result != null and result.unsupported and result.action_type == PalBattleController.ActionType.MAGIC, "enemy status magic remains explicit until its battle script effects are implemented")
	_expect(session.role_hp[0] == 100, "unsupported enemy status magic does not fabricate damage")


func _test_consuming_healing_item() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 0, 0, false)])
	database.player_roles.dexterities[0] = 999
	var heal := PalScriptEntry.new()
	heal.operation = 0x001b
	heal.operands = PackedInt32Array([0, 50, 0])
	database.scripts = [PalScriptEntry.new(), heal, PalScriptEntry.new()]
	_add_item(database, 99, 1, 0, PalItemDefinition.FLAG_USABLE | PalItemDefinition.FLAG_CONSUMING)
	var session := _session_for(database, PackedInt32Array([0, 1]))
	session.role_hp[1] = 20
	session.set_item_count(99, 1)
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 53)
	_expect(controller.can_pending_player_use_item(99) and controller.submit_use_item(99, 1), "consuming restorative can be assigned to a living party target")
	_expect(not controller.can_pending_player_use_item(99), "the second player cannot reserve the same last consumable")
	controller.submit_defend()
	var result := controller.execute_next_action()
	_expect(result != null and result.action_type == PalBattleController.ActionType.USE_ITEM and result.item_object_id == 99 and result.hits.size() == 1, "item action reports the selected object and restored target")
	_expect(session.role_hp[1] == 70 and session.item_count(99) == 0, "healing item runs opcode 001B and consumes exactly one inventory unit")


func _test_throw_item_magic_damage() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 10, 0, false)])
	database.player_roles.dexterities[0] = 999
	_add_magic(database, 101, PalMagicDefinition.TYPE_NORMAL, 0, 0, PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY, 0)
	var simulate := PalScriptEntry.new()
	simulate.operation = 0x0042
	simulate.operands = PackedInt32Array([101, 120, 0])
	database.scripts = [PalScriptEntry.new(), simulate, PalScriptEntry.new()]
	_add_item(database, 153, 0, 1, PalItemDefinition.FLAG_THROWABLE | PalItemDefinition.FLAG_CONSUMING)
	var session := _session_for(database, PackedInt32Array([0]))
	session.set_item_count(153, 1)
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 59)
	_expect(controller.can_pending_player_throw_item(153) and controller.submit_throw_item(153, 0), "supported 0042 throw script can target a living enemy")
	var result := controller.execute_next_action()
	_expect(result != null and result.action_type == PalBattleController.ActionType.THROW_ITEM and result.magic_object_id == 101 and not result.hits.is_empty() and result.hits[0].damage > 0, "thrown item simulates its configured offensive magic damage")
	_expect(controller.enemies[0].hp < 999 and session.item_count(153) == 0, "throwing updates enemy HP and consumes exactly one item")


func _test_flee_success_and_boss_failure() -> void:
	var database := _synthetic_database([_enemy_definition(999, 1, 1, 0, 0, false)])
	database.player_roles.dexterities[0] = 999
	var session := _session_for(database, PackedInt32Array([0]))
	session.role_flee_rate[0] = 999
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 61, false)
	_expect(controller.submit_flee(), "classic flee command is accepted for the remaining party")
	var escaped := controller.execute_next_action()
	_expect(escaped != null and escaped.flee_succeeded and controller.battle_result == PalBattleController.BattleResult.FLED, "flee rate beats living enemy strength outside boss battles")
	var boss_controller := PalBattleController.new()
	boss_controller.start_battle(database, session, 0, 0, 61, true)
	boss_controller.submit_flee()
	var failed := boss_controller.execute_next_action()
	_expect(failed != null and not failed.flee_succeeded and boss_controller.battle_result == PalBattleController.BattleResult.ONGOING, "boss battle always rejects fleeing without ending the battle")


func _test_repeat_previous_magic_commands() -> void:
	var database := _synthetic_database([_enemy_definition(9999, 1, 1, 0, 0, false)])
	for role_index in [0, 1]:
		database.player_roles.dexterities[role_index] = 999
	var heal := PalScriptEntry.new()
	heal.operation = 0x001b
	heal.operands = PackedInt32Array([0, 10, 0])
	database.scripts = [PalScriptEntry.new(), heal, PalScriptEntry.new()]
	_add_magic(database, 100, PalMagicDefinition.TYPE_NORMAL, 5, 10, PalMagicObjectDefinition.FLAG_USABLE_IN_BATTLE | PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY, 0)
	_add_magic(database, 101, PalMagicDefinition.TYPE_APPLY_TO_PLAYER, 6, 0, PalMagicObjectDefinition.FLAG_USABLE_IN_BATTLE, 1)
	var session := _session_for(database, PackedInt32Array([0, 1]))
	session.learned_magics_by_role[0] = PackedInt32Array([100])
	session.learned_magics_by_role[1] = PackedInt32Array([101])
	session.role_hp[1] = 80
	var first_turn_controller := PalBattleController.new()
	first_turn_controller.start_battle(database, _session_for(database, PackedInt32Array([0, 1])), 0, 0, 65)
	_expect(first_turn_controller.repeat_previous_commands() and first_turn_controller.players.all(func(player: PalBattleController.PlayerState) -> bool: return player.action_type == PalBattleController.ActionType.ATTACK), "R on the first turn converts the empty previous action into normal attacks")
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 67)
	_expect(controller.submit_magic(100, 0) and controller.submit_magic(101, 1), "manual magic commands establish the previous-turn action cache")
	controller.execute_remaining_actions()
	session.role_mp[0] = 0
	session.role_mp[1] = 0
	_expect(controller.repeat_previous_commands(), "R repeat accepts the previous command set for the whole remaining party")
	_expect(controller.players[0].action_type == PalBattleController.ActionType.ATTACK and controller.players[1].action_type == PalBattleController.ActionType.DEFEND, "repeat falls back from unaffordable offensive magic to attack and healing magic to defend")
	controller.execute_remaining_actions()
	session.role_mp[0] = 50
	session.role_mp[1] = 50
	controller.repeat_previous_commands()
	_expect(controller.players[0].action_type == PalBattleController.ActionType.MAGIC and controller.players[0].action_id == 100 and controller.players[1].action_type == PalBattleController.ActionType.MAGIC and controller.players[1].action_id == 101, "repeat fallback does not overwrite the original previous-turn magic cache")


func _test_repeat_exhausted_items() -> void:
	var database := _synthetic_database([_enemy_definition(9999, 1, 1, 0, 0, false)])
	for role_index in [0, 1]:
		database.player_roles.dexterities[role_index] = 999
	var heal := PalScriptEntry.new()
	heal.operation = 0x001b
	heal.operands = PackedInt32Array([0, 10, 0])
	var simulate := PalScriptEntry.new()
	simulate.operation = 0x0042
	simulate.operands = PackedInt32Array([100, 20, 0])
	database.scripts = [PalScriptEntry.new(), heal, PalScriptEntry.new(), simulate, PalScriptEntry.new()]
	_add_magic(database, 100, PalMagicDefinition.TYPE_NORMAL, 0, 0, PalMagicObjectDefinition.FLAG_USABLE_TO_ENEMY, 0)
	_add_item(database, 99, 1, 0, PalItemDefinition.FLAG_USABLE | PalItemDefinition.FLAG_CONSUMING)
	_add_item(database, 153, 0, 3, PalItemDefinition.FLAG_THROWABLE | PalItemDefinition.FLAG_CONSUMING)
	var session := _session_for(database, PackedInt32Array([0, 1]))
	session.role_hp[1] = 80
	session.set_item_count(99, 1)
	session.set_item_count(153, 1)
	var controller := PalBattleController.new()
	controller.start_battle(database, session, 0, 0, 71)
	_expect(controller.submit_throw_item(153, 0) and controller.submit_use_item(99, 1), "manual throw and use commands reserve their last inventory units")
	controller.execute_remaining_actions()
	_expect(session.item_count(99) == 0 and session.item_count(153) == 0 and controller.repeat_previous_commands(), "repeat processes item commands after the previous units were consumed")
	_expect(controller.players[0].action_type == PalBattleController.ActionType.ATTACK and controller.players[1].action_type == PalBattleController.ActionType.DEFEND, "repeat falls back from exhausted thrown item to attack and used item to defend")
	controller.execute_remaining_actions()
	session.set_item_count(99, 1)
	session.set_item_count(153, 1)
	controller.repeat_previous_commands()
	_expect(controller.players[0].action_type == PalBattleController.ActionType.THROW_ITEM and controller.players[1].action_type == PalBattleController.ActionType.USE_ITEM and controller.available_item_count(99) == 0 and controller.available_item_count(153) == 0, "restored inventory reactivates cached item commands and reserves each repeated item once")


func _test_defeat() -> void:
	var database := _synthetic_database([
		_enemy_definition(999, 10, 1000, 0, 500, false),
	])
	database.player_roles.hp[0] = 1
	database.player_roles.max_hp[0] = 1
	database.player_roles.dexterities[0] = 0
	var found_damage_seed := false
	for seed_value in range(1, 128):
		var session := _session_for(database, PackedInt32Array([0]))
		var controller := PalBattleController.new()
		controller.start_battle(database, session, 0, 0, seed_value)
		controller.submit_attack(0)
		var result := controller.execute_next_action()
		if result != null and result.actor_is_enemy and not result.hits.is_empty() and result.hits[0].damage > 0:
			found_damage_seed = true
			_expect(controller.battle_result == PalBattleController.BattleResult.DEFEAT, "losing the last living player ends the battle in defeat")
			break
	_expect(found_damage_seed, "fixed seed search reaches a non-evaded enemy physical attack")


func _synthetic_database(enemy_definitions: Array[PalEnemyDefinition]) -> PalContentDatabase:
	var database := PalContentDatabase.new()
	database.player_roles = _synthetic_roles()
	database.enemy_objects.append(PalEnemyObjectDefinition.new())
	var team := PalEnemyTeam.new()
	team.team_id = 0
	for enemy_index in range(enemy_definitions.size()):
		var definition := enemy_definitions[enemy_index]
		definition.enemy_id = enemy_index
		database.enemies.append(definition)
		var object := PalEnemyObjectDefinition.new()
		object.object_id = enemy_index + 1
		object.enemy_id = enemy_index
		database.enemy_objects.append(object)
		team.object_ids.append(object.object_id)
	while team.object_ids.size() < PalEnemyTeam.MAX_ENEMIES:
		team.object_ids.append(0)
	database.enemy_teams.append(team)
	var battlefield := PalBattlefield.new()
	battlefield.battlefield_id = 0
	database.battlefields.append(battlefield)
	return database


func _synthetic_roles() -> PalPlayerRoles:
	var roles := PalPlayerRoles.new()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		roles.avatar_numbers.append(0)
		roles.battle_sprite_numbers.append(0)
		roles.scene_sprite_numbers.append(0)
		roles.name_word_indices.append(0)
		roles.attack_all.append(0)
		roles.levels.append(1)
		roles.max_hp.append(100)
		roles.max_mp.append(50)
		roles.hp.append(100)
		roles.mp.append(50)
		roles.equipments_by_role.append(PackedInt32Array([0, 0, 0, 0, 0, 0]))
		roles.attack_strengths.append(40)
		roles.magic_strengths.append(20)
		roles.defenses.append(20)
		roles.dexterities.append(40 - role_index)
		roles.flee_rates.append(20)
		roles.poison_resistances.append(0)
		roles.elemental_resistances_by_role.append(PackedInt32Array([0, 0, 0, 0, 0]))
		roles.magics_by_role.append(PackedInt32Array())
		roles.walk_frames.append(3)
		roles.death_sounds.append(0)
		roles.attack_sounds.append(0)
		roles.weapon_sounds.append(0)
		roles.critical_sounds.append(0)
		roles.magic_sounds.append(0)
		roles.cover_sounds.append(0)
		roles.dying_sounds.append(0)
	return roles


func _synthetic_progression(experience_per_level: int) -> PalLevelProgression:
	var progression := PalLevelProgression.new()
	for _role_index in range(PalPlayerRoles.ROLE_COUNT):
		progression.magic_learning_by_role.append([])
	for _level in range(PalLevelProgression.MAX_LEVEL + 1):
		progression.experience_thresholds.append(experience_per_level)
	return progression


func _enemy_definition(health: int, level: int, attack: int, defense: int, dexterity: int, dual_move: bool) -> PalEnemyDefinition:
	var enemy := PalEnemyDefinition.new()
	enemy.health = health
	enemy.level = level
	enemy.attack_strength = attack
	enemy.defense = defense
	enemy.dexterity = dexterity
	enemy.physical_resistance = 1
	enemy.dual_move = 1 if dual_move else 0
	return enemy


func _add_magic(database: PalContentDatabase, object_id: int, magic_type: int, mp_cost: int, base_damage: int, flags: int, success_script: int) -> void:
	while database.magic_objects.size() <= object_id:
		database.magic_objects.append(PalMagicObjectDefinition.new())
	var object := PalMagicObjectDefinition.new()
	object.object_id = object_id
	object.magic_number = database.magics.size()
	object.flags = flags
	object.script_on_success = success_script
	database.magic_objects[object_id] = object
	var definition := PalMagicDefinition.new()
	definition.magic_number = database.magics.size()
	definition.magic_type = magic_type
	definition.mp_cost = mp_cost
	definition.base_damage = base_damage
	database.magics.append(definition)


func _add_item(database: PalContentDatabase, object_id: int, use_script: int, throw_script: int, flags: int) -> void:
	while database.items.size() <= object_id:
		database.items.append(PalItemDefinition.new())
	var item := PalItemDefinition.new()
	item.object_id = object_id
	item.script_on_use = use_script
	item.script_on_throw = throw_script
	item.flags = flags
	database.items[object_id] = item


func _session_for(database: PalContentDatabase, party_roles: PackedInt32Array) -> GameSession:
	var session := GameSession.new()
	session.party_roles = party_roles
	session.initialize_role_state(database.player_roles)
	return session
