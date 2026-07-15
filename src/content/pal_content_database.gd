# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 本地生成内容的统一只读入口，负责解析静态结构并缓存 Sprite、肖像和 UI 图像。
## 玩家位置、背包等可变状态由 `GameSession` 持有，不应写入本数据库。
class_name PalContentDatabase
extends RefCounted

# 原版脚本没有附带标题或肖像、但可由剧情明确确认的角色台词。
# 键为当前 DOS 数据集的 M.MSG 索引，值为 PLAYERROLES 角色索引。
const MESSAGE_SPEAKER_ROLE_OVERRIDES: Dictionary = {
	585: 0, # 李逍遥在客栈密道旁的“嘿嘿．．”
}

## 当前内容根目录，默认指向被 Git 忽略的本地导入产物。
var root_path: String = "res://generated/pal/content"
## 最近一次读取或结构校验失败原因。
var error_message: String = ""
## `SSS.MKF` 解析得到的全部剧情场景。
var scenes: Array[PalSceneDefinition] = []
## 全局事件对象数组；场景通过起止索引取得自己的区间。
var event_objects: Array[PalEventObject] = []
## `ScriptVM` 使用的完整脚本表。
var scripts: Array[PalScriptEntry] = []
## DOS OBJECT 表中的物品定义。
var items: Array[PalItemDefinition] = []
## 角色肖像、场景 Sprite、名字和步态字段。
var player_roles: PalPlayerRoles
## WORD.DAT 解码后的词条。
var words: Array = []
## M.MSG 解码后的消息行。
var messages: Array = []
## 可选 DESC.DAT 中按对象编号保存的说明。
var item_descriptions: Dictionary = {}
## 文本转换器实际识别的源编码。
var source_encoding: String = ""
var _mgo_sprites: Dictionary = {}
var _rgm_portraits: Dictionary = {}
var _item_bitmaps: Dictionary = {}
var _ui_sprite: PalSprite
var _speaker_portrait_defaults: Dictionary = {}


## 从生成目录加载核心结构和文字数据库，并清空旧缓存。
## 任一必需文件缺失或结构长度错误时返回 `false`，原因写入 `error_message`。
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
	item_descriptions.clear()
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


## 读取并解析指定编号的 64×128 PAL 地图。
func load_map(map_number: int) -> PalMapData:
	var bytes := _read_file(root_path.path_join("world/maps/%03d.map" % map_number))
	return PalMapData.from_bytes(bytes)


## 读取指定地图配套的 GOP 图块 Sprite 表。
func load_map_tiles(map_number: int) -> PalSprite:
	var bytes := _read_file(root_path.path_join("world/tiles/%03d.gop" % map_number))
	return PalSprite.from_bytes(bytes)


## 读取 256 色 RGB 调色板；`night` 为真时选择同编号的夜间版本。
func load_palette(index: int = 0, night: bool = false) -> PackedByteArray:
	return _read_file(root_path.path_join("palettes/%02d_%s.rgb" % [index, "night" if night else "day"]))


## 按编号读取并缓存 MGO 场景 Sprite；缺失时返回无效对象。
func load_mgo_sprite(sprite_number: int) -> PalSprite:
	if _mgo_sprites.has(sprite_number):
		return _mgo_sprites[sprite_number]
	var path := root_path.path_join("sprites/mgo/%03d.spr" % sprite_number)
	var file := FileAccess.open(path, FileAccess.READ)
	var sprite := PalSprite.from_bytes(file.get_buffer(file.get_length()) if file != null else PackedByteArray())
	_mgo_sprites[sprite_number] = sprite
	return sprite


## 按编号读取并缓存 RGM 对话肖像；缺失时返回无效索引图像。
func load_rgm_portrait(portrait_number: int) -> PalIndexedImage:
	if _rgm_portraits.has(portrait_number):
		return _rgm_portraits[portrait_number]
	var path := root_path.path_join("portraits/rgm/%03d.rle" % portrait_number)
	var file := FileAccess.open(path, FileAccess.READ)
	var portrait := RleDecoder.decode(file.get_buffer(file.get_length()) if file != null else PackedByteArray())
	_rgm_portraits[portrait_number] = portrait
	return portrait


## 返回 DATA.MKF 中包含窗口、光标和数字的经典 UI Sprite 表。
func load_ui_sprite() -> PalSprite:
	if _ui_sprite == null:
		_ui_sprite = PalSprite.from_bytes(_read_file(root_path.path_join("data/09.bin")))
	return _ui_sprite


## 按 BALL.MKF 分块编号读取并缓存物品图标。
func load_item_bitmap(bitmap_number: int) -> PalIndexedImage:
	if _item_bitmaps.has(bitmap_number):
		return _item_bitmaps[bitmap_number]
	var bytes := _read_file(root_path.path_join("items/ball/%03d.rle" % bitmap_number))
	var image := RleDecoder.decode(bytes)
	_item_bitmaps[bitmap_number] = image
	return image


## 返回属于指定场景的事件对象引用；脚本对这些对象的修改会保留在本次会话中。
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


## 返回 WORD 词条，越界时返回空字符串。
func get_word(index: int) -> String:
	return str(words[index]) if index >= 0 and index < words.size() else ""


## 返回 M.MSG 消息，越界时返回空字符串。
func get_message(index: int) -> String:
	return str(messages[index]) if index >= 0 and index < messages.size() else ""


## 返回对象说明；当前数据集没有 DESC.DAT 时可能为空。
func get_item_description(item_id: int) -> String:
	return str(item_descriptions.get(str(item_id), item_descriptions.get(item_id, "")))


## 判断消息是否以成对引号开启无角色剧情叙述。
func is_quoted_narration_start(index: int) -> bool:
	# DOS 文本用成对半角引号标记无角色的剧情叙述；续行只在末尾带结束引号。
	return get_message(index).strip_edges().begins_with("\"")


## 返回指定对象编号的物品定义，越界时返回 `null`。
func item_definition(object_id: int) -> PalItemDefinition:
	return items[object_id] if object_id >= 0 and object_id < items.size() else null


## 返回经人工剧情确认的无标题消息说话角色，未知时为 -1。
static func speaker_role_for_message(index: int) -> int:
	return int(MESSAGE_SPEAKER_ROLE_OVERRIDES.get(index, -1))


## 返回从原版脚本统计出的说话人默认肖像编号，未知时为 0。
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
	item_descriptions = parsed.get("object_descriptions", {})


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
