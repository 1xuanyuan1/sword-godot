# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实敌队、Sprite 和 OpenGL 像素验证 R 重复指令在队列执行期连续换目标。
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
	preview.set_process(false)
	if not preview.load_battle(5, 21, PackedInt32Array([0, 1])) or preview._controller.enemies.size() != 3:
		_fail("无法用真实三敌人敌队 5 启动 R 换目标回归")
		return
	preview.set_process(false)
	for role_index in preview._session.party_roles:
		preview._session.role_dexterity[role_index] = 999
	for player in preview._controller.players:
		player.previous_action_type = PalBattleController.ActionType.ATTACK
		player.previous_target_index = 0
	preview._controller.enemies[0].hp = 0
	preview._controller.enemies[1].hp = 1
	preview._enemy_nodes[0].hide()
	var repeat_event := InputEventKey.new()
	repeat_event.keycode = KEY_R
	repeat_event.pressed = true
	preview._unhandled_key_input(repeat_event)
	if preview._input_mode != PalBattlePreview.InputMode.WAITING or not preview._controller.players.all(func(player: PalBattleController.PlayerState) -> bool: return player.target_index == 1):
		_fail("按 R 后没有先从已倒下的旧目标切到下一个存活敌人")
		return
	var first_result := preview._controller.execute_next_action()
	if first_result == null or first_result.hits.is_empty() or first_result.target_index != 1 or first_result.hits[0].target_index != 1 or not first_result.hits[0].defeated:
		_fail("重复队列中第一名队员没有击倒第一个替换目标")
		return
	preview._battle_ui._floating_numbers.clear()
	preview._play_player_attack(first_result)
	if not await _wait_for_hit_number(preview) or not await _wait_for_player_home(preview, first_result.actor_index):
		_fail("第一次重复攻击没有完整播放受击与归位动画")
		return
	await create_timer(0.12).timeout
	var second_result := preview._controller.execute_next_action()
	if second_result == null or second_result.hits.is_empty() or second_result.target_index != 2 or second_result.hits[0].target_index != 2:
		_fail("第一个替换目标倒下后，后续队员没有在出手前再次切到存活敌人")
		return
	preview._battle_ui._floating_numbers.clear()
	preview._play_player_attack(second_result)
	if not await _wait_for_hit_number(preview):
		_fail("二次换目标后没有在新敌人上绘制受击数字")
		return
	var actor_index := second_result.actor_index
	var actor_home := preview._top_left_for_frame(preview._player_sprites[actor_index], 0, preview._player_foot_positions[actor_index])
	if preview._player_nodes[actor_index].position.distance_to(actor_home) <= 1.0 or preview._enemy_nodes[0].visible or preview._enemy_nodes[1].visible or not preview._enemy_nodes[2].visible:
		_fail("R 二次换目标时的真实人物与敌人可见状态不正确")
		return
	var image := viewport.get_texture().get_image()
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("battle_repeat_retarget.png")
	if image == null or image.get_size() != Vector2i(320, 200) or image.save_png(output_path) != OK:
		_fail("无法写入 R 重复指令连续换目标截图")
		return
	if not await _wait_for_player_home(preview, actor_index):
		_fail("R 换目标动画结束后没有回到原始战位")
		return
	print("PASS: R 重复指令跳过旧死敌人，并在队列前一人击杀替换目标后再次切换：%s" % output_path)
	quit(0)


func _wait_for_hit_number(preview: PalBattlePreview) -> bool:
	for _step in range(120):
		await create_timer(0.01).timeout
		if not preview._battle_ui._floating_numbers.is_empty():
			return true
	return false


func _wait_for_player_home(preview: PalBattlePreview, actor_index: int) -> bool:
	var expected := preview._top_left_for_frame(preview._player_sprites[actor_index], 0, preview._player_foot_positions[actor_index])
	for _step in range(120):
		await create_timer(0.02).timeout
		if preview._player_nodes[actor_index].position.distance_to(expected) <= 0.1:
			return true
	return false


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
