# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用真实战斗 UI 和 OpenGL 像素验证飞龙探云手的失败／已空反馈弹窗。
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
	if not preview.load_battle(18, 21, PackedInt32Array([0])):
		_fail("无法启动飞龙探云手反馈的真实战斗回归")
		return
	preview.set_process(false)
	var glyphs: Dictionary = preview._battle_ui._font_glyphs
	for character in PalBattlePreview.STEAL_FAILED_MESSAGE:
		if not glyphs.has(str(character)):
			_fail("偷取失败文案缺少经典点阵字形：%s" % character)
			return
	var failed_glyph: Array = glyphs.get("败", [])
	if not glyphs.has("敗") or failed_glyph != glyphs["敗"] or failed_glyph.size() < 4 or failed_glyph[2] != 16 or failed_glyph[3] != 15:
		_fail("简体“败”没有复用繁体“敗”的 16×15 经典点阵字形")
		return
	var enemy := preview._controller.enemies[0]
	enemy.steal_item = 99
	enemy.steal_item_count = 0
	var empty_result := PalBattleController.ActionResult.new()
	preview._controller._steal_from_enemy(0, 1, empty_result)
	var empty_event: PalBattleController.ScriptEvent = empty_result.script_events[0]
	if empty_event.outcome != PalBattleController.StealOutcome.NO_ITEMS:
		_fail("敌人偷窃池已空时没有生成 NO_ITEMS 结果")
		return
	preview._show_steal_message(empty_event)
	await process_frame
	await process_frame
	if preview._battle_ui._message != PalBattlePreview.STEAL_NO_ITEMS_MESSAGE:
		_fail("敌人已空时没有显示“敌人已无可偷物品”")
		return
	var empty_image := viewport.get_texture().get_image()
	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var empty_path := output_directory.path_join("battle_steal_no_items.png")
	if empty_image == null or empty_image.get_size() != Vector2i(320, 200) or empty_image.save_png(empty_path) != OK:
		_fail("无法写入敌人已无可偷物品截图")
		return
	preview._battle_ui.clear_message()
	var failed_event: PalBattleController.ScriptEvent
	for seed_value in range(1, 128):
		enemy.steal_item_count = 1
		preview._session.set_item_count(99, 0)
		preview._controller.set_random_seed(seed_value)
		var failed_result := PalBattleController.ActionResult.new()
		preview._controller._steal_from_enemy(0, 1, failed_result)
		var candidate: PalBattleController.ScriptEvent = failed_result.script_events[0]
		if candidate.outcome == PalBattleController.StealOutcome.FAILED:
			failed_event = candidate
			break
	if failed_event == null or enemy.steal_item_count != 1:
		_fail("无法用真实战斗随机源复现不消耗偷窃池的偷取失败")
		return
	preview._show_steal_message(failed_event)
	await process_frame
	await process_frame
	if preview._battle_ui._message != PalBattlePreview.STEAL_FAILED_MESSAGE:
		_fail("随机偷窃失败时没有显示“偷取失败”")
		return
	var failed_image := viewport.get_texture().get_image()
	var failed_path := output_directory.path_join("battle_steal_failed.png")
	if failed_image == null or failed_image.get_size() != Vector2i(320, 200) or failed_image.save_png(failed_path) != OK:
		_fail("无法写入偷取失败截图")
		return
	if _pixel_difference(empty_image, failed_image) <= 0:
		_fail("两种偷窃失败原因没有绘制不同的单行战斗弹窗")
		return
	print("PASS: 飞龙探云手随机失败／敌人已空均使用物品式单行战斗弹窗：%s、%s" % [failed_path, empty_path])
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
