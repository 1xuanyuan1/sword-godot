# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal main.c and uigame.c.
# SPDX-License-Identifier: GPL-3.0-or-later
## 正式游戏启动入口：播放商标 RNG、山水标题动画，并显示原版“新的故事／旧的回忆”菜单。
## 本地内容缺失时自动进入资源实验室；F10 始终保留为开发入口。
class_name PalStartup
extends Control

const MobileInput := preload("res://src/ui/pal_mobile_input.gd")

const StartupRequest := preload("res://src/game/pal_startup_request.gd")
const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")
const PALETTE_SHADER: Shader = preload("res://shaders/indexed_palette.gdshader")

enum Phase {
	TRADEMARK,
	SPLASH,
	SPLASH_FADE,
	OPENING_MENU,
	FADE_TO_GAME,
}

const TRADEMARK_RNG := 6
const TRADEMARK_PALETTE := 3
const TRADEMARK_FPS := 25.0
const TRADEMARK_HOLD_SECONDS := 1.0
const TRADEMARK_FADE_SECONDS := 0.5
const SPLASH_TICK_SECONDS := 0.085
const SPLASH_PALETTE_FADE_SECONDS := 15.0
const SPLASH_EXIT_DELAY_SECONDS := 0.5
const OPENING_MENU_FADE_SECONDS := 0.6
const TITLE_MUSIC := 5
const OPENING_MENU_MUSIC := 4
const COLOR_NORMAL := 0x4f
const COLOR_SELECTED_FIRST := 0xf9
const MENU_POSITIONS := [Vector2i(125, 95), Vector2i(125, 112)]
const REQUIRED_STARTUP_FILES := [
	"content/battle/backgrounds/038.idx",
	"content/battle/backgrounds/039.idx",
	"content/battle/backgrounds/060.idx",
	"content/sprites/mgo/071.spr",
	"content/sprites/mgo/073.spr",
	"content/archives/rng.mkf",
	"audio/rix/004.wav",
	"audio/rix/005.wav",
]

var phase: Phase = Phase.TRADEMARK
var menu_selection: int = 0

var _database := PalContentDatabase.new()
var _session := GameSession.new()
var _save_manager := PalSaveManager.new()
var _save_menu: PalGameMenu
var _audio_player: Node
var _save_system_available: bool = false
var _startup_ready: bool = false
var _startup_error_message: String = ""

var _trademark_stream := RngPlaybackStream.new()
var _trademark_frame_count: int = 0
var _trademark_frame_index: int = 0
var _trademark_texture: ImageTexture
var _trademark_layer: Control
var _trademark_view: TextureRect
var _trademark_fade: ColorRect
var _trademark_material: ShaderMaterial
var _trademark_elapsed: float = 0.0
var _splash_elapsed: float = 0.0
var _splash_tick: int = 0
var _splash_exit_remaining: float = -1.0
var _split_position: int = 200
var _title_reveal_height: int = 0
var _cranes: Array[Dictionary] = []
var _transition_elapsed: float = 0.0
var _opening_menu_elapsed: float = OPENING_MENU_FADE_SECONDS

var _splash_up_texture: Texture2D
var _splash_down_texture: Texture2D
var _opening_menu_texture: Texture2D
var _title_texture: Texture2D
var _crane_textures: Array[Texture2D] = []
var _palette: PackedByteArray = PackedByteArray()
var _font_texture: Texture2D
var _font_glyphs: Dictionary = {}


func _ready() -> void:
	if _run_bundled_export_smoke():
		return
	if _run_desktop_export_smoke():
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_build_save_menu()
	_build_trademark_layer()
	var has_startup_content := _has_startup_content()
	var database_loaded := has_startup_content and _database.load_generated()
	if not has_startup_content or not database_loaded:
		if _startup_error_message.is_empty():
			_startup_error_message = _database.error_message
		push_error("正式启动资源检查失败，将进入资源实验室：%s" % _startup_error_message)
		call_deferred("_open_resource_lab")
		return
	_session.reset_new_game()
	_session.initialize_role_state(_database.player_roles)
	_save_system_available = _save_manager.configure(_database)
	_save_menu.configure(_database, _session)
	if _save_system_available:
		_save_menu.configure_save_slots(_save_manager.slot_summaries(), _save_manager.current_slot)
	_load_classic_resources()
	_audio_player = AudioPlayer.new()
	_audio_player.name = "PalStartupAudio"
	add_child(_audio_player)
	_audio_player.configure(_database, _session)
	_startup_ready = true
	if "--pal-skip-intro" in OS.get_cmdline_user_args():
		skip_to_opening_menu()
	else:
		_begin_trademark()


## 内置内容发布包的隐藏启动检查。导出 Android/Web 数据包后可在桌面 Godot 中挂载该包，
## 验证被替换成 `.sample` 的 WAV 仍可按原始 res:// 路径解析，而不依赖真机日志。
func _run_bundled_export_smoke() -> bool:
	if not "--pal-bundled-export-smoke" in OS.get_cmdline_user_args():
		return false
	var generated_root := PalRuntimePaths.EDITOR_GENERATED_ROOT
	var content_ready := _has_startup_content(generated_root)
	var database := PalContentDatabase.new()
	var database_loaded := content_ready and database.load_generated(generated_root.path_join("content"))
	var title_music := ResourceLoader.load(generated_root.path_join("audio/rix/005.wav"), "AudioStreamWAV", ResourceLoader.CACHE_MODE_REUSE) as AudioStreamWAV if content_ready else null
	var menu_music := ResourceLoader.load(generated_root.path_join("audio/rix/004.wav"), "AudioStreamWAV", ResourceLoader.CACHE_MODE_REUSE) as AudioStreamWAV if content_ready else null
	var audio_loaded := title_music != null and menu_music != null
	var success := content_ready and database_loaded and audio_loaded
	print("BUNDLED_EXPORT_SMOKE " + JSON.stringify({
		"success": success,
		"generated_root": generated_root,
		"content_ready": content_ready,
		"database_loaded": database_loaded,
		"audio_loaded": audio_loaded,
		"error": _startup_error_message if not _startup_error_message.is_empty() else database.error_message,
	}))
	get_tree().quit(0 if success else 1)
	return true


## 发布包门禁使用的隐藏启动检查：验证 user:// 可写且 PCK 内的导入辅助文件可释放。
## 只在显式传入 `--pal-desktop-smoke` 时运行，不改变普通玩家启动流程。
func _run_desktop_export_smoke() -> bool:
	var arguments := OS.get_cmdline_user_args()
	if not "--pal-desktop-smoke" in arguments:
		return false
	var report := PalImportReport.new()
	var tool_paths: Array[String] = []
	for relative_path in ["pal_text_convert.py", "rix_renderer/build.py", "rix_renderer/main.cpp", "rix_renderer/compat.h"]:
		var tool_path := PalDataImporter._materialize_import_tool(relative_path, report)
		if not tool_path.is_empty():
			tool_paths.append(tool_path)
	var generated_root := PalRuntimePaths.generated_root()
	var absolute_root := ProjectSettings.globalize_path(generated_root)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	var probe_path := generated_root.path_join(".desktop_write_test")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE) if directory_error == OK else null
	if probe != null:
		probe.store_string("ok")
		probe = null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	var success := (
		not OS.has_feature("editor")
		and generated_root == PalRuntimePaths.EXPORTED_GENERATED_ROOT
		and tool_paths.size() == 4
		and report.warnings.is_empty()
		and directory_error == OK
	)
	var import_source := ""
	for argument in arguments:
		if argument.begins_with("--pal-desktop-import="):
			import_source = argument.trim_prefix("--pal-desktop-import=").strip_edges()
			break
	var imported := false
	var database_loaded := false
	if success and not import_source.is_empty():
		report = PalDataImporter.import_from(import_source)
		imported = report.success
		var database := PalContentDatabase.new()
		database_loaded = imported and database.load_generated()
		success = imported and database_loaded
	print("DESKTOP_EXPORT_SMOKE " + JSON.stringify({
		"success": success,
		"platform": OS.get_name(),
		"generated_root": generated_root,
		"tool_count": tool_paths.size(),
		"imported": imported,
		"database_loaded": database_loaded,
		"import_errors": report.errors.size(),
		"warnings": report.warnings,
	}))
	get_tree().quit(0 if success else 1)
	return true


func _build_save_menu() -> void:
	_save_menu = PalGameMenu.new()
	_save_menu.name = "StartupSaveMenu"
	_save_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_menu.load_slot_requested.connect(_on_load_slot_requested)
	add_child(_save_menu)


func _build_trademark_layer() -> void:
	_trademark_layer = Control.new()
	_trademark_layer.name = "TrademarkLayer"
	_trademark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trademark_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trademark_view = TextureRect.new()
	_trademark_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trademark_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trademark_view.stretch_mode = TextureRect.STRETCH_SCALE
	_trademark_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trademark_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trademark_material = ShaderMaterial.new()
	_trademark_material.shader = PALETTE_SHADER
	_trademark_material.set_shader_parameter("palette_mix", 1.0)
	_trademark_material.set_shader_parameter("global_alpha", 1.0)
	_trademark_view.material = _trademark_material
	_trademark_layer.add_child(_trademark_view)
	_trademark_fade = ColorRect.new()
	_trademark_fade.color = Color(0, 0, 0, 0)
	_trademark_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trademark_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trademark_layer.add_child(_trademark_fade)
	_trademark_layer.hide()
	add_child(_trademark_layer)


func _has_startup_content(root_override: String = "") -> bool:
	_startup_error_message = ""
	var generated_root := PalRuntimePaths.generated_root() if root_override.is_empty() else root_override
	if not FileAccess.file_exists(generated_root.path_join("content/core/scenes.bin")):
		_startup_error_message = "缺少 content/core/scenes.bin"
		return false
	var manifest_file := FileAccess.open(generated_root.path_join("manifest.json"), FileAccess.READ)
	var manifest = JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else null
	if not manifest is Dictionary or int(manifest.get("format_version", 0)) < PalImportReport.FORMAT_VERSION:
		_startup_error_message = "manifest.json 缺失、损坏或版本过旧"
		return false
	for relative_path in REQUIRED_STARTUP_FILES:
		var resource_path := generated_root.path_join(relative_path)
		var exists := AudioPlayer.wav_resource_exists(resource_path) if relative_path.get_extension() == "wav" else FileAccess.file_exists(resource_path)
		if not exists:
			_startup_error_message = "缺少 %s" % relative_path
			return false
	return true


func _load_classic_resources() -> void:
	_palette = _database.load_palette(0, false)
	_splash_up_texture = _indexed_texture(_database.load_battle_background(38), _database.load_palette(1, false))
	_splash_down_texture = _indexed_texture(_database.load_battle_background(39), _database.load_palette(1, false))
	_opening_menu_texture = _indexed_texture(_database.load_battle_background(60), _palette)
	var splash_palette := _database.load_palette(1, false)
	var title_sprite := _database.load_mgo_sprite(71)
	_title_texture = _sprite_frame_texture(title_sprite, 0, splash_palette)
	var crane_sprite := _database.load_mgo_sprite(73)
	for frame_index in range(crane_sprite.frame_count()):
		_crane_textures.append(_sprite_frame_texture(crane_sprite, frame_index, splash_palette))
	var metadata_file := FileAccess.open(_database.root_path.path_join("text/font_glyphs.json"), FileAccess.READ)
	if metadata_file != null:
		var parsed = JSON.parse_string(metadata_file.get_as_text())
		if parsed is Dictionary:
			_font_glyphs = PalClassicFont.with_compatibility_aliases(parsed.get("glyphs", {}))
	var atlas_image := Image.load_from_file(ProjectSettings.globalize_path(_database.root_path.path_join("text/font_atlas.png")))
	if not atlas_image.is_empty():
		_font_texture = ImageTexture.create_from_image(atlas_image)
	_load_trademark_stream()


func _load_trademark_stream() -> void:
	_trademark_frame_count = 0
	if not _trademark_stream.configure(_database.root_path.path_join("archives/rng.mkf")):
		return
	_trademark_frame_count = _trademark_stream.animation_frame_count(TRADEMARK_RNG)
	var palette := _database.load_palette(TRADEMARK_PALETTE, false)
	if palette.size() >= PaletteDecoder.PALETTE_BYTES:
		var palette_image := Image.create_from_data(256, 1, false, Image.FORMAT_RGB8, palette)
		_trademark_material.set_shader_parameter("palette_texture", ImageTexture.create_from_image(palette_image))


func _begin_trademark() -> void:
	phase = Phase.TRADEMARK
	_trademark_elapsed = 0.0
	_trademark_frame_index = 0
	if _trademark_frame_count > 0 and _trademark_stream.open(TRADEMARK_RNG, 0, -1):
		_update_trademark_texture()
		_trademark_fade.color = Color(0, 0, 0, 0)
		_trademark_layer.show()
	else:
		_trademark_frame_count = 0
		_trademark_stream.close()
		_trademark_layer.hide()
	queue_redraw()


func _begin_splash() -> void:
	_trademark_layer.hide()
	_trademark_stream.close()
	_trademark_view.texture = null
	_trademark_texture = null
	phase = Phase.SPLASH
	_splash_elapsed = 0.0
	_splash_tick = 0
	_splash_exit_remaining = -1.0
	_split_position = 200
	_title_reveal_height = 0
	_cranes.clear()
	var random := RandomNumberGenerator.new()
	random.randomize()
	for index in range(9):
		_cranes.append({
			"x": random.randi_range(300, 600),
			"y": random.randi_range(0, 80),
			"frame": random.randi_range(0, 7),
		})
	_advance_splash_tick()
	_audio_player.play_music(TITLE_MUSIC, true, 2.0)
	queue_redraw()


## 直接显示正式标题菜单，供本地视觉回归和 `--pal-skip-intro` 使用。
func skip_to_opening_menu(fade_in: bool = false) -> void:
	if _audio_player == null:
		return
	phase = Phase.OPENING_MENU
	menu_selection = 0
	_splash_exit_remaining = -1.0
	_opening_menu_elapsed = 0.0 if fade_in else OPENING_MENU_FADE_SECONDS
	_audio_player.play_music(OPENING_MENU_MUSIC, true, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not _startup_ready:
		return
	match phase:
		Phase.TRADEMARK:
			_trademark_elapsed += delta
			var movie_seconds := float(_trademark_frame_count) / TRADEMARK_FPS
			if _trademark_frame_count > 0 and _trademark_elapsed < movie_seconds:
				var desired_frame := mini(_trademark_frame_count - 1, int(_trademark_elapsed * TRADEMARK_FPS))
				while _trademark_stream.frame_index < desired_frame and _trademark_stream.advance():
					_trademark_frame_index = _trademark_stream.frame_index
					_update_trademark_texture()
			var fade := clampf((_trademark_elapsed - movie_seconds - TRADEMARK_HOLD_SECONDS) / TRADEMARK_FADE_SECONDS, 0.0, 1.0)
			_trademark_fade.color = Color(0, 0, 0, fade)
			if _trademark_frame_count <= 0 or _trademark_elapsed >= movie_seconds + TRADEMARK_HOLD_SECONDS + TRADEMARK_FADE_SECONDS:
				_begin_splash()
		Phase.SPLASH:
			if _splash_exit_remaining >= 0.0:
				_splash_exit_remaining -= delta
				if _splash_exit_remaining <= 0.0:
					_begin_splash_fade()
			else:
				_splash_elapsed += delta
				while _splash_elapsed >= float(_splash_tick) * SPLASH_TICK_SECONDS:
					_advance_splash_tick()
		Phase.SPLASH_FADE:
			_transition_elapsed += delta
			if _transition_elapsed >= OPENING_MENU_FADE_SECONDS:
				skip_to_opening_menu(true)
		Phase.OPENING_MENU:
			_opening_menu_elapsed = minf(OPENING_MENU_FADE_SECONDS, _opening_menu_elapsed + delta)
		Phase.FADE_TO_GAME:
			_transition_elapsed += delta
			if _transition_elapsed >= OPENING_MENU_FADE_SECONDS:
				get_tree().change_scene_to_file("res://scenes/map_explorer.tscn")
	queue_redraw()


func _advance_splash_tick() -> void:
	if _split_position > 1:
		_split_position -= 1
	for index in range(_cranes.size()):
		var crane: Dictionary = _cranes[index]
		if not _crane_textures.is_empty():
			crane["frame"] = posmod(int(crane["frame"]) + (_splash_tick & 1), _crane_textures.size())
		if _split_position > 1 and (_split_position & 1) != 0:
			crane["y"] = int(crane["y"]) + 1
		crane["x"] = int(crane["x"]) - 1
		_cranes[index] = crane
	_title_reveal_height = mini(_title_texture.get_height() if _title_texture != null else 0, _title_reveal_height + 1)
	_splash_tick += 1


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or event is not InputEventKey:
		return
	if event.keycode == KEY_F10:
		_open_resource_lab()
		get_viewport().set_input_as_handled()
		return
	if _save_menu != null and _save_menu.visible:
		return
	match phase:
		Phase.SPLASH:
			if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_finish_splash()
				get_viewport().set_input_as_handled()
		Phase.OPENING_MENU:
			if _opening_menu_elapsed < OPENING_MENU_FADE_SECONDS:
				return
			match event.keycode:
				KEY_UP, KEY_LEFT:
					menu_selection = posmod(menu_selection - 1, 2)
				KEY_DOWN, KEY_RIGHT:
					menu_selection = posmod(menu_selection + 1, 2)
				KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					_confirm_opening_menu()
				KEY_ESCAPE:
					_start_game(0)
				_:
					return
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _save_menu.visible or not MobileInput.is_primary_press(event):
		return
	if phase == Phase.SPLASH:
		_finish_splash()
		accept_event()
		return
	if phase != Phase.OPENING_MENU or _opening_menu_elapsed < OPENING_MENU_FADE_SECONDS:
		return
	var point := Vector2i(MobileInput.pointer_position(event))
	for index in range(MENU_POSITIONS.size()):
		if Rect2i(MENU_POSITIONS[index] - Vector2i(3, 2), Vector2i(86, 18)).has_point(point):
			menu_selection = index
			_confirm_opening_menu()
			accept_event()
			return


func _finish_splash() -> void:
	_split_position = 1
	_title_reveal_height = _title_texture.get_height() if _title_texture != null else 0
	_splash_elapsed = SPLASH_PALETTE_FADE_SECONDS
	_splash_exit_remaining = SPLASH_EXIT_DELAY_SECONDS


func _begin_splash_fade() -> void:
	phase = Phase.SPLASH_FADE
	_transition_elapsed = 0.0
	_audio_player.play_music(0, false, OPENING_MENU_FADE_SECONDS)
	queue_redraw()


func _confirm_opening_menu() -> void:
	if menu_selection == 0:
		_start_game(0)
	elif _save_system_available:
		_save_menu.configure_save_slots(_save_manager.slot_summaries(), _save_manager.current_slot)
		_save_menu.open_load_slots(true)


func _on_load_slot_requested(slot: int) -> void:
	if StartupRequest.request_load_slot(slot):
		_save_menu.close_menu()
		_start_game(slot)


func _start_game(slot: int) -> void:
	if slot <= 0:
		StartupRequest.consume_load_slot()
	phase = Phase.FADE_TO_GAME
	_transition_elapsed = 0.0
	_audio_player.play_music(0, false, OPENING_MENU_FADE_SECONDS)
	queue_redraw()


func _open_resource_lab() -> void:
	if _audio_player != null:
		_audio_player.stop_all()
	get_tree().change_scene_to_file("res://scenes/import_lab.tscn")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	match phase:
		Phase.TRADEMARK:
			pass
		Phase.SPLASH:
			_draw_splash()
		Phase.SPLASH_FADE:
			_draw_splash()
			var splash_fade := clampf(_transition_elapsed / OPENING_MENU_FADE_SECONDS, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, splash_fade))
		Phase.OPENING_MENU, Phase.FADE_TO_GAME:
			_draw_opening_menu()
			if phase == Phase.OPENING_MENU and _opening_menu_elapsed < OPENING_MENU_FADE_SECONDS:
				var opening_alpha := 1.0 - clampf(_opening_menu_elapsed / OPENING_MENU_FADE_SECONDS, 0.0, 1.0)
				draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, opening_alpha))
			elif phase == Phase.FADE_TO_GAME:
				var alpha := clampf(_transition_elapsed / OPENING_MENU_FADE_SECONDS, 0.0, 1.0)
				draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, alpha))


func _update_trademark_texture() -> void:
	var indexed := _trademark_stream.current_indexed_image()
	if not indexed.is_valid():
		return
	var image := indexed.to_index_alpha_image()
	if _trademark_texture == null:
		_trademark_texture = ImageTexture.create_from_image(image)
	else:
		_trademark_texture.update(image)
	_trademark_view.texture = _trademark_texture


func _draw_splash() -> void:
	var brightness := 1.0 if _splash_exit_remaining >= 0.0 else clampf(_splash_elapsed / SPLASH_PALETTE_FADE_SECONDS, 0.0, 1.0)
	var modulate := Color(brightness, brightness, brightness, 1.0)
	if _splash_up_texture != null and _split_position < 200:
		var upper_height := 200 - _split_position
		draw_texture_rect_region(_splash_up_texture, Rect2(0, 0, 320, upper_height), Rect2(0, _split_position, 320, upper_height), modulate)
	if _splash_down_texture != null and _split_position > 0:
		draw_texture_rect_region(_splash_down_texture, Rect2(0, 200 - _split_position, 320, _split_position), Rect2(0, 0, 320, _split_position), modulate)
	for crane in _cranes:
		var frame_index := int(crane.get("frame", 0))
		if frame_index >= 0 and frame_index < _crane_textures.size() and _crane_textures[frame_index] != null:
			draw_texture(_crane_textures[frame_index], Vector2(int(crane.get("x", 0)), int(crane.get("y", 0))), modulate)
	if _title_texture != null and _title_reveal_height > 0:
		var reveal := mini(_title_reveal_height, _title_texture.get_height())
		draw_texture_rect_region(_title_texture, Rect2(255, 10, _title_texture.get_width(), reveal), Rect2(0, 0, _title_texture.get_width(), reveal), modulate)


func _draw_opening_menu() -> void:
	if _opening_menu_texture != null:
		draw_texture_rect(_opening_menu_texture, Rect2(Vector2.ZERO, size), false)
	for index in range(2):
		var color_index := COLOR_SELECTED_FIRST + int(Time.get_ticks_msec() / 100) % 6 if index == menu_selection else COLOR_NORMAL
		_draw_pal_text(_database.get_word(7 + index), MENU_POSITIONS[index], _palette_color(color_index), true)


func _draw_pal_text(text: String, position: Vector2i, color: Color, shadow: bool = false) -> void:
	if shadow:
		_draw_pal_glyphs(text, position + Vector2i(1, 1), Color(0, 0, 0, 0.9))
	_draw_pal_glyphs(text, position, color)


func _draw_pal_glyphs(text: String, position: Vector2i, color: Color) -> void:
	if _font_texture == null or _font_glyphs.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(position + Vector2i(0, 13)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		return
	var x := position.x
	for character in text:
		var key := str(character)
		if _font_glyphs.has(key):
			var values: Array = _font_glyphs[key]
			var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			draw_texture_rect_region(_font_texture, Rect2(Vector2(x, position.y), region.size), region, color)
			x += 16
		else:
			draw_string(ThemeDB.fallback_font, Vector2(x, position.y + 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			x += 8


func _indexed_texture(indexed: PalIndexedImage, palette: PackedByteArray) -> Texture2D:
	return ImageTexture.create_from_image(indexed.to_rgba_image(palette)) if indexed != null and indexed.is_valid() and not palette.is_empty() else null


func _sprite_frame_texture(sprite: PalSprite, frame_index: int, palette: PackedByteArray) -> Texture2D:
	if sprite == null or not sprite.is_valid() or frame_index < 0 or frame_index >= sprite.frame_count():
		return null
	return _indexed_texture(RleDecoder.decode(sprite.get_frame(frame_index)), palette)


func _palette_color(index: int) -> Color:
	if index < 0 or _palette.size() < (index + 1) * 3:
		return Color.WHITE
	return Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2])
