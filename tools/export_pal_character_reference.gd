# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 从玩家本地导入的 MGO/RGM 生成角色制作参考板；输出目录必须由调用者显式指定。
## 参考板只用于私有美术生产，不属于游戏运行资源或公开发布内容。
extends SceneTree

const CANVAS_SIZE := Vector2i(1536, 1024)
const PORTRAIT_PANEL := Rect2i(64, 64, 576, 576)
const SPRITE_PANEL := Rect2i(680, 64, 792, 896)
const DIRECTION_FRAME_INDICES := [0, 3, 6, 9]


func _init() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var sprite_number := int(options.get("sprite", 0))
	var portrait_number := int(options.get("portrait", 0))
	var output_path := str(options.get("out", ""))
	if sprite_number <= 0 or portrait_number <= 0 or output_path.is_empty():
		_fail("用法：--sprite=N --portrait=N --out=res://path/reference.png")
		return
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail(database.error_message)
		return
	var palette := database.load_palette(0, false)
	var sprite := database.load_mgo_sprite(sprite_number)
	var portrait := database.load_rgm_portrait(portrait_number)
	if not sprite.is_valid() or sprite.frame_count() <= DIRECTION_FRAME_INDICES[-1]:
		_fail("MGO Sprite %d 缺少四方向基准帧" % sprite_number)
		return
	if not portrait.is_valid() or palette.size() < PaletteDecoder.PALETTE_BYTES:
		_fail("RGM %d 或调色板不可用" % portrait_number)
		return

	var canvas := Image.create_empty(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("e9e1d2"))
	canvas.fill_rect(PORTRAIT_PANEL, Color("2a241f"))
	canvas.fill_rect(SPRITE_PANEL, Color("cfc3ae"))
	_blit_centered(canvas, portrait.to_rgba_image(palette), PORTRAIT_PANEL, 8)

	var frame_slots := [
		Rect2i(704, 104, 354, 808),
		Rect2i(1082, 104, 170, 380),
		Rect2i(1270, 104, 170, 380),
		Rect2i(1082, 532, 358, 380),
	]
	for index in range(DIRECTION_FRAME_INDICES.size()):
		var frame_index: int = DIRECTION_FRAME_INDICES[index]
		var frame := RleDecoder.decode(sprite.get_frame(frame_index))
		if not frame.is_valid():
			_fail("MGO Sprite %d 第 %d 帧解码失败" % [sprite_number, frame_index])
			return
		var scale := 12 if index == 0 else 6
		_blit_centered(canvas, frame.to_rgba_image(palette), frame_slots[index], scale)

	var absolute_path := ProjectSettings.globalize_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_fail("无法创建输出目录：%s" % error_string(directory_error))
		return
	var save_error := canvas.save_png(absolute_path)
	if save_error != OK:
		_fail("无法保存参考板：%s" % error_string(save_error))
		return
	print("PASS: MGO %d / RGM %d 角色参考板：%s" % [sprite_number, portrait_number, output_path])
	quit(0)


func _blit_centered(canvas: Image, source: Image, slot: Rect2i, scale: int) -> void:
	var scaled := source.duplicate()
	scaled.resize(source.get_width() * scale, source.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var position: Vector2i = slot.position + Vector2i((slot.size - scaled.get_size()) / 2)
	canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), position)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {}
	for argument in arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var separator := argument.find("=")
		result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
