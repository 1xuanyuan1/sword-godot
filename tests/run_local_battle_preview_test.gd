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
	print("PASS: 经典指令、玩家/敌人仙术、普攻及战后奖励/升级均可绘制：%s、%s、%s、%s、%s、%s、%s、%s" % [output_path, magic_path, healing_path, offensive_path, attack_path, enemy_magic_path, reward_path, level_path])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
