# 场景角色与遮挡渲染

探索样板已不再使用几何占位或整屏 CPU 合成作为默认显示。角色和事件对象会从本机导入的 `MGO.MKF` 读取原版 Sprite。地图导入阶段为每个唯一 `map_number` 生成 Godot 4.7 `TileSet` 和四个 `TileMapLayer`；CPU 索引画布只保留作像素基准。

## TileSet 生成产物

- GOP 的所有 32×15 RLE 图块装入 32×16 单元的 RG8 图集：R 是 PAL 调色板索引，G 是透明度，最后一行透明。
- 图集使用保留压缩缓冲的无损 `PortableCompressedTexture2D`，随 TileSet 保存为本地二进制 `.res`。
- `StaticBottom` 和 `StaticTop` 保存完整地图；`CoverBottom`、`CoverTop` 为运行时特殊遮挡预留。
- 相同 GOP Sprite 在不同位置可以拥有不同阻挡或逻辑高度，因此 TileSet 使用 alternative tile 保存 `pal_layer`、`pal_sprite_index`、`pal_blocked` 和 `pal_height`。
- 原版资源和这些 Godot 资源全部位于被 Git 忽略的 `generated/pal/content/world/`。

PAL 每格有两个 half。它们映射到 Godot 等距单元：

```gdscript
Vector2i(map_x + map_y + half, map_y - map_x)
```

Godot 等距单元 `(0,0)` 的默认中心是 `(16,8)`，因此生成的 TileMapLayer 统一偏移 `(-16,-8)`。最终单元中心恰好回到 PAL 世界坐标：

```text
(map_x × 32 + half × 16, map_y × 16 + half × 8)
```

当前数据的地图 145 含一个引用不存在 GOP 帧的原始记录。SDLPal 对缺失底层帧会回退到 `(0,0,0)` 底层图块，对缺失上层帧则跳过；导入器沿用该行为并报告警告，不会伪造新素材。

移动碰撞不能只用 `x % 32` 判断 half。NPC 和脚本位移可能落在 32×16 菱形内部任意像素，`PalMapCoordinates.world_to_tile()` 按 SDLPal `PAL_CheckObstacleWithRange` 的四区边界映射到实际 `(map_x,map_y,half)`。玩家主动移动、TileMap 自定义阻挡查询和怪物追逐统一调用该换算；玩家另外保留固定队伍偏移形成的左上视口活动边界，脚本落点和 NPC 路径不套用该边界。

EventObject 移动阻挡使用严格的 `abs(dx) + abs(dy) × 2 < 16`；NPC 已经挤占队伍脚点后的脱困条件才使用 `≤12`。阻挡判断按原版只读取正 `state`，因此正 `vanish_time` 暂时隐藏对象时不会意外解除碰撞。

SDLPal 在 320×200 视口超出 64×128 地图边界时，也会重复绘制 `(0,0,0)` 底层图块。楼梯落点等合法场景会短暂看到这一区域，因此生成场景在四周加入只覆盖一个视口所需的底层 padding；移动阻挡仍把实际地图范围外视为不可行走。

## 数据链路

- `DATA.MKF` 第 3 分块对应 SDLPal 的 `PLAYERROLES`，其中 `rgwSpriteNum` 决定各角色在普通场景使用的 MGO Sprite。
- `SSS.MKF` 的 `EVENTOBJECT` 直接保存 NPC、怪物和场景物件的 Sprite 编号、方向、当前帧及逻辑层。
- `MGO.MKF` 的非空分块先经 YJ1 解压，再按 Sprite 偏移表切分为 RLE 索引帧。
- 导入后的 `.spr` 只写入被 Git 忽略的 `generated/pal/content/sprites/mgo/`，不能随代码发布。

当前 DOS 繁体资源共有 636 个非空 MGO Sprite。导入测试会验证它们全部能解压并形成合法帧表。第 571 号 Sprite 含有 SDLPal `palcommon.c` 明确兼容的原始偏移回绕特例，Godot 解析器保留了同样的处理。

场景切换后，探索控制器会依据 `PalSceneCatalog` 将详细场景名归并为大区域名，并在 HUD 顶部显示短暂地点 Toast。例如从余杭乘船抵达“仙灵岛·岸”时显示“仙灵岛”；仙灵岛内部的岸、峡和莲池之间切换不会重复刷屏。初次启动、读档恢复、无效名称也不会触发该提示。地点 Toast 使用独立控件，不会占用或打断剧情对话框。

## 方向与行走帧

角色站立帧按“方向 × 每方向帧数”定位。`PLAYERROLES.rgwWalkFrames` 为 0 时沿用原版默认值 3；四帧角色按四步循环，三帧角色沿用 SDLPal 的 `0 → 1 → 0 → 2` 步态。事件对象在 `nSpriteFrames == 3` 时也保留原版对帧 2、3 的重映射规则。

`0015` 下发的有效剧情动作帧在 CPU 对照渲染器和 `PalTileMapWorld` 中都优先于残留步态标志。正常移动会先清除旧剧情动作，因此不会破坏普通行走；移动之后再次设置的倒地、举杯或固定姿势则必须由两种后端画出同一帧。合成测试会同时调用两条选帧路径，避免只修隐藏的 CPU 基准而遗漏默认 TileMap 画面。

队伍移动会保存五格位置与方向轨迹。Godot 版保留 SDLPal 的菱形方向偏移，但为改善试玩观感将第二、第三名队员的基点从 `rgTrail[1]` 前移到 `rgTrail[0]`，朝向延迟也由第 3 格缩到第 2 格；两人持续直行时脚底间距由约 `48×24` 收紧为 `32×16`，仍留有两个 half 格避免人物重叠。编队位置遇到地图或事件阻挡时，两条渲染路径都退回同一个紧凑轨迹中心。脚本改变队伍成员后，角色 Sprite 会按新的角色编号延迟载入并复用缓存。

人物场景 Sprite 统一由 `PalContentDatabase.load_player_scene_sprite()` 根据 PLAYERROLES 当前编号解析，MGO 数据只按实际 Sprite 编号缓存。渲染器不能再按角色编号长期缓存结果：`0065` 会在剧情中换装，而读档会直接恢复整组 `scene_sprite_numbers`，后者不会额外发出脚本换装信号。这样喂药、端酒、倒地等特殊造型结束或读档后，CPU 对照和正式 TileMap 都会在下一次同步立即使用正确造型。

## Y 排序和地图遮挡

SDLPal 先绘制完整双层地图，再把以下内容放进同一个基准 Y 队列：

1. 队伍成员；
2. 当前场景的可见事件对象；
3. 可能盖住每个角色的高逻辑层地图块。

Godot 的 `PalSceneRenderer` 按 `scene.c` 的坐标、逻辑层和覆盖块扫描规则实现同一流程。这样人物经过床沿、墙体、屋檐或其他高层地图块时，遮挡关系由地图数据决定，而不是简单地让所有人物永远位于地图上方。

原生路径中的 `PalTileMapWorld` 使用以下节点：

```text
PalTileMapWorld
├── PalTileMap###
│   ├── StaticBottom       # 完整底层 TileMapLayer
│   ├── StaticTop          # 完整上层 TileMapLayer
│   ├── CoverBottom        # 预留的 TileMap Y 排序对照层
│   └── CoverTop
├── YSortRoot              # 队伍、事件和兼容覆盖 Sprite2D
└── PalCamera              # 320×200 整数位置 Camera2D
```

静态地图完全由 TileMapLayer 绘制。人物和事件使用带脚底基准的 `Node2D + Sprite2D`；SDLPal 可能重复绘制的特殊覆盖块使用同一 RG8 图集内容创建兼容 Sprite2D，并和人物进入同一 Y 排序容器。这样既保留 Godot 原生地图，也避免强行用单个 TileMap 单元表达原版逐人物覆盖队列。

## 采集物星芒

正式 `PalTileMapWorld` 会为当前可拾取的宝箱、草药、柜子暗格、地面物件和尸骨掉落绘制 9×9 金色四角星芒。分类器检查 EventObject 的可见状态、搜索模式、静态 Sprite 结构及当前触发脚本中的正向物品/金钱指令；带购买成本的商贩、动画 NPC 奖励和纯剧情取得物不会被标记。室内暗格即使没有独立 MGO Sprite，也会按 EventObject 世界坐标生成标识。

星芒和事件对象共用基准 Y，并经过 `PalSceneRenderer.expanded_draw_items()` 的覆盖块扫描，所以屋顶、树冠和柜架仍可遮住它；它不是 HUD 置顶提示。Shader 使用固定白／金／琥珀像素和 1.2 秒呼吸周期，不受日夜调色板影响。实际执行正向 `001E/001F` 后，探索控制器才把该 EventObject 记入 `GameSession.collectible_marker_event_ids` 并刷新世界；普通宝箱还会依赖原版空箱入口或隐藏状态，可重复鼠儿果则只永久熄灭提示，不改变继续采摘的原版行为。

CPU 整屏合成不新增星芒能力。像素基准测试通过 `PalTileMapWorld.set_collectible_markers_enabled(false)` 关闭辅助层，正式游戏始终默认开启。

`ScriptVM 007F` 使用独立的剧情镜头偏移。它只改变 `PalCamera` 和 CPU 对照渲染使用的视口左上角，不修改 `GameSession.viewport_position`、队伍脚底、轨迹或事件坐标；逐帧平移、固定格坐标和复位因此不会误触碰撞。场景切换会清空临时偏移。

本地 `run_local_tilemap_visual_test.gd` 会让 TileMapLayer 和 CPU 使用同一会话状态。正式项目的默认清屏色固定为黑色，与 CPU 索引画布初始化及 SDLPal 地图边界语义一致；否则地图图块之间极少量未覆盖像素会露出 Godot 默认灰底。离屏 SubViewport 推进场景帧后还会等待 `RenderingServer.frame_post_draw`，避免 Metal 尚未提交纹理时读到全透明帧。当前从余杭到蜀山、锁妖塔、圣姑住处、神木林、大理、火麒麟洞、女娲神殿、回魂仙梦南诏、十年前余杭、试炼窟女娲遗迹、五灵珠祭坛、祭雨和无底深渊共登记 138 个固定视口；新增 12 个第十七章用例均在 Godot 4.7 Metal 真窗口下逐个达到 320×200 零差异并实际检查截图。Metal 长时间连续运行不再提交某个 SubViewport 时，可在 `--` 后追加 `--pal-visual-case=用例名` 隔离运行，不能用 dummy renderer 代替。
