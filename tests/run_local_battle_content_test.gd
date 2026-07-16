# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源验证敌队、战场背景、双方战斗 Sprite 和 FIRE 仙术特效可完整解析。
## 测试只输出编号与计数，不转储原版图像或文本。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	if database.enemies.size() != 154 or database.enemy_teams.size() != 380 or database.battlefields.size() != 65 or not database.enemy_positions.is_valid():
		_fail("战斗 DATA 结构数量不符：敌人 %d、敌队 %d、战场 %d" % [database.enemies.size(), database.enemy_teams.size(), database.battlefields.size()])
		return
	if database.level_progression == null or database.level_progression.experience_for_level(1) != 15 or 349 not in database.level_progression.magic_objects_for_level(0, 7):
		_fail("升级经验或李逍遥 7 级习得仙术规则与本地 DATA.MKF 不符")
		return
	var referenced_teams: Dictionary = {}
	var referenced_battlefields: Dictionary = {}
	var out_of_range_teams := PackedInt32Array()
	for entry in database.scripts:
		if entry.operation == 0x0007:
			referenced_teams[entry.operands[0]] = true
		elif entry.operation == 0x004a:
			referenced_battlefields[entry.operands[0]] = true
	for team_id in referenced_teams:
		var team := database.enemy_team_definition(team_id)
		if team == null:
			out_of_range_teams.append(team_id)
			continue
		if team.active_object_ids().is_empty():
			_fail("脚本引用了无效或空敌队 %d" % team_id)
			return
		for object_id in team.active_object_ids():
			var enemy := database.enemy_definition_for_object(object_id)
			if enemy == null or not database.load_enemy_battle_sprite(enemy.enemy_id).is_valid():
				_fail("敌队 %d 的对象 %d 缺少敌人属性或 Sprite" % [team_id, object_id])
				return
	# 当前 DOS 数据在连续测试表末尾保留了越界编号 380；正式剧情敌队范围仍为 0–379。
	if out_of_range_teams != PackedInt32Array([380]):
		_fail("脚本中出现未登记的越界敌队：%s" % out_of_range_teams)
		return
	for battlefield_id in referenced_battlefields:
		if database.battlefield_definition(battlefield_id) == null or not database.load_battle_background(battlefield_id).is_valid():
			_fail("脚本引用的战场 %d 缺少定义或背景" % battlefield_id)
			return
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		var sprite_number := database.player_roles.battle_sprite_for(role_index)
		if not database.load_player_battle_sprite(sprite_number).is_valid():
			_fail("角色 %d 缺少战斗 Sprite %d" % [role_index, sprite_number])
			return
	var effect_numbers: Dictionary = {}
	for magic in database.magics:
		# 召唤与未使用记录会把该字段解释为其他编号；FIRE.MKF 本数据集只有 0–54。
		if magic.effect_sprite >= 0 and magic.effect_sprite < 55:
			effect_numbers[magic.effect_sprite] = true
	for effect_number in effect_numbers:
		if not database.load_magic_effect_sprite(effect_number).is_valid():
			_fail("仙术属性引用的 FIRE.MKF 特效 %d 缺失" % effect_number)
			return
	var item_session := GameSession.new()
	item_session.party_roles = PackedInt32Array([0, 1])
	item_session.initialize_role_state(database.player_roles)
	for role_index in item_session.party_roles:
		item_session.role_hp[role_index] = item_session.role_max_hp[role_index]
	var item_controller := PalBattleController.new()
	if not item_controller.start_battle(database, item_session, 18, 21, 71):
		_fail("真实仙术和物品支持范围无法创建首战控制器")
		return
	if database.player_roles.cooperative_magic_for(0) != 386 or database.player_roles.covered_by_role(0) != 2 or item_session.cooperative_magic_for(0, database.player_roles) != 386 or not item_controller.can_pending_player_use_cooperative_magic():
		_fail("李逍遥合体气功或 PLAYERROLES 保护关系解析错误")
		return
	var enemy_magic_count := 0
	var supported_enemy_magic_count := 0
	for enemy in database.enemies:
		if enemy.magic <= 0 or enemy.magic == 0xffff:
			continue
		enemy_magic_count += 1
		var object := database.magic_object_definition(enemy.magic)
		var definition := database.magic_definition_for_object(enemy.magic)
		if object != null and definition != null and item_controller._enemy_magic_effect_is_supported(object, definition):
			supported_enemy_magic_count += 1
	if enemy_magic_count == 0 or supported_enemy_magic_count == 0:
		_fail("本地敌人仙术表没有可验证的基础攻击仙术")
		return
	var first_team := database.enemy_team_definition(18)
	if first_team == null or first_team.active_object_ids() != PackedInt32Array([495, 495]) or not database.load_battle_background(21).is_valid():
		_fail("前期首场强制战斗没有解析为战场 21、敌队 18 的两个敌人")
		return
	var supported_use_items := 0
	var supported_throw_items := 0
	for item in database.items:
		if item == null or item.object_id <= 0:
			continue
		item_session.set_item_count(item.object_id, 1)
		if item_controller.can_pending_player_use_item(item.object_id):
			supported_use_items += 1
		if item_controller.can_pending_player_throw_item(item.object_id):
			supported_throw_items += 1
	if supported_use_items == 0 or supported_throw_items == 0:
		_fail("本地物品表没有可执行的基础恢复品或攻击暗器")
		return
	print("PASS: %d 个脚本敌队、%d 个脚本战场、6 名角色、合击/保护关系、升级规则、%d 组 FIRE 特效、%d/%d 个已接入/全部敌术及 %d/%d 个使用/投掷物品均可加载；首战为敌队 18 / 战场 21" % [referenced_teams.size(), referenced_battlefields.size(), effect_numbers.size(), supported_enemy_magic_count, enemy_magic_count, supported_use_items, supported_throw_items])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
