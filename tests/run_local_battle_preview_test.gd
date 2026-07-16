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
	var reward_image := viewport.get_texture().get_image()
	var reward_path := output_directory.path_join("battle_reward.png")
	if reward_image == null or reward_image.save_png(reward_path) != OK:
		_fail("无法写入原版布局战斗奖励截图")
		return
	if preview._battle_ui.advance_reward_page():
		_fail("首战奖励总览后没有进入李逍遥升级页")
		return
	await process_frame
	var level_image := viewport.get_texture().get_image()
	var level_path := output_directory.path_join("battle_level_up.png")
	if level_image == null or level_image.save_png(level_path) != OK:
		_fail("无法写入原版布局升级数值截图")
		return
	print("PASS: 经典指令、敌人体力、其他／物品菜单、物品／逃跑动画、玩家/敌人仙术、普攻及战后奖励/升级均可绘制：%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s、%s" % [output_path, enemy_target_path, misc_path, item_action_path, item_list_path, item_use_path, throw_path, flee_path, magic_path, healing_path, offensive_path, attack_path, enemy_magic_path, reward_path, level_path])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
