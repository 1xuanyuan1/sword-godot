# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal battle.c PAL_LoadBattleSprites.
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典战斗数据与站位的可视化样板，直接绘制本地导入的原版战场和战斗 Sprite。
## 当前只负责验证静态资源；回合状态与输入控制会由后续 BattleController 接管。
class_name PalBattlePreview
extends Control

const PLAYER_POSITIONS: Array = [
	[Vector2i(240, 170)],
	[Vector2i(200, 176), Vector2i(256, 152)],
	[Vector2i(180, 180), Vector2i(234, 170), Vector2i(270, 146)],
]

var _database: PalContentDatabase
var _background: TextureRect
var _fighter_root: Node2D
var _status: Label
var _enemy_team_id: int = 18
var _battlefield_id: int = 21
var _party_roles: PackedInt32Array = PackedInt32Array([0, 1])


func _ready() -> void:
	_build_interface()
	_database = PalContentDatabase.new()
	if not _database.load_generated():
		_status.text = "战斗资源不可用：%s｜Esc 返回" % _database.error_message
		return
	load_battle(_enemy_team_id, _battlefield_id, _party_roles)


## 加载一个敌队、战场和最多三人的队伍并立即重绘；任一核心资源缺失时返回 `false`。
## 此方法不修改 `GameSession`，可安全用于开发检查和后续战斗进入前的资源预检。
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
	var palette := _database.load_palette(0, false)
	_background.texture = _texture_for_indexed(background, palette)
	var enemy_labels: Array[String] = []
	for enemy_index in range(active_enemies.size()):
		var object_id := active_enemies[enemy_index]
		var enemy := _database.enemy_definition_for_object(object_id)
		if enemy == null:
			continue
		var sprite := _database.load_enemy_battle_sprite(enemy.enemy_id)
		var position := _database.enemy_positions.position_for(enemy_index, active_enemies.size())
		position.y += enemy.y_position_offset
		_add_fighter(sprite, position, palette, "Enemy%d" % enemy_index)
		enemy_labels.append("%d->%d HP%d" % [object_id, enemy.enemy_id, enemy.health])
	var player_positions: Array = PLAYER_POSITIONS[_party_roles.size() - 1]
	for party_index in range(_party_roles.size()):
		var role_index := _party_roles[party_index]
		var sprite_number := _database.player_roles.battle_sprite_for(role_index)
		_add_fighter(_database.load_player_battle_sprite(sprite_number), player_positions[party_index], palette, "Player%d" % party_index)
	_status.text = "战场%d | 敌队%d: %s | 方向键切换 Esc返回" % [battlefield_id, enemy_team_id, " / ".join(enemy_labels)]
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		KEY_LEFT:
			_load_nearest_team(-1)
		KEY_RIGHT:
			_load_nearest_team(1)
		KEY_UP:
			_load_nearest_battlefield(1)
		KEY_DOWN:
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
	status_background.size = Vector2(320, 14)
	status_background.color = Color(0, 0, 0, 0.82)
	add_child(status_background)
	_status = Label.new()
	_status.position = Vector2(3, 2)
	_status.size = Vector2(314, 12)
	_status.add_theme_font_size_override("font_size", 7)
	_status.add_theme_color_override("font_color", Color.WHITE)
	add_child(_status)


func _add_fighter(sprite: PalSprite, foot_position: Vector2i, palette: PackedByteArray, node_name: String) -> void:
	if sprite == null or not sprite.is_valid() or sprite.frame_count() <= 0:
		return
	var frame := RleDecoder.decode(sprite.get_frame(0))
	if not frame.is_valid():
		return
	var fighter := Sprite2D.new()
	fighter.name = node_name
	fighter.centered = false
	fighter.position = Vector2(foot_position.x - frame.width / 2.0, foot_position.y - frame.height)
	fighter.texture = _texture_for_indexed(frame, palette)
	fighter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fighter.z_index = foot_position.y
	_fighter_root.add_child(fighter)


func _texture_for_indexed(indexed: PalIndexedImage, palette: PackedByteArray) -> Texture2D:
	if indexed == null or not indexed.is_valid() or palette.size() < PaletteDecoder.PALETTE_BYTES:
		return null
	return ImageTexture.create_from_image(indexed.to_rgba_image(palette))


func _clear_fighters() -> void:
	for child in _fighter_root.get_children():
		child.free()


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
