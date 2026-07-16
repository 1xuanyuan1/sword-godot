# 经典战斗系统

Godot 版以固定 SDLPal 的经典回合制路径为行为基准，不启用 `ENABLE_REVISIED_BATTLE` 蓄力模式。静态资源、普攻回合、首批玩家仙术和 `ScriptVM 004A/0007` 剧情桥接已经接通；敌人法术、物品、毒与状态及奖励结算仍在开发。

## 原版资源映射

| 内容 | 原版来源 | Godot 生成位置 |
| --- | --- | --- |
| 敌人属性 | `DATA.MKF #1` | 保留为 `content/data/01.bin`，由 `PalEnemyDefinition` 解析 |
| 敌队五槽编组 | `DATA.MKF #2` | 保留为 `content/data/02.bin`，由 `PalEnemyTeam` 解析 |
| 角色属性和战斗 Sprite 编号 | `DATA.MKF #3` | 保留为 `content/data/03.bin`，由 `PalPlayerRoles` 解析 |
| 仙术特效、类型、MP 和基础伤害 | `DATA.MKF #4` | 保留为 `content/data/04.bin`，由 `PalMagicDefinition` 解析 |
| 战场波动和五灵修正 | `DATA.MKF #5` | 保留为 `content/data/05.bin`，由 `PalBattlefield` 解析 |
| 状态框、四向图标和数字 | `DATA.MKF #9` | 由 `PalBattleUI` 运行时解码 |
| 五种敌人数站位 | `DATA.MKF #13` | 保留为 `content/data/13.bin`，由敌人位置矩阵解析 |
| 敌人对象到属性索引 | `SSS.MKF #2` | `content/core/objects_dos.bin` |
| 仙术对象到属性与脚本 | `SSS.MKF #2` | `PalMagicObjectDefinition` 按同一 OBJECT 项解释 |
| 敌人战斗 Sprite | `ABC.MKF` | `content/battle/sprites/enemies/*.spr` |
| 玩家战斗 Sprite | `F.MKF` | `content/battle/sprites/players/*.spr` |
| 仙术逐帧特效 | `FIRE.MKF` | `content/battle/sprites/magic/*.spr` |
| 320×200 战场背景 | `FBP.MKF` | `content/battle/backgrounds/*.idx` |

以上生成路径都位于被 Git 忽略的 `generated/pal/`，不会随源码提交。

## 敌队解析链路

脚本 `0007` 的第一个操作数是敌队编号，不是敌人编号。运行时按以下顺序解析：

```text
敌队编号
  → PalEnemyTeam.object_ids
  → PalEnemyObjectDefinition.enemy_id
  → PalEnemyDefinition + ABC.MKF Sprite
```

`0xFFFF` 和零槽位不生成敌人。有效对象按原顺序压紧，再用 `DATA.MKF #13` 的 `position[enemy_index][enemy_count - 1]` 取得脚底坐标；敌人属性中的 `y_position_offset` 最后叠加。玩家使用 `battle.c` 的一人、二人、三人固定站位表。

操作码 `004A` 只设置战场编号，真正启动战斗的是 `0007`。当前前期强制战斗数据为：

```text
6964: 004A [21, 0, 0]       # 战场 21
6965: 0007 [18, 40091, 0]  # 敌队 18，战败跳转 40091，不允许逃跑
```

## 当前战斗样板

资源实验室中的“战斗样板”默认加载敌队 18、战场 21 和李逍遥/赵灵儿：

- 主行动按官方菱形排列：上攻击、左仙术、右合击、下其他；
- 选择攻击后，方向键切换仍存活的敌人，空格或回车确认；只剩一个敌人时直接确认；
- 选择仙术后显示角色已学会的真实仙术和“消耗 MP / 当前 MP”；单体治疗会选择我方角色，单体攻击会选择敌人；
- `D` 为当前队员提交防御；
- `[` / `]` 切换非空敌队，`PageUp` / `PageDown` 切换战场背景；
- Esc 返回资源实验室。

样板使用新的临时 `GameSession`，不会污染探索进度，并为测试补满两名队员 HP/MP，使赵灵儿的五灵咒可以直接验证；剧情战斗仍使用正式会话中的真实数值。它已使用 `PalBattleController` 真实执行攻击、防御、仙术、敌人物理攻击、自动防御、体力扣减、死亡和胜负，不伪造结果。`PalBattleUI` 按 `uibattle.c` 固定坐标绘制角色状态框、头像、HP/MP 数字、当前角色箭头和四向图标，并固定在所有按脚底 Y 排序的战斗人物之上；仙术窗口等大面板不会被人物反向盖住。选敌时直接让敌人 Sprite 按调色板索引低四位 `+7` 闪烁，不显示自制目标 HP 或编号。

玩家物理攻击按 `fight.c::PAL_BattleShowPlayerAttackAnim()` 使用 F.MKF 的备战帧 7、接近帧 8 和攻击帧 9，再让敌人受击变色、显示蓝色上浮伤害并回到原战位。敌人物理攻击同样读取敌人属性中的待机、施法和攻击帧数，接近目标后显示格挡或受击帧、伤害数字和归位过程。

玩家仙术先按 `PAL_BattleShowPlayerPreMagicAnim()` 左上蓄势并切换施法帧，再按 DATA.MKF 中的速度、重复、偏移和图层字段播放 FIRE.MKF Sprite，并在生效帧播放仙术 VOC。当前已支持：

- 气疗术、观音咒等由 `001B/001C/001D` 成功脚本直接增减 HP/MP 的单体或全体恢复仙术；普通治疗不会复活倒地角色；
- 风、雷、冰、火、土等基础攻击仙术，使用 `PAL_CalcMagicDamage()` 的灵力随机修正、敌人防御、五灵/毒抗和战场五灵修正；
- 黄、青、蓝数字分别显示 HP 恢复、MP 恢复和伤害，结果继续写回同一 `GameSession`。

净衣咒、金刚咒、回梦等依赖毒、异常状态或持续回合脚本的仙术在列表中保留但显示为不可用；在对应状态系统实现前不会只播放动画而漏掉效果。

## 当前回合逻辑

`PalBattleController` 不依赖任何 Godot 场景节点。它持有敌人本场体力、玩家指令、防御状态和行动队列；玩家当前 HP/MP 继续由 `GameSession` 持有。`ActionResult` 携带仙术对象、目标、MP 消耗、伤害和恢复量，`PalBattlePreview` 据此播放 Sprite、受击变色和数字，不重复计算数值。

全队完成指令后，敌人与玩家统一进入行动队列：

- 敌人身法为 `(等级 + 6) × 3 + signed(基础身法)`；
- 双动敌人加入两次，身法较低的一项标记为第二动；
- 防御指令将玩家身法乘 5；
- 濒死角色身法减半；
- 每项最终乘 `0.9–1.1`，再按身法从高到低执行。

基础伤害忠于 `fight.c::PAL_CalcBaseDamage()`：

```text
攻击 > 防御       → 攻击 × 2 - 防御 × 1.6
攻击 > 防御 × 0.6 → 攻击 - 防御 × 0.6
否则              → 0
```

物理伤害再除以目标物理抗性。玩家单体普攻会加入 `1–2` 浮动、经典暴击和李逍遥额外一击判定；敌人物理攻击加入等级攻击、随机修正和 7/17 自动防御判定。最终有效普攻至少造成 1 点伤害。

攻击仙术先把角色灵力乘 `RandomFloat(10, 11) / 10`，用同一基础伤害公式减去敌人防御后除以 4，再加仙术基础伤害；随后依次应用目标五灵/毒抗和当前战场的五灵修正，最低造成 1 点伤害。

固定随机种子使用移植自 `util.c` 的 32 位 LCG。这样测试可以精确复现行动顺序和伤害，同时正式运行仍会使用当前时间生成种子。

## 剧情战斗桥接

`004A` 把战场编号写入 `GameSession.battlefield_number`。执行 `0007` 时，VM 保存战败和逃跑分支，进入 `waiting_for_battle` 并向 `MapExplorer` 请求敌队、战场和 Boss 标志。探索输入、菜单、接触事件和 10 FPS 自动脚本在等待期间全部暂停。

`MapExplorer` 在同一个 HUD CanvasLayer 上覆盖剧情模式的 `PalBattlePreview`，直接复用探索的内容数据库与 `GameSession`，因此战斗扣除的 HP 不会在返回地图后丢失。进入时切换 `0045` 指定的战斗 BGM，确认胜负后恢复场景 BGM，再按以下规则调用 `complete_battle()`：

- 胜利继续 `0007` 的下一条指令；
- 战败且 `operand[1]` 非零时跳到该入口；
- 逃跑且 `operand[2]` 非零时跳到该入口；
- `operand[2] == 0` 同时表示 Boss 战、不允许逃跑。

当前 UI 尚无逃跑指令，但 VM 分支已按官方语义实现。若战斗资源缺失，探索层会显示具体原因并延后按战败分支恢复，避免在信号回调中重入脚本解释循环。

## 尚未完成

- 敌人法术、召唤、合击、使用/投掷物品、逃跑和自动战斗；
- 中毒、异常状态、装备加成、保护与替队员承伤；
- 经验、金钱、升级、掉落和战后脚本；
- 状态类仙术、完整死亡与逃跑动画，以及普攻动作音效；
- 逃跑、自动战斗和战斗中脚本事件的完整执行。

敌人本轮抽中法术时，控制器会明确返回“尚未接入”的动作，不会静默改成物理攻击。默认敌队 18 不触发该边界，已经可以完整验证当前普攻闭环。

## 测试

合成结构测试不依赖原版资源：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_tests.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_battle_logic_tests.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_battle_bridge_tests.gd
```

本地资源完整性与首战截图：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_content_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_logic_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_bridge_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_battle_preview_test.gd
```

截图只写入 `generated/pal/visual_tests/`。当前真实资源验收覆盖 154 条敌人属性、380 个敌队、65 个战场定义、43 个脚本引用战场、六名角色战斗 Sprite、55 组 FIRE 仙术 Sprite，以及敌队 18 / 战场 21 的气疗术、风咒、普攻画面和自动普攻到胜负。
