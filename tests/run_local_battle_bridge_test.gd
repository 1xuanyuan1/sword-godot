# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 用真实脚本表验证首个前期强制战斗会阻塞并请求敌队 18 / 战场 21。
## 测试停在战斗请求边界，不自动跳过或伪造后续剧情结果。
extends SceneTree


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var session := GameSession.new()
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var requests: Array = []
	vm.battle_requested.connect(func(team: int, field: int, boss: bool) -> void: requests.append([team, field, boss]))
	vm.run_trigger(6964)
	if requests != [[18, 21, true]]:
		_fail("脚本 6964/6965 未请求敌队 18 / 战场 21：%s" % requests)
		return
	if not vm.waiting_for_battle or vm.running:
		_fail("首战请求后 ScriptVM 没有进入战斗等待")
		return
	var preview := PalBattlePreview.new()
	preview.lab_mode = false
	preview._build_interface()
	if not preview.begin_battle(database, session, 18, 21) or preview._session != session:
		_fail("剧情战斗覆盖层无法复用探索 GameSession")
		return
	preview.free()
	vm.free()
	print("PASS: 真实脚本请求敌队 18 / 战场 21 并阻塞剧情，覆盖层复用探索会话")
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
