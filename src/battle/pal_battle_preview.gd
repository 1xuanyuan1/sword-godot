# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal battle.c, fight.c and uibattle.c classic paths.
# SPDX-License-Identifier: GPL-3.0-or-later
## 经典战斗的 Godot 画面与输入编排器，绘制原版战场并播放双方物理和仙术动画。
## 回合/成长数值由 `PalBattleController` 持有，经典状态框、指令、仙术和结算页由 `PalBattleUI` 绘制。
class_name PalBattlePreview
extends Control

## 剧情模式下玩家确认胜负结果时发出；值使用 `PalBattleController.BattleResult`。
signal battle_finished(result: int)

enum InputMode {
	COMMAND,
	ENEMY_TARGET,
	PLAYER_TARGET,
	MAGIC_LIST,
	MISC_MENU,
	ITEM_ACTION,
	ITEM_LIST,
	WAITING,
	REWARD,
	RESULT,
}

const PLAYER_POSITIONS: Array = [
	[Vector2i(240, 170)],
	[Vector2i(200, 176), Vector2i(256, 152)],
	[Vector2i(180, 180), Vector2i(234, 170), Vector2i(270, 146)],
]
const COOPERATIVE_POSITIONS: Array[Vector2i] = [Vector2i(208, 157), Vector2i(234, 170), Vector2i(260, 183)]
const BATTLE_FRAME_SECONDS := 0.04
const DEFAULT_LAB_BATTLE_MUSIC := 37

## 为真时作为资源实验室独立样板运行；剧情覆盖层应在加入场景树前设为 `false`。
@export var lab_mode: bool = true
## 最近一次载入或启动战斗失败原因。
var error_message: String = ""

var _database: PalContentDatabase
var _session: GameSession
var _controller: PalBattleController
var _background: TextureRect
var _persistent_effect_root: Node2D
var _fighter_root: Node2D
var _magic_root: Node2D
var _battle_ui: PalBattleUI
var _summon_node: Sprite2D
var _script_dialog_box: PalDialogBox
var _error_label: Label
var _enemy_team_id: int = 18
var _battlefield_id: int = 21
var _is_boss: bool = false
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
var _selected_party_index: int = 0
var _selected_action: int = 0
var _pending_magic_object_id: int = 0
var _pending_cooperative_magic: bool = false
var _pending_item_object_id: int = 0
var _pending_item_throwable: bool = false
var _input_mode: InputMode = InputMode.WAITING
var _action_timer: float = 0.0
var _animation_in_progress: bool = false
var _last_enemy_flash_phase: int = -1
var _pending_blow_displacement: int = 0
var _script_dialog_waiting: bool = false
var _script_dialog_advance_requested: bool = false
var _audio_player: PalAudioPlayer


func _ready() -> void:
	_build_interface()
	if not lab_mode:
		hide()
		return
	_audio_player = PalAudioPlayer.new()
	_audio_player.name = "BattleLabAudio"
	add_child(_audio_player)
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
	if (_controller.battle_result != PalBattleController.BattleResult.ONGOING and not _controller.has_pending_script_results()) or _controller.is_accepting_commands() or _animation_in_progress:
		return
	_action_timer -= delta
	if _action_timer <= 0.0:
		_execute_next_action()


## 加载一个敌队、战场和最多三人的队伍，创建全新的临时会话并立即重绘。
## 任一核心资源缺失时返回 `false`；样板会话不会修改探索场景的正式进度。
func load_battle(enemy_team_id: int, battlefield_id: int, party_roles: PackedInt32Array) -> bool:
	var preview_session := GameSession.new()
	preview_session.party_roles = party_roles.slice(0, mini(3, party_roles.size()))
	# 资源实验室用于反复验证指令和特效，默认补满队员 HP/MP，避免未入队角色的
	# 原始初始值让五灵咒全部变灰；剧情战斗仍完整沿用正式 GameSession。
	if _database != null and preview_session.initialize_role_state(_database.player_roles):
		for role_index in preview_session.party_roles:
			preview_session.role_hp[role_index] = preview_session.role_max_hp[role_index]
			preview_session.role_mp[role_index] = preview_session.role_max_mp[role_index]
		# 样板预置基础恢复品和暗器，只修改临时会话，便于直接验证战斗物品菜单。
		for item_id in [99, 104, 153, 162]:
			if _database.item_definition(item_id) != null:
				preview_session.set_item_count(item_id, 3 if item_id in [99, 104] else 2)
	preview_session.battle_music_number = DEFAULT_LAB_BATTLE_MUSIC
	var started := _start_battle_view(_database, preview_session, enemy_team_id, battlefield_id, false)
	if started and lab_mode and _audio_player != null:
		_audio_player.configure(_database, _session)
		_audio_player.play_music(_session.battle_music_number, true, 0.0)
	return started


## 使用探索场景现有数据库和会话打开剧情战斗；玩家 HP 和胜利奖励会写回该会话。
## `is_boss` 决定胜利音乐，并继续表示该战斗不允许逃跑。
## 失败时返回 `false` 并显示具体原因，不自行伪造胜负。
func begin_battle(content_database: PalContentDatabase, game_session: GameSession, enemy_team_id: int, battlefield_id: int, is_boss: bool = false) -> bool:
	_database = content_database
	_session = game_session
	show()
	return _start_battle_view(content_database, game_session, enemy_team_id, battlefield_id, is_boss)


## 注入探索场景的统一音频播放器，供仙术特效播放 DATA.MKF 定义的 VOC 音效。
## 传入 `null` 时战斗仍可运行，只跳过音效。
func configure_audio_player(audio_player: PalAudioPlayer) -> void:
	_audio_player = audio_player


func _start_battle_view(content_database: PalContentDatabase, game_session: GameSession, enemy_team_id: int, battlefield_id: int, is_boss: bool) -> bool:
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
	_is_boss = is_boss
	_party_roles = party_roles.slice(0, mini(3, party_roles.size()))
	if not _session.equipment_effects_ready:
		var equipment_manager := PalEquipmentManager.new()
		if not equipment_manager.configure(_database, _session):
			_show_error("装备效果无法载入：%s" % equipment_manager.error_message)
			return false
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
		var sprite_number := _session.battle_sprite_for(role_index, _database.player_roles.battle_sprite_for(role_index))
		var sprite := _database.load_player_battle_sprite(sprite_number)
		var foot: Vector2i = configured_positions[party_index]
		_player_sprites.append(sprite)
		_player_foot_positions.append(foot)
		_player_current_frames.append(0)
		_player_nodes.append(_add_fighter(sprite, foot, "Player%d" % party_index))
	_controller = PalBattleController.new()
	if not _controller.start_battle(_database, _session, enemy_team_id, battlefield_id, -1, is_boss):
		_show_error("无法开始战斗：%s" % _controller.error_message)
		return false
	_battle_ui.configure(_database, _session, _controller, _player_foot_positions)
	var living_enemies := _controller.living_enemy_indices()
	_selected_enemy_index = living_enemies[0] if not living_enemies.is_empty() else -1
	_selected_party_index = 0
	_selected_action = 0
	_pending_magic_object_id = 0
	_pending_cooperative_magic = false
	_pending_item_object_id = 0
	_pending_item_throwable = false
	_action_timer = 0.0
	_animation_in_progress = false
	_script_dialog_waiting = false
	_script_dialog_advance_requested = false
	if _controller.is_accepting_commands():
		_enter_command_mode()
	else:
		_input_mode = InputMode.WAITING
		_battle_ui.set_mode(PalBattleUI.Mode.WAITING)
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ESC 在实验室模式会立即切换场景，使本节点当场脱离 SceneTree。
	# 先保存仍然有效的 Viewport，避免动作完成后 get_viewport() 已返回 null。
	var input_viewport := get_viewport()
	# 战斗脚本对白优先于所有战斗指令：第一次确认补完逐字文字，第二次才继续。
	# 其余按键在对白期间一并吞掉，避免方向、重复指令或退出误触发。
	if _script_dialog_waiting:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and _script_dialog_box != null:
			if _script_dialog_box.is_typing():
				_script_dialog_box.reveal_all()
			else:
				_script_dialog_advance_requested = true
		if input_viewport != null:
			input_viewport.set_input_as_handled()
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
		KEY_R:
			if _input_mode == InputMode.COMMAND:
				_repeat_previous_commands()
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
	if handled and input_viewport != null:
		input_viewport.set_input_as_handled()


func _build_interface() -> void:
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_background)
	_persistent_effect_root = Node2D.new()
	_persistent_effect_root.name = "PersistentBattleEffects"
	add_child(_persistent_effect_root)
	_fighter_root = Node2D.new()
	_fighter_root.name = "Fighters"
	add_child(_fighter_root)
	_magic_root = Node2D.new()
	_magic_root.name = "MagicEffects"
	add_child(_magic_root)
	_battle_ui = PalBattleUI.new()
	_battle_ui.name = "ClassicBattleUI"
	_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 战斗角色按脚底 Y 值使用 100–180 的 z_index；官方菜单必须整体压在角色之上。
	_battle_ui.z_index = 1000
	add_child(_battle_ui)
	_script_dialog_box = PalDialogBox.new()
	_script_dialog_box.name = "BattleScriptDialog"
	_script_dialog_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_dialog_box.z_index = 1100
	add_child(_script_dialog_box)
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
	_error_label.z_index = 1001
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
	for child in _magic_root.get_children():
		child.free()
	for child in _persistent_effect_root.get_children():
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
			elif direction.x > 0 and _controller.can_pending_player_use_cooperative_magic():
				_set_action_selection(2)
			elif direction.y > 0:
				_set_action_selection(3)
		InputMode.ENEMY_TARGET:
			_select_enemy(-1 if direction.x < 0 or direction.y > 0 else 1)
		InputMode.PLAYER_TARGET:
			_select_player(-1 if direction.x < 0 or direction.y > 0 else 1)
		InputMode.MAGIC_LIST:
			_battle_ui.move_magic_selection(direction.x, direction.y)
		InputMode.MISC_MENU:
			_battle_ui.move_misc_selection(direction.y if direction.y != 0 else direction.x)
		InputMode.ITEM_ACTION:
			_battle_ui.move_item_action_selection(direction.y if direction.y != 0 else direction.x)
		InputMode.ITEM_LIST:
			_battle_ui.move_item_selection(direction.x, direction.y)


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


func _select_player(step: int) -> void:
	if _controller == null or _input_mode != InputMode.PLAYER_TARGET:
		return
	_selected_party_index = clampi(_selected_party_index + step, 0, _controller.players.size() - 1)
	_battle_ui.set_player_selection(_selected_party_index)


func _confirm_current_selection() -> void:
	if _controller == null or _animation_in_progress:
		return
	if _input_mode == InputMode.REWARD:
		if _battle_ui.advance_reward_page():
			_confirm_battle_result()
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
				2:
					_confirm_cooperative_magic_selection()
				3:
					_battle_ui.open_misc_menu()
					_input_mode = InputMode.MISC_MENU
		InputMode.ENEMY_TARGET:
			_submit_targeted_action(_selected_enemy_index)
		InputMode.PLAYER_TARGET:
			_submit_targeted_action(_selected_party_index)
		InputMode.MAGIC_LIST:
			if _battle_ui.selected_magic_enabled():
				_confirm_magic_selection()
		InputMode.MISC_MENU:
			match _battle_ui.selected_misc_index:
				1:
					_battle_ui.open_item_action_menu()
					_input_mode = InputMode.ITEM_ACTION
				2:
					_submit_defend()
				3:
					_submit_flee()
				_:
					_battle_ui.show_message("该指令正在接入", 900)
		InputMode.ITEM_ACTION:
			_battle_ui.open_item_list(_battle_ui.selected_item_action == 1)
			_input_mode = InputMode.ITEM_LIST
		InputMode.ITEM_LIST:
			if _battle_ui.selected_item_enabled():
				_confirm_item_selection()


func _begin_enemy_target_selection() -> void:
	var living := _controller.living_enemy_indices()
	if living.is_empty():
		return
	_selected_enemy_index = living[0] if _selected_enemy_index not in living else _selected_enemy_index
	# 经典模式只剩一个目标时无需多按一次确认键。
	if living.size() == 1:
		_submit_targeted_action(living[0])
		return
	_input_mode = InputMode.ENEMY_TARGET
	_battle_ui.set_mode(PalBattleUI.Mode.ENEMY_TARGET)
	_battle_ui.set_enemy_selection(_selected_enemy_index)
	_last_enemy_flash_phase = -1
	_refresh_enemy_target_flash(true)


func _confirm_magic_selection() -> void:
	var magic_object_id := _battle_ui.selected_magic_object()
	var object := _database.magic_object_definition(magic_object_id)
	var definition := _database.magic_definition_for_object(magic_object_id)
	if object == null or definition == null:
		return
	_pending_magic_object_id = magic_object_id
	var applies_to_all := object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD, PalMagicDefinition.TYPE_APPLY_TO_PARTY]
	if applies_to_all:
		_submit_magic(-1)
	elif object.is_used_on_enemy():
		_begin_enemy_target_selection()
	else:
		_selected_party_index = 0
		if _controller.players.size() == 1:
			_submit_magic(0)
			return
		_input_mode = InputMode.PLAYER_TARGET
		_battle_ui.set_player_selection(_selected_party_index)
		_battle_ui.set_mode(PalBattleUI.Mode.PLAYER_TARGET)


func _confirm_cooperative_magic_selection() -> void:
	if not _controller.can_pending_player_use_cooperative_magic():
		return
	var magic_object_id := _controller.pending_cooperative_magic_object_id()
	var object := _database.magic_object_definition(magic_object_id)
	var definition := _database.magic_definition_for_object(magic_object_id)
	if object == null or definition == null:
		return
	_pending_cooperative_magic = true
	if object.applies_to_all() or definition.magic_type in [PalMagicDefinition.TYPE_ATTACK_ALL, PalMagicDefinition.TYPE_ATTACK_WHOLE, PalMagicDefinition.TYPE_ATTACK_FIELD]:
		_submit_cooperative_magic(-1)
	else:
		_begin_enemy_target_selection()


func _confirm_item_selection() -> void:
	var item_object_id := _battle_ui.selected_item_object()
	var item := _database.item_definition(item_object_id)
	if item == null:
		return
	_pending_item_object_id = item_object_id
	_pending_item_throwable = _battle_ui.selected_item_action == 1
	if item.applies_to_all():
		_submit_item(-1)
	elif _pending_item_throwable:
		_begin_enemy_target_selection()
	else:
		_selected_party_index = 0
		if _controller.players.size() == 1:
			_submit_item(0)
			return
		_input_mode = InputMode.PLAYER_TARGET
		_battle_ui.set_player_selection(_selected_party_index)
		_battle_ui.set_mode(PalBattleUI.Mode.PLAYER_TARGET)


func _submit_targeted_action(target_index: int) -> void:
	if _pending_item_object_id > 0:
		_submit_item(target_index)
	elif _pending_cooperative_magic:
		_submit_cooperative_magic(target_index)
	elif _pending_magic_object_id > 0:
		_submit_magic(target_index)
	else:
		_submit_attack()


func _submit_magic(target_index: int) -> void:
	if _pending_magic_object_id <= 0 or not _controller.submit_magic(_pending_magic_object_id, target_index):
		return
	_reset_enemy_highlight()
	_pending_magic_object_id = 0
	_after_command_submitted()


func _submit_cooperative_magic(target_index: int) -> void:
	if not _pending_cooperative_magic or not _controller.submit_cooperative_magic(target_index):
		return
	_reset_enemy_highlight()
	_pending_cooperative_magic = false
	_after_command_submitted()


func _submit_item(target_index: int) -> void:
	if _pending_item_object_id <= 0:
		return
	var accepted := _controller.submit_throw_item(_pending_item_object_id, target_index) if _pending_item_throwable else _controller.submit_use_item(_pending_item_object_id, target_index)
	if not accepted:
		return
	_reset_enemy_highlight()
	_pending_item_object_id = 0
	_pending_item_throwable = false
	_after_command_submitted()


func _submit_attack() -> void:
	if not _controller.submit_attack(_selected_enemy_index):
		return
	_pending_magic_object_id = 0
	_pending_cooperative_magic = false
	_reset_enemy_highlight()
	_after_command_submitted()


func _submit_defend() -> void:
	if _controller == null or not _controller.submit_defend():
		return
	_reset_enemy_highlight()
	_after_command_submitted()


func _submit_flee() -> void:
	if _controller == null or not _controller.submit_flee():
		return
	_reset_enemy_highlight()
	_after_command_submitted()


func _repeat_previous_commands() -> void:
	if _controller == null or not _controller.repeat_previous_commands():
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
	_pending_magic_object_id = 0
	_pending_cooperative_magic = false
	_pending_item_object_id = 0
	_pending_item_throwable = false
	_battle_ui.set_action_selection(0)
	_battle_ui.set_enemy_selection(_selected_enemy_index)
	_battle_ui.set_mode(PalBattleUI.Mode.COMMAND)
	_battle_ui.clear_message()
	_reset_enemy_highlight()


func _cancel_or_leave() -> void:
	if _animation_in_progress:
		return
	if _input_mode in [InputMode.ENEMY_TARGET, InputMode.PLAYER_TARGET] and _pending_item_object_id > 0:
		_pending_item_object_id = 0
		_battle_ui.open_item_list(_pending_item_throwable)
		_input_mode = InputMode.ITEM_LIST
	elif _input_mode == InputMode.ITEM_LIST:
		_battle_ui.open_item_action_menu()
		_input_mode = InputMode.ITEM_ACTION
	elif _input_mode == InputMode.ITEM_ACTION:
		_battle_ui.open_misc_menu()
		_input_mode = InputMode.MISC_MENU
	elif _input_mode == InputMode.MISC_MENU:
		_enter_command_mode()
	elif _input_mode in [InputMode.ENEMY_TARGET, InputMode.PLAYER_TARGET, InputMode.MAGIC_LIST]:
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
	if _controller.battle_result == PalBattleController.BattleResult.VICTORY:
		var reward := _controller.claim_victory_rewards()
		if reward != null and not reward.script_events.is_empty():
			await _play_script_events(reward.script_events)
		_input_mode = InputMode.REWARD
		_battle_ui.show_reward(reward)
		if _audio_player != null:
			_audio_player.play_music(2 if _is_boss else 3, false, 0.0)
	elif _controller.battle_result == PalBattleController.BattleResult.DEFEAT:
		_input_mode = InputMode.RESULT
		_battle_ui.set_mode(PalBattleUI.Mode.RESULT)
		_battle_ui.show_message("全队倒下")
	elif _controller.battle_result == PalBattleController.BattleResult.FLED:
		_input_mode = InputMode.RESULT
		_battle_ui.set_mode(PalBattleUI.Mode.RESULT)
		_battle_ui.show_message("逃跑成功")
	elif _controller.battle_result == PalBattleController.BattleResult.TERMINATED:
		_input_mode = InputMode.RESULT
		_battle_ui.set_mode(PalBattleUI.Mode.RESULT)
		_battle_ui.show_message("敌人离开了战斗")
	elif _controller.is_accepting_commands():
		_enter_command_mode()
	else:
		_action_timer = 0.16


func _play_action_result(result: PalBattleController.ActionResult) -> void:
	_pending_blow_displacement = 0
	if not result.script_events.is_empty():
		var immediate_events: Array[PalBattleController.ScriptEvent] = []
		var defer_trance_sprite := false
		if result.action_type == PalBattleController.ActionType.MAGIC:
			var magic := _database.magic_definition_for_object(result.magic_object_id)
			defer_trance_sprite = magic != null and magic.magic_type == PalMagicDefinition.TYPE_TRANCE
		for event in result.script_events:
			if not defer_trance_sprite or event.type != PalBattleController.ScriptEventType.PLAYER_SPRITE:
				immediate_events.append(event)
		if not immediate_events.is_empty():
			await _play_script_events(immediate_events)
	if not result.script_hits.is_empty():
		await _play_script_hits(result)
	if result.unsupported:
		_battle_ui.show_message(result.summary, 800)
		await _wait_frames(6)
		return
	if result.action_type == PalBattleController.ActionType.SCRIPT:
		return
	if result.skipped:
		await _wait_frames(2)
		return
	if result.action_type == PalBattleController.ActionType.POISON:
		await _play_poison_result(result)
		return
	if result.action_type == PalBattleController.ActionType.DEFEND and not result.actor_is_enemy:
		_set_player_frame(result.actor_index, 3)
		await _wait_frames(4)
		_set_player_frame(result.actor_index, _resting_player_frame(result.actor_index))
		return
	if result.action_type == PalBattleController.ActionType.MAGIC and not result.actor_is_enemy:
		await _play_player_magic(result)
		return
	if result.action_type == PalBattleController.ActionType.COOPERATIVE_MAGIC and not result.actor_is_enemy:
		await _play_cooperative_magic(result)
		return
	if result.action_type == PalBattleController.ActionType.MAGIC and result.actor_is_enemy:
		await _play_enemy_magic(result)
		return
	if result.action_type == PalBattleController.ActionType.USE_ITEM and not result.actor_is_enemy:
		await _play_player_use_item(result)
		return
	if result.action_type == PalBattleController.ActionType.THROW_ITEM and not result.actor_is_enemy:
		await _play_player_throw_item(result)
		return
	if result.action_type == PalBattleController.ActionType.FLEE and not result.actor_is_enemy:
		await _play_player_flee(result)
		return
	if result.actor_is_enemy:
		await _play_enemy_attack(result)
	else:
		await _play_player_attack(result)


func _play_script_events(events: Array[PalBattleController.ScriptEvent]) -> void:
	for event in events:
		match event.type:
			PalBattleController.ScriptEventType.DIALOG_START:
				var portrait_texture: Texture2D
				if event.tertiary > 0:
					portrait_texture = _texture_for_indexed(_database.load_rgm_portrait(event.tertiary), _palette)
				_script_dialog_box.begin(event.value, event.secondary, portrait_texture)
			PalBattleController.ScriptEventType.DIALOG_MESSAGE:
				if not _script_dialog_box.visible:
					_script_dialog_box.begin(event.secondary, event.tertiary)
				var message := _database.get_message(event.value)
				_script_dialog_box.show_message(message)
				await _wait_for_script_dialog()
			PalBattleController.ScriptEventType.CLEAR_DIALOG:
				_script_dialog_waiting = false
				_script_dialog_advance_requested = false
				_script_dialog_box.hide_dialog()
			PalBattleController.ScriptEventType.SOUND:
				if _audio_player != null:
					_audio_player.play_sound(event.value)
			PalBattleController.ScriptEventType.MUSIC:
				if _audio_player != null:
					_audio_player.play_music(event.value, event.secondary != 0, float(event.tertiary) / 1000.0)
			PalBattleController.ScriptEventType.DELAY:
				await _wait_frames(maxi(1, event.value * 2))
			PalBattleController.ScriptEventType.SUMMON:
				if _audio_player != null:
					_audio_player.play_sound(212)
				_sync_enemy_fighters()
				await _wait_frames(8)
			PalBattleController.ScriptEventType.TRANSFORM:
				if _audio_player != null:
					_audio_player.play_sound(47)
				_sync_enemy_fighters()
				await _wait_frames(8)
			PalBattleController.ScriptEventType.ENEMY_ESCAPE:
				await _play_enemy_escape()
			PalBattleController.ScriptEventType.ITEM_GAIN:
				# 随机掉落脚本随后通常带 003E/FFFF；这里只保证背包和提示时序一致。
				pass
			PalBattleController.ScriptEventType.SCREEN_SHAKE:
				await _play_script_screen_shake(event.value, event.secondary)
			PalBattleController.ScriptEventType.PLAYER_SPRITE:
				_sync_player_fighters()
				await _wait_frames(2)
			PalBattleController.ScriptEventType.HIDING:
				for node in _player_nodes:
					if node != null:
						node.visible = event.value <= 0
				await _wait_frames(4)
			PalBattleController.ScriptEventType.STEAL:
				var message := "%s %d %s" % [_database.get_word(34), event.secondary, _database.get_word(10) if event.value == 0 else _database.get_word(event.value)]
				_battle_ui.show_message(message, 800)
				await _wait_frames(20)
			PalBattleController.ScriptEventType.BLOW:
				# 006B 的位移在后续每一帧仙术特效中随机累计；这里只保存本动作范围的参数。
				_pending_blow_displacement = event.value
			PalBattleController.ScriptEventType.PRE_MAGIC:
				await _play_script_pre_magic(event.value)
	_script_dialog_waiting = false
	_script_dialog_advance_requested = false
	if _script_dialog_box.visible:
		_script_dialog_box.hide_dialog()


func _wait_for_script_dialog() -> void:
	_script_dialog_waiting = true
	_script_dialog_advance_requested = false
	var elapsed_frames := 0
	var typing_finished_frame := -1
	while is_instance_valid(_script_dialog_box) and _script_dialog_box.visible:
		await _wait_frames(1)
		elapsed_frames += 1
		if _script_dialog_advance_requested:
			break
		if _script_dialog_box.is_typing():
			continue
		if typing_finished_frame < 0:
			typing_finished_frame = elapsed_frames
		# 没有输入时沿用原来的最短 18 帧节奏，并在逐字结束后保留约半秒阅读时间。
		if elapsed_frames >= maxi(18, typing_finished_frame + 12):
			break
	_script_dialog_waiting = false
	_script_dialog_advance_requested = false


func _play_script_hits(result: PalBattleController.ActionResult) -> void:
	for hit in result.script_hits:
		if not hit.target_is_enemy or hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
			continue
		var foot := _enemy_foot_positions[hit.target_index]
		_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 6)
		if hit.damage > 0:
			_battle_ui.show_number(hit.damage, Vector2i(foot.x - 9, maxi(10, foot.y - 115)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
	await _wait_frames(4)
	for hit in result.script_hits:
		if not hit.target_is_enemy or hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
			continue
		if hit.defeated:
			_enemy_nodes[hit.target_index].hide()
		else:
			_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 0)


func _play_enemy_escape() -> void:
	if _audio_player != null:
		_audio_player.play_sound(45)
	for _frame in range(56):
		for enemy_index in range(_enemy_nodes.size()):
			var node := _enemy_nodes[enemy_index]
			if node != null and node.visible:
				node.position.x -= 5
		await _wait_frames(1)
	for node in _enemy_nodes:
		if node != null:
			node.hide()


func _sync_enemy_fighters() -> void:
	for node in _enemy_nodes:
		if node != null:
			node.free()
	_enemy_nodes.clear()
	_enemy_sprites.clear()
	_enemy_foot_positions.clear()
	_enemy_current_frames.clear()
	var enemy_count := mini(5, _controller.enemies.size())
	for enemy_index in range(enemy_count):
		var state := _controller.enemies[enemy_index]
		var sprite := _database.load_enemy_battle_sprite(state.definition.enemy_id)
		var foot := _database.enemy_positions.position_for(enemy_index, enemy_count)
		foot.y += state.definition.y_position_offset
		_enemy_sprites.append(sprite)
		_enemy_foot_positions.append(foot)
		_enemy_current_frames.append(0)
		var node := _add_fighter(sprite, foot, "Enemy%d" % enemy_index)
		_enemy_nodes.append(node)
		if node != null and not state.is_alive():
			node.hide()
	_last_enemy_flash_phase = -1


func _sync_player_fighters() -> void:
	for node in _player_nodes:
		if node != null:
			node.free()
	_player_nodes.clear()
	_player_sprites.clear()
	_player_current_frames.clear()
	for party_index in range(_controller.players.size()):
		var role_index := _controller.players[party_index].role_index
		var sprite_number := _session.battle_sprite_for(role_index, _database.player_roles.battle_sprite_for(role_index))
		var sprite := _database.load_player_battle_sprite(sprite_number)
		_player_sprites.append(sprite)
		_player_current_frames.append(0)
		var node := _add_fighter(sprite, _player_foot_positions[party_index], "Player%d" % party_index)
		_player_nodes.append(node)
		if node != null and _session.role_hp[role_index] <= 0:
			_set_player_frame(party_index, _resting_player_frame(party_index))


func _play_script_screen_shake(frame_count: int, level: int) -> void:
	var original_position := position
	for frame in range(maxi(0, frame_count)):
		position = original_position + Vector2(0, -level if (frame & 1) == 0 else level)
		await _wait_frames(1)
	position = original_position


func _play_script_pre_magic(party_index: int) -> void:
	if party_index >= 0 and party_index < _player_nodes.size():
		_set_player_frame(party_index, 6)
	for shift in range(5):
		for index in range(_player_nodes.size()):
			_set_player_frame(index, _player_current_frames[index], _player_foot_positions[index], shift * 2)
		await _wait_frames(1)
	for index in range(_player_nodes.size()):
		_set_player_frame(index, _resting_player_frame(index))


func _play_poison_result(result: PalBattleController.ActionResult) -> void:
	_battle_ui.show_message(result.summary, 650)
	for hit in result.hits:
		if hit.target_is_enemy:
			if hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
				continue
			var enemy_foot := _enemy_foot_positions[hit.target_index]
			_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 6)
			if hit.damage > 0:
				_battle_ui.show_number(hit.damage, Vector2i(enemy_foot.x - 9, maxi(10, enemy_foot.y - 115)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
		else:
			if hit.target_index < 0 or hit.target_index >= _player_nodes.size():
				continue
			var player_foot := _player_foot_positions[hit.target_index]
			_set_player_frame(hit.target_index, 4 if hit.damage > 0 else _resting_player_frame(hit.target_index), player_foot, 6)
			if hit.damage > 0:
				_battle_ui.show_number(hit.damage, Vector2i(player_foot.x - 9, maxi(10, player_foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
			if hit.healing > 0:
				_battle_ui.show_number(hit.healing, Vector2i(player_foot.x - 9, maxi(10, player_foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_YELLOW)
			if hit.mp_restored > 0:
				_battle_ui.show_number(hit.mp_restored, Vector2i(player_foot.x - 9, maxi(10, player_foot.y - 67)), PalBattleUI.UI_FRAME_NUMBER_CYAN)
	await _wait_frames(4)
	for hit in result.hits:
		if hit.target_is_enemy and hit.target_index >= 0 and hit.target_index < _enemy_nodes.size():
			if hit.defeated:
				_enemy_nodes[hit.target_index].hide()
			else:
				_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 0)
		elif not hit.target_is_enemy and hit.target_index >= 0 and hit.target_index < _player_nodes.size():
			_set_player_frame(hit.target_index, _resting_player_frame(hit.target_index), _player_foot_positions[hit.target_index])
	await _wait_frames(2)


func _play_player_attack(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var actor_index := result.actor_index
	var role_index := _controller.players[actor_index].role_index
	var original_foot := _player_foot_positions[actor_index]
	var strike_groups := _player_attack_strike_groups(result.hits)
	if strike_groups.is_empty():
		return
	# fight.c 只在第一击前播放四帧准备动作；双剑的每一击随后各跑完整攻击与命中音效。
	_set_player_frame(actor_index, 7, original_foot)
	await _wait_frames(4)
	for strike_index in range(strike_groups.size()):
		var strike_hits: Array = strike_groups[strike_index]
		var critical := strike_hits.any(func(hit: PalBattleController.Hit) -> bool: return hit.critical)
		if _audio_player != null:
			_audio_player.play_sound(_database.player_roles.critical_sound_for(role_index) if critical else _database.player_roles.attack_sound_for(role_index))
		var target_foot := Vector2i(150, 100)
		if not strike_hits.is_empty():
			var first_hit: PalBattleController.Hit = strike_hits[0]
			if first_hit.target_index >= 0 and first_hit.target_index < _enemy_foot_positions.size():
				target_foot = _enemy_foot_positions[first_hit.target_index]
		var attack_foot := target_foot + Vector2i(64, 20)
		if strike_index == 0:
			await _move_player(actor_index, attack_foot, 8, BATTLE_FRAME_SECONDS * 2.0)
		else:
			_set_player_frame(actor_index, 8, attack_foot)
			await _wait_frames(2)
		attack_foot -= Vector2i(10, 2)
		await _move_player(actor_index, attack_foot, 8, BATTLE_FRAME_SECONDS)
		_set_player_frame(actor_index, 9, attack_foot)
		if _audio_player != null:
			_audio_player.play_sound(_database.player_roles.weapon_sound_for(role_index))
		await _wait_frames(1)
		for raw_hit in strike_hits:
			var hit: PalBattleController.Hit = raw_hit
			if hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
				continue
			_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 6)
			var foot := _enemy_foot_positions[hit.target_index]
			_battle_ui.show_number(hit.damage, Vector2i(foot.x - 9, maxi(10, foot.y - 115)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
		# 原版首个特效帧显示数字，余下两帧与三帧受击位移让上一击先上浮，再开始下一击。
		await _wait_frames(5)
		for raw_hit in strike_hits:
			var hit: PalBattleController.Hit = raw_hit
			if hit.target_index < 0 or hit.target_index >= _enemy_nodes.size():
				continue
			if hit.defeated:
				_enemy_nodes[hit.target_index].hide()
			else:
				_set_enemy_frame(hit.target_index, _enemy_current_frames[hit.target_index], 0)
	await _move_player(actor_index, original_foot, 8, BATTLE_FRAME_SECONDS * 3.0)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(2)


func _player_attack_strike_groups(hits: Array[PalBattleController.Hit]) -> Array:
	var groups: Array = []
	for hit in hits:
		var sequence := maxi(0, hit.attack_sequence)
		while groups.size() <= sequence:
			groups.append([])
		groups[sequence].append(hit)
	return groups


func _play_player_magic(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var definition := _database.magic_definition_for_object(result.magic_object_id)
	var object := _database.magic_object_definition(result.magic_object_id)
	if definition == null or object == null:
		return
	if definition.magic_type == PalMagicDefinition.TYPE_SUMMON:
		await _play_player_summon_magic(result, object, definition)
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	var casting_foot := original_foot
	# fight.c::PAL_BattleShowPlayerPreMagicAnim 以 4、3、2、1 像素的步长向左上蓄势。
	for step in range(4, 0, -1):
		casting_foot -= Vector2i(step, step / 2)
		_set_player_frame(actor_index, _player_current_frames[actor_index], casting_foot)
		await _wait_frames(1)
	await _wait_frames(2)
	_set_player_frame(actor_index, 5, casting_foot)
	await _wait_frames(1)
	var effect_sprite := _database.load_magic_effect_sprite(definition.effect_sprite)
	if effect_sprite != null and effect_sprite.is_valid():
		await _play_magic_effect_sprite(effect_sprite, definition, result, casting_foot)
	elif definition.magic_type != PalMagicDefinition.TYPE_TRANCE:
		_battle_ui.show_message("仙术特效资源缺失，请重新导入 Data", 1000)
		if _audio_player != null:
			_audio_player.play_sound(definition.sound)
		await _wait_frames(4)
	if definition.magic_type == PalMagicDefinition.TYPE_TRANCE:
		await _play_trance_transition(result, casting_foot)
	else:
		await _show_magic_result(result, object, definition)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(5)


func _play_player_summon_magic(result: PalBattleController.ActionResult, object: PalMagicObjectDefinition, definition: PalMagicDefinition) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	var casting_foot := original_foot
	for step in range(4, 0, -1):
		casting_foot -= Vector2i(step, step / 2)
		_set_player_frame(actor_index, _player_current_frames[actor_index], casting_foot)
		await _wait_frames(1)
	await _wait_frames(2)
	_set_player_frame(actor_index, 5, casting_foot)
	if _audio_player != null:
		var role_index := _controller.players[actor_index].role_index
		_audio_player.play_sound(_database.player_roles.magic_sound_for(role_index))
	for shift in range(1, 11):
		for party_index in range(_player_nodes.size()):
			var shift_foot := casting_foot if party_index == actor_index else _player_foot_positions[party_index]
			_set_player_frame(party_index, _player_current_frames[party_index], shift_foot, shift)
		await _wait_frames(1)
	for node in _player_nodes:
		if node != null:
			node.hide()
	var summon_sprite := _database.load_player_battle_sprite(definition.specific + 10)
	if summon_sprite == null or not summon_sprite.is_valid():
		_battle_ui.show_message("召唤神将 Sprite 缺失，请重新导入 Data", 1000)
		_sync_player_fighters()
		await _wait_frames(4)
		return
	var summon_foot := Vector2i(240 + definition.x_offset, 165 + definition.y_offset)
	_summon_node = _add_fighter(summon_sprite, summon_foot, "SummonedGod")
	var delay_seconds := clampf((definition.speed + 5) * 0.01, 0.01, 0.2)
	for frame_index in range(summon_sprite.frame_count()):
		_apply_fighter_frame(_summon_node, summon_sprite, summon_foot, frame_index, 0)
		await get_tree().create_timer(delay_seconds).timeout
	var effect_object_id := _database.magic_object_id_for_magic_number(definition.effect_sprite)
	var effect_definition := _database.magic_definition_for_object(effect_object_id)
	var effect_sprite := _database.load_magic_effect_sprite(effect_definition.effect_sprite) if effect_definition != null else null
	if effect_sprite != null and effect_sprite.is_valid():
		await _play_magic_effect_sprite(effect_sprite, effect_definition, result, summon_foot, false)
	else:
		_battle_ui.show_message("召唤后续仙术特效缺失", 1000)
		await _wait_frames(4)
	await _show_magic_result(result, object, definition)
	if _summon_node != null:
		_summon_node.free()
		_summon_node = null
	_sync_player_fighters()
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(5)


func _play_trance_transition(result: PalBattleController.ActionResult, casting_foot: Vector2i) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	for shift in range(6):
		_set_player_frame(result.actor_index, _player_current_frames[result.actor_index], casting_foot, shift * 2)
		await _wait_frames(1)
	# 成功脚本已经把临时战斗 Sprite 写入 GameSession，此时才重建节点以复现梦蛇变身时序。
	_sync_player_fighters()
	await _wait_frames(4)


func _play_player_use_item(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	await _wait_frames(4)
	var use_foot := original_foot - Vector2i(15, 7)
	_set_player_frame(actor_index, 5, use_foot)
	if _audio_player != null:
		_audio_player.play_sound(28)
	_battle_ui.show_message(_database.get_word(result.item_object_id), 900)
	var affected := PackedInt32Array()
	if result.target_index < 0:
		for party_index in range(_player_nodes.size()):
			affected.append(party_index)
	else:
		affected.append(result.target_index)
	for shift in range(7):
		for party_index in affected:
			_set_player_frame(party_index, _player_current_frames[party_index], _player_foot_positions[party_index], shift)
		await _wait_frames(1)
	for shift in range(5, -1, -1):
		for party_index in affected:
			_set_player_frame(party_index, _player_current_frames[party_index], _player_foot_positions[party_index], shift)
		await _wait_frames(1)
	for hit in result.hits:
		if hit.target_index < 0 or hit.target_index >= _player_foot_positions.size():
			continue
		var foot := _player_foot_positions[hit.target_index]
		if hit.healing > 0:
			_battle_ui.show_number(hit.healing, Vector2i(foot.x - 9, maxi(10, foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_YELLOW)
		if hit.mp_restored > 0:
			_battle_ui.show_number(hit.mp_restored, Vector2i(foot.x - 9, maxi(10, foot.y - 67)), PalBattleUI.UI_FRAME_NUMBER_CYAN)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(8)


func _play_cooperative_magic(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size() or result.contributor_indices.size() <= 1:
		return
	var definition := _database.magic_definition_for_object(result.magic_object_id)
	var object := _database.magic_object_definition(result.magic_object_id)
	if definition == null or object == null:
		return
	if definition.magic_type == PalMagicDefinition.TYPE_SUMMON:
		await _play_player_summon_magic(result, object, definition)
		return
	var original_feet := _player_foot_positions.duplicate()
	var cooperative_feet := original_feet.duplicate()
	cooperative_feet[result.actor_index] = COOPERATIVE_POSITIONS[0]
	var position_index := 0
	for party_index in range(_player_nodes.size()):
		if party_index == result.actor_index:
			continue
		position_index += 1
		if party_index in result.contributor_indices and position_index < COOPERATIVE_POSITIONS.size():
			cooperative_feet[party_index] = COOPERATIVE_POSITIONS[position_index]
	if _audio_player != null:
		_audio_player.play_sound(29)
	for step in range(1, 7):
		var progress := float(step) / 6.0
		for party_index in result.contributor_indices:
			var foot := Vector2i(
				roundi(lerpf(original_feet[party_index].x, cooperative_feet[party_index].x, progress)),
				roundi(lerpf(original_feet[party_index].y, cooperative_feet[party_index].y, progress))
			)
			_set_player_frame(party_index, _player_current_frames[party_index], foot)
		await _wait_frames(1)
	for contributor_offset in range(result.contributor_indices.size() - 1, -1, -1):
		var party_index := result.contributor_indices[contributor_offset]
		if party_index == result.actor_index:
			continue
		_set_player_frame(party_index, 5, cooperative_feet[party_index])
		await _wait_frames(3)
	_set_player_frame(result.actor_index, 5, cooperative_feet[result.actor_index], 6)
	await _wait_frames(5)
	_set_player_frame(result.actor_index, 6, cooperative_feet[result.actor_index])
	await _wait_frames(3)
	var effect_sprite := _database.load_magic_effect_sprite(definition.effect_sprite)
	if effect_sprite != null and effect_sprite.is_valid():
		await _play_magic_effect_sprite(effect_sprite, definition, result, cooperative_feet[result.actor_index])
		await _show_magic_result(result, object, definition)
	else:
		_battle_ui.show_message("合击特效资源缺失，请重新导入 Data", 1000)
		await _wait_frames(4)
	for step in range(1, 7):
		var progress := float(step) / 6.0
		for party_index in result.contributor_indices:
			var foot := Vector2i(
				roundi(lerpf(cooperative_feet[party_index].x, original_feet[party_index].x, progress)),
				roundi(lerpf(cooperative_feet[party_index].y, original_feet[party_index].y, progress))
			)
			_set_player_frame(party_index, _resting_player_frame(party_index), foot)
		await _wait_frames(1)
	for party_index in result.contributor_indices:
		_set_player_frame(party_index, _resting_player_frame(party_index), original_feet[party_index])
	await _wait_frames(3)


func _play_player_throw_item(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	var throw_foot := original_foot
	for step in range(4, 0, -1):
		throw_foot -= Vector2i(step, step / 2)
		_set_player_frame(actor_index, _player_current_frames[actor_index], throw_foot)
		await _wait_frames(1)
	_battle_ui.show_message(_database.get_word(result.item_object_id), 1000)
	_set_player_frame(actor_index, 5, throw_foot)
	if _audio_player != null:
		var role_index := _controller.players[actor_index].role_index
		_audio_player.play_sound(_database.player_roles.magic_sound_for(role_index))
	await _wait_frames(8)
	_set_player_frame(actor_index, 6, throw_foot)
	await _wait_frames(2)
	var definition := _database.magic_definition_for_object(result.magic_object_id)
	var object := _database.magic_object_definition(result.magic_object_id)
	var effect_sprite := _database.load_magic_effect_sprite(definition.effect_sprite) if definition != null else null
	if definition != null and object != null and effect_sprite != null and effect_sprite.is_valid():
		await _play_magic_effect_sprite(effect_sprite, definition, result, throw_foot)
		await _show_magic_result(result, object, definition)
	else:
		_battle_ui.show_message("投掷特效资源缺失", 900)
		await _wait_frames(4)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)
	await _wait_frames(4)


func _play_player_flee(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _player_nodes.size():
		return
	if result.flee_succeeded:
		if _audio_player != null:
			_audio_player.play_sound(45)
		var feet := _player_foot_positions.duplicate()
		for _frame in range(16):
			for party_index in range(_player_nodes.size()):
				if _session.role_hp[_controller.players[party_index].role_index] <= 0:
					continue
				var delta := Vector2i(4, 6) if party_index == 0 and _player_nodes.size() > 1 else (Vector2i(4, 4) if party_index == 1 or _player_nodes.size() == 1 else Vector2i(6, 3))
				feet[party_index] += delta
				_set_player_frame(party_index, 0, feet[party_index])
			await _wait_frames(1)
		for node in _player_nodes:
			node.hide()
		await _wait_frames(1)
		return
	var actor_index := result.actor_index
	var original_foot := _player_foot_positions[actor_index]
	var failed_foot := original_foot
	for _frame in range(3):
		failed_foot += Vector2i(4, 2)
		_set_player_frame(actor_index, 0, failed_foot)
		await _wait_frames(1)
	_set_player_frame(actor_index, 1, failed_foot)
	_battle_ui.show_message(_database.get_word(31), 900)
	await _wait_frames(8)
	_set_player_frame(actor_index, _resting_player_frame(actor_index), original_foot)


func _play_magic_effect_sprite(sprite: PalSprite, definition: PalMagicDefinition, result: PalBattleController.ActionResult, casting_foot: Vector2i, animate_caster: bool = true) -> void:
	var effect_positions := _magic_effect_positions(definition, result)
	if effect_positions.is_empty():
		return
	var effect_nodes: Array[Sprite2D] = []
	for index in range(effect_positions.size()):
		var node := Sprite2D.new()
		node.name = "Magic%02d" % index
		node.centered = false
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_magic_root.add_child(node)
		effect_nodes.append(node)
	var frame_count := sprite.frame_count()
	var repeat_start := clampi(definition.fire_delay, 0, maxi(0, frame_count - 1))
	var repeated_frames := maxi(0, frame_count - repeat_start) * definition.effect_times
	var total_frames := mini(512, frame_count + repeated_frames + definition.shake)
	var delay_seconds := clampf((definition.speed + 5) * 0.01, 0.01, 0.2)
	var final_frame_index := maxi(0, frame_count - 1)
	for animation_index in range(total_frames):
		var frame_index := animation_index if animation_index < frame_count else repeat_start + posmod(animation_index - repeat_start, maxi(1, frame_count - repeat_start))
		final_frame_index = frame_index
		if animation_index == repeat_start:
			if animate_caster:
				_set_player_frame(result.actor_index, 6, casting_foot)
			if _audio_player != null:
				_audio_player.play_sound(definition.sound)
		var frame := RleDecoder.decode(sprite.get_frame(frame_index))
		if not frame.is_valid():
			continue
		for node_index in range(effect_nodes.size()):
			var foot := effect_positions[node_index]
			var node := effect_nodes[node_index]
			node.texture = _texture_for_sprite_frame(sprite, frame_index, 0)
			node.position = Vector2(foot.x - frame.width / 2.0, foot.y - frame.height)
			node.z_index = foot.y + definition.specific
		_apply_blow_to_enemies()
		await get_tree().create_timer(delay_seconds).timeout
	_keep_magic_effect(sprite, final_frame_index, definition, effect_positions)
	for node in effect_nodes:
		node.free()


func _magic_effect_positions(definition: PalMagicDefinition, result: PalBattleController.ActionResult) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match definition.magic_type:
		PalMagicDefinition.TYPE_NORMAL:
			if result.target_index >= 0 and result.target_index < _enemy_foot_positions.size():
				positions.append(_enemy_foot_positions[result.target_index])
		PalMagicDefinition.TYPE_ATTACK_ALL:
			positions = [Vector2i(70, 140), Vector2i(100, 110), Vector2i(160, 100)]
		PalMagicDefinition.TYPE_ATTACK_WHOLE:
			positions.append(Vector2i(120, 100))
		PalMagicDefinition.TYPE_ATTACK_FIELD:
			positions.append(Vector2i(160, 200))
		PalMagicDefinition.TYPE_APPLY_TO_PLAYER:
			if result.target_index >= 0 and result.target_index < _player_foot_positions.size():
				positions.append(_player_foot_positions[result.target_index])
		PalMagicDefinition.TYPE_APPLY_TO_PARTY:
			positions = _player_foot_positions.duplicate()
		PalMagicDefinition.TYPE_TRANCE:
			if result.actor_index >= 0 and result.actor_index < _player_foot_positions.size():
				positions.append(_player_foot_positions[result.actor_index])
	for index in range(positions.size()):
		positions[index] += Vector2i(definition.x_offset, definition.y_offset)
	return positions


func _show_magic_result(result: PalBattleController.ActionResult, object: PalMagicObjectDefinition, definition: PalMagicDefinition) -> void:
	# 暗器的 0042 模拟仙术对象可能没有“对敌使用”菜单标志，但命中结果仍明确指向敌人。
	if object.is_used_on_enemy() or result.hits.any(func(hit: PalBattleController.Hit) -> bool: return hit.target_is_enemy):
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
		return
	var affected := PackedInt32Array()
	if definition.magic_type == PalMagicDefinition.TYPE_APPLY_TO_PARTY or result.target_index < 0:
		for party_index in range(_player_nodes.size()):
			affected.append(party_index)
	else:
		affected.append(result.target_index)
	for hit in result.hits:
		if hit.target_index < 0 or hit.target_index >= _player_foot_positions.size():
			continue
		var foot := _player_foot_positions[hit.target_index]
		if hit.healing > 0:
			_battle_ui.show_number(hit.healing, Vector2i(foot.x - 9, maxi(10, foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_YELLOW)
		if hit.mp_restored > 0:
			_battle_ui.show_number(hit.mp_restored, Vector2i(foot.x - 9, maxi(10, foot.y - 67)), PalBattleUI.UI_FRAME_NUMBER_CYAN)
	for shift in range(7):
		for party_index in affected:
			_set_player_frame(party_index, _player_current_frames[party_index], _player_foot_positions[party_index], shift)
		await _wait_frames(1)
	for shift in range(6, -1, -1):
		for party_index in affected:
			_set_player_frame(party_index, _player_current_frames[party_index], _player_foot_positions[party_index], shift)
		await _wait_frames(1)


func _play_enemy_attack(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _enemy_nodes.size() or result.hits.is_empty():
		return
	var actor_index := result.actor_index
	var hit := result.hits[0]
	if hit.target_index < 0 or hit.target_index >= _player_nodes.size():
		return
	var definition := _controller.enemies[actor_index].definition
	if _audio_player != null and definition.sounds.size() > 0:
		_audio_player.play_sound(definition.sounds[0])
	var original_foot := _enemy_foot_positions[actor_index]
	for frame_offset in range(definition.magic_frames):
		_set_enemy_frame(actor_index, definition.idle_frames + frame_offset)
		await _wait_frames(2)
	var target_foot := _player_foot_positions[hit.target_index]
	var attack_foot := target_foot - Vector2i(44, 16)
	var cover_original_foot := Vector2i.ZERO
	var cover_guard_foot := Vector2i.ZERO
	if hit.covering_index >= 0 and hit.covering_index < _player_nodes.size():
		cover_original_foot = _player_foot_positions[hit.covering_index]
		cover_guard_foot = target_foot - Vector2i(24, 12)
		_set_player_frame(hit.covering_index, 3, cover_guard_foot)
	if _audio_player != null and definition.sounds.size() > 1:
		_audio_player.play_sound(definition.sounds[1])
	var first_attack_frame := maxi(0, definition.idle_frames + definition.magic_frames - 1)
	await _move_enemy(actor_index, attack_foot, first_attack_frame, BATTLE_FRAME_SECONDS * 2.0)
	var attack_frame_count := maxi(1, definition.attack_frames + 1)
	for frame_offset in range(attack_frame_count):
		var frame := definition.idle_frames + definition.magic_frames + frame_offset - 1
		_set_enemy_frame(actor_index, frame, 0, attack_foot)
		await _wait_frames(maxi(1, definition.action_wait_frames))
	var target_frame := 3 if hit.auto_defended else 4
	if hit.covering_index < 0:
		_set_player_frame(hit.target_index, target_frame, target_foot, 0 if hit.auto_defended else 6)
	if _audio_player != null:
		var target_role := _controller.players[hit.target_index].role_index
		var sound_role := _controller.players[hit.covering_index].role_index if hit.covering_index >= 0 else target_role
		var hit_sound := _database.player_roles.cover_sound_for(sound_role) if hit.auto_defended else (definition.sounds[4] if definition.sounds.size() > 4 else 0)
		_audio_player.play_sound(hit_sound)
		if hit.defeated:
			_audio_player.play_sound(_database.player_roles.death_sound_for(target_role))
	if hit.damage > 0:
		_battle_ui.show_number(hit.damage, Vector2i(target_foot.x - 9, maxi(10, target_foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
	await _wait_frames(1)
	if hit.covering_index < 0:
		_set_player_frame(hit.target_index, target_frame, target_foot + Vector2i(8, 4))
	await _wait_frames(3)
	await _move_enemy(actor_index, original_foot, 0, BATTLE_FRAME_SECONDS * 2.0)
	_set_enemy_frame(actor_index, 0, 0, original_foot)
	if hit.covering_index >= 0:
		_set_player_frame(hit.covering_index, _resting_player_frame(hit.covering_index), cover_original_foot)
	_set_player_frame(hit.target_index, _resting_player_frame(hit.target_index), target_foot)
	await _wait_frames(4)


func _play_enemy_magic(result: PalBattleController.ActionResult) -> void:
	if result.actor_index < 0 or result.actor_index >= _enemy_nodes.size():
		return
	var definition := _database.magic_definition_for_object(result.magic_object_id)
	if definition == null:
		return
	var actor_index := result.actor_index
	var enemy := _controller.enemies[actor_index].definition
	var original_foot := _enemy_foot_positions[actor_index]
	var casting_foot := original_foot + Vector2i(12, 6)
	_set_enemy_frame(actor_index, _enemy_current_frames[actor_index], 0, casting_foot)
	await _wait_frames(1)
	casting_foot += Vector2i(4, 2)
	_set_enemy_frame(actor_index, _enemy_current_frames[actor_index], 0, casting_foot)
	await _wait_frames(1)
	if _audio_player != null and enemy.sounds.size() > 1 and enemy.sounds[1] >= 0:
		_audio_player.play_sound(enemy.sounds[1])
	for frame_offset in range(enemy.magic_frames):
		_set_enemy_frame(actor_index, enemy.idle_frames + frame_offset, 0, casting_foot)
		await _wait_frames(maxi(1, enemy.action_wait_frames))
	if enemy.magic_frames == 0:
		await _wait_frames(1)
	if definition.fire_delay == 0:
		for frame_offset in range(enemy.attack_frames + 1):
			var attack_frame := frame_offset - 1 + enemy.idle_frames + enemy.magic_frames
			_set_enemy_frame(actor_index, attack_frame, 0, casting_foot)
			await _wait_frames(maxi(1, enemy.action_wait_frames))
	var effect_sprite := _database.load_magic_effect_sprite(definition.effect_sprite)
	if effect_sprite != null and effect_sprite.is_valid():
		await _play_enemy_magic_effect_sprite(effect_sprite, definition, result, casting_foot)
	else:
		_battle_ui.show_message("敌人仙术特效资源缺失，请重新导入 Data", 1000)
		if _audio_player != null:
			_audio_player.play_sound(definition.sound)
		await _wait_frames(4)
	await _show_enemy_magic_result(result)
	_set_enemy_frame(actor_index, 0, 0, original_foot)
	await _wait_frames(8)


func _play_enemy_magic_effect_sprite(sprite: PalSprite, definition: PalMagicDefinition, result: PalBattleController.ActionResult, casting_foot: Vector2i) -> void:
	var effect_positions := _enemy_magic_effect_positions(definition, result)
	if effect_positions.is_empty():
		return
	var effect_nodes: Array[Sprite2D] = []
	for index in range(effect_positions.size()):
		var node := Sprite2D.new()
		node.name = "EnemyMagic%02d" % index
		node.centered = false
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_magic_root.add_child(node)
		effect_nodes.append(node)
	var frame_count := sprite.frame_count()
	var repeat_start := clampi(definition.fire_delay, 0, maxi(0, frame_count - 1))
	var repeated_frames := maxi(0, frame_count - repeat_start) * definition.effect_times
	var total_frames := mini(512, frame_count + repeated_frames + definition.shake)
	var delay_seconds := clampf((definition.speed + 5) * 0.01, 0.01, 0.2)
	var casting_enemy := _controller.enemies[result.actor_index].definition
	var final_frame_index := maxi(0, frame_count - 1)
	for animation_index in range(total_frames):
		var frame_index := animation_index if animation_index < frame_count else repeat_start + posmod(animation_index - repeat_start, maxi(1, frame_count - repeat_start))
		final_frame_index = frame_index
		if animation_index == repeat_start:
			var attack_frame := maxi(0, casting_enemy.idle_frames + casting_enemy.magic_frames - 1)
			_set_enemy_frame(result.actor_index, attack_frame, 0, casting_foot)
			if _audio_player != null:
				_audio_player.play_sound(definition.sound)
		if definition.fire_delay > 0 and animation_index >= definition.fire_delay:
			if animation_index < definition.fire_delay + casting_enemy.attack_frames:
				var attack_frame := animation_index - definition.fire_delay + casting_enemy.idle_frames + casting_enemy.magic_frames
				_set_enemy_frame(result.actor_index, attack_frame, 0, casting_foot)
		var frame := RleDecoder.decode(sprite.get_frame(frame_index))
		if not frame.is_valid():
			continue
		for node_index in range(effect_nodes.size()):
			var foot := effect_positions[node_index]
			var node := effect_nodes[node_index]
			node.texture = _texture_for_sprite_frame(sprite, frame_index, 0)
			node.position = Vector2(foot.x - frame.width / 2.0, foot.y - frame.height)
			node.z_index = foot.y + definition.specific
		_apply_blow_to_players()
		await get_tree().create_timer(delay_seconds).timeout
	_keep_magic_effect(sprite, final_frame_index, definition, effect_positions)
	for node in effect_nodes:
		node.free()


func _keep_magic_effect(sprite: PalSprite, frame_index: int, definition: PalMagicDefinition, positions: Array[Vector2i]) -> void:
	if definition.keep_effect != 0xffff or sprite == null or not sprite.is_valid() or positions.is_empty():
		return
	var battlefield := _database.battlefield_definition(_battlefield_id)
	var screen_wave := (battlefield.screen_wave if battlefield != null else 0) + definition.wave
	if screen_wave >= 9:
		return
	var frame := RleDecoder.decode(sprite.get_frame(frame_index))
	if not frame.is_valid():
		return
	for index in range(positions.size()):
		var node := Sprite2D.new()
		node.name = "PersistentMagic%02d" % index
		node.centered = false
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.texture = _texture_for_sprite_frame(sprite, frame_index, 0)
		var foot := positions[index]
		node.position = Vector2(foot.x - frame.width / 2.0, foot.y - frame.height)
		_persistent_effect_root.add_child(node)


func _apply_blow_to_enemies() -> void:
	if _pending_blow_displacement == 0:
		return
	var blow := randi_range(mini(0, _pending_blow_displacement), maxi(0, _pending_blow_displacement))
	if blow == 0:
		return
	var movement := Vector2i(blow, int(float(blow) / 2.0))
	for enemy_index in range(_enemy_nodes.size()):
		if _enemy_nodes[enemy_index] == null:
			continue
		_enemy_foot_positions[enemy_index] += movement
		_set_enemy_frame(enemy_index, _enemy_current_frames[enemy_index], 0, _enemy_foot_positions[enemy_index])


func _apply_blow_to_players() -> void:
	if _pending_blow_displacement == 0:
		return
	var blow := randi_range(mini(0, _pending_blow_displacement), maxi(0, _pending_blow_displacement))
	if blow == 0:
		return
	var movement := Vector2i(blow, int(float(blow) / 2.0))
	for player_index in range(_player_nodes.size()):
		if _player_nodes[player_index] == null:
			continue
		_player_foot_positions[player_index] += movement
		_set_player_frame(player_index, _player_current_frames[player_index], _player_foot_positions[player_index])


func _enemy_magic_effect_positions(definition: PalMagicDefinition, result: PalBattleController.ActionResult) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match definition.magic_type:
		PalMagicDefinition.TYPE_NORMAL:
			if result.target_index >= 0 and result.target_index < _player_foot_positions.size():
				positions.append(_player_foot_positions[result.target_index])
		PalMagicDefinition.TYPE_ATTACK_ALL:
			# fight.c::PAL_BattleShowEnemyMagicAnim 固定使用三名队员的原版脚底坐标。
			positions = [Vector2i(180, 180), Vector2i(234, 170), Vector2i(270, 146)]
		PalMagicDefinition.TYPE_ATTACK_WHOLE:
			positions.append(Vector2i(240, 150))
		PalMagicDefinition.TYPE_ATTACK_FIELD:
			positions.append(Vector2i(160, 200))
		PalMagicDefinition.TYPE_APPLY_TO_PLAYER:
			if result.target_index >= 0 and result.target_index < _player_foot_positions.size():
				positions.append(_player_foot_positions[result.target_index])
		PalMagicDefinition.TYPE_APPLY_TO_PARTY:
			positions = _player_foot_positions.duplicate()
	for index in range(positions.size()):
		positions[index] += Vector2i(definition.x_offset, definition.y_offset)
	return positions


func _show_enemy_magic_result(result: PalBattleController.ActionResult) -> void:
	var affected := PackedInt32Array()
	for hit in result.hits:
		if hit.target_index < 0 or hit.target_index >= _player_foot_positions.size():
			continue
		affected.append(hit.target_index)
		var foot := _player_foot_positions[hit.target_index]
		_set_player_frame(hit.target_index, 3 if hit.auto_defended else 4, foot, 6)
		if hit.damage > 0:
			_battle_ui.show_number(hit.damage, Vector2i(foot.x - 9, maxi(10, foot.y - 75)), PalBattleUI.UI_FRAME_NUMBER_BLUE)
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(4, 2), Vector2i(6, 3), Vector2i(7, 3), Vector2i(7, 3)]
	for frame_index in range(offsets.size()):
		for party_index in affected:
			var hit: PalBattleController.Hit
			for candidate in result.hits:
				if candidate.target_index == party_index:
					hit = candidate
					break
			var target_frame := 3 if hit != null and hit.auto_defended else 4
			_set_player_frame(party_index, target_frame, _player_foot_positions[party_index] + offsets[frame_index], 6 if frame_index < 3 else 0)
		await _wait_frames(1)
	for party_index in affected:
		_set_player_frame(party_index, _resting_player_frame(party_index), _player_foot_positions[party_index])


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
		return 0 if _session.status_rounds_for(role_index, GameSession.STATUS_PUPPET) > 0 else 2
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
