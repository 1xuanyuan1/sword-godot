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
