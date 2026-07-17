# 开发工作流

## 运行项目

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

首次运行先在资源实验室选择本机合法取得的 `Data` 目录并执行导入。导入器只读取源目录，所有产物写入 `generated/pal/`。

## 命令行导入

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/import_cli.gd -- --source /path/to/Data
```

当导入格式版本、TileSet 生成规则或本机原版资源发生变化时，应重新导入，不能手工修改 `generated/` 中的结果来掩盖转换问题。

导入器会构建本机 `tools/rix_renderer/build/rix_renderer`，扫描脚本引用并生成 RIX/OPL WAV。首次完整导入约生成 72 首曲目、占用约 289 MB；该目录已被 Git 忽略。新增 WAV 后若 Godot 编辑器尚未识别，可重启编辑器或执行一次资源扫描。

## 测试层级

### 合成测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_tests.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_equipment_tests.gd
```

这些测试只使用代码构造的字节和状态，可以在 GitHub CI 执行，必须覆盖格式边界、ScriptVM 基础行为、TileSet 坐标、自定义数据，以及装备六槽、背包交换和脚本效果。

版本化存档格式、100 槽、校验和及损坏诊断：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_save_system_tests.gd
```

地图阻挡改动必须覆盖 32×16 菱形的北部、half 1、东部、南部和东南部区域，以及玩家左上视口边界；禁止在世界层、TileMap 层和 ScriptVM 中复制三份 half 推断公式。

EventObject 阻挡测试还要区分移动碰撞 `<16` 与队伍挤占 `≤12`，覆盖 15/16 边界及正 `vanish_time` 状态，避免临时隐藏错误地变成可穿过。

### 本地资源测试

`tests/run_local_*.gd` 读取 `generated/pal/`，用于验证完整导入数据、剧情流程、菜单和像素截图。它们可以提交测试代码，但不得提交输出截图、原版文字转储或资源文件。

经典菜单、状态、装备、场外仙术和系统页视觉与真实气疗术回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_menu_visual_test.gd
```

该测试必须使用真实渲染器，截图写入被忽略的 `generated/pal/visual_tests/`。场外仙术样板只能从 PLAYERROLES 初始仙术与升级习得表选择，且必须验证使用/成功脚本、HP 恢复和 MP 单次扣除，禁止通过遍历共用 OBJECT 表猜测仙术类型。

音频资源和独立音量回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_audio_test.gd
```

RNG 剧情动画引用、导入完整性和 HUD 播放回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_rng_player_test.gd
```

全部场景 EventObject 自动行为回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_event_auto_script_test.gd
```

完整 PAL 内容的存读档往返与装备重建：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_save_system_test.gd
```

需要复现运行时 bug 时，在问题发生前使用一个独立槽保存并记录操作步骤。代码修复后，只要格式版本和内容指纹兼容即可继续读档；存档属于本机用户数据，不得加入 Git。

客栈手动搜索范围和真实触发脚本回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_manual_search_test.gd
```

修改搜索或交互行为时，合成测试必须至少覆盖朝向检查点、身后排除、`trigger_mode 1/2/3` 的 2/8/13 点边界和同格 EventObject 顺序；本地测试负责验证真实资源中的对象编号及脚本可以完整结束。

修改 NPC 自动路线或阻挡行为时，还要覆盖 NPC 与队伍重叠后的四方向脱困顺序，并运行全部 294 个剧情场景自动脚本门禁和黑苗客栈入房回归。

场景进入、出口、楼梯和传送离开生命周期回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_scene_transition_test.gd
```

其中楼梯用例必须从真实 EventObject 的接触范围启动，不可绕过 `MapExplorer` 直接调用脚本入口；这样才能同时覆盖触发模式、对象顺序和后续 8 步动画。

桂花酒之后到水月宫惨案、客栈次日、离开余杭并抵达苏州的早期主线回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_early_mainline_test.gd
```

修改场景脚本入口、批量 EventObject 状态、音乐停止、RNG/战斗/屏幕渐变等待、习得仙术、`0022/0078` 战后续跑、FBP 黑屏或这段主线消息时必须运行该测试。回归只保存消息编号和状态断言，不得输出原版文本；后续主线继续按真实剧情顺序扩展同类长期测试，不增加已验收的人工检查点。

战斗静态内容、纯逻辑回合和首战画面回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_battle_logic_tests.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_battle_bridge_tests.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_content_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_logic_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_bridge_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_battle_preview_test.gd
```

合成测试验证固定随机序列、行动排序、双动、防御、合击、保护格挡、敌我仙术、九种状态、敌我下毒/解毒、毒抗、毒杀胜负、复活、装备双击、附带物品攻击、三类敌人战斗脚本、血量分支、召唤、敌人逃跑、战后随机掉落、基础使用/投掷物品、库存预留、逃跑、`R` 重复指令及资源不足降级、最低伤害、死亡目标重选、胜负、主经验升级和 `004A/0007` 三种结果分支；本地 headless 测试验证真实敌队/Sprite、PLAYERROLES 合击/保护关系、60/85 个已接入/全部敌术、68/49 个使用/投掷物品脚本、27/22/10 个敌人脚本入口、首战普攻、551 号基础毒、止血草、梅花镖、逃跑、52 经验/96 文奖励及脚本 6964/6965 的阻塞请求；最后一个测试必须使用真实渲染器，验证 `R` 键入口并把敌队 22 的战斗对白、合体气功、保护格挡、敌队 17 的敌术和敌队 18 / 战场 21 的战斗、其他/物品菜单、物品/仙术动画、毒性结算、奖励与升级页截图写入被忽略的 `generated/pal/visual_tests/`。

### 人工剧情检查点

资源实验室的“剧情测试”只用于尚未验收、必须人工观察的问题。验证完成后删除按钮和检查点，保留对应的自动回归，避免测试界面持续膨胀。

## 地图像素对照

迁移 TileMapLayer 时，同一 `GameSession` 状态分别交给 CPU 基准和 Godot 原生渲染路径，在 320×200、最近邻、整数相机坐标下截图比较。重点检查透明边缘、调色板、床沿、门框、楼梯、门口 NPC 和屋檐。

若 Godot Y 排序无法逐像素表达 SDLPal 覆盖块规则，地图主体仍保持 TileMapLayer，只让特殊覆盖块进入兼容 Sprite2D 层。

像素测试必须使用真实渲染器，不能加 `--headless`（headless 使用 dummy renderer，无法读回 GPU 纹理）：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_tilemap_visual_test.gd
```

临时查看旧 CPU 路径可在运行探索场景时追加用户参数：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  res://scenes/map_explorer.tscn -- --pal-map-backend=legacy
```

## Git 与提交

- 修改前先检查 `git status`，用户已有修改不得覆盖或顺带提交。
- 功能达到可运行、测试通过并同步中文文档后再 commit。
- 每个可验证里程碑独立提交并 push 到 `origin/main`。
- `Data/`、`generated/`、存档、构建产物和本地日志不得加入 Git。
- 开发待办完成后归档到功能变更记录，并回填关联编号。

## 注释和文档检查

新增 GDScript 文件必须有中文模块说明；公开类、信号和公开函数使用 `##` 文档注释。复杂私有函数解释数据来源、坐标公式或兼容原因，不复述显而易见的语句。

修改目录职责、公开接口、资源格式、输入方式或测试命令时，必须同步更新 `docs/README.md` 及对应专题文档。

本地执行与 CI 相同的注释和链接检查：

```bash
python3 tools/check_documentation.py
```
