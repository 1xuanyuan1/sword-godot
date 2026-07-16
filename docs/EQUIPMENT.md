# 装备系统

Godot 版装备系统以固定 SDLPal 镜像的 `global.h::PLAYERROLES`、`global.c::PAL_UpdateEquipments()`、`script.c` 装备操作码和 `uigame.c::PAL_EquipItemMenu()` 为行为基准。原版装备名称、图标、背景和脚本仍来自用户本机合法导入的资源，不进入 Git。

## 数据与状态边界

`DATA.MKF #3` 的 `PLAYERROLES` 在 word offset 66 保存六个装备部位，每个部位连续保存六名角色的对象编号。`PalPlayerRoles` 只解析这份新游戏初始值；开始游戏后，当前装备、背包交换和脚本效果都由 `GameSession` 持有，不改写静态内容数据库。

当前六槽在装备页中的显示顺序为：头戴、披挂、身穿、手持、脚穿、佩带。当前数据中李逍遥的新游戏装备为：

| 部位 | 对象 | 名称 |
| --- | ---: | --- |
| 头戴 | 196 | 头巾 |
| 披挂 | 225 | 披风 |
| 身穿 | 208 | 布袍 |
| 手持 | 166 | 木剑 |
| 脚穿 | 235 | 草鞋 |
| 佩带 | 249 | 护腕 |

这些装备不是背包里的展示物品。`PalEquipmentManager.configure()` 会在新游戏或战斗开始前重新执行其装备脚本，把效果写入 `GameSession.equipment_effects_by_slot`。因此李逍遥当前真实初始属性为攻击 35、灵力 20、防御 41、身法 31、逃跑 32；不能再用未计装备的裸属性计算战斗。

## 装备脚本

装备不是一张硬编码的“物品 → 加成”表。每件物品的 `script_on_equip` 指向 SSS 脚本，当前装备层实现：

| 操作码 | 装备语义 |
| --- | --- |
| `0017` | 向指定装备槽写入某个 `PLAYERROLES` 属性组的 16 位效果 |
| `0018` | 把物品装进 `operand[0] - 0x0B` 部位，交换背包中的新旧物品 |
| `001A` | 装备过程中写战斗 Sprite、攻击全体、合体仙术等字段 |
| `0023` | 卸下某角色一个部位或全部六槽，并把物品放回背包 |
| `002D` | 保存装备维持的角色状态；当前已识别双击状态 |

攻击、灵力、防御、身法、逃跑、毒抗和五灵抗性读取基础值后逐槽叠加。加成保持 SDLPal 的 16 位 `WORD` 回绕语义，负数效果按二补码保存。战斗 Sprite 覆盖与攻击全体效果也由装备槽决定。

少量后期饰品的脚本还会用 99 级毒等方式表达特殊免疫。装备双击已经进入经典战斗行动次数，并由独立装备状态槽避免被普通回合递减或解咒清除；装备效果组 65 也会覆盖角色基础合击仙术。未接入的 99 级装备毒和其他特殊操作码仍会输出明确诊断，不会被伪造成普通数值。

## 换装流程与界面

主菜单选择“物品 → 装备”后，只列出背包中带 `kItemFlagEquipable` 的物品。选择物品进入原版 `FBP.MKF #1` 装备页：

- 左上显示 BALL 物品图标、名称和数量；
- 中部显示当前角色六件装备；
- 右侧显示已计装备的武术、灵力、防御、身法和吉运；
- 左下按队伍顺序选择角色；不能装备该物品的角色使用原版不可用颜色。

确认后，`PalGameMenu` 只发出请求，`MapExplorer` 交给 `PalEquipmentManager` 执行脚本。新装备从背包减一，旧装备回到背包；若换下了物品，装备页会继续以旧物品作为待装备对象，复现 SDLPal 的 `wLastUnequippedItem` 行为。

## 测试

不依赖原版资源的六槽、脚本与背包交换测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_equipment_tests.gd
```

本地真实资源菜单测试会校验李逍遥六件初始装备，并生成被 Git 忽略的 `classic_equipment.png`：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility \
  --script res://tests/run_local_menu_visual_test.gd
```
