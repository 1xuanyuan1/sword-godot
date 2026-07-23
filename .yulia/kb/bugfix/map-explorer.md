---
name: '地图探索交互 Bug 修复记录'
summary: '记录地图探索输入、菜单和场景交互问题及修复'
keywords:
  - map-explorer
  - input
  - 地图探索
  - 菜单
---

# 地图探索交互 Bug 修复记录

## 修复记录

## 2026-07-23

### [BF-049] 桌面运行时目录分流导致 Web 发布包找不到内置内容

- **来源**: 发布自测
- **关联需求**: M5 Web 发布质量
- **问题描述**: `PalRuntimePaths` 最初只区分编辑器与非编辑器，把所有导出包都指向 `user://generated/pal`。桌面包需要该可写目录执行首次导入，但 EVA Web 包会把已生成内容内置在只读的 `res://generated/pal`，因此更新后的网页包会在启动时找错数据库。与此同时，Web 暂存工程只链接 `generated/scenes/shaders/src`，遗漏新加入的 `assets/ui/status_condition_icons.png`；Godot 报 `ICON_ATLAS` 解析错误却仍以退出码 0 产出损坏包。
- **涉及文件**:
  - `src/game/pal_runtime_paths.gd`
  - `tests/run_tests.gd`
  - `tools/prepare_eva_web_project.mjs`
- **修复内容**: 运行时目录现在明确区分编辑器、Web 与桌面：编辑器／Web 从 `res://generated/pal` 读取，只有桌面导出使用 `user://generated/pal`。Web 暂存工程同步链接 `assets/`，确保状态图集及后续代码资源依赖可参与导入。新增 Web 路径合成断言，387 项检查通过；EVA 工程重新构建为 12 个 gzip 分片，过滤日志无 Parse/Compile 错误，并在 Chromium WebGL 2 中完成全部分片下载解压、正式 TileMap 启动、中文对话和资源加载检查，控制台无脚本或资源错误。
- **状态**: ✅ 已修复

---

### [BF-051] Android 开始新游戏被导出重映射检查禁用

- **来源**: 用户试玩反馈
- **关联需求**: Android 本地验收包与移动端触控
- **问题描述**: Android 资源实验室中的“开始新游戏”不可点击；即使从正式标题菜单进入，地图也可能加载失败。根因是 Godot 导出后只保留 TileMap 场景的 `.tscn.remap` 和字库 PNG 的导入纹理，资源实验室与 `PalContentDatabase` 却用 `FileAccess` 检查原始 `.tscn`，启动、菜单和战斗 UI 也从文件系统直接读取原始字库 PNG。源码工程因原文件存在而无法暴露该问题；标题菜单同时缺少通过 `_input` 接收 Android `InputEventScreenTouch` 的兜底路径。
- **涉及文件**:
  - `src/content/pal_content_database.gd`
  - `src/ui/import_lab.gd`
  - `src/ui/pal_classic_font.gd`
  - `src/ui/pal_startup.gd`
  - `src/ui/pal_game_menu.gd`
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_startup_load_test.gd`
  - `export_presets.cfg`
  - `README.md`
- **修复内容**: TileMap 场景存在性与加载统一改走 `ResourceLoader`，使 `.tscn.remap` 能按原始 `res://` 路径解析；经典字库增加共享加载入口，优先读取包内导入纹理并兼容桌面 `user://` 原始 PNG，启动、菜单和战斗复用同一规则。标题菜单在 `_input` 层直接消费真实 `InputEventScreenTouch`，不依赖触摸转鼠标。启动回归通过 Viewport 派发真实触摸验证“新的故事／旧的回忆”和实验室按钮；Android 同款 PCK smoke 真实加载数据库、音乐、字库与地图 12，全部成功。验收包提升到 `0.1.3(4)`。
- **状态**: ✅ 已修复

## 2026-07-22

### [BF-043] 大理庆典场景入口因有限循环没有事件上下文而永久卡住

- **来源**: 主线自测
- **关联需求**: M5 五灵珠祭雨与大理之战主线
- **问题描述**: SDLPal 以 EventObject `0xFFFF` 运行场景进入脚本，先沿用最近触发转场的事件对象；`0002/0003 op1` 的有限循环也借该对象保存计数。`MapExplorer` 却用默认事件编号 0 启动场景入口。大理庆典入口 `38555` 包含两个八次有限移动循环，因没有 EventObject 无法累计次数，脚本永久回跳且地魔兽战、无底深渊和后续主线都不可达。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_dali_altar_battle_mainline_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 场景入口统一以 `0xFFFF` 交给 `ScriptVM`，精确沿用最近 EventObject，同时继续由场景定义保存脚本返回的新入口。合成回归先运行普通事件建立最近对象，再通过正式 `MapExplorer` 场景入口验证三次有限移动后自然结束并清零计数；第十七章真实资源回归直接执行庆典入口，完成消息 `12502–12534`、地魔兽敌队 287／战场 36 和场景 290 转场。
- **状态**: ✅ 已修复

## 2026-07-20

### [BF-042] 解救林月如战后没有自动进入刺伤与复活术过场

- **来源**: 用户试玩反馈
- **关联需求**: M5 苏州城外解救林月如主线
- **问题描述**: 敌队 22 胜利后，脚本 `10357` 会把更早的 EventObject 413 设为可见，并以触碰脚本 `10390` 播放林月如刺伤李逍遥、赵灵儿救治及习得复活术。接触扫描在当前 EventObject 420 完成后只从数组后续位置继续，因而漏掉数组更早的 413；地图画面仍可打开 ESC 菜单，但方向键和后续剧情状态表现为像卡住。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_local_suzhou_rescue_runtime_test.gd`
- **修复内容**: 每个触碰脚本结束后重新从当前场景事件数组头部扫描，并记录本轮已经处理的 EventObject，避免重复触发当前对象；因此既能发现 413 这类刚刚启用的前置事件，也不会让可重复触碰事件递归。新增正式 `MapExplorer + TileMapLayer + PalTileMapWorld` 回归，实际覆盖敌队 22 胜利、10390 刺伤救治、队伍恢复和赵灵儿 301 号复活术习得。
- **状态**: ✅ 已修复

### [BF-037] 水月宫惨案后重入客栈会重播李大娘带走赵灵儿剧情

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 水月宫惨案返航与余杭客栈夜间主线
- **问题描述**: 夜间长剧情结束前，楼下李大娘 EventObject 57 被切到离场自动脚本 `7476`，但脚本只给了部分移动帧就切回客房；对象因此以可见状态和旧触发入口 `7294` 保留在运行时。玩家睡醒后再次进入楼下时，对象会继续重播离场动作，并可能在隐藏前重新触发李大娘带走赵灵儿的旧对白；本机问题存档也精确保存了 `state=2 / auto_script=7476 / trigger_script=7294` 的矛盾状态。
- **涉及文件**:
  - `src/content/pal_content_database.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `tests/run_local_scene_transition_test.gd`
- **修复内容**: 场景重入前识别剧情运行时后来安装或已推进、且线性终点明确为 `0049` 隐藏自身的 NPC 离场自动脚本，直接把对象推进到隐藏后的稳定入口；原始 EventObject 自带的自动脚本保持首次正常演出。连续主线回归新增“次日再次进入楼下”检查，真实 `MapExplorer` 回归复现旧存档状态并确认 `7294/7346` 不再可触发；带窗口 OpenGL 测试通过正式 `TileMapLayer + PalTileMapWorld` 路径保存并检查重入截图。现有存档在下次载入对应场景时也会自动收束残留离场状态。
- **状态**: ✅ 已修复

---

### [BF-041] 未装备玉佛珠也能通过乱葬岗尸妖封锁

- **来源**: 主线自测
- **关联需求**: M5 黑水镇、乱葬岗与将军冢主线
- **问题描述**: 乱葬岗入口脚本 `16393` 使用唯一一条真实 `0086 274,0,16398` 检查队伍是否装备玉佛珠。当前实现直接把第二操作数当数量下限，因而将 0 解释为“需要零件”，未装备玉佛珠时也会隐藏封锁对象 1252 并进入将军冢；场外 `ScriptVM` 和战斗效果解释器存在同一错误。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `src/battle/pal_battle_controller.gd`
  - `tests/run_script_opcode_behavior_tests.gd`
  - `tests/run_local_blackwater_tomb_mainline_test.gd`
- **修复内容**: 在 `GameSession` 统一实现装备数量门槛，保留多件装备检查，同时把 DOS 原始数据的零操作数按至少一件解释；场外和战斗脚本共用该规则。合成回归覆盖零操作数在未装备／已装备时的两条分支，真实主线先确认未装备会显示消息 `4927–4928` 且封锁保留，再由赵灵儿通过真实装备脚本穿戴玉佛珠并确认对象 1252 隐藏、入口推进到 `16271`。
- **状态**: ✅ 已修复

---

## 2026-07-17

### [BF-016] 客栈房门转场后移动与交互永久失效

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 场景转场与探索输入
- **问题描述**: 客栈房门脚本依次执行 `0059` 场景切换与 `0050` 渐隐。场景请求在下一帧过早应用，自动渐显因此杀掉尚未结束的渐隐 Tween；画面虽恢复正常，渐隐绑定的 VM 完成回调却永久丢失，使 `waiting_for_screen_fade` 一直为真，方向键、交互和菜单全部被拦截，只有 F10 返回仍可响应。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_local_scene_transition_test.gd`
- **修复内容**: 活动渐变期间不再应用待处理场景；渐变结束时先清理已完成 Tween、恢复 ScriptVM，再加载待处理场景并执行自动渐显。真实 `MapExplorer` 生命周期回归覆盖 `4667` 房门脚本，等待转场完成后检查所有输入门禁均已清空，并实际移动一步。
- **状态**: ✅ 已修复

---

### [BF-024] 仙灵岛洗澡与晃衣服过场被黑色渐变遮罩覆盖

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 仙灵岛主线过场与屏幕渐变
- **问题描述**: 洗澡脚本 `9649` 在花树场景中多次执行 `0050` 渐隐，并紧接 `007F` 移动或复位剧情镜头。Godot 版只在后续 `0005` 重绘或脚本结束时消费待渐显状态，因此赵灵儿洗澡、上岸和李逍遥用树枝晃衣服的画面会被顶层黑色遮罩盖住；第一次尝试把渐显统一移到 `_refresh_world()` 尾部，又会因诊断渲染提前返回而让遮罩永久全黑。早期视觉测试还错误载入场景 19 / 地图 9，只看到李逍遥动作，漏掉了场景 13 / 地图 119 的花树背景与赵灵儿 EventObject 209。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 先完整回滚会扩大黑屏范围的负修复，再按官方 `script.c 007F → PAL_MakeScene` 与 `scene.c fNeedToFadeIn` 时序，在镜头完成真实世界重绘后消费待渐显状态，同时保留 `0005` 重绘兜底。真实回归固定正确的场景 13 / 地图 119、剧情入口 `9649`、触发事件 204、赵灵儿 MGO 339，并检查发现衣服、洗澡姿势、上岸后第 9–16 帧及最终遮罩状态；带窗口运行时保存并检查 320×200 像素截图。剧情测试暂留“仙灵岛洗澡过场（待验收）”入口供人工确认。
- **状态**: ✅ 已修复

---

### [BF-025] 仙灵岛追打剧情中李逍遥没有保持倒地姿势

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 仙灵岛主线人物动作
- **问题描述**: 赵灵儿追打李逍遥的脚本先用 `006E` 做两次小步位移，再切到特殊 Sprite 193，并通过 `0015 0,0,0` 指定第 0 帧倒地。`006E` 留下的 `_showing_walk_frame` 为真时，渲染器会跳过刚设置的剧情帧，继续取步态帧，因此李逍遥看起来仍然直立；黑屏修复后这一原本被遮住的动作错误变得可见。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 让当前有效的 `party_script_frames` 始终优先于残留步态标志；真正的普通移动仍由 `record_party_step()` 清除旧姿势，不影响行走动画。新增合成回归复现“移动标志仍为真、随后重新下发 `0015`”的顺序，并把真实洗澡回归继续执行到 EventObject 205 的追打段，核对 Sprite 193 第 0 帧数据及带窗口像素截图。
- **状态**: ✅ 已修复

---

### [BF-027] 默认 TileMap 渲染仍把李逍遥倒地帧画成腾空帧

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 TileMap 原生地图与仙灵岛人物动作
- **问题描述**: BF-025 只修改了 `MapExplorer` 内被默认隐藏的 CPU 对照选帧函数，实际游戏使用的 `PalTileMapWorld._party_frame()` 仍在 `_showing_walk_frame` 为真时忽略 `0015` 剧情帧。测试也只直接调用 CPU 函数，因此误报通过；从正式存档或剧情测试进入都会继续显示 Sprite 193 的腾空/步态帧。
- **涉及文件**:
  - `src/world/pal_tilemap_world.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `docs/SCENE_RENDERING.md`
- **修复内容**: 将 TileMap 原生选帧规则同步为“有效剧情帧优先”，并把合成回归改为同时检查 CPU 与 TileMap 两个后端返回同一索引帧。真实资源回归进一步直接读取 `PalTileMapWorld` 当前帧，与 Sprite 193 第 0 帧逐像素索引比较；带窗口截图确认默认 TileMap 画面中的李逍遥横向倒地。
- **状态**: ✅ 已修复

---

### [BF-028] 水月宫求婚后因 0080 未实现而提前结束剧情

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 水月宫成亲与过夜主线
- **问题描述**: 李逍遥答应娶赵灵儿后，官方脚本 `9136` 使用操作码 `0080` 在日间与夜间调色板之间切换。Godot `ScriptVM` 尚未实现该指令，因而把它当作未支持操作并立即结束触发脚本；对白关闭后错误恢复玩家控制，床边只会提示“附近没有可交互事件”，后续睡觉、“一夜过去”和天亮离开流程全部没有执行。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 对齐官方 `script.c` 实现 `0080` 昼夜调色板切换，并在 `op0=0` 时请求正式 TileMap 场景同步最终调色板；黑色 FBP 准备完成后替换已经结束的顶层渐隐遮罩，保证“一夜过去”叙述显示在黑底之上。新增两次切换可逆、黑屏叙述层级的合成回归，以及真实资源脚本 `8992–9186` 回归，确认消息 `2294–2362` 完整执行、夜间最终恢复白天、李逍遥恢复普通造型、床边事件进入稳定脚本 `9187`，且离场事件被隐藏。
- **状态**: ✅ 已修复

---

### [BF-030] 喂药后读档仍沿用李逍遥剧情 Sprite 导致步态异常

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 求药归来主线、TileMap 人物渲染与 Godot 存档
- **问题描述**: 给李大娘服用紫金丹的剧情会把李逍遥临时切到 Sprite 193，结束时再恢复普通 Sprite 2。`PalTileMapWorld` 和 CPU 对照路径却另外按角色编号缓存已经解析的 Sprite；`0065` 正常换装会发信号清缓存，但读档直接恢复整组 `scene_sprite_numbers`，不会经过该信号。如果读档前缓存的是 Sprite 193，即使存档状态已经恢复 Sprite 2，后续移动仍会用 193 的特殊动作帧组成错误步态。
- **涉及文件**:
  - `src/content/pal_content_database.gd`
  - `src/world/pal_tilemap_world.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `docs/SCENE_RENDERING.md`
  - `docs/SAVE_SYSTEM.md`
- **修复内容**: 移除两个渲染器按角色编号保存的二级 Sprite 缓存，统一通过 `PalContentDatabase.load_player_scene_sprite()` 读取 PLAYERROLES 当前编号，继续复用数据库按实际 MGO 编号维护的安全缓存。合成回归模拟不发 `0065` 信号的读档式 `193 → 2` 直接恢复，并同时检查 TileMap 与 CPU 路径；真实求药回归确认脚本 `6072–6224` 最终恢复 Sprite 2，第一次移动清除剧情站立帧后使用 12 帧普通步态 Sprite。
- **状态**: ✅ 已修复

---

### [BF-031] 码头剧情检查点继续游玩导致夜间李大娘重现且楼梯关闭

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 剧情检查点、求药归来夜间客栈与存档兼容
- **问题描述**: “码头乘船”人工检查点从全新内容数据库启动，只覆盖张四、船只和码头入口，遗漏开场脚本 `7952–8144` 已经完成的客栈状态。玩家从该检查点继续主线并保存后，喂药夜晚仍保留 EventObject 12 的李大娘叫醒专用 Sprite 628；负责离场的 EventObject 11 也停在初始位置/自动入口 `4455`，EventObject 4 楼梯状态为 0。地图块本身阻挡队伍，而隐藏的接触事件不会执行 `4475`，因此画面同时出现不应存在的李大娘并提示前方被阻挡。
- **涉及文件**:
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_intro_test.gd`
  - `docs/DEVELOPMENT_WORKFLOW.md`
  - `docs/SCRIPT_VM.md`
  - `docs/SAVE_SYSTEM.md`
- **修复内容**: 码头检查点现在同时恢复 Scene 1 的开场稳定入口 8145、开启 EventObject 4，并把 EventObject 11 推进到 `(1152,384)` / 自动入口 4458、隐藏 EventObject 12。为已经生成的存档增加精确兼容修复：仅当 Scene 1 已到喂药稳定入口 6225 且 4/11/12 仍完全匹配旧检查点矛盾组合时，在读档内存中恢复上述状态并显示提示；正常主线不会命中。合成回归覆盖检查点定义、识别和幂等性，真实开场回归固定三个对象，实际读取用户槽位 007 后确认李大娘消失、楼梯接触脚本 4475 被触发并请求进入场景 3。
- **状态**: ✅ 已修复

---

### [BF-032] 酒剑仙御剑术 RNG 动画被渐隐遮罩全程覆盖

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 山神庙御剑教学、RNG 播放与屏幕渐变
- **问题描述**: 山神庙脚本 `6622` 在 RNG #1 前执行 `0050` 渐隐。Godot 已成功载入并推进 RNG 帧，但 `ScreenFade` 位于 HUD 最上层，渐隐结束后仍保持 alpha 1.0；RNG 播放入口没有像官方 `PAL_RNGPlay()` 那样在第一帧消费 `fNeedToFadeIn`，所以整段御剑术画面被黑层覆盖。原有测试只检查 `0036/0037` 请求编号和播放完成，未读取实际像素，因而出现假通过。
- **涉及文件**:
  - `src/ui/pal_rng_player.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_local_rng_player_test.gd`
  - `docs/SCRIPT_VM.md`
  - `docs/DEVELOPMENT_WORKFLOW.md`
  - `docs/ARCHITECTURE.md`
- **修复内容**: RNG 成功显示第 0 帧后若存在前置 `0050`，先暂停播放器帧计时并把顶层遮罩从黑色渐显到透明；渐显完成再从首帧按脚本帧率继续播放。Headless 回归验证暂停、遮罩和恢复时序，带窗口 OpenGL 回归执行真实脚本 `6622` 并检查 320×200 像素：修复前遮罩 alpha 1.0、非黑像素 0，修复后遮罩隐藏、非黑像素 51,931，截图只写入被忽略的 `generated/pal/visual_tests/training_rng_001.png`。
- **状态**: ✅ 已修复

## 2026-07-16

### [BF-009] 收起桂花酒后李逍遥消失直到再次移动

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 端酒菜剧情与人物动作
- **问题描述**: 端酒菜脚本先用特殊 Sprite 的第 15 帧表现李逍遥收酒动作，再通过操作码 `0065` 切回普通场景 Sprite。Godot 会话仍保留旧造型的绝对动作帧，而普通 Sprite 没有该帧，导致人物暂时不绘制；正常移动清除动作帧后才重新出现。
- **涉及文件**:
  - `src/game/game_session.gd`
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_meal_and_wine_test.gd`
- **修复内容**: 操作码 `0065` 切换角色场景 Sprite 时，只清除该角色在当前队伍中的旧脚本动作帧；若后续 `0015` 需要新造型动作，会在同一脚本中重新设置。新增合成操作码回归与真实端酒菜回归，确保收酒后立即恢复普通造型，不依赖后续移动刷新。
- **状态**: ✅ 已修复

---

### [BF-012] 乘船剧情停在触发脚本操作码 000E

- **来源**: 用户试玩反馈
- **关联需求**: M3 余杭至仙灵岛主线流程
- **问题描述**: `ScriptVM` 已在自动脚本兼容层实现 `000B–000E` 四方向单步，却没有在主触发脚本解释循环实现同组指令。乘船脚本执行到 `0x170C: 000E` 时被当作未移植指令，船只无法完成八步移动和新旧船体切换。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 主触发脚本按官方 `script.c` 为当前 EventObject 设置南/西/北/东方向，以速度 2 调用统一 NPC 单步和步态推进；保留脚本间隔 `0005` 的逐步重绘。真实脚本 `0x170C` 回归确认 EventObject 117 完成四步向东、四步向南，净移动 `(0,16)`，随后隐藏旧船并启用 EventObject 118。
- **状态**: ✅ 已修复

---

### [BF-013] 张四离开后李逍遥与船停在余杭码头

- **来源**: 用户试玩反馈
- **关联需求**: M3 余杭至仙灵岛主线流程
- **问题描述**: 张四的登船步行和船夫自动移动已经执行，但 `ScriptVM` 尚未实现脚本 `0x172C` 使用的操作码 `003F`。该操作码负责让队伍乘坐当前 EventObject 同步驶向目标，因此李逍遥和船停在原地，后续落点设置、场景切换及仙灵岛进入脚本均被中断。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 对齐官方 `PAL_PartyRideEventObject`，实现 `003F`、`0044`、`0097` 三档乘坐速度；每个脚本帧同步更新队伍视口、轨迹与当前船只位置，并保留登船固定动作。真实资源回归从张四登船继续执行到李逍遥乘船驶离，确认 `0059` 切换至仙灵岛、进入消息完整、BGM 70、战斗 BGM 37、落点 `(752, 808)` 及稳定入口 `0x2544`。
- **状态**: ✅ 已修复

---

### [BF-014] 余杭乘船后直接闪现到仙灵岛

- **来源**: 用户试玩反馈
- **关联需求**: M3 余杭至仙灵岛主线流程
- **问题描述**: 余杭驶离动画完成后，操作码 `0050` 仍只是重绘占位，没有执行官方约 0.6 秒的调色板渐隐，也没有保留下一次场景重绘时自动渐显的状态。因此较长的离港移动结束后会直接闪到仙灵岛，缺少原版清晰的离港与靠岸视觉边界。
- **涉及文件**:
  - `src/game/script_vm.gd`
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_early_mainline_test.gd`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 实现阻塞式 `0050/0051` 渐隐渐显等待状态，在独立 HUD 顶层加入覆盖地图、人物与界面的黑色转场层；渐变期间暂停 VM 与玩家输入，渐隐完成后继续设置目的地并切场景，仙灵岛进入脚本首次 `0005` 重绘时自动渐显。对照官方数据确认目的地没有第二条乘船位移指令，靠岸段由渐显、停靠船只和“总算靠岸了”对话组成；真实资源回归固定余杭渐隐请求及后续仙灵岛状态。
- **状态**: ✅ 已修复

## 2026-07-15

### [BF-002] Esc 键直接退出探索场景

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 探索与基础菜单
- **问题描述**: 基础菜单上线后仍保留了旧测试场景的 Esc 返回行为，玩家按常规习惯尝试打开菜单时会直接退出探索场景。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `README.md`
- **修复内容**: 将 Esc、M、Tab 统一映射为打开菜单，菜单内 Esc 负责返回或关闭；将退出探索并返回资源实验室改为 F10，并增加键位常量回归测试和界面提示。
- **状态**: ✅ 已修复

---

### [BF-003] 厨房入口错误重播开场剧情

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 场景流程
- **问题描述**: 客栈厨房入口按原版数据切换到场景 1 的厨房区域，但场景进入脚本执行后的返回入口没有写回场景定义，导致再次进入场景 1 时从 `7952` 重播完整开场，看起来像被传送回第一个场景。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `src/debug/pal_debug_checkpoint.gd`
  - `src/debug/story_test_lab.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_intro_test.gd`
  - `tests/run_local_scene_transition_test.gd`
  - `README.md`
  - `docs/SCRIPT_VM.md`
- **修复内容**: 对齐 SDLPal `play.c`，将场景进入脚本返回的新入口持久化到当前场景；完成开场后场景 1 从稳定入口 `8145` 恢复，厨房入口仍执行原版脚本 `4631` 并落到 `(1248, 1104)`，不再重播开场。剧情测试界面移除已验收的非桂花酒人工检查点，只保留桂花酒流程和当前厨房入口，旧行为继续由自动回归覆盖。
- **状态**: ✅ 已修复

---

### [BF-007] TileMap 相机把对话框和菜单移出屏幕

- **来源**: 用户试玩反馈
- **关联需求**: M2–M3 探索、对话与菜单
- **问题描述**: 默认地图迁移到 `TileMapLayer + Camera2D` 后，顶部状态栏、对话框和菜单仍与地图共用默认世界画布。相机定位到 PAL 世界坐标时会同时变换这些屏幕 UI，导致开场剧情实际执行但对话框完全移出 320×200 视口。
- **涉及文件**:
  - `src/world/map_explorer.gd`
  - `tests/run_tests.gd`
  - `docs/ARCHITECTURE.md`
- **修复内容**: 新增前景 `HudLayer: CanvasLayer`，将状态栏、对话框、Toast 和经典菜单统一挂到该层，地图与人物继续留在 Camera2D 世界画布；增加节点归属回归，防止后续 HUD 再次被相机变换。
- **状态**: ✅ 已修复
