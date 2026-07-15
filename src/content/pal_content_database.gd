# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
class_name PalContentDatabase
extends RefCounted

# 原版脚本没有附带标题或肖像、但可由剧情明确确认的角色台词。
# 键为当前 DOS 数据集的 M.MSG 索引，值为 PLAYERROLES 角色索引。
const MESSAGE_SPEAKER_ROLE_OVERRIDES: Dictionary = {
	585: 0, # 李逍遥在客栈密道旁的“嘿嘿．．”
}

var root_path: String = "res://generated/pal/content"
var error_message: String = ""
var scenes: Array[PalSceneDefinition] = []
var event_objects: Array[PalEventObject] = []
var scripts: Array[PalScriptEntry] = []
var player_roles: PalPlayerRoles
var words: Array = []
var messages: Array = []
var source_encoding: String = ""
var _mgo_sprites: Dictionary = {}
var _rgm_portraits: Dictionary = {}


func load_generated(path: String = "res://generated/pal/content") -> bool:
	root_path = path
	error_message = ""
	scenes.clear()
	event_objects.clear()
	scripts.clear()
	player_roles = null
	words.clear()
	messages.clear()
	_mgo_sprites.clear()
	_rgm_portraits.clear()
	var core := root_path.path_join("core")
	var event_bytes := _read_file(core.path_join("event_objects.bin"))
	var scene_bytes := _read_file(core.path_join("scenes.bin"))
	var script_bytes := _read_file(core.path_join("scripts.bin"))
	if not error_message.is_empty():
		return false
	if event_bytes.size() % PalEventObject.BYTE_SIZE != 0 or scene_bytes.size() % PalSceneDefinition.BYTE_SIZE != 0 or script_bytes.size() % PalScriptEntry.BYTE_SIZE != 0:
		error_message = "生成数据库的结构长度不匹配"
		return false
	for offset in range(0, event_bytes.size(), PalEventObject.BYTE_SIZE):
		var event := PalEventObject.from_bytes(event_bytes, offset)
		event.object_id = event_objects.size() + 1
		event_objects.append(event)
	for offset in range(0, scene_bytes.size(), PalSceneDefinition.BYTE_SIZE):
		scenes.append(PalSceneDefinition.from_bytes(scene_bytes, offset))
	for offset in range(0, script_bytes.size(), PalScriptEntry.BYTE_SIZE):
		scripts.append(PalScriptEntry.from_bytes(script_bytes, offset))
	player_roles = PalPlayerRoles.from_bytes(_read_file(root_path.path_join("data/03.bin")))
	if player_roles == null or not player_roles.is_valid():
		error_message = player_roles.error_message if player_roles != null else "PLAYERROLES 数据缺失"
		return false
	_load_text_database()
	return not scenes.is_empty() and not scripts.is_empty()


func load_map(map_number: int) -> PalMapData:
	var bytes := _read_file(root_path.path_join("world/maps/%03d.map" % map_number))
	return PalMapData.from_bytes(bytes)


func load_map_tiles(map_number: int) -> PalSprite:
	var bytes := _read_file(root_path.path_join("world/tiles/%03d.gop" % map_number))
	return PalSprite.from_bytes(bytes)


func load_palette(index: int = 0, night: bool = false) -> PackedByteArray:
	return _read_file(root_path.path_join("palettes/%02d_%s.rgb" % [index, "night" if night else "day"]))


func load_mgo_sprite(sprite_number: int) -> PalSprite:
	if _mgo_sprites.has(sprite_number):
		return _mgo_sprites[sprite_number]
	var path := root_path.path_join("sprites/mgo/%03d.spr" % sprite_number)
	var file := FileAccess.open(path, FileAccess.READ)
	var sprite := PalSprite.from_bytes(file.get_buffer(file.get_length()) if file != null else PackedByteArray())
	_mgo_sprites[sprite_number] = sprite
	return sprite


func load_rgm_portrait(portrait_number: int) -> PalIndexedImage:
	if _rgm_portraits.has(portrait_number):
		return _rgm_portraits[portrait_number]
	var path := root_path.path_join("portraits/rgm/%03d.rle" % portrait_number)
	var file := FileAccess.open(path, FileAccess.READ)
	var portrait := RleDecoder.decode(file.get_buffer(file.get_length()) if file != null else PackedByteArray())
	_rgm_portraits[portrait_number] = portrait
	return portrait


func events_for_scene(scene_index: int) -> Array[PalEventObject]:
	var result: Array[PalEventObject] = []
	if scene_index < 0 or scene_index >= scenes.size():
		return result
	var start := scenes[scene_index].event_object_index
	var finish := event_objects.size()
	if scene_index + 1 < scenes.size():
		finish = scenes[scene_index + 1].event_object_index
	for index in range(start, mini(finish, event_objects.size())):
		result.append(event_objects[index])
	return result


func get_word(index: int) -> String:
	return str(words[index]) if index >= 0 and index < words.size() else ""


func get_message(index: int) -> String:
	return str(messages[index]) if index >= 0 and index < messages.size() else ""


static func speaker_role_for_message(index: int) -> int:
	return int(MESSAGE_SPEAKER_ROLE_OVERRIDES.get(index, -1))


func _load_text_database() -> void:
	var path := root_path.path_join("text/text.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	source_encoding = str(parsed.get("encoding", ""))
	words = parsed.get("words", [])
	messages = parsed.get("messages", [])


func _read_file(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error_message = "无法读取生成资源：%s" % path
		return PackedByteArray()
	return file.get_buffer(file.get_length())
