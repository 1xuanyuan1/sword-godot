# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式 MapExplorer + TileMap 世界复现床前边界站位，并从六神丹物品脚本自动续跑赵灵儿苏醒剧情。
## 带窗口运行时截图只写入被 Git 忽略的 generated/pal/visual_tests/。
extends SceneTree

const OUTPUT_DIR := "res://generated/pal/visual_tests"

var _messages: Array[int] = []
var _unsupported: Array[String] = []
var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not PalDebugCheckpoint.request("baihe_medicine_use"):
		_fail("六神丹人工检查点不可用")
		return
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	var vm: ScriptVM = explorer._script_vm
	var linger: PalEventObject = explorer._database.event_objects[904]
	vm.dialog_message.connect(func(index: int) -> void: _messages.append(index))
	vm.unsupported_instruction.connect(
		func(index: int, operation: int) -> void:
			_unsupported.append("0x%04X@%d" % [operation, index])
	)
	if explorer._tile_world == null or explorer._tile_world.loaded_map_number != explorer._database.scenes[52].map_number:
		_fail("六神丹回归没有载入正式 PalTileMapWorld")
	elif explorer._session.party_roles != PackedInt32Array([0, 2]) or explorer._session.item_count(286) != 1:
		_fail("六神丹检查点没有恢复床前队伍与道具：party=%s medicine=%d" % [explorer._session.party_roles, explorer._session.item_count(286)])
	elif not vm._is_party_facing_event(linger.object_id, 1):
		_fail("床前边界站位没有通过 0081 面向偏移判定")
	elif explorer._is_touch_event_in_range(linger, explorer._session.party_world_position()):
		_fail("床前边界站位没有复现普通接触距离严格失败")
	if not _failure.is_empty():
		_cleanup(explorer)
		quit(1)
		return

	# 走正式物品使用入口，让 MapExplorer 负责消耗六神丹并衔接 0081 确认的对象。
	explorer._on_item_use_requested(286)
	if not vm.touch_trigger_armed or vm.touch_trigger_event_id != linger.object_id or linger.trigger_script != 14864:
		_fail("六神丹没有记录赵灵儿目标：armed=%s event=%d trigger=%d" % [vm.touch_trigger_armed, vm.touch_trigger_event_id, linger.trigger_script])
	elif explorer._session.item_count(286) != 0:
		_fail("六神丹物品脚本完成后没有恰好消耗一颗：%d" % explorer._session.item_count(286))
	await process_frame
	if _failure.is_empty() and not vm.is_busy():
		_fail("六神丹命中后没有自动进入赵灵儿苏醒入口 14864")

	var deadline := Time.get_ticks_msec() + 45000
	while _failure.is_empty() and Time.get_ticks_msec() < deadline:
		var stable: bool = (
			not vm.is_busy()
			and not explorer._touch_scan_active
			and not explorer._screen_fade_active
			and explorer._pending_scene_index < 0
			and explorer._session.party_roles == PackedInt32Array([0, 1, 2])
		)
		if stable:
			break
		if vm.waiting_for_dialog:
			explorer._dialog_box.reveal_all()
			vm.advance_dialog()
		elif vm.waiting_for_confirmation:
			vm.complete_confirmation(true)
		elif vm.waiting_for_shop:
			vm.complete_shop()
		elif vm.waiting_for_key:
			vm.complete_key_wait()
		await process_frame

	if _failure.is_empty() and (vm.is_busy() or explorer._touch_scan_active or explorer._screen_fade_active):
		_fail("赵灵儿苏醒剧情没有在保护时间内结束：cursor=%d busy=%s touch=%s fade=%s" % [vm._cursor, vm.is_busy(), explorer._touch_scan_active, explorer._screen_fade_active])
	elif _failure.is_empty() and not _unsupported.is_empty():
		_fail("赵灵儿苏醒剧情出现未支持指令：%s" % ", ".join(_unsupported))
	elif _failure.is_empty() and not _messages_are_complete():
		_fail("赵灵儿苏醒与韩医仙后续提示消息范围不完整：%s" % [_messages])
	elif _failure.is_empty() and explorer._session.party_roles != PackedInt32Array([0, 1, 2]):
		_fail("赵灵儿苏醒后没有恢复三人队：%s" % explorer._session.party_roles)
	elif _failure.is_empty() and (explorer._session.scene_index != 52 or explorer._session.music_number != 55):
		_fail("赵灵儿苏醒后场景或音乐不稳定：scene=%d music=%d" % [explorer._session.scene_index, explorer._session.music_number])
	elif _failure.is_empty() and (linger.state != 0 or explorer._database.event_objects[905].state != 2 or explorer._database.event_objects[905].trigger_script != 15050):
		_fail("赵灵儿或韩医仙最终状态不正确：linger=%d doctor=%d/%d" % [linger.state, explorer._database.event_objects[905].state, explorer._database.event_objects[905].trigger_script])
	elif _failure.is_empty():
		await _save_recovered_frame(explorer)

	if _failure.is_empty():
		print("PASS: 六神丹从床前边界站位直接续跑 EventObject 905，赵灵儿苏醒并恢复三人队")
	_cleanup(explorer)
	await process_frame
	quit(0 if _failure.is_empty() else 1)


func _save_recovered_frame(explorer) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = explorer.get_viewport().get_texture().get_image()
	if image == null:
		_fail("无法读取赵灵儿苏醒后的正式 TileMap 画面")
		return
	image.resize(320, 200, Image.INTERPOLATE_NEAREST)
	var nonblack_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r > 0.04 or color.g > 0.04 or color.b > 0.04:
				nonblack_pixels += 1
	if nonblack_pixels < 5000:
		_fail("赵灵儿苏醒后的画面仍接近全黑：%d 个非黑像素" % nonblack_pixels)
		return
	var output_directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_directory)
	if image.save_png(output_directory.path_join("baihe_linger_recovered.png")) != OK:
		_fail("无法保存赵灵儿苏醒后的 TileMap 截图")


func _message_range(first: int, last: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(first, last + 1):
		result.append(index)
	return result


func _messages_are_complete() -> bool:
	var recovery := _message_range(4254, 4345)
	if _messages.size() < recovery.size() + 3:
		return false
	for index in range(recovery.size()):
		if _messages[index] != recovery[index]:
			return false
	# 苏醒脚本结束后，正式接触链会在同一游戏更新周期命中床边韩医仙，
	# 自动补上下一步主线提示；附近自动脚本可能在玩家移动前再扫描一次，
	# 但每轮都必须是完整的 4350–4352，不能截断或混入别的入口。
	var follow_up_size := _messages.size() - recovery.size()
	if follow_up_size % 3 != 0:
		return false
	for index in range(follow_up_size):
		if _messages[recovery.size() + index] != 4350 + index % 3:
			return false
	return true


func _cleanup(explorer) -> void:
	if explorer._script_vm != null:
		explorer._script_vm.stop()
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
		explorer._audio_player._music_player.stream = null
		for player in explorer._audio_player._sound_players:
			player.stream = null
	explorer.free()


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
		printerr("FAIL: %s" % message)
