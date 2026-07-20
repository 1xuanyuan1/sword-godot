# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从本机合法导入的 ABC.MKF/BALL.MKF 内容生成飞龙探云手图鉴缩略图。
## 输出仅写入 Git 忽略的 generated/pal/guide/，原版图像不会进入仓库。
extends SceneTree

const OUTPUT_ROOT := "res://generated/pal/guide/steal"


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var palette := database.load_palette(0, false)
	if palette.size() < 256 * 3:
		_fail("缺少图鉴需要的日间调色板")
		return
	var enemy_directory := ProjectSettings.globalize_path(OUTPUT_ROOT.path_join("enemies"))
	var item_directory := ProjectSettings.globalize_path(OUTPUT_ROOT.path_join("items"))
	DirAccess.make_dir_recursive_absolute(enemy_directory)
	DirAccess.make_dir_recursive_absolute(item_directory)

	var object_ids := _discover_enemy_objects(database)
	var item_ids: Dictionary = {}
	var enemy_count := 0
	for raw_object_id in object_ids:
		var object_id := int(raw_object_id)
		var enemy := database.enemy_definition_for_object(object_id)
		if enemy == null or enemy.steal_item_count <= 0:
			continue
		var sprite := database.load_enemy_battle_sprite(enemy.enemy_id)
		if not sprite.is_valid() or sprite.frame_count() <= 0:
			_fail("敌人对象 %d 缺少战斗 Sprite" % object_id)
			return
		var frame := RleDecoder.decode(sprite.get_frame(0))
		if not frame.is_valid() or frame.to_rgba_image(palette).save_png(enemy_directory.path_join("%03d.png" % object_id)) != OK:
			_fail("敌人对象 %d 的首帧缩略图生成失败" % object_id)
			return
		enemy_count += 1
		if enemy.steal_item > 0:
			item_ids[enemy.steal_item] = true

	for raw_item_id in item_ids:
		var item_id := int(raw_item_id)
		var item := database.item_definition(item_id)
		var bitmap := database.load_item_bitmap(item.bitmap) if item != null else null
		if bitmap == null or not bitmap.is_valid() or bitmap.to_rgba_image(palette).save_png(item_directory.path_join("%03d.png" % item_id)) != OK:
			_fail("物品对象 %d 的缩略图生成失败" % item_id)
			return
	if enemy_count != 135 or item_ids.size() != 72:
		_fail("图鉴缩略图数量不正确：敌人 %d/135，物品 %d/72" % [enemy_count, item_ids.size()])
		return
	print("PASS: 已从本机导入资源生成 135 张怪物图和 72 张物品图：%s" % ProjectSettings.globalize_path(OUTPUT_ROOT))
	quit(0)


func _discover_enemy_objects(database: PalContentDatabase) -> Dictionary:
	var result: Dictionary = {}
	for team in database.enemy_teams:
		if team == null:
			continue
		for object_id in team.active_object_ids():
			result[object_id] = true
	for entry in database.scripts:
		if entry.operation in [0x009e, 0x009f] and entry.operands[0] not in [0, 0xffff]:
			result[entry.operands[0]] = true
	return result


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
