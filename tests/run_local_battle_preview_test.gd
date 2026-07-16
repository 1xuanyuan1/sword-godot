# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 用真实 Godot 渲染器截取敌队 18、战场 21 的经典指令和仙术列表，验证官方 UI 与双方 Sprite。
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
	preview._cancel_or_leave()
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
	print("PASS: 敌队 18 / 战场 21 的原版状态框、四向指令、真实仙术列表和普攻位移动画均可绘制：%s、%s、%s" % [output_path, magic_path, attack_path])
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
