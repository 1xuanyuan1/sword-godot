# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机数据验证全部剧情场景的 EventObject 自动脚本不会停在未支持指令。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var scene_count := mini(6, database.scenes.size()) if "--early-scenes" in OS.get_cmdline_user_args() else database.scenes.size()
	var unsupported: Array[String] = []
	var changed_events := 0
	for scene_index in range(scene_count):
		var session := GameSession.new()
		session.scene_index = scene_index
		var vm := ScriptVM.new()
		vm.configure(database, session)
		vm.set_scene_map(database.load_map(database.scenes[scene_index].map_number))
		vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("scene%d:0x%04X@%d" % [scene_index + 1, operation, index]))
		var before: Dictionary = {}
		for event in database.events_for_scene(scene_index):
			before[event.object_id] = [event.position, event.state, event.current_frame, event.auto_script, event.vanish_time]
		for frame in range(120):
			vm.tick_frame()
		for event in database.events_for_scene(scene_index):
			var after := [event.position, event.state, event.current_frame, event.auto_script, event.vanish_time]
			if before.get(event.object_id) != after:
				changed_events += 1
		vm.free()
	if not unsupported.is_empty():
		printerr("FAIL: %d 个场景自动脚本遇到未支持指令：%s" % [scene_count, ", ".join(unsupported)])
		quit(1)
		return
	if changed_events == 0:
		printerr("FAIL: %d 个场景的自动脚本没有改变任何事件状态" % scene_count)
		quit(1)
		return
	print("PASS: %d 个剧情场景自动脚本运行 120 帧，无未支持指令；%d 个事件发生动作或状态变化" % [scene_count, changed_events])
	quit(0)
