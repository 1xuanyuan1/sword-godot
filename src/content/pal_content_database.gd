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
var items: Array[PalItemDefinition] = []
var player_roles: PalPlayerRoles
var words: Array = []
var messages: Array = []
var source_encoding: String = ""
var _mgo_sprites: Dictionary = {}
var _rgm_portraits: Dictionary = {}
var _item_bitmaps: Dictionary = {}
var _ui_sprite: PalSprite
var _speaker_portrait_defaults: Dictionary = {}


func load_generated(path: String = "res://generated/pal/content") -> bool:
	root_path = path
	error_message = ""
	scenes.clear()
	event_objects.clear()
	scripts.clear()
	items.clear()
	player_roles = null
	words.clear()
	messages.clear()
	_mgo_sprites.clear()
	_rgm_portraits.clear()
	_item_bitmaps.clear()
	_ui_sprite = null
	_speaker_portrait_defaults.clear()
	var core := root_path.path_join("core")
	var event_bytes := _read_file(core.path_join("event_objects.bin"))
	var scene_bytes := _read_file(core.path_join("scenes.bin"))
	var script_bytes := _read_file(core.path_join("scripts.bin"))
	var object_bytes := _read_file(core.path_join("objects_dos.bin"))
	if not error_message.is_empty():
		return false
	if event_bytes.size() % PalEventObject.BYTE_SIZE != 0 or scene_bytes.size() % PalSceneDefinition.BYTE_SIZE != 0 or script_bytes.size() % PalScriptEntry.BYTE_SIZE != 0 or object_bytes.size() % PalItemDefinition.BYTE_SIZE != 0:
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
	for offset in range(0, object_bytes.size(), PalItemDefinition.BYTE_SIZE):
		items.append(PalItemDefinition.from_bytes(object_bytes, offset, items.size()))
	player_roles = PalPlayerRoles.from_bytes(_read_file(root_path.path_join("data/03.bin")))
	if player_roles == null or not player_roles.is_valid():
		error_message = player_roles.error_message if player_roles != null else "PLAYERROLES 数据缺失"
		return false
	_load_text_database()
	_build_speaker_portrait_defaults()
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


func load_ui_sprite() -> PalSprite:
	if _ui_sprite == null:
		_ui_sprite = PalSprite.from_bytes(_read_file(root_path.path_join("data/09.bin")))
	return _ui_sprite


func load_item_bitmap(bitmap_number: int) -> PalIndexedImage:
	if _item_bitmaps.has(bitmap_number):
		return _item_bitmaps[bitmap_number]
	var bytes := _read_file(root_path.path_join("items/ball/%03d.rle" % bitmap_number))
	var image := RleDecoder.decode(bytes)
	_item_bitmaps[bitmap_number] = image
	return image


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


func is_quoted_narration_start(index: int) -> bool:
	# DOS 文本用成对半角引号标记无角色的剧情叙述；续行只在末尾带结束引号。
	return get_message(index).strip_edges().begins_with("\"")


func item_definition(object_id: int) -> PalItemDefinition:
	return items[object_id] if object_id >= 0 and object_id < items.size() else null


static func speaker_role_for_message(index: int) -> int:
	return int(MESSAGE_SPEAKER_ROLE_OVERRIDES.get(index, -1))


func portrait_for_speaker(speaker: String) -> int:
	return int(_speaker_portrait_defaults.get(speaker, 0))


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


func _build_speaker_portrait_defaults() -> void:
	_speaker_portrait_defaults.clear()
	var portrait_counts: Dictionary = {}
	var current_portrait := 0
	for entry in scripts:
		match entry.operation:
			0x003c, 0x003d:
				current_portrait = entry.operands[0]
			0x003b, 0x003e, 0x0000, 0x0001, 0x0002, 0x0005, 0x0009, 0x008e:
				current_portrait = 0
			0xffff:
				if current_portrait <= 0:
					continue
				var text := get_message(entry.operands[0]).strip_edges()
				if not _is_speaker_title(text):
					continue
				var speaker := _speaker_name_from_title(text)
				if not portrait_counts.has(speaker):
					portrait_counts[speaker] = {}
				var counts: Dictionary = portrait_counts[speaker]
				counts[current_portrait] = int(counts.get(current_portrait, 0)) + 1
	for speaker in portrait_counts:
		var best_portrait := 0
		var best_count := -1
		var counts: Dictionary = portrait_counts[speaker]
		for portrait in counts:
			var count := int(counts[portrait])
			if count > best_count:
				best_portrait = int(portrait)
				best_count = count
		_speaker_portrait_defaults[speaker] = best_portrait


static func _is_speaker_title(text: String) -> bool:
	return text.ends_with(":") or text.ends_with("：") or text.ends_with("∶")


static func _speaker_name_from_title(text: String) -> String:
	return text.trim_suffix(":").trim_suffix("：").trim_suffix("∶")


func _read_file(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error_message = "无法读取生成资源：%s" % path
		return PackedByteArray()
	return file.get_buffer(file.get_length())
