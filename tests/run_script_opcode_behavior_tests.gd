# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## TD-001 缺口操作码的合成行为回归；覆盖成功、分支失败、阻塞恢复和 signed WORD 边界。
extends SceneTree

const PoisonDefinition := preload("res://src/content/pal_poison_definition.gd")
const REQUIRED_OPCODES := [
	0x000a, 0x0019, 0x0026, 0x0027, 0x0030, 0x0031, 0x0033, 0x0034, 0x0035, 0x003a,
	0x0041, 0x004d, 0x004e, 0x004f, 0x0056, 0x0057, 0x0058, 0x005a, 0x005c,
	0x0062, 0x0063, 0x006a, 0x006b, 0x0071, 0x0074,
	0x0084, 0x0086, 0x0088, 0x008a, 0x008b, 0x008c, 0x008d, 0x008f,
	0x0092, 0x0095, 0x0096, 0x0098, 0x0099, 0x009b,
	0x00a0, 0x00a4, 0x00a5, 0x00a6,
]

var _checks := 0
var _failures: Array[String] = []
var _covered: Dictionary = {}


func _init() -> void:
	_test_common_path_equivalence()
	_test_field_state_and_branches()
	_test_blocking_and_system_operations()
	_test_shop_transactions()
	_test_battle_operations()
	var missing: PackedStringArray = PackedStringArray()
	for operation in REQUIRED_OPCODES:
		if not _covered.has(operation):
			missing.append("%04X" % operation)
	_expect(missing.is_empty(), "all 43 TD-001 opcodes execute in a behavior test; missing=%s" % ",".join(missing))
	if _failures.is_empty():
		print("PASS: %d TD-001 opcode behavior checks; 43/43 operations executed" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("%d/%d TD-001 opcode behavior checks failed" % [_failures.size(), _checks])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _cover(operation: int) -> void:
	_covered[operation] = true


func _test_common_path_equivalence() -> void:
	# 0082：主触发与即时调用会同步走完，自动脚本逐帧重试；最终世界状态必须一致。
	var positions: Array[Vector2i] = []
	for context in range(3):
		var database := _field_database()
		var event := database.event_objects[0]
		event.position = Vector2i.ZERO
		if context == 0:
			database.scripts = [_entry(0), _entry(0x0082, 1, 0, 0), _entry(0)]
			var vm := ScriptVM.new()
			vm.configure(database, _field_session(database))
			vm.run_trigger(1, 1)
			vm.free()
		elif context == 1:
			database.scripts = [_entry(0), _entry(0x0082, 1, 0, 0), _entry(0)]
			event.auto_script = 1
			var vm := ScriptVM.new()
			vm.configure(database, _field_session(database))
			for _frame in range(8):
				vm.tick_frame()
				if event.auto_script == 2:
					break
			vm.free()
		else:
			database.scripts = [_entry(0), _entry(0x0004, 3, 1, 0), _entry(0), _entry(0x0082, 1, 0, 0), _entry(0)]
			event.auto_script = 1
			var vm := ScriptVM.new()
			vm.configure(database, _field_session(database))
			vm.tick_frame()
			vm.free()
		positions.append(event.position)
	_expect(positions == [Vector2i(32, 0), Vector2i(32, 0), Vector2i(32, 0)], "0082 reaches the same high-speed NPC target through trigger, auto and instant paths")
	_cover(0x0082) # 公共层迁移回归，不属于原 43 项，但必须锁住架构要求。

	# 0083：三条路径都走同一距离失败分支，并传播脚本失败标志。
	var failed_states: Array[int] = []
	var success_flags: Array[bool] = []
	for context in range(3):
		var database := _field_database()
		database.event_objects[0].position = Vector2i.ZERO
		database.event_objects[1].position = Vector2i(320, 200)
		if context < 2:
			database.scripts = [_entry(0), _entry(0x0083, 2, 1, 4), _entry(0x0049, 1, 1, 0), _entry(0), _entry(0x0049, 1, 0xfffe, 0), _entry(0)]
		else:
			database.scripts = [_entry(0), _entry(0x0004, 3, 1, 0), _entry(0), _entry(0x0083, 2, 1, 6), _entry(0x0049, 1, 1, 0), _entry(0), _entry(0x0049, 1, 0xfffe, 0), _entry(0)]
		var vm := ScriptVM.new()
		vm.configure(database, _field_session(database))
		if context == 0:
			vm.run_trigger(1, 1)
		else:
			database.event_objects[0].auto_script = 1
			vm.tick_frame()
			vm.tick_frame()
		failed_states.append(database.event_objects[0].state)
		success_flags.append(vm.script_success)
		vm.free()
	_expect(failed_states == [-2, -2, -2] and success_flags == [false, false, false], "0083 has identical jump and failure semantics in trigger, auto and instant contexts")
	_cover(0x0083)

	# 0087：三条路径只推进一帧，不移动事件坐标。
	var frames: Array[int] = []
	for context in range(3):
		var database := _field_database()
		var event := database.event_objects[0]
		event.sprite_frames = 3
		if context < 2:
			database.scripts = [_entry(0), _entry(0x0087, 0, 0, 0), _entry(0)]
		else:
			database.scripts = [_entry(0), _entry(0x0004, 3, 1, 0), _entry(0), _entry(0x0087, 0, 0, 0), _entry(0)]
		var vm := ScriptVM.new()
		vm.configure(database, _field_session(database))
		if context == 0:
			vm.run_trigger(1, 1)
		else:
			event.auto_script = 1
			vm.tick_frame()
		frames.append(event.current_frame)
		vm.free()
	_expect(frames == [1, 1, 1], "0087 advances one identical EventObject animation frame through all common paths")
	_cover(0x0087)


func _test_field_state_and_branches() -> void:
	var database := _field_database()
	var session := _field_session(database)
	var vm := ScriptVM.new()
	vm.configure(database, session)

	# 0019 preserves signed input and WORD wraparound.
	database.scripts = [_entry(0), _entry(0x0019, 17, 0xffff, 1), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.role_attack_strength[0] == 39, "0019 applies signed FFFF as -1 to an explicit PLAYERROLES field")
	session.role_attack_strength[0] = 0
	vm.run_trigger(1, 1)
	_expect(session.role_attack_strength[0] == 0xffff, "0019 retains official 16-bit underflow semantics")
	_cover(0x0019)

	# 0034 succeeds deterministically at collect value 1 and branches without mutating at zero.
	database.scripts = [_entry(0), _entry(0x0034, 4, 0, 0), _entry(0), _entry(0), _entry(0x0047, 77, 0, 0), _entry(0)]
	session.collect_value = 1
	vm.run_trigger(1, 1)
	_expect(session.collect_value == 0 and session.item_count(5) == 1, "0034 converts one collect point through store zero")
	var sounds: Array[int] = []
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))
	vm.run_trigger(1, 1)
	_expect(sounds == [77] and session.item_count(5) == 1, "0034 takes its failure branch at zero collect value without changing inventory")
	_cover(0x0034)

	var shakes: Array = []
	vm.screen_shake_requested.connect(func(frames: int, level: int) -> void: shakes.append([frames, level]))
	database.scripts = [_entry(0), _entry(0x0035, 3, 0, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(shakes == [[3, 4]], "0035 uses the official default shake level when operand one is zero")
	_cover(0x0035)

	database.scripts = [_entry(0), _entry(0x0041), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(not vm.script_success, "0041 marks a field script as failed without aborting the interpreter")
	_cover(0x0041)

	session.add_magic(0, 10)
	database.scripts = [_entry(0), _entry(0x0056, 10, 1, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(not session.has_magic(0, 10), "0056 removes the selected learned magic and tolerates an already-absent magic")
	vm.run_trigger(1, 1)
	_cover(0x0056)

	session.role_mp[0] = 7
	database.magics[0].base_damage = 0
	database.scripts = [_entry(0), _entry(0x0057, 10, 0, 0), _entry(0)]
	vm.run_trigger(1, 0)
	_expect(database.magics[0].base_damage == 56 and session.role_mp[0] == 0, "0057 uses the default MP multiplier eight and consumes all MP")
	_cover(0x0057)

	# 0058 branches below the threshold; signed FFFF is a negative boundary and therefore falls through.
	database.scripts = [_entry(0), _entry(0x0058, 5, 2, 4), _entry(0x0047, 11, 0, 0), _entry(0), _entry(0x0047, 22, 0, 0), _entry(0)]
	session.set_item_count(5, 1)
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [22], "0058 jumps when inventory is below the requested amount")
	database.scripts[1].operands[1] = 0xffff
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [11], "0058 interprets its amount as signed WORD at the negative boundary")
	_cover(0x0058)

	database.scripts = [_entry(0), _entry(0x005a), _entry(0)]
	session.role_hp[0] = 5
	vm.run_trigger(1, 0)
	_expect(session.role_hp[0] == 2, "005A halves odd HP using integer truncation")
	_cover(0x005a)

	database.scripts = [_entry(0), _entry(0x0062, 2, 0, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.chase_speed_change_cycles == 2 and session.chase_range_multiplier == 0, "0062 pauses chase for the requested update cycles")
	vm.tick_frame()
	vm.tick_frame()
	_expect(session.chase_speed_change_cycles == 0 and session.chase_range_multiplier == 1, "0062 restores the chase range exactly when its counter expires")
	database.scripts = [_entry(0), _entry(0x0063, 0, 0, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.chase_speed_change_cycles == 0 and session.chase_range_multiplier == 3, "0063 accepts the zero-cycle boundary and immediately selects accelerated range")
	_cover(0x0062)
	_cover(0x0063)

	var waves: Array = []
	vm.screen_wave_requested.connect(func(amplitude: int, progression: int) -> void: waves.append([amplitude, progression]))
	database.scripts = [_entry(0), _entry(0x0071, 6, 0xfffe, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(waves == [[6, -2]], "0071 forwards amplitude and signed wave progression")
	_cover(0x0071)

	database.scripts = [_entry(0), _entry(0x0074, 4, 0, 0), _entry(0x0047, 31, 0, 0), _entry(0), _entry(0x0047, 32, 0, 0), _entry(0)]
	session.role_hp[0] = session.role_max_hp[0] - 1
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [32], "0074 jumps when any party role is not at full HP")
	session.role_hp[0] = session.role_max_hp[0]
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [31], "0074 falls through when the whole party is full HP")
	_cover(0x0074)

	# 0084 only commits event placement after the formal map obstruction test succeeds.
	database.scripts = [_entry(0), _entry(0x0084, 2, 3, 4), _entry(0), _entry(0), _entry(0x0047, 41, 0, 0), _entry(0)]
	session.party_direction = GameSession.DIR_EAST
	var open_map := _map_with_blocked_position(Vector2i(-1, -1))
	vm.set_scene_map(open_map)
	vm.run_trigger(1, 1)
	var placed := session.party_world_position() + Vector2i(16, 8)
	_expect(database.event_objects[1].position == placed and database.event_objects[1].state == 3 and vm.script_success, "0084 places the item event one half-step ahead on an unblocked TileMap position")
	var before_position := database.event_objects[1].position
	var before_state := database.event_objects[1].state
	vm.set_scene_map(_map_with_blocked_position(placed))
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [41] and database.event_objects[1].position == before_position and database.event_objects[1].state == before_state and not vm.script_success, "0084 failure leaves item-event position and state unchanged")
	_cover(0x0084)

	database.scripts = [_entry(0), _entry(0x0086, 5, 1, 4), _entry(0x0047, 51, 0, 0), _entry(0), _entry(0x0047, 52, 0, 0), _entry(0)]
	session.replace_equipped_item(0, 0, 0)
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [52], "0086 jumps when the requested item is not equipped")
	session.replace_equipped_item(0, 0, 5)
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [51], "0086 counts equipment across current party roles")
	_cover(0x0086)

	database.scripts = [_entry(0), _entry(0x0088, 10, 0, 0), _entry(0)]
	session.cash = 7001
	vm.run_trigger(1, 1)
	_expect(session.cash == 2001 and database.magics[0].base_damage == 2000, "0088 caps spending at 5000 and derives damage with the official two-fifths ratio")
	session.cash = 1
	vm.run_trigger(1, 1)
	_expect(session.cash == 0 and database.magics[0].base_damage == 0, "0088 handles the one-coin integer boundary")
	_cover(0x0088)

	database.scripts = [_entry(0), _entry(0x008a), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.auto_battle_pending, "008A marks only the next battle for automatic commands")
	_cover(0x008a)

	var redraws: Array[int] = []
	vm.redraw_requested.connect(func(delay: int) -> void: redraws.append(delay))
	database.scripts = [_entry(0), _entry(0x008b, 7, 0, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.palette_index == 7 and redraws.back() == 0, "008B changes palette number and requests a formal-world redraw")
	_cover(0x008b)

	database.scripts = [_entry(0), _entry(0x008d, 1, 0, 0), _entry(0)]
	session.role_levels[0] = PalLevelProgression.MAX_LEVEL
	var old_max_hp := session.role_max_hp[0]
	vm.run_trigger(1, 0)
	_expect(session.role_levels[0] == PalLevelProgression.MAX_LEVEL and session.role_max_hp[0] >= old_max_hp + 10, "008D caps level but preserves official requested-growth behavior at level 99")
	_cover(0x008d)

	database.scripts = [_entry(0), _entry(0x008f), _entry(0)]
	session.cash = 5
	vm.run_trigger(1, 1)
	_expect(session.cash == 2, "008F halves odd cash by integer truncation")
	_cover(0x008f)

	database.scripts = [_entry(0), _entry(0x0095, 1, 4, 0), _entry(0x0047, 61, 0, 0), _entry(0), _entry(0x0047, 62, 0, 0), _entry(0)]
	session.scene_index = 0
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [62], "0095 compares the current one-based scene and jumps on equality")
	database.scripts[1].operands[0] = 2
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(sounds == [61], "0095 falls through for a different scene")
	_cover(0x0095)

	var follower_signals := [0]
	vm.followers_changed.connect(func() -> void: follower_signals[0] += 1)
	database.scripts = [_entry(0), _entry(0x0098, 301, 0, 999), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(session.follower_sprite_numbers == PackedInt32Array([301]) and follower_signals[0] == 1, "0098 keeps at most the two defined follower operands and ignores zero/operand two")
	_cover(0x0098)

	var map_changes: Array[int] = []
	vm.map_change_requested.connect(func(scene_index: int) -> void: map_changes.append(scene_index))
	database.scripts = [_entry(0), _entry(0x0099, 0xffff, 77, 0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(database.scenes[0].map_number == 77 and map_changes == [0], "0099 FFFF updates and reloads only the current TileMap scene")
	database.scripts[1].operands = PackedInt32Array([2, 88, 0])
	vm.run_trigger(1, 1)
	_expect(database.scenes[1].map_number == 88 and map_changes == [0], "0099 changes an off-screen scene without reloading the current map")
	_cover(0x0099)
	vm.free()


func _test_blocking_and_system_operations() -> void:
	var database := _field_database()
	var session := _field_session(database)
	var vm := ScriptVM.new()
	vm.configure(database, session)
	var sounds: Array[int] = []
	vm.sound_requested.connect(func(number: int) -> void: sounds.append(number))

	# 000A yes falls through, no jumps, and both choices resume from a blocking state.
	database.scripts = [_entry(0), _entry(0x000a, 4, 0, 0), _entry(0x0047, 1, 0, 0), _entry(0), _entry(0x0047, 2, 0, 0), _entry(0)]
	var confirmations := [0]
	vm.confirmation_requested.connect(func() -> void: confirmations[0] += 1)
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_confirmation and confirmations[0] == 1 and sounds.is_empty(), "000A blocks before executing either choice branch")
	vm.complete_confirmation(true)
	_expect(sounds == [1], "000A yes resumes at the following instruction")
	sounds.clear()
	vm.run_trigger(1, 1)
	vm.complete_confirmation(false)
	_expect(sounds == [2], "000A no resumes at its explicit jump entry")
	database.messages = ["正文"]
	database.scripts = [_entry(0), _entry(0x003b), _entry(0xffff, 0, 0, 0), _entry(0x000a, 5, 0, 0), _entry(0), _entry(0)]
	var confirmation_count_before_dialog := int(confirmations[0])
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_dialog and not vm.waiting_for_confirmation and confirmations[0] == confirmation_count_before_dialog, "000A waits for the current dialogue body round before opening its menu")
	vm.advance_dialog()
	_expect(vm.waiting_for_confirmation and confirmations[0] == confirmation_count_before_dialog + 1, "000A opens only after dialogue acknowledgement")
	vm.complete_confirmation(true)
	_cover(0x000a)

	var shops: Array = []
	vm.shop_requested.connect(func(store_id: int, buying: bool) -> void: shops.append([store_id, buying]))
	for operation in [0x0026, 0x0027]:
		database.scripts = [_entry(0), _entry(operation, 3, 0, 0), _entry(0x0047, operation, 0, 0), _entry(0)]
		sounds.clear()
		vm.run_trigger(1, 1)
		_expect(vm.waiting_for_shop and sounds.is_empty(), "%04X blocks while the classic shop is open" % operation)
		vm.complete_shop()
		_expect(sounds == [operation], "%04X resumes after the shop closes" % operation)
		_cover(operation)
	_expect(shops == [[3, true], [3, false]], "0026/0027 distinguish buy and sell requests")
	database.scripts = [_entry(0), _entry(0x003b), _entry(0xffff, 0, 0, 0), _entry(0x0026, 3, 0, 0), _entry(0)]
	var shop_count_before_dialog: int = shops.size()
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_dialog and not vm.waiting_for_shop and shops.size() == shop_count_before_dialog, "0026 waits for dialogue acknowledgement before opening the store")
	vm.advance_dialog()
	_expect(vm.waiting_for_shop and shops.size() == shop_count_before_dialog + 1, "0026 opens after the dialogue boundary and then blocks")
	vm.complete_shop()

	var key_requests := [0]
	vm.key_wait_requested.connect(func() -> void: key_requests[0] += 1)
	database.scripts = [_entry(0), _entry(0x004d), _entry(0x0047, 4, 0, 0), _entry(0)]
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_key and key_requests[0] == 1 and sounds.is_empty(), "004D blocks until any key is delivered")
	vm.complete_key_wait()
	_expect(sounds == [4], "004D resumes at the next instruction")
	_cover(0x004d)

	var load_requests := [0]
	vm.load_current_save_requested.connect(func() -> void: load_requests[0] += 1)
	database.scripts = [_entry(0), _entry(0x004e), _entry(0x0047, 5, 0, 0), _entry(0)]
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_load and load_requests[0] == 1 and sounds.is_empty(), "004E terminates script flow and waits for active-slot UI resolution")
	vm.complete_load_request()
	_expect(not vm.is_busy() and sounds.is_empty(), "004E never continues into the old script after load cancellation")
	_cover(0x004e)

	var game_over: Array[float] = []
	vm.game_over_requested.connect(func(duration: float) -> void: game_over.append(duration))
	database.scripts = [_entry(0), _entry(0x004f), _entry(0x0047, 6, 0, 0), _entry(0)]
	sounds.clear()
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_screen_fade and game_over.size() == 1 and sounds.is_empty(), "004F blocks on the red game-over fade")
	vm.complete_screen_fade()
	_expect(sounds == [6], "004F resumes after the red fade callback")
	_cover(0x004f)

	var color_fades: Array = []
	vm.color_fade_requested.connect(func(color: int, from_color: bool, duration: float) -> void: color_fades.append([color, from_color, duration]))
	database.scripts = [_entry(0), _entry(0x008c, 0x123, 2, 1), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_screen_fade and color_fades.size() == 1 and color_fades[0][0] == 0x23 and color_fades[0][1] and is_equal_approx(color_fades[0][2], 1.28), "008C masks the palette index to a byte and preserves fade direction/timing")
	vm.complete_screen_fade()
	_cover(0x008c)

	var endings: Array = []
	vm.ending_requested.connect(func(kind: int, first: int, second: int, third: int) -> void: endings.append([kind, first, second, third]))
	for spec in [[0x0096, 0, 0, 0], [0x00a4, 68, 0, 15], [0x00a5, 69, 571, 2]]:
		database.scripts = [_entry(0), _entry(spec[0], spec[1], spec[2], spec[3]), _entry(0)]
		vm.run_trigger(1, 1)
		_expect(vm.waiting_for_screen_fade, "%04X blocks while the ending player owns the frame" % spec[0])
		vm.complete_screen_fade()
		_cover(spec[0])
	_expect(endings == [[ScriptVM.ENDING_ANIMATION, 0, 0, 0], [ScriptVM.ENDING_SCROLL_FBP, 68, 0, 15], [ScriptVM.ENDING_SHOW_FBP_EFFECT, 69, 571, 2]], "0096/00A4/00A5 route typed operands to the dedicated ending player")

	var scene_fades: Array[float] = []
	vm.scene_fade_requested.connect(func(duration: float) -> void: scene_fades.append(duration))
	database.scripts = [_entry(0), _entry(0x009b), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(vm.waiting_for_screen_fade and scene_fades == [1.2], "009B rebuilds and blocks on the formal current-scene fade")
	vm.complete_screen_fade()
	_cover(0x009b)

	var quit_requests := [0]
	vm.quit_requested.connect(func() -> void: quit_requests[0] += 1)
	database.scripts = [_entry(0), _entry(0x00a0), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(quit_requests[0] == 1 and not vm.is_busy(), "00A0 emits the test-safe unified quit request without terminating this process")
	_cover(0x00a0)

	var backups := [0]
	vm.screen_backup_requested.connect(func() -> void: backups[0] += 1)
	database.scripts = [_entry(0), _entry(0x00a6), _entry(0)]
	vm.run_trigger(1, 1)
	_expect(backups[0] == 1, "00A6 requests one current-screen backup and continues")
	_cover(0x00a6)
	vm.free()


func _test_shop_transactions() -> void:
	var database := _field_database()
	var session := _field_session(database)
	var menu := PalGameMenu.new()
	menu.database = database
	menu.session = session
	session.cash = 200
	session.set_item_count(5, 98)
	menu.open_shop(0, true)
	menu._confirm_shop_selection()
	menu._shop_confirmation_selection = 1
	menu._confirm_shop_selection()
	_expect(session.cash == 99 and session.item_count(5) == 99, "classic buy page deducts base price and reaches the 99-item cap")
	menu._confirm_shop_selection()
	menu._shop_confirmation_selection = 1
	menu._confirm_shop_selection()
	_expect(session.cash == 99 and session.item_count(5) == 99, "classic buy page rejects purchases beyond 99 without charging cash")
	menu.open_shop(0, false)
	_expect(menu._shop_ids == [5], "classic sell page lists only owned sellable items")
	menu._confirm_shop_selection()
	menu._shop_confirmation_selection = 1
	menu._confirm_shop_selection()
	_expect(session.cash == 149 and session.item_count(5) == 98, "classic sell page pays integer half of the 101 base price")
	menu.free()

	var bytes := PackedByteArray()
	bytes.resize(PalStoreDefinition.BYTE_SIZE)
	bytes.encode_u16(0, 5)
	bytes.encode_u16(16, 9)
	var store := PalStoreDefinition.from_bytes(bytes, 0, 4)
	_expect(store != null and store.store_id == 4 and store.item_ids == PackedInt32Array([5, 9]), "DATA.MKF #0 store parser reads all nine little-endian item slots and skips zeros")


func _test_battle_operations() -> void:
	var database := _battle_database()
	var session := _field_session(database)
	var controller := PalBattleController.new()
	_expect(controller.start_battle(database, session, 0, 0, 123), "battle fixture starts for TD-001 effect opcodes")

	database.scripts = [_entry(0), _entry(0x0030, 17, 50, 1), _entry(0)]
	var result := PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, false, 0, result)
	_expect(session.equipment_effect_total(0, 17) == 20, "0030 writes a signed percentage of the base role stat into the temporary battle slot")
	_cover(0x0030)

	database.scripts = [_entry(0), _entry(0x0031, 77, 0, 0), _entry(0)]
	result = PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, false, 0, result)
	_expect(session.battle_sprite_for(0, 0) == 77 and result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.PLAYER_SPRITE), "0031 changes the target battle Sprite through the temporary equipment slot")
	_cover(0x0031)

	database.scripts = [_entry(0), _entry(0x0033, 2, 0, 0), _entry(0)]
	result = PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, true, 0, result)
	_expect(session.collect_value == 4, "0033 adds the target enemy collect value")
	controller.enemies[0].definition.collect_value = 0
	database.scripts = [_entry(0), _entry(0x0033, 3, 0, 0), _entry(0), _entry(0x001f, 5, 1, 0), _entry(0)]
	controller._run_battle_effect_script(1, false, true, 0, PalBattleController.ActionResult.new())
	_expect(session.item_count(5) == 1, "0033 jumps when the target enemy has no collect value")
	controller.enemies[0].definition.collect_value = 4
	_cover(0x0033)

	database.scripts = [_entry(0), _entry(0x005c, 2, 0, 0), _entry(0)]
	result = PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, false, 0, result)
	_expect(controller._hiding_turns == 2 and result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.HIDING), "005C starts a bounded battle-only hiding state")
	_cover(0x005c)

	database.scripts = [_entry(0), _entry(0x006a, 0, 0, 0), _entry(0)]
	controller.enemies[0].steal_item = 5
	controller.enemies[0].steal_item_count = 1
	var count_before_steal := session.item_count(5)
	result = PalBattleController.ActionResult.new()
	var steal_outcome := controller._run_battle_effect_script(1, false, true, 0, result)
	_expect(bool(steal_outcome.success) and session.item_count(5) == count_before_steal + 1 and controller.enemies[0].steal_item_count == 0, "006A steals an item and keeps normal script success semantics")
	var failed_steal := controller._run_battle_effect_script(1, false, true, 0, PalBattleController.ActionResult.new())
	_expect(bool(failed_steal.success), "006A no-item failure does not mark the whole use script failed")
	_cover(0x006a)

	database.scripts = [_entry(0), _entry(0x006b, 0xfff8, 0, 0), _entry(0)]
	result = PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, true, 0, result)
	_expect(controller._blow_displacement == -8 and result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.BLOW and event.value == -8), "006B preserves signed WORD blow displacement in battle visual events")
	_cover(0x006b)

	database.scripts = [_entry(0), _entry(0x0092, 1, 0, 0), _entry(0)]
	result = PalBattleController.ActionResult.new()
	controller._run_battle_effect_script(1, false, false, 0, result)
	_expect(result.script_events.any(func(event: PalBattleController.ScriptEvent) -> bool: return event.type == PalBattleController.ScriptEventType.PRE_MAGIC and event.value == 0), "0092 emits the selected one-based player pre-magic animation")
	_cover(0x0092)

	# 008A is consumed immediately by a real battle and is cleared unconditionally during cleanup.
	var auto_database := _battle_database()
	var auto_session := _field_session(auto_database)
	auto_session.auto_battle_pending = true
	var auto_controller := PalBattleController.new()
	auto_controller.start_battle(auto_database, auto_session, 0, 0, 7)
	_expect(auto_controller.is_auto_battle() and not auto_session.auto_battle_pending, "008A is consumed when the immediately following battle starts")
	auto_controller.battle_result = PalBattleController.BattleResult.VICTORY
	auto_controller._apply_battle_cleanup_if_needed()
	_expect(not auto_controller._auto_battle, "008A battle state is cleared after every battle result")

	var flee_database := _battle_database()
	var flee_session := _field_session(flee_database)
	flee_database.scripts = [_entry(0), _entry(0x003a, 3, 0, 0), _entry(0), _entry(0x0041), _entry(0)]
	var flee_controller := PalBattleController.new()
	flee_controller.start_battle(flee_database, flee_session, 0, 0, 9, false)
	flee_controller._run_battle_effect_script(1, false, false, 0, PalBattleController.ActionResult.new())
	_expect(flee_controller.battle_result == PalBattleController.BattleResult.FLED, "003A ends a non-boss battle as fled")
	var boss_controller := PalBattleController.new()
	boss_controller.start_battle(flee_database, _field_session(flee_database), 0, 0, 9, true)
	var boss_outcome := boss_controller._run_battle_effect_script(1, false, false, 0, PalBattleController.ActionResult.new())
	_expect(boss_controller.battle_result == PalBattleController.BattleResult.ONGOING and not bool(boss_outcome.success), "003A takes its failure branch in a boss battle")
	_cover(0x003a)


func _field_database() -> PalContentDatabase:
	var database := PalContentDatabase.new()
	database.player_roles = _roles()
	for scene_index in range(2):
		var scene := PalSceneDefinition.new()
		scene.map_number = scene_index
		scene.event_object_index = 0 if scene_index == 0 else 2
		database.scenes.append(scene)
	for object_id in range(1, 3):
		var event := PalEventObject.new()
		event.object_id = object_id
		event.position = Vector2i(160 + object_id * 16, 112)
		event.state = 2
		event.sprite_frames = 3
		database.event_objects.append(event)
	database.scripts = [_entry(0)]
	while database.items.size() <= 10:
		var item := PalItemDefinition.new()
		item.object_id = database.items.size()
		database.items.append(item)
	database.items[5].price = 101
	database.items[5].flags = PalItemDefinition.FLAG_SELLABLE
	while database.magic_objects.size() <= 10:
		var magic_object := PalMagicObjectDefinition.new()
		magic_object.object_id = database.magic_objects.size()
		database.magic_objects.append(magic_object)
	database.magic_objects[10].magic_number = 0
	var magic := PalMagicDefinition.new()
	magic.magic_number = 0
	database.magics.append(magic)
	var store := PalStoreDefinition.new()
	store.store_id = 0
	store.item_ids = PackedInt32Array([5])
	database.stores.append(store)
	return database


func _battle_database() -> PalContentDatabase:
	var database := _field_database()
	var enemy := PalEnemyDefinition.new()
	enemy.enemy_id = 0
	enemy.health = 100
	enemy.level = 1
	enemy.attack_strength = 10
	enemy.defense = 5
	enemy.dexterity = 5
	enemy.physical_resistance = 1
	enemy.collect_value = 4
	database.enemies.append(enemy)
	database.enemy_objects.clear()
	database.enemy_objects.append(PalEnemyObjectDefinition.new())
	var enemy_object := PalEnemyObjectDefinition.new()
	enemy_object.object_id = 1
	enemy_object.enemy_id = 0
	database.enemy_objects.append(enemy_object)
	var team := PalEnemyTeam.new()
	team.team_id = 0
	team.object_ids = PackedInt32Array([1, 0, 0, 0, 0])
	database.enemy_teams.append(team)
	var field := PalBattlefield.new()
	field.battlefield_id = 0
	database.battlefields.append(field)
	return database


func _field_session(database: PalContentDatabase) -> GameSession:
	var session := GameSession.new()
	session.party_roles = PackedInt32Array([0])
	session.initialize_role_state(database.player_roles)
	return session


func _roles() -> PalPlayerRoles:
	var roles := PalPlayerRoles.new()
	for role_index in range(PalPlayerRoles.ROLE_COUNT):
		roles.avatar_numbers.append(0)
		roles.battle_sprite_numbers.append(0)
		roles.scene_sprite_numbers.append(0)
		roles.name_word_indices.append(0)
		roles.attack_all.append(0)
		roles.levels.append(1)
		roles.max_hp.append(100)
		roles.max_mp.append(50)
		roles.hp.append(100)
		roles.mp.append(50)
		roles.equipments_by_role.append(PackedInt32Array([0, 0, 0, 0, 0, 0]))
		roles.attack_strengths.append(40)
		roles.magic_strengths.append(30)
		roles.defenses.append(20)
		roles.dexterities.append(15)
		roles.flee_rates.append(10)
		roles.poison_resistances.append(0)
		roles.elemental_resistances_by_role.append(PackedInt32Array([0, 0, 0, 0, 0]))
		roles.covered_by.append(0)
		roles.magics_by_role.append(PackedInt32Array())
		roles.cooperative_magics.append(0)
		roles.walk_frames.append(3)
		roles.death_sounds.append(0)
		roles.attack_sounds.append(0)
		roles.weapon_sounds.append(0)
		roles.critical_sounds.append(0)
		roles.magic_sounds.append(0)
		roles.cover_sounds.append(0)
		roles.dying_sounds.append(0)
	return roles


func _map_with_blocked_position(blocked_position: Vector2i) -> PalMapData:
	var map := PalMapData.new()
	map.tiles.resize(PalMapData.WIDTH * PalMapData.HEIGHT * PalMapData.HALVES)
	if blocked_position.x >= 0 and blocked_position.y >= 0:
		var tile := PalMapCoordinates.world_to_tile(blocked_position)
		if PalMapCoordinates.is_valid_tile(tile):
			map.tiles[(tile.y * PalMapData.WIDTH + tile.x) * PalMapData.HALVES + tile.z] = 0x2000
	return map


func _entry(operation: int, first: int = 0, second: int = 0, third: int = 0) -> PalScriptEntry:
	var entry := PalScriptEntry.new()
	entry.operation = operation
	entry.operands = PackedInt32Array([first, second, third])
	return entry
