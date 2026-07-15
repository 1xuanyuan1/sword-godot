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
