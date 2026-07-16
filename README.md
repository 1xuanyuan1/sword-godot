# Sword Godot Study Port

这是一个使用 Godot 4.7 学习复刻经典《仙剑奇侠传》运行机制的非官方项目，主要参考开源的 [SDLPal](https://github.com/sdlpal/sdlpal) 重实现。

## 项目定位与版权边界

- 本项目仅用于个人学习、技术研究和开源交流，与大宇资讯、软星科技及 SDLPal 维护团队不存在官方关系。
- 本仓库不包含、不提供、也不帮助下载原版游戏资源。运行资源导入器前，请自行合法取得相应版本的游戏数据。
- 《仙剑奇侠传》名称、角色、美术、音乐、文本和其他原版内容的权利归各自权利人所有。
- “仅供学习”是项目目的说明，不会缩减 `GPL-3.0` 赋予代码接收者的权利，也不能替代原版资源所需的授权。

## 当前状态

项目按可运行里程碑开发：

- M0：Godot 工程、许可、上游基准与资源隔离。
- M1：原版数据校验，以及 MKF、YJ1、RLE、调色板等格式导入。
- M2：等距地图、移动、事件对象和脚本虚拟机样板。
- M3–M4：菜单、物品、存档和经典回合制战斗。
- M5：完整流程、音画、桌面导出和通关回归。

当前可启动资源实验室，选择本机合法取得的 `Data` 目录后执行只读校验和本地导入。生成内容位于 `res://generated/pal/`，已被 Git 忽略。导入器会为每个有效 `map_number` 生成 Godot 4.7 `TileSet + TileMapLayer`，并把剧情实际引用的 RIX/OPL 与 VOC 离线转换为 Godot 可播放音频；探索场景默认使用原生 TileMap、Camera2D、Sprite2D 和 AudioStreamPlayer，CPU 合成路径仅保留作像素对照。地图探索已经支持双层地图、MGO 角色/NPC、原版方向步态、遮挡排序、移动阻挡、按朝向扫描 PAL half 格的搜索事件、接触事件、EventObject 自动路线与追逐、临时隐藏/重现、场景 BGM 与剧情音效。首场景进入脚本可完整执行，原版中文消息会配合 RGM 角色肖像，在上、下或中部对话框中按空格/回车推进；用引号标记的系统叙述会显示为较小字号的居中黑底白字 Toast。探索时按 Esc、M 或 Tab 打开原版布局菜单，按 I 直接打开原版物品选择页，按 F10 返回资源实验室；经典菜单和物品页已经可以正常使用桂花酒推进醉道士剧情，“系统”页可独立调节音乐和音效音量。真实资源自动回归已继续覆盖买虾、鱼嫂无鲜虾、李大娘病倒、求药归来和夜间山神庙提醒；完整后续主线仍在 M3 中逐段补齐。资源实验室中的“剧情测试”只保留桂花酒流程相关的待验收入口；完成项从人工测试界面移除，行为继续由自动回归测试覆盖。

第一次阅读代码请从[中文文档导航](docs/README.md)开始，再查看[项目目录结构](docs/PROJECT_STRUCTURE.md)和[整体架构](docs/ARCHITECTURE.md)。详细进度见[功能变更记录](.yulia/kb/changelog/changelog.md)，后续工作和优先级见[开发待办跟踪](.yulia/kb/changelog/todo.md)。功能完成并验证后，会从待办归档到变更记录。

从新游戏到结局的原版主线、关键道具、谜题、主要 Boss 和 Godot 当前可玩范围见[完整游戏攻略](docs/GAME_WALKTHROUGH.md)。

原版菜单还原范围与坐标基准见[经典菜单与物品页](docs/CLASSIC_UI.md)。
音频导入、场景曲目关系和菜单音量见[音乐、音效与音量](docs/AUDIO.md)。

## 开发环境

- Godot 4.7（标准版，类型化 GDScript）
- 默认逻辑画布 320×200，窗口 960×600，最近邻采样
- 首阶段目标：当前资源实际识别出的 DOS 繁体中文版（CP950/Big5）、macOS/Windows、经典回合制、新版 Godot 存档

运行项目：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

运行无原版资源依赖的合成测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
```

命令行校验/导入本地资源：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/import_cli.gd -- --source /path/to/Data
```

## 许可证

项目代码采用 GNU General Public License v3.0。移植或改写自 SDLPal 的部分保留对应版权声明和出处。参见 [LICENSE](LICENSE)、[THIRD_PARTY.md](THIRD_PARTY.md) 与 [docs/UPSTREAM.md](docs/UPSTREAM.md)。

项目文档默认使用中文，英文只作为许可证原文、第三方原始名称或补充内容。约定见 [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md)。
