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

## 方向与行走帧

角色站立帧按“方向 × 每方向帧数”定位。`PLAYERROLES.rgwWalkFrames` 为 0 时沿用原版默认值 3；四帧角色按四步循环，三帧角色沿用 SDLPal 的 `0 → 1 → 0 → 2` 步态。事件对象在 `nSpriteFrames == 3` 时也保留原版对帧 2、3 的重映射规则。

队伍移动会保存五格位置与方向轨迹。第二、第三名队员使用 SDLPal 的 `rgTrail[1]` 编队偏移和 `rgTrail[2]` 朝向；编队位置遇到地图或事件阻挡时，退回轨迹中心点。脚本改变队伍成员后，角色 Sprite 会按新的角色编号延迟载入并复用缓存。

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

本地 `run_local_tilemap_visual_test.gd` 会让 TileMapLayer 和 CPU 使用同一会话状态。目前客栈 map 12 的固定视口已经达到 320×200 零差异像素。
