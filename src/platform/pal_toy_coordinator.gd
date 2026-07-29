# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 共享 Toy 功能编排器，让标题页和探索场景复用同一套云存档与排行榜流程。
class_name PalToyCoordinator
extends Node

## Toy App WebView 关闭是否成功；失败时调用方应使用常规 Godot 退出。
signal close_browser_finished(success: bool)

const ToyService := preload("res://src/platform/pal_toy_service.gd")

var _save_manager: PalSaveManager
var _menu: PalGameMenu
var _session: GameSession
var _service: PalToyService
var _download_slot: int = 1


## 绑定存档、菜单与会话，并开始检查 Toy SDK 能力。
func configure(save_manager: PalSaveManager, menu: PalGameMenu, session: GameSession) -> void:
	_save_manager = save_manager
	_menu = menu
	_session = session
	_service = ToyService.new()
	_service.name = "PalToyService"
	add_child(_service)
	_connect_menu()
	_connect_service()
	_service.initialize()


## 返回当前是否可以在菜单中展示 Toy 云端入口。
func is_available() -> bool:
	return _service != null and _service.is_available()


## 玩家完成一次本地保存后上报三个历史最高分。
func submit_scores() -> void:
	if _service != null:
		_service.submit_session_scores(_session)


## 优先请求 Toy App 关闭 WebView，不支持时通过信号让调用方回退。
func request_close_browser() -> void:
	if _service == null:
		close_browser_finished.emit(false)
		return
	_service.request_close_browser()


func _connect_menu() -> void:
	_menu.toy_cloud_state_requested.connect(_on_cloud_state_requested)
	_menu.toy_cloud_upload_requested.connect(_on_cloud_upload_requested)
	_menu.toy_cloud_download_requested.connect(_on_cloud_download_requested)
	_menu.toy_rank_requested.connect(_on_rank_requested)


func _connect_service() -> void:
	_service.availability_changed.connect(_on_availability_changed)
	_service.cloud_info_received.connect(_on_cloud_info_received)
	_service.cloud_upload_finished.connect(_on_cloud_upload_finished)
	_service.cloud_download_finished.connect(_on_cloud_download_finished)
	_service.rank_received.connect(_on_rank_received)
	_service.scores_submitted.connect(_on_scores_submitted)
	_service.close_finished.connect(func(success: bool) -> void: close_browser_finished.emit(success))


func _on_availability_changed(available: bool, message: String) -> void:
	_menu.configure_toy_features(available, message)


func _on_cloud_state_requested() -> void:
	if _service != null:
		_service.request_cloud_info()


func _on_cloud_upload_requested(slot: int) -> void:
	var save_text := _save_manager.export_slot_text(slot)
	if save_text.is_empty():
		_menu.notify_toy_cloud_operation(false, "上传失败：%s" % _save_manager.error_message)
		return
	_menu.set_toy_busy(true, "正在压缩并上传存档…")
	_service.upload_save(save_text, slot)


func _on_cloud_download_requested(slot: int) -> void:
	_download_slot = clampi(slot, 1, PalSaveManager.SLOT_COUNT)
	_menu.set_toy_busy(true, "正在下载并校验存档…")
	_service.download_save()


func _on_rank_requested(board: int) -> void:
	_menu.set_toy_busy(true, "正在读取排行榜…")
	_service.request_rank(board)


func _on_cloud_info_received(metadata: Dictionary, message: String) -> void:
	_menu.notify_toy_cloud_info(metadata, message)


func _on_cloud_upload_finished(success: bool, message: String) -> void:
	_menu.notify_toy_cloud_operation(success, message)
	if success:
		_service.request_cloud_info()
		_service.submit_session_scores(_session)


func _on_cloud_download_finished(success: bool, message: String, save_text: String) -> void:
	if success:
		success = _save_manager.import_slot_text(_download_slot, save_text)
		if not success:
			message = "云存档不兼容：%s" % _save_manager.error_message
	if success:
		_menu.configure_save_slots(_save_manager.slot_summaries(), _download_slot)
		message = "云存档已下载到槽位 %03d" % _download_slot
	_menu.notify_toy_cloud_operation(success, message)


func _on_rank_received(board: int, entries: Array, mine: Dictionary, message: String) -> void:
	_menu.notify_toy_rank(board, entries, mine, message)


func _on_scores_submitted(success: bool, message: String) -> void:
	if not success and not message.is_empty():
		_menu.notify_toy_score_error(message)
