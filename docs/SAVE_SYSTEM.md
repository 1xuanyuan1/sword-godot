# Godot 版本化存档系统

本项目使用独立的 Godot JSON 存档，不读写原版 `.rpg` 文件。存档只保存玩家依法导入的数据所产生的运行状态，不包含原版地图、文字、图片或音频资源。

## 槽位与操作

- 系统菜单提供 100 个独立槽位，每页显示 5 个。
- 资源实验室启动页提供“读取存档”，直接打开同一套 100 槽界面；确认后进入对应探索场景，Esc 直接返回实验室。
- 上／下键按 1–100 连续切换槽位，经过每页第 5 槽时自动翻页；左／右键每次翻 5 个槽位并保留当前行，空格或回车确认，Esc 返回。
- 槽位摘要显示中文地点名、保存时间、队伍头像、姓名和等级；右侧小数字是该槽累计保存次数。
- 保存和读取只允许在探索地图的空闲状态执行，不保存半句对话、战斗中间帧、渐变或菜单内部选择。

存档位于 `user://saves/slot_001.json` 至 `slot_100.json`。在 macOS 默认对应 `~/Library/Application Support/Godot/app_userdata/Sword Godot Study Port/saves/`；实际路径以 Godot 的 `user://` 为准。

## 保存范围

`PalSaveManager` 保存并恢复以下状态：

- 当前场景、队伍位置、方向、五格轨迹和角色场景形象；
- 队伍成员、等级、经验、HP/MP、成长属性、仙术、毒和九种状态；
- 背包、六槽装备、金钱、日夜调色板、BGM 编号及音乐／音效音量；
- 全部 294 个 Scene、5332 个 EventObject、物品／仙术／敌人脚本游标。

装备属性属于当前装备和静态脚本的派生结果，不直接信任存档中的缓存；读档后由 `PalEquipmentManager` 重新执行装备脚本构建。读档加载地图时不重跑 `script_on_enter`，避免重复剧情、重复奖励或重复取得道具。

角色场景形象同样以存档恢复的 `scene_sprite_numbers` 为准。正式 TileMap 与 CPU 对照渲染器每次同步都通过内容数据库解析当前 Sprite 编号，不依赖 `0065` 换装信号清理角色缓存；因此从特殊剧情造型期间读取一个普通造型存档时，不会继续显示读档前的动作。

## 格式与损坏保护

- `format_version` 控制结构兼容；不支持的版本会在菜单中标记为不可读取。
- 内容指纹覆盖当前 PAL 结构化数据；换用不同版本资源后，旧档不会被错误套到不匹配的数据上。
- 载荷使用 SHA-256 校验；截断、手工改坏或校验不符会显示明确错误。
- 写入先生成临时文件，再备份旧档并替换；失败时尽量保留上一份有效存档。
- Godot 存档不承诺兼容原版 SDLPal／DOS `.rpg`，也不应提交 GitHub。

代码 bug 修复后，只要 `format_version` 和 PAL 内容指纹仍兼容，玩家可以继续读取修复前保存的进度。复现问题时可在异常出现前另存一个槽位，并向开发者提供操作步骤；存档可能含原版运行状态，因此默认只在本机使用，不加入仓库。

剧情测试检查点不是完整主线存档。旧版“码头乘船”检查点继续游玩后可能把客栈开场的李大娘叫醒姿势和关闭楼梯写入正式槽位；读取时若 Scene 1 已处于喂药后的稳定入口，且 EventObject 4/11/12 仍精确保持该旧检查点的矛盾组合，探索场景会自动修复并显示提示。正常主线存档不会命中该兼容规则；修复后的进度再次保存即可固化。

## 测试

不依赖原版资源的格式、校验、损坏和往返测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_save_system_tests.gd
```

使用本机完整数据验证全部 Scene、EventObject 和装备重建：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_local_save_system_test.gd
```

存档页视觉快照包含在 `tests/run_local_menu_visual_test.gd`；输出继续写入被忽略的 `generated/pal/visual_tests/`。

启动页入口、独立取消和正式槽位只读恢复回归：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tests/run_local_startup_load_test.gd
```
