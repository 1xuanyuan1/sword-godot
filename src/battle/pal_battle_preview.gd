# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal battle.c, fight.c and uibattle.c classic paths.
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典战斗的 Godot 画面与输入编排器，绘制原版战场并播放双方物理攻击动画。
## 回合数值由 `PalBattleController` 持有，经典状态框、指令和仙术列表由 `PalBattleUI` 绘制。
class_name PalBattlePreview
extends Control

## 剧情模式下玩家确认胜负结果时发出；值使用 `PalBattleController.BattleResult`。
signal battle_finished(result: int)

enum InputMode {
	COMMAND,
	ENEMY_TARGET,
	MAGIC_LIST,
	WAITING,
	RESULT,
}

const PLAYER_POSITIONS: Array = [
	[Vector2i(240, 170)],
	[Vector2i(200, 176), Vector2i(256, 152)],
	[Vector2i(180, 180), Vector2i(234, 170), Vector2i(270, 146)],
]
const BATTLE_FRAME_SECONDS := 0.04

## 为真时作为资源实验室独立样板运行；剧情覆盖层应在加入场景树前设为 `false`。
@export var lab_mode: bool = true
## 最近一次载入或启动战斗失败原因。
var error_message: String = ""

var _database: PalContentDatabase
var _session: GameSession
var _controller: PalBattleController
var _background: TextureRect
var _fighter_root: Node2D
var _battle_ui: PalBattleUI
var _error_label: Label
var _enemy_team_id: int = 18
var _battlefield_id: int = 21
var _party_roles: PackedInt32Array = PackedInt32Array([0, 1])
var _enemy_nodes: Array[Sprite2D] = []
var _player_nodes: Array[Sprite2D] = []
var _enemy_sprites: Array[PalSprite] = []
var _player_sprites: Array[PalSprite] = []
var _enemy_foot_positions: Array[Vector2i] = []
var _player_foot_positions: Array[Vector2i] = []
var _enemy_current_frames: PackedInt32Array = PackedInt32Array()
var _player_current_frames: PackedInt32Array = PackedInt32Array()
var _palette: PackedByteArray = PackedByteArray()
var _fighter_texture_cache: Dictionary = {}
var _selected_enemy_index: int = 0
var _selected_action: int = 0
var _input_mode: InputMode = InputMode.WAITING
var _action_timer: float = 0.0
var _animation_in_progress: bool = false
var _last_enemy_flash_phase: int = -1


func _ready() -> void:
	_build_interface()
	if not lab_mode:
		hide()
		return
	_database = PalContentDatabase.new()
	if not _database.load_generated():
		_show_error("战斗资源不可用：%s" % _database.error_message)
		return
	load_battle(_enemy_team_id, _battlefield_id, _party_roles)


func _process(delta: float) -> void:
	if not visible or _controller == null:
		return
	if not _animation_in_progress:
		_refresh_enemy_target_flash()
	if _controller.battle_result != PalBattleController.BattleResult.ONGOING or _controller.is_accepting_commands() or _animation_in_progress:
		return
	_action_timer -= delta
	if _action_timer <= 0.0:
		_execute_next_action()


## 加载一个敌队、战场和最多三人的队伍，创建全新的临时会话并立即重绘。
## 任一核心资源缺失时返回 `false`；样板会话不会修改探索场景的正式进度。
func load_battle(enemy_team_id: int, battlefield_id: int, party_roles: PackedInt32Array) -> bool:
	var preview_session := GameSession.new()
	preview_session.party_roles = party_roles.slice(0, mini(3, party_roles.size()))
	return _start_battle_view(_database, preview_session, enemy_team_id, battlefield_id)


## 使用探索场景现有数据库和会话打开剧情战斗；玩家 HP 会由控制器直接写回该会话。
## 失败时返回 `false` 并显示具体原因，不自行伪造胜负。
func begin_battle(content_database: PalContentDatabase, game_session: GameSession, enemy_team_id: int, battlefield_id: int) -> bool:
	_database = content_database
	_session = game_session
	show()
	return _start_battle_view(content_database, game_session, enemy_team_id, battlefield_id)


func _start_battle_view(content_database: PalContentDatabase, game_session: GameSession, enemy_team_id: int, battlefield_id: int) -> bool:
	_database = content_database
	_session = game_session
	error_message = ""
	_error_label.hide()
	var party_roles := game_session.party_roles if game_session != null else PackedInt32Array()
	if _database == null or party_roles.is_empty():
		_show_error("战斗缺少内容数据库、会话或队伍")
		return false
	var team := _database.enemy_team_definition(enemy_team_id)
	var battlefield := _database.battlefield_definition(battlefield_id)
	var background := _database.load_battle_background(battlefield_id)
	if team == null or battlefield == null or not background.is_valid():
		_show_error("敌队 %d 或战场 %d 不可用，请重新导入 Data" % [enemy_team_id, battlefield_id])
		return false
	var active_enemies := team.active_object_ids()
	if active_enemies.is_empty():
		_show_error("敌队 %d 没有有效敌人" % enemy_team_id)
		return false
	_enemy_team_id = enemy_team_id
	_battlefield_id = battlefield_id
	_party_roles = party_roles.slice(0, mini(3, party_roles.size()))
	_clear_fighters()
	_palette = _database.load_palette(_session.palette_index, _session.night_palette)
	_fighter_texture_cache.clear()
	_background.texture = _texture_for_indexed(background, _palette)
	for enemy_index in range(active_enemies.size()):
		var object_id := active_enemies[enemy_index]
		var enemy := _database.enemy_definition_for_object(object_id)
		if enemy == null:
			continue
		var sprite := _database.load_enemy_battle_sprite(enemy.enemy_id)
		var foot := _database.enemy_positions.position_for(enemy_index, active_enemies.size())
		foot.y += enemy.y_position_offset
		_enemy_sprites.append(sprite)
		_enemy_foot_positions.append(foot)
		_enemy_current_frames.append(0)
		_enemy_nodes.append(_add_fighter(sprite, foot, "Enemy%d" % enemy_index))
	var configured_positions: Array = PLAYER_POSITIONS[_party_roles.size() - 1]
	for party_index in range(_party_roles.size()):
		var role_index := _party_roles[party_index]
		var sprite_number := _database.player_roles.battle_sprite_for(role_index)
		var sprite := _database.load_player_battle_sprite(sprite_number)
		var foot: Vector2i = configured_positions[party_index]
		_player_sprites.append(sprite)
		_player_foot_positions.append(foot)
		_player_current_frames.append(0)
		_player_nodes.append(_add_fighter(sprite, foot, "Player%d" % party_index))
	_controller = PalBattleController.new()
	if not _controller.start_battle(_database, _session, enemy_team_id, battlefield_id):
		_show_error("无法开始战斗：%s" % _controller.error_message)
		return false
	_battle_ui.configure(_database, _session, _controller, _player_foot_positions)
	_selected_enemy_index = _controller.living_enemy_indices()[0]
	_selected_action = 0
	_action_timer = 0.0
	_animation_in_progress = false
	_enter_command_mode()
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var handled := true
	match event.keycode:
		KEY_ESCAPE:
			_cancel_or_leave()
		KEY_UP:
			_handle_direction(Vector2i(0, -1))
		KEY_DOWN:
			_handle_direction(Vector2i(0, 1))
		KEY_LEFT:
			_handle_direction(Vector2i(-1, 0))
		KEY_RIGHT:
			_handle_direction(Vector2i(1, 0))
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_confirm_current_selection()
		KEY_D:
			if _input_mode == InputMode.COMMAND:
				_submit_defend()
		KEY_BRACKETLEFT:
			if lab_mode and not _animation_in_progress:
				_load_nearest_team(-1)
		KEY_BRACKETRIGHT:
			if lab_mode and not _animation_in_progress:
				_load_nearest_team(1)
		KEY_PAGEUP:
			if lab_mode and not _animation_in_progress:
				_load_nearest_battlefield(1)
		KEY_PAGEDOWN:
			if lab_mode and not _animation_in_progress:
				_load_nearest_battlefield(-1)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_background)
	_fighter_root = Node2D.new()
	_fighter_root.name = "Fighters"
	add_child(_fighter_root)
	_battle_ui = PalBattleUI.new()
	_battle_ui.name = "ClassicBattleUI"
	_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battle_ui)
	_error_label = Label.new()
	_error_label.position = Vector2(8, 82)
	_error_label.size = Vector2(304, 36)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_font_size_override("font_size", 8)
	_error_label.add_theme_color_override("font_color", Color.WHITE)
	_error_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_error_label.add_theme_constant_override("shadow_offset_x", 1)
	_error_label.add_theme_constant_override("shadow_offset_y", 1)
	_error_label.hide()
	add_child(_error_label)


func _add_fighter(sprite: PalSprite, foot_position: Vector2i, node_name: String) -> Sprite2D:
	if sprite == null or not sprite.is_valid() or sprite.frame_count() <= 0:
		return null
	var fighter := Sprite2D.new()
	fighter.name = node_name
	fighter.centered = false
	fighter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fighter_root.add_child(fighter)
	_apply_fighter_frame(fighter, sprite, foot_position, 0, 0)
	return fighter


func _apply_fighter_frame(node: Sprite2D, sprite: PalSprite, foot: Vector2i, frame_index: int, color_shift: int) -> void:
	if node == null or sprite == null or not sprite.is_valid() or sprite.frame_count() <= 0:
		return
	var frame := clampi(frame_index, 0, sprite.frame_count() - 1)
	var indexed := RleDecoder.decode(sprite.get_frame(frame))
	if not indexed.is_valid():
		return
	node.texture = _texture_for_sprite_frame(sprite, frame, color_shift)
	node.position = Vector2(foot.x - indexed.width / 2.0, foot.y - indexed.height)
	node.z_index = foot.y


func _texture_for_sprite_frame(sprite: PalSprite, frame_index: int, color_shift: int) -> Texture2D:
	var cache_key := "%d:%d:%d" % [sprite.get_instance_id(), frame_index, color_shift]
	if _fighter_texture_cache.has(cache_key):
		return _fighter_texture_cache[cache_key]
	var indexed := RleDecoder.decode(sprite.get_frame(frame_index))
	if color_shift != 0 and indexed.is_valid():
		indexed = _shift_indexed_image(indexed, color_shift)
	var texture := _texture_for_indexed(indexed, _palette)
	_fighter_texture_cache[cache_key] = texture
	return texture


func _shift_indexed_image(source: PalIndexedImage, shift: int) -> PalIndexedImage:
	var result := PalIndexedImage.new()
	result.width = source.width
	result.height = source.height
	result.indices = source.indices.duplicate()
	result.opacity = source.opacity.duplicate()
	# PAL_RLEBlitWithColorShift 只移动调色板索引低四位，高四位色系保持不变。
	for index in range(result.indices.size()):
		if result.opacity[index] == 0:
			continue
		var palette_index := result.indices[index]
		result.indices[index] = (palette_index & 0xf0) | clampi((palette_index & 0x0f) + shift, 0, 15)
	return result


func _texture_for_indexed(indexed: PalIndexedImage, palette: PackedByteArray) -> Texture2D:
	if indexed == null or not indexed.is_valid() or palette.size() < PaletteDecoder.PALETTE_BYTES:
		return null
	return ImageTexture.create_from_image(indexed.to_rgba_image(palette))


func _clear_fighters() -> void:
	for child in _fighter_root.get_children():
		child.free()
	_enemy_nodes.clear()
	_player_nodes.clear()
	_enemy_sprites.clear()
	_player_sprites.clear()
	_enemy_foot_positions.clear()
	_player_foot_positions.clear()
	_enemy_current_frames.clear()
	_player_current_frames.clear()
	_last_enemy_flash_phase = -1


func _handle_direction(direction: Vector2i) -> void:
	match _input_mode:
		InputMode.COMMAND:
			if direction.y < 0:
				_set_action_selection(0)
			elif direction.x < 0 and _pending_role_has_magics():
				_set_action_selection(1)
			elif direction.x > 0:
				# 合击合法性依赖队伍、状态和合击仙术；尚未接入前保持官方不可用色。
				_set_action_selection(0)
			elif direction.y > 0:
				_set_action_selection(3)
		InputMode.ENEMY_TARGET:
			_select_enemy(-1 if direction.x < 0 or direction.y > 0 else 1)
		InputMode.MAGIC_LIST:
			_battle_ui.move_magic_selection(direction.x, direction.y)


func _set_action_selection(action_index: int) -> void:
	_selected_action = action_index
	_battle_ui.set_action_selection(action_index)


func _select_enemy(step: int) -> void:
	if _controller == null or _input_mode != InputMode.ENEMY_TARGET:
		return
	var living := _controller.living_enemy_indices()
	if living.is_empty():
		return
	var current := living.find(_selected_enemy_index)
	_selected_enemy_index = living[posmod(current + step if current >= 0 else 0, living.size())]
	_battle_ui.set_enemy_selection(_selected_enemy_index)
	_last_enemy_flash_phase = -1
	_refresh_enemy_target_flash(true)


func _confirm_current_selection() -> void:
	if _controller == null or _animation_in_progress:
		return
	if _input_mode == InputMode.RESULT:
		_confirm_battle_result()
		return
	if not _controller.is_accepting_commands():
		return
	match _input_mode:
		InputMode.COMMAND:
			match _selected_action:
				0:
					_begin_enemy_target_selection()
				1:
					_battle_ui.open_magic_list(_controller.pending_role_index())
					_input_mode = InputMode.MAGIC_LIST
				3:
					_battle_ui.show_message("其他指令正在接入", 1000)
		InputMode.ENEMY_TARGET:
			_submit_attack()
		InputMode.MAGIC_LIST:
			if _battle_ui.selected_magic_enabled():
				# 此阶段只接入真实名称、消耗和可用状态，避免用普通攻击冒充仙术结算。
				_battle_ui.show_message("仙术结算与特效正在接入", 1200)


func _begin_enemy_target_selection() -> void:
	var living := _controller.living_enemy_indices()
	if living.is_empty():
		return
	_selected_enemy_index = living[0] if _selected_enemy_index not in living else _selected_enemy_index
	# 经典模式只剩一个目标时无需多按一次确认键。
	if living.size() == 1:
		_submit_attack()
		return
	_input_mode = InputMode.ENEMY_TARGET
	_battle_ui.set_mode(PalBattleUI.Mode.ENEMY_TARGET)
	_battle_ui.set_enemy_selection(_selected_enemy_index)
	_last_enemy_flash_phase = -1
	_refresh_enemy_target_flash(true)


func _submit_attack() -> void:
	if not _controller.submit_attack(_selected_enemy_index):
		return
	_reset_enemy_highlight()
	_after_command_submitted()


func _submit_defend() -> void:
	if _controller == null or not _controller.submit_defend():
		return
	_reset_enemy_highlight()
	_after_command_submitted()


func _after_command_submitted() -> void:
	_battle_ui.clear_message()
	_select_first_living_enemy()
	if _controller.is_accepting_commands():
		_enter_command_mode()
	else:
		_input_mode = InputMode.WAITING
		_battle_ui.set_mode(PalBattleUI.Mode.WAITING)
		_action_timer = 0.12


func _enter_command_mode() -> void:
	_input_mode = InputMode.COMMAND
	_selected_action = 0
	_battle_ui.set_action_selection(0)
	_battle_ui.set_enemy_selection(_selected_enemy_index)
	_battle_ui.set_mode(PalBattleUI.Mode.COMMAND)
	_battle_ui.clear_message()
	_reset_enemy_highlight()


func _cancel_or_leave() -> void:
	if _animation_in_progress:
		return
	if _input_mode in [InputMode.ENEMY_TARGET, InputMode.MAGIC_LIST]:
		_enter_command_mode()
	elif lab_mode:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _confirm_battle_result() -> void:
	if lab_mode:
		load_battle(_enemy_team_id, _battlefield_id, _party_roles)
	else:
		var result := _controller.battle_result
		hide()
		battle_finished.emit(result)


func _execute_next_action() -> void:
	if _animation_in_progress:
		return
	var result := _controller.execute_next_action()
	if result == null:
		return
	_animation_in_progress = true
	_input_mode = InputMode.WAITING
	_battle_ui.set_mode(PalBattleUI.Mode.WAITING)
	await _play_action_result(result)
	_animation_in_progress = false
	_select_first_living_enemy()
	if _controller.battle_result != PalBattleController.BattleResult.ONGOING:
		_input_mode = InputMode.RESULT
		_battle_ui.set_mode(PalBattleUI.Mode.RESULT)
		_battle_ui.show_message("战斗胜利" if _controller.battle_result == PalBattleController.BattleResult.VICTORY else "全队倒下")
	elif _controller.is_accepting_commands():
		_enter_command_mode()
	else:
		_action_timer = 0.16


func _play_action_result(result: PalBattleController.ActionResult) -> void:
	if result.skipped:
		await _wait_frames(2)
		return
	if result.unsupported:
		_battle_ui.show_message(result.summary, 800)
		await _wait_frames(6)
		return
	if result.action_type == PalBattleController.ActionType.DEFEND and not result.actor_is_enemy:
		_set_player_frame(result.actor_index, 3)
		await _wait_frames(4)
		_set_player_frame(result.actor_index, _resting_player_frame(result.actor_index))
		return
	if result.actor_is_enemy:
		await _play_enemy_attack(result)
	else:
		await _play_player_attack(result)


func _play_player_attack(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	var target_foot := Vector2i(150, 100)
	if not result.hits.is_empty() and result.hits[0].target_index >= 0 and result.hits[0].target_index < _enemy_foot_positions.size():
		target_foot = _enemy_foot_positions[result.hits[0].target_index]
	_set_player_frame(actor_index, 7, original_foot)
	await _wait_frames(4)
	var attack_foot := target_foot + Vector2i(64, 20)
	await _move_player(actor_index, attack_foot, 8, BATTLE_FRAME_SECONDS * 2.0)
	attack_foot -= Vector2i(10, 2)
	await _move_player(actor_index, attack_foot, 8, BATTLE_FRAME_SECONDS)
	_set_player_frame(actor_index, 9, attack_foot)
	await _wait_frames(1)
	for hit in result.hits:
		if hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
			continue
		_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 6)
		var foot := _enemy_foot_positions[hit.target_index]
		_battle_ui.show_number(hit.damage, Vector2i(foot.x - 9, maxi(10, foot.y - 115)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
	await _wait_frames(3)
	for hit in result.hits:
		if hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
			continue
		if hit.defeated:
			_enemy_nodes[hit.target_index].hide()
		else:
			_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 0)
	await _move_player(actor_index, original_foot, 8, BATTLE_FRAME_SECONDS * 3.0)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(2)


func _play_enemy_attack(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _enemy_nodes.size() or result.hits.is_empty():
		return
	var actor_index := result.actor_index
	var hit := result.hits[0]
	if hit.target_index < 0 or hit.target_index >= _player_nodes.size():
		return
	var definition := _controller.enemies[actor_index].definition
	var original_foot := _enemy_foot_positions[actor_index]
	for frame_offset in range(definition.magic_frames):
		_set_enemy_frame(actor_index, definition.idle_frames + frame_offset)
		await _wait_frames(2)
	var target_foot := _player_foot_positions[hit.target_index]
	var attack_foot := target_foot - Vector2i(44, 16)
	var first_attack_frame := maxi(0, definition.idle_frames + definition.magic_frames - 1)
	await _move_enemy(actor_index, attack_foot, first_attack_frame, BATTLE_FRAME_SECONDS * 2.0)
	var attack_frame_count := maxi(1, definition.attack_frames + 1)
	for frame_offset in range(attack_frame_count):
		var frame := definition.idle_frames + definition.magic_frames + frame_offset - 1
		_set_enemy_frame(actor_index, frame, 0, attack_foot)
		await _wait_frames(maxi(1, definition.action_wait_frames))
	var target_frame := 3 if hit.auto_defended else 4
	_set_player_frame(hit.target_index, target_frame, target_foot, 0 if hit.auto_defended else 6)
	if hit.damage > 0:
		_battle_ui.show_number(hit.damage, Vector2i(target_foot.x - 9, maxi(10, target_foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
	await _wait_frames(1)
	_set_player_frame(hit.target_index, target_frame, target_foot + Vector2i(8, 4))
	await _wait_frames(3)
	await _move_enemy(actor_index, original_foot, 0, BATTLE_FRAME_SECONDS * 2.0)
	_set_enemy_frame(actor_index, 0, 0, original_foot)
	_set_player_frame(hit.target_index, _resting_player_frame(hit.target_index), target_foot)
	await _wait_frames(4)


func _move_player(player_index: int, target_foot: Vector2i, frame_index: int, duration: float) -> void:
	if player_index < 0 or player_index >= _player_nodes.size() or _player_nodes[player_index] == null:
		return
	var node := _player_nodes[player_index]
	_set_player_frame(player_index, frame_index, _foot_for_node(node, _player_sprites[player_index], _player_current_frames[player_index]))
	var target_position := _top_left_for_frame(_player_sprites[player_index], frame_index, target_foot)
	var tween := create_tween()
	tween.tween_property(node, "position", target_position, duration)
	await tween.finished
	node.z_index = target_foot.y


func _move_enemy(enemy_index: int, target_foot: Vector2i, frame_index: int, duration: float) -> void:
	if enemy_index < 0 or enemy_index >= _enemy_nodes.size() or _enemy_nodes[enemy_index] == null:
		return
	var node := _enemy_nodes[enemy_index]
	_set_enemy_frame(enemy_index, frame_index, 0, _foot_for_node(node, _enemy_sprites[enemy_index], _enemy_current_frames[enemy_index]))
	var target_position := _top_left_for_frame(_enemy_sprites[enemy_index], frame_index, target_foot)
	var tween := create_tween()
	tween.tween_property(node, "position", target_position, duration)
	await tween.finished
	node.z_index = target_foot.y


func _foot_for_node(node: Sprite2D, sprite: PalSprite, frame_index: int) -> Vector2i:
	var frame := clampi(frame_index, 0, sprite.frame_count() - 1)
	var indexed := RleDecoder.decode(sprite.get_frame(frame))
	return Vector2i(roundi(node.position.x + indexed.width / 2.0), roundi(node.position.y + indexed.height))


func _top_left_for_frame(sprite: PalSprite, frame_index: int, foot: Vector2i) -> Vector2:
	var frame := clampi(frame_index, 0, sprite.frame_count() - 1)
	var indexed := RleDecoder.decode(sprite.get_frame(frame))
	return Vector2(foot.x - indexed.width / 2.0, foot.y - indexed.height)


func _set_player_frame(player_index: int, frame_index: int, foot: Vector2i = Vector2i(-9999, -9999), color_shift: int = 0) -> void:
	if player_index < 0 or player_index >= _player_nodes.size() or _player_nodes[player_index] == null:
		return
	var frame := clampi(frame_index, 0, _player_sprites[player_index].frame_count() - 1)
	_player_current_frames[player_index] = frame
	var resolved_foot := _player_foot_positions[player_index] if foot.x == -9999 else foot
	_apply_fighter_frame(_player_nodes[player_index], _player_sprites[player_index], resolved_foot, frame, color_shift)


func _set_enemy_frame(enemy_index: int, frame_index: int, color_shift: int = 0, foot: Vector2i = Vector2i(-9999, -9999)) -> void:
	if enemy_index < 0 or enemy_index >= _enemy_nodes.size() or _enemy_nodes[enemy_index] == null:
		return
	var frame := clampi(frame_index, 0, _enemy_sprites[enemy_index].frame_count() - 1)
	_enemy_current_frames[enemy_index] = frame
	var resolved_foot := _enemy_foot_positions[enemy_index] if foot.x == -9999 else foot
	_apply_fighter_frame(_enemy_nodes[enemy_index], _enemy_sprites[enemy_index], resolved_foot, frame, color_shift)


func _resting_player_frame(player_index: int) -> int:
	if player_index < 0 or player_index >= _controller.players.size():
		return 0
	var role_index := _controller.players[player_index].role_index
	if role_index < 0 or role_index >= _session.role_hp.size():
		return 0
	if _session.role_hp[role_index] <= 0:
		return 2
	if _session.role_hp[role_index] < mini(100, _session.role_max_hp[role_index] / 5):
		return 1
	return 0


func _wait_frames(frame_count: int) -> void:
	await get_tree().create_timer(maxi(1, frame_count) * BATTLE_FRAME_SECONDS).timeout


func _refresh_enemy_target_flash(force: bool = false) -> void:
	var flash_phase := int(Time.get_ticks_msec() / 100) % 2 if _input_mode == InputMode.ENEMY_TARGET else 0
	if not force and flash_phase == _last_enemy_flash_phase:
		return
	_last_enemy_flash_phase = flash_phase
	for enemy_index in range(_enemy_nodes.size()):
		if _enemy_nodes[enemy_index] == null or not _enemy_nodes[enemy_index].visible:
			continue
		var shift := 7 if _input_mode == InputMode.ENEMY_TARGET and enemy_index == _selected_enemy_index and flash_phase == 1 else 0
		_set_enemy_frame(enemy_index, _enemy_current_frames[enemy_index], shift)


func _reset_enemy_highlight() -> void:
	if _animation_in_progress:
		return
	_last_enemy_flash_phase = -1
	for enemy_index in range(_enemy_nodes.size()):
		if _enemy_nodes[enemy_index] != null and _enemy_nodes[enemy_index].visible:
			_set_enemy_frame(enemy_index, _enemy_current_frames[enemy_index], 0)


func _select_first_living_enemy() -> void:
	if _controller == null:
		return
	var living := _controller.living_enemy_indices()
	if not living.is_empty() and _selected_enemy_index not in living:
		_selected_enemy_index = living[0]
	_battle_ui.set_enemy_selection(_selected_enemy_index)


func _pending_role_has_magics() -> bool:
	if _controller == null or _session == null:
		return false
	var role_index := _controller.pending_role_index()
	return role_index >= 0 and role_index < _session.learned_magics_by_role.size() and not _session.learned_magics_by_role[role_index].is_empty()


func _show_error(message: String) -> void:
	error_message = message
	_error_label.text = message
	_error_label.show()


func _load_nearest_team(step: int) -> void:
	if _database == null or _database.enemy_teams.is_empty():
		return
	var candidate := _enemy_team_id
	for _attempt in range(_database.enemy_teams.size()):
		candidate = posmod(candidate + step, _database.enemy_teams.size())
		var team := _database.enemy_team_definition(candidate)
		if team != null and not team.active_object_ids().is_empty():
			load_battle(candidate, _battlefield_id, _party_roles)
			return


func _load_nearest_battlefield(step: int) -> void:
	if _database == null or _database.battlefields.is_empty():
		return
	var candidate := posmod(_battlefield_id + step, _database.battlefields.size())
	load_battle(_enemy_team_id, candidate, _party_roles)
