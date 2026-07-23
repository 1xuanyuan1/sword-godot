---
name: '音频系统 Bug 修复记录'
summary: '记录场景 BGM、剧情音效、菜单和探索声音相关问题及修复'
keywords:
  - audio
  - bgm
  - sound-effect
  - 音频
---

# 音频系统 Bug 修复记录

## 修复记录

## 2026-07-23

### [BF-050] Android 内置音频被启动门禁误判缺失并跳转资源实验室

- **来源**: 用户试玩反馈
- **关联需求**: Android 本地验收包
- **问题描述**: Android APK 启动后直接进入资源实验室。Godot 导出时会把原始 WAV 替换为 `.wav.import` 映射和 `.sample` 导入产物，APK 中因此没有 `audio/rix/004.wav` 与 `005.wav` 原文件；正式启动门禁仍只用 `FileAccess.file_exists()` 检查这两个原始路径，误判内置内容不完整。实际音频导入产物、核心数据库、地图与其他启动资源均已正确打入 APK。
- **涉及文件**:
  - `src/audio/pal_audio_player.gd`
  - `src/ui/pal_startup.gd`
  - `tests/run_tests.gd`
  - `export_presets.cfg`
  - `README.md`
- **修复内容**: 把导入资源与桌面运行时原始 WAV 的可用性判断统一到 `PalAudioPlayer.wav_resource_exists()`：先走 `ResourceLoader` 解析导出包重映射，再兼容 `user://` 原始文件。正式启动门禁复用该规则并输出具体缺失项；新增内置内容导出 smoke，可挂载 Android 同款 PCK，真实加载核心数据库和标题音乐 004/005。Android 验收包版本提升到 `0.1.2(3)`，导出后已确认 `.wav.import` 与对应 `.sample` 均存在且 smoke 加载成功。
- **状态**: ✅ 已修复

## 2026-07-17

### [BF-019] 循环 WAV 的零循环终点导致场景与战斗 BGM 立即停止

- **来源**: 用户试玩反馈
- **关联需求**: M2–M5 场景、战斗与音画同步
- **问题描述**: 场景曲 31、战斗曲 37 等离线 WAV 都有正常时长和有效振幅，系统菜单音量也为 100，但 `PalAudioPlayer` 只把导入流的 `loop_mode` 改为前向循环。Godot 对没有源循环标记的 WAV 保留 `loop_end = 0`，导致循环播放器在第 0 帧直接结束；既有测试过早读取 `playing`，没有验证 Master 总线波形，因而未能稳定发现实际静音。
- **涉及文件**:
  - `src/audio/pal_audio_player.gd`
  - `tests/run_local_audio_test.gd`
  - `docs/AUDIO.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`
  - `docs/CLASSIC_UI.md`
- **修复内容**: 每次创建循环 BGM 播放副本时，将循环起点固定为 0，并按 `WAV 时长 × mix_rate` 设置完整采样循环终点。音频回归延长实际混音时间，检查持续播放状态，并用 `AudioEffectCapture` 分别确认场景 BGM 31、战斗 BGM 37 与剧情音效 98 在 Master 总线产生有效峰值。同时核对固定 SDLPal `PAL_BattleMain()` 和随机遇敌脚本：通用遇敌只执行音乐停止、像素切屏和战斗 BGM 起奏，没有可统一映射的额外 VOC，故不加入猜测音效。
- **状态**: ✅ 已修复

## 2026-07-16

### [BF-008] 无依据的脚步与菜单音效过响，剧情检查点未播放 BGM 31

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 探索、菜单与场景音频
- **问题描述**: 试玩版曾用 `VOC 1/2/3` 临时映射脚步、菜单打开、移动选择和确认，其中脚步与菜单选择复用 `VOC 2`，音量高且没有固定 SDLPal 上游行为依据。同时，场景 1 的剧情检查点会绕过场景进入脚本，因此不会执行原本请求 BGM 31 的 `0x0043`。
- **涉及文件**:
  - `src/audio/pal_audio_player.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/world/map_explorer.gd`
  - `src/debug/pal_debug_checkpoint.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_audio_test.gd`
  - `docs/AUDIO.md`
- **修复内容**: 移除全部人为猜测的脚步和菜单 VOC，只保留剧情脚本通过 `0x0047` 明确请求的音效。场景 1 的酒菜和端酒检查点显式保存该剧情时点已经确定的曲目 31，加载检查点时恢复播放；曲目不按可复用的地图编号推测。本地音频回归增加 `AudioStreamPlayer.playing` 断言，避免只验证文件能加载却没有真正开始播放。
- **状态**: ✅ 已修复

---

### [BF-010] 独立战斗样板未启动战斗 BGM

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典战斗音画同步
- **问题描述**: 正式剧情战斗会在覆盖层打开前播放 `0045` 保存的战斗曲，但资源实验室的独立战斗样板只配置了 `PalAudioPlayer`，没有发起 BGM 播放请求，因此普通攻击和仙术有音效、战斗背景音乐却保持静音。
- **涉及文件**:
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
  - `docs/AUDIO.md`
- **修复内容**: 独立样板为临时会话设置当前 DOS 数据的标准战斗曲 RIX 37，音频播放器配置完成后立即循环播放；切换敌队、重开或从胜利页返回时同样恢复 37。正式剧情入口继续只使用 `GameSession.battle_music_number`，不受样板默认值影响。真实渲染回归新增曲目编号与 `AudioStreamPlayer.playing` 断言。
- **状态**: ✅ 已修复
