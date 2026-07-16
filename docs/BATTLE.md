# 经典战斗系统

Godot 版以固定 SDLPal 的经典回合制路径为行为基准，不启用 `ENABLE_REVISIED_BATTLE` 蓄力模式。当前第一阶段已经接通静态战斗数据、战场背景、双方 Sprite 和官方站位；指令选择、行动队列和胜负结算仍在开发。

## 原版资源映射

| 内容 | 原版来源 | Godot 生成位置 |
| --- | --- | --- |
| 敌人属性 | `DATA.MKF #1` | 保留为 `content/data/01.bin`，由 `PalEnemyDefinition` 解析 |
| 敌队五槽编组 | `DATA.MKF #2` | 保留为 `content/data/02.bin`，由 `PalEnemyTeam` 解析 |
| 角色属性和战斗 Sprite 编号 | `DATA.MKF #3` | 保留为 `content/data/03.bin`，由 `PalPlayerRoles` 解析 |
| 战场波动和五灵修正 | `DATA.MKF #5` | 保留为 `content/data/05.bin`，由 `PalBattlefield` 解析 |
| 五种敌人数站位 | `DATA.MKF #13` | 保留为 `content/data/13.bin`，由敌人位置矩阵解析 |
| 敌人对象到属性索引 | `SSS.MKF #2` | `content/core/objects_dos.bin` |
| 敌人战斗 Sprite | `ABC.MKF` | `content/battle/sprites/enemies/*.spr` |
| 玩家战斗 Sprite | `F.MKF` | `content/battle/sprites/players/*.spr` |
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

- 左/右方向键切换非空敌队；
- 上/下方向键切换战场背景；
- Esc 返回资源实验室。

这个入口只验证原版背景、Sprite、人数和站位，不伪造回合结果。下一阶段会在同一资源层上加入 `BattleController`、经典指令 UI、身法行动队列、伤害与敌人 AI。

## 测试

合成结构测试不依赖原版资源：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_tests.gd
```

本地资源完整性与首战截图：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_battle_content_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_battle_preview_test.gd
```

截图只写入 `generated/pal/visual_tests/`。当前真实资源验收覆盖 154 条敌人属性、380 个敌队、65 个战场定义、43 个脚本引用战场、六名角色战斗 Sprite，以及敌队 18 / 战场 21 的 320×200 画面。
