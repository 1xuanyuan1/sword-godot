# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 用真实 Godot 渲染器截取敌队 18、战场 21 的静态战斗样板，验证背景和四个战斗 Sprite 已进入画面。
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
	print("PASS: 敌队 18 / 战场 21 静态战斗样板为 320×200，双方四个 Sprite 均已绘制：%s" % output_path)
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
