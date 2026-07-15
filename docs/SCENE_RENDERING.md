# 场景角色与遮挡渲染

探索样板已不再使用几何占位标记。角色和事件对象会从本机导入的 `MGO.MKF` 读取原版 Sprite，并在 320×200 索引画布上与地图共同合成。

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
