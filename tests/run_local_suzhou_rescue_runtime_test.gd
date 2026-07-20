# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用正式 MapExplorer + TileMap 世界验证苏州城外“解救月如”接触链。
## 重点覆盖：战后脚本启用较早的 EventObject 413 时，接触扫描必须重新从场景头部检查。
extends SceneTree

var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var explorer = load("res://scenes/map_explorer.tscn").instantiate()
	root.add_child(explorer)
	await process_frame
	await process_frame
	if explorer._script_vm == null or explorer._database == null:
		_fail("MapExplorer 没有初始化正式 ScriptVM/内容数据库")
		return
	explorer._script_vm.stop()

	var database: PalContentDatabase = explorer._database
	var unsupported: Array[String] = []
	explorer._script_vm.unsupported_instruction.connect(
		func(index: int, operation: int) -> void:
			unsupported.append("0x%04X@%d" % [operation, index])
	)
	explorer._load_scene(21, false)
	explorer._session.party_roles = PackedInt32Array([0])
	explorer._session.battlefield_number = 3
	explorer._session.set_party_world_position(Vector2i(976, 1016))

	# event 420 是第二次呼救后的“解救”入口；10357 胜利后把更早的
	# event 413 设为可见，413 的 10390 才是刺伤、救治和习得复活术的动画。
	var tied_yueru: PalEventObject = database.event_objects[419]
	var stabbing_yueru: PalEventObject = database.event_objects[412]
	tied_yueru.state = 1
	tied_yueru.trigger_script = 10357
	tied_yueru.trigger_mode = PalEventObject.TRIGGER_TOUCH_FARTHER
	stabbing_yueru.state = 0
	stabbing_yueru.trigger_script = 10390
	stabbing_yueru.trigger_mode = PalEventObject.TRIGGER_TOUCH_FARTHER
	explorer._refresh_world()

	# 保留“接触扫描正在处理 event 420”的真实状态，再模拟其脚本启动。
	explorer._touch_scan_active = true
	explorer._touch_scan_next_index = 419
	explorer._run_event_trigger(tied_yueru)
	if not await _drive_until(explorer, func() -> bool: return explorer._script_vm.waiting_for_battle):
		_fail("解救入口没有推进到敌队 22 战斗等待")
		return
	if not explorer._battle_view.visible:
		_fail("解救入口请求战斗后覆盖层没有显示")
		return

	# 战斗结果页由玩家确认后才会通知 MapExplorer；这里直接模拟确认后的胜利回调。
	explorer._battle_view.hide()
	explorer._script_vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	if not await _drive_until(explorer, func() -> bool: return not explorer._script_vm.is_busy() and not explorer._touch_scan_active):
		_fail("战后接触链没有在保护帧数内结束")
		return

	if not unsupported.is_empty():
		_fail("刺伤/救治正式剧情遇到未支持指令：%s" % ", ".join(unsupported))
	elif stabbing_yueru.state != 0:
		_fail("战后没有运行较早的 EventObject 413 刺伤脚本：state=%d" % stabbing_yueru.state)
	elif explorer._session.party_roles != PackedInt32Array([0, 1]):
		_fail("刺伤救治后队伍没有恢复为李逍遥/赵灵儿：%s" % explorer._session.party_roles)
	elif not explorer._session.has_magic(1, 301):
		_fail("赵灵儿没有习得可复活仙术 301")
	elif explorer._session.role_hp[0] != explorer._session.role_max_hp[0] or explorer._session.role_hp[1] != explorer._session.role_max_hp[1]:
		_fail("救治后双人 HP 没有恢复满值")
	else:
		print("PASS: TileMap 正式 MapExplorer 完成解救月如战后接触链，刺伤动画与赵灵儿复活术均已推进")

	explorer._script_vm.stop()
	if explorer._audio_player != null:
		explorer._audio_player.stop_all()
		# Release loaded WAV references before freeing the temporary MapExplorer;
		# otherwise headless Godot reports orphan AudioStream resources at exit.
		explorer._audio_player._music_player.stream = null
		for player in explorer._audio_player._sound_players:
			player.stream = null
	explorer.free()
	await process_frame
	quit(0 if _failure.is_empty() else 1)


func _drive_until(explorer, predicate: Callable) -> bool:
	for _guard in range(4000):
		if predicate.call():
			return true
		if explorer._script_vm.waiting_for_dialog:
			explorer._script_vm.advance_dialog()
		elif explorer._script_vm.waiting_for_screen_fade:
			explorer._script_vm.complete_screen_fade()
		elif explorer._script_vm.waiting_for_frames:
			explorer._script_vm.tick_frame()
		else:
			await process_frame
	return predicate.call()


func _fail(message: String) -> void:
	_failure = message
	printerr("FAIL: %s" % message)
	quit(1)
