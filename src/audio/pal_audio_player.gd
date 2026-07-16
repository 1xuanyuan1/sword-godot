# Copyright (C) 2026 sword-godot contributors
# Adapted from SDLPal audio.c, rixplay.cpp and sound.c playback behavior.
# SPDX-License-Identifier: GPL-3.0-or-later
## Godot 原生 PAL 音频播放层，负责播放离线转换的 RIX/OPL BGM 与 VOC 音效。
## 音乐编号和切换语义来自 ScriptVM；音量由 GameSession 持有，本节点只负责即时应用。
class_name PalAudioPlayer
extends Node

## 请求的本地音频不存在或无法加载时发出，便于探索场景显示可操作的重新导入提示。
signal audio_missing(kind: String, number: int, path: String)

const SOUND_VOICE_COUNT := 8
const SILENCE_DB := -80.0

## 当前已请求并成功载入的 RIX 曲目编号；0 表示停止，-1 表示尚未请求。
var current_music_number: int = -1
## 最近一次成功载入的 VOC 音效编号。
var last_sound_number: int = -1
## 最近一次加载失败说明；成功播放时清空。
var error_message: String = ""

var _database: PalContentDatabase
var _session: GameSession
var _music_player: AudioStreamPlayer
var _sound_players: Array[AudioStreamPlayer] = []
var _sound_cursor: int = 0
var _music_tween: Tween
var _missing_keys: Dictionary = {}


## 注入内容数据库和会话，建立一个 BGM 声道与八个可重叠音效声道。
## 该函数不会自动开始音乐；场景进入脚本的 `0x0043` 决定首个曲目。
func configure(content_database: PalContentDatabase, game_session: GameSession) -> void:
	_database = content_database
	_session = game_session
	_ensure_players()
	apply_session_volumes()


## 播放或切换一个 RIX 曲目；`number <= 0` 表示停止。
## `loop` 和 `fade_seconds` 直接对应 SDLPal `0x0043` 的第二操作数语义。
## 文件缺失时保留当前曲目、返回 `false` 并发出 `audio_missing`。
func play_music(number: int, loop: bool = true, fade_seconds: float = 0.0) -> bool:
	_ensure_players()
	if number <= 0:
		current_music_number = 0
		_stop_music(maxf(0.0, fade_seconds))
		return true
	var path := _music_path(number)
	var stream := _load_wav(path)
	if stream == null:
		_report_missing("BGM", number, path)
		return false
	error_message = ""
	var playable := stream.duplicate(true) as AudioStreamWAV
	if playable == null:
		_report_missing("BGM", number, path)
		return false
	playable.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if current_music_number == number and _music_player.playing:
		# 官方同曲请求只更新循环标记，不从头重播。
		var current_stream := _music_player.stream as AudioStreamWAV
		if current_stream != null:
			current_stream.loop_mode = playable.loop_mode
		return true
	current_music_number = number
	_start_music(playable, maxf(0.0, fade_seconds))
	return true


## 在循环声道池中播放一次 VOC 音效；编号按官方行为取绝对值。
## 音效为 0、音量为 0 或文件缺失时返回 `false`。
func play_sound(number: int) -> bool:
	_ensure_players()
	number = absi(number)
	if number <= 0 or _session == null or _session.sound_volume <= 0:
		return false
	var path := _sound_path(number)
	var stream := _load_wav(path)
	if stream == null:
		_report_missing("音效", number, path)
		return false
	error_message = ""
	var player := _sound_players[_sound_cursor]
	_sound_cursor = (_sound_cursor + 1) % _sound_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_percent_to_db(_session.sound_volume)
	player.play()
	last_sound_number = number
	return true


## 把 GameSession 中的音乐、音效百分比立即应用到全部 Godot 声道。
func apply_session_volumes() -> void:
	_ensure_players()
	var music_volume := _session.music_volume if _session != null else GameSession.AUDIO_VOLUME_MAX
	var sound_volume := _session.sound_volume if _session != null else GameSession.AUDIO_VOLUME_MAX
	_music_player.volume_db = volume_percent_to_db(music_volume)
	for player in _sound_players:
		player.volume_db = volume_percent_to_db(sound_volume)


## 立即停止 BGM 与全部音效，供离开探索场景或测试清理使用。
func stop_all() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	if _music_player != null:
		_music_player.stop()
	for player in _sound_players:
		player.stop()
	current_music_number = 0


## 返回指定曲目的本地生成资源是否可由 Godot 加载。
func has_music_resource(number: int) -> bool:
	return number > 0 and ResourceLoader.exists(_music_path(number))


## 返回指定音效的本地生成资源是否可由 Godot 加载。
func has_sound_resource(number: int) -> bool:
	return number != 0 and ResourceLoader.exists(_sound_path(absi(number)))


## 将 0–100 线性音量换算为 Godot 分贝；0 使用稳定静音下限而不是负无穷。
static func volume_percent_to_db(value: int) -> float:
	var linear := clampf(float(value) / GameSession.AUDIO_VOLUME_MAX, 0.0, 1.0)
	return SILENCE_DB if linear <= 0.0 else linear_to_db(linear)


func _ensure_players() -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "Music"
		add_child(_music_player)
	if _sound_players.is_empty():
		for index in range(SOUND_VOICE_COUNT):
			var player := AudioStreamPlayer.new()
			player.name = "Sound%02d" % index
			add_child(player)
			_sound_players.append(player)


func _start_music(stream: AudioStreamWAV, fade_seconds: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	var target_db := volume_percent_to_db(_session.music_volume if _session != null else GameSession.AUDIO_VOLUME_MAX)
	if fade_seconds <= 0.0 or not _music_player.playing:
		_music_player.stop()
		_music_player.stream = stream
		_music_player.volume_db = target_db
		_music_player.play()
		return
	# SDLPal 在同一个 fade 时长内各用一半淡出旧曲、淡入新曲。
	var half := fade_seconds / 2.0
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", SILENCE_DB, half)
	_music_tween.tween_callback(_replace_music_stream.bind(stream))
	_music_tween.tween_property(_music_player, "volume_db", target_db, half)


func _replace_music_stream(stream: AudioStreamWAV) -> void:
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = SILENCE_DB
	_music_player.play()


func _stop_music(fade_seconds: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	if not _music_player.playing:
		return
	if fade_seconds <= 0.0:
		_music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", SILENCE_DB, fade_seconds)
	_music_tween.tween_callback(_music_player.stop)


func _load_wav(path: String) -> AudioStreamWAV:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_REUSE) as AudioStreamWAV


func _music_path(number: int) -> String:
	return _audio_root().path_join("rix/%03d.wav" % number)


func _sound_path(number: int) -> String:
	return _audio_root().path_join("voc/%03d.wav" % number)


func _audio_root() -> String:
	if _database == null:
		return "res://generated/pal/audio"
	return _database.root_path.get_base_dir().path_join("audio")


func _report_missing(kind: String, number: int, path: String) -> void:
	error_message = "%s %d 尚未生成：%s" % [kind, number, path]
	var key := "%s:%d" % [kind, number]
	if _missing_keys.has(key):
		return
	_missing_keys[key] = true
	push_warning(error_message)
	audio_missing.emit(kind, number, path)
