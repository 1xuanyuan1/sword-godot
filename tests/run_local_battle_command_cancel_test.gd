# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实战斗 UI 和 OpenGL 像素验证 ESC 从后续队员退回上一名队员。
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
	if not preview.load_battle(18, 21, PackedInt32Array([0, 1])):
		_fail("无法启动李逍遥与赵灵儿的真实双人战斗")
		return
	preview.set_process(false)
	if preview._input_mode != PalBattlePreview.InputMode.COMMAND or preview._controller.pending_party_index() != 0:
		_fail("双人战斗没有从李逍遥的主指令开始")
		return
	preview._submit_attack()
	if preview._input_mode != PalBattlePreview.InputMode.COMMAND or preview._controller.pending_party_index() != 1:
		_fail("李逍遥提交普攻后没有轮到赵灵儿")
		return
	await process_frame
	await process_frame
	var second_player_image := viewport.get_texture().get_image()
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	preview._unhandled_key_input(cancel_event)
	if not is_instance_valid(preview) or preview._input_mode != PalBattlePreview.InputMode.COMMAND or preview._controller.pending_party_index() != 0 or preview._controller.players[0].action_type != -1:
		_fail("赵灵儿主指令阶段按 ESC 没有撤销李逍遥的指令并退回李逍遥")
		return
	await process_frame
	await process_frame
	var returned_image := viewport.get_texture().get_image()
	if _pixel_difference(second_player_image, returned_image) <= 0:
		_fail("ESC 退回李逍遥后，真实战斗 UI 的当前队员指示没有变化")
		return
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("battle_command_cancel_previous.png")
	if returned_image == null or returned_image.get_size() != Vector2i(320, 200) or returned_image.save_png(output_path) != OK:
		_fail("无法写入 ESC 退回上一名队员的战斗截图")
		return
	print("PASS: 赵灵儿主指令阶段按 ESC 已撤销李逍遥指令并退回李逍遥：%s" % output_path)
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
