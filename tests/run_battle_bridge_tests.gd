# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用合成脚本验证 `004A/0007` 的战场状态、阻塞请求和胜败/逃跑分支。
## 同时检查探索 HUD 已预留隐藏的剧情战斗覆盖层，不依赖原版资源。
extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	_test_battle_victory_and_defeat_branches()
	_test_battle_flee_branch()
	_test_battle_wait_blocks_other_triggers()
	_test_explorer_battle_overlay()
	if _failures.is_empty():
		print("PASS: %d scripted battle bridge checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("%d/%d checks failed" % [_failures.size(), _checks])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _test_battle_victory_and_defeat_branches() -> void:
	var database := _database_with_operations([0, 0x004a, 0x0007, 0x0047, 0, 0x0047, 0])
	database.scripts[1].operands[0] = 21
	database.scripts[2].operands = PackedInt32Array([18, 5, 0])
	database.scripts[3].operands[0] = 11
	database.scripts[5].operands[0] = 22
	var victory := _configured_vm(database)
	var victory_vm: ScriptVM = victory[0]
	var victory_session: GameSession = victory[1]
	var victory_requests: Array = []
	var victory_sounds: Array[int] = []
	victory_vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: victory_requests.append([team, field, boss]))
	victory_vm.sound_requested.connect(func(number: int) -> void: victory_sounds.append(number))
	victory_vm.run_trigger(1)
	_expect(victory_session.battlefield_number == 21 and victory_requests == [[18, 21, true]], "004A and 0007 request the selected boss battlefield")
	_expect(victory_vm.waiting_for_battle and not victory_vm.running and victory_sounds.is_empty(), "0007 blocks later script instructions")
	victory_vm.complete_battle(ScriptVM.BATTLE_RESULT_VICTORY)
	_expect(not victory_vm.waiting_for_battle and victory_sounds == [11], "victory resumes at the instruction after 0007")
	victory_vm.free()

	var defeat := _configured_vm(database)
	var defeat_vm: ScriptVM = defeat[0]
	var defeat_sounds: Array[int] = []
	defeat_vm.battle_requested.connect(func(_team: int, _field: int, _boss: bool) -> void: pass)
	defeat_vm.sound_requested.connect(func(number: int) -> void: defeat_sounds.append(number))
	defeat_vm.run_trigger(1)
	defeat_vm.complete_battle(ScriptVM.BATTLE_RESULT_DEFEAT)
	_expect(defeat_sounds == [22], "defeat jumps to operand one")
	defeat_vm.free()


func _test_battle_flee_branch() -> void:
	var database := _database_with_operations([0, 0x004a, 0x0007, 0x0047, 0, 0x0047, 0])
	database.scripts[1].operands[0] = 9
	database.scripts[2].operands = PackedInt32Array([3, 0, 5])
	database.scripts[3].operands[0] = 33
	database.scripts[5].operands[0] = 44
	var configured := _configured_vm(database)
	var vm: ScriptVM = configured[0]
	var requests: Array = []
	var sounds: Array[int] = []
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: requests.append([team, field, boss]))
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(1)
	vm.complete_battle(ScriptVM.BATTLE_RESULT_FLED)
	_expect(requests == [[3, 9, false]], "nonzero flee entry marks a battle as escapable")
	_expect(sounds == [44], "flee jumps to operand two")
	vm.free()


func _test_battle_wait_blocks_other_triggers() -> void:
	var database := _database_with_operations([0, 0x0007, 0, 0x0047, 0])
	database.scripts[1].operands = PackedInt32Array([1, 0, 0])
	database.scripts[3].operands[0] = 77
	var configured := _configured_vm(database)
	var vm: ScriptVM = configured[0]
	var sounds: Array[int] = []
	vm.battle_requested.connect(func(_team: int, _field: int, _boss: bool) -> void: pass)
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(1)
	_expect(vm.run_trigger(3) == 3 and sounds.is_empty(), "battle wait rejects unrelated trigger scripts")
	vm.stop()
	_expect(not vm.waiting_for_battle, "stop clears battle wait state")
	vm.free()


func _test_explorer_battle_overlay() -> void:
	var explorer = load("res://src/world/map_explorer.gd").new()
	explorer._build_interface()
	_expect(explorer._battle_view != null and explorer._battle_view.get_parent() == explorer._ui_layer, "battle overlay belongs to the foreground HUD canvas")
	_expect(not explorer._battle_view.lab_mode, "explorer battle overlay uses story mode")
	explorer.free()


func _configured_vm(database: PalContentDatabase) -> Array:
	var session := GameSession.new()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	return [vm, session]


func _database_with_operations(operations: Array[int]) -> PalContentDatabase:
	var database := PalContentDatabase.new()
	for operation in operations:
		var entry := PalScriptEntry.new()
		entry.operation = operation
		entry.operands = PackedInt32Array([0, 0, 0])
		database.scripts.append(entry)
	return database
