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

正式启动现会依次播放原版商标 RNG、山水合拢/仙鹤/题字片头，并进入“新的故事／旧的回忆”标题菜单；“旧的回忆”复用与游戏内一致的 100 槽读档界面，F10 可随时进入资源实验室。首次运行或生成内容缺失时会自动打开资源实验室。

当前可启动资源实验室，选择本机合法取得的 `Data` 目录后执行只读校验和本地导入；已有生成内容时可直接选择“开始新游戏”，或从“读取存档”打开与游戏内一致的原版 100 槽界面并恢复进度。生成内容位于 `res://generated/pal/`，已被 Git 忽略。导入器会为每个有效 `map_number` 生成 Godot 4.7 `TileSet + TileMapLayer`，并把剧情实际引用的 RIX/OPL、VOC 和全部可解码 RNG 过场离线转换为 Godot 可播放内容；探索场景默认使用原生 TileMap、Camera2D、Sprite2D 和 AudioStreamPlayer，CPU 合成路径仅保留作像素对照。地图探索已经支持双层地图、MGO 角色/NPC、原版方向步态、遮挡排序、移动阻挡、按朝向扫描 PAL half 格的搜索事件、接触事件、EventObject 自动路线与追逐、临时隐藏/重现、场景 BGM 与剧情音效。首场景进入脚本可完整执行，原版中文消息会配合 RGM 角色肖像，在上、下或中部对话框中按空格/回车推进；用引号标记的系统叙述会显示为较小字号的居中黑底白字 Toast。`0036/0037` 会在 HUD 全屏播放对应 RNG 剧情动画并阻塞脚本，结束后继续执行角色数值与习得仙术等后续指令。探索时按 Esc、M 或 Tab 打开原版布局菜单，按 I 直接打开原版物品选择页，按 F10 返回资源实验室；经典菜单的状态页使用原版 FBP、RGM 头像、装备图标和属性坐标，场外仙术页支持施法者、3×5 仙术列表、MP/说明、单体/全体目标及真实使用/成功脚本，成功后才扣除 MP；物品“装备／使用”均已可用，装备页支持六槽初始装备、角色许可、背包换装和实时属性，剧情商店支持买入/卖出、确认与金钱/库存结算，“系统”页可独立调节音乐和音效音量。战斗已解析敌人、敌队、战场、站位和双方原版 Sprite，并实现经典普攻、普通/召唤合击、玩家/敌人攻击与状态仙术、物品、毒与九种经典状态及逃跑闭环：固定 SDLPal 随机序列、全队指令、身法队列、双动敌人、敌人物理 AI、伤害、恢复、死亡和胜负；李逍遥的头巾、披风、布袍、木剑、草鞋和护腕等初始装备会在战斗前执行原版装备脚本，攻击、防御、身法、毒抗、五灵抗性、攻击全体、装备双击、合击覆盖和战斗 Sprite 覆盖不再遗漏。画面已改用官方角色状态框、攻击／仙术／合击／其他四向图标、其他与物品菜单、敌我目标箭头/闪烁、上浮数字和双方逐帧动作。双方普通攻击已读取 PLAYERROLES 与敌人 DATA 原版音效。仙术会按真实名称选择目标、扣除 MP，气疗术等恢复法术执行原版成功脚本，五灵咒按敌人抗性与战场修正结算；风神等召唤仙术使用 F.MKF 神将与后续 FIRE 特效，梦蛇会对施法者自己执行临时 Sprite 变身。下毒、解毒、复活、混乱、定身、昏睡、封咒、傀儡、勇气、防护、加速和双击会按经典回合执行、递减并显示毒性结算。右侧合击按健康队员数量启用，读取角色/装备的真实合击仙术，让每名贡献者消耗仙术 MP 数值对应的 HP（最低保留 1），再以合计武术与灵力结算并播放原版演出；濒死或异常角色也会在自动防御成功时由 PLAYERROLES 指定的健康队友上前保护。当前数据 85/85 个敌术均走完整结算路径；敌人物理攻击配置的附带物品毒也已接通。敌人的 `script_on_turn_start`、`script_on_ready` 和 `script_on_battle_end` 由专用战斗上下文执行，支持战斗内对白/音效、动态换仙术、血量分支、敌人逃跑、召唤、分裂、变身及随机掉落；真实静态敌队的 27/22/10 个对应入口均通过可达指令审计。战斗物品页使用原版 3×7 背包布局，84 个使用物品脚本和 49 个投掷物品脚本落在当前完整路径，支持恢复、投掷、临时属性/Sprite、隐藏、偷取、收妖、吹飞、召唤与变身；逃跑会按原版公式成功、失败或被 Boss 禁止，并把结果 3 交回剧情分支。胜利后会播放普通/Boss 胜利音乐，按敌人属性结算经验与金钱，执行敌人战后掉落脚本、主等级随机成长、升级回满、升级习得仙术和经典战后半恢复，并以原版窗口显示奖励及升级前后数值。资源实验室的“战斗样板”会补满两名队员 HP/MP，并预置止血草、鼠儿果、梅花镖和血玲珑，便于直接验证仙术、合击与物品。`ScriptVM 004A/0007` 已能暂停探索、切换战斗 BGM、覆盖打开同一 `GameSession` 的战斗，并按胜利/战败/逃跑入口恢复剧情；隐藏经验成长、更完整的死亡/复活动画和后续主线实机验证仍由战斗与主线待办继续推进。真实资源自动回归已继续覆盖蜀山、锁妖塔、圣姑住处、神木林、大理和回魂仙梦主线；十年前南诏守卫、天蛇杖、两次水魔兽、十年前余杭木剑换水灵珠及返回女娲神殿均已验证。金凤凰蛋壳 275 现由回魂仙梦返回后的真实脚本 `34687` 正式发放，不提前伪造。资源实验室中的“剧情测试”只保留桂花酒流程相关的待验收入口；完成项从人工测试界面移除，行为继续由自动回归测试覆盖。

系统菜单现提供 100 个版本化 Godot 存档槽，保存完整队伍、装备、背包、场景、EventObject 和脚本游标状态，并使用格式版本、PAL 内容指纹与 SHA-256 诊断不兼容或损坏文件。槽位页显示中文地点、保存时间、队伍头像、姓名和等级；读档不会重跑场景进入脚本。该格式不兼容原版 `.rpg`。

真实资源回归已从御剑教学继续覆盖水月宫惨案、离开余杭、苏州、林家堡夜间、隐龙窟、白河村药材任务、第七章、鬼阴山、扬州、蛤蟆山、长安尚书府、蜀山锁妖塔、圣姑住处、神木林、隐密树洞、大理族议、火麒麟、回魂仙梦、灵儿生产和试炼窟。第十六章固定盖罗娇敌队 223／战场 6、傀儡虫 152 的六类真实掉落敌人、土灵珠 267 的迷宫脱离脚本及 36 只交付；生产房、试炼窟外、洞窟各层和女娲遗迹新增 15 个正式 TileMap 视口后，126 个用例均通过 Godot 4.7 Metal 真实窗口 320×200 零差异像素检查。当前稳定终点为场景 173“李逍遥醒来”，灵儿／逍遥／阿奴 `[1,0,4]` 三人队及进入脚本 `32941`，下一段从五灵珠祭坛开始。

探索 HUD 现支持 `0076` FBP 全屏图片和 `0093` 场景过程渐变；全屏图位于地图/HUD 上方、剧情对话下方，`FFFF` 显示官方黑屏路径。`0051 FFFF` 按 SDLPal 的 signed SHORT 语义使用默认约 0.6 秒渐显，不会误算为超长动画。

第一次阅读代码请从[中文文档导航](docs/README.md)开始，再查看[项目目录结构](docs/PROJECT_STRUCTURE.md)和[整体架构](docs/ARCHITECTURE.md)。详细进度见[功能变更记录](.yulia/kb/changelog/changelog.md)，后续工作和优先级见[开发待办跟踪](.yulia/kb/changelog/todo.md)。功能完成并验证后，会从待办归档到变更记录。

从新游戏到结局的原版主线、关键道具、谜题、主要 Boss 和 Godot 当前可玩范围见[完整游戏攻略](docs/GAME_WALKTHROUGH.md)。

原版菜单还原范围与坐标基准见[经典菜单、状态、仙术与物品页](docs/CLASSIC_UI.md)。
音频导入、场景曲目关系和菜单音量见[音乐、音效与音量](docs/AUDIO.md)。
100 槽、格式校验和 bug 复现用法见[Godot 版本化存档系统](docs/SAVE_SYSTEM.md)。
敌队、战场、战斗 Sprite 与当前实现边界见[经典战斗系统](docs/BATTLE.md)。

## 开发环境

- Godot 4.7（标准版，类型化 GDScript）
- Python 3（本地资源导入和文本转换）
- 默认逻辑画布 320×200，窗口 960×600，最近邻采样
- 首阶段目标：当前资源实际识别出的 DOS 繁体中文版（CP950/Big5）、macOS/Windows、经典回合制、新版 Godot 存档

### 一键生成本地资源

准备一份自行合法取得的原版游戏 `Data` 目录，然后在仓库根目录执行：

macOS：

```bash
./tools/generate_resources.sh
```

Windows（CMD 或 PowerShell）：

```bat
tools\generate_resources.cmd
```

无参数时命令读取本项目内被 Git 忽略的 `Data/`，也可以显式传入 `Data` 本身或包含 `Data` 的游戏目录：

```bash
# macOS
./tools/generate_resources.sh "/path/to/game/Data"
```

```bat
rem Windows
tools\generate_resources.cmd "D:\games\PAL\Data"
```

macOS 会自动识别 `/Applications/Godot.app`；其他安装位置及 Windows 可将 Godot 加入 `PATH`，或使用 `--godot` 指定可执行文件：

```bat
tools\generate_resources.cmd "D:\games\PAL\Data" --godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe"
```

首次运行时，脚本会从 `https://github.com/sdlpal/sdlpal.git` 自动克隆官方 SDLPal 源码到相邻的 `sdlpal-official/`，供 RIX 音乐转换器使用；也可通过 `--sdlpal` 指定已有源码或其他克隆目标。官方 SDLPal **不包含原版游戏 Data**，因此仍须使用自己合法取得的资源。RIX 转换另需 C++17 编译器：macOS 可使用 Xcode Command Line Tools，Windows 可使用 Visual Studio Build Tools 或 LLVM。

`Data/` 和 `generated/` 都只保留在本机并受 Git 忽略；导入器只读取原版目录，不会修改其中的文件。运行 `./tools/generate_resources.sh --help` 或 `tools\generate_resources.cmd --help` 可查看完整参数。

运行项目：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

运行无原版资源依赖的合成测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_equipment_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_battle_logic_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_battle_bridge_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_save_system_tests.gd
```

底层命令行校验/导入入口（通常直接使用上面的一键命令即可）：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/import_cli.gd -- --source /path/to/Data
```

## 许可证

项目代码采用 GNU General Public License v3.0。移植或改写自 SDLPal 的部分保留对应版权声明和出处。参见 [LICENSE](LICENSE)、[THIRD_PARTY.md](THIRD_PARTY.md) 与 [docs/UPSTREAM.md](docs/UPSTREAM.md)。

项目文档默认使用中文，英文只作为许可证原文、第三方原始名称或补充内容。约定见 [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md)。
