# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从真实 DOS 对象根入口执行 TD-001 的关键剧情物品、仙术与明王脚本。
extends SceneTree

const ATTRIBUTE_ITEMS := [72, 112, 132, 150]


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地 DOS 内容不可用：%s" % database.error_message)
		return
	if not _test_attribute_items(database):
		return
	if not _test_placeable_story_items(database):
		return
	if not _test_battle_magics(database):
		return
	if not _test_mingwang_enemy_script(database):
		return
	print("PASS: 舍利子/試煉果/雪蛤蟆/金蠶王/捕獸夾/蘆葦漂/酒神/乾坤一擲/明王真实根入口回归通过")
	quit(0)


func _test_attribute_items(database: PalContentDatabase) -> bool:
	var session := GameSession.new()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	for item_id in ATTRIBUTE_ITEMS:
		var item := database.item_definition(item_id)
		if item == null or item.script_on_use <= 0:
			vm.free()
			return _fail_bool("属性物品 %d 缺少真实使用脚本" % item_id)
	var before_max_mp := session.role_max_mp[0]
	vm.run_trigger(database.item_definition(72).script_on_use, 0)
	if session.role_max_mp[0] != before_max_mp + 3:
		vm.free()
		return _fail_bool("舍利子没有从真实入口执行 0019 最大真气 +3（%d -> %d）" % [before_max_mp, session.role_max_mp[0]])
	var before_magic := session.role_magic_strength[0]
	vm.run_trigger(database.item_definition(112).script_on_use, 0)
	if session.role_magic_strength[0] != before_magic + 3:
		vm.free()
		return _fail_bool("試煉果没有从真实入口执行 0019 灵力 +3")
	var before_attack := session.role_attack_strength[0]
	before_magic = session.role_magic_strength[0]
	var before_defense := session.role_defense[0]
	vm.run_trigger(database.item_definition(132).script_on_use, 0)
	if session.role_attack_strength[0] != before_attack + 2 or session.role_magic_strength[0] != before_magic + 2 or session.role_defense[0] != before_defense + 2:
		vm.free()
		return _fail_bool("雪蛤蟆没有从真实入口同时提升武术/防御")
	var before_level := session.role_levels[0]
	vm.run_trigger(database.item_definition(150).script_on_use, 0)
	if session.role_levels[0] != mini(PalLevelProgression.MAX_LEVEL, before_level + 1):
		vm.free()
		return _fail_bool("金蠶王没有从真实入口执行 008D 升级")
	vm.free()
	return true


func _test_placeable_story_items(database: PalContentDatabase) -> bool:
	for item_id in [285, 294]:
		var item := database.item_definition(item_id)
		if item == null or item.script_on_use <= 0:
			return _fail_bool("剧情物品 %d 缺少真实使用脚本" % item_id)
		var first_entry := database.scripts[item.script_on_use]
		if first_entry.operation != 0x0084:
			return _fail_bool("剧情物品 %d 的真实根入口不是 0084" % item_id)
		var event_id := first_entry.operands[0]
		var scene_index := _scene_for_event(database, event_id)
		if scene_index < 0:
			return _fail_bool("0084 目标事件 %d 不属于任何场景" % event_id)
		var map := database.load_map(database.scenes[scene_index].map_number)
		if map == null or not map.is_valid():
			return _fail_bool("剧情物品 %d 的场景地图不可用" % item_id)
		var target_position := _first_open_half(map)
		if target_position.x < 0:
			return _fail_bool("剧情物品 %d 的地图没有可放置 half 格" % item_id)
		var target_event := database.event_objects[event_id - 1]
		var old_position := target_event.position
		var old_state := target_event.state
		var session := GameSession.new()
		session.scene_index = scene_index
		session.party_direction = GameSession.DIR_EAST
		session.set_party_world_position(target_position - Vector2i(16, 8))
		var vm := ScriptVM.new()
		vm.configure(database, session)
		vm.set_scene_map(map)
		vm.run_trigger(item.script_on_use, 0)
		var placed := target_event.position == target_position and target_event.state == 2 and vm.script_success
		target_event.position = old_position
		target_event.state = old_state
		vm.free()
		if not placed:
			return _fail_bool("剧情物品 %d 未从真实根入口完成正式地图阻挡检查与事件放置" % item_id)
	return true


func _test_battle_magics(database: PalContentDatabase) -> bool:
	var team_id := _first_valid_team(database)
	if team_id < 0:
		return _fail_bool("没有可用于真实仙术脚本回归的敌队")
	var session := GameSession.new()
	session.party_roles = PackedInt32Array([0])
	session.initialize_role_state(database.player_roles)
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, 0, 20260717):
		return _fail_bool("真实仙术战斗环境无法启动：%s" % controller.error_message)

	var wine_god := database.magic_object_definition(370)
	var wine_definition := database.magic_definition_for_object(370)
	if wine_god == null or wine_definition == null:
		return _fail_bool("酒神对象 370 无法加载")
	session.role_mp[0] = 50
	session.set_item_count(86, 1)
	var result := PalBattleController.ActionResult.new()
	var wine_outcome := controller._run_battle_effect_script(wine_god.script_on_use, false, false, 0, result)
	if not bool(wine_outcome.success) or session.item_count(86) != 0 or session.role_mp[0] != 0 or wine_definition.base_damage != 400:
		return _fail_bool("酒神真实使用入口没有执行 0020/0057、清空 MP 并设置 8 倍基础伤害")

	var coin_magic := database.magic_object_definition(394)
	var coin_definition := database.magic_definition_for_object(394)
	if coin_magic == null or coin_definition == null:
		return _fail_bool("乾坤一擲对象 394 无法加载")
	session.cash = 7000
	var coin_outcome := controller._run_battle_effect_script(coin_magic.script_on_use, false, false, 0, PalBattleController.ActionResult.new())
	if not bool(coin_outcome.success) or session.cash != 2000 or coin_definition.base_damage != 2000:
		return _fail_bool("乾坤一擲真实使用入口没有执行 0088 的 5000 上限与四成伤害换算")
	return true


func _test_mingwang_enemy_script(database: PalContentDatabase) -> bool:
	var mingwang := database.enemy_object_definition(519)
	if mingwang == null or database.enemy_definition_for_object(519) == null:
		return _fail_bool("明王对象 519 无法加载")
	var team := PalEnemyTeam.new()
	team.team_id = database.enemy_teams.size()
	team.object_ids = PackedInt32Array([519, 0, 0, 0, 0])
	database.enemy_teams.append(team)
	var session := GameSession.new()
	session.party_roles = PackedInt32Array([0, 1])
	session.initialize_role_state(database.player_roles)
	var base_level := session.role_levels[1]
	var base_max_hp := session.role_max_hp[1]
	var base_max_mp := session.role_max_mp[1]
	var base_attack := session.role_attack_strength[1]
	var base_magic := session.role_magic_strength[1]
	var base_defense := session.role_defense[1]
	var base_dexterity := session.role_dexterity[1]
	var base_flee := session.role_flee_rate[1]
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team.team_id, 0, 519):
		return _fail_bool("明王战斗环境无法启动：%s" % controller.error_message)
	# 原剧情在此段复活倒下的赵灵儿；保持真实前置状态，0022 才应成功。
	session.role_hp[1] = 0
	# a16d 是从明王真实 turn 根 a125 线性可达的八条 0019 成长段。
	var result := PalBattleController.ActionResult.new()
	var outcome := controller._run_enemy_battle_script(0xa16d, 0, result)
	if not bool(outcome.success):
		return _fail_bool("明王真实敌人脚本的 0019 成长段未执行完成")
	var expected := (
		session.role_levels[1] == ((base_level + 11) & 0xffff)
		and session.role_max_hp[1] == ((base_max_hp + 170) & 0xffff)
		and session.role_max_mp[1] == ((base_max_mp + 190) & 0xffff)
		and session.role_attack_strength[1] == ((base_attack + 100) & 0xffff)
		and session.role_magic_strength[1] == ((base_magic + 155) & 0xffff)
		and session.role_defense[1] == ((base_defense + 55) & 0xffff)
		and session.role_dexterity[1] == ((base_dexterity + 80) & 0xffff)
		and session.role_flee_rate[1] == ((base_flee + 30) & 0xffff)
	)
	if not expected:
		return _fail_bool("明王 0019 没有按真实操作数修改赵灵儿的八组 PLAYERROLES 字段")
	return true


func _scene_for_event(database: PalContentDatabase, event_id: int) -> int:
	var event_index := event_id - 1
	for scene_index in range(database.scenes.size() - 1):
		var start := database.scenes[scene_index].event_object_index
		var finish := database.scenes[scene_index + 1].event_object_index
		if event_index >= start and event_index < finish:
			return scene_index
	return -1


func _first_open_half(map: PalMapData) -> Vector2i:
	for y in range(2, PalMapData.HEIGHT - 2):
		for x in range(2, PalMapData.WIDTH - 2):
			for half in range(PalMapData.HALVES):
				if not PalMapData.is_blocked(map.tile_value(x, y, half)):
					return Vector2i(x * 32 + half * 16, y * 16 + half * 8)
	return Vector2i(-1, -1)


func _first_valid_team(database: PalContentDatabase) -> int:
	for team_id in range(database.enemy_teams.size()):
		var team := database.enemy_team_definition(team_id)
		if team != null and not team.active_object_ids().is_empty() and database.enemy_definition_for_object(team.active_object_ids()[0]) != null:
			return team_id
	return -1


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
