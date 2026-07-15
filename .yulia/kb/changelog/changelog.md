---
name: '功能变更记录'
summary: '项目功能变更的 changelog，记录新增、修改、重构等功能点'
keywords:
  - changelog
  - feature
  - 功能变更
---

# 功能变更记录

本文件记录 Sword Godot Study Port 已完成并通过阶段性验证的功能。文档默认使用中文；原版游戏资源不纳入仓库。

## 变更记录

## 2026-07-15

### [FT-005] [feat] 增加剧情测试检查点

- **关联需求**: 缩短剧情功能的人工验证路径
- **关联 TODO**: TD-007
- **功能描述**: 在资源实验室增加“剧情测试”入口，可直接跳转到开场、密道、黑苗客栈、楼梯和“获得 500 文”系统提示等检查点，无需每次从新游戏开头重复推进。
- **验证情况**: 已覆盖开场剧情、李大娘离场、黑苗客栈对话及 NPC 进入客房、出口和楼梯自动触发。
- **涉及文件**:
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `scenes/story_test_lab.tscn`
  - `tests/run_local_intro_test.gd`
  - `tests/run_local_inn_conversation_test.gd`
  - `tests/run_local_scene_transition_test.gd`

### [FT-004] [feat] 完成首段剧情与对话交互样板

- **关联需求**: 首个可玩探索样板
- **关联 TODO**: TD-001、TD-002
- **功能描述**: 接入异步脚本虚拟机和原版消息，支持逐字显示、按键立即展开当前角色本轮文本、自动换行、分页上下文、角色姓名与肖像，以及居中的黑底白字系统提示。补充 NPC 自动脚本、李大娘离场、黑苗客栈事件、出口和楼梯自动触发，并让脚本移动过程播放步行动画。
- **验证情况**: 开场共 67 条消息及相应动作通过本地回归；黑苗客栈消息 604–633、“获得 500 文”和相关 NPC 路线通过本地回归。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `src/game/game_session.gd`
  - `src/ui/pal_dialog_box.gd`
  - `src/world/map_explorer.gd`

### [FT-003] [feat] 建立等距地图探索样板

- **关联需求**: M2 可玩探索样板
- **关联 TODO**: TD-002、TD-008
- **功能描述**: 从本地导入数据读取首场景，完成等距地图双层绘制、遮挡排序、阻挡检测、主角四方向移动和步态、队伍轨迹跟随，以及 NPC/EventObject 显示与交互。
- **验证情况**: 可在合法取得并完成本地导入的 PAL 数据上进入客栈及相邻场景进行探索。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `src/content/pal_content_database.gd`
  - `src/game/game_session.gd`

### [FT-002] [feat] 实现 PAL 资源导入与预览基础能力

- **关联需求**: M1 资源导入与显示实验室
- **关联 TODO**: TD-006
- **功能描述**: 建立本地数据校验、导入和资源实验室，已覆盖 MKF 容器、YJ1 解压、RLE/FBP 图像、调色板、地图、MGO 角色、RGM 肖像、VOC 音频、RNG 动画、文本与字库等基础数据路径。
- **验证情况**: 当前 101 项无原版资源依赖的合成测试通过；本地资源可导入到被 Git 忽略的 `res://generated/pal/`。
- **涉及文件**:
  - `src/import/pal_data_importer.gd`
  - `src/content/pal_content_database.gd`
  - `tests/run_tests.gd`

### [FT-001] [feat] 初始化 Godot 学习复刻工程

- **关联需求**: M0 仓库与工程初始化
- **关联 TODO**: 无
- **功能描述**: 建立 Godot 4.7 类型化 GDScript 工程，采用 GPL-3.0，默认逻辑画布 320×200、窗口 960×600 和最近邻采样；记录 SDLPal 上游基准并隔离原版及转换后资源。
- **验证情况**: 工程可启动，许可证、第三方署名、中文文档约定与资源版权边界已经写入仓库。
- **涉及文件**:
  - `project.godot`
  - `LICENSE`
  - `THIRD_PARTY.md`
  - `.gitignore`
  - `docs/UPSTREAM.md`
  - `docs/DOCUMENTATION.md`

---

### [FT-006] [feat] 贯通端酒菜与醉道士剧情

- **关联需求**: M2–M3 主线场景流程
- **关联 TODO**: TD-001、TD-002、TD-007、TD-008
- **功能描述**: 增加剧情物品数量状态并实现脚本物品增减、事件状态同步、未来触发入口和场景转场占位操作码；将原本瞬移的脚本强制走位改为逐帧步行动画。新增“端酒菜给黑苗人”和“醉道士喝桂花酒”检查点，可直接验证桂花酒的获得与消耗、角色造型恢复和相关人物状态收尾。
- **验证情况**: 110 项合成测试通过；本地资源回归覆盖端酒菜消息 674–692、16 步强制走位和醉道士消息 757–789；开场、黑苗客栈、出口及楼梯旧回归继续通过。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/world/map_explorer.gd`
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_meal_and_wine_test.gd`

---

### [FT-007] [feat] 增加基础菜单与剧情物品使用

- **关联需求**: M3 菜单与物品系统
- **关联 TODO**: TD-001、TD-002、TD-003、TD-007、TD-008
- **功能描述**: 解析 DOS `OBJECT_ITEM` 数据并接入物品名称、使用脚本和标志；探索时可通过 M/Tab 打开基础菜单、通过 I 直接打开背包，查看持有数量并选择可用物品。实现原版“面向指定事件对象”的操作码，使桂花酒只有在玩家正面对着醉道士时才生效，成功后自动进入接酒剧情，失败则显示“无任何效果”。状态、法术、装备和系统菜单保留后续入口。
- **验证情况**: 115 项合成测试通过；本地资源回归已从物品对象 272 的使用脚本 39660 正常进入醉道士消息 751–789，并验证桂花酒消耗与事件状态收尾；开场、黑苗客栈、出口、楼梯和实际场景启动检查继续通过。
- **涉及文件**:
  - `src/content/pal_item_definition.gd`
  - `src/content/pal_content_database.gd`
  - `src/game/script_vm.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/world/map_explorer.gd`
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_meal_and_wine_test.gd`

---

### [FT-008] [refactor] 按官方 SDLPal 重做菜单与物品页

- **关联需求**: M3 菜单与物品系统
- **关联 TODO**: TD-003（阶段性）
- **功能描述**: 移除现代整屏面板和大按钮，按官方 `PAL_InGameMenu`、`PAL_InventoryMenu` 与 `PAL_ItemSelectMenu` 的 320×200 坐标重做主菜单、装备／使用子菜单和 3×7 物品选择页。运行时解码本地 `DATA.MKF #9` 原版窗口、光标和数字 Sprite，使用原版点阵字库及调色板颜色，并从 `BALL.MKF` 显示选中物品图标；原版资源继续隔离在 `generated/`。状态、仙术、系统和装备功能仍按后续里程碑实现。
- **涉及文件**:
  - `src/ui/pal_game_menu.gd`
  - `src/content/pal_content_database.gd`
  - `src/import/pal_data_importer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_menu_visual_test.gd`
  - `README.md`
  - `docs/CLASSIC_UI.md`

---

### [FT-009] [feat] 建立中文项目文档与源码注释基线

- **关联需求**: 项目可维护性与开发可读性
- **关联 TODO**: TD-010
- **功能描述**: 新增中文文档总入口、项目目录结构、整体架构和开发工作流，说明资源导入、状态所有权、场景执行和 Git 资源边界。为全部核心 GDScript 增加模块职责及公开 API 的 Godot `##` 注释，并逐项解释 ScriptVM 已实现操作码；CI 持续检查源码注释、核心模块索引和文档内部链接。
- **验证情况**: Godot 全工程解析、142 项合成测试和 `tools/check_documentation.py` 均通过；README 可按推荐顺序进入全部中文专题文档。
- **涉及文件**:
  - `README.md`
  - `docs/`
  - `src/`
  - `tools/check_documentation.py`
  - `.github/workflows/ci.yml`

---

### [FT-010] [refactor] 将 PAL 地图迁移到 TileSet 与 TileMapLayer

- **关联需求**: M2 等距地图原生化
- **关联 TODO**: TD-011
- **功能描述**: 按唯一 `map_number` 将 32×15 GOP 索引图块转换为无损 RG8 TileSet，并用 StaticBottom/StaticTop TileMapLayer、Camera2D、原生人物 Sprite2D 和兼容覆盖层替换默认整屏 CPU 合成。alternative tile 保存阻挡与逻辑高度；清单保存 MAP/GOP SHA-256 指纹，缺失帧和越界视口按 SDLPal 官方规则兼容。CPU 渲染器保留为命令行诊断基准。
- **验证情况**: 223 张导入地图、293 个可玩场景和 221 个唯一场景地图均可加载；客栈、厨房、楼梯边界、室外和夜间屋檐五个固定视口与 CPU 基准均为 320×200 零像素差异；现有剧情、桂花酒和菜单回归继续通过。
- **涉及文件**:
  - `src/import/pal_tileset_builder.gd`
  - `src/import/pal_data_importer.gd`
  - `src/world/pal_tilemap_world.gd`
  - `src/world/map_explorer.gd`
  - `src/content/pal_content_database.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_tileset_content_test.gd`
  - `tests/run_local_tilemap_visual_test.gd`
  - `docs/SCENE_RENDERING.md`
