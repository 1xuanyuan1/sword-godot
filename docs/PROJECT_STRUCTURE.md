# 项目目录结构

项目是单一 Godot 4.7 工程。Git 仓库保存运行机制、转换工具、测试和文档；原版资源及其转换产物只存在于本机。

```text
sword/
├── project.godot          # Godot 工程配置，主场景为 scenes/main.tscn
├── scenes/                # 可直接切换的 Godot 场景
├── src/
│   ├── audio/             # Godot 原生 BGM/音效播放与音量应用
│   ├── battle/            # 经典战斗画面、回合状态与控制器
│   ├── content/           # PAL 结构化数据模型和内容数据库
│   ├── debug/             # 剧情检查点与开发验证入口
│   ├── formats/           # MKF、YJ1、RLE、Sprite、地图等底层格式
│   ├── game/              # 运行时会话状态和 ScriptVM
│   ├── import/            # 本地原版数据校验与转换
│   ├── ui/                # 资源实验室、对话框、菜单和预览 UI
│   └── world/             # 地图探索、TileMap 世界和人物节点
├── shaders/               # 索引颜色到 PAL 调色板的 GPU 映射
├── tools/                 # 命令行导入、文字转换和离线音频辅助工具
├── tests/                 # 无原版资源的 CI 测试与本地数据集成测试
├── docs/                  # 中文架构、格式、功能和开发说明
├── .yulia/                # 开发待办、功能变更和问题归档
└── generated/             # 本机导入产物，整目录被 Git 忽略
```

## 入口与主要场景

- `scenes/main.tscn`：工程主入口，提供数据目录选择、导入和实验室导航。
- `scenes/map_explorer.tscn`：当前可玩探索场景，连接 `GameSession`、`ScriptVM`、地图世界、对话框和菜单。
- `scenes/rng_preview.tscn`：RNG 增量动画浏览器。
- `scenes/battle_preview.tscn`：敌队、战场、双方战斗 Sprite 和首个经典普攻回合的可操作样板。
- `scenes/story_test_lab.tscn`：只保留尚需人工验收的剧情检查点；完成项转为自动回归后移除。

## 源码模块

### `src/formats`

纯格式层，不持有游戏进度。输入通常是 `PackedByteArray`，输出是解析后的数据对象或索引图像。这里实现 MKF 分块、YJ1 解压、RLE、PAL Sprite、地图位字段、调色板、RNG 和 VOC。

### `src/audio`

`PalAudioPlayer` 加载本地转换的 RIX/VOC WAV，维护 BGM 声道、短音效声道池、循环、淡入淡出和即时音量；它不决定剧情应该播放哪个编号。

### `src/battle`

`PalBattleRandom` 复现 SDLPal 的固定随机序列；`PalBattleController` 持有单场敌人体力、指令和行动队列，并把玩家体力写回 `GameSession`；`PalBattlePreview` 只绘制战场、双方 Sprite、目标光标和动作结果。静态敌人属性仍属于 `src/content`，场景节点不直接计算伤害。

### `src/import`

负责大小写不敏感地识别原版 `Data` 文件，验证格式并写入 `generated/pal/`。导入器不会修改原始数据目录，也不会把生成内容加入 Git。

### `src/content`

将导入后的二进制结构转换为游戏可用的场景、事件、角色、物品和脚本对象。`PalContentDatabase` 是运行时读取内容的统一入口；它不保存玩家进度。

### `src/game`

`GameSession` 保存本次游戏的可变状态，例如队伍位置、方向、物品、金钱、调色板和场景索引。`ScriptVM` 解释 SDLPal 事件脚本并修改会话或事件对象。

### `src/world`

`map_explorer.gd` 负责输入、移动、事件触发和各子系统编排。`PalMapCoordinates` 统一把任意 PAL 世界像素映射为菱形碰撞 half；`PalTileMapWorld` 负责 TileMapLayer、Camera2D、人物 Sprite2D、调色板和遮挡，不负责剧情规则。

### `src/ui`

只负责屏幕控件和输入反馈。菜单和对话框读取内容数据库与会话，但不直接解析 MKF，也不自行推进 ScriptVM。

### `src/debug`

保存开发期剧情检查点。检查点只修改当前临时会话，不读写正式存档；已验收入口必须从人工界面移除。

## 测试与本地生成内容

- `tests/run_tests.gd`：CI 使用合成字节运行，不依赖原版游戏。
- `tests/run_battle_logic_tests.gd`：CI 使用合成敌我数据验证经典回合、伤害和胜负。
- `tests/run_local_*.gd`：使用本机 `generated/pal/` 验证完整资源、剧情和画面，不在 GitHub CI 执行。
- `generated/pal/content/`：运行时数据库、Sprite、地图、二进制 TileSet 等本地产物。
- `generated/pal/audio/`：本机 RIX/OPL 与 VOC 转换结果。
- `generated/pal/visual_tests/`：本地截图和像素对照结果。

只有源码、测试、文档和完全合成的数据可以提交。`Data/`、`generated/`、存档、音频转换结果和原版截图均不可提交。
