# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源自动打完敌队 18 / 战场 21 的普攻样板。
## 验证真实 PLAYERROLES 和黑苗敌人数据可走完行动队列，不输出任何原版素材。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	# 仙灵岛最低级绿叶小妖的基础防御是 0xFFFA；与等级修正相加后应按 WORD 回绕为 18。
	var leaf_session := GameSession.new()
	leaf_session.party_roles = PackedInt32Array([0])
	var leaf_controller := PalBattleController.new()
	if not leaf_controller.start_battle(database, leaf_session, 16, 0, 20260722):
		_fail("仙灵岛绿叶小妖战斗无法初始化")
		return
	if leaf_controller.enemies.is_empty() or leaf_controller.enemies[0].object_id != 499 or leaf_controller.enemies[0].definition.defense != 0xfffa:
		_fail("敌队 16 不再是预期的绿叶小妖数据")
		return
	leaf_session.role_dexterity[0] = 999
	if not leaf_controller.submit_attack(0):
		_fail("李逍遥无法攻击绿叶小妖")
		return
	var leaf_attack := leaf_controller.execute_next_action()
	if leaf_attack == null or leaf_attack.actor_is_enemy or leaf_attack.hits.is_empty() or leaf_attack.hits[0].damage <= 1:
		_fail("绿叶小妖防御符号位仍让李逍遥普攻退化为 1 点")
		return
	var leaf_damage := leaf_attack.hits[0].damage
	var session := GameSession.new()
	session.party_roles = PackedInt32Array([0, 1])
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, 18, 21, 20260716):
		_fail("首战逻辑无法初始化：%s" % controller.error_message)
		return
	if controller.enemies.size() != 2:
		_fail("首战应有两个敌人，实际为 %d" % controller.enemies.size())
		return
	var resolved_actions := 0
	var damage_events := 0
	while controller.battle_result == PalBattleController.BattleResult.ONGOING and controller.turn_number <= 30:
		while controller.is_accepting_commands():
			var living := controller.living_enemy_indices()
			if living.is_empty() or not controller.submit_attack(living[0]):
				_fail("首战无法提交普通攻击")
				return
		for result in controller.execute_remaining_actions():
			resolved_actions += 1
			if result.unsupported:
				_fail("首战敌人触发了尚未支持的法术行动")
				return
			for hit in result.hits:
				if hit.damage > 0:
					damage_events += 1
	if controller.battle_result == PalBattleController.BattleResult.ONGOING:
		_fail("首战普攻样板在 30 回合内没有结束")
		return
	if resolved_actions == 0 or damage_events == 0:
		_fail("首战没有产生可观察的行动与伤害")
		return

	# 用同一真实敌队独立验证胜利奖励；直接清空 HP 只缩短测试，不绕过控制器的奖励累计。
	var reward_session := GameSession.new()
	reward_session.party_roles = PackedInt32Array([0, 1])
	var reward_controller := PalBattleController.new()
	if not reward_controller.start_battle(database, reward_session, 18, 21, 20260717):
		_fail("首战奖励回归无法初始化")
		return
	var expected_experience := 0
	var expected_cash := 0
	for enemy_index in range(reward_controller.enemies.size()):
		var enemy := reward_controller.enemies[enemy_index]
		expected_experience += enemy.definition.experience
		expected_cash += enemy.definition.cash
		reward_controller._apply_enemy_damage(enemy_index, enemy.hp, false)
	reward_controller._check_battle_result()
	var old_level := reward_session.role_levels[0]
	var reward := reward_controller.claim_victory_rewards()
	if reward == null or reward.experience != expected_experience or reward.cash != expected_cash or reward_session.cash != expected_cash:
		_fail("首战经验/金钱没有按真实敌人属性结算")
		return
	if reward_session.role_levels[0] <= old_level or reward.level_ups.is_empty():
		_fail("李逍遥没有按真实 DATA.MKF #14 阈值在首战后升级")
		return
	var enemy_magic_sample := _find_enemy_magic_sample(database)
	if enemy_magic_sample.is_empty():
		_fail("找不到可准确结算的真实敌人攻击仙术")
		return
	var magic_session := GameSession.new()
	magic_session.party_roles = PackedInt32Array([0, 1])
	var magic_controller := PalBattleController.new()
	var magic_team := int(enemy_magic_sample.get("team", -1))
	if not magic_controller.start_battle(database, magic_session, magic_team, 21, 20260718):
		_fail("真实敌人仙术样板无法初始化")
		return
	var magic_result := PalBattleController.ActionResult.new()
	magic_result.actor_is_enemy = true
	magic_result.actor_index = int(enemy_magic_sample.get("enemy_index", -1))
	magic_controller._execute_enemy_magic(magic_result.actor_index, 0, magic_result)
	if magic_result.unsupported or magic_result.action_type != PalBattleController.ActionType.MAGIC or magic_result.hits.is_empty() or magic_result.hits[0].damage <= 0:
		_fail("真实敌人基础攻击仙术没有产生玩家伤害")
		return
	var item_session := GameSession.new()
	item_session.party_roles = PackedInt32Array([0, 1])
	item_session.set_item_count(99, 1)
	var item_controller := PalBattleController.new()
	if not item_controller.start_battle(database, item_session, 18, 21, 20260719):
		_fail("真实止血草战斗样板无法初始化")
		return
	item_session.role_hp[1] = 20
	item_session.role_dexterity[0] = 999
	if not item_controller.submit_use_item(99, 1):
		_fail("止血草无法提交给第二名队员")
		return
	item_controller.submit_defend()
	var item_result := item_controller.execute_next_action()
	if item_result == null or item_result.action_type != PalBattleController.ActionType.USE_ITEM or item_session.role_hp[1] != 70 or item_session.item_count(99) != 0:
		_fail("止血草没有按真实脚本恢复 50 HP 并消耗一个")
		return
	var throw_session := GameSession.new()
	throw_session.party_roles = PackedInt32Array([0, 1])
	throw_session.set_item_count(153, 1)
	var throw_controller := PalBattleController.new()
	throw_controller.start_battle(database, throw_session, 18, 21, 20260720)
	throw_session.role_dexterity[0] = 999
	if not throw_controller.submit_throw_item(153, 0):
		_fail("梅花镖无法提交给真实首战敌人")
		return
	throw_controller.submit_defend()
	var throw_result := throw_controller.execute_next_action()
	if throw_result == null or throw_result.action_type != PalBattleController.ActionType.THROW_ITEM or throw_result.hits.is_empty() or throw_result.hits[0].damage <= 0 or throw_session.item_count(153) != 0:
		_fail("梅花镖没有按真实 0042 脚本伤敌并消耗一个")
		return
	var flee_session := GameSession.new()
	flee_session.party_roles = PackedInt32Array([0, 1])
	var flee_controller := PalBattleController.new()
	flee_controller.start_battle(database, flee_session, 18, 21, 20260721, false)
	flee_session.role_dexterity[0] = 999
	flee_session.role_flee_rate[0] = 999
	flee_controller.submit_flee()
	var flee_result := flee_controller.execute_next_action()
	if flee_result == null or not flee_result.flee_succeeded or flee_controller.battle_result != PalBattleController.BattleResult.FLED:
		_fail("真实首战敌队没有按经典逃跑公式返回 FLED")
		return
	var poison := database.poison_definition(551)
	var poison_session := GameSession.new()
	poison_session.party_roles = PackedInt32Array([0])
	var poison_controller := PalBattleController.new()
	if poison == null or not poison_controller.start_battle(database, poison_session, 16, 0, 20260723):
		_fail("真实基础毒或绿叶小妖回合无法初始化")
		return
	poison_session.add_role_poison(0, 551, poison.player_script)
	poison_controller.submit_defend()
	var poison_tick_found := false
	for poison_result in poison_controller.execute_remaining_actions():
		if poison_result.action_type == PalBattleController.ActionType.POISON and poison_result.hits.any(func(hit: PalBattleController.Hit) -> bool: return not hit.target_is_enemy and hit.damage == 7):
			poison_tick_found = true
	if not poison_tick_found:
		_fail("真实 551 号毒没有在经典回合末造成 7 点伤害")
		return
	print("PASS: 李逍遥对绿叶小妖普攻 %d 点；首战样板结果 %d、%d 次行动/%d 次伤害；奖励 %d 经验/%d 文；敌术 %d、止血草、梅花镖、基础毒和逃跑均可结算" % [leaf_damage, controller.battle_result, resolved_actions, damage_events, reward.experience, reward.cash, magic_result.magic_object_id])
	quit(0)


func _find_enemy_magic_sample(database: PalContentDatabase) -> Dictionary:
	for team_id in range(database.enemy_teams.size()):
		var team := database.enemy_team_definition(team_id)
		if team == null:
			continue
		var objects := team.active_object_ids()
		for enemy_index in range(objects.size()):
			var enemy := database.enemy_definition_for_object(objects[enemy_index])
			if enemy == null or enemy.magic <= 0 or enemy.magic == 0xffff:
				continue
			var object := database.magic_object_definition(enemy.magic)
			var definition := database.magic_definition_for_object(enemy.magic)
			if object != null and definition != null and object.script_on_use == 0 and object.script_on_success == 0 and definition.base_damage > 0 and definition.base_damage < 0x8000 and definition.magic_type in [PalMagicDefinition.TYPE_NORMAL, PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD]:
				return {"team": team_id, "enemy_index": enemy_index, "magic": enemy.magic}
	return {}


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
