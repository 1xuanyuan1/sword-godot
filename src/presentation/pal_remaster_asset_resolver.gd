# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 加载 Private 高清包与无脚本 MOD Manifest，并按固定优先级解析逻辑资源 ID。
## 解析失败只告警一次并尝试下一候选；调用方最终回退经典内容或合成占位资源。
class_name PalRemasterAssetResolver
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const SOURCE_PRIVATE := 10
const SOURCE_MOD := 20
const MOD_TYPES := ["portrait", "field_sprite", "voice", "ui_theme"]
const ASSET_TYPES := ["environment", "field_sprite", "portrait", "battlefield", "battle_action", "cutscene", "voice", "ui_theme"]
const TYPE_BY_PREFIX := {
	"map": "environment",
	"character": "field_sprite",
	"portrait": "portrait",
	"battlefield": "battlefield",
	"battle": "battle_action",
	"cutscene": "cutscene",
	"voice": "voice",
	"ui": "ui_theme",
}

## 成功解析的单个资源路径及来源信息。
class ResolvedAsset:
	var logical_id: String = ""
	var type: String = ""
	var path: String = ""
	var sha256: String = ""
	var pack_id: String = ""
	var source_tier: int = 0
	var priority: int = 0

class Candidate:
	var logical_id: String = ""
	var type: String = ""
	var relative_path: String = ""
	var sha256: String = ""
	var pack_root: String = ""
	var pack_id: String = ""
	var source_tier: int = 0
	var priority: int = 0

## 最近一次 Manifest 结构错误；缺失可选资源不会写入这里。
var error_message: String = ""

var _candidates: Dictionary = {}
var _reported_failures: Dictionary = {}
var _verify_files: bool = true
var _allow_unapproved: bool = false
var _failure_warnings_enabled: bool = true


## 清空旧索引并加载编辑器 Private 仓、用户高清包和 `user://mods`。
func reload() -> bool:
	_candidates.clear()
	_reported_failures.clear()
	error_message = ""
	var success := true
	var private_roots := PackedStringArray(["res://sword-assets"] if Engine.is_editor_hint() else ["user://remaster/assets"])
	for pack_root in private_roots:
		success = _load_remaster_directory(pack_root.path_join("manifests/remaster"), pack_root) and success
	success = _load_mod_directory("user://mods") and success
	return success


## 加入已解析的 Private 高清包 Manifest；整份清单先校验后原子注册。
func add_remaster_manifest_data(data: Dictionary, pack_root: String) -> bool:
	error_message = ""
	if not _has_only_keys(data, ["schema_version", "pack_id", "asset_version", "chapter", "generated_at", "assets"]):
		return _set_error("高清资源清单包含未声明字段")
	if str(data.get("schema_version", "")) != SCHEMA_VERSION:
		return _set_error("高清资源清单 schema_version 必须为 %s" % SCHEMA_VERSION)
	var pack_id := str(data.get("pack_id", ""))
	if not _is_pack_id(pack_id) or str(data.get("asset_version", "")).is_empty():
		return _set_error("高清资源清单缺少有效 pack_id 或 asset_version")
	var raw_assets = data.get("assets")
	if raw_assets is not Array:
		return _set_error("高清资源清单 assets 必须为数组")
	var pending: Array[Candidate] = []
	var seen: Dictionary = {}
	for raw_asset in raw_assets:
		if raw_asset is not Dictionary:
			return _set_error("高清资源清单包含非对象条目")
		if not _has_only_keys(raw_asset, ["id", "type", "path", "sha256", "chapter", "generation", "source_references", "review_status", "fallback_asset_id", "notes"]):
			return _set_error("高清资源包 %s 的条目包含未声明字段" % pack_id)
		var status := str(raw_asset.get("review_status", ""))
		if status not in ["draft", "generated", "technical_review", "approved", "rejected"]:
			return _set_error("高清资源包 %s 包含无效 review_status" % pack_id)
		if status != "approved" and not _allow_unapproved:
			continue
		var candidate := _candidate_from_asset(raw_asset, pack_root, pack_id)
		if candidate == null:
			return false
		if seen.has(candidate.logical_id):
			return _set_error("高清资源包 %s 重复声明 %s" % [pack_id, candidate.logical_id])
		seen[candidate.logical_id] = true
		pending.append(candidate)
	_register_candidates(pending)
	return true


## 加入已解析的无脚本 MOD Manifest；`enabled=false` 时安全跳过整包。
func add_mod_manifest_data(data: Dictionary, pack_root: String) -> bool:
	error_message = ""
	if not _has_only_keys(data, ["schema_version", "pack_id", "version", "priority", "enabled", "entries"]):
		return _set_error("MOD Manifest 包含未声明字段或脚本入口")
	if str(data.get("schema_version", "")) != SCHEMA_VERSION:
		return _set_error("MOD schema_version 必须为 %s" % SCHEMA_VERSION)
	if data.has("enabled") and not bool(data.get("enabled", false)):
		return true
	var pack_id := str(data.get("pack_id", ""))
	if not _is_pack_id(pack_id) or str(data.get("version", "")).is_empty():
		return _set_error("MOD 缺少有效 pack_id 或 version")
	var priority_value = data.get("priority")
	if priority_value is not int or int(priority_value) < -1000 or int(priority_value) > 1000:
		return _set_error("MOD %s 的 priority 必须在 -1000 到 1000" % pack_id)
	var raw_entries = data.get("entries")
	if raw_entries is not Array:
		return _set_error("MOD entries 必须为数组")
	var pending: Array[Candidate] = []
	var seen: Dictionary = {}
	for raw_entry in raw_entries:
		if raw_entry is not Dictionary:
			return _set_error("MOD %s 包含非对象条目" % pack_id)
		if not _has_only_keys(raw_entry, ["logical_id", "type", "path", "sha256"]):
			return _set_error("MOD %s 的条目包含未声明字段或脚本入口" % pack_id)
		var candidate := _candidate_from_mod(raw_entry, pack_root, pack_id, int(priority_value))
		if candidate == null:
			return false
		if seen.has(candidate.logical_id):
			return _set_error("MOD %s 重复声明 %s" % [pack_id, candidate.logical_id])
		seen[candidate.logical_id] = true
		pending.append(candidate)
	_register_candidates(pending)
	return true


## 按 MOD 优先级和 Private 包顺序解析逻辑 ID；无可用文件时返回 `null`。
func resolve(logical_id: String, expected_type: String = "") -> ResolvedAsset:
	var raw_candidates = _candidates.get(logical_id, [])
	if raw_candidates is not Array:
		return null
	var candidates: Array = raw_candidates.duplicate()
	candidates.sort_custom(func(left: Candidate, right: Candidate) -> bool:
		if left.source_tier != right.source_tier:
			return left.source_tier > right.source_tier
		return left.priority > right.priority
	)
	for raw_candidate in candidates:
		var candidate: Candidate = raw_candidate
		if not expected_type.is_empty() and candidate.type != expected_type:
			continue
		var resolved_path := candidate.pack_root.path_join(candidate.relative_path)
		if _verify_files and not _candidate_file_is_valid(candidate, resolved_path):
			continue
		var result := ResolvedAsset.new()
		result.logical_id = candidate.logical_id
		result.type = candidate.type
		result.path = resolved_path
		result.sha256 = candidate.sha256
		result.pack_id = candidate.pack_id
		result.source_tier = candidate.source_tier
		result.priority = candidate.priority
		return result
	return null


## 测试与清单预览可关闭文件存在性及哈希检查；正式运行保持默认开启。
func set_file_verification_enabled(enabled: bool) -> void:
	_verify_files = enabled


## 开发期可允许 generated/technical_review 条目参与预览；正式运行只接受 approved。
func set_unapproved_preview_enabled(enabled: bool) -> void:
	_allow_unapproved = enabled


## 自动测试可关闭预期的回退警告；正式运行默认每个失败原因只提示一次。
func set_failure_warnings_enabled(enabled: bool) -> void:
	_failure_warnings_enabled = enabled


func _candidate_from_asset(raw: Dictionary, pack_root: String, pack_id: String) -> Candidate:
	var logical_id := str(raw.get("id", ""))
	var asset_type := str(raw.get("type", ""))
	var relative_path := str(raw.get("path", ""))
	var sha256 := str(raw.get("sha256", ""))
	if not _logical_id_matches_type(logical_id, asset_type):
		_set_error("高清资源 %s 的类型 %s 与逻辑 ID 不匹配" % [logical_id, asset_type])
		return null
	if not _is_safe_relative_path(relative_path):
		_set_error("高清资源 %s 使用了不安全路径" % logical_id)
		return null
	if not _is_sha256(sha256):
		_set_error("高清资源 %s 缺少小写 SHA-256" % logical_id)
		return null
	var candidate := Candidate.new()
	candidate.logical_id = logical_id
	candidate.type = asset_type
	candidate.relative_path = relative_path
	candidate.sha256 = sha256
	candidate.pack_root = pack_root
	candidate.pack_id = pack_id
	candidate.source_tier = SOURCE_PRIVATE
	return candidate


func _candidate_from_mod(raw: Dictionary, pack_root: String, pack_id: String, priority: int) -> Candidate:
	var logical_id := str(raw.get("logical_id", ""))
	var asset_type := str(raw.get("type", ""))
	var relative_path := str(raw.get("path", ""))
	var sha256 := str(raw.get("sha256", ""))
	if asset_type not in MOD_TYPES or not _logical_id_matches_type(logical_id, asset_type):
		_set_error("MOD %s 的资源 %s 使用了禁止类型 %s" % [pack_id, logical_id, asset_type])
		return null
	if not _is_safe_relative_path(relative_path):
		_set_error("MOD %s 的资源 %s 使用了不安全路径" % [pack_id, logical_id])
		return null
	if not sha256.is_empty() and not _is_sha256(sha256):
		_set_error("MOD %s 的资源 %s SHA-256 无效" % [pack_id, logical_id])
		return null
	var candidate := Candidate.new()
	candidate.logical_id = logical_id
	candidate.type = asset_type
	candidate.relative_path = relative_path
	candidate.sha256 = sha256
	candidate.pack_root = pack_root
	candidate.pack_id = pack_id
	candidate.source_tier = SOURCE_MOD
	candidate.priority = priority
	return candidate


func _register_candidates(candidates: Array[Candidate]) -> void:
	for candidate in candidates:
		if not _candidates.has(candidate.logical_id):
			_candidates[candidate.logical_id] = []
		var values: Array = _candidates[candidate.logical_id]
		values.append(candidate)


func _load_remaster_directory(manifest_root: String, pack_root: String) -> bool:
	var directory := DirAccess.open(manifest_root)
	if directory == null:
		return true
	var success := true
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var data = _read_json(manifest_root.path_join(file_name))
		if data is Dictionary and data.has("assets"):
			success = add_remaster_manifest_data(data, pack_root) and success
	for child_name in directory.get_directories():
		success = _load_remaster_directory(manifest_root.path_join(child_name), pack_root) and success
	return success


func _load_mod_directory(mod_root: String) -> bool:
	var directory := DirAccess.open(mod_root)
	if directory == null:
		return true
	var success := true
	for child_name in directory.get_directories():
		var pack_root := mod_root.path_join(child_name)
		var data = _read_json(pack_root.path_join("manifest.json"))
		if data is Dictionary:
			success = add_mod_manifest_data(data, pack_root) and success
	return success


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _candidate_file_is_valid(candidate: Candidate, resolved_path: String) -> bool:
	if not FileAccess.file_exists(resolved_path):
		_report_once(resolved_path, "文件缺失")
		return false
	if candidate.sha256.is_empty():
		return true
	var actual := _file_sha256(resolved_path)
	if actual != candidate.sha256:
		_report_once(resolved_path, "SHA-256 不匹配")
		return false
	return true


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while file.get_position() < file.get_length():
		if context.update(file.get_buffer(mini(1024 * 1024, file.get_length() - file.get_position()))) != OK:
			return ""
	return context.finish().hex_encode()


func _report_once(path: String, reason: String) -> void:
	var key := "%s:%s" % [path, reason]
	if _reported_failures.has(key):
		return
	_reported_failures[key] = true
	if _failure_warnings_enabled:
		push_warning("高清资源回退：%s（%s）" % [path, reason])


func _set_error(message: String) -> bool:
	error_message = message
	return false


static func _logical_id_matches_type(logical_id: String, asset_type: String) -> bool:
	if asset_type not in ASSET_TYPES or logical_id.is_empty() or logical_id.contains("//"):
		return false
	var parts := logical_id.split("/", false)
	if parts.size() < 2 or not TYPE_BY_PREFIX.has(parts[0]):
		return false
	if TYPE_BY_PREFIX[parts[0]] != asset_type:
		return false
	match parts[0]:
		"map":
			return parts.size() == 3 and parts[2] == "environment"
		"character":
			return parts.size() == 3 and parts[2] == "field"
		"portrait", "battle", "cutscene":
			return parts.size() == 3
		"battlefield", "voice", "ui":
			return parts.size() == 2
	return false


static func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.to_utf8_buffer().find(0) >= 0:
		return false
	for part in path.split("/", false):
		if part == ".." or part == ".":
			return false
	return true


static func _is_pack_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if character.to_lower() not in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return value[0].to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789"


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _has_only_keys(data: Dictionary, allowed: Array[String]) -> bool:
	for key in data:
		if str(key) not in allowed:
			return false
	return true
