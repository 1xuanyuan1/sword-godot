# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## Toy JS SDK 桥接：负责单云存档分块协议、排行榜和 B 站 WebView 关闭。
class_name PalToyService
extends Node

## Toy SDK 加载或能力检查完成时发出。
signal availability_changed(available: bool, message: String)
## 返回云存档清单摘要；不存在时 `metadata` 为空。
signal cloud_info_received(metadata: Dictionary, message: String)
## 云存档全部分块与最终清单写入完成时发出。
signal cloud_upload_finished(success: bool, message: String)
## 云存档下载、解压与 SHA-256 校验完成时发出。
signal cloud_download_finished(success: bool, message: String, save_text: String)
## 指定榜位的前五名和当前玩家名次读取完成时发出。
signal rank_received(board: int, entries: Array, mine: Dictionary, message: String)
## 三个榜位的历史最高分上报完成时发出。
signal scores_submitted(success: bool, message: String)
## B 站 WebView 关闭请求结束时发出；容器成功关闭时可能不再回调。
signal close_finished(success: bool)

const CLOUD_PROTOCOL_VERSION := 1
const CLOUD_ENCODING := "gzip-base64"
const CLOUD_CHUNK_SIZE := 960
const CLOUD_MAX_CHUNKS := 120
const SCORE_MIN := -16_777_216
const SCORE_MAX := 16_777_215

const BRIDGE_SOURCE := """
(() => {
  if (window.SwordPalToyBridge) return;
  const manifestKey = "pal-save-v1-manifest";
  const chunkKey = (index) => `pal-save-v1-${String(index).padStart(3, "0")}`;
  const errorText = (error) => String(error && error.message ? error.message : error);
  const finish = (callback, task) => {
    Promise.resolve()
      .then(task)
      .then((result) => callback(JSON.stringify(result)))
      .catch((error) => callback(JSON.stringify({ success: false, error: errorText(error) })));
  };
  const requireToy = () => {
    if (!window.toy) throw new Error("Toy SDK 未加载");
    return window.toy;
  };
  const readManifest = async (toy) => {
    const values = await toy.getCloudStorage([manifestKey]);
    if (!values[manifestKey]) return null;
    try {
      return JSON.parse(values[manifestKey]);
    } catch (_error) {
      throw new Error("云存档清单已损坏");
    }
  };

  window.SwordPalToyBridge = {
    available() {
      return Boolean(window.toy);
    },

    checkAbilities(callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const preview = (window.location?.pathname || "").includes("/toy/preview/");
        const names = [
          "getCloudStorage", "setCloudStorage", "removeCloudStorage",
          "submitScore", "getRankList", "getMyRank", "closeBrowser"
        ];
        const supported = {};
        for (const name of names) {
          try {
            supported[name] = await toy.isSupport(name);
          } catch (_error) {
            supported[name] = false;
          }
        }
        return {
          success: true,
          preview,
          cloud: supported.getCloudStorage && supported.setCloudStorage && supported.removeCloudStorage,
          rank: supported.submitScore && supported.getRankList && supported.getMyRank,
          closeBrowser: supported.closeBrowser,
          supported,
        };
      });
    },

    getCloudInfo(callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const manifest = await readManifest(toy);
        return { success: true, manifest };
      });
    },

    uploadCloud(manifestText, chunksText, callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const manifest = JSON.parse(manifestText);
        const chunks = JSON.parse(chunksText);
        if (!Array.isArray(chunks) || chunks.length < 1 || chunks.length > 120) {
          throw new Error("云存档分块数越界");
        }
        const oldManifest = await readManifest(toy);
        const items = {};
        chunks.forEach((chunk, index) => {
          if (typeof chunk !== "string" || new TextEncoder().encode(chunk).length > 1024) {
            throw new Error(`云存档分块 ${index} 超出 1KB`);
          }
          items[chunkKey(index)] = chunk;
        });

		// 先写完全部数据分块并清理旧尾块，最后更新清单；下载端永远以清单为准。
		await toy.setCloudStorage(items);
		const oldCount = Number(oldManifest && oldManifest.chunks) || 0;
		if (oldCount > chunks.length) {
		  const stale = [];
		  for (let index = chunks.length; index < oldCount; index += 1) stale.push(chunkKey(index));
		  if (stale.length) await toy.removeCloudStorage(stale);
		}
		await toy.setCloudStorage({ [manifestKey]: manifestText });
		return { success: true, manifest };
      });
    },

    downloadCloud(callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const manifest = await readManifest(toy);
        if (!manifest) throw new Error("云端还没有存档");
        const count = Number(manifest.chunks);
        if (!Number.isInteger(count) || count < 1 || count > 120) {
          throw new Error("云存档清单中的分块数无效");
        }
        const keys = Array.from({ length: count }, (_value, index) => chunkKey(index));
        const values = await toy.getCloudStorage(keys);
        const chunks = keys.map((key) => {
          if (typeof values[key] !== "string") throw new Error(`云存档缺少分块 ${key}`);
          return values[key];
        });
        return { success: true, manifest, data: chunks.join("") };
      });
    },

    getRanks(board, callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const entries = await toy.getRankList({ board, period: "all", limit: 5 });
        let mine = {};
        let mineError = "";
        try {
          mine = await toy.getMyRank({ board, period: "all" });
        } catch (error) {
          mineError = errorText(error);
        }
        return { success: true, board, entries, mine, mineError };
      });
    },

    submitScores(scoresText, callback) {
      finish(callback, async () => {
        const toy = requireToy();
        const scores = JSON.parse(scoresText);
        const submitted = {};
        for (const board of [1, 2, 3]) {
          const result = await toy.submitScore({ board, score: Number(scores[String(board)]) });
          submitted[String(board)] = result.score;
        }
        return { success: true, submitted };
      });
    },

    closeBrowser(callback) {
      finish(callback, async () => {
        const toy = requireToy();
        if (!(await toy.isSupport("closeBrowser"))) return { success: false, unsupported: true };
        await toy.closeBrowser();
        return { success: true };
      });
    },
  };
})();
"""

var _bridge: JavaScriptObject
var _sdk_loaded: bool = false
var _available: bool = false
var _preview_host: bool = false
var _cloud_supported: bool = false
var _rank_supported: bool = false
var _close_supported: bool = false
var _availability_callback: JavaScriptObject
var _cloud_info_callback: JavaScriptObject
var _cloud_upload_callback: JavaScriptObject
var _cloud_download_callback: JavaScriptObject
var _rank_callback: JavaScriptObject
var _scores_callback: JavaScriptObject
var _close_callback: JavaScriptObject


## 初始化 Web 桥接并异步检查 Toy 云存储、排行榜和关闭容器能力。
func initialize() -> void:
	if not OS.has_feature("web"):
		availability_changed.emit(false, "Toy SDK 仅在 Web 发布中可用")
		return
	JavaScriptBridge.eval(BRIDGE_SOURCE, true)
	_bridge = JavaScriptBridge.get_interface("SwordPalToyBridge")
	if _bridge == null or not bool(_bridge.available()):
		availability_changed.emit(false, "Toy SDK 未加载")
		return
	_sdk_loaded = true
	_available = false
	availability_changed.emit(false, "正在检查 Toy 能力…")
	_availability_callback = JavaScriptBridge.create_callback(_on_availability_result)
	_bridge.checkAbilities(_availability_callback)


## 返回当前页面是否已加载 Toy SDK。
func is_available() -> bool:
	return _available


## 返回云存档读写能力是否通过 `isSupport` 检查。
func cloud_supported() -> bool:
	return _cloud_supported


## 返回排行榜能力是否通过 `isSupport` 检查。
func rank_supported() -> bool:
	return _rank_supported


## 读取云存档清单，不下载数据分块。
func request_cloud_info() -> void:
	if not _available or _bridge == null:
		cloud_info_received.emit({}, "Toy 云存档不可用")
		return
	if _preview_host:
		cloud_info_received.emit({}, "预览模式：正式页面将连接云存档")
		return
	_cloud_info_callback = JavaScriptBridge.create_callback(_on_cloud_info_result)
	_bridge.getCloudInfo(_cloud_info_callback)


## 压缩并上传一份已通过 `PalSaveManager` 校验的存档文本。
func upload_save(save_text: String, source_slot: int) -> void:
	if not _available or not _cloud_supported:
		cloud_upload_finished.emit(false, "Toy 云存档不可用")
		return
	var payload := build_cloud_payload(save_text, source_slot)
	if not bool(payload.get("success", false)):
		cloud_upload_finished.emit(false, str(payload.get("error", "无法压缩存档")))
		return
	_cloud_upload_callback = JavaScriptBridge.create_callback(_on_cloud_upload_result)
	_bridge.uploadCloud(
		JSON.stringify(payload["manifest"], "", false),
		JSON.stringify(payload["chunks"], "", false),
		_cloud_upload_callback
	)


## 下载、解压并校验当前 Toy 下的单一云存档。
func download_save() -> void:
	if not _available or not _cloud_supported:
		cloud_download_finished.emit(false, "Toy 云存档不可用", "")
		return
	_cloud_download_callback = JavaScriptBridge.create_callback(_on_cloud_download_result)
	_bridge.downloadCloud(_cloud_download_callback)


## 读取指定榜位的总榜前五名和当前用户名次。
func request_rank(board: int) -> void:
	board = clampi(board, 1, 3)
	if not _available:
		rank_received.emit(board, [], {}, "Toy 排行榜不可用")
		return
	if _preview_host:
		rank_received.emit(board, [], {}, "预览模式：正式页面将显示排行榜")
		return
	if not _rank_supported:
		rank_received.emit(board, [], {}, "Toy 排行榜不可用")
		return
	_rank_callback = JavaScriptBridge.create_callback(_on_rank_result)
	_bridge.getRanks(board, _rank_callback)


## 上报三个只保留历史最高值的榜位分数。
func submit_session_scores(session: GameSession) -> void:
	if not _available or not _rank_supported:
		return
	_scores_callback = JavaScriptBridge.create_callback(_on_scores_result)
	_bridge.submitScores(JSON.stringify(scores_for_session(session), "", false), _scores_callback)


## 在 B 站 App WebView 内请求关闭当前容器；不支持时通知调用方回退到 Godot 退出。
func request_close_browser() -> void:
	if not _sdk_loaded:
		close_finished.emit(false)
		return
	_close_callback = JavaScriptBridge.create_callback(_on_close_result)
	_bridge.closeBrowser(_close_callback)


## 把存档 JSON 经 gzip + Base64 压缩为满足 Toy 1KB/value 上限的分块和清单。
static func build_cloud_payload(save_text: String, source_slot: int) -> Dictionary:
	var record = JSON.parse_string(save_text)
	if record is not Dictionary or record.get("header") is not Dictionary or record.get("metadata") is not Dictionary:
		return {"success": false, "error": "存档不是有效的版本化 JSON"}
	var raw := save_text.to_utf8_buffer()
	var compressed := raw.compress(FileAccess.COMPRESSION_GZIP)
	if compressed.is_empty():
		return {"success": false, "error": "gzip 压缩失败"}
	var encoded := Marshalls.raw_to_base64(compressed)
	var chunks: Array[String] = []
	for offset in range(0, encoded.length(), CLOUD_CHUNK_SIZE):
		chunks.append(encoded.substr(offset, CLOUD_CHUNK_SIZE))
	if chunks.is_empty() or chunks.size() > CLOUD_MAX_CHUNKS:
		return {"success": false, "error": "存档压缩后需要 %d 个分块，超出 Toy 云存储容量" % chunks.size()}
	var header: Dictionary = record["header"]
	var metadata: Dictionary = record["metadata"]
	var manifest := {
		"protocol": CLOUD_PROTOCOL_VERSION,
		"encoding": CLOUD_ENCODING,
		"chunks": chunks.size(),
		"raw_size": raw.size(),
		"compressed_size": compressed.size(),
		"sha256": _sha256(raw),
		"format_version": int(header.get("format_version", 0)),
		"content_fingerprint": str(header.get("content_fingerprint", "")),
		"saved_at": str(metadata.get("saved_at", "")),
		"scene_index": int(metadata.get("scene_index", -1)),
		"source_slot": source_slot,
	}
	return {"success": true, "manifest": manifest, "chunks": chunks}


## 把 Toy 返回的 Base64 分块还原为原始存档文本，并校验大小与 SHA-256。
static func decode_cloud_payload(encoded: String, manifest: Dictionary) -> Dictionary:
	if int(manifest.get("protocol", 0)) != CLOUD_PROTOCOL_VERSION or str(manifest.get("encoding", "")) != CLOUD_ENCODING:
		return {"success": false, "error": "云存档协议版本不兼容"}
	var raw_size := int(manifest.get("raw_size", 0))
	if raw_size <= 0 or raw_size > 4 * 1024 * 1024:
		return {"success": false, "error": "云存档原始大小无效"}
	var compressed := Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		return {"success": false, "error": "云存档 Base64 数据损坏"}
	var raw := compressed.decompress(raw_size, FileAccess.COMPRESSION_GZIP)
	if raw.size() != raw_size:
		return {"success": false, "error": "云存档 gzip 解压失败"}
	if _sha256(raw) != str(manifest.get("sha256", "")):
		return {"success": false, "error": "云存档 SHA-256 校验失败"}
	return {"success": true, "save_text": raw.get_string_from_utf8()}


## 根据当前会话生成三个排行榜绝对分数：李逍遥等级、当前队伍等级之和、持有金钱。
static func scores_for_session(session: GameSession) -> Dictionary:
	if session == null:
		return {"1": 0, "2": 0, "3": 0}
	var leader_level := session.role_levels[0] if not session.role_levels.is_empty() else 0
	var party_total := 0
	var seen: Dictionary = {}
	for role_index in session.party_roles:
		if seen.has(role_index):
			continue
		seen[role_index] = true
		if role_index >= 0 and role_index < session.role_levels.size():
			party_total += session.role_levels[role_index]
	return {
		"1": clampi(leader_level, SCORE_MIN, SCORE_MAX),
		"2": clampi(party_total, SCORE_MIN, SCORE_MAX),
		"3": clampi(session.cash, SCORE_MIN, SCORE_MAX),
	}


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _parse_callback(arguments: Array) -> Dictionary:
	if arguments.is_empty():
		return {"success": false, "error": "Toy SDK 未返回结果"}
	var parsed = JSON.parse_string(str(arguments[0]))
	return parsed if parsed is Dictionary else {"success": false, "error": "Toy SDK 返回了无效数据"}


func _result_error(result: Dictionary, fallback: String) -> String:
	var raw := str(result.get("error", "")).strip_edges()
	if raw.is_empty():
		return fallback
	var normalized := raw.to_lower()
	if "toy id not available on host" in normalized:
		return "Toy 预览页没有正式 ID，云功能将在正式页面启用"
	if raw.begins_with("[ToySDK]"):
		push_warning("%s：%s" % [fallback, raw])
		if "login" in normalized:
			return "请先登录 B 站再使用 Toy 云功能"
		return "%s，请稍后重试" % fallback
	return raw


func _on_availability_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	if not bool(result.get("success", false)):
		_available = false
		availability_changed.emit(false, _result_error(result, "Toy SDK 能力检查失败"))
		return
	_cloud_supported = bool(result.get("cloud", false))
	_rank_supported = bool(result.get("rank", false))
	_close_supported = bool(result.get("closeBrowser", false))
	_preview_host = bool(result.get("preview", false))
	_available = _cloud_supported and _rank_supported
	if _available:
		availability_changed.emit(true, "Toy 云存档与排行榜已连接")
	elif _preview_host:
		_available = true
		availability_changed.emit(true, "Toy 预览模式：正式页面将启用云功能")
	else:
		availability_changed.emit(false, "当前环境不支持 Toy 云存档与排行榜")


func _on_cloud_info_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	if not bool(result.get("success", false)):
		cloud_info_received.emit({}, _result_error(result, "读取云存档失败"))
		return
	var manifest = result.get("manifest")
	cloud_info_received.emit(manifest if manifest is Dictionary else {}, "")


func _on_cloud_upload_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	cloud_upload_finished.emit(bool(result.get("success", false)), "云存档上传完成" if bool(result.get("success", false)) else _result_error(result, "云存档上传失败"))


func _on_cloud_download_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	if not bool(result.get("success", false)):
		cloud_download_finished.emit(false, _result_error(result, "云存档下载失败"), "")
		return
	var manifest = result.get("manifest")
	if manifest is not Dictionary:
		cloud_download_finished.emit(false, "云存档清单无效", "")
		return
	var decoded := decode_cloud_payload(str(result.get("data", "")), manifest)
	cloud_download_finished.emit(
		bool(decoded.get("success", false)),
		"云存档下载完成" if bool(decoded.get("success", false)) else str(decoded.get("error", "云存档解码失败")),
		str(decoded.get("save_text", ""))
	)


func _on_rank_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	var board := clampi(int(result.get("board", 1)), 1, 3)
	if not bool(result.get("success", false)):
		rank_received.emit(board, [], {}, _result_error(result, "读取排行榜失败"))
		return
	var entries = result.get("entries")
	var mine = result.get("mine")
	var message := str(result.get("mineError", ""))
	rank_received.emit(board, entries if entries is Array else [], mine if mine is Dictionary else {}, message)


func _on_scores_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	scores_submitted.emit(bool(result.get("success", false)), "" if bool(result.get("success", false)) else _result_error(result, "排行榜上报失败"))


func _on_close_result(arguments: Array) -> void:
	var result := _parse_callback(arguments)
	close_finished.emit(bool(result.get("success", false)))
