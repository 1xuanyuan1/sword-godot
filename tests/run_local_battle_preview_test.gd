# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 用真实 Godot 渲染器截取敌我仙术、经典指令、普攻和战后结算，验证官方 UI 与双方 Sprite。
## 截图只写入被 Git 忽略的 `generated/pal/visual_tests/`。
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := PalBattlePreview.new()
	preview.size = Vector2(320, 200)
	viewport.add_child(preview)
	await process_frame
	await process_frame
	# 本测试逐项手动执行行动并截取确定帧，关闭样板自己的自动行动调度，避免异步动画互相覆盖。
	preview.set_process(false)
	# SubViewport 不会驱动真实音频设备；这里验证样板已选择并装载循环曲目，
	# 实际 AudioStreamPlayer.playing 状态由 run_local_audio_test.gd 在 SceneTree 根节点验证。
	var battle_music_stream := preview._audio_player._music_player.stream as AudioStreamWAV if preview._audio_player != null else null
	if preview._audio_player == null or preview._audio_player.current_music_number != PalBattlePreview.DEFAULT_LAB_BATTLE_MUSIC or battle_music_stream == null or battle_music_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		var current_music := preview._audio_player.current_music_number if preview._audio_player != null else -999
		_fail("独立战斗样板没有装载循环战斗 BGM 37：编号 %d" % current_music)
		return
	var repeat_event := InputEventKey.new()
	repeat_event.keycode = KEY_R
	repeat_event.pressed = true
	preview._unhandled_key_input(repeat_event)
	if preview._input_mode != PalBattlePreview.InputMode.WAITING or not preview._controller.players.all(func(player: PalBattleController.PlayerState) -> bool: return player.action_type == PalBattleController.ActionType.ATTACK):
		_fail("战斗主指令阶段按 R 没有让全队重复首回合默认攻击")
		return
	# 恢复首战初始状态，避免快捷键检查影响后续逐项动画回归。
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview.set_process(false)
	if preview._fighter_root.get_child_count() != 4:
		_fail("首战应绘制两个敌人与两名队员，实际为 %d" % preview._fighter_root.get_child_count())
		return
	if not preview._battle_ui.has_classic_resources():
		_fail("战斗状态框、四向图标或点阵字资源未成功加载")
		return
	if preview._battle_ui.z_index <= preview._player_nodes[0].z_index:
		_fail("经典战斗 UI 没有位于按 Y 排序的人物之上")
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(320, 200):
		_fail("当前渲染器无法读回 320×200 战斗画面；请去掉 --headless")
		return
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("battle_team_018_field_021.png")
	if image.save_png(output_path) != OK:
		_fail("无法写入战斗样板截图")
		return
	preview._handle_direction(Vector2i(1, 0))
	if preview._selected_action != 2 or not preview._controller.can_pending_player_use_cooperative_magic():
		_fail("两名健康队员没有启用右侧经典合击图标")
		return
	preview._confirm_current_selection()
	if preview._input_mode != PalBattlePreview.InputMode.ENEMY_TARGET:
		_fail("李逍遥的合体气功没有进入敌人目标选择")
		return
	var coop_hp_before := PackedInt32Array([preview._session.role_hp[0], preview._session.role_hp[1]])
	preview._confirm_current_selection()
	var cooperative_result := preview._controller.execute_next_action()
	if cooperative_result == null or cooperative_result.action_type != PalBattleController.ActionType.COOPERATIVE_MAGIC or cooperative_result.magic_object_id != 386 or cooperative_result.hits.is_empty() or cooperative_result.hits[0].damage <= 0:
		_fail("真实合体气功没有生成合击伤害结果")
		return
	if preview._session.role_hp[0] != coop_hp_before[0] - 9 or preview._session.role_hp[1] != coop_hp_before[1] - 9:
		_fail("合体气功没有让两名贡献者各消耗 9 HP")
		return
	preview._play_cooperative_magic(cooperative_result)
	var cooperative_image: Image
	for _step in range(160):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() > 0:
			cooperative_image = viewport.get_texture().get_image()
			break
	var cooperative_path := output_directory.path_join("battle_cooperative_magic.png")
	if cooperative_image == null or cooperative_image.save_png(cooperative_path) != OK:
		_fail("合体气功播放期间没有绘制多人施法与 FIRE 特效")
		return
	for _step in range(180):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() == 0:
			break
	await create_timer(0.8).timeout
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview.set_process(false)
	preview._begin_enemy_target_selection()
	await process_frame
	var enemy_vitals := preview._battle_ui.selected_enemy_vitals()
	if preview._input_mode != PalBattlePreview.InputMode.ENEMY_TARGET or enemy_vitals.is_empty():
		_fail("选择敌人时没有进入闪烁目标阶段或显示敌人体力")
		return
	var selected_enemy := preview._controller.enemies[preview._selected_enemy_index]
	if int(enemy_vitals.get("hp", -1)) != selected_enemy.hp or int(enemy_vitals.get("max_hp", -1)) != selected_enemy.max_hp:
		_fail("左上角敌人体力没有读取控制器中的真实当前/最大值")
		return
	var enemy_target_image := viewport.get_texture().get_image()
	var enemy_target_path := output_directory.path_join("battle_enemy_target_vitals.png")
	if enemy_target_image == null or enemy_target_image.save_png(enemy_target_path) != OK:
		_fail("无法写入敌人选择与体力条截图")
		return
	preview._cancel_or_leave()
	if not preview._battle_ui.selected_enemy_vitals().is_empty():
		_fail("退出敌人选择后左上角体力条没有隐藏")
		return
	preview._set_action_selection(3)
	preview._confirm_current_selection()
	await process_frame
	if preview._input_mode != PalBattlePreview.InputMode.MISC_MENU or preview._battle_ui.selected_misc_index != 1:
		_fail("选择其他图标后没有打开经典自动／物品／防御／逃跑／状态菜单")
		return
	var misc_image := viewport.get_texture().get_image()
	var misc_path := output_directory.path_join("battle_misc_menu.png")
	if misc_image == null or misc_image.save_png(misc_path) != OK:
		_fail("无法写入战斗其他菜单截图")
		return
	preview._confirm_current_selection()
	await process_frame
	if preview._input_mode != PalBattlePreview.InputMode.ITEM_ACTION:
		_fail("其他菜单选择物品后没有打开使用／投掷子菜单")
		return
	var item_action_image := viewport.get_texture().get_image()
	var item_action_path := output_directory.path_join("battle_item_action_menu.png")
	if item_action_image == null or item_action_image.save_png(item_action_path) != OK:
		_fail("无法写入战斗物品子菜单截图")
		return
	preview._confirm_current_selection()
	await process_frame
	if preview._input_mode != PalBattlePreview.InputMode.ITEM_LIST or preview._battle_ui.selected_item_object() != 99 or not preview._battle_ui.selected_item_enabled():
		_fail("战斗使用物品页没有显示样板背包中的止血草或错误置灰")
		return
	var item_list_image := viewport.get_texture().get_image()
	var item_list_path := output_directory.path_join("battle_item_list.png")
	if item_list_image == null or item_list_image.save_png(item_list_path) != OK:
		_fail("无法写入战斗物品列表截图")
		return
	preview._session.role_hp[1] = 20
	preview._session.role_dexterity[0] = 999
	preview._confirm_current_selection()
	if preview._input_mode != PalBattlePreview.InputMode.PLAYER_TARGET:
		_fail("止血草没有进入我方角色目标选择")
		return
	preview._select_player(1)
	preview._confirm_current_selection()
	preview._submit_defend()
	var item_result: PalBattleController.ActionResult
	for _step in range(8):
		var candidate := preview._controller.execute_next_action()
		if candidate == null:
			break
		if candidate.action_type == PalBattleController.ActionType.USE_ITEM:
			item_result = candidate
			break
	if item_result == null or item_result.action_type != PalBattleController.ActionType.USE_ITEM or preview._session.role_hp[1] != 70:
		_fail("止血草没有按真实脚本恢复第二名队员 50 HP")
		return
	preview._play_player_use_item(item_result)
	await create_timer(0.42).timeout
	var item_use_image := viewport.get_texture().get_image()
	var item_use_path := output_directory.path_join("battle_item_use.png")
	if item_use_image == null or item_use_image.save_png(item_use_path) != OK:
		_fail("无法写入战斗使用物品动画截图")
		return
	await create_timer(0.9).timeout
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview._session.role_dexterity[0] = 999
	if not preview._controller.submit_throw_item(153, 0):
		_fail("梅花镖没有进入真实投掷行动")
		return
	preview._submit_defend()
	var throw_result := preview._controller.execute_next_action()
	if throw_result == null or throw_result.action_type != PalBattleController.ActionType.THROW_ITEM or throw_result.hits.is_empty() or throw_result.hits[0].damage <= 0:
		_fail("梅花镖没有生成真实伤害结果")
		return
	preview._play_player_throw_item(throw_result)
	var throw_image: Image
	for _step in range(120):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() > 0:
			throw_image = viewport.get_texture().get_image()
			break
	var throw_path := output_directory.path_join("battle_item_throw.png")
	if throw_image == null or throw_image.save_png(throw_path) != OK:
		_fail("梅花镖投掷期间没有绘制模拟仙术特效")
		return
	for _step in range(120):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() == 0:
			break
	await create_timer(0.6).timeout
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview._session.role_dexterity[0] = 999
	preview._session.role_flee_rate[0] = 999
	preview._set_action_selection(3)
	preview._confirm_current_selection()
	preview._battle_ui.move_misc_selection(2)
	preview._confirm_current_selection()
	var flee_result := preview._controller.execute_next_action()
	if flee_result == null or flee_result.action_type != PalBattleController.ActionType.FLEE or not flee_result.flee_succeeded or preview._controller.battle_result != PalBattleController.BattleResult.FLED:
		_fail("其他菜单没有按真实公式提交成功逃跑")
		return
	preview._play_player_flee(flee_result)
	await create_timer(0.32).timeout
	var flee_image := viewport.get_texture().get_image()
	var flee_path := output_directory.path_join("battle_flee.png")
	if flee_image == null or flee_image.save_png(flee_path) != OK:
		_fail("无法写入全队逃跑动画截图")
		return
	await create_timer(0.5).timeout
	if preview._player_nodes.any(func(node: Sprite2D) -> bool: return node.visible):
		_fail("逃跑动画结束后仍有队员留在战场")
		return
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview._set_action_selection(1)
	preview._confirm_current_selection()
	await process_frame
	var magic_image := viewport.get_texture().get_image()
	var magic_path := output_directory.path_join("battle_magic_menu.png")
	if preview._input_mode != PalBattlePreview.InputMode.MAGIC_LIST or preview._battle_ui.selected_magic_object() <= 0:
		_fail("选择仙术图标后没有打开角色的真实仙术列表")
		return
	if magic_image == null or magic_image.save_png(magic_path) != OK:
		_fail("无法写入仙术列表截图")
		return
	preview._confirm_current_selection()
	await process_frame
	if preview._input_mode != PalBattlePreview.InputMode.PLAYER_TARGET:
		_fail("气疗术没有进入我方角色目标选择")
		return
	preview._select_player(1)
	preview._session.role_hp[1] = 28
	var hp_before := preview._session.role_hp[1]
	var mp_before := preview._session.role_mp[0]
	preview._confirm_current_selection()
	preview._submit_defend()
	var magic_result: PalBattleController.ActionResult
	for _step in range(8):
		var candidate := preview._controller.execute_next_action()
		if candidate == null:
			break
		if candidate.action_type == PalBattleController.ActionType.MAGIC:
			magic_result = candidate
			break
	if magic_result == null or preview._session.role_hp[1] != mini(preview._session.role_max_hp[1], hp_before + 75) or preview._session.role_mp[0] != mp_before - 6:
		_fail("气疗术没有按真实脚本恢复 75 HP 并消耗 6 MP")
		return
	preview._play_player_magic(magic_result)
	await create_timer(0.62).timeout
	if preview._magic_root.get_child_count() == 0:
		_fail("气疗术播放期间没有绘制 FIRE.MKF 特效")
		return
	var healing_image := viewport.get_texture().get_image()
	var healing_path := output_directory.path_join("battle_healing_magic.png")
	if healing_image == null or healing_image.save_png(healing_path) != OK:
		_fail("无法写入气疗术动画截图")
		return
	await create_timer(1.5).timeout
	if preview._magic_root.get_child_count() != 0:
		_fail("气疗术结束后没有清除临时特效节点")
		return
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview._submit_defend()
	preview._set_action_selection(1)
	preview._confirm_current_selection()
	preview._battle_ui.selected_magic_index = 5 # 排序后的“风咒”。
	preview._confirm_current_selection()
	if preview._input_mode != PalBattlePreview.InputMode.ENEMY_TARGET:
		_fail("风咒没有进入敌方目标选择")
		return
	preview._confirm_current_selection()
	var offensive_result: PalBattleController.ActionResult
	for _step in range(8):
		var candidate := preview._controller.execute_next_action()
		if candidate == null:
			break
		if candidate.action_type == PalBattleController.ActionType.MAGIC:
			offensive_result = candidate
			break
	if offensive_result == null or offensive_result.hits.is_empty() or offensive_result.hits[0].damage <= 0 or preview._session.role_mp[1] != 235:
		_fail("风咒没有扣除 5 MP 并按官方公式伤害敌人")
		return
	preview._play_player_magic(offensive_result)
	await create_timer(0.48).timeout
	if preview._magic_root.get_child_count() == 0:
		_fail("风咒播放期间没有绘制 FIRE.MKF 特效")
		return
	var offensive_image := viewport.get_texture().get_image()
	var offensive_path := output_directory.path_join("battle_offensive_magic.png")
	if offensive_image == null or offensive_image.save_png(offensive_path) != OK:
		_fail("无法写入风咒动画截图")
		return
	await create_timer(1.2).timeout
	var attack_result := PalBattleController.ActionResult.new()
	attack_result.actor_index = 0
	var hit := PalBattleController.Hit.new()
	hit.target_is_enemy = true
	hit.target_index = 0
	hit.damage = 12
	attack_result.hits.append(hit)
	preview._play_player_attack(attack_result)
	await create_timer(0.29).timeout
	var attack_image := viewport.get_texture().get_image()
	var attack_path := output_directory.path_join("battle_player_attack.png")
	if attack_image == null or attack_image.save_png(attack_path) != OK:
		_fail("无法写入玩家普攻动画截图")
		return
	await create_timer(0.65).timeout
	var expected_position := preview._top_left_for_frame(preview._player_sprites[0], 0, preview._player_foot_positions[0])
	if preview._player_nodes[0].position.distance_to(expected_position) > 0.1:
		_fail("玩家普攻动画结束后没有回到原始战位")
		return
	preview.load_battle(18, 21, PackedInt32Array([1]))
	preview.set_process(false)
	if preview._session.status_rounds_for(1, GameSession.STATUS_DUAL_ATTACK) <= 0:
		_fail("赵灵儿的仙女剑装备脚本没有提供持久双击状态")
		return
	preview._session.set_role_status(1, GameSession.STATUS_BRAVERY, 2)
	preview._session.role_dexterity[1] = 999
	if not preview._controller.submit_attack(0):
		_fail("赵灵儿双剑普攻没有进入行动队列")
		return
	var dual_result := preview._controller.execute_next_action()
	if dual_result == null or dual_result.actor_index != 0 or dual_result.hits.size() != 2 or dual_result.hits[0].attack_sequence != 0 or dual_result.hits[1].attack_sequence != 1:
		_fail("赵灵儿双剑没有生成两轮独立攻击结果")
		return
	preview._battle_ui._floating_numbers.clear()
	var sound_cursor_before := preview._audio_player._sound_cursor
	preview._play_player_attack(dual_result)
	var dual_image: Image
	var dual_number_frame_gap := 0
	for _step in range(140):
		await create_timer(0.01).timeout
		if preview._battle_ui._floating_numbers.size() >= 2:
			var first_started := int(preview._battle_ui._floating_numbers[0].get("started", 0))
			var second_started := int(preview._battle_ui._floating_numbers[1].get("started", 0))
			dual_number_frame_gap = int((second_started - first_started) / 40.0)
			dual_image = viewport.get_texture().get_image()
			break
	var dual_sound_count := posmod(preview._audio_player._sound_cursor - sound_cursor_before, PalAudioPlayer.SOUND_VOICE_COUNT)
	if dual_image == null or dual_number_frame_gap < 8:
		_fail("赵灵儿双剑两段伤害仍在同一时刻重叠：间隔 %d 帧" % dual_number_frame_gap)
		return
	if dual_sound_count != 4:
		_fail("赵灵儿双剑没有逐击播放角色声和武器声：实际调用 %d 次" % dual_sound_count)
		return
	var dual_path := output_directory.path_join("battle_player_dual_attack.png")
	if dual_image.save_png(dual_path) != OK:
		_fail("无法写入赵灵儿双剑二连击截图")
		return
	await create_timer(0.6).timeout
	expected_position = preview._top_left_for_frame(preview._player_sprites[0], 0, preview._player_foot_positions[0])
	if preview._player_nodes[0].position.distance_to(expected_position) > 0.1:
		_fail("赵灵儿双剑二连击结束后没有回到原始战位")
		return
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview.set_process(false)
	var cover_result := PalBattleController.ActionResult.new()
	cover_result.actor_is_enemy = true
	cover_result.actor_index = 0
	var cover_hit := PalBattleController.Hit.new()
	cover_hit.target_index = 1
	cover_hit.auto_defended = true
	cover_hit.covering_index = 0
	cover_result.hits.append(cover_hit)
	preview._play_enemy_attack(cover_result)
	var cover_image: Image
	for _step in range(80):
		await create_timer(0.03).timeout
		if preview._player_current_frames[0] == 3:
			cover_image = viewport.get_texture().get_image()
			break
	var cover_path := output_directory.path_join("battle_player_cover.png")
	if cover_image == null or cover_image.save_png(cover_path) != OK:
		_fail("保护角色没有上前为濒死队员格挡")
		return
	await create_timer(0.8).timeout

	preview.load_battle(17, 21, PackedInt32Array([0, 1]))
	var enemy_magic_actor := -1
	for enemy_index in range(preview._controller.enemies.size()):
		if preview._controller.enemies[enemy_index].definition.magic == 312:
			enemy_magic_actor = enemy_index
			break
	if enemy_magic_actor < 0:
		_fail("敌队 17 中找不到真实敌术 312")
		return
	var enemy_magic_result := PalBattleController.ActionResult.new()
	enemy_magic_result.actor_is_enemy = true
	enemy_magic_result.actor_index = enemy_magic_actor
	preview._controller._execute_enemy_magic(enemy_magic_actor, 0, enemy_magic_result)
	if enemy_magic_result.unsupported or enemy_magic_result.hits.is_empty() or enemy_magic_result.hits[0].damage <= 0:
		_fail("真实敌术 312 没有生成可播放的玩家伤害结果")
		return
	preview._play_enemy_magic(enemy_magic_result)
	var enemy_magic_image: Image
	for _step in range(120):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() > 0:
			enemy_magic_image = viewport.get_texture().get_image()
			break
	var enemy_magic_path := output_directory.path_join("battle_enemy_magic.png")
	if enemy_magic_image == null or enemy_magic_image.save_png(enemy_magic_path) != OK:
		_fail("敌人仙术播放期间没有绘制 FIRE.MKF 特效")
		return
	for _step in range(160):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() == 0:
			break
	await create_timer(0.6).timeout

	preview.load_battle(19, 21, PackedInt32Array([0, 1]))
	preview._battle_ui.clear_message()
	var fat_miao_index := -1
	for enemy_index in range(preview._controller.enemies.size()):
		if preview._controller.enemies[enemy_index].object_id == 485:
			fat_miao_index = enemy_index
			break
	if fat_miao_index < 0:
		_fail("敌队 19 中找不到胖苗 485")
		return
	var terrain_magic_result := PalBattleController.ActionResult.new()
	terrain_magic_result.actor_is_enemy = true
	terrain_magic_result.actor_index = fat_miao_index
	preview._controller._execute_enemy_magic(fat_miao_index, 0, terrain_magic_result)
	if terrain_magic_result.magic_object_id != 338 or terrain_magic_result.unsupported:
		_fail("胖苗没有生成可播放的弦月斩 338")
		return
	preview._play_enemy_magic(terrain_magic_result)
	for _step in range(240):
		await create_timer(0.03).timeout
		if preview._magic_root.get_child_count() == 0 and preview._persistent_effect_root.get_child_count() > 0:
			break
	if preview._persistent_effect_root.get_child_count() != 1:
		_fail("胖苗弦月斩结束后没有留下一个战场破坏层")
		return
	var terrain_image := viewport.get_texture().get_image()
	var terrain_path := output_directory.path_join("battle_enemy_persistent_terrain.png")
	if terrain_image == null or terrain_image.save_png(terrain_path) != OK:
		_fail("无法写入胖苗弦月斩持久地形截图")
		return
	preview._persistent_effect_root.hide()
	await process_frame
	await process_frame
	var terrain_without_effect := viewport.get_texture().get_image()
	preview._persistent_effect_root.show()
	if _pixel_difference(terrain_image, terrain_without_effect) <= 0:
		_fail("胖苗弦月斩的持久节点没有改变战场像素")
		return
	await create_timer(0.5).timeout
	if preview._persistent_effect_root.get_child_count() != 1:
		_fail("胖苗弦月斩的地形破坏没有保持到后续战斗阶段")
		return
	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	if preview._persistent_effect_root.get_child_count() != 0:
		_fail("开始下一场战斗时没有清除上一场的持久地形")
		return

	preview._session.learned_magics_by_role[0] = PackedInt32Array([315])
	preview._session.role_max_mp[0] = 999
	preview._session.role_mp[0] = 999
	preview._session.role_dexterity[0] = 999
	if not preview._controller.submit_magic(315, 0):
		_fail("真实风神 315 无法提交到战斗样板")
		return
	preview._submit_defend()
	var summon_result: PalBattleController.ActionResult
	for _step in range(8):
		var candidate := preview._controller.execute_next_action()
		if candidate == null:
			break
		if candidate.action_type == PalBattleController.ActionType.MAGIC:
			summon_result = candidate
			break
	if summon_result == null or summon_result.magic_object_id != 315 or summon_result.hits.size() != 2:
		_fail("真实风神 315 没有生成敌方全体伤害结果")
		return
	preview._play_player_magic(summon_result)
	var summon_image: Image
	for _step in range(300):
		await create_timer(0.03).timeout
		if preview._summon_node != null and is_instance_valid(preview._summon_node) and preview._summon_node.visible:
			summon_image = viewport.get_texture().get_image()
			break
	var summon_path := output_directory.path_join("battle_summon_wind_god.png")
	if summon_image == null or summon_image.save_png(summon_path) != OK:
		_fail("风神动画没有在 F.MKF 神将出现时写入截图")
		return
	for _step in range(360):
		await create_timer(0.03).timeout
		if preview._summon_node == null and preview._magic_root.get_child_count() == 0:
			break
	if preview._summon_node != null or preview._magic_root.get_child_count() != 0 or preview._player_nodes.any(func(node: Sprite2D) -> bool: return not node.visible):
		_fail("风神动画结束后没有清除神将/仙术节点或恢复队员")
		return

	preview.load_battle(18, 21, PackedInt32Array([1]))
	preview._session.learned_magics_by_role[1] = PackedInt32Array([295])
	preview._session.role_max_mp[1] = 999
	preview._session.role_mp[1] = 999
	preview._session.role_dexterity[1] = 999
	if not preview._controller.submit_magic(295, 99):
		_fail("真实梦蛇 295 无法提交到战斗样板")
		return
	preview._input_mode = PalBattlePreview.InputMode.WAITING
	preview._battle_ui.set_mode(PalBattleUI.Mode.WAITING)
	var trance_result := preview._controller.execute_next_action()
	if trance_result == null or trance_result.magic_object_id != 295 or trance_result.target_index != 0 or preview._session.battle_sprite_for(1, preview._database.player_roles.battle_sprite_for(1)) != 5:
		_fail("真实梦蛇 295 没有对施法者自己切换临时战斗 Sprite")
		return
	preview._play_player_magic(trance_result)
	var trance_image: Image
	var dream_snake_sprite := preview._database.load_player_battle_sprite(5)
	for _step in range(240):
		await create_timer(0.03).timeout
		if not preview._player_sprites.is_empty() and preview._player_sprites[0] == dream_snake_sprite and preview._player_nodes[0].visible:
			trance_image = viewport.get_texture().get_image()
			break
	var trance_path := output_directory.path_join("battle_trance_dream_snake.png")
	if trance_image == null or trance_image.save_png(trance_path) != OK:
		_fail("梦蛇动画没有在战斗 Sprite 5 出现时写入截图")
		return
	await create_timer(0.5).timeout

	preview.load_battle(18, 21, PackedInt32Array([0]))
	preview.set_process(false)
	preview._session.learned_magics_by_role[0] = PackedInt32Array([377])
	preview._session.role_max_mp[0] = 999
	preview._session.role_mp[0] = 999
	preview._session.role_dexterity[0] = 999
	if not preview._controller.submit_magic(377, 0):
		_fail("真实飞龙探云手 377 无法提交到战斗样板")
		return
	var steal_result := preview._controller.execute_next_action()
	var steal_event: PalBattleController.ScriptEvent
	if steal_result != null:
		for event in steal_result.script_events:
			if event.type == PalBattleController.ScriptEventType.STEAL:
				steal_event = event
				break
	if steal_result == null or steal_result.action_type != PalBattleController.ActionType.MAGIC or steal_result.magic_object_id != 377 or steal_event == null or steal_event.tertiary != 0:
		_fail("真实飞龙探云手没有生成指向目标敌人的专用偷窃动作事件")
		return
	preview._battle_ui.clear_message()
	preview._play_action_result(steal_result)
	var steal_image: Image
	var steal_resource_error_seen := false
	for _step in range(140):
		await create_timer(0.01).timeout
		steal_resource_error_seen = steal_resource_error_seen or preview._battle_ui._message.contains("特效资源缺失")
		if preview._player_current_frames[0] == 10:
			var steal_foot := preview._foot_for_node(preview._player_nodes[0], preview._player_sprites[0], 10)
			if steal_foot.x < preview._player_foot_positions[0].x - 30:
				steal_image = viewport.get_texture().get_image()
				break
	var steal_path := output_directory.path_join("battle_steal_flying_dragon.png")
	if steal_image == null or steal_image.save_png(steal_path) != OK:
		_fail("飞龙探云手没有在敌人附近绘制李逍遥第 10 帧专用偷窃动作")
		return
	for _step in range(140):
		await create_timer(0.02).timeout
		steal_resource_error_seen = steal_resource_error_seen or preview._battle_ui._message.contains("特效资源缺失")
		var resting_position := preview._top_left_for_frame(preview._player_sprites[0], 0, preview._player_foot_positions[0])
		if preview._player_current_frames[0] == 0 and preview._player_nodes[0].position.distance_to(resting_position) < 0.1:
			break
	if steal_resource_error_seen:
		_fail("飞龙探云手仍把 FFFF 哨兵误报为 FIRE.MKF 特效资源缺失")
		return

	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	var poison_result := PalBattleController.ActionResult.new()
	poison_result.action_type = PalBattleController.ActionType.POISON
	poison_result.poison_tick = true
	poison_result.summary = "毒性发作"
	var poison_hit := PalBattleController.Hit.new()
	poison_hit.target_index = 0
	poison_hit.damage = 7
	poison_result.hits.append(poison_hit)
	preview._session.increase_role_hp_mp(preview._controller.players[0].role_index, -7, 0)
	preview._play_poison_result(poison_result)
	await create_timer(0.08).timeout
	var poison_image := viewport.get_texture().get_image()
	var poison_path := output_directory.path_join("battle_poison_tick.png")
	if poison_image == null or poison_image.save_png(poison_path) != OK:
		_fail("无法写入回合末毒性结算截图")
		return
	await create_timer(0.5).timeout

	preview.load_battle(18, 21, PackedInt32Array([0, 1]))
	preview._session.role_hp[0] = 100
	for enemy_index in range(preview._controller.enemies.size()):
		var enemy := preview._controller.enemies[enemy_index]
		preview._controller._apply_enemy_damage(enemy_index, enemy.hp, false)
	preview._controller._check_battle_result()
	var reward := preview._controller.claim_victory_rewards()
	if reward == null or reward.experience != 52 or reward.cash != 96 or reward.level_ups.size() != 1:
		_fail("首战真实奖励应为 52 经验、96 文并让李逍遥升级一次")
		return
	preview._battle_ui.show_reward(reward)
	await process_frame
	# SubViewport 的纹理比 Control.queue_redraw() 晚一帧可读，避免保存到奖励页之前的旧画面。
	await process_frame
	var reward_image := viewport.get_texture().get_image()
	var reward_path := output_directory.path_join("battle_reward.png")
	if reward_image == null or reward_image.save_png(reward_path) != OK:
		_fail("无法写入原版布局战斗奖励截图")
		return
	if preview._battle_ui.advance_reward_page():
		_fail("首战奖励总览后没有进入李逍遥升级页")
		return
	await process_frame
	await process_frame
	var level_image := viewport.get_texture().get_image()
	var level_path := output_directory.path_join("battle_level_up.png")
	if level_image == null or level_image.save_png(level_path) != OK:
		_fail("无法写入原版布局升级数值截图")
		return

	preview.load_battle(22, 21, PackedInt32Array([0, 1]))
	preview.set_process(false)
	var battle_script_result := preview._controller.execute_next_action()
	if battle_script_result == null or battle_script_result.action_type != PalBattleController.ActionType.SCRIPT:
		_fail("敌队 22 没有在玩家选指令前返回真实回合开始脚本")
		return
	var dialog_start: PalBattleController.ScriptEvent
	var dialog_message: PalBattleController.ScriptEvent
	for script_event in battle_script_result.script_events:
		if dialog_start == null and script_event.type == PalBattleController.ScriptEventType.DIALOG_START:
			dialog_start = script_event
		elif dialog_message == null and script_event.type == PalBattleController.ScriptEventType.DIALOG_MESSAGE:
			dialog_message = script_event
	if dialog_start == null or dialog_message == null:
		_fail("敌队 22 的真实战斗脚本没有解析出对白位置和 M.MSG 消息")
		return
	var dialog_events: Array[PalBattleController.ScriptEvent] = [dialog_start, dialog_message]
	preview._play_script_events(dialog_events)
	await process_frame
	if not preview._script_dialog_waiting or not preview._script_dialog_box.is_typing():
		_fail("敌人回合脚本对白没有进入可跳过逐字显示的等待状态")
		return
	var dialog_confirm_event := InputEventKey.new()
	dialog_confirm_event.keycode = KEY_SPACE
	dialog_confirm_event.pressed = true
	preview._unhandled_key_input(dialog_confirm_event)
	if preview._script_dialog_box.is_typing() or preview._script_dialog_advance_requested:
		_fail("战斗对白第一次空格没有只显示完整当前句")
		return
	await process_frame
	var script_dialog_image := viewport.get_texture().get_image()
	var script_dialog_path := output_directory.path_join("battle_enemy_script_dialog.png")
	if script_dialog_image == null or script_dialog_image.save_png(script_dialog_path) != OK:
		_fail("无法写入敌人回合脚本对白截图")
		return
	preview._unhandled_key_input(dialog_confirm_event)
	for _step in range(10):
		await create_timer(0.05).timeout
		if not preview._script_dialog_waiting:
			break
	if preview._script_dialog_waiting or preview._script_dialog_box.visible:
		_fail("战斗对白完整显示后的第二次空格没有继续脚本")
		return
	print("PASS: 经典指令、敌人脚本对白、合击、保护格挡、敌人体力、其他／物品菜单、物品／逃跑动画、玩家/敌人仙术、飞龙探云手、胖苗持久地形、风神召唤、梦蛇变身、普攻/双剑二连击、毒性结算及战后奖励/升级均可绘制：%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s" % [output_path, script_dialog_path, cooperative_path, cover_path, enemy_target_path, misc_path, item_action_path, item_list_path, item_use_path, throw_path, flee_path, magic_path, healing_path, offensive_path, steal_path, terrain_path, summon_path, trance_path, attack_path, dual_path, enemy_magic_path, poison_path, reward_path, level_path])
	quit(0)


func _pixel_difference(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var difference := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				difference += 1
	return difference


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
