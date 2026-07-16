# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源验证脚本引用的敌队、战场背景和双方战斗 Sprite 可完整解析。
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
	var first_team := database.enemy_team_definition(18)
	if first_team == null or first_team.active_object_ids() != PackedInt32Array([495, 495]) or not database.load_battle_background(21).is_valid():
		_fail("前期首场强制战斗没有解析为战场 21、敌队 18 的两个敌人")
		return
	print("PASS: %d 个脚本敌队、%d 个脚本战场及 6 名角色战斗资源均可加载；首战为敌队 18 / 战场 21" % [referenced_teams.size(), referenced_battlefields.size()])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
