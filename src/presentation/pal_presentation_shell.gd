# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 1920×1080 正式展示壳：运行 320×200 经典 SubViewport，并承载 HD-2D 世界与高清 HUD。
## 当前默认经典回退；切到高清时经典逻辑仍在 SubViewport 中作为权威运行路径。
class_name PalPresentationShell
extends Control

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")
const MODE_CLASSIC := 0
const MODE_HD2D := 1
const TECHNICAL_PREVIEW_ARGUMENT := "--pal-remaster-technical-preview"
const PRIVATE_ROOT_ARGUMENT_PREFIX := "--pal-remaster-private-root="
const FORCE_HD2D_ARGUMENT := "--pal-remaster-hd2d"
const DEBUG_CHECKPOINT_ARGUMENT_PREFIX := "--pal-debug-checkpoint="

@export_file("*.tscn") var initial_classic_scene := "res://scenes/main.tscn"

var _classic_container: SubViewportContainer
var _classic_viewport: SubViewport
var _classic_scene: Node
var _hd_world: PalHd2DWorld
var _hd_hud: CanvasLayer
var _classic_background: ColorRect
var _asset_resolver: PalRemasterAssetResolver
var _mode: int = MODE_CLASSIC


func _ready() -> void:
	_build_shell()
	var configured_mode := str(ProjectSettings.get_setting("presentation/default_mode", "classic"))
	var force_hd2d := FORCE_HD2D_ARGUMENT in OS.get_cmdline_user_args()
	set_presentation_mode(MODE_HD2D if force_hd2d or configured_mode == "hd2d" else MODE_CLASSIC)
	var opening_scene := initial_classic_scene
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(DEBUG_CHECKPOINT_ARGUMENT_PREFIX):
			var checkpoint_id := argument.trim_prefix(DEBUG_CHECKPOINT_ARGUMENT_PREFIX)
			if DebugCheckpoint.request(checkpoint_id):
				opening_scene = "res://scenes/map_explorer.tscn"
			else:
				push_warning("未知剧情检查点：%s" % checkpoint_id)
	if not opening_scene.is_empty():
		var result := open_classic_scene(opening_scene)
		if result != OK:
			push_error("无法打开经典启动场景 %s：%s" % [opening_scene, error_string(result)])


## 在 Shell 的 320×200 SubViewport 中替换经典场景；供 PalSceneRouter 调用。
func open_classic_scene(scene_path: String) -> Error:
	var packed := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN
	var instance := packed.instantiate()
	if instance == null:
		return ERR_CANT_CREATE
	if _classic_scene != null:
		_classic_viewport.remove_child(_classic_scene)
		_classic_scene.queue_free()
	_classic_scene = instance
	_classic_viewport.add_child(instance)
	call_deferred("_bind_snapshot_source")
	return OK


## 切换经典回退或 HD-2D 展示；两种模式始终由同一个经典 SubViewport 推进游戏逻辑。
func set_presentation_mode(mode: int) -> void:
	_mode = MODE_HD2D if mode == MODE_HD2D else MODE_CLASSIC
	_update_presentation_layers()


func _update_presentation_layers() -> void:
	var hd_available := _mode == MODE_HD2D and _hd_world != null and _hd_world.has_active_environment()
	if _classic_container != null:
		_classic_container.modulate.a = 0.0 if hd_available else 1.0
	if _classic_background != null:
		_classic_background.visible = not hd_available
	if _hd_world != null:
		_hd_world.visible = hd_available
	if _hd_hud != null:
		_hd_hud.visible = hd_available


## 返回当前经典回退或 HD-2D 模式编号。
func presentation_mode() -> int:
	return _mode


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _classic_container != null:
		_update_classic_rect()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hd_world = PalHd2DWorld.new()
	_hd_world.name = "HdWorldRoot"
	add_child(_hd_world)
	_hd_world.active_environment_changed.connect(_on_hd_environment_changed)
	_asset_resolver = PalRemasterAssetResolver.new()
	var user_arguments := OS.get_cmdline_user_args()
	var technical_preview := TECHNICAL_PREVIEW_ARGUMENT in user_arguments
	_asset_resolver.set_unapproved_preview_enabled(technical_preview or bool(ProjectSettings.get_setting("presentation/allow_unapproved_assets", false)))
	var private_roots := PackedStringArray()
	for argument in user_arguments:
		if argument.begins_with(PRIVATE_ROOT_ARGUMENT_PREFIX):
			private_roots.append(argument.trim_prefix(PRIVATE_ROOT_ARGUMENT_PREFIX))
	if not _asset_resolver.set_additional_remaster_roots(private_roots):
		push_warning("高清素材目录参数无效，将保持经典回退：%s" % _asset_resolver.error_message)
	if not _asset_resolver.reload():
		push_warning("高清素材清单加载失败，将使用经典或占位回退：%s" % _asset_resolver.error_message)
	_hd_world.configure_asset_resolver(_asset_resolver)
	_classic_background = ColorRect.new()
	_classic_background.name = "ClassicLetterboxBackground"
	_classic_background.color = Color.BLACK
	_classic_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_classic_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_classic_background)

	_classic_container = SubViewportContainer.new()
	_classic_container.name = "ClassicViewportContainer"
	_classic_container.stretch = true
	_classic_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_classic_container)
	_classic_viewport = SubViewport.new()
	_classic_viewport.name = "ClassicViewport"
	_classic_viewport.size = PalPresentationMetrics.CLASSIC_CONTENT_SIZE
	_classic_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_classic_viewport.gui_embed_subwindows = true
	_classic_container.add_child(_classic_viewport)

	_hd_hud = CanvasLayer.new()
	_hd_hud.name = "HdHud"
	_hd_hud.layer = 20
	add_child(_hd_hud)
	_update_classic_rect()


func _update_classic_rect() -> void:
	var output_size := Vector2i(roundi(size.x), roundi(size.y))
	if output_size.x <= 0 or output_size.y <= 0:
		output_size = PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE
	var classic_rect := PalPresentationMetrics.classic_content_rect(output_size)
	_classic_container.position = Vector2(classic_rect.position)
	_classic_container.size = Vector2(classic_rect.size)


func _bind_snapshot_source() -> void:
	if _classic_scene == null:
		return
	var tile_world := _classic_scene.find_child("PalTileMapWorld", true, false) as PalTileMapWorld
	if tile_world == null:
		_hd_world.clear_world()
		return
	var callback := Callable(self, "_on_presentation_snapshot_ready")
	if not tile_world.presentation_snapshot_ready.is_connected(callback):
		tile_world.presentation_snapshot_ready.connect(callback)
	if tile_world.latest_snapshot != null:
		_on_presentation_snapshot_ready(tile_world.latest_snapshot)


func _on_presentation_snapshot_ready(snapshot: PalWorldPresentationSnapshot) -> void:
	_hd_world.sync_snapshot(snapshot)


func _on_hd_environment_changed(_available: bool, _map_number: int) -> void:
	_update_presentation_layers()
