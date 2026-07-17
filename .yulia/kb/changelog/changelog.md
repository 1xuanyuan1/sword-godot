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

## 2026-07-17

### [FT-042] [feat] 还原经典状态页与场外仙术菜单

- **关联需求**: M3 菜单、法术与状态系统
- **关联 TODO**: TD-003（阶段性）
- **功能描述**: 开放主菜单“状态”和“仙术”入口；状态页使用原版 `FBP.MKF #0`、RGM 头像、装备图标和经典坐标显示经验、等级、HP/MP、五项属性、六件装备及毒状态。场外仙术支持多人施法者选择、3×5 列表、MP 与说明、单体目标选择及全体施放，并按顺序执行使用/成功脚本，只有完整成功后扣除一次 MP。仙术候选严格来自角色初始和升级习得表，避免物品与仙术共用 `OBJECT` 表造成误判。
- **验证情况**: 295 项合成测试、真实资源菜单视觉测试和中文文档检查通过；真实样板仙术 296“气疗术”可恢复 HP、正确扣除一次 MP，仙术页不再误显示“银杏子”，左上 MP 与说明区域无文字遮挡。
- **涉及文件**:
  - `src/content/pal_magic_object_definition.gd`
  - `src/game/script_vm.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_menu_visual_test.gd`
  - `README.md`
  - `docs/CLASSIC_UI.md`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

## 2026-07-16

### [FT-020] [feat] 推进买虾、病倒求药与山神庙主线

- **关联需求**: M3 完整场景流程
- **关联 TODO**: TD-001、TD-002、TD-008（阶段性）
- **功能描述**: 对齐固定 SDLPal `script.c`，实现 `006D` 场景进入/传送脚本改写、`0077` 停止 BGM 与官方淡出单位、`009A` 含首尾的 EventObject 批量状态修改。真实资源主线从醉道士喝完桂花酒继续覆盖李大娘给 50 文买虾、鱼嫂无鲜虾、李大娘病倒、仙药消耗、求药归来切换夜间状态和场景 1 山神庙约定提醒；同时固定初始房间皮帽与木鞋的搜索拾取回归。
- **验证情况**: 226 项合成测试通过；买虾消息 790–803、鱼嫂 1182–1188、求药归来 1190–1213、山神庙提醒 1214–1220 及运行时状态全部通过。开场、黑苗客栈、楼梯、厨房、桂花酒、皮帽/木鞋拾取、BGM 31 和 294 场景自动事件继续回归通过。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `tests/run_local_manual_search_test.gd`
  - `README.md`
  - `docs/SCRIPT_VM.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-021] [feat] 增加基于脚本数据的完整游戏攻略

- **关联需求**: 原版流程对照与完整通关验收
- **关联 TODO**: 无
- **功能描述**: 新增中文全流程攻略，从余杭客栈覆盖到南诏终战，共 18 章；记录关键道具、白河药方、京城作法材料、锁妖塔、桃源村支线、十年前南诏、36 只傀儡虫、五灵珠祭坛位置、Boss 顺序及当前 Godot 可玩边界。攻略以本机脚本、消息编号、物品表、EventObject 坐标和固定 SDLPal 行为为依据，不转储原版对白或资源。
- **验证情况**: 已用脚本表核对银杏果/鲤鱼/鹿茸消耗、木剑交换水灵珠、五灵珠祭坛坐标和当前已回归剧情入口；中文文档索引与内部链接检查通过。
- **涉及文件**:
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/README.md`
  - `README.md`

---

### [FT-022] [feat] 建立经典战斗资源与静态显示基础

- **关联需求**: M4 经典战斗提前实施
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 解析 `DATA.MKF` 中 154 条敌人属性、380 个敌队、65 个战场定义、五种敌人数站位，以及 OBJECT 敌人映射和 PLAYERROLES 战斗 Sprite/基础数值；导入 `ABC.MKF`、`F.MKF` 与全部 FBP 320×200 索引背景到本地生成目录。新增战斗样板，按 SDLPal `battle.c` 的原始锚点绘制敌队 18、战场 21、两个黑苗敌人与李逍遥/赵灵儿，并可切换敌队和战场检查资源。
- **验证情况**: 本阶段提交快照的 242 项合成测试通过；本地回归确认 380 个脚本敌队、43 个脚本战场及六名角色战斗 Sprite 可加载，敌队 18 / 战场 21 的 320×200 真实渲染截图包含双方四个 Sprite。指令选择、行动队列和胜负结算仍属于 TD-005 后续阶段。
- **涉及文件**:
  - `src/content/pal_enemy_object_definition.gd`
  - `src/content/pal_enemy_definition.gd`
  - `src/content/pal_enemy_team.gd`
  - `src/content/pal_battlefield.gd`
  - `src/content/pal_player_roles.gd`
  - `src/content/pal_content_database.gd`
  - `src/import/pal_data_importer.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/ui/import_lab.gd`
  - `scenes/battle_preview.tscn`
  - `tests/run_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-023] [feat] 接通经典普攻回合与首战操作样板

- **关联需求**: M4 经典战斗提前实施
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 新增与场景解耦的 `PalBattleController` 和移植自 SDLPal `util.c` 的可固定种子随机序列；实现全队攻击/防御指令、经典身法行动队列、双动敌人、濒死减速、玩家单体/全体普攻、暴击、李逍遥额外判定、敌人物理 AI、自动防御、最低伤害、死亡目标重选和胜负。玩家 HP 写回 `GameSession`，敌人本场 HP 留在控制器。战斗样板升级为可操作入口，可选目标、攻击、防御、查看双方 HP 和逐项结算；未实现的敌人法术会显式报告，不会静默改成普攻。
- **验证情况**: 247 项既有合成测试、19 项独立战斗逻辑检查和中文文档检查通过；固定随机序列与 SDLPal LCG 对齐。本地真实资源确认首战敌队 18 / 战场 21 可执行 41 次行动并在 30 回合内得到胜负，两个黑苗敌人不会触发尚未支持的法术分支；320×200 真实渲染仍包含双方四个 Sprite、目标光标和 HP 信息。
- **涉及文件**:
  - `src/battle/pal_battle_random.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/game/game_session.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `.github/workflows/ci.yml`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-024] [feat] 接通剧情 RNG 过场与角色仙术状态

- **关联需求**: M3 场景流程、M5 音画能力
- **关联 TODO**: TD-001、TD-006、TD-008（阶段性）
- **功能描述**: 导入器从只转换首个 RNG 分块改为转换全部可解码动画并记录逐段清单；新增全屏 `PalRngPlayer`，由 `ScriptVM 0036/0037` 选择帧区间并阻塞剧情，播放完成或资源缺失后安全续跑。`GameSession` 增加角色已学仙术状态，VM 同步实现 `001D` 角色/全队 HP/MP 修改与 `0055` 习得仙术，使御剑教学等过场之后的数值指令不会提前或丢失。
- **验证情况**: 247 项合成测试、中文文档检查和求药归来/山神庙早期主线回归通过；本地目标数据的 11 个脚本引用 RNG 动画共 1410 帧均可加载，HUD 两帧区间能按完成信号隐藏并解除 VM 等待。生成 PNG 继续只保存在被忽略的 `generated/pal/rng/`。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/import/pal_data_importer.gd`
  - `src/ui/pal_rng_player.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_rng_player_test.gd`
  - `README.md`
  - `docs/RNG_FORMAT.md`
  - `docs/SCRIPT_VM.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-025] [feat] 将经典战斗接入剧情脚本与探索 HUD

- **关联需求**: M3 场景流程、M4 经典战斗
- **关联 TODO**: TD-001、TD-005、TD-008（阶段性）
- **功能描述**: 实现 `ScriptVM 004A/0007`：保存战场编号，阻塞发出敌队/战场/Boss 请求，并在胜利、战败或逃跑后按原版入口恢复。`MapExplorer` 在 HUD CanvasLayer 上创建剧情模式战斗覆盖层，暂停地图输入、菜单、触发和自动脚本，复用探索 `GameSession` 保留战斗 HP，进入/退出时切换战斗与场景 BGM。战斗视图区分实验室重开和剧情回传；`PAL_StartBattle` 的倒地队员 1 HP 入场行为也已补齐。
- **验证情况**: 247 项既有合成测试、21 项回合逻辑检查、10 项战斗桥接检查和中文文档检查通过；真实脚本 6964/6965 确认请求敌队 18、战场 21、不可逃跑并进入等待，剧情覆盖层可使用同一个探索会话启动。首战真实资源自动普攻与 320×200 渲染回归继续通过。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_battle_bridge_tests.gd`
  - `tests/run_local_battle_bridge_test.gd`
  - `.github/workflows/ci.yml`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/SCRIPT_VM.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-026] [feat] 还原经典战斗 UI、仙术列表与物理攻击动画

- **关联需求**: M4 经典战斗提前实施
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 移除战斗顶部/底部开发文字条、自制目标三角和目标 HP，新增独立 `PalBattleUI`，按固定 SDLPal `uibattle.c` 坐标使用 `DATA.MKF #9` 绘制原版角色状态框、头像、黄/青 HP/MP 数字、当前角色箭头及攻击／仙术／合击／其他四向图标。UI 层固定高于按脚底 Y 排序的人物，避免仙术面板被角色反向盖住。选敌改为调色板低四位 `+7` 的 Sprite 闪烁，伤害改为官方蓝色数字上浮。新增 OBJECT 仙术视图与 `DATA.MKF #4` 解析，战斗仙术页可显示角色真实名称、MP 消耗和可用状态；尚未实现的施法不会冒充普攻。玩家与敌人物理攻击加入备战、接近、攻击、受击、数字和归位动画。
- **验证情况**: 252 项合成格式测试、21 项经典战斗逻辑检查、10 项剧情战斗桥接检查及中文文档检查通过。本地真实渲染验证敌队 18 / 战场 21 的官方状态框、四向指令、李逍遥“气疗术”及 6/100 MP 显示，并截取普攻接近攻击帧；生成截图继续只保存在被忽略的 `generated/pal/visual_tests/`。
- **涉及文件**:
  - `src/content/pal_magic_object_definition.gd`
  - `src/content/pal_magic_definition.gd`
  - `src/content/pal_content_database.gd`
  - `src/battle/pal_battle_ui.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`

---

### [FT-027] [feat] 接通玩家仙术结算与原版 FIRE 特效

- **关联需求**: M3 法术系统、M4 经典战斗
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 导入全部 `FIRE.MKF` 仙术逐帧 Sprite，按 `DATA.MKF #4` 的速度、重复、偏移、图层和音效字段播放原版特效；战斗控制器新增玩家仙术指令、敌我目标与 MP 校验，支持气疗术、观音咒等 `001B/001C/001D` 恢复脚本，以及按敌人抗性和战场修正结算的基础五灵攻击仙术。普通治疗不复活倒地角色；依赖毒、异常状态或持续回合脚本的仙术在对应系统完成前保持不可用，不会伪造效果或消耗 MP。
- **验证情况**: 252 项合成格式测试、30 项经典战斗逻辑检查和 10 项剧情战斗桥接检查通过；本地资源确认 55 组 FIRE 特效全部可加载，并真实渲染验证气疗术恢复 75 HP、消耗 6 MP，以及风咒消耗 5 MP、伤害敌人、目标选择、特效与 DATA 音效。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/battle/pal_battle_ui.gd`
  - `src/content/pal_content_database.gd`
  - `src/content/pal_magic_definition.gd`
  - `src/import/pal_data_importer.gd`
  - `src/ui/import_lab.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `tests/run_tests.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`

---

### [FT-028] [feat] 接通战后主经验、金钱与升级结算

- **关联需求**: M3 角色成长、M4 经典战斗
- **关联 TODO**: TD-005、TD-006（阶段性）
- **功能描述**: 新增 `PalLevelProgression` 解析 `DATA.MKF #6/#14` 的升级仙术和每级经验阈值；`GameSession` 持有主经验及升级后攻击、灵力、防御、身法和逃跑值。敌人首次倒下时累计经验/金钱，胜利后只结算一次；存活队员按官方随机范围升级、回满 HP/MP、习得当前等级仙术，全队随后执行经典差额半恢复。普通/Boss 胜利分别播放 RIX 3/2，`PalBattleUI` 使用原版窗口和点阵字显示奖励总览及八项升级前后数值。敌人战后脚本入口已保留在报告中，但在专用战斗脚本上下文完成前不会错误交给地图 VM。
- **验证情况**: 254 项合成格式测试、39 项经典战斗逻辑检查和 10 项剧情战斗桥接检查通过；真实资源确认首战敌队 18 固定获得 52 经验、96 文并让李逍遥升到 2 级，OpenGL 截图验证原版奖励与升级页面，普通/Boss 胜利音乐已本地生成且继续隔离在 `generated/`。
- **涉及文件**:
  - `src/content/pal_level_progression.gd`
  - `src/content/pal_content_database.gd`
  - `src/game/game_session.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/battle/pal_battle_ui.gd`
  - `src/import/pal_data_importer.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-029] [feat] 接通敌人基础攻击仙术与原版动画

- **关联需求**: M4 经典战斗
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 敌人 AI 按 `magic_rate` 决定施法，支持普通单体、攻击全体、攻击整体和攻击战场四类纯伤害仙术；结算复用 SDLPal 敌方灵力、角色防御、`100 + 五灵/毒抗`、倍率 20、战场修正、主动防御和 1/3 魔法自动防御公式。画面按 `PAL_BattleShowEnemyMagicAnim()` 播放敌人右下蓄势、施法帧、敌人/仙术音效、FIRE 特效、蓝色伤害、角色变色与后退。依赖毒、异常状态、召唤或脚本的敌术保持显式不支持，不退化为普攻或伪造伤害。
- **验证情况**: 254 项合成格式测试、45 项经典战斗逻辑检查和 10 项剧情战斗桥接检查通过；本地资源确认 85 个带敌术的敌人中有 58 个基础攻击敌术可准确结算，敌队 17 的敌术对象 312 已通过真实扣血和 OpenGL 动画截图，首战敌队 18 的普攻/奖励回归保持通过。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-030] [feat] 在敌人选择阶段显示目标生命条

- **关联需求**: M4 经典战斗试玩辅助
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 敌人 Sprite 按原版调色板闪烁供玩家选择时，在左上角同步显示当前目标名称、血条和真实当前／最大 HP；切换目标会立即读取 `PalBattleController` 的本场敌人状态，确认或取消目标后面板自动隐藏。该辅助 UI 不改变伤害、敌人数据或战斗结算，并在文档中明确区别于原版常驻界面。
- **验证情况**: 45 项经典战斗逻辑检查通过；真实敌队 18 / 战场 21 已生成 320×200 OpenGL 截图，确认苗人拳目标显示 360/360，退出目标阶段后数据接口返回空且面板隐藏。
- **涉及文件**:
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`

---

### [FT-031] [change] 收窄选敌生命面板并改用红色血条

- **关联需求**: M4 经典战斗试玩辅助
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 根据试玩反馈把左上角敌人生命面板从 148 像素收窄至 82 像素，接近单个主角状态框宽度；移除重复的 HP 标签，重新排列当前／最大体力数字，并把动态颜色血条统一改为红色，降低对原版战场画面的遮挡。
- **验证情况**: 真实敌队 18 / 战场 21 的 320×200 OpenGL 截图回归通过，苗人拳名称、360/360 数字和红色血条均完整显示，玩家状态框及目标闪烁不受影响。
- **涉及文件**:
  - `src/battle/pal_battle_ui.gd`
  - `docs/BATTLE.md`

---

### [FT-032] [feat] 接通双方普通攻击原版音效

- **关联需求**: M4 经典战斗音画同步
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 扩展 `PLAYERROLES` 解析角色攻击、武器、暴击、格挡和死亡音效字段；玩家普攻在起手和命中帧分别播放角色原版音效，暴击使用独立编号。敌人物理攻击同步播放敌人属性中的攻击、动作及命中音效，自动格挡和角色倒下改用对应角色音效，不再出现只有动作没有声音的普攻。
- **验证情况**: 255 项合成检查和 45 项经典战斗逻辑检查通过；本地 DOS 数据确认李逍遥攻击／武器／暴击音效分别解析为 37／1／5，战斗 Debug 已重启供实际听感验证。
- **涉及文件**:
  - `src/content/pal_player_roles.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_tests.gd`
  - `tests/run_battle_logic_tests.gd`
  - `docs/BATTLE.md`

---

### [FT-033] [feat] 实现战斗物品、原版其他菜单与逃跑

- **关联需求**: M4 经典战斗
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 按 `uibattle.c` 接入“自动／物品／防御／逃跑／状态”和“使用／投掷”菜单，复用原版 3×7 物品网格、数量、BALL 图标及说明；指令阶段预留消耗数量，执行时才写回背包。基础恢复品支持 `001B/001C/001D`，暗器支持 `0042` 模拟仙术、`0021` 固定伤害和 `0066` 武器伤害，并播放角色用物/投掷帧、FIRE 特效、音效及数字。逃跑按全体存活敌人身法/等级与角色逃跑值结算，成功返回 `FLED = 3`，Boss 战强制失败并播放反馈。
- **验证情况**: 255 项合成检查、55 项经典战斗逻辑和真实资源回归通过；当前数据 29 个基础使用物品、49 个基础投掷物品可执行，止血草恢复 50 HP、梅花镖扣库存伤敌、普通战逃跑均已真实结算。其他/物品三级菜单、使用、投掷 FIRE 与全队逃跑动画已生成 320×200 OpenGL 截图。
- **涉及文件**:
  - `src/content/pal_item_definition.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-034] [feat] 恢复 R 键重复上一回合战斗指令

- **关联需求**: M4 经典战斗
- **关联 TODO**: TD-005（阶段性）
- **功能描述**: 对齐官方 `input.c::kKeyRepeat`、`fight.c::PAL_BattleCommitAction()` 与经典回合 `fRepeat`，在战斗主指令阶段按 `R` 可让当前及后续队员按各自缓存重复上一回合动作、对象编号和目标。首回合空缓存转为普攻；攻击仙术/投掷物资源不足时降级为普攻，恢复仙术/使用物品资源不足时降级为防御；临时降级不会覆盖缓存，资源恢复后仍可重复原指令。
- **验证情况**: 255 项合成检查、64 项经典战斗逻辑、10 项剧情战斗桥接、真实首战逻辑及 OpenGL 战斗回归通过；覆盖首回合全队普攻、两类仙术 MP 不足降级、两类物品耗尽降级、缓存不被降级动作污染、物品重复预留与实际 `KEY_R` 输入入口。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`
  - `.yulia/kb/changelog/todo.md`

---

### [FT-035] [feat] 接通六槽装备、原版装备页与战斗属性

- **关联需求**: M3 装备系统、M4 经典战斗数值
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 解析 `PLAYERROLES` 六槽初始装备，新增 `PalEquipmentManager` 对齐 SDLPal `0017/0018/001A/0023/002D` 的装备、换装、属性和卸装语义；装备与背包交换、角色许可、攻击/灵力/防御/身法/逃跑、毒抗、五灵抗性、攻击全体和战斗 Sprite 覆盖统一保存到 `GameSession`。经典“物品 → 装备”已启用，使用 `FBP.MKF #1` 原版背景显示物品图标、队员、六件当前装备和实时属性，并保留换下物品继续选择的 `wLastUnequippedItem` 行为。战斗开始前自动重建装备效果，修复李逍遥初始六件装备未生效造成的最低伤害问题；剧情 `0020` 也会按原版在背包不足时移除已装备物品。
- **验证情况**: 273 项基础合成检查、20 项装备系统检查、65 项经典战斗逻辑、10 项剧情战斗桥接和中文文档检查通过；真实资源确认李逍遥初始装备为头巾、披风、布袍、木剑、草鞋、护腕，属性为攻 35／灵 20／防 41／身 31／逃 32，对绿叶小妖固定回归普攻为 40 点；原版装备页 OpenGL 快照已生成到被忽略的 `generated/`。
- **涉及文件**:
  - `src/content/pal_player_roles.gd`
  - `src/content/pal_item_definition.gd`
  - `src/game/game_session.gd`
  - `src/game/pal_equipment_manager.gd`
  - `src/game/script_vm.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/world/map_explorer.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_equipment_tests.gd`
  - `tests/run_tests.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_menu_visual_test.gd`
  - `.github/workflows/ci.yml`
  - `README.md`
  - `docs/EQUIPMENT.md`
  - `docs/CLASSIC_UI.md`
  - `docs/BATTLE.md`

---

### [FT-036] [feat] 接通经典战斗毒、异常状态与回合末结算

- **关联需求**: M3 法术与状态系统、M4 经典战斗
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 解析 OBJECT 毒等级、颜色和敌我脚本，将玩家跨战斗毒/状态保存到 `GameSession`，敌人毒/状态保存到单场控制器；新增战斗效果脚本解释器，接入概率/条件分支、HP/MP、固定伤害、复活、敌我下毒、按种类/等级解毒、状态设置/移除、吸血和立即击倒。经典回合末严格按玩家毒→玩家状态递减→敌人毒→敌人状态递减结算，并让毒杀进入真实胜负/奖励路径。混乱、定身、昏睡、封咒、傀儡、勇气、防护、加速、双击全部进入指令限制、队列和伤害行为；装备双击保持为不被普通递减/解咒清除的持久效果。敌人物理攻击的附带物品毒脚本、状态敌术、毒性受击色偏、数字和提示也已接通。
- **验证情况**: 273 项基础合成检查、20 项装备系统检查、93 项经典战斗逻辑、10 项剧情战斗桥接和中文文档检查通过；真实资源确认 60/85 个已接入/全部敌术、68/49 个使用/投掷物品脚本可执行，551 号基础毒在经典回合末造成 7 点伤害，首战普攻 40 点、52 经验/96 文、敌术 312、止血草、梅花镖与逃跑继续通过；OpenGL 回归新增毒性结算截图。
- **涉及文件**:
  - `src/content/pal_poison_definition.gd`
  - `src/content/pal_content_database.gd`
  - `src/game/game_session.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/EQUIPMENT.md`
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-037] [feat] 恢复经典合击与角色保护格挡

- **关联需求**: M4 经典战斗
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 补充 PLAYERROLES 的 `covered_by` 与 `cooperative_magic` 字段解析，并让装备效果组 65 按官方顺序覆盖基础合击。右侧合击图标按经典健康条件启用，支持单体目标、提交后结束余下指令、身法乘 10、跳过本轮其他玩家行动和 `R` 重复；每名健康贡献者消耗仙术 MP 数值对应的 HP且最低保留 1，合计武术/灵力后按原版魔法伤害、抗性和战场修正结算。画面还原多人合击站位、音效 29、施法帧与 FIRE 特效。敌人物理攻击抽中自动防御时，会按 `covered_by` 让健康队友移动到濒死/异常目标前方，以保护帧和原版音效零伤害格挡；异常目标找不到健康保护人时不能自行闪避。
- **验证情况**: 274 项基础合成检查、22 项装备系统检查、104 项经典战斗逻辑、10 项剧情战斗桥接和中文文档检查通过；真实资源确认李逍遥合击对象 386“合体气功”、每位贡献者消耗 9 HP，角色保护关系与 60/85 个敌术继续可加载；OpenGL 回归新增合体气功多人动画和保护格挡截图，首战、物品、仙术、毒性结算及奖励页保持通过。
- **涉及文件**:
  - `src/content/pal_player_roles.gd`
  - `src/game/game_session.gd`
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_tests.gd`
  - `tests/run_equipment_tests.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/EQUIPMENT.md`
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-038] [feat] 接通敌人回合、就绪与战后脚本上下文

- **关联需求**: M4 经典战斗
- **关联 TODO**: TD-003、TD-005（阶段性）
- **功能描述**: 为每个单场敌人复制 `script_on_turn_start`、`script_on_ready`、`script_on_battle_end` 游标和可变仙术字段，新增专用敌人战斗脚本解释路径；在玩家选指令前、敌人行动前和胜利结算时按 SDLPal 顺序执行，支持流程/概率分支、战斗内上下/下方/居中对白、音效与音乐、减半体力、HP 百分比分支、动态换仙术、立即击倒、敌人逃跑、队伍成员/重复敌人条件、召唤、分裂、变身及随机掉落。逻辑副作用通过类型化 `ScriptEvent` 交给战斗画面，复用既有对话框、音频和 Sprite 阵列播放；敌人脚本终止使用独立结果，不误走玩家逃跑或胜利奖励。
- **验证情况**: 274 项基础合成检查、22 项装备系统检查、123 项经典战斗逻辑、10 项剧情战斗桥接和早期主线回归通过；真实资源确认 27/22/10 个敌人回合/就绪/战后入口的可达操作码全部受支持，敌队 22 对白、敌队 25 脚本逃跑和敌队 46 双掉落可执行，60/85 个敌术与 68/49 个使用/投掷物品脚本继续可加载；OpenGL 新增敌队 22 战斗对白截图，原有合击、保护、仙术、物品、毒性和奖励截图全部通过。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `README.md`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-039] [feat] 贯通黑苗人离店与山神庙御剑教学回归

- **关联需求**: M3 完整场景流程、M5 完整通关回归
- **关联 TODO**: TD-001、TD-008（阶段性）
- **功能描述**: 纠正脚本 `6254` 的剧情语义，将其固定为黑苗人夜间离开客栈及 EventObject 60–62 自动脚本回归；新增真实山神庙醉道士入口 `6622` / EventObject 196 的完整教学回归，覆盖消息 `1360–1400`、RNG #1、渐隐与音乐、李逍遥习得对象 345、全队 HP/MP 恢复、日间调色板、角色位置/造型、27 个关键事件状态，以及场景 7 后续进入脚本 `6767`。测试驱动同步支持显式完成 RNG 等待，确保动画后的技能与剧情状态不会提前生效。
- **验证情况**: 274 项基础合成检查、22 项装备系统检查、123 项经典战斗逻辑、10 项剧情战斗桥接、中文文档门禁和早期主线真实资源回归全部通过；买虾、求药归来、黑苗人夜间离店、山神庙御剑教学、张四登船、仙灵岛抵达及道具叙述 Toast 可连续纳入同一自动门禁，测试不输出或提交原版文本。
- **涉及文件**:
  - `tests/run_local_early_mainline_test.gd`
  - `README.md`
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/SCRIPT_VM.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-040] [feat] 贯通天亮返店与赵灵儿营救战后剧情

- **关联需求**: M3 场景流程、M4 经典战斗桥接、M5 完整通关回归
- **关联 TODO**: TD-001、TD-005、TD-008（阶段性）
- **功能描述**: 对齐固定 SDLPal `script.c`，把保留操作码 `0078` 实现为官方空操作，并在场景 VM 接入 `0022` 按最大 HP 十分比复活当前角色或全队、清除三级以下毒与临时状态；复活规则下沉到 `GameSession`，战斗效果脚本与场景剧情共用同一语义。真实资源回归从御剑教学继续覆盖天亮独白、余杭日间音乐、李大娘早餐对话和客房赵灵儿营救入口 `6906`，验证赵灵儿临时入队、敌队 18／战场 21 请求、模拟胜利、战后复活回满、正式入队、音乐渐隐及后续 EventObject 入口。
- **验证情况**: 277 项基础合成检查、22 项装备系统检查、123 项经典战斗逻辑、10 项剧情战斗桥接、真实脚本战斗桥接、中文文档门禁和扩展后的早期主线回归全部通过；脚本 `6906–7017` 的消息 `1475–1512` 可越过战斗等待完整执行，不再停在 `0078`，且测试不输出或提交原版文本。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/battle/pal_battle_controller.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `README.md`
  - `docs/SCRIPT_VM.md`
  - `docs/BATTLE.md`
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-041] [feat] 贯通赵灵儿同行再次赴仙灵岛

- **关联需求**: M3 场景流程、M5 完整通关回归
- **关联 TODO**: TD-002、TD-008（阶段性）
- **功能描述**: 将营救战后的李大娘入口 `7031`、稳定提醒 `7067`、张四送行 `7071`、余杭码头登船 `5925` 和仙灵岛双人抵达入口 `9541` 接入同一真实主线回归；验证消息 `1514–1552`、码头/船只/张四状态、船与队伍同步驶离、渐隐、落点、李逍遥与赵灵儿队伍顺序、场景 BGM 70 及战斗 BGM 37。首次求药赴岛改用重新加载的干净内容数据库独立验证，避免第二次赴岛改写场景入口后掩盖首次抵达对白。
- **验证情况**: 扩展后的早期主线真实资源回归和中文文档门禁通过；买虾、求药归来、御剑教学、营救战及首次/再次乘船赴岛可同时回归，测试继续只记录消息编号和状态，不输出或提交原版文本。
- **涉及文件**:
  - `tests/run_local_early_mainline_test.gd`
  - `README.md`
  - `docs/GAME_WALKTHROUGH.md`
  - `docs/SCRIPT_VM.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

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

---

### [FT-011] [feat] 接通探索 BGM、音效与系统音量菜单

- **关联需求**: M1、M3、M5 音画与经典菜单
- **关联 TODO**: TD-012
- **功能描述**: 扫描剧情脚本中的场景/战斗音乐引用，用固定 SDLPal 的 RIX/OPL 实现离线生成 72 首 Godot WAV；新增 `PalAudioPlayer` 的单 BGM 声道、八声道短音效池、循环和淡入淡出，将 `0x0043/0x0047` 接入实际播放。第一个场景按脚本播放曲目 31 和剧情音效 98；探索移动和经典菜单增加集中配置的反馈音。系统页沿用原版五行窗口，可分别以 0–100 调节音乐与音效并立即生效。
- **验证情况**: 164 项合成测试、首场景 67 条对话/音频请求、本地 BGM 31 与 VOC 98 加载、菜单/脚步音效、独立音量、出口/楼梯/厨房转场、223 张 TileMapLayer 全量加载及中文文档门禁均通过；真实探索场景连续运行无音频错误。
- **涉及文件**:
  - `src/audio/pal_audio_player.gd`
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/import/pal_data_importer.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_audio_test.gd`
  - `tests/run_local_intro_test.gd`
  - `tests/run_local_menu_visual_test.gd`
  - `docs/AUDIO.md`
  - `docs/CLASSIC_UI.md`
  - `tools/rix_renderer/README.md`

---

### [FT-012] [feat] 补齐早期场景 EventObject 自动行为

- **关联需求**: M2–M3 场景探索
- **关联 TODO**: TD-002
- **功能描述**: 对齐 SDLPal `PAL_RunAutoScript` 与 `play.c`，补齐自动脚本同帧跳转、概率分支、NPC 动作、剧情音效、临时隐藏、追逐、速度 4/8 路线、直接移动、逻辑层、区域判断和原地动画。EventObject 的正负消失计时与镜头外重现恢复官方生命周期；追逐读取当前 PAL 地图和事件阻挡，NPC 自动进入接触范围后可在同一更新周期触发剧情。
- **验证情况**: 173 项合成测试通过；前六个剧情场景各运行 120 个自动脚本帧，无未支持指令，35 个事件发生动作或状态变化；开场 67 条对话、黑苗客栈对话/NPC 入房、500 文、出口、楼梯、厨房、酒菜 Toast 与桂花酒流程全部回归通过。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_auto_script_test.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`
  - `README.md`

---

### [FT-013] [feat] 建立全剧情场景自动事件门禁

- **关联需求**: M2–M3 场景探索
- **关联 TODO**: TD-002
- **功能描述**: 补齐 EventObject 自动脚本调用的即时子脚本安全子集，使修改自动/触发入口、剧情音效和直接移动不会静默提前结束；将早期六场景检查升级为全部 294 个剧情场景的 120 帧自动事件回归，并保留 `--early-scenes` 快速模式。
- **验证情况**: 175 项合成测试通过；294 个剧情场景全量自动脚本门禁无未支持指令，约 1,500 个事件发生动作、路线、状态或入口变化；开场和桂花酒真实剧情回归继续通过。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_event_auto_script_test.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-014] [feat] 接通场景传送离开脚本生命周期

- **关联需求**: M2–M3 场景路由与 ScriptVM
- **关联 TODO**: TD-001、TD-002
- **功能描述**: 实现操作码 `0038`，在脚本明确传送离开时执行当前 `SCENE.script_on_teleport`，支持子脚本等待、落点、`0059` 切场景和返回调用者；场景没有传送脚本时按 `op0` 走失败入口。实现 `00A1` 队伍收拢状态，传送后队员临时叠到队长位置，下一次正常移动恢复队伍轨迹。
- **验证情况**: 180 项合成测试通过；真实场景 6 从离开入口执行脚本 `6051` 后进入场景 4，落点、音效和队伍收拢正确；客栈出口、楼梯、厨房入口与开场稳定入口继续通过。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-015] [change] 对齐官方手动搜索事件范围

- **关联需求**: M2–M3 场景探索
- **关联 TODO**: TD-002（阶段性）
- **功能描述**: 将“选择附近最近事件”的临时实现替换为 SDLPal `PAL_GetSearchTriggerRange`/`PAL_Search` 的 13 点 half 格扫描；搜索模式 1/2/3 分别限制前 2/8/13 个检查点，同格事件保持 EventObject 全局顺序。命中普通动画 NPC 后恢复站立帧、转向队伍并清除队伍遗留动作，特殊剧情帧保持不变。
- **验证情况**: 193 项合成测试通过，覆盖朝东 13 点序列、身后排除、SearchNear/SearchNormal 边界、同格优先级和 NPC 转身；本地客栈事件 5 按真实资源命中且脚本 `0x18AE` 完整结束，开场、黑苗客栈、出口、楼梯、厨房及桂花酒回归继续通过。
- **涉及文件**:
  - `src/content/pal_event_object.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_manual_search_test.gd`
  - `README.md`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-016] [change] 对齐接触事件扫描与站立行为

- **关联需求**: M2–M3 场景探索
- **关联 TODO**: TD-002（阶段性）
- **功能描述**: 按 SDLPal `PAL_GameUpdate` 对齐接触事件的严格加权距离边界、EventObject 顺序和 NPC 朝向；接触有动画对象时恢复 NPC 第 0 帧及队伍站立姿势。新增可续跑扫描状态，使前一个触发脚本等待对话、帧数或自动行走后，仍能从下一个重叠对象继续；场景切换时安全取消旧扫描。
- **验证情况**: 204 项合成测试通过，覆盖严格 16 像素边界、消失对象、NPC 转向、空入口跳过和重叠脚本顺序；真实客栈楼梯由 EventObject 3 的接触范围启动并完成 8 步动画，开场、黑苗客栈、厨房、传送离开和桂花酒流程继续通过。
- **涉及文件**:
  - `src/content/pal_event_object.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-017] [feat] 增加阻挡型 NPC 队伍脱困行为

- **关联需求**: M2–M3 场景探索
- **关联 TODO**: TD-002（阶段性）
- **功能描述**: 对齐 SDLPal `PAL_GameUpdate` 的队伍挤占处理；阻挡型有 Sprite NPC 自动移动到队伍脚下时，从 NPC 朝向的下一方向开始旋转尝试四个 half 格，将队伍平移到首个可走位置。被动位移保持队伍朝向和历史轨迹，避免门口路线冲突伪装成主动行走或永久卡住玩家。
- **验证情况**: 210 项合成测试通过，覆盖首选方向、候选阻挡后的旋转、轨迹/朝向保持和无 Sprite 触发点排除；294 个剧情场景共 1539 个 EventObject 发生动作或状态变化且无未支持指令，开场、黑苗 NPC 入房、楼梯、厨房、传送离开和桂花酒流程继续通过。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-018] [refactor] 统一 PAL 菱形地图碰撞坐标

- **关联需求**: M2 等距地图探索
- **关联 TODO**: TD-002（阶段性）
- **功能描述**: 新增 `PalMapCoordinates`，按 SDLPal `PAL_CheckObstacleWithRange` 的 32×16 菱形四区规则，把任意世界像素统一映射到 MAP `(x,y,half)`；`MapExplorer` 主动移动、`PalTileMapWorld` TileSet 自定义阻挡和 `ScriptVM` NPC 追逐改用同一换算。玩家主动移动同时恢复固定队伍偏移对应的左上视口边界，脚本和 NPC 路径仍可使用完整地图范围。
- **验证情况**: 217 项合成测试通过，覆盖 half 0/1、东/南/东南菱形区域和玩家视口边界；223 张导入地图、293 个可玩场景和 221 个唯一地图均可加载，294 个剧情场景自动脚本无未支持指令，开场、黑苗客栈、楼梯、厨房、传送离开和桂花酒流程继续通过。
- **涉及文件**:
  - `src/world/pal_map_coordinates.gd`
  - `src/world/map_explorer.gd`
  - `src/world/pal_tilemap_world.gd`
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/SCENE_RENDERING.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`

---

### [FT-019] [fix] 对齐 EventObject 移动阻挡半径

- **关联需求**: M2 等距地图探索
- **关联 TODO**: TD-002（阶段性）
- **功能描述**: 将 MapExplorer、TileMap 队员回退和 ScriptVM NPC 路径的事件阻挡从临时近似 `≤12` 统一为 SDLPal `PAL_CheckObstacle` 的严格加权距离 `<16`；`≤12` 只保留给 NPC 已挤占队伍脚点后的脱困。碰撞按原版读取正 `state`，正 `vanish_time` 临时隐藏不会解除阻挡。
- **验证情况**: 222 项合成测试通过，覆盖加权距离、15/16 边界和临时隐藏阻挡；294 个剧情场景自动脚本无未支持指令，1536 个 EventObject 正常发生动作或状态变化，黑苗 NPC 入房、楼梯、厨房、传送离开和桂花酒流程继续通过。
- **涉及文件**:
  - `src/world/pal_map_coordinates.gd`
  - `src/world/map_explorer.gd`
  - `src/world/pal_tilemap_world.gd`
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `docs/ARCHITECTURE.md`
  - `docs/SCENE_RENDERING.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`
