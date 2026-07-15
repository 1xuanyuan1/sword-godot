# SDLPal 上游基准

行为和数据格式参考使用独立、只读的同级检出：

- 本地路径：`/Users/xuanyuan/Documents/godotwork/sdlpal-official`
- 主要镜像：`https://gitee.com/sdlpal/sdlpal.git`
- 核验远端：`https://github.com/sdlpal/sdlpal.git`
- 分支：`master`
- 固定提交：`79718a1aa2fb889994d1d084765025994d429706`
- 提交时间：2026-07-13 19:40:35 +0800

旧目录 `/Users/xuanyuan/Documents/godotwork/sdlpal` 仅保留用于历史代码和旧 EXE 行为对照。

本地集成数据最初被假定为简体版，但字节级编码检测和词条解码确认它是 DOS 繁体 CP950/Big5 版本。导入器会把检测结果写入被 Git 忽略的本地清单。

## 更新规则

不会自动更新上游。若要切换 SDLPal 版本，必须先人工审查行为变化，在本文记录相关源码映射后再修改固定提交。Godot 复刻以 SDLPal 默认经典战斗路径为准，即不启用 `ENABLE_REVISIED_BATTLE`。

## 初始源码映射

| Godot 子系统 | SDLPal 参考文件 |
| --- | --- |
| MKF、Sprite、RLE 格式 | `palcommon.c` |
| YJ1/YJ2 压缩 | `yj1.c` |
| 调色板和渐变 | `palette.c` |
| 等距地图 | `map.c`、`scene.c`、`res.c` |
| 结构化游戏数据和存档状态 | `global.c`、`global.h` |
| 脚本虚拟机 | `script.c` |
| 经典战斗循环 | `battle.c`、`fight.c`、`uibattle.c` |
| 文本、代码页和字库 | `text.c`、`font.c`、`codepage.h` |
| RIX/VOC 音频 | `rixplay.cpp`、`sound.c`、`adplug/` |
