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
	var summon_definition := database.magic_definition_for_object(315)
	var summon_effect_object_id := database.magic_object_id_for_magic_number(summon_definition.effect_sprite) if summon_definition != null else 0
	var summon_effect_definition := database.magic_definition_for_object(summon_effect_object_id)
	if summon_definition == null or summon_definition.magic_type != PalMagicDefinition.TYPE_SUMMON or not database.load_player_battle_sprite(summon_definition.specific + 10).is_valid():
		_fail("风神 315 没有解析为带 F.MKF 神将 Sprite 的召唤仙术")
		return
	if summon_effect_object_id <= 0 or summon_effect_definition == null or not database.load_magic_effect_sprite(summon_effect_definition.effect_sprite).is_valid():
		_fail("风神 315 没有按召唤记录的 effect_sprite 找到后续 FIRE 特效")
		return
	var summon_session := GameSession.new()
	summon_session.party_roles = PackedInt32Array([0])
	summon_session.initialize_role_state(database.player_roles)
	summon_session.learned_magics_by_role[0] = PackedInt32Array([315])
	summon_session.role_hp[0] = summon_session.role_max_hp[0]
	summon_session.role_max_mp[0] = 999
	summon_session.role_mp[0] = 999
	summon_session.role_dexterity[0] = 999
	var summon_controller := PalBattleController.new()
	if not summon_controller.start_battle(database, summon_session, 18, 21, 72) or not summon_controller.submit_magic(315, 0):
		_fail("真实风神 315 无法在首战控制器中提交")
		return
	var summon_mp_before := summon_session.role_mp[0]
	var summon_result := summon_controller.execute_next_action()
	if summon_result == null or summon_result.unsupported or summon_result.target_index != -1 or summon_result.hits.size() != 2 or summon_session.role_mp[0] != summon_mp_before - summon_definition.mp_cost:
		var result_summary := "null" if summon_result == null else "type=%d unsupported=%s target=%d hits=%d" % [summon_result.action_type, summon_result.unsupported, summon_result.target_index, summon_result.hits.size()]
		_fail("真实风神 315 没有扣除 MP 并伤害敌方全体：%s，MP %d→%d（消耗 %d）" % [result_summary, summon_mp_before, summon_session.role_mp[0], summon_definition.mp_cost])
		return
	var trance_definition := database.magic_definition_for_object(295)
	if trance_definition == null or trance_definition.magic_type != PalMagicDefinition.TYPE_TRANCE:
		_fail("梦蛇 295 没有解析为变身仙术")
		return
	var trance_session := GameSession.new()
	trance_session.party_roles = PackedInt32Array([1])
	trance_session.initialize_role_state(database.player_roles)
	trance_session.learned_magics_by_role[1] = PackedInt32Array([295])
	trance_session.role_hp[1] = trance_session.role_max_hp[1]
	trance_session.role_max_mp[1] = 999
	trance_session.role_mp[1] = 999
	trance_session.role_dexterity[1] = 999
	var trance_controller := PalBattleController.new()
	if not trance_controller.start_battle(database, trance_session, 18, 21, 74) or not trance_controller.submit_magic(295, 99):
		_fail("真实梦蛇 295 无法作为施法者自身目标提交")
		return
	var trance_result := trance_controller.execute_next_action()
	if trance_result == null or trance_result.unsupported or trance_result.target_index != 0 or trance_session.battle_sprite_for(1, database.player_roles.battle_sprite_for(1)) != 5:
		_fail("真实梦蛇 295 没有把赵灵儿的临时战斗 Sprite 切换为 5")
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
	var scripted_session := GameSession.new()
	scripted_session.party_roles = PackedInt32Array([0, 1])
	scripted_session.initialize_role_state(database.player_roles)
	for role_index in scripted_session.party_roles:
		scripted_session.role_hp[role_index] = scripted_session.role_max_hp[role_index]
	var dialog_controller := PalBattleController.new()
	if not dialog_controller.start_battle(database, scripted_session, 22, 21, 81) or not dialog_controller.has_pending_script_results():
		_fail("真实敌队 22 没有在指令选择前进入回合开始脚本")
		return
	var dialog_result := dialog_controller.execute_next_action()
	if dialog_result == null or not dialog_result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.DIALOG_MESSAGE):
		_fail("真实敌队 22 的回合开始脚本没有输出战斗对白")
		return
	var escape_controller := PalBattleController.new()
	if not escape_controller.start_battle(database, scripted_session, 25, 21, 82):
		_fail("真实敌队 25 的脚本终止战斗无法初始化")
		return
	var escape_result := escape_controller.execute_next_action()
	if escape_controller.battle_result != PalBattleController.BattleResult.TERMINATED or escape_result == null or not escape_result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.ENEMY_ESCAPE):
		_fail("真实敌队 25 没有通过 0069 进入敌人逃跑结果")
		return
	var drop_session := GameSession.new()
	drop_session.party_roles = PackedInt32Array([0])
	drop_session.initialize_role_state(database.player_roles)
	drop_session.role_hp[0] = drop_session.role_max_hp[0]
	var drop_controller := PalBattleController.new()
	if not drop_controller.start_battle(database, drop_session, 46, 21, 83):
		_fail("真实敌队 46 无法用于战后掉落回归")
		return
	for enemy_index in range(drop_controller.enemies.size()):
		drop_controller._apply_enemy_damage(enemy_index, drop_controller.enemies[enemy_index].hp, false)
	drop_controller._check_battle_result()
	var drop_reward := drop_controller.claim_victory_rewards()
	if drop_reward == null or drop_session.item_count(104) != 2 or drop_reward.script_events.size() != 6:
		_fail("真实敌队 46 的两个对象 402 没有各执行一次战后掉落与居中提示")
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
	var script_audit := _audit_enemy_battle_scripts(database)
	var unsupported: Array = script_audit.get("unsupported", [])
	if not unsupported.is_empty():
		_fail("真实敌人战斗脚本仍有未支持入口：%s" % unsupported)
		return
	print("PASS: %d 个脚本敌队、%d 个脚本战场、6 名角色、合击/保护关系、升级规则、风神/梦蛇、%d 组 FIRE 特效、%d/%d 个已接入/全部敌术、%d/%d 个使用/投掷物品及 %d/%d/%d 个敌人回合/就绪/战后脚本入口均可加载；敌队 22 对白、25 逃跑、46 双掉落可执行，首战为敌队 18 / 战场 21" % [referenced_teams.size(), referenced_battlefields.size(), effect_numbers.size(), supported_enemy_magic_count, enemy_magic_count, supported_use_items, supported_throw_items, script_audit.get("turn", 0), script_audit.get("ready", 0), script_audit.get("end", 0)])
	quit(0)


func _audit_enemy_battle_scripts(database: PalContentDatabase) -> Dictionary:
	var object_ids: Dictionary = {}
	for team in database.enemy_teams:
		for object_id in team.active_object_ids():
			object_ids[object_id] = true
	var roots := {"turn": {}, "ready": {}, "end": {}}
	for object_id in object_ids:
		var object := database.enemy_object_definition(int(object_id))
		if object == null:
			continue
		if object.script_on_turn_start > 0:
			roots["turn"][object.script_on_turn_start] = true
		if object.script_on_ready > 0:
			roots["ready"][object.script_on_ready] = true
		if object.script_on_battle_end > 0:
			roots["end"][object.script_on_battle_end] = true
	var unsupported: Array[String] = []
	for kind in roots:
		for root in roots[kind]:
			_scan_enemy_script(database, int(root), str(kind), unsupported)
	return {
		"turn": roots["turn"].size(),
		"ready": roots["ready"].size(),
		"end": roots["end"].size(),
		"unsupported": unsupported,
	}


func _scan_enemy_script(database: PalContentDatabase, root: int, kind: String, unsupported: Array[String]) -> void:
	var pending := [root]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var cursor: int = pending.pop_back()
		while cursor > 0 and cursor < database.scripts.size() and not visited.has(cursor):
			visited[cursor] = true
			var entry := database.scripts[cursor]
			if not PalBattleController.is_enemy_script_opcode_supported(entry.operation):
				unsupported.append("%s:%04X/%04X" % [kind, cursor, entry.operation])
				break
			match entry.operation:
				0x0000, 0x0001:
					break
				0x0002:
					pending.append(entry.operands[0])
					break
				0x0003:
					cursor = entry.operands[0]
					continue
				0x0004:
					pending.append(entry.operands[0])
				0x0006:
					pending.append(entry.operands[1])
				0x002e:
					pending.append(entry.operands[2])
				0x005e, 0x0064, 0x0079:
					pending.append(entry.operands[1])
				0x0091:
					pending.append(entry.operands[0])
				0x009c:
					pending.append(entry.operands[1])
				0x009e:
					pending.append(entry.operands[2])
				0x00a2:
					for offset in range(1, maxi(1, entry.operands[0]) + 1):
						pending.append(cursor + offset)
					break
			cursor += 1


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
