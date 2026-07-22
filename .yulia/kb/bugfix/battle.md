---
name: '经典战斗 Bug 修复记录'
summary: '记录经典战斗数值、行动、动画和结算问题及修复'
keywords:
  - battle
  - 战斗
  - 伤害
  - 数值
---

# 经典战斗 Bug 修复记录

## 修复记录

## 2026-07-22

### [BF-044] R 重复指令未在执行前再次更换已死目标

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典战斗行动队列
- **问题描述**: 按 R 时会根据上回合指令选出一个存活敌人，但同一行动队列中更高身法的队员可能又先击倒这个替换目标。后续队员执行普攻时只在局部伤害计算中找到了下一个敌人，没有把实际目标写回指令和 `ActionResult`；单体攻击仙术、合击与投掷物也缺少统一的执行前目标校验，可导致动作或特效仍指向已死敌人。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_repeat_retarget_test.gd`
  - `.yulia/kb/bugfix/battle.md`
- **修复内容**: 对齐 SDLPal 在 `PAL_BattlePlayerPerformAction()` 开始时调用 `PAL_BattlePlayerValidateAction()` 的时机，为玩家普攻、单体对敌仙术、合击和投掷物增加共用的执行前目标重选，并将最终敌人索引写回玩家指令与动作结果。合成回归覆盖“旧目标已死 → R 选出替换目标 → 队列前一人再击杀 → 后一人二次换目标”；真实 OpenGL 战斗回归隐藏旧敌人后通过 R 发起攻击，检查实际目标、受击数字和像素截图。
- **状态**: ✅ 已修复

---

## 2026-07-20

### [BF-033] 战后奖励金钱数值压住前方文字

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典战斗结算
- **问题描述**: 战后奖励总览把金钱数值按五位右对齐从 `x=132` 绘制，首战的“96”因此落在 `x=150–156`，与前方“打败敌人得”的最后一个字重叠，同时距离后方“文钱”过远。固定 SDLPal 基准实际使用 `PAL_XY(162, 119)` 和 `kNumAlignMid`。
- **涉及文件**:
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_battle_preview_test.gd`
- **修复内容**: 为原版数字 Sprite 绘制补齐左／中／右三种 `PAL_DrawNumber` 对齐算法，奖励金钱恢复为 `(162, 119)` 中间对齐，使两位数“96”准确落在 `x=171–177`。合成测试固定该坐标范围；带窗口 OpenGL 回归等待 SubViewport 实际完成重绘后重新生成并检查奖励截图。
- **状态**: ✅ 已修复

---

### [BF-034] 蜜蜂施加的普通毒在战斗结束后仍持续存在

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典毒与战斗清理
- **问题描述**: 蜜蜂对象 403 的普攻通过附带物品 117 执行 `0029`，给玩家施加 551 号 0 级赤毒。当前统一战斗清理错误地把全部中毒都视为跨战斗状态，只清除临时异常，遗漏 SDLPal `battle.c` 在任意战斗结果后对全部角色执行的 `PAL_CurePoisonByLevel(role, 3)`，导致赤毒在胜利或逃跑后仍继续保留。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `docs/BATTLE.md`
  - `docs/ARCHITECTURE.md`
- **修复内容**: 统一战斗清理恢复原版分级规则，为全部六名角色移除三级及以下毒，同时保留四级特殊附着和 99 级装备效果。合成回归覆盖胜利、失败、逃跑、非当前队员及高级毒保留；真实资源回归固定 `蜜蜂 403 → 物品 117 → 0029 → 赤毒 551` 链路，并验证战后清除 551、保留四级 561 附着。
- **状态**: ✅ 已修复

---

### [BF-036] 胖苗弦月斩结束后没有保留战场破坏

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典战斗仙术演出
- **问题描述**: 胖苗对象 485 使用弦月斩 338，其 DATA.MKF 仙术记录明确设置 `keep_effect = FFFF`；SDLPal 会把 FIRE 特效最后一帧写入本场战斗背景，但 Godot 版播放结束后统一删除了全部仙术节点，导致地形破坏立即消失。字段虽已解析，却没有接入画面生命周期。
- **涉及文件**:
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
- **修复内容**: 在战场背景与人物之间增加单场持久特效层，玩家和敌人仙术共用 `keep_effect` 末帧保留逻辑，并对齐原版 `screen_wave < 9` 条件；持久层跨后续回合保留、开始下一场战斗时清空。真实敌队 19 的胖苗弦月斩通过 OpenGL 截图、节点生命周期及实际像素变化检查。
- **状态**: ✅ 已修复

---

### [BF-038] 赵灵儿双剑二连击共用一次动作音效且伤害数字重叠

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典玩家物理攻击演出
- **问题描述**: 装备仙女剑的赵灵儿已由控制器正确结算两段普攻伤害，但 `ActionResult.hits` 没有保留两击的轮次；表现层因而只播放一次接近和挥剑动作、一次角色攻击声与一次武器命中声，再在同一毫秒、同一坐标同时创建两个伤害数字，造成动作／声音像单击且两段数值完全叠住。原版 `fight.c` 会为双击状态逐次调用 `PAL_BattleShowPlayerAttackAnim()`，每一击分别播放动作、声音和伤害上浮。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
- **修复内容**: 为物理命中结果增加攻击轮次，单体与全体双击都按 0/1 分组；表现层只在第一击前播放备战帧，但每一击分别重播接近／攻击帧、角色声、武器声、敌人受击和对应伤害数字。两段数字按原版特效与受击节奏间隔约 9 帧，第一段已向上浮动后才出现第二段。合成测试固定双击轮次，真实赵灵儿／仙女剑回归确认两击、四次音效调用、数字时间差和归位，并生成 OpenGL 截图。
- **状态**: ✅ 已修复

---

### [BF-039] 战斗脚本对白无法用空格立即显示整句

- **来源**: 用户试玩反馈
- **关联需求**: M4 敌人战斗脚本对白
- **问题描述**: 战斗脚本的 `DIALOG_MESSAGE` 只按消息长度等待固定时间；与此同时战斗动画状态会屏蔽普通确认指令，导致对白逐字出现时按空格或回车完全无效，只能等待整句按固定节奏显示并自动继续。
- **涉及文件**:
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
- **修复内容**: 将固定对白计时改为可响应输入的逐帧等待；逐字期间第一次空格或回车只调用既有 `PalDialogBox.reveal_all()` 补完整句，完整显示后第二次确认才提前继续，未输入时仍保留原最短等待和逐字结束后的阅读时间。对白等待优先吞掉其他战斗按键，避免方向、重复指令或退出误触发；合成输入回归和敌队 22 的真实 OpenGL 战斗对白均已验证。
- **状态**: ✅ 已修复

---

### [BF-040] 飞龙探云手误报仙术特效资源缺失

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典玩家仙术演出
- **问题描述**: 飞龙探云手对象 377 映射的仙术记录 98 将 `effect_sprite` 设为 `FFFF`，这是原版“没有 FIRE.MKF Sprite、改由成功脚本播放专用动作”的明确哨兵。当前表现层却把它当作需要加载的 Sprite 编号，失败后显示“仙术特效资源缺失”；同时 `006A` 只结算偷取物品和显示文字，没有携带目标或播放李逍遥掠过敌人的专用偷窃动作。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `src/battle/pal_battle_preview.gd`
  - `tests/run_script_opcode_behavior_tests.gd`
  - `tests/run_local_battle_content_test.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
- **修复内容**: 将 `FFFF` 识别为有意省略 FIRE 特效，不再误报资源缺失；`006A` 无论偷窃成功与否都生成包含目标敌人的专用事件。表现层按 `fight.c::PAL_BattleStealFromEnemy()` 使用李逍遥战斗 Sprite 第 10 帧，从敌人右下方连续向左上掠过、末段令敌人闪白并归位，同时按原顺序播放施法声、脚本声和成功提示。合成回归固定成功／无物品两条事件路径，真实资源固定 `377 → 98 → FFFF → 0047 → 006A`，OpenGL 回归检查专用动作像素、归位和全程无资源错误。
- **状态**: ✅ 已修复

---

### [BF-043] 战斗仙术列表顶栏缺少技能说明

- **来源**: 用户试玩反馈
- **关联需求**: M4 经典战斗 UI
- **问题描述**: 场外仙术页会读取 `DESC.DAT`，在顶栏显示所需／当前 MP 和选中仙术说明；战斗仙术页却始终固定绘制金钱与 MP 双窗，没有读取同一份说明资源，导致列表上方中央区域整块空白。雷咒等攻击仙术虽然已有“属性、级别与目标”说明，战斗中仍不可见。
- **涉及文件**:
  - `src/battle/pal_battle_ui.gd`
  - `tests/run_local_battle_preview_test.gd`
  - `docs/BATTLE.md`
  - `.yulia/kb/bugfix/battle.md`
- **修复内容**: 战斗仙术页复用场外仙术顶栏布局：存在说明时左侧显示所需／当前 MP，右侧从 `(102, 3)` 开始按 `*` 分行绘制 `DESC.DAT` 内容；说明缺失时保留原金钱与 MP 回退。真实资源回归断言选中仙术说明已接入，并在 Godot 4.7 OpenGL 窗口中生成和检查 `battle_magic_menu.png`，确认说明、MP 与仙术列表没有重叠。
- **状态**: ✅ 已修复

---

## 2026-07-17

### [BF-017] 战斗界面切换场景后输入处理访问空 Viewport

- **来源**: 用户试玩反馈
- **关联需求**: M3–M4 仙灵岛战斗与调试场景
- **问题描述**: 战斗预览的按键回调会先执行取消、确认或场景切换，再通过 `get_viewport()` 标记输入已处理。若该动作使战斗节点在同一回调中离开 SceneTree，后取 Viewport 会得到空值并反复报错 `Cannot call method 'set_input_as_handled' on a null value`。
- **涉及文件**:
  - `src/battle/pal_battle_preview.gd`
- **修复内容**: 在执行可能切换场景的按键动作前保存有效 Viewport，动作完成后仅通过该有效引用标记输入；节点已经脱离场景树时不再调用空值。非 Headless 战斗预览回归继续通过。
- **状态**: ✅ 已修复

## 2026-07-16

### [BF-015] 李逍遥攻击绿叶小妖只能造成 1 点伤害

- **来源**: 用户试玩反馈
- **关联需求**: M3–M4 经典战斗数值
- **问题描述**: 仙灵岛敌队 16 的绿叶小妖基础防御原始值为 `0xFFFA`。SDLPal 在 16 位 `WORD` 中加上等级防御修正，结果会回绕为 `18`；Godot 版直接使用宽整数相加，误得到 `65554`，使李逍遥空装普攻和同类玩家攻击路径始终退化为最低 1 点。
- **涉及文件**:
  - `src/battle/pal_battle_controller.gd`
  - `tests/run_battle_logic_tests.gd`
  - `tests/run_local_battle_logic_test.gd`
  - `docs/BATTLE.md`
- **修复内容**: 统一玩家单体普攻、全体普攻和攻击仙术的敌方有效防御计算，保留官方 16 位 `WORD` 加法回绕语义。合成测试固定 `0xFFFA + 24 == 18`，真实资源回归固定敌队 16、对象 499 和绿叶小妖防御原值，并确认李逍遥空装普攻不再退化为 1 点。
- **状态**: ✅ 已修复
