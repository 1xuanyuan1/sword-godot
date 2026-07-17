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
	var master_bus := AudioServer.get_bus_index("Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(master_bus, capture, 0)
	await process_frame
	if not audio.has_music_resource(31):
		printerr("FAIL: 开场 RIX 31 尚未生成，请重新导入 Data")
		quit(1)
		return
	if not audio.has_sound_resource(98):
		printerr("FAIL: 开场剧情 VOC 98 尚未生成")
		quit(1)
		return
	capture.clear_buffer()
	if not audio.play_sound(98):
		printerr("FAIL: 本地开场剧情音效无法载入 Godot 声道：%s" % audio.error_message)
		quit(1)
		return
	await create_timer(0.4).timeout
	var sound_peak := _capture_peak(capture)
	if sound_peak < 0.001:
		printerr("FAIL: 音效 98 虽进入播放器，但 Master 总线没有收到有效波形：peak=%.6f" % sound_peak)
		quit(1)
		return
	capture.clear_buffer()
	if not audio.play_music(31, true):
		printerr("FAIL: 本地开场 BGM 无法载入 Godot 声道：%s" % audio.error_message)
		quit(1)
		return
	await create_timer(0.25).timeout
	if audio.current_music_number != 31 or audio._music_player.stream == null or not audio._music_player.playing or audio.last_sound_number != 98:
		var stream_length: float = audio._music_player.stream.get_length() if audio._music_player.stream != null else -1.0
		printerr(
			"FAIL: BGM 31 没有持续播放：number=%d stream=%s length=%.3f playing=%s position=%.3f sound=%d"
			% [
				audio.current_music_number,
				str(audio._music_player.stream),
				stream_length,
				str(audio._music_player.playing),
				audio._music_player.get_playback_position(),
				audio.last_sound_number,
			]
		)
		quit(1)
		return
	var opening_music_peak := _capture_peak(capture)
	if opening_music_peak < 0.001:
		printerr("FAIL: BGM 31 虽处于播放状态，但 Master 总线没有收到有效波形：peak=%.6f" % opening_music_peak)
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
	capture.clear_buffer()
	await create_timer(0.25).timeout
	var battle_stream := audio._music_player.stream as AudioStreamWAV
	if audio.current_music_number != 37 or battle_stream == null or not audio._music_player.playing or battle_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		printerr("FAIL: 战斗 BGM 37 没有真正进入循环播放状态")
		quit(1)
		return
	var battle_music_peak := _capture_peak(capture)
	if battle_music_peak < 0.001:
		printerr("FAIL: 战斗 BGM 37 虽处于播放状态，但 Master 总线没有收到有效波形：peak=%.6f" % battle_music_peak)
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
	AudioServer.remove_bus_effect(master_bus, 0)
	audio.free()
	playing_stream = null
	battle_stream = null
	capture = null
	# 让音频线程消费 stop/free 命令，避免测试进程在播放对象仍被 CoreAudio 引用时退出。
	await create_timer(0.1).timeout
	print("PASS: 开场 BGM 31、战斗 BGM 37 与音效 98 均在 Master 总线产生有效波形，独立音量可用")
	quit(0)


func _capture_peak(capture: AudioEffectCapture) -> float:
	var frame_count := capture.get_frames_available()
	if frame_count <= 0:
		return 0.0
	var peak := 0.0
	for frame in capture.get_buffer(frame_count):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak
