# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机生成资源验证开场 BGM、剧情音效和 Godot 声道加载，不输出原版音频内容。
extends SceneTree

const AudioPlayer := preload("res://src/audio/pal_audio_player.gd")


func _init() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		printerr("SKIP: 本地生成资源不存在：%s" % database.error_message)
		quit(0)
		return
	var session := GameSession.new()
	session.reset_new_game()
	var audio = AudioPlayer.new()
	root.add_child(audio)
	audio.configure(database, session)
	await process_frame
	if not audio.has_music_resource(31):
		printerr("FAIL: 开场 RIX 31 尚未生成，请重新导入 Data")
		quit(1)
		return
	if not audio.has_sound_resource(98):
		printerr("FAIL: 开场剧情 VOC 98 尚未生成")
		quit(1)
		return
	if not audio.play_music(31, true) or not audio.play_sound(98):
		printerr("FAIL: 本地开场 BGM/剧情音效无法载入 Godot 声道：%s" % audio.error_message)
		quit(1)
		return
	await process_frame
	if audio.current_music_number != 31 or audio._music_player.stream == null or not audio._music_player.playing or audio.last_sound_number != 98:
		printerr("FAIL: BGM 31 没有真正进入播放状态，或音频播放器状态没有反映开场脚本请求")
		quit(1)
		return
	var playing_stream: AudioStreamWAV = audio._music_player.stream
	if not audio.play_music(31, false) or audio._music_player.stream != playing_stream or playing_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		printerr("FAIL: 同曲请求应该只更新循环标记，不能从头替换 BGM")
		quit(1)
		return
	if not audio.has_music_resource(37):
		printerr("FAIL: 标准战斗 RIX 37 尚未生成，请重新导入 Data")
		quit(1)
		return
	if not audio.play_music(37, true):
		printerr("FAIL: 标准战斗 BGM 37 无法载入 Godot 声道：%s" % audio.error_message)
		quit(1)
		return
	await process_frame
	var battle_stream := audio._music_player.stream as AudioStreamWAV
	if audio.current_music_number != 37 or battle_stream == null or not audio._music_player.playing or battle_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		printerr("FAIL: 战斗 BGM 37 没有真正进入循环播放状态")
		quit(1)
		return
	session.set_music_volume(40)
	session.set_sound_volume(30)
	audio.apply_session_volumes()
	if not is_equal_approx(audio._music_player.volume_db, AudioPlayer.volume_percent_to_db(40)) or not is_equal_approx(audio._sound_players[0].volume_db, AudioPlayer.volume_percent_to_db(30)):
		printerr("FAIL: 音乐/音效独立音量没有即时应用")
		quit(1)
		return
	audio.stop_all()
	print("PASS: 开场 BGM 31、战斗 BGM 37、剧情音效 98 和独立音量均可由 Godot 加载")
	quit(0)
