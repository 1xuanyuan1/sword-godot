# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 1920×1080 正式展示壳：经典模式运行 320×200，重制模式运行 384×216 的纯 2D SubViewport。
## 非地图场景仍固定在重制视野中央的 320×200 核心区，避免菜单、RNG 与过场被拉伸。
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
var _remaster_hud_root: Control
var _remaster_status_background: ColorRect
var _remaster_status_label: Label
var _remaster_location_toast: PanelContainer
var _remaster_location_label: Label
var _remaster_dialog_toast: PanelContainer
var _remaster_dialog_message: RichTextLabel
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


## 在 Shell 的 2D SubViewport 中替换场景；供 PalSceneRouter 调用。
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
	_layout_classic_scene()
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
		_remaster_hud.visible = _mode == MODE_REMASTER_2D
	_update_classic_rect()
	_layout_classic_scene()
	_sync_remaster_hud()


## 返回当前 Presentation Shell 的经典或高清 2D 展示模式。
func presentation_mode() -> int:
	return _mode


## 返回高清 2D 逻辑视口是否已按 384×216 正确创建。
func remaster_renderer_ready() -> bool:
	return _mode == MODE_REMASTER_2D and _classic_viewport != null and _classic_viewport.size == PalPresentationMetrics.REMASTER_LOGICAL_SIZE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _classic_container != null:
		_update_classic_rect()


func _process(_delta: float) -> void:
	_sync_remaster_hud()


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
	_build_remaster_hud()
	_update_classic_rect()


## 顶部状态和地点名不进入 384×216 SubViewport，直接按输出分辨率绘制，避免小字号先栅格化再放大。
func _build_remaster_hud() -> void:
	_remaster_hud_root = Control.new()
	_remaster_hud_root.name = "NativeHudRoot"
	_remaster_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaster_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_remaster_hud.add_child(_remaster_hud_root)

	_remaster_status_background = ColorRect.new()
	_remaster_status_background.name = "StatusBackground"
	_remaster_status_background.color = Color(0.02, 0.03, 0.06, 0.82)
	_remaster_status_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaster_hud_root.add_child(_remaster_status_background)
	_remaster_status_label = Label.new()
	_remaster_status_label.name = "StatusLabel"
	_remaster_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaster_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_remaster_status_label.add_theme_font_size_override("font_size", 40)
	_remaster_status_label.add_theme_color_override("font_color", Color("f8fafc"))
	_remaster_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_remaster_status_label.add_theme_constant_override("outline_size", 2)
	_remaster_hud_root.add_child(_remaster_status_label)

	_remaster_location_toast = PanelContainer.new()
	_remaster_location_toast.name = "LocationToast"
	_remaster_location_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var location_style := StyleBoxFlat.new()
	location_style.bg_color = Color(0, 0, 0, 0.88)
	location_style.border_color = Color("d6a85f")
	location_style.set_border_width_all(5)
	location_style.corner_radius_top_left = 10
	location_style.corner_radius_top_right = 10
	location_style.corner_radius_bottom_left = 10
	location_style.corner_radius_bottom_right = 10
	_remaster_location_toast.add_theme_stylebox_override("panel", location_style)
	_remaster_location_label = Label.new()
	_remaster_location_label.name = "LocationLabel"
	_remaster_location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaster_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remaster_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_remaster_location_label.add_theme_font_size_override("font_size", 50)
	_remaster_location_label.add_theme_color_override("font_color", Color.WHITE)
	_remaster_location_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_remaster_location_label.add_theme_constant_override("outline_size", 3)
	_remaster_location_toast.add_child(_remaster_location_label)
	_remaster_location_toast.hide()
	_remaster_hud_root.add_child(_remaster_location_toast)

	_remaster_dialog_toast = PanelContainer.new()
	_remaster_dialog_toast.name = "DialogToast"
	_remaster_dialog_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialog_toast_style := StyleBoxFlat.new()
	dialog_toast_style.bg_color = Color(0, 0, 0, 0.94)
	dialog_toast_style.corner_radius_top_left = 10
	dialog_toast_style.corner_radius_top_right = 10
	dialog_toast_style.corner_radius_bottom_left = 10
	dialog_toast_style.corner_radius_bottom_right = 10
	dialog_toast_style.content_margin_left = 30
	dialog_toast_style.content_margin_top = 20
	dialog_toast_style.content_margin_right = 30
	dialog_toast_style.content_margin_bottom = 20
	_remaster_dialog_toast.add_theme_stylebox_override("panel", dialog_toast_style)
	_remaster_dialog_message = RichTextLabel.new()
	_remaster_dialog_message.name = "Message"
	_remaster_dialog_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaster_dialog_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remaster_dialog_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_remaster_dialog_message.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_remaster_dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remaster_dialog_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_remaster_dialog_message.scroll_active = false
	_remaster_dialog_message.bbcode_enabled = false
	_remaster_dialog_message.clip_contents = true
	_remaster_dialog_message.add_theme_font_size_override("normal_font_size", 40)
	_remaster_dialog_message.add_theme_color_override("default_color", Color.WHITE)
	_remaster_dialog_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_remaster_dialog_message.add_theme_constant_override("outline_size", 3)
	_remaster_dialog_toast.add_child(_remaster_dialog_message)
	_remaster_dialog_toast.hide()
	_remaster_hud_root.add_child(_remaster_dialog_toast)


func _update_classic_rect() -> void:
	var output_size := Vector2i(roundi(size.x), roundi(size.y))
	if output_size.x <= 0 or output_size.y <= 0:
		output_size = PalPresentationMetrics.DEFAULT_REMASTER_CANVAS_SIZE
	var content_rect := (
		PalPresentationMetrics.remaster_content_rect(output_size)
		if _mode == MODE_REMASTER_2D
		else PalPresentationMetrics.classic_content_rect(output_size)
	)
	_classic_container.position = Vector2(content_rect.position)
	_classic_container.size = Vector2(content_rect.size)
	var logical_size := PalPresentationMetrics.logical_size(_mode == MODE_REMASTER_2D)
	_classic_container.stretch_shrink = maxi(1, content_rect.size.x / logical_size.x)
	_layout_remaster_hud(content_rect)


func _layout_remaster_hud(content_rect: Rect2i) -> void:
	if _remaster_hud_root == null:
		return
	var scale := float(content_rect.size.x) / float(PalPresentationMetrics.REMASTER_LOGICAL_SIZE.x)
	var core_origin := Vector2(content_rect.position) + Vector2(PalPresentationMetrics.REMASTER_CLASSIC_OFFSET) * scale
	_remaster_status_background.position = core_origin + Vector2(3, 3) * scale
	_remaster_status_background.size = Vector2(314, 20) * scale
	_remaster_status_label.position = core_origin + Vector2(6, 5) * scale
	_remaster_status_label.size = Vector2(308, 17) * scale
	_remaster_status_label.add_theme_font_size_override("font_size", maxi(8, roundi(8.0 * scale)))
	_remaster_status_label.add_theme_constant_override("outline_size", maxi(1, roundi(0.4 * scale)))
	_remaster_location_toast.position = core_origin + Vector2(104, 28) * scale
	_remaster_location_toast.size = Vector2(112, 24) * scale
	_remaster_location_toast.custom_minimum_size = Vector2(112, 24) * scale
	_remaster_location_label.add_theme_font_size_override("font_size", maxi(10, roundi(10.0 * scale)))
	_remaster_location_label.add_theme_constant_override("outline_size", maxi(1, roundi(0.6 * scale)))
	_remaster_dialog_toast.position = core_origin + Vector2(72, 84) * scale
	_remaster_dialog_toast.size = Vector2(176, 32) * scale
	_remaster_dialog_toast.custom_minimum_size = Vector2(176, 32) * scale
	_remaster_dialog_message.add_theme_font_size_override("normal_font_size", maxi(8, roundi(8.0 * scale)))
	_remaster_dialog_message.add_theme_constant_override("outline_size", maxi(1, roundi(0.6 * scale)))


func _sync_remaster_hud() -> void:
	if _remaster_hud == null or _remaster_status_background == null:
		return
	var available := _mode == MODE_REMASTER_2D and _classic_scene != null and _classic_scene.has_method("remaster_hud_state")
	if not available:
		_remaster_status_background.hide()
		_remaster_status_label.hide()
		_remaster_location_toast.hide()
		_remaster_dialog_toast.hide()
		return
	var state: Dictionary = _classic_scene.call("remaster_hud_state")
	var status_visible := bool(state.get("status_visible", false))
	_remaster_status_background.visible = status_visible
	_remaster_status_label.visible = status_visible
	_remaster_status_label.text = str(state.get("status_text", ""))
	_remaster_status_label.add_theme_color_override("font_color", state.get("status_color", Color("f8fafc")) as Color)
	_remaster_location_toast.visible = bool(state.get("location_visible", false))
	_remaster_location_label.text = str(state.get("location_text", ""))
	_remaster_dialog_toast.visible = bool(state.get("dialog_toast_visible", false))
	_remaster_dialog_message.text = str(state.get("dialog_toast_text", ""))
	_remaster_dialog_message.visible_characters = int(state.get("dialog_toast_visible_characters", -1))


## 地图探索场景主动消费 384×216 视野；其余经典场景只占中央 320×200 核心区。
func _layout_classic_scene() -> void:
	if _classic_scene == null:
		return
	var remaster_enabled := _mode == MODE_REMASTER_2D
	var uses_world_canvas := _classic_scene.has_method("set_remaster_canvas_enabled")
	if uses_world_canvas:
		_classic_scene.call("set_remaster_canvas_enabled", remaster_enabled)
	var scene_position := Vector2.ZERO
	var scene_size := Vector2(PalPresentationMetrics.CLASSIC_CONTENT_SIZE)
	if remaster_enabled and uses_world_canvas:
		scene_size = Vector2(PalPresentationMetrics.REMASTER_LOGICAL_SIZE)
	elif remaster_enabled:
		scene_position = Vector2(PalPresentationMetrics.REMASTER_CLASSIC_OFFSET)
	if _classic_scene is Control:
		var control := _classic_scene as Control
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.position = scene_position
		control.size = scene_size
	elif _classic_scene is Node2D:
		(_classic_scene as Node2D).position = scene_position
