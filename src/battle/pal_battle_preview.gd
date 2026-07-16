# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal battle.c PAL_LoadBattleSprites.
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典战斗资源与普攻回合的可操作样板，绘制原版战场和战斗 Sprite。
## 指令、行动队列和体力结算交给 `PalBattleController`，本节点只处理输入与视觉反馈。
class_name PalBattlePreview
extends Control

const PLAYER_POSITIONS: Array = [
	[Vector2i(240, 170)],
	[Vector2i(200, 176), Vector2i(256, 152)],
	[Vector2i(180, 180), Vector2i(234, 170), Vector2i(270, 146)],
]

var _database: PalContentDatabase
var _session: GameSession
var _controller: PalBattleController
var _background: TextureRect
var _fighter_root: Node2D
var _status: Label
var _party_status: Label
var _target_cursor: Polygon2D
var _enemy_team_id: int = 18
var _battlefield_id: int = 21
var _party_roles: PackedInt32Array = PackedInt32Array([0, 1])
var _enemy_nodes: Array[Sprite2D] = []
var _player_nodes: Array[Sprite2D] = []
var _enemy_foot_positions: Array[Vector2i] = []
var _selected_enemy_index: int = 0
var _action_timer: float = 0.0
var _last_action_text: String = ""


func _ready() -> void:
	_build_interface()
	_database = PalContentDatabase.new()
	if not _database.load_generated():
		_status.text = "战斗资源不可用：%s｜Esc 返回" % _database.error_message
		return
	load_battle(_enemy_team_id, _battlefield_id, _party_roles)


func _process(delta: float) -> void:
	if _controller == null or _controller.battle_result != PalBattleController.BattleResult.ONGOING or _controller.is_accepting_commands():
		return
	_action_timer -= delta
	if _action_timer <= 0.0:
		_execute_next_action()


## 加载一个敌队、战场和最多三人的队伍，创建全新的临时会话并立即重绘。
## 任一核心资源缺失时返回 `false`；样板会话不会修改探索场景的正式进度。
func load_battle(enemy_team_id: int, battlefield_id: int, party_roles: PackedInt32Array) -> bool:
	if _database == null or party_roles.is_empty():
		return false
	var team := _database.enemy_team_definition(enemy_team_id)
	var battlefield := _database.battlefield_definition(battlefield_id)
	var background := _database.load_battle_background(battlefield_id)
	if team == null or battlefield == null or not background.is_valid():
		_status.text = "敌队 %d 或战场 %d 不可用，请重新导入 Data｜Esc 返回" % [enemy_team_id, battlefield_id]
		return false
	var active_enemies := team.active_object_ids()
	if active_enemies.is_empty():
		_status.text = "敌队 %d 没有有效敌人｜方向键切换｜Esc 返回" % enemy_team_id
		return false
	_enemy_team_id = enemy_team_id
	_battlefield_id = battlefield_id
	_party_roles = party_roles.slice(0, mini(3, party_roles.size()))
	_clear_fighters()
	_enemy_nodes.clear()
	_player_nodes.clear()
	_enemy_foot_positions.clear()
	var palette := _database.load_palette(0, false)
	_background.texture = _texture_for_indexed(background, palette)
	for enemy_index in range(active_enemies.size()):
		var object_id := active_enemies[enemy_index]
		var enemy := _database.enemy_definition_for_object(object_id)
		if enemy == null:
			continue
		var sprite := _database.load_enemy_battle_sprite(enemy.enemy_id)
		var position := _database.enemy_positions.position_for(enemy_index, active_enemies.size())
		position.y += enemy.y_position_offset
		_enemy_nodes.append(_add_fighter(sprite, position, palette, "Enemy%d" % enemy_index))
		_enemy_foot_positions.append(position)
	var player_positions: Array = PLAYER_POSITIONS[_party_roles.size() - 1]
	for party_index in range(_party_roles.size()):
		var role_index := _party_roles[party_index]
		var sprite_number := _database.player_roles.battle_sprite_for(role_index)
		_player_nodes.append(_add_fighter(_database.load_player_battle_sprite(sprite_number), player_positions[party_index], palette, "Player%d" % party_index))
	_session = GameSession.new()
	_session.party_roles = _party_roles.duplicate()
	_controller = PalBattleController.new()
	if not _controller.start_battle(_database, _session, enemy_team_id, battlefield_id):
		_status.text = "无法开始战斗：%s｜Esc 返回" % _controller.error_message
		return false
	_selected_enemy_index = _controller.living_enemy_indices()[0]
	_action_timer = 0.0
	_last_action_text = ""
	_refresh_battle_ui()
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		KEY_LEFT:
			_select_enemy(-1)
		KEY_RIGHT:
			_select_enemy(1)
		KEY_SPACE, KEY_ENTER:
			_confirm_attack_or_restart()
		KEY_D:
			_submit_defend()
		KEY_BRACKETLEFT:
			_load_nearest_team(-1)
		KEY_BRACKETRIGHT:
			_load_nearest_team(1)
		KEY_PAGEUP:
			_load_nearest_battlefield(1)
		KEY_PAGEDOWN:
			_load_nearest_battlefield(-1)


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
	var status_background := ColorRect.new()
	status_background.position = Vector2(0, 0)
	status_background.size = Vector2(320, 25)
	status_background.color = Color(0, 0, 0, 0.82)
	add_child(status_background)
	_status = Label.new()
	_status.position = Vector2(3, 2)
	_status.size = Vector2(314, 21)
	_status.add_theme_font_size_override("font_size", 7)
	_status.add_theme_color_override("font_color", Color.WHITE)
	add_child(_status)
	var party_background := ColorRect.new()
	party_background.position = Vector2(0, 184)
	party_background.size = Vector2(320, 16)
	party_background.color = Color(0, 0, 0, 0.82)
	add_child(party_background)
	_party_status = Label.new()
	_party_status.position = Vector2(3, 185)
	_party_status.size = Vector2(314, 13)
	_party_status.add_theme_font_size_override("font_size", 7)
	_party_status.add_theme_color_override("font_color", Color.WHITE)
	add_child(_party_status)
	_target_cursor = Polygon2D.new()
	_target_cursor.polygon = PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(4, 5)])
	_target_cursor.color = Color(1.0, 0.9, 0.2)
	_target_cursor.z_index = 1000
	add_child(_target_cursor)


func _add_fighter(sprite: PalSprite, foot_position: Vector2i, palette: PackedByteArray, node_name: String) -> Sprite2D:
	if sprite == null or not sprite.is_valid() or sprite.frame_count() <= 0:
		return null
	var frame := RleDecoder.decode(sprite.get_frame(0))
	if not frame.is_valid():
		return null
	var fighter := Sprite2D.new()
	fighter.name = node_name
	fighter.centered = false
	fighter.position = Vector2(foot_position.x - frame.width / 2.0, foot_position.y - frame.height)
	fighter.texture = _texture_for_indexed(frame, palette)
	fighter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fighter.z_index = foot_position.y
	_fighter_root.add_child(fighter)
	return fighter


func _texture_for_indexed(indexed: PalIndexedImage, palette: PackedByteArray) -> Texture2D:
	if indexed == null or not indexed.is_valid() or palette.size() < PaletteDecoder.PALETTE_BYTES:
		return null
	return ImageTexture.create_from_image(indexed.to_rgba_image(palette))


func _clear_fighters() -> void:
	for child in _fighter_root.get_children():
		child.free()


func _select_enemy(step: int) -> void:
	if _controller == null or not _controller.is_accepting_commands():
		return
	var living := _controller.living_enemy_indices()
	if living.is_empty():
		return
	var current := living.find(_selected_enemy_index)
	_selected_enemy_index = living[posmod(current + step if current >= 0 else 0, living.size())]
	_refresh_battle_ui()


func _confirm_attack_or_restart() -> void:
	if _controller == null:
		return
	if _controller.battle_result != PalBattleController.BattleResult.ONGOING:
		load_battle(_enemy_team_id, _battlefield_id, _party_roles)
		return
	if not _controller.is_accepting_commands() or not _controller.submit_attack(_selected_enemy_index):
		return
	_last_action_text = ""
	_action_timer = 0.15
	_select_first_living_enemy()
	_refresh_battle_ui()


func _submit_defend() -> void:
	if _controller == null or not _controller.submit_defend():
		return
	_last_action_text = ""
	_action_timer = 0.15
	_select_first_living_enemy()
	_refresh_battle_ui()


func _execute_next_action() -> void:
	var result := _controller.execute_next_action()
	if result == null:
		return
	_last_action_text = result.summary
	for hit in result.hits:
		var nodes: Array[Sprite2D] = _enemy_nodes if hit.target_is_enemy else _player_nodes
		if hit.target_index < 0 or hit.target_index >= nodes.size() or nodes[hit.target_index] == null:
			continue
		var node := nodes[hit.target_index]
		if hit.defeated:
			node.visible = false
		elif hit.damage > 0:
			node.modulate = Color(1.0, 0.35, 0.35)
			var tween := create_tween()
			tween.tween_property(node, "modulate", Color.WHITE, 0.18)
	_select_first_living_enemy()
	_refresh_battle_ui()
	_action_timer = 0.45


func _select_first_living_enemy() -> void:
	if _controller == null:
		return
	var living := _controller.living_enemy_indices()
	if living.is_empty():
		return
	if _selected_enemy_index not in living:
		_selected_enemy_index = living[0]


func _refresh_battle_ui() -> void:
	if _controller == null:
		_target_cursor.visible = false
		return
	var result_text := ""
	match _controller.battle_result:
		PalBattleController.BattleResult.VICTORY:
			result_text = "战斗胜利！空格重新开始"
		PalBattleController.BattleResult.DEFEAT:
			result_text = "全队倒下。空格重新开始"
		_:
			if _controller.is_accepting_commands():
				var role_index := _controller.pending_role_index()
				result_text = "%s：左右选敌　空格攻击　D防御" % _role_name(role_index)
			else:
				result_text = "第%d回合行动中……" % _controller.turn_number
	var detail_text := _last_action_text
	if detail_text.is_empty() and _selected_enemy_index >= 0 and _selected_enemy_index < _controller.enemies.size():
		var target := _controller.enemies[_selected_enemy_index]
		detail_text = "目标 HP %d/%d" % [target.hp, target.max_hp]
	_status.text = "战场%d 敌队%d｜%s\n%s" % [_battlefield_id, _enemy_team_id, result_text, detail_text]
	var party_parts: Array[String] = []
	for player in _controller.players:
		party_parts.append("%s HP %d/%d" % [
			_role_name(player.role_index),
			_session.role_hp[player.role_index],
			_session.role_max_hp[player.role_index],
		])
	_party_status.text = "　".join(party_parts)
	_target_cursor.visible = _controller.is_accepting_commands() and _selected_enemy_index >= 0 and _selected_enemy_index < _enemy_foot_positions.size()
	if _target_cursor.visible:
		var foot := _enemy_foot_positions[_selected_enemy_index]
		_target_cursor.position = Vector2(foot.x - 4, foot.y - 60)


func _role_name(role_index: int) -> String:
	if role_index < 0:
		return ""
	var name := _database.get_word(_database.player_roles.name_word_for(role_index))
	return name if not name.is_empty() else "角色%d" % role_index


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
