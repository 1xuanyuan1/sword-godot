# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 1920×1080 正式展示壳：运行 320×200 经典 SubViewport，并承载逐步接入的高清 2D 世界与 HUD。
## 在高清 2D 渲染器完成前，重制模式必须安全回退经典画面。
class_name PalPresentationShell
extends Control

const DebugCheckpoint := preload("res://src/debug/pal_debug_checkpoint.gd")
const MODE_CLASSIC := 0
const MODE_REMASTER_2D := 1
const FORCE_REMASTER_2D_ARGUMENT := "--pal-remaster-2d"
const LEGACY_HD2D_ARGUMENT := "--pal-remaster-hd2d"
const DEBUG_CHECKPOINT_ARGUMENT_PREFIX := "--pal-debug-checkpoint="

@export_file("*.tscn") var initial_classic_scene := "res://scenes/main.tscn"

var _classic_container: SubViewportContainer
var _classic_viewport: SubViewport
var _classic_scene: Node
var _remaster_hud: CanvasLayer
var _classic_background: ColorRect
var _mode: int = MODE_CLASSIC


func _ready() -> void:
	_build_shell()
	var user_arguments := OS.get_cmdline_user_args()
	var configured_mode := str(ProjectSettings.get_setting("presentation/default_mode", "classic"))
	var force_remaster := FORCE_REMASTER_2D_ARGUMENT in user_arguments
	if LEGACY_HD2D_ARGUMENT in user_arguments:
		push_warning("--pal-remaster-hd2d 已退役；暂按 --pal-remaster-2d 处理")
		force_remaster = true
	set_presentation_mode(MODE_REMASTER_2D if force_remaster or configured_mode == "remaster_2d" else MODE_CLASSIC)
	var opening_scene := initial_classic_scene
	for argument in user_arguments:
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
	return OK


## 切换经典或高清 2D 展示。高清世界未就绪时始终保持经典回退可见。
func set_presentation_mode(mode: int) -> void:
	_mode = MODE_REMASTER_2D if mode == MODE_REMASTER_2D else MODE_CLASSIC
	_update_presentation_layers()


func _update_presentation_layers() -> void:
	if _classic_container != null:
		_classic_container.modulate.a = 1.0
		_classic_container.visible = true
	if _classic_background != null:
		_classic_background.visible = true
	if _remaster_hud != null:
		_remaster_hud.visible = false


func presentation_mode() -> int:
	return _mode


func remaster_renderer_ready() -> bool:
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _classic_container != null:
		_update_classic_rect()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	_remaster_hud = CanvasLayer.new()
	_remaster_hud.name = "RemasterHud"
	_remaster_hud.layer = 20
	add_child(_remaster_hud)
	_update_classic_rect()


func _update_classic_rect() -> void:
	var output_size := Vector2i(roundi(size.x), roundi(size.y))
	if output_size.x <= 0 or output_size.y <= 0:
		output_size = PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE
	var classic_rect := PalPresentationMetrics.classic_content_rect(output_size)
	_classic_container.position = Vector2(classic_rect.position)
	_classic_container.size = Vector2(classic_rect.size)
