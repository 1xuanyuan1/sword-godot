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
	print("PASS: 首战普攻样板以结果 %d 结束，共执行 %d 次行动、%d 次有效伤害；胜利获得 %d 经验 / %d 文并触发升级" % [controller.battle_result, resolved_actions, damage_events, reward.experience, reward.cash])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
