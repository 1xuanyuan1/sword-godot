# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var session := GameSession.new()
	session.reset_new_game()
	session.scene_index = -1 # 回归只驱动目标触发脚本，避免无关场景自动脚本改变状态。
	session.set_party_world_position(Vector2i(1248, 1040))
	database.player_roles.scene_sprite_numbers[0] = 208
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var messages: Array[int] = []
	var dialog_starts: Array[int] = []
	var current_dialog_position: Array[int] = [-1]
	var message_positions: Dictionary = {}
	var unsupported: Array[String] = []
	var walk_steps: Array[int] = []
	vm.dialog_started.connect(func(position: int, _color: int, _portrait: int) -> void:
		current_dialog_position[0] = position
		dialog_starts.append(position)
	)
	vm.dialog_message.connect(func(index: int) -> void:
		messages.append(index)
		message_positions[index] = current_dialog_position[0]
	)
	vm.unsupported_instruction.connect(func(index: int, operation: int) -> void: unsupported.append("0x%04X@%d" % [operation, index]))
	vm.party_step_performed.connect(func() -> void: walk_steps.append(1))

	vm.run_trigger(4995, 21)
	_drive_script(vm)
	if messages != [718, 719] or dialog_starts != [3]:
		_fail("酒菜环境描述没有合并成一个系统 Toast：消息 %s，位置 %s" % [messages, dialog_starts], vm)
		return

	messages.clear()
	dialog_starts.clear()
	message_positions.clear()
	vm.run_trigger(4885, 16)
	_drive_script(vm)
	var expected_delivery: Array[int] = []
	for index in range(674, 693):
		expected_delivery.append(index)
	if not unsupported.is_empty():
		_fail("端酒菜剧情遇到未支持指令：%s" % ", ".join(unsupported), vm)
		return
	if messages != expected_delivery:
		_fail("端酒菜对话不完整：%s" % messages, vm)
		return
	if message_positions.get(692, -1) != 3:
		_fail("收起桂花酒的系统叙述没有使用 Toast：%s" % message_positions.get(692, -1), vm)
		return
	if session.party_world_position() != Vector2i(1312, 1072) or walk_steps.size() != 16:
		_fail("端酒菜强制走位不完整：位置 %s，步数 %d" % [session.party_world_position(), walk_steps.size()], vm)
		return
	if session.item_count(272) != 1 or database.player_roles.scene_sprite_numbers[0] != 2:
		_fail("端酒菜后没有正确收起桂花酒或恢复普通造型", vm)
		return
	if session.scripted_party_frame(0) != -1:
		_fail("收起桂花酒后仍残留旧端盘动作帧，李逍遥会在移动前消失", vm)
		return

	messages.clear()
	session.scene_index = 2
	session.party_direction = GameSession.DIR_SOUTH
	session.set_party_world_position(Vector2i(1040, 1672))
	var wine := database.item_definition(272)
	if wine == null or wine.script_on_use != 39660 or not wine.is_usable():
		_fail("桂花酒对象数据没有正确解析", vm)
		return
	vm.run_trigger(wine.script_on_use, 0xffff)
	_drive_script(vm)
	if not vm.script_success or database.event_objects[62].trigger_script != 5066 or database.event_objects[62].trigger_mode != 5:
		_fail("从物品菜单使用桂花酒后，醉道士事件没有进入接酒状态", vm)
		return
	vm.run_trigger(database.event_objects[62].trigger_script, 63)
	_drive_script(vm)
	var expected_wine: Array[int] = []
	for index in range(751, 790):
		expected_wine.append(index)
	if not unsupported.is_empty():
		_fail("醉道士剧情遇到未支持指令：%s" % ", ".join(unsupported), vm)
		return
	if messages != expected_wine:
		_fail("从物品使用进入的醉道士对话不完整：%s" % messages, vm)
		return
	if session.item_count(272) != 0 or database.event_objects[62].state != 0:
		_fail("醉道士喝酒后物品或人物状态没有正确收尾", vm)
		return
	print("PASS: 酒菜描述 718–719 与收酒消息 692 使用 Toast；端酒菜、菜单用酒及醉道士流程均完成")
	vm.free()
	quit(0)


func _drive_script(vm: ScriptVM) -> void:
	var guard := 0
	while (vm.running or vm.waiting_for_dialog or vm.waiting_for_frames or vm.waiting_for_party_walk) and guard < 20000:
		if vm.waiting_for_dialog:
			vm.advance_dialog()
		else:
			vm.tick_frame()
		guard += 1


func _fail(message: String, vm: ScriptVM) -> void:
	printerr("FAIL: %s" % message)
	vm.free()
	quit(1)
