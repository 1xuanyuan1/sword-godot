# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 本地生成内容的统一只读入口，负责解析静态结构并缓存 Sprite、肖像和 UI 图像。
## 玩家位置、背包等可变状态由 `GameSession` 持有，不应写入本数据库。
class_name PalContentDatabase
extends RefCounted

const PoisonDefinition := preload("res://src/content/pal_poison_definition.gd")

# 原版脚本没有附带标题或肖像、但可由剧情明确确认的角色台词。
# 键为当前 DOS 数据集的 M.MSG 索引，值为 PLAYERROLES 角色索引。
const MESSAGE_SPEAKER_ROLE_OVERRIDES: Dictionary = {
	585: 0, # 李逍遥在客栈密道旁的“嘿嘿．．”
	2514: 0, # 偷看少女洗澡后，李逍遥询问能否回头。
	2515: 0,
	2516: 0,
	2517: 0,
	2518: 0,
	2519: 0,
	2526: 0, # 少女现身后，李逍遥求饶。
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
## `DATA.MKF #0` 中的九格商店物品表。
var stores: Array[PalStoreDefinition] = []
## DOS OBJECT 表中的物品定义。
var items: Array[PalItemDefinition] = []
## DOS OBJECT 表按敌人结构解释后的定义；索引与对象编号一致。
var enemy_objects: Array[PalEnemyObjectDefinition] = []
## DOS OBJECT 表按仙术结构解释后的定义；索引与对象编号一致。
var magic_objects: Array[PalMagicObjectDefinition] = []
## DOS OBJECT 表按毒结构解释后的定义；索引与对象编号一致。
var poisons: Array = []
## `DATA.MKF #1` 中的敌人基础属性。
var enemies: Array[PalEnemyDefinition] = []
## `DATA.MKF #2` 中的敌队编组。
var enemy_teams: Array[PalEnemyTeam] = []
## `DATA.MKF #5` 中的战场效果表。
var battlefields: Array[PalBattlefield] = []
## `DATA.MKF #4` 中的仙术特效、类型、消耗和基础数值。
var magics: Array[PalMagicDefinition] = []
## `DATA.MKF #6/#14` 中的升级经验和按角色习得仙术规则。
var level_progression: PalLevelProgression
## `DATA.MKF #13` 中按敌人数排列的五槽站位矩阵。
var enemy_positions: PalBattlefield.EnemyPositions
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
var _enemy_battle_sprites: Dictionary = {}
var _player_battle_sprites: Dictionary = {}
var _magic_effect_sprites: Dictionary = {}
var _battle_backgrounds: Dictionary = {}
var _rgm_portraits: Dictionary = {}
var _item_bitmaps: Dictionary = {}
var _ui_sprite: PalSprite
var _speaker_portrait_defaults: Dictionary = {}
var _tilemap_scenes: Dictionary = {}
var _tilemap_manifest: Dictionary = {}
var _verified_tilemaps: Dictionary = {}
var _initial_event_auto_scripts: PackedInt32Array = PackedInt32Array()


## 从生成目录加载核心结构和文字数据库，并清空旧缓存。
## 任一必需文件缺失或结构长度错误时返回 `false`，原因写入 `error_message`。
func load_generated(path: String = "res://generated/pal/content") -> bool:
	root_path = path
	error_message = ""
	scenes.clear()
	event_objects.clear()
	scripts.clear()
	stores.clear()
	items.clear()
	enemy_objects.clear()
	magic_objects.clear()
	poisons.clear()
	enemies.clear()
	enemy_teams.clear()
	battlefields.clear()
	magics.clear()
	level_progression = null
	enemy_positions = null
	player_roles = null
	words.clear()
	messages.clear()
	item_descriptions.clear()
	_mgo_sprites.clear()
	_enemy_battle_sprites.clear()
	_player_battle_sprites.clear()
	_magic_effect_sprites.clear()
	_battle_backgrounds.clear()
	_rgm_portraits.clear()
	_item_bitmaps.clear()
	_ui_sprite = null
	_speaker_portrait_defaults.clear()
	_tilemap_scenes.clear()
	_tilemap_manifest.clear()
	_verified_tilemaps.clear()
	_initial_event_auto_scripts = PackedInt32Array()
	var core := root_path.path_join("core")
	var event_bytes := _read_file(core.path_join("event_objects.bin"))
	var scene_bytes := _read_file(core.path_join("scenes.bin"))
	var script_bytes := _read_file(core.path_join("scripts.bin"))
	var object_bytes := _read_file(core.path_join("objects_dos.bin"))
	var store_bytes := _read_file(root_path.path_join("data/00.bin"))
	var enemy_bytes := _read_file(root_path.path_join("data/01.bin"))
	var enemy_team_bytes := _read_file(root_path.path_join("data/02.bin"))
	var magic_bytes := _read_file(root_path.path_join("data/04.bin"))
	var battlefield_bytes := _read_file(root_path.path_join("data/05.bin"))
	var level_magic_bytes := _read_file(root_path.path_join("data/06.bin"))
	var enemy_position_bytes := _read_file(root_path.path_join("data/13.bin"))
	var level_experience_bytes := _read_file(root_path.path_join("data/14.bin"))
	if not error_message.is_empty():
		return false
	if event_bytes.size() % PalEventObject.BYTE_SIZE != 0 or scene_bytes.size() % PalSceneDefinition.BYTE_SIZE != 0 or script_bytes.size() % PalScriptEntry.BYTE_SIZE != 0 or object_bytes.size() % PalItemDefinition.BYTE_SIZE != 0 or store_bytes.size() % PalStoreDefinition.BYTE_SIZE != 0 or enemy_bytes.size() % PalEnemyDefinition.BYTE_SIZE != 0 or enemy_team_bytes.size() % PalEnemyTeam.BYTE_SIZE != 0 or magic_bytes.size() % PalMagicDefinition.BYTE_SIZE != 0 or battlefield_bytes.size() % PalBattlefield.BYTE_SIZE != 0:
		error_message = "生成数据库的结构长度不匹配"
		return false
	for offset in range(0, event_bytes.size(), PalEventObject.BYTE_SIZE):
		var event := PalEventObject.from_bytes(event_bytes, offset)
		event.object_id = event_objects.size() + 1
		event_objects.append(event)
		_initial_event_auto_scripts.append(event.auto_script)
	for offset in range(0, scene_bytes.size(), PalSceneDefinition.BYTE_SIZE):
		scenes.append(PalSceneDefinition.from_bytes(scene_bytes, offset))
	for offset in range(0, script_bytes.size(), PalScriptEntry.BYTE_SIZE):
		scripts.append(PalScriptEntry.from_bytes(script_bytes, offset))
	for offset in range(0, store_bytes.size(), PalStoreDefinition.BYTE_SIZE):
		stores.append(PalStoreDefinition.from_bytes(store_bytes, offset, stores.size()))
	for offset in range(0, object_bytes.size(), PalItemDefinition.BYTE_SIZE):
		var object_id := items.size()
		items.append(PalItemDefinition.from_bytes(object_bytes, offset, object_id))
		enemy_objects.append(PalEnemyObjectDefinition.from_bytes(object_bytes, offset, object_id))
		magic_objects.append(PalMagicObjectDefinition.from_bytes(object_bytes, offset, object_id))
		poisons.append(PoisonDefinition.from_bytes(object_bytes, offset, object_id))
	for offset in range(0, enemy_bytes.size(), PalEnemyDefinition.BYTE_SIZE):
		enemies.append(PalEnemyDefinition.from_bytes(enemy_bytes, offset, enemies.size()))
	for offset in range(0, enemy_team_bytes.size(), PalEnemyTeam.BYTE_SIZE):
		enemy_teams.append(PalEnemyTeam.from_bytes(enemy_team_bytes, offset, enemy_teams.size()))
	for offset in range(0, magic_bytes.size(), PalMagicDefinition.BYTE_SIZE):
		magics.append(PalMagicDefinition.from_bytes(magic_bytes, offset, magics.size()))
	for offset in range(0, battlefield_bytes.size(), PalBattlefield.BYTE_SIZE):
		battlefields.append(PalBattlefield.from_bytes(battlefield_bytes, offset, battlefields.size()))
	level_progression = PalLevelProgression.from_bytes(level_magic_bytes, level_experience_bytes)
	if not level_progression.is_valid():
		error_message = level_progression.error_message
		return false
	enemy_positions = PalBattlefield.EnemyPositions.from_bytes(enemy_position_bytes)
	if not enemy_positions.is_valid():
		error_message = enemy_positions.error_message
		return false
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


## 加载导入器为指定地图生成的 TileMapLayer 场景，并在本次运行中缓存资源。
## 文件缺失、格式过旧或资源损坏时返回 `null`，并提示用户重新导入 Data。
func load_tilemap_scene(map_number: int) -> PackedScene:
	if _tilemap_scenes.has(map_number):
		return _tilemap_scenes[map_number]
	if not _verify_tilemap_content(map_number):
		return null
	var path := root_path.path_join("world/tilemaps/%03d.tscn" % map_number)
	if not FileAccess.file_exists(path):
		error_message = "地图 %d 缺少 TileMapLayer 资源，请在资源实验室重新导入 Data" % map_number
		return null
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if scene == null:
		error_message = "地图 %d TileMapLayer 资源损坏：%s" % [map_number, path]
		return null
	_tilemap_scenes[map_number] = scene
	return scene


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


## 按 PLAYERROLES 当前的场景形象编号加载指定角色 Sprite。
## 角色换装或读档直接恢复 `scene_sprite_numbers` 后会立即解析新编号；无效角色返回无效 Sprite。
func load_player_scene_sprite(role_index: int) -> PalSprite:
	if player_roles == null:
		return PalSprite.new()
	var sprite_number := player_roles.scene_sprite_for(role_index)
	return load_mgo_sprite(sprite_number) if sprite_number > 0 else PalSprite.new()


## 按敌人属性编号读取并缓存 `ABC.MKF` 战斗 Sprite；缺失时返回无效对象。
func load_enemy_battle_sprite(enemy_id: int) -> PalSprite:
	if _enemy_battle_sprites.has(enemy_id):
		return _enemy_battle_sprites[enemy_id]
	var sprite := _load_generated_sprite(root_path.path_join("battle/sprites/enemies/%03d.spr" % enemy_id))
	_enemy_battle_sprites[enemy_id] = sprite
	return sprite


## 按 Sprite 编号读取并缓存 `F.MKF` 玩家战斗 Sprite；缺失时返回无效对象。
func load_player_battle_sprite(sprite_number: int) -> PalSprite:
	if _player_battle_sprites.has(sprite_number):
		return _player_battle_sprites[sprite_number]
	var sprite := _load_generated_sprite(root_path.path_join("battle/sprites/players/%03d.spr" % sprite_number))
	_player_battle_sprites[sprite_number] = sprite
	return sprite


## 按 FIRE.MKF 特效编号读取并缓存仙术 Sprite；未重新导入时返回无效对象。
func load_magic_effect_sprite(effect_number: int) -> PalSprite:
	if _magic_effect_sprites.has(effect_number):
		return _magic_effect_sprites[effect_number]
	var sprite := _load_generated_sprite(root_path.path_join("battle/sprites/magic/%03d.spr" % effect_number))
	_magic_effect_sprites[effect_number] = sprite
	return sprite


## 读取 320×200 战场索引背景；未重新导入或编号越界时返回无效图像。
func load_battle_background(battlefield_id: int) -> PalIndexedImage:
	if _battle_backgrounds.has(battlefield_id):
		return _battle_backgrounds[battlefield_id]
	var result := PalIndexedImage.new()
	var path := root_path.path_join("battle/backgrounds/%03d.idx" % battlefield_id)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error_message = "缺少战场背景 %d，请重新导入 Data" % battlefield_id
	else:
		result.indices = file.get_buffer(file.get_length())
		if result.indices.size() != 320 * 200:
			result.error_message = "战场背景 %d 长度错误" % battlefield_id
		else:
			result.width = 320
			result.height = 200
			result.opacity.resize(result.indices.size())
			result.opacity.fill(255)
	_battle_backgrounds[battlefield_id] = result
	return result


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


## 在重新载入场景前完成已经启动、且线性终点为“隐藏自身”的 NPC 离场脚本。
## 剧情切场景时可能来不及走完最后几步；若原样保留，旧 NPC 会在日后重入时重播离场并触发旧对白。
func complete_pending_event_departures(scene_index: int) -> int:
	var completed := 0
	for event in events_for_scene(scene_index):
		if event.state <= 0 or event.auto_script <= 0:
			continue
		var event_index := event.object_id - 1
		if event_index >= 0 and event_index < _initial_event_auto_scripts.size() and event.auto_script == _initial_event_auto_scripts[event_index]:
			# 原始场景自带的自动离场必须首次正常演出；这里只收束剧情运行时后来安装或已推进的路线。
			continue
		var completed_entry := _linear_self_hide_completion_entry(event.auto_script)
		if completed_entry <= 0:
			continue
		event.state = 0
		event.auto_script = completed_entry
		event.auto_script_idle_count = 0
		completed += 1
	return completed


func _linear_self_hide_completion_entry(entry_index: int) -> int:
	var cursor := entry_index
	var scanned := 0
	while cursor > 0 and cursor < scripts.size() and scanned < 64:
		var entry := scripts[cursor]
		match entry.operation:
			# 自动离场只允许等待、转向、走到目标和推进动作帧；遇到分支或副作用就不推断。
			0x0009, 0x000f, 0x0010, 0x0011, 0x007c, 0x0087:
				cursor += 1
			0x0049:
				if entry.operands[0] in [0, 0xffff] and entry.operands[1] == 0:
					return cursor + 1
				return 0
			_:
				return 0
		scanned += 1
	return 0


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


## 返回指定商店定义，编号越界时返回 `null`。
func store_definition(store_id: int) -> PalStoreDefinition:
	return stores[store_id] if store_id >= 0 and store_id < stores.size() else null


## 返回指定敌队定义，编号越界时返回 `null`。
func enemy_team_definition(team_id: int) -> PalEnemyTeam:
	return enemy_teams[team_id] if team_id >= 0 and team_id < enemy_teams.size() else null


## 返回 OBJECT 表中的敌人视图，编号越界时返回 `null`。
func enemy_object_definition(object_id: int) -> PalEnemyObjectDefinition:
	return enemy_objects[object_id] if object_id >= 0 and object_id < enemy_objects.size() else null


## 返回 OBJECT 表中的仙术视图，编号越界时返回 `null`。
func magic_object_definition(object_id: int) -> PalMagicObjectDefinition:
	return magic_objects[object_id] if object_id >= 0 and object_id < magic_objects.size() else null


## 按 OBJECT 联合体的 `rgwData[2 + field]` 同步修改所有解析视图，对应脚本 0090。
## DOS 对象没有显式类型标签，因此不能只更新当前调用方猜测的某一种视图。
func set_object_script(object_id: int, field: int, script_entry: int) -> bool:
	if object_id < 0 or object_id >= items.size() or field < 0 or field > 2:
		return false
	var item := items[object_id]
	var magic := magic_objects[object_id]
	var enemy := enemy_objects[object_id]
	var poison = poisons[object_id]
	match field:
		0:
			item.script_on_use = script_entry
			magic.script_on_success = script_entry
			enemy.script_on_turn_start = script_entry
			poison.player_script = script_entry
		1:
			item.script_on_equip = script_entry
			magic.script_on_use = script_entry
			enemy.script_on_battle_end = script_entry
		2:
			item.script_on_throw = script_entry
			enemy.script_on_ready = script_entry
			poison.enemy_script = script_entry
	return true


## 返回 OBJECT 表中的毒定义视图，编号越界时返回 `null`。
func poison_definition(object_id: int) -> RefCounted:
	return poisons[object_id] if object_id >= 0 and object_id < poisons.size() else null


## 通过仙术对象编号返回 DATA.MKF 属性；映射无效时返回 `null`。
func magic_definition_for_object(object_id: int) -> PalMagicDefinition:
	var object := magic_object_definition(object_id)
	return magics[object.magic_number] if object != null and object.magic_number >= 0 and object.magic_number < magics.size() else null


## 返回 OBJECT 表中第一个映射到指定 DATA.MKF 仙术记录的对象编号。
## 召唤仙术的 `effect_sprite` 实际保存第二段效果仙术编号，SDLPal 也从对象表头开始查找。
func magic_object_id_for_magic_number(magic_number: int) -> int:
	for object in magic_objects:
		if object != null and object.magic_number == magic_number:
			return object.object_id
	return 0


## 通过 OBJECT 敌人对象编号返回对应基础属性；映射无效时返回 `null`。
func enemy_definition_for_object(object_id: int) -> PalEnemyDefinition:
	var object := enemy_object_definition(object_id)
	return enemies[object.enemy_id] if object != null and object.enemy_id >= 0 and object.enemy_id < enemies.size() else null


## 返回指定战场效果定义，编号越界时返回 `null`。
func battlefield_definition(battlefield_id: int) -> PalBattlefield:
	return battlefields[battlefield_id] if battlefield_id >= 0 and battlefield_id < battlefields.size() else null


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


func _load_generated_sprite(path: String) -> PalSprite:
	var file := FileAccess.open(path, FileAccess.READ)
	return PalSprite.from_bytes(file.get_buffer(file.get_length()) if file != null else PackedByteArray())


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


func _verify_tilemap_content(map_number: int) -> bool:
	if _verified_tilemaps.has(map_number):
		return bool(_verified_tilemaps[map_number])
	if _tilemap_manifest.is_empty():
		var manifest_path := root_path.get_base_dir().path_join("manifest.json")
		var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
		var parsed = JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else null
		if parsed is not Dictionary or int(parsed.get("format_version", 0)) < PalImportReport.FORMAT_VERSION:
			error_message = "本地生成清单版本过旧或损坏，请在资源实验室重新导入 Data"
			return false
		_tilemap_manifest = parsed
	var tileset_report = _tilemap_manifest.get("files", {}).get("tileset_maps", {})
	var map_report = tileset_report.get("maps", {}).get(str(map_number), {})
	if not map_report is Dictionary or map_report.is_empty():
		error_message = "生成清单缺少地图 %d 的 TileSet 记录，请重新导入 Data" % map_number
		return false
	var map_hash := _file_sha256(root_path.path_join("world/maps/%03d.map" % map_number))
	var tile_hash := _file_sha256(root_path.path_join("world/tiles/%03d.gop" % map_number))
	if map_hash != str(map_report.get("map_sha256", "")) or tile_hash != str(map_report.get("gop_sha256", "")):
		error_message = "地图 %d 的 MAP/GOP 与 TileSet 内容指纹不一致，请重新导入 Data" % map_number
		_verified_tilemaps[map_number] = false
		return false
	_verified_tilemaps[map_number] = true
	return true


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(file.get_buffer(file.get_length())) != OK:
		return ""
	return context.finish().hex_encode()
