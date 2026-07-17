# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal script.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## SDLPal 事件脚本解释器，以异步等待状态执行触发、自动、对话和移动指令。
## VM 修改注入的 `GameSession` 和事件对象，并用信号请求 UI 或世界层执行副作用。
class_name ScriptVM
extends Node

## 每条指令执行前发出，供测试和调试器记录入口、操作码及参数。
signal instruction_started(index: int, operation: int, operands: PackedInt32Array)
## 遇到尚未实现的操作码或安全指令上限时发出。
signal unsupported_instruction(index: int, operation: int)
## 当前触发脚本结束时发出，`next_entry` 应写回可重复触发入口。
signal script_finished(next_entry: int)
## 脚本要求当前场景刷新时发出；延迟单位保留原版语义。
signal redraw_requested(delay_units: int)
## 开始一轮对话，携带位置、颜色和 RGM 肖像编号。
signal dialog_started(position: int, color: int, portrait: int)
## 输出一条 M.MSG 消息索引。
signal dialog_message(message_index: int)
## 原版脚本要求保留对话上下文并切换页面。
signal dialog_page_break
## 当前对话上下文结束或 VM 被停止。
signal dialog_ended
## 请求音频层切换场景音乐，并携带循环与淡入淡出语义。
signal music_requested(music_number: int, loop: bool, fade_seconds: float)
## 请求播放一次音效。
signal sound_requested(sound_number: int)
## 请求显示一张 FBP 全屏图片；`image_number == 0xffff` 表示原版黑屏过场。
## `fade_seconds` 大于零时，显示层完成渐显后必须调用 `complete_screen_fade()`。
signal fbp_requested(image_number: int, fade_seconds: float)
## 请求屏幕渐隐或渐显；探索控制器完成动画后必须调用 `complete_screen_fade()`。
signal screen_fade_requested(fade_out: bool, duration_seconds: float)
## 请求播放阻塞剧情的 RNG 过场；`end_frame == -1` 表示播放到动画结束。
signal rng_animation_requested(animation_number: int, start_frame: int, end_frame: int, frames_per_second: int)
## 请求打开一场阻塞剧情的经典战斗；`is_boss` 为真时不允许逃跑。
signal battle_requested(enemy_team_id: int, battlefield_id: int, is_boss: bool)
## 请求探索控制器切换到从 0 开始的场景索引。
signal scene_change_requested(scene_index: int)
## PLAYERROLES 场景 Sprite 或队伍成员发生变化。
signal player_sprites_changed
## 脚本驱动队伍完成一个小步，世界层应同步步态。
signal party_step_performed
## 脚本自动行走抵达目标。
signal party_walk_finished
## 剧情镜头相对队伍跟随视口的偏移发生变化；探索渲染器应立即同步。
signal camera_offset_requested(offset: Vector2i)

const MAX_INSTRUCTIONS_PER_RUN := 10000

## 当前 VM 使用的静态脚本和事件数据库。
var database: PalContentDatabase
## 当前 VM 修改的游戏会话；格式测试可不提供。
var session: GameSession
## 是否正在同步解释指令。
var running: bool = false
## 是否等待玩家推进当前对话轮次。
var waiting_for_dialog: bool = false
## 是否等待脚本帧计数归零。
var waiting_for_frames: bool = false
## 是否正在逐帧把队伍移动到脚本目标。
var waiting_for_party_walk: bool = false
## 是否正在逐帧让队伍乘坐当前事件对象移动到脚本目标。
var waiting_for_party_ride: bool = false
## 是否正在等待探索控制器完成阻塞式屏幕渐隐或渐显。
var waiting_for_screen_fade: bool = false
## 是否正在等待剧情 RNG 动画播放完成。
var waiting_for_rng: bool = false
## 是否正在等待战斗覆盖层返回胜负。
var waiting_for_battle: bool = false
## 最近一次条件指令是否成功，供后续分支判断。
var script_success: bool = true
## 本轮 `0081` 是否已把一个面对的事件提升为下一帧接触触发。
## 该状态独立于 `script_success`，因为物品脚本可能先检查多个不匹配对象。
var touch_trigger_armed: bool = false

var _cursor: int = 0
var _event_object_id: int = 0
var _last_event_object_id: int = 0
var _call_stack: Array[Dictionary] = []
var _dialog_has_body: bool = false
var _dialog_is_toast: bool = false
var _frames_remaining: int = 0
var _auto_frame_number: int = 0
var _close_dialog_after_frame_wait: bool = false
var _camera_pan_active: bool = false
var _camera_pan_step: Vector2i = Vector2i.ZERO
var _camera_offset: Vector2i = Vector2i.ZERO
var _next_trigger_entry: int = 0
var _party_walk_target: Vector2i = Vector2i.ZERO
var _party_walk_speed: int = 0
var _party_ride_target: Vector2i = Vector2i.ZERO
var _party_ride_speed: int = 0
var _party_ride_event_id: int = 0
var _scene_map_data: PalMapData
var _reported_auto_instructions: Dictionary = {}
var _current_rng_animation: int = 0
var _battle_defeat_entry: int = 0
var _battle_flee_entry: int = 0
var _equipment_manager := PalEquipmentManager.new()

const BATTLE_RESULT_VICTORY := 1
const BATTLE_RESULT_DEFEAT := 2
const BATTLE_RESULT_FLED := 3


#region Public lifecycle

## 注入内容数据库和可选会话；会话为空时只适合无状态格式测试。
func configure(content_database: PalContentDatabase, game_session: GameSession = null) -> void:
	database = content_database
	session = game_session
	# 新游戏与读档都从空的调用上下文继续；不能沿用读档前最后一次事件目标。
	_last_event_object_id = 0
	_auto_frame_number = 0
	_camera_offset = Vector2i.ZERO
	_camera_pan_active = false
	if session != null and database != null:
		session.initialize_role_state(database.player_roles)
	_equipment_manager.database = database
	_equipment_manager.session = session
	_reported_auto_instructions.clear()


## 设置当前场景的原始 PAL 地图，供追逐类自动脚本检查地图和事件阻挡。
## 只保存只读引用，不修改地图数据；场景切换后应由 MapExplorer 重新调用。
func set_scene_map(map_data: PalMapData) -> void:
	_scene_map_data = map_data


## 从指定脚本入口执行一个触发事件。
## VM 忙碌或入口无效时不修改状态并返回原入口；暂停或结束时返回未来入口。
func run_trigger(entry_index: int, event_object_id: int = 0) -> int:
	if database == null or entry_index <= 0 or entry_index >= database.scripts.size() or running or waiting_for_dialog or waiting_for_screen_fade or waiting_for_rng or waiting_for_battle:
		return entry_index
	if event_object_id == 0xffff:
		event_object_id = _last_event_object_id
	if event_object_id != 0:
		_last_event_object_id = event_object_id
	_call_stack.clear()
	_dialog_has_body = false
	_dialog_is_toast = false
	waiting_for_frames = false
	waiting_for_party_walk = false
	waiting_for_party_ride = false
	waiting_for_screen_fade = false
	waiting_for_rng = false
	waiting_for_battle = false
	_battle_defeat_entry = 0
	_battle_flee_entry = 0
	_frames_remaining = 0
	_close_dialog_after_frame_wait = false
	_camera_pan_active = false
	touch_trigger_armed = false
	_cursor = entry_index
	_next_trigger_entry = entry_index
	_event_object_id = event_object_id
	script_success = true
	running = true
	return _continue_execution()


## 结束当前对话等待并从暂停指令继续执行。
func advance_dialog() -> void:
	if not waiting_for_dialog:
		return
	waiting_for_dialog = false
	_dialog_has_body = false
	running = true
	_continue_execution()


## 通知 VM 当前 RNG 过场已经播放完成，并从下一条脚本继续。
func complete_rng_animation() -> void:
	if not waiting_for_rng:
		return
	waiting_for_rng = false
	running = true
	_continue_execution()


## 通知 VM 屏幕渐隐或渐显已经结束，并从下一条脚本继续。
func complete_screen_fade() -> void:
	if not waiting_for_screen_fade:
		return
	waiting_for_screen_fade = false
	running = true
	_continue_execution()


## 通知 VM 剧情战斗已经结束，并按 `0007` 的战败或逃跑入口恢复脚本。
## 胜利和未配置分支的其他结果继续执行 `0007` 的下一条指令。
func complete_battle(result: int) -> void:
	if not waiting_for_battle:
		return
	waiting_for_battle = false
	if result == BATTLE_RESULT_DEFEAT and _battle_defeat_entry > 0:
		_cursor = _battle_defeat_entry
	elif result == BATTLE_RESULT_FLED and _battle_flee_entry > 0:
		_cursor = _battle_flee_entry
	_battle_defeat_entry = 0
	_battle_flee_entry = 0
	running = true
	_continue_execution()


## 立即清空所有等待、调用栈和对话状态，并发出 `dialog_ended`。
func stop() -> void:
	running = false
	waiting_for_dialog = false
	waiting_for_frames = false
	waiting_for_party_walk = false
	waiting_for_party_ride = false
	waiting_for_screen_fade = false
	waiting_for_rng = false
	waiting_for_battle = false
	_battle_defeat_entry = 0
	_battle_flee_entry = 0
	_dialog_has_body = false
	_dialog_is_toast = false
	_frames_remaining = 0
	_close_dialog_after_frame_wait = false
	_camera_pan_active = false
	touch_trigger_armed = false
	_call_stack.clear()
	dialog_ended.emit()


## 推进一个 10 FPS SDLPal 脚本帧，包括自动脚本、等待和队伍自动行走。
## 返回本帧是否可能改变世界画面。
func tick_frame() -> bool:
	_auto_frame_number += 1
	if waiting_for_screen_fade or waiting_for_rng or waiting_for_battle:
		return false
	# SDLPal pauses scene updates while waiting for a dialog key.
	var world_changed := false if waiting_for_dialog or _close_dialog_after_frame_wait else _tick_auto_scripts()
	if waiting_for_party_walk:
		return _tick_party_walk() or world_changed
	if waiting_for_party_ride:
		return _tick_party_ride() or world_changed
	if not waiting_for_frames:
		return world_changed
	if _camera_pan_active:
		_camera_offset += _camera_pan_step
		camera_offset_requested.emit(_camera_offset)
	_frames_remaining -= 1
	world_changed = true
	if _frames_remaining <= 0:
		waiting_for_frames = false
		_camera_pan_active = false
		if _close_dialog_after_frame_wait:
			_close_dialog_after_frame_wait = false
			_dialog_has_body = false
			_dialog_is_toast = false
			dialog_ended.emit()
		_continue_execution()
	return world_changed

#endregion

#region Instruction interpreter


func _continue_execution() -> int:
	# SDLPal 用脚本表索引而不是字节地址跳转；每条普通指令默认前进一项。
	var executed := 0
	while running and _cursor > 0 and _cursor < database.scripts.size() and executed < MAX_INSTRUCTIONS_PER_RUN:
		var entry := database.scripts[_cursor]
		instruction_started.emit(_cursor, entry.operation, entry.operands)
		var next_cursor := _cursor + 1
		match entry.operation:
			# 停止脚本；触发入口保持在本轮入口，适合可重复事件。
			0x0000:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(_next_trigger_entry)
			# 停止脚本，并把下一条指令保存为事件未来的触发入口。
			0x0001:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(next_cursor)
			# 停止脚本，并把 operand[0] 指定入口保存为未来触发入口。
			0x0002:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				if _return_from_call():
					continue
				return _finish(entry.operands[0])
			# 无条件跳转到 operand[0]。
			0x0003:
				_cursor = entry.operands[0]
				continue
			# 调用子脚本：operand[0] 为入口，operand[1] 为事件编号；0 表示沿用当前事件。
			0x0004:
				_call_stack.append({"cursor": next_cursor, "event_object_id": _event_object_id})
				_cursor = entry.operands[0]
				_event_object_id = _event_object_id if entry.operands[1] == 0 else entry.operands[1]
				continue
			# 清除对话并重绘场景；operand[1] 保留原版重绘延迟单位。
			0x0005:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_ended.emit()
				redraw_requested.emit(entry.operands[1])
			# 启动敌队 operand[0]；战败跳 operand[1]，operand[2] 非零时允许逃跑并作为逃跑入口。
			0x0007:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				_cursor = next_cursor
				_battle_defeat_entry = entry.operands[1]
				_battle_flee_entry = entry.operands[2]
				running = false
				waiting_for_battle = true
				battle_requested.emit(entry.operands[0], session.battlefield_number if session != null else 0, entry.operands[2] == 0)
				return _cursor
			# 将下一条指令设为事件未来入口，但继续执行当前脚本。
			0x0008:
				# Keep running, but make the next instruction the event's future trigger entry.
				_next_trigger_entry = next_cursor
			# 等待 operand[0] 个脚本帧；0 按 1 帧处理。
			0x0009:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_ended.emit()
				return _wait_for_frames(next_cursor, entry.operands[0] if entry.operands[0] > 0 else 1)
			# 触发脚本中的当前 EventObject 向南/西/北/东走一步；乘船等剧情会在重绘之间连续使用。
			0x000b, 0x000c, 0x000d, 0x000e:
				var event := _event_by_id(_event_object_id)
				if event != null:
					event.direction = entry.operation - 0x000b
					_npc_walk_one_step(event, 2)
			# 设置当前事件方向和当前帧；对应 operand[0]/operand[1]，0xFFFF 表示不修改。
			0x000f:
				var event := _event_by_id(_event_object_id)
				if event != null:
					if entry.operands[0] != 0xffff:
						event.direction = entry.operands[0]
					if entry.operands[1] != 0xffff:
						event.current_frame = entry.operands[1]
			# 把 operand[0] 事件放到队伍相对位置，operand[1]/operand[2] 为有符号偏移。
			0x0012:
				var event := _resolve_event(entry.operands[0])
				if event != null and session != null:
					event.position = session.party_world_position() + Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			# 把 operand[0] 事件放到绝对世界坐标 operand[1], operand[2]。
			0x0013:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position = Vector2i(entry.operands[1], entry.operands[2])
			# 设置当前触发事件的动作帧为 operand[0]，并把方向重置为南。
			0x0014:
				var event := _event_by_id(_event_object_id)
				if event != null:
					event.current_frame = entry.operands[0]
					event.direction = GameSession.DIR_SOUTH
			# 设置队员动作：方向 operand[0]、动作 operand[1]、队员索引 operand[2]。
			0x0015:
				if session != null:
					session.set_party_gesture(entry.operands[0], entry.operands[1], entry.operands[2])
			# 设置 operand[0] 事件的方向 operand[1] 和当前帧 operand[2]。
			0x0016:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.direction = entry.operands[1]
					event.current_frame = entry.operands[2]
			# 增减角色体力、真气或两者；operand[0] 非零时作用于全队，否则作用于当前角色。
			# 对齐 SDLPal script.c 的 001B–001D，供场外治疗仙术与剧情物品共用。
			0x001b, 0x001c, 0x001d:
				if session != null:
					var delta := _signed_word(entry.operands[1])
					var hp_delta := delta if entry.operation in [0x001b, 0x001d] else 0
					var mp_delta := delta if entry.operation in [0x001c, 0x001d] else 0
					if entry.operands[0] != 0:
						var changed := false
						for role_index in session.party_roles:
							changed = session.increase_role_hp_mp(role_index, hp_delta, mp_delta) or changed
						# 官方只有全体 001B 会在无人可恢复时把本轮脚本标为失败。
						if entry.operation == 0x001b:
							script_success = changed
					elif not session.increase_role_hp_mp(_event_object_id, hp_delta, mp_delta):
						script_success = false
			# 增减金钱 signed(operand[0])；不足以扣除时跳到 operand[1]。
			0x001e:
				if session != null:
					var cash_delta := _signed_word(entry.operands[0])
					if cash_delta < 0 and session.cash < -cash_delta and entry.operands[1] > 0:
						_cursor = entry.operands[1]
						continue
					session.cash += cash_delta
			# 增加物品 operand[0]；数量为 signed(operand[1])，0 在当前实现按 1 处理。
			0x001f:
				if session != null:
					var amount := _signed_word(entry.operands[1])
					session.change_item_count(entry.operands[0], 1 if amount == 0 else amount)
			# 移除物品 operand[0]×operand[1]；数量不足时跳到 operand[2]。
			0x0020:
				if session != null:
					var amount := entry.operands[1] if entry.operands[1] > 0 else 1
					var total_amount := session.item_count(entry.operands[0]) + session.equipped_item_count(entry.operands[0])
					if total_amount < amount and entry.operands[2] > 0:
						_cursor = entry.operands[2]
						continue
					if not session.equipment_effects_ready:
						_equipment_manager.rebuild_all_effects()
					_equipment_manager.remove_item_including_equipment(entry.operands[0], amount)
			# 按最大 HP 的十分比复活当前角色或全队，并清除三级以下毒与临时状态。
			0x0022:
				if session != null:
					var revived := false
					if entry.operands[0] != 0:
						for role_index in session.party_roles:
							revived = session.revive_role(role_index, entry.operands[1], database) or revived
					else:
						revived = session.revive_role(_event_object_id, entry.operands[1], database)
					script_success = revived
			# 按毒对象或毒等级清除玩家毒状态；供净衣咒等场外仙术使用。
			0x002b:
				if session != null:
					if entry.operands[0] != 0:
						for role_index in session.party_roles:
							session.cure_role_poison(role_index, entry.operands[1])
					else:
						session.cure_role_poison(_event_object_id, entry.operands[1])
			0x002c:
				if session != null:
					if entry.operands[0] != 0:
						for role_index in session.party_roles:
							session.cure_role_poisons_by_level(role_index, entry.operands[1], database)
					else:
						session.cure_role_poisons_by_level(_event_object_id, entry.operands[1], database)
			# 设置或清除当前角色的经典状态；失败语义与官方 PAL_SetPlayerStatus 一致。
			0x002d:
				if session != null and not session.set_role_status(_event_object_id, entry.operands[0], entry.operands[1]):
					script_success = false
			0x002f:
				if session != null:
					session.remove_role_status(_event_object_id, entry.operands[0])
			# 卸下指定角色装备；operand[1] 为 0 时清空六槽，否则使用 1–6 的部位编号。
			0x0023:
				if session != null:
					if not session.equipment_effects_ready and not _equipment_manager.rebuild_all_effects():
						script_success = false
					else:
						_equipment_manager.remove_equipment_from_script(entry.operands[0], entry.operands[1])
			# 把 operand[0] 事件的自动脚本入口改为 operand[1]。
			0x0024:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.auto_script = entry.operands[1]
					event.auto_script_idle_count = 0
			# 把 operand[0] 事件的触发脚本入口改为 operand[1]。
			0x0025:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.trigger_script = entry.operands[1]
			# 开始屏幕中央普通对话；operand[0] 为文字颜色。
			0x003b:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				_dialog_is_toast = _starts_quoted_narration(next_cursor)
				dialog_started.emit(3 if _dialog_is_toast else 2, entry.operands[0], 0)
			# 开始上方肖像对话；operand[0] 为 RGM 肖像，operand[1] 为颜色。
			0x003c:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				_dialog_is_toast = entry.operands[0] == 0 and _starts_quoted_narration(next_cursor)
				dialog_started.emit(3 if _dialog_is_toast else 0, entry.operands[1], 0 if _dialog_is_toast else entry.operands[0])
			# 开始下方肖像对话；operand[0] 为 RGM 肖像，operand[1] 为颜色。
			0x003d:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				_dialog_is_toast = entry.operands[0] == 0 and _starts_quoted_narration(next_cursor)
				dialog_started.emit(3 if _dialog_is_toast else 1, entry.operands[1], 0 if _dialog_is_toast else entry.operands[0])
			# 显示中央窗口文字；本项目用于无角色系统 Toast。
			0x003e:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				_dialog_is_toast = true
				dialog_started.emit(3, entry.operands[0], 0)
			# 队伍乘坐当前事件对象到目标；003F/0044/0097 分别使用低/普通/高速。
			0x003f, 0x0044, 0x0097:
				var ride_event := _event_by_id(_event_object_id)
				if session != null and ride_event != null:
					_party_ride_target = Vector2i(
						entry.operands[0] * 32 + entry.operands[2] * 16,
						entry.operands[1] * 16 + entry.operands[2] * 8
					)
					_party_ride_speed = 2 if entry.operation == 0x003f else (4 if entry.operation == 0x0044 else 8)
					_party_ride_event_id = _event_object_id
					_cursor = next_cursor
					waiting_for_party_ride = true
					return _cursor
			# 选择后续 0037 要播放的 RNG 动画编号。
			0x0036:
				_current_rng_animation = entry.operands[0]
			# 播放当前 RNG 动画；存在播放器时阻塞脚本直到回调完成。
			0x0037:
				var end_frame := entry.operands[1] if entry.operands[1] > 0 else -1
				var frames_per_second := entry.operands[2] if entry.operands[2] > 0 else 16
				if get_signal_connection_list(&"rng_animation_requested").is_empty():
					rng_animation_requested.emit(_current_rng_animation, entry.operands[0], end_frame, frames_per_second)
				else:
					_cursor = next_cursor
					running = false
					waiting_for_rng = true
					rng_animation_requested.emit(_current_rng_animation, entry.operands[0], end_frame, frames_per_second)
					return _cursor
			# 执行当前场景的传送离开脚本；不存在时跳到 operand[0] 失败入口。
			0x0038:
				var teleport_entry := 0
				if session != null and session.scene_index >= 0 and session.scene_index < database.scenes.size():
					teleport_entry = database.scenes[session.scene_index].script_on_teleport
				if teleport_entry <= 0 or teleport_entry >= database.scripts.size():
					script_success = false
					_cursor = entry.operands[0]
					continue
				_call_stack.append({"cursor": next_cursor, "event_object_id": _event_object_id})
				_cursor = teleport_entry
				_event_object_id = _last_event_object_id
				continue
			# 设置 operand[0] 事件的触发模式为 operand[1]。
			0x0040:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.trigger_mode = entry.operands[1]
			# 切换背景音乐为 operand[0]；播放层通过信号完成实际音频切换。
			0x0043:
				if session != null:
					session.music_number = entry.operands[0]
				var loop_music := entry.operands[1] != 1
				var fade_seconds := 3.0 if entry.operands[1] == 3 and entry.operands[0] != 9 else 0.0
				music_requested.emit(entry.operands[0], loop_music, fade_seconds)
			# 设置下一场战斗的音乐编号为 operand[0]。
			0x0045:
				if session != null:
					session.battle_music_number = entry.operands[0]
			# 设置队伍地图位置：operand[0]/[1] 为格坐标，operand[2] 为 half。
			0x0046:
				if session != null:
					var world_x := entry.operands[0] * 32 + entry.operands[2] * 16
					var world_y := entry.operands[1] * 16 + entry.operands[2] * 8
					session.set_party_world_position(Vector2i(world_x, world_y))
			# 播放 operand[0] 音效。
			0x0047:
				sound_requested.emit(entry.operands[0])
			# 设置 operand[0] 事件状态为 signed(operand[1])。
			0x0049:
				var event := _resolve_event(entry.operands[0])
				if event != null and entry.operands[0] != 0:
					event.state = _signed_word(entry.operands[1])
			# 设置下一场战斗使用的战场背景与五灵修正编号。
			0x004a:
				if session != null:
					session.battlefield_number = entry.operands[0]
			# 屏幕渐隐/渐显；默认速度对应官方 PAL_FadeOut/PAL_FadeIn 的约 0.6 秒。
			0x0050, 0x0051:
				# 0051 在官方源码中先把速度转为 SHORT；剧情常用 0xFFFF 表示默认速度，
				# 不能把它当作无符号 65535，否则一次渐显会错误地持续十多个小时。
				var fade_speed := entry.operands[0] if entry.operation == 0x0050 else _signed_word(entry.operands[0])
				var fade_duration := float(fade_speed if fade_speed > 0 else 1) * 0.6
				var fade_out := entry.operation == 0x0050
				if get_signal_connection_list(&"screen_fade_requested").is_empty():
					screen_fade_requested.emit(fade_out, fade_duration)
				else:
					_cursor = next_cursor
					running = false
					waiting_for_screen_fade = true
					screen_fade_requested.emit(fade_out, fade_duration)
					return _cursor
			# 临时隐藏当前触发事件；operand[0] 为帧数，0 使用原版默认 800。
			0x0052:
				var event := _event_by_id(_event_object_id)
				if event != null:
					event.state *= -1
					event.vanish_time = entry.operands[0] if entry.operands[0] > 0 else 800
			# 切换到当前编号的日间调色板。
			0x0053:
				if session != null:
					session.night_palette = false
			# 切换到当前编号的夜间调色板。
			0x0054:
				if session != null:
					session.night_palette = true
			# 为 operand[1] 指定角色加入仙术 operand[0]；角色为 0 时沿用当前调用角色。
			0x0055:
				if session != null:
					var role_index := _event_object_id if entry.operands[1] == 0 else entry.operands[1] - 1
					session.add_magic(role_index, entry.operands[0])
			# 切换到 1-based 的 operand[0] 场景，并在下一安全时机载入。
			0x0059:
				if session != null and entry.operands[0] > 0 and entry.operands[0] <= database.scenes.size():
					_set_camera_offset(Vector2i.ZERO)
					session.scene_index = entry.operands[0] - 1
					session.world_layer = 0
					scene_change_requested.emit(session.scene_index)
			# 将角色 operand[0] 的普通场景 Sprite 改为 operand[1]。
			0x0065:
				if database.player_roles != null and entry.operands[0] < database.player_roles.scene_sprite_numbers.size():
					var role_index := entry.operands[0]
					database.player_roles.scene_sprite_numbers[role_index] = entry.operands[1]
					# SDLPal 会在场景更新时按新 Sprite 恢复站立帧。Godot 版单独保存
					# 剧情动作，因此必须在换装时丢弃旧造型的绝对帧；紧随其后的
					# 0015 若需要新动作，会在同一段脚本中重新设置。
					if session != null:
						session.clear_party_gestures_for_role(role_index)
					player_sprites_changed.emit()
			# 让 operand[0] 事件移动 signed(operand[1]), signed(operand[2]) 并推进步态。
			0x006c:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
					event.current_frame = (event.current_frame + 1) % maxi(1, event.sprite_frames)
			# 修改 1-based 场景的进入/传送脚本；两个新入口都为零时同时清空。
			0x006d:
				var scene_number := entry.operands[0]
				if scene_number > 0 and scene_number <= database.scenes.size():
					var scene := database.scenes[scene_number - 1]
					if entry.operands[1] == 0 and entry.operands[2] == 0:
						scene.script_on_enter = 0
						scene.script_on_teleport = 0
					else:
						if entry.operands[1] != 0:
							scene.script_on_enter = entry.operands[1]
						if entry.operands[2] != 0:
							scene.script_on_teleport = entry.operands[2]
			# 队伍移动一步：operand[0]/[1] 为世界偏移，operand[2]×8 为逻辑层。
			0x006e:
				if session != null:
					var movement := Vector2i(_signed_word(entry.operands[0]), _signed_word(entry.operands[1]))
					session.record_party_step(session.party_direction, movement)
					session.world_layer = entry.operands[2] * 8
					party_step_performed.emit()
			# 若 operand[0] 事件状态等于 signed(operand[1])，同步当前触发事件状态。
			0x006f:
				var invoking_event := _event_by_id(_event_object_id)
				var compared_event := _resolve_event(entry.operands[0])
				var target_state := _signed_word(entry.operands[1])
				if invoking_event != null and compared_event != null and compared_event.state == target_state:
					invoking_event.state = target_state
			# 队伍走到 operand[0]/[1] 格、operand[2] half；0070/007A/007B 速度依次为 2/4/8。
			0x0070, 0x007a, 0x007b:
				if session != null:
					var world_x := entry.operands[0] * 32 + entry.operands[2] * 16
					var world_y := entry.operands[1] * 16 + entry.operands[2] * 8
					var target := Vector2i(world_x, world_y)
					if session.party_world_position() != target:
						_party_walk_target = target
						_party_walk_speed = 2 if entry.operation == 0x0070 else (4 if entry.operation == 0x007a else 8)
						_cursor = next_cursor
						waiting_for_party_walk = true
						return _cursor
			# 将屏幕渐变到新场景；当前保留重绘时序，视觉渐变仍待实现。
			0x0073:
				# The visual fade is still pending; redraw the current scene and preserve script timing.
				redraw_requested.emit(0)
			# 用三个 1-based 角色编号重建队伍，零操作数会被跳过。
			0x0075:
				if session != null:
					session.party_roles = PackedInt32Array()
					for role in entry.operands:
						if role > 0:
							session.party_roles.append(role - 1)
					if session.party_roles.is_empty():
						session.party_roles.append(0)
					session.clear_party_gestures()
					player_sprites_changed.emit()
			# 显示 FBP 全屏图片；0xFFFF 解压失败后按原版得到全黑画面。
			0x0076:
				# PAL_ShowFBP 每个淡入步长等待 `(operand[1] + 1) * 10ms`，
				# 16×6 个子步骤合计约 `(operand[1] + 1) * 0.96s`。
				var fade_seconds := float(entry.operands[1] + 1) * 0.96 if entry.operands[1] > 0 else 0.0
				if fade_seconds > 0.0 and not get_signal_connection_list(&"fbp_requested").is_empty():
					_cursor = next_cursor
					running = false
					waiting_for_screen_fade = true
					fbp_requested.emit(entry.operands[0], fade_seconds)
					return _cursor
				fbp_requested.emit(entry.operands[0], fade_seconds)
			# 停止当前 BGM；operand[0] 为 0 时淡出 2 秒，否则淡出 operand[0]×3 秒。
			0x0077:
				var fade_seconds := 2.0 if entry.operands[0] == 0 else float(entry.operands[0]) * 3.0
				if session != null:
					session.music_number = 0
				music_requested.emit(0, false, fade_seconds)
			# 官方 SDLPal `script.c` 将 0078 保留为空操作；继续下一条而不是误报未支持。
			0x0078:
				pass
			# 直接移动 operand[0] 事件，operand[1]/[2] 为有符号世界偏移。
			0x007d:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			# 设置 operand[0] 事件的逻辑层为 signed(operand[1])。
			0x007e:
				var event := _resolve_event(entry.operands[0])
				if event != null:
					event.layer = _signed_word(entry.operands[1])
			# 平移或复位剧情镜头；队伍世界位置保持不变。
			0x007f:
				if entry.operands[0] == 0 and entry.operands[1] == 0:
					_set_camera_offset(Vector2i.ZERO)
					if entry.operands[2] != 0xffff:
						redraw_requested.emit(0)
				elif entry.operands[2] == 0xffff:
					# 固定镜头以 PAL 格坐标为中心；相对偏移只影响渲染，不改变队伍脚底坐标。
					var target_viewport := Vector2i(entry.operands[0] * 32 - 160, entry.operands[1] * 16 - 112)
					_set_camera_offset(target_viewport - (session.viewport_position if session != null else Vector2i.ZERO))
				else:
					var camera_step := Vector2i(_signed_word(entry.operands[0]), _signed_word(entry.operands[1]))
					return _wait_for_camera_pan(next_cursor, camera_step, maxi(1, _signed_word(entry.operands[2])))
			# 队伍未面向/接近 operand[0] 事件时跳到 operand[2]；operand[1] 为距离级别。
			0x0081:
				if _is_party_facing_event(entry.operands[0], entry.operands[1]):
					if entry.operands[1] > 0:
						touch_trigger_armed = true
				else:
					script_success = false
					_cursor = entry.operands[2]
					continue
			# 恢复场景画面并开启下一页对话，同时保持当前说话人与肖像上下文。
			0x008e:
				if _dialog_has_body:
					return _pause_at_dialog_boundary()
				dialog_page_break.emit()
				redraw_requested.emit(0)
			# 按 signed operand[0] 渐变当前场景；负数渐隐，正数渐显。
			0x0093:
				var step := _signed_word(entry.operands[0])
				if step == 0:
					step = 1
				# PAL_SceneFade 每个调色板步长约 100ms，遍历 64 级亮度。
				var fade_duration := float(ceili(64.0 / absf(float(step)))) * 0.1
				var fade_out := step < 0
				if get_signal_connection_list(&"screen_fade_requested").is_empty():
					screen_fade_requested.emit(fade_out, fade_duration)
				else:
					_cursor = next_cursor
					running = false
					waiting_for_screen_fade = true
					screen_fade_requested.emit(fade_out, fade_duration)
					return _cursor
			# 目标事件状态等于 signed(operand[1]) 时跳到 operand[2]；0 用于立即结束脚本。
			0x0094:
				var compared_event := _resolve_event(entry.operands[0])
				if compared_event != null and compared_event.state == _signed_word(entry.operands[1]):
					_cursor = entry.operands[2]
					continue
			# 将 operand[0] 到 operand[1]（含两端）的 EventObject 状态批量改为 signed(operand[2])。
			0x009a:
				var target_state := _signed_word(entry.operands[2])
				for event_object_id in range(entry.operands[0], entry.operands[1] + 1):
					var event := _event_by_id(event_object_id)
					if event != null:
						event.state = target_state
			# 把所有队员收拢到队长位置，下一次正常移动后恢复跟随编队。
			0x00a1:
				if session != null:
					session.collapse_party_formation()
			# 播放 CD 音轨，桌面移植无 CD 时按官方回退到 operand[1] 的 RIX 曲目。
			0x00a3:
				if session != null:
					session.music_number = entry.operands[1]
				music_requested.emit(entry.operands[1], true, 0.0)
			# 延迟 operand[0]×80ms；10 FPS VM 换算为相应脚本帧数。
			0x0085:
				# SDLPal delays operand × 80 ms; scene scripts advance at 10 FPS here.
				return _wait_for_frames(next_cursor, maxi(1, ceili(entry.operands[0] * 0.8)))
			# 输出 M.MSG 的 operand[0] 消息；连续正文会合并成同一轮对话。
			0xffff:
				dialog_message.emit(entry.operands[0])
				_cursor = next_cursor
				if not _is_dialog_title(database.get_message(entry.operands[0])):
					_dialog_has_body = true
					if _dialog_is_toast and not _is_dialog_message_entry(next_cursor):
						return _wait_for_frames(next_cursor, 14, true)
				executed += 1
				continue
			_:
				unsupported_instruction.emit(_cursor, entry.operation)
				return _finish(_cursor)
		_cursor = next_cursor
		executed += 1

	if executed >= MAX_INSTRUCTIONS_PER_RUN:
		unsupported_instruction.emit(_cursor, -1)
	return _finish(_cursor)

#endregion

#region Wait states and helpers


func _return_from_call() -> bool:
	if _call_stack.is_empty():
		return false
	var frame: Dictionary = _call_stack.pop_back()
	_cursor = int(frame["cursor"])
	_event_object_id = int(frame["event_object_id"])
	return true


func _finish(next_entry: int) -> int:
	running = false
	waiting_for_dialog = false
	waiting_for_frames = false
	waiting_for_party_walk = false
	waiting_for_party_ride = false
	waiting_for_screen_fade = false
	waiting_for_rng = false
	waiting_for_battle = false
	_battle_defeat_entry = 0
	_battle_flee_entry = 0
	_dialog_has_body = false
	_dialog_is_toast = false
	_frames_remaining = 0
	_close_dialog_after_frame_wait = false
	_camera_pan_active = false
	dialog_ended.emit()
	script_finished.emit(next_entry)
	return next_entry


func _pause_at_dialog_boundary() -> int:
	running = false
	waiting_for_dialog = true
	return _cursor


func _starts_quoted_narration(entry_index: int) -> bool:
	if not _is_dialog_message_entry(entry_index):
		return false
	return database.is_quoted_narration_start(database.scripts[entry_index].operands[0])


func _is_dialog_message_entry(entry_index: int) -> bool:
	return database != null and entry_index > 0 and entry_index < database.scripts.size() and database.scripts[entry_index].operation == 0xffff


func _tick_party_walk() -> bool:
	if not waiting_for_party_walk or session == null:
		return false
	var offset := _party_walk_target - session.party_world_position()
	if offset == Vector2i.ZERO:
		waiting_for_party_walk = false
		party_walk_finished.emit()
		_continue_execution()
		return false
	var direction: int
	if offset.y < 0:
		direction = GameSession.DIR_WEST if offset.x < 0 else GameSession.DIR_NORTH
	else:
		direction = GameSession.DIR_SOUTH if offset.x < 0 else GameSession.DIR_EAST
	var movement := Vector2i(
		offset.x if absi(offset.x) <= _party_walk_speed * 2 else _party_walk_speed * (-2 if offset.x < 0 else 2),
		offset.y if absi(offset.y) <= _party_walk_speed else _party_walk_speed * (-1 if offset.y < 0 else 1)
	)
	session.record_party_step(direction, movement)
	party_step_performed.emit()
	if session.party_world_position() == _party_walk_target:
		waiting_for_party_walk = false
		party_walk_finished.emit()
		_continue_execution()
	return true


func _tick_party_ride() -> bool:
	if not waiting_for_party_ride or session == null:
		return false
	var event := _event_by_id(_party_ride_event_id)
	if event == null:
		waiting_for_party_ride = false
		_continue_execution()
		return false
	var offset := _party_ride_target - session.party_world_position()
	if offset == Vector2i.ZERO:
		waiting_for_party_ride = false
		_party_ride_event_id = 0
		_continue_execution()
		return false
	var direction: int
	if offset.y < 0:
		direction = GameSession.DIR_WEST if offset.x < 0 else GameSession.DIR_NORTH
	else:
		direction = GameSession.DIR_SOUTH if offset.x < 0 else GameSession.DIR_EAST
	var movement := Vector2i(
		offset.x if absi(offset.x) <= _party_ride_speed * 2 else _party_ride_speed * (-2 if offset.x < 0 else 2),
		offset.y if absi(offset.y) <= _party_ride_speed else _party_ride_speed * (-1 if offset.y < 0 else 1)
	)
	# 对齐 SDLPal `PAL_PartyRideEventObject`：轨迹记录新位置，队伍固定动作不被普通步态清除。
	if session.trail_positions.size() != GameSession.TRAIL_SIZE or session.trail_directions.size() != GameSession.TRAIL_SIZE:
		session.set_party_world_position(session.party_world_position())
	for index in range(GameSession.TRAIL_SIZE - 1, 0, -1):
		session.trail_positions[index] = session.trail_positions[index - 1]
		session.trail_directions[index] = session.trail_directions[index - 1]
	session.party_direction = direction
	session.viewport_position += movement
	session.trail_positions[0] = session.party_world_position()
	session.trail_directions[0] = direction
	event.position += movement
	if session.party_world_position() == _party_ride_target:
		waiting_for_party_ride = false
		_party_ride_event_id = 0
		_continue_execution()
	return true


func _wait_for_frames(next_cursor: int, frame_count: int, close_dialog_after_wait: bool = false) -> int:
	_cursor = next_cursor
	_frames_remaining = maxi(1, frame_count)
	waiting_for_frames = true
	_close_dialog_after_frame_wait = close_dialog_after_wait
	_camera_pan_active = false
	return _cursor


func _wait_for_camera_pan(next_cursor: int, step: Vector2i, frame_count: int) -> int:
	_cursor = next_cursor
	_frames_remaining = maxi(1, frame_count)
	waiting_for_frames = true
	_close_dialog_after_frame_wait = false
	_camera_pan_step = step
	_camera_pan_active = true
	return _cursor


func _set_camera_offset(offset: Vector2i) -> void:
	_camera_offset = offset
	camera_offset_requested.emit(_camera_offset)


func _event_by_id(event_object_id: int) -> PalEventObject:
	if database == null or event_object_id <= 0 or event_object_id > database.event_objects.size():
		return null
	return database.event_objects[event_object_id - 1]


func _resolve_event(operand: int) -> PalEventObject:
	return _event_by_id(_event_object_id if operand == 0 or operand == 0xffff else operand)


func _is_party_facing_event(event_object_id: int, range: int) -> bool:
	if session == null or database == null or range < 0:
		return false
	var event := _event_by_id(event_object_id)
	if event == null or event.state <= 0:
		return false
	var is_in_current_scene := false
	for scene_event in database.events_for_scene(session.scene_index):
		if scene_event.object_id == event_object_id:
			is_in_current_scene = true
			break
	if not is_in_current_scene:
		return false
	var facing_position := event.position
	facing_position.x += 16 if session.party_direction in [GameSession.DIR_WEST, GameSession.DIR_SOUTH] else -16
	facing_position.y += 8 if session.party_direction in [GameSession.DIR_WEST, GameSession.DIR_NORTH] else -8
	var offset := facing_position - session.party_world_position()
	if absi(offset.x) + absi(offset.y) * 2 >= range * 32 + 16:
		return false
	if range > 0:
		event.trigger_mode = PalEventObject.TRIGGER_TOUCH_NEAR + range
	return true


func _tick_auto_scripts() -> bool:
	if database == null or session == null or session.scene_index < 0 or session.scene_index >= database.scenes.size():
		return false
	var changed := false
	for event in database.events_for_scene(session.scene_index):
		changed = _update_event_lifecycle(event) or changed
		if event.is_visible() and event.auto_script > 0:
			changed = _run_auto_script_step(event) or changed
	return changed


func _run_auto_script_step(event: PalEventObject, jump_budget: int = 64) -> bool:
	if event.auto_script <= 0 or event.auto_script >= database.scripts.size():
		return false
	if jump_budget <= 0:
		_report_unsupported_auto(event.auto_script, database.scripts[event.auto_script].operation)
		return false
	var entry := database.scripts[event.auto_script]
	match entry.operation:
		# 自动脚本停在当前入口；下一帧仍可重复检查。
		0x0000:
			return false
		# 自动脚本改用下一条入口并结束本帧。
		0x0001:
			event.auto_script += 1
			return false
		# 停止并替换入口；operand[1] 次后才允许进入下一条。
		0x0002:
			if entry.operands[1] == 0 or event.auto_script_idle_count + 1 < entry.operands[1]:
				event.auto_script_idle_count += 1
				event.auto_script = entry.operands[0]
			else:
				event.auto_script_idle_count = 0
				event.auto_script += 1
			return false
		# 无条件跳转；官方 `goto begin` 会在同一脚本帧继续执行目标指令。
		0x0003:
			if entry.operands[1] == 0 or event.auto_script_idle_count + 1 < entry.operands[1]:
				event.auto_script_idle_count += 1
				event.auto_script = entry.operands[0]
				return _run_auto_script_step(event, jump_budget - 1)
			event.auto_script_idle_count = 0
			event.auto_script += 1
			return false
		# 同步调用 operand[0] 子脚本；自动脚本不能在这里进入对话等待。
		0x0004:
			_run_instant_trigger_script(entry.operands[0], entry.operands[1] if entry.operands[1] > 0 else event.object_id)
			event.auto_script += 1
			return true
		# 按官方概率语义跳转；命中且目标非零时同帧继续目标指令。
		0x0006:
			if randi_range(1, 100) >= entry.operands[0]:
				if entry.operands[1] > 0:
					event.auto_script = entry.operands[1]
					return _run_auto_script_step(event, jump_budget - 1)
				return false
			event.auto_script += 1
			return false
		# 自动脚本等待 operand[0] 帧。
		0x0009:
			event.auto_script_idle_count += 1
			if event.auto_script_idle_count >= maxi(1, entry.operands[0]):
				event.auto_script_idle_count = 0
				event.auto_script += 1
			return false
		# NPC 向南/西/北/东走一步，方向由操作码 000B–000E 决定。
		0x000b, 0x000c, 0x000d, 0x000e:
			event.direction = entry.operation - 0x000b
			_npc_walk_one_step(event, 2)
			event.auto_script += 1
			return true
		# 设置当前自动事件方向和当前帧，0xFFFF 表示不修改。
		0x000f:
			if entry.operands[0] != 0xffff:
				event.direction = entry.operands[0]
			if entry.operands[1] != 0xffff:
				event.current_frame = entry.operands[1]
			event.auto_script += 1
			return true
		# NPC 以速度 3 走到 operand[0]/[1] 格、operand[2] half；未到达则停在本入口。
		0x0010:
			var reached := _npc_walk_to(event, entry.operands[0], entry.operands[1], entry.operands[2], 3)
			if reached:
				event.auto_script += 1
			return true
		# NPC 以隔帧速度 2 走到目标；对象编号奇偶用于错开更新。
		0x0011:
			if ((event.object_id & 1) ^ (_auto_frame_number & 1)) != 0:
				var reached := _npc_walk_to(event, entry.operands[0], entry.operands[1], entry.operands[2], 2)
				if reached:
					event.auto_script += 1
				return true
			return false
		# 设置当前自动事件动作帧，并按官方规则重置为朝南。
		0x0014:
			event.current_frame = entry.operands[0]
			event.direction = GameSession.DIR_SOUTH
			event.auto_script += 1
			return true
		# 设置队员脚本动作；自动脚本下一帧继续。
		0x0015:
			if session != null:
				session.set_party_gesture(entry.operands[0], entry.operands[1], entry.operands[2])
			event.auto_script += 1
			return session != null
		# 设置指定事件方向和动作帧。
		0x0016:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null and entry.operands[0] != 0:
				target.direction = entry.operands[1]
				target.current_frame = entry.operands[2]
			event.auto_script += 1
			return target != null
		# 修改目标事件的自动脚本入口。
		0x0024:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null and entry.operands[0] != 0:
				target.auto_script = entry.operands[1]
				target.auto_script_idle_count = 0
			event.auto_script += 1
			return false
		# 修改目标事件的触发脚本入口。
		0x0025:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null and entry.operands[0] != 0:
				target.trigger_script = entry.operands[1]
			event.auto_script += 1
			return false
		# 修改目标事件的触发模式。
		0x0040:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null and entry.operands[0] != 0:
				target.trigger_mode = entry.operands[1]
			event.auto_script += 1
			return false
		# 播放剧情指定的 VOC 音效。
		0x0047:
			sound_requested.emit(entry.operands[0])
			event.auto_script += 1
			return false
		# 修改目标事件状态。
		0x0049:
			if entry.operands[0] != 0:
				var target := _resolve_auto_event(entry.operands[0], event)
				if target != null:
					target.state = _signed_word(entry.operands[1])
			event.auto_script += 1
			return true
		# 让当前事件暂时消失 15 帧，正计时到零后自动重现。
		0x004b:
			event.vanish_time = -15
			event.auto_script += 1
			return true
		# 按范围和速度追逐队伍；operand[2] 非零时忽略阻挡。
		0x004c:
			_monster_chase_player(event, entry.operands[1] if entry.operands[1] > 0 else 4, entry.operands[0] if entry.operands[0] > 0 else 8, entry.operands[2] != 0)
			event.auto_script += 1
			return true
		# 临时隐藏当前事件；计时结束后等事件离开视口再恢复正状态。
		0x0052:
			event.state *= -1
			event.vanish_time = entry.operands[0] if entry.operands[0] > 0 else 800
			event.auto_script += 1
			return true
		# 当比较事件达到指定状态时，同步当前自动事件状态。
		0x006f:
			var compared_event := _resolve_auto_event(entry.operands[0], event)
			var target_state := _signed_word(entry.operands[1])
			if compared_event != null and compared_event.state == target_state:
				event.state = target_state
			event.auto_script += 1
			return true
		# 移动目标事件并推进一帧 NPC 动画。
		0x006c:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null:
				target.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
				_advance_npc_frame(target)
			event.auto_script += 1
			return target != null
		# NPC 隔帧以速度 4 走到目标；用于普通场景路线。
		0x007c:
			if ((event.object_id & 1) ^ (_auto_frame_number & 1)) != 0:
				var reached := _npc_walk_to(event, entry.operands[0], entry.operands[1], entry.operands[2], 4)
				if reached:
					event.auto_script += 1
				return true
			return false
		# 直接移动指定事件，不推进动作帧。
		0x007d:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null:
				target.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			event.auto_script += 1
			return target != null
		# 设置指定事件的逻辑层。
		0x007e:
			var target := _resolve_auto_event(entry.operands[0], event)
			if target != null:
				target.layer = _signed_word(entry.operands[1])
			event.auto_script += 1
			return target != null
		# NPC 以速度 8 走到目标；到达前保持当前入口。
		0x0082:
			if _npc_walk_to(event, entry.operands[0], entry.operands[1], entry.operands[2], 8):
				event.auto_script += 1
			return true
		# 目标事件不在当前场景或离当前事件过远时跳到 operand[2]。
		0x0083:
			var target := _event_by_id(entry.operands[0])
			if target == null or not _event_is_in_current_scene(entry.operands[0]) or _event_distance(target, event) >= entry.operands[1] * 32 + 16:
				event.auto_script = entry.operands[2]
			else:
				event.auto_script += 1
			return false
		# 只推进当前事件动画，不改变位置。
		0x0087:
			_advance_npc_frame(event)
			event.auto_script += 1
			return true
		# DOS 自动说明文字与新版占位指令只推进入口，不阻塞探索场景。
		0xffff, 0x00a7:
			event.auto_script += 1
			return false
	_report_unsupported_auto(event.auto_script, entry.operation)
	return false


func _update_event_lifecycle(event: PalEventObject) -> bool:
	var was_visible := event.is_visible()
	if event.vanish_time != 0:
		event.vanish_time += 1 if event.vanish_time < 0 else -1
	elif event.state < 0 and _event_outside_reactivation_area(event):
		# SDLPal 避免隐藏对象在镜头内突然弹回；离开 320×320 检查区后才恢复。
		event.state = absi(event.state)
		event.current_frame = 0
	return was_visible != event.is_visible()


func _event_outside_reactivation_area(event: PalEventObject) -> bool:
	if session == null:
		return false
	var viewport := session.viewport_position
	return event.position.x < viewport.x or event.position.x > viewport.x + 320 or event.position.y < viewport.y or event.position.y > viewport.y + 320


func _event_is_in_current_scene(event_object_id: int) -> bool:
	if database == null or session == null:
		return false
	for scene_event in database.events_for_scene(session.scene_index):
		if scene_event.object_id == event_object_id:
			return true
	return false


func _event_distance(first: PalEventObject, second: PalEventObject) -> int:
	return PalMapCoordinates.weighted_distance(first.position, second.position)


func _monster_chase_player(event: PalEventObject, speed: int, chase_range: int, floating: bool) -> void:
	if session == null:
		return
	var offset := session.party_world_position() - event.position
	if absi(offset.x) + absi(offset.y) * 2 < chase_range * 32:
		if offset.y < 0:
			event.direction = GameSession.DIR_WEST if offset.x < 0 else GameSession.DIR_NORTH
		else:
			event.direction = GameSession.DIR_SOUTH if offset.x < 0 else GameSession.DIR_EAST
		var candidate := event.position + GameSession.movement_for_direction(event.direction)
		_npc_walk_one_step(event, speed if floating or not _npc_position_blocked(candidate, event.object_id) else 0)
	else:
		# 官方即使没有进入追逐范围，也会用零速度推进怪物原地动画。
		_npc_walk_one_step(event, 0)


func _npc_position_blocked(world_position: Vector2i, moving_event_id: int) -> bool:
	if _scene_map_data != null and _scene_map_data.is_valid():
		var tile := PalMapCoordinates.world_to_tile(world_position)
		if not PalMapCoordinates.is_valid_tile(tile):
			return true
		if PalMapData.is_blocked(_scene_map_data.tile_value(tile.x, tile.y, tile.z)):
			return true
	for other in database.events_for_scene(session.scene_index):
		if other.object_id == moving_event_id or not other.blocks_movement():
			continue
		if PalMapCoordinates.positions_collide(other.position, world_position):
			return true
	return false


func _report_unsupported_auto(index: int, operation: int) -> void:
	var key := "%d:%d" % [index, operation]
	if _reported_auto_instructions.has(key):
		return
	_reported_auto_instructions[key] = true
	unsupported_instruction.emit(index, operation)


func _run_instant_trigger_script(entry_index: int, event_object_id: int) -> bool:
	var cursor := entry_index
	var current_event_object_id := event_object_id
	var stack: Array[Dictionary] = []
	var executed := 0
	while cursor > 0 and cursor < database.scripts.size() and executed < 256:
		var entry := database.scripts[cursor]
		var next_cursor := cursor + 1
		# 即时子脚本只接受不会暂停 UI 的安全操作码；含义与主解释器相同。
		match entry.operation:
			# 结束当前即时调用；有调用栈时返回上层。
			0x0000, 0x0001:
				if stack.is_empty():
					return true
				var frame: Dictionary = stack.pop_back()
				cursor = int(frame["cursor"])
				current_event_object_id = int(frame["event_object_id"])
				continue
			# 无条件跳转。
			0x0003:
				cursor = entry.operands[0]
				continue
			# 调用另一个即时脚本，并可切换当前事件编号。
			0x0004:
				stack.append({"cursor": next_cursor, "event_object_id": current_event_object_id})
				cursor = entry.operands[0]
				if entry.operands[1] > 0:
					current_event_object_id = entry.operands[1]
				continue
			# 设置当前事件方向/帧。
			0x000f:
				var target := _event_by_id(current_event_object_id)
				if target != null:
					if entry.operands[0] != 0xffff:
						target.direction = entry.operands[0]
					if entry.operands[1] != 0xffff:
						target.current_frame = entry.operands[1]
			# 设置目标事件绝对位置。
			0x0013:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null:
					target.position = Vector2i(entry.operands[1], entry.operands[2])
			# 设置当前事件动作并朝南。
			0x0014:
				var target := _event_by_id(current_event_object_id)
				if target != null:
					target.current_frame = entry.operands[0]
					target.direction = GameSession.DIR_SOUTH
			# 设置目标事件方向和帧。
			0x0016:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null and entry.operands[0] != 0:
					target.direction = entry.operands[1]
					target.current_frame = entry.operands[2]
			# 设置目标事件自动脚本入口，并清空旧等待计数。
			0x0024:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null and entry.operands[0] != 0:
					target.auto_script = entry.operands[1]
					target.auto_script_idle_count = 0
			# 设置目标事件触发脚本入口。
			0x0025:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null and entry.operands[0] != 0:
					target.trigger_script = entry.operands[1]
			# 设置目标事件触发模式。
			0x0040:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null and entry.operands[0] != 0:
					target.trigger_mode = entry.operands[1]
			# 设置目标事件状态。
			0x0049:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null and entry.operands[0] != 0:
					target.state = _signed_word(entry.operands[1])
			# 播放不会阻塞自动脚本的剧情音效。
			0x0047:
				sound_requested.emit(entry.operands[0])
			# 直接移动目标事件。
			0x007d:
				var target := _instant_target_event(entry.operands[0], current_event_object_id)
				if target != null:
					target.position += Vector2i(_signed_word(entry.operands[1]), _signed_word(entry.operands[2]))
			_:
				_report_unsupported_auto(cursor, entry.operation)
				return false
		cursor = next_cursor
		executed += 1
	return false


func _instant_target_event(operand: int, current_event_object_id: int) -> PalEventObject:
	return _event_by_id(current_event_object_id if operand == 0 or operand == 0xffff else operand)


func _resolve_auto_event(operand: int, invoking_event: PalEventObject) -> PalEventObject:
	return invoking_event if operand == 0 or operand == 0xffff else _event_by_id(operand)


func _npc_walk_to(event: PalEventObject, tile_x: int, tile_y: int, half: int, speed: int) -> bool:
	var target := Vector2i(tile_x * 32 + half * 16, tile_y * 16 + half * 8)
	var offset := target - event.position
	if offset.y < 0:
		event.direction = GameSession.DIR_WEST if offset.x < 0 else GameSession.DIR_NORTH
	else:
		event.direction = GameSession.DIR_SOUTH if offset.x < 0 else GameSession.DIR_EAST
	if absi(offset.x) < speed * 2 or absi(offset.y) < speed * 2:
		event.position = target
	else:
		_npc_walk_one_step(event, speed)
	if event.position == target:
		event.current_frame = 0
		return true
	return false


func _npc_walk_one_step(event: PalEventObject, speed: int) -> void:
	var x_sign := -1 if event.direction in [GameSession.DIR_WEST, GameSession.DIR_SOUTH] else 1
	var y_sign := -1 if event.direction in [GameSession.DIR_WEST, GameSession.DIR_NORTH] else 1
	event.position += Vector2i(x_sign * 2 * speed, y_sign * speed)
	_advance_npc_frame(event)


func _advance_npc_frame(event: PalEventObject) -> void:
	var frame_count := 4 if event.sprite_frames == 3 else event.sprite_frames
	if frame_count <= 0:
		frame_count = event.sprite_frames_auto
	if frame_count > 0:
		event.current_frame = (event.current_frame + 1) % frame_count


static func _signed_word(value: int) -> int:
	return value - 0x10000 if value >= 0x8000 else value


static func _is_dialog_title(text: String) -> bool:
	var content := text.strip_edges()
	return content.ends_with(":") or content.ends_with("：") or content.ends_with("∶")

#endregion
