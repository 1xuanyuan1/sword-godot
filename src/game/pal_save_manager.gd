# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Godot 新存档的版本化读写器，负责 100 个槽位、内容指纹和损坏校验。
## 存档保存在 `user://saves/`；它只写用户目录，不修改原版资源或生成目录。
class_name PalSaveManager
extends RefCounted

const FORMAT_VERSION := 1
const SLOT_COUNT := 100
const SLOTS_PER_PAGE := 5
const DEFAULT_SAVE_DIRECTORY := "user://saves"
const CONTENT_FINGERPRINT_FILES := [
	"core/scenes.bin",
	"core/event_objects.bin",
	"core/scripts.bin",
	"core/objects_dos.bin",
	"data/03.bin",
]

## 最近一次配置、保存或读取失败的中文原因；成功时为空。
var error_message: String = ""
## 当前系统菜单默认选中的槽位，范围为 1–100。
var current_slot: int = 1

var _database: PalContentDatabase
var _save_directory: String = DEFAULT_SAVE_DIRECTORY
var _content_fingerprint: String = ""
var _metadata_cache: Dictionary = {}


## 绑定内容数据库和存档目录，并计算静态内容指纹。
## `fingerprint_override` 只供合成测试或明确隔离的自定义内容使用；生产运行应保持为空。
func configure(database: PalContentDatabase, save_directory: String = DEFAULT_SAVE_DIRECTORY, fingerprint_override: String = "") -> bool:
	error_message = ""
	_database = database
	_save_directory = save_directory.simplify_path()
	_metadata_cache.clear()
	if _database == null or _database.player_roles == null or _database.scenes.is_empty() or _database.event_objects.is_empty():
		error_message = "存档系统缺少已加载的 PAL 内容数据库"
		return false
	_content_fingerprint = fingerprint_override if not fingerprint_override.is_empty() else _calculate_content_fingerprint()
	if _content_fingerprint.is_empty():
		if error_message.is_empty():
			error_message = "无法计算当前 PAL 内容指纹"
		return false
	var absolute_directory := ProjectSettings.globalize_path(_save_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		error_message = "无法创建存档目录：%s" % error_string(directory_error)
		return false
	return true


## 把当前会话和剧情数据库运行时状态写入指定槽位。
## 槽位无效、会话未初始化或文件写入失败时返回 `false`，不会覆盖已有存档。
func save_slot(slot: int, session: GameSession) -> bool:
	error_message = ""
	if not _validate_slot(slot) or session == null:
		if error_message.is_empty():
			error_message = "没有可保存的游戏会话"
		return false
	if session.role_levels.size() != PalPlayerRoles.ROLE_COUNT or session.trail_positions.size() != GameSession.TRAIL_SIZE:
		error_message = "游戏会话尚未完成初始化，不能保存"
		return false
	var scene := _database.scenes[session.scene_index] if session.scene_index >= 0 and session.scene_index < _database.scenes.size() else null
	if scene == null:
		error_message = "当前场景索引无效，不能保存"
		return false
	var save_count := _next_save_count()
	var payload := {
		"session": _serialize_session(session),
		"runtime_content": _serialize_runtime_content(),
	}
	var payload_json := JSON.stringify(payload, "", false)
	var metadata := {
		"slot": slot,
		"save_count": save_count,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"scene_index": session.scene_index,
		"map_number": scene.map_number,
		"cash": session.cash,
		"party": _party_metadata(session),
	}
	var record := {
		"header": {
			"format_version": FORMAT_VERSION,
			"content_fingerprint": _content_fingerprint,
		},
		"metadata": metadata,
		"payload_sha256": _sha256_text(payload_json),
		"payload_json": payload_json,
	}
	var absolute_path := ProjectSettings.globalize_path(slot_path(slot))
	var temporary_path := absolute_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		error_message = "无法创建临时存档：%s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(record, "  ", false))
	file.flush()
	file = null
	if not _replace_file(temporary_path, absolute_path):
		return false
	current_slot = slot
	_metadata_cache.erase(slot)
	return true


## 从指定槽位读取并恢复同一个 `GameSession` 与内容数据库对象。
## 会先完成格式、校验和、内容指纹及结构验证；失败时不修改当前游戏。
func load_slot(slot: int, session: GameSession) -> bool:
	error_message = ""
	if not _validate_slot(slot) or session == null:
		if error_message.is_empty():
			error_message = "没有可恢复的游戏会话"
		return false
	var record := _read_record(slot)
	if not _validate_record(record):
		return false
	var payload = JSON.parse_string(str(record["payload_json"]))
	_restore_session(session, payload["session"])
	_restore_runtime_content(payload["runtime_content"])
	current_slot = slot
	return true


## 返回 1–100 槽的轻量摘要，供经典菜单分页绘制。
## 每项包含是否存在、是否可读、场景、时间和队伍角色/等级，不暴露完整存档内容。
func slot_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		result.append(slot_metadata(slot))
	return result


## 返回单个槽位的摘要；损坏、版本不兼容和内容不匹配会给出独立诊断。
func slot_metadata(slot: int) -> Dictionary:
	if _metadata_cache.has(slot):
		return _metadata_cache[slot].duplicate(true)
	var result := {
		"slot": slot,
		"exists": false,
		"can_load": false,
		"save_count": 0,
		"saved_at": "",
		"scene_index": -1,
		"map_number": 0,
		"cash": 0,
		"party": [],
		"error": "",
	}
	if not _slot_in_range(slot):
		result["error"] = "槽位超出 1–%d" % SLOT_COUNT
		return result
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		_metadata_cache[slot] = result
		return result.duplicate(true)
	result["exists"] = true
	var previous_error := error_message
	var record := _read_record(slot)
	if not _validate_record(record):
		result["error"] = error_message
		error_message = previous_error
		_metadata_cache[slot] = result
		return result.duplicate(true)
	var metadata: Dictionary = record["metadata"]
	for key in ["save_count", "saved_at", "scene_index", "map_number", "cash", "party"]:
		result[key] = metadata.get(key, result[key])
	result["can_load"] = true
	error_message = previous_error
	_metadata_cache[slot] = result
	return result.duplicate(true)


## 返回指定槽位的 Godot 用户目录路径；无效槽位仍返回格式化路径，调用方应先校验。
func slot_path(slot: int) -> String:
	return _save_directory.path_join("slot_%03d.json" % slot)


## 删除一个存档槽，主要供测试和以后存档管理界面使用。
func delete_slot(slot: int) -> bool:
	error_message = ""
	if not _validate_slot(slot):
		return false
	var absolute_path := ProjectSettings.globalize_path(slot_path(slot))
	if not FileAccess.file_exists(absolute_path):
		_metadata_cache.erase(slot)
		return true
	var result := DirAccess.remove_absolute(absolute_path)
	if result != OK:
		error_message = "无法删除存档 %d：%s" % [slot, error_string(result)]
		return false
	_metadata_cache.erase(slot)
	return true


func _serialize_session(session: GameSession) -> Dictionary:
	return {
		"scene_index": session.scene_index,
		"viewport_position": _vector_to_data(session.viewport_position),
		"party_direction": session.party_direction,
		"cash": session.cash,
		"palette_index": session.palette_index,
		"night_palette": session.night_palette,
		"music_number": session.music_number,
		"battle_music_number": session.battle_music_number,
		"battlefield_number": session.battlefield_number,
		"music_volume": session.music_volume,
		"sound_volume": session.sound_volume,
		"world_layer": session.world_layer,
		"party_roles": Array(session.party_roles),
		"follower_sprite_numbers": Array(session.follower_sprite_numbers),
		"collect_value": session.collect_value,
		"chase_speed_change_cycles": session.chase_speed_change_cycles,
		"chase_range_multiplier": session.chase_range_multiplier,
		"party_script_frames": Array(session.party_script_frames),
		"inventory": _dictionary_to_pairs(session.inventory),
		"role_levels": Array(session.role_levels),
		"role_max_hp": Array(session.role_max_hp),
		"role_max_mp": Array(session.role_max_mp),
		"role_hp": Array(session.role_hp),
		"role_mp": Array(session.role_mp),
		"role_experience": Array(session.role_experience),
		"role_attack_strength": Array(session.role_attack_strength),
		"role_magic_strength": Array(session.role_magic_strength),
		"role_defense": Array(session.role_defense),
		"role_dexterity": Array(session.role_dexterity),
		"role_flee_rate": Array(session.role_flee_rate),
		"role_equipments_by_role": _packed_matrix_to_data(session.role_equipments_by_role),
		"role_poison_resistance": Array(session.role_poison_resistance),
		"role_elemental_resistances_by_role": _packed_matrix_to_data(session.role_elemental_resistances_by_role),
		"role_status_rounds_by_role": _packed_matrix_to_data(session.role_status_rounds_by_role),
		"role_poisons_by_role": _dictionary_array_to_pairs(session.role_poisons_by_role),
		"learned_magics_by_role": _packed_matrix_to_data(session.learned_magics_by_role),
		"trail_positions": _vectors_to_data(session.trail_positions),
		"trail_directions": Array(session.trail_directions),
		"party_formation_collapsed": session.party_formation_collapsed,
	}


func _serialize_runtime_content() -> Dictionary:
	var scenes: Array = []
	for scene in _database.scenes:
		scenes.append([scene.map_number, scene.script_on_enter, scene.script_on_teleport, scene.event_object_index])
	var events: Array = []
	for event in _database.event_objects:
		events.append([
			event.vanish_time, event.position.x, event.position.y, event.layer,
			event.trigger_script, event.auto_script, event.state, event.trigger_mode,
			event.sprite_number, event.sprite_frames, event.direction, event.current_frame,
			event.script_idle_frame, event.sprite_pointer_offset, event.sprite_frames_auto,
			event.auto_script_idle_count,
		])
	var item_scripts: Array = []
	for item in _database.items:
		item_scripts.append([item.script_on_use, item.script_on_equip, item.script_on_throw])
	var magic_scripts: Array = []
	for magic in _database.magic_objects:
		magic_scripts.append([magic.script_on_success, magic.script_on_use])
	var enemy_scripts: Array = []
	for enemy in _database.enemy_objects:
		enemy_scripts.append([enemy.script_on_turn_start, enemy.script_on_battle_end, enemy.script_on_ready])
	return {
		"scenes": scenes,
		"events": events,
		"item_scripts": item_scripts,
		"magic_scripts": magic_scripts,
		"enemy_scripts": enemy_scripts,
		"player_scene_sprites": Array(_database.player_roles.scene_sprite_numbers),
	}


func _party_metadata(session: GameSession) -> Array:
	var result: Array = []
	for role_index in session.party_roles:
		result.append({
			"role_index": role_index,
			"level": session.role_levels[role_index] if role_index >= 0 and role_index < session.role_levels.size() else 0,
		})
	return result


func _validate_record(record: Dictionary) -> bool:
	if record.is_empty() or record.get("header") is not Dictionary or record.get("metadata") is not Dictionary or record.get("payload_json") is not String:
		error_message = "存档文件结构损坏"
		return false
	var header: Dictionary = record["header"]
	if not _is_integer(header.get("format_version")) or int(header["format_version"]) != FORMAT_VERSION:
		error_message = "存档版本不兼容：需要版本 %d" % FORMAT_VERSION
		return false
	if str(header.get("content_fingerprint", "")) != _content_fingerprint:
		error_message = "存档使用的 PAL 资源版本与当前导入内容不一致"
		return false
	var payload_json := str(record["payload_json"])
	var expected_checksum := str(record.get("payload_sha256", ""))
	if expected_checksum.is_empty() or expected_checksum != _sha256_text(payload_json):
		error_message = "存档校验和不匹配，文件可能已损坏"
		return false
	var payload = JSON.parse_string(payload_json)
	if payload is not Dictionary:
		error_message = "存档载荷不是有效 JSON 数据"
		return false
	if not _validate_metadata(record["metadata"]):
		return false
	if not _validate_session(payload.get("session")):
		return false
	if not _validate_runtime_content(payload.get("runtime_content")):
		return false
	return true


func _validate_metadata(value: Variant) -> bool:
	if value is not Dictionary:
		error_message = "存档摘要损坏"
		return false
	var metadata: Dictionary = value
	if not _is_integer(metadata.get("save_count")) or int(metadata["save_count"]) < 1 or str(metadata.get("saved_at", "")).is_empty():
		error_message = "存档摘要缺少保存次数或时间"
		return false
	if not _is_integer(metadata.get("scene_index")) or not _is_integer(metadata.get("map_number")) or metadata.get("party") is not Array:
		error_message = "存档摘要中的场景或队伍无效"
		return false
	for member in metadata["party"]:
		if member is not Dictionary or not _is_integer(member.get("role_index")) or not _is_integer(member.get("level")):
			error_message = "存档摘要中的队员信息损坏"
			return false
	return true


func _validate_session(value: Variant) -> bool:
	if value is not Dictionary:
		error_message = "存档中的游戏会话损坏"
		return false
	var data: Dictionary = value
	var scalar_keys := ["scene_index", "party_direction", "cash", "palette_index", "music_number", "battle_music_number", "battlefield_number", "music_volume", "sound_volume", "world_layer"]
	for key in scalar_keys:
		if not _is_integer(data.get(key)):
			error_message = "存档会话字段 %s 无效" % key
			return false
	if int(data["scene_index"]) < 0 or int(data["scene_index"]) >= _database.scenes.size() or int(data["party_direction"]) < GameSession.DIR_SOUTH or int(data["party_direction"]) > GameSession.DIR_EAST:
		error_message = "存档中的场景或队伍方向越界"
		return false
	if int(data["music_volume"]) < 0 or int(data["music_volume"]) > GameSession.AUDIO_VOLUME_MAX or int(data["sound_volume"]) < 0 or int(data["sound_volume"]) > GameSession.AUDIO_VOLUME_MAX:
		error_message = "存档中的音量设置越界"
		return false
	if data.get("night_palette") is not bool or data.get("party_formation_collapsed") is not bool or not _validate_vector(data.get("viewport_position")):
		error_message = "存档中的视口或布尔状态无效"
		return false
	if not _validate_int_array(data.get("party_roles"), 1, 3, 0, PalPlayerRoles.ROLE_COUNT - 1) or not _validate_int_array(data.get("party_script_frames"), 3, PalPlayerRoles.ROLE_COUNT, -1, 65535):
		error_message = "存档中的队伍角色或动作帧无效"
		return false
	if data.has("follower_sprite_numbers") and not _validate_int_array(data.get("follower_sprite_numbers"), 0, 2, 0, 0xffff):
		error_message = "存档中的跟随者 Sprite 无效"
		return false
	for optional_scalar in ["collect_value", "chase_speed_change_cycles", "chase_range_multiplier"]:
		if data.has(optional_scalar) and not _is_integer(data[optional_scalar]):
			error_message = "存档会话字段 %s 无效" % optional_scalar
			return false
	var role_array_keys := ["role_levels", "role_max_hp", "role_max_mp", "role_hp", "role_mp", "role_experience", "role_attack_strength", "role_magic_strength", "role_defense", "role_dexterity", "role_flee_rate", "role_poison_resistance"]
	for key in role_array_keys:
		if not _validate_int_array(data.get(key), PalPlayerRoles.ROLE_COUNT, PalPlayerRoles.ROLE_COUNT, 0, 0x7fffffff):
			error_message = "存档中的角色数组 %s 损坏" % key
			return false
	if not _validate_matrix(data.get("role_equipments_by_role"), PalPlayerRoles.ROLE_COUNT, GameSession.EQUIPMENT_SLOT_COUNT, 0, _database.items.size() - 1):
		error_message = "存档中的角色装备损坏"
		return false
	if not _validate_matrix(data.get("role_elemental_resistances_by_role"), PalPlayerRoles.ROLE_COUNT, PalPlayerRoles.ELEMENT_COUNT, 0, 0xffff) or not _validate_matrix(data.get("role_status_rounds_by_role"), PalPlayerRoles.ROLE_COUNT, GameSession.STATUS_COUNT, 0, 0xffff):
		error_message = "存档中的抗性或角色状态损坏"
		return false
	if not _validate_variable_matrix(data.get("learned_magics_by_role"), PalPlayerRoles.ROLE_COUNT, PalPlayerRoles.MAGIC_SLOT_COUNT, 0, _database.magic_objects.size() - 1):
		error_message = "存档中的已学仙术损坏"
		return false
	if not _validate_pairs(data.get("inventory"), 1, _database.items.size() - 1, 1, 0x7fffffff):
		error_message = "存档中的背包损坏"
		return false
	var poison_rows = data.get("role_poisons_by_role")
	if poison_rows is not Array or poison_rows.size() != PalPlayerRoles.ROLE_COUNT:
		error_message = "存档中的角色毒状态损坏"
		return false
	for row in poison_rows:
		if not _validate_pairs(row, 1, _database.poisons.size() - 1, 0, _database.scripts.size() - 1, GameSession.MAX_POISONS):
			error_message = "存档中的角色毒状态损坏"
			return false
	var trail = data.get("trail_positions")
	if trail is not Array or trail.size() != GameSession.TRAIL_SIZE:
		error_message = "存档中的队伍轨迹损坏"
		return false
	for position in trail:
		if not _validate_vector(position):
			error_message = "存档中的队伍轨迹坐标损坏"
			return false
	if not _validate_int_array(data.get("trail_directions"), GameSession.TRAIL_SIZE, GameSession.TRAIL_SIZE, GameSession.DIR_SOUTH, GameSession.DIR_EAST):
		error_message = "存档中的队伍轨迹方向损坏"
		return false
	return true


func _validate_runtime_content(value: Variant) -> bool:
	if value is not Dictionary:
		error_message = "存档中的剧情运行时状态损坏"
		return false
	var data: Dictionary = value
	if not _validate_matrix(data.get("scenes"), _database.scenes.size(), 4, -0x8000, 0xffff):
		error_message = "存档中的场景状态数量或字段不匹配"
		return false
	if not _validate_matrix(data.get("events"), _database.event_objects.size(), 16, -0x8000, 0xffff):
		error_message = "存档中的 EventObject 状态数量或字段不匹配"
		return false
	if not _validate_matrix(data.get("item_scripts"), _database.items.size(), 3, 0, _database.scripts.size() - 1) or not _validate_matrix(data.get("magic_scripts"), _database.magic_objects.size(), 2, 0, _database.scripts.size() - 1) or not _validate_matrix(data.get("enemy_scripts"), _database.enemy_objects.size(), 3, 0, _database.scripts.size() - 1):
		error_message = "存档中的对象脚本游标损坏"
		return false
	if not _validate_int_array(data.get("player_scene_sprites"), PalPlayerRoles.ROLE_COUNT, PalPlayerRoles.ROLE_COUNT, 0, 0xffff):
		error_message = "存档中的角色场景形象损坏"
		return false
	return true


func _restore_session(session: GameSession, data: Dictionary) -> void:
	session.scene_index = int(data["scene_index"])
	session.viewport_position = _vector_from_data(data["viewport_position"])
	session.party_direction = int(data["party_direction"])
	session.cash = int(data["cash"])
	session.palette_index = int(data["palette_index"])
	session.night_palette = bool(data["night_palette"])
	session.music_number = int(data["music_number"])
	session.battle_music_number = int(data["battle_music_number"])
	session.battlefield_number = int(data["battlefield_number"])
	session.music_volume = int(data["music_volume"])
	session.sound_volume = int(data["sound_volume"])
	session.world_layer = int(data["world_layer"])
	session.party_roles = _packed_from_data(data["party_roles"])
	session.follower_sprite_numbers = _packed_from_data(data.get("follower_sprite_numbers", []))
	session.collect_value = int(data.get("collect_value", 0))
	session.chase_speed_change_cycles = maxi(0, int(data.get("chase_speed_change_cycles", 0)))
	session.chase_range_multiplier = clampi(int(data.get("chase_range_multiplier", 1)), 0, 3)
	session.auto_battle_pending = false
	session.party_script_frames = _packed_from_data(data["party_script_frames"])
	session.inventory = _pairs_to_dictionary(data["inventory"])
	session.role_levels = _packed_from_data(data["role_levels"])
	session.role_max_hp = _packed_from_data(data["role_max_hp"])
	session.role_max_mp = _packed_from_data(data["role_max_mp"])
	session.role_hp = _packed_from_data(data["role_hp"])
	session.role_mp = _packed_from_data(data["role_mp"])
	session.role_experience = _packed_from_data(data["role_experience"])
	session.role_attack_strength = _packed_from_data(data["role_attack_strength"])
	session.role_magic_strength = _packed_from_data(data["role_magic_strength"])
	session.role_defense = _packed_from_data(data["role_defense"])
	session.role_dexterity = _packed_from_data(data["role_dexterity"])
	session.role_flee_rate = _packed_from_data(data["role_flee_rate"])
	session.role_equipments_by_role = _packed_matrix_from_data(data["role_equipments_by_role"])
	session.role_poison_resistance = _packed_from_data(data["role_poison_resistance"])
	session.role_elemental_resistances_by_role = _packed_matrix_from_data(data["role_elemental_resistances_by_role"])
	session.role_status_rounds_by_role = _packed_matrix_from_data(data["role_status_rounds_by_role"])
	session.role_poisons_by_role = _pairs_to_dictionary_array(data["role_poisons_by_role"])
	session.learned_magics_by_role = _packed_matrix_from_data(data["learned_magics_by_role"])
	session.trail_positions = _vectors_from_data(data["trail_positions"])
	session.trail_directions = _packed_from_data(data["trail_directions"])
	session.party_formation_collapsed = bool(data["party_formation_collapsed"])
	# 装备效果是当前装备和静态脚本的派生数据；读档后由 PalEquipmentManager 重建。
	session.clear_all_equipment_effects()


func _restore_runtime_content(data: Dictionary) -> void:
	for index in range(_database.scenes.size()):
		var row: Array = data["scenes"][index]
		var scene := _database.scenes[index]
		scene.map_number = int(row[0])
		scene.script_on_enter = int(row[1])
		scene.script_on_teleport = int(row[2])
		scene.event_object_index = int(row[3])
	for index in range(_database.event_objects.size()):
		var row: Array = data["events"][index]
		var event := _database.event_objects[index]
		event.vanish_time = int(row[0])
		event.position = Vector2i(int(row[1]), int(row[2]))
		event.layer = int(row[3])
		event.trigger_script = int(row[4])
		event.auto_script = int(row[5])
		event.state = int(row[6])
		event.trigger_mode = int(row[7])
		event.sprite_number = int(row[8])
		event.sprite_frames = int(row[9])
		event.direction = int(row[10])
		event.current_frame = int(row[11])
		event.script_idle_frame = int(row[12])
		event.sprite_pointer_offset = int(row[13])
		event.sprite_frames_auto = int(row[14])
		event.auto_script_idle_count = int(row[15])
	for index in range(_database.items.size()):
		var row: Array = data["item_scripts"][index]
		# OBJECT 是无类型联合体。通过统一入口恢复三个原始脚本字段，确保物品、
		# 仙术、敌人与毒四种解析视图在 0090 改写后仍保持一致。
		_database.set_object_script(index, 0, int(row[0]))
		_database.set_object_script(index, 1, int(row[1]))
		_database.set_object_script(index, 2, int(row[2]))
	for index in range(_database.magic_objects.size()):
		var row: Array = data["magic_scripts"][index]
		_database.magic_objects[index].script_on_success = int(row[0])
		_database.magic_objects[index].script_on_use = int(row[1])
	for index in range(_database.enemy_objects.size()):
		var row: Array = data["enemy_scripts"][index]
		_database.enemy_objects[index].script_on_turn_start = int(row[0])
		_database.enemy_objects[index].script_on_battle_end = int(row[1])
		_database.enemy_objects[index].script_on_ready = int(row[2])
	_database.player_roles.scene_sprite_numbers = _packed_from_data(data["player_scene_sprites"])


func _read_record(slot: int) -> Dictionary:
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		error_message = "无法读取存档 %d：%s" % [slot, error_string(FileAccess.get_open_error())]
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var parsed = parser.data if parse_error == OK else null
	if parsed is not Dictionary:
		error_message = "存档 %d 不是有效 JSON 文件%s" % [slot, "：%s" % parser.get_error_message() if parse_error != OK else ""]
		return {}
	return parsed


func _replace_file(temporary_path: String, destination_path: String) -> bool:
	var backup_path := destination_path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(destination_path):
		var backup_error := DirAccess.rename_absolute(destination_path, backup_path)
		if backup_error != OK:
			error_message = "无法备份旧存档：%s" % error_string(backup_error)
			DirAccess.remove_absolute(temporary_path)
			return false
	var rename_error := DirAccess.rename_absolute(temporary_path, destination_path)
	if rename_error != OK:
		error_message = "无法完成存档写入：%s" % error_string(rename_error)
		DirAccess.remove_absolute(temporary_path)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, destination_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return true


func _next_save_count() -> int:
	var highest := 0
	for slot in range(1, SLOT_COUNT + 1):
		var metadata := slot_metadata(slot)
		if bool(metadata.get("can_load", false)):
			highest = maxi(highest, int(metadata.get("save_count", 0)))
	return highest + 1


func _calculate_content_fingerprint() -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		error_message = "无法初始化内容指纹"
		return ""
	var separator := PackedByteArray()
	separator.append(0)
	for relative_path in CONTENT_FINGERPRINT_FILES:
		var path := _database.root_path.path_join(relative_path)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			error_message = "计算存档内容指纹时缺少：%s" % path
			return ""
		if context.update(relative_path.to_utf8_buffer()) != OK or context.update(separator) != OK or context.update(file.get_buffer(file.get_length())) != OK:
			error_message = "无法计算内容指纹：%s" % relative_path
			return ""
	return context.finish().hex_encode()


func _validate_slot(slot: int) -> bool:
	if not _slot_in_range(slot):
		error_message = "存档槽位必须在 1–%d 之间" % SLOT_COUNT
		return false
	if _database == null or _content_fingerprint.is_empty():
		error_message = "存档系统尚未配置"
		return false
	return true


func _slot_in_range(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floorf(value)))


static func _validate_vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _is_integer(value[0]) and _is_integer(value[1])


static func _validate_int_array(value: Variant, minimum_size: int, maximum_size: int, minimum_value: int, maximum_value: int) -> bool:
	if value is not Array or value.size() < minimum_size or value.size() > maximum_size:
		return false
	for element in value:
		if not _is_integer(element) or int(element) < minimum_value or int(element) > maximum_value:
			return false
	return true


static func _validate_matrix(value: Variant, rows: int, columns: int, minimum_value: int, maximum_value: int) -> bool:
	if value is not Array or value.size() != rows:
		return false
	for row in value:
		if not _validate_int_array(row, columns, columns, minimum_value, maximum_value):
			return false
	return true


static func _validate_variable_matrix(value: Variant, rows: int, maximum_columns: int, minimum_value: int, maximum_value: int) -> bool:
	if value is not Array or value.size() != rows:
		return false
	for row in value:
		if not _validate_int_array(row, 0, maximum_columns, minimum_value, maximum_value):
			return false
	return true


static func _validate_pairs(value: Variant, first_minimum: int, first_maximum: int, second_minimum: int, second_maximum: int, maximum_count: int = 0x7fffffff) -> bool:
	if value is not Array or value.size() > maximum_count:
		return false
	var seen: Dictionary = {}
	for pair in value:
		if pair is not Array or pair.size() != 2 or not _is_integer(pair[0]) or not _is_integer(pair[1]):
			return false
		var key := int(pair[0])
		var second := int(pair[1])
		if key < first_minimum or key > first_maximum or second < second_minimum or second > second_maximum or seen.has(key):
			return false
		seen[key] = true
	return true


static func _vector_to_data(value: Vector2i) -> Array:
	return [value.x, value.y]


static func _vector_from_data(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _vectors_to_data(values: Array[Vector2i]) -> Array:
	var result: Array = []
	for value in values:
		result.append(_vector_to_data(value))
	return result


static func _vectors_from_data(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(_vector_from_data(value))
	return result


static func _packed_from_data(values: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for value in values:
		result.append(int(value))
	return result


static func _packed_matrix_to_data(values: Array) -> Array:
	var result: Array = []
	for row in values:
		result.append(Array(row))
	return result


static func _packed_matrix_from_data(values: Array) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for row in values:
		result.append(_packed_from_data(row))
	return result


static func _dictionary_to_pairs(values: Dictionary) -> Array:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b))
	var result: Array = []
	for key in keys:
		result.append([int(key), int(values[key])])
	return result


static func _dictionary_array_to_pairs(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_dictionary_to_pairs(value))
	return result


static func _pairs_to_dictionary(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for pair in values:
		result[int(pair[0])] = int(pair[1])
	return result


static func _pairs_to_dictionary_array(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in values:
		result.append(_pairs_to_dictionary(row))
	return result


static func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()
