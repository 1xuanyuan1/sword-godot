# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机真实资源验证从隐龙窟近迹进入迷宫、击败两名 Boss、石钥匙开门并抵达白河村。
## 测试只比较消息编号、场景状态和战斗结果，不输出或提交原版对白与画面资源。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var failure := _test_hidden_dragon_to_baihe(database)
	if not failure.is_empty():
		printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: 隐龙窟近迹、半人蛇／狐狸精 Boss、石钥匙开门、少女离洞及抵达白河村主线完成")
	quit(0)


func _test_hidden_dragon_to_baihe(database: PalContentDatabase) -> String:
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = 41
	session.party_roles = PackedInt32Array([2, 0])
	session.initialize_role_state(database.player_roles)
	for role_index in session.party_roles:
		session.role_hp[role_index] = session.role_max_hp[role_index]
		session.role_mp[role_index] = session.role_max_mp[role_index]
	session.set_party_world_position(Vector2i(1760, 1792))

	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var requested_scenes: Array[int] = []
	var battle_requests: Array = []
	var next_entries: Array[int] = []
	var unsupported: Array[String] = []
	var music_requests: Array = []
	vm.dialog_message.connect(func(index: int) -> void: messages.append(index))
	vm.scene_change_requested.connect(func(index: int) -> void: requested_scenes.append(index))
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: battle_requests.append([team, field, boss]))
	vm.script_finished.connect(func(next: int) -> void: next_entries.append(next))
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.music_requested.connect(func(number: int, loop: bool, fade: float) -> void: music_requests.append([number, loop, fade]))

	vm.run_trigger(database.scenes[41].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty() or next_entries != [13819] or music_requests != [[82, true, 0.0]] or session.battlefield_number != 3 or session.battle_music_number != 37:
		vm.free()
		return "隐龙窟近迹进入状态不正确：unsupported=%s next=%s music=%s field=%d battle_music=%d" % [unsupported, next_entries, music_requests, session.battlefield_number, session.battle_music_number]

	# 近迹入口剧情调整队伍顺序，并把两人送到隐龙窟第二段迷宫。
	messages.clear()
	requested_scenes.clear()
	next_entries.clear()
	var nearby_exit := database.event_objects[691]
	vm.run_trigger(nearby_exit.trigger_script, nearby_exit.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or messages != _message_range(3828, 3846) or requested_scenes != [43] or session.scene_index != 43 or session.party_world_position() != Vector2i(1824, 1872):
		vm.free()
		return "隐龙窟近迹剧情没有进入第二段迷宫：messages=%s scenes=%s/%d pos=%s unsupported=%s" % [messages, requested_scenes, session.scene_index, session.party_world_position(), unsupported]
	if next_entries != [13583] or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "进入迷宫后的稳定入口或队伍顺序不正确：next=%s party=%s" % [next_entries, session.party_roles]
	nearby_exit.trigger_script = next_entries[0]

	# 新迷宫入口切换区域音乐和半人蛇／狐狸精共用的战场配置。
	music_requests.clear()
	next_entries.clear()
	vm.run_trigger(database.scenes[43].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty() or next_entries != [14078] or music_requests != [[78, true, 0.0]] or session.music_number != 78 or session.battlefield_number != 24 or session.battle_music_number != 37:
		vm.free()
		return "隐龙窟第二段入口环境不正确：next=%s music=%s/%d field=%d battle_music=%d" % [next_entries, music_requests, session.music_number, session.battlefield_number, session.battle_music_number]

	# 只固定主线需要的两次迷宫出口；地图寻路和每个岔路由 TileMap 视觉回归负责。
	requested_scenes.clear()
	next_entries.clear()
	var maze_to_crossroads := database.event_objects[703]
	vm.run_trigger(maze_to_crossroads.trigger_script, maze_to_crossroads.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or requested_scenes != [45] or session.scene_index != 45:
		vm.free()
		return "隐龙窟第二段没有进入交叉迷宫：scenes=%s/%d unsupported=%s" % [requested_scenes, session.scene_index, unsupported]
	requested_scenes.clear()
	var crossroads_to_snake := database.event_objects[763]
	vm.run_trigger(crossroads_to_snake.trigger_script, crossroads_to_snake.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or requested_scenes != [40] or session.scene_index != 40:
		vm.free()
		return "交叉迷宫没有进入半人蛇区域：scenes=%s/%d unsupported=%s" % [requested_scenes, session.scene_index, unsupported]

	# 半人蛇触发敌队 45／战场 24；真实控制器结算胜利后，未来入口不再重复开战。
	messages.clear()
	battle_requests.clear()
	next_entries.clear()
	var snake_event := database.event_objects[673]
	vm.run_trigger(snake_event.trigger_script, snake_event.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or not vm.waiting_for_battle or battle_requests != [[45, 24, true]] or messages != _message_range(3955, 3963):
		vm.free()
		return "半人蛇战前脚本不正确：battle=%s messages=%s unsupported=%s" % [battle_requests, messages, unsupported]
	var battle_failure := _resolve_boss(database, session, 45, 24, 486, 45001)
	if not battle_failure.is_empty():
		vm.free()
		return battle_failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty() or next_entries != [13902] or session.battle_music_number != 40:
		vm.free()
		return "半人蛇胜利后没有恢复后续战斗音乐：next=%s battle_music=%d unsupported=%s" % [next_entries, session.battle_music_number, unsupported]
	snake_event.trigger_script = next_entries[0]
	messages.clear()
	next_entries.clear()
	vm.run_trigger(snake_event.trigger_script, snake_event.object_id)
	_drive_script(vm)
	if messages != [3964] or not battle_requests == [[45, 24, true]] or next_entries != [13902]:
		vm.free()
		return "半人蛇胜利后的再次接触仍重复开战或对白错误：messages=%s battles=%s next=%s" % [messages, battle_requests, next_entries]

	# 从半人蛇区域进入内洞，狐狸精胜利后取得石钥匙并清除 Boss EventObject。
	requested_scenes.clear()
	var snake_area_exit := database.event_objects[672]
	vm.run_trigger(snake_area_exit.trigger_script, snake_area_exit.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or requested_scenes != [46] or session.scene_index != 46:
		vm.free()
		return "半人蛇区域没有进入隐龙窟内洞：scenes=%s/%d unsupported=%s" % [requested_scenes, session.scene_index, unsupported]
	messages.clear()
	battle_requests.clear()
	next_entries.clear()
	var fox_event := database.event_objects[770]
	vm.run_trigger(fox_event.trigger_script, fox_event.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or not vm.waiting_for_battle or battle_requests != [[44, 24, true]] or messages != _message_range(3965, 3997) or fox_event.state != 0:
		vm.free()
		return "狐狸精战前脚本不正确：battle=%s messages=%s state=%d unsupported=%s" % [battle_requests, messages, fox_event.state, unsupported]
	battle_failure = _resolve_boss(database, session, 44, 24, 469, 44001)
	if not battle_failure.is_empty():
		vm.free()
		return battle_failure
	vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_drive_script(vm)
	if not unsupported.is_empty() or messages != _message_range(3965, 4016) or next_entries != [13905] or session.item_count(289) != 1 or session.battle_music_number != 40:
		vm.free()
		return "狐狸精胜利后没有释放少女并取得石钥匙：messages=%s next=%s key=%d battle_music=%d unsupported=%s" % [messages, next_entries, session.item_count(289), session.battle_music_number, unsupported]

	# 面对石门使用对象 289；物品脚本把门改为接触入口，消耗钥匙并解除阻挡。
	var stone_door := database.event_objects[767]
	session.party_direction = GameSession.DIR_SOUTH
	session.set_party_world_position(Vector2i(480, 976))
	messages.clear()
	next_entries.clear()
	vm.run_trigger(stone_door.trigger_script, stone_door.object_id)
	_drive_script(vm)
	if messages != [4024] or next_entries != [14066]:
		vm.free()
		return "石门在使用钥匙前没有显示锁住提示：messages=%s next=%s" % [messages, next_entries]
	var stone_key := database.item_definition(289)
	next_entries.clear()
	vm.run_trigger(stone_key.script_on_use, 0xffff)
	_drive_script(vm)
	if not unsupported.is_empty() or not vm.script_success or stone_door.trigger_script != 14069 or session.item_count(289) != 0 or not vm.touch_trigger_armed:
		vm.free()
		return "石钥匙没有安装开门入口并消耗：success=%s trigger=%d key=%d armed=%s unsupported=%s" % [vm.script_success, stone_door.trigger_script, session.item_count(289), vm.touch_trigger_armed, unsupported]
	vm.run_trigger(stone_door.trigger_script, stone_door.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or stone_door.state != 1 or stone_door.trigger_mode != 0:
		vm.free()
		return "石门打开后仍然阻挡或可重复触发：state=%d mode=%d unsupported=%s" % [stone_door.state, stone_door.trigger_mode, unsupported]

	# 穿过石门离洞；山路剧情送走获救少女，随后从正式出口进入白河村。
	requested_scenes.clear()
	var cave_exit := database.event_objects[768]
	vm.run_trigger(cave_exit.trigger_script, cave_exit.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or requested_scenes != [47] or session.scene_index != 47 or session.party_world_position() != Vector2i(464, 1672):
		vm.free()
		return "隐龙窟石门后出口没有进入白河村前山路：scenes=%s/%d pos=%s unsupported=%s" % [requested_scenes, session.scene_index, session.party_world_position(), unsupported]
	messages.clear()
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[47].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty() or messages != _message_range(4384, 4400) or next_entries != [15155] or music_requests != [[12, true, 0.0]] or session.battlefield_number != 2:
		vm.free()
		return "获救少女离洞剧情不完整：messages=%s next=%s music=%s field=%d unsupported=%s" % [messages, next_entries, music_requests, session.battlefield_number, unsupported]
	if database.event_objects.slice(790, 795).any(func(event: PalEventObject) -> bool: return event.state != 0):
		vm.free()
		return "离洞剧情结束后少女 EventObject 791–795 没有清理"

	requested_scenes.clear()
	next_entries.clear()
	var road_exit := database.event_objects[789]
	vm.run_trigger(road_exit.trigger_script, road_exit.object_id)
	_drive_script(vm)
	if not unsupported.is_empty() or requested_scenes != [48] or session.scene_index != 48 or session.party_world_position() != Vector2i(576, 1632):
		vm.free()
		return "白河村前山路没有进入村内：scenes=%s/%d pos=%s unsupported=%s" % [requested_scenes, session.scene_index, session.party_world_position(), unsupported]
	next_entries.clear()
	music_requests.clear()
	vm.run_trigger(database.scenes[48].script_on_enter)
	_drive_script(vm)
	if not unsupported.is_empty() or next_entries != [15519] or music_requests != [[12, true, 0.0]] or session.music_number != 12 or PalSceneCatalog.name_for_scene_index(session.scene_index) != "白河村" or session.party_roles != PackedInt32Array([0, 2]):
		vm.free()
		return "抵达白河村后的稳定状态不正确：next=%s music=%s/%d scene=%s party=%s unsupported=%s" % [next_entries, music_requests, session.music_number, PalSceneCatalog.name_for_scene_index(session.scene_index), session.party_roles, unsupported]
	vm.free()
	return ""


func _resolve_boss(database: PalContentDatabase, session: GameSession, team_id: int, field_id: int, expected_object_id: int, seed: int) -> String:
	var controller := PalBattleController.new()
	if not controller.start_battle(database, session, team_id, field_id, seed, true):
		return "Boss 敌队 %d／战场 %d 无法建立：%s" % [team_id, field_id, controller.error_message]
	if controller.enemies.size() != 1 or controller.enemies[0].object_id != expected_object_id:
		return "Boss 敌队 %d 对象不正确：%s" % [team_id, controller.enemies.map(func(enemy: PalBattleController.EnemyState) -> int: return enemy.object_id)]
	controller._apply_enemy_damage(0, controller.enemies[0].hp, false)
	controller._check_battle_result()
	var reward := controller.claim_victory_rewards()
	if controller.battle_result != PalBattleController.BattleResult.VICTORY or reward == null or reward.experience <= 0 or reward.cash <= 0:
		return "Boss 敌队 %d 没有产生真实胜利奖励" % team_id
	return ""


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while vm.is_busy() and not vm.waiting_for_battle and guard < 40000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		elif vm.waiting_for_confirmation:
			vm.complete_confirmation(true)
		elif vm.waiting_for_shop:
			vm.complete_shop()
		elif vm.waiting_for_key:
			vm.complete_key_wait()
		elif vm.waiting_for_screen_fade:
			vm.complete_screen_fade()
		elif vm.waiting_for_rng:
			vm.complete_rng_animation()
		else:
			vm.tick_frame()
		guard += 1


func _message_range(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result
