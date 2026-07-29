# 精致国风像素 2D 高清重制与第一章 TTS

`release` 分支从旧版基线 Tag `v0.1.5` 开始。当前方向是在保留完整主线、地图拓扑、战斗、菜单与存档的前提下，以 `384×216` 逻辑视野和 1920×1080 输出重制全部 2D 画面。完整规格、数据模型、工具契约和逐章任务见 [2d-remaster-tts 需求目录](../.yulia/kb/requirements/2d-remaster-tts/spec/plan.md)。

## 不变边界

- 正式地图继续使用 `TileMapLayer + PalTileMapWorld`；CPU 合成只用于经典像素对照。
- MAP/GOP 编号、阻挡、入口、EventObject 坐标、人物选帧、Y 排序、遮挡、战斗和脚本语义保持不变。
- `GameSession.viewport_position`、`PARTY_OFFSET=(160,112)`、相机中心和旧存档不迁移。
- TTS 只读取开发期离线生成的本地音频；客户端不包含 MiniMax Key。
- `Data/`、`generated/`、Private `sword-assets/` 和外部素材工具不进入公开仓或正式运行包。

## 1080p 展示结构

`PalPresentationMetrics` 同时定义：

- 经典基准 `320×200`；
- 高清逻辑视野 `384×216`；
- 5 倍输出 `1920×1080`；
- 原 UI 核心区 `(32,8,320,200)`，物理区 `(160,40,1600,1000)`。

相机中心仍为 `session.viewport_position + (160,100)`。高清模式只扩大周围可见范围：左右各增加 32、上下各增加 8 个 PAL 逻辑像素。菜单、对话、战斗、RNG、FBP 和结局继续以原 320×200 布局为核心，不拉伸。

经典与高清配置都由 `PalTileMapWorld` 和同一份 `PalWorldPresentationSnapshot` / `PalSceneLayout` 驱动。高清资源缺失时，地图使用经典 TileSet 5 倍最近邻显示，人物使用经典 MGO 帧；不得复制移动、碰撞、帧选择或事件规则。

## 资源契约

- `map/{id}/tileset`：160×80 高清 Tile 单元，对应原 32×15 有效内容的 160×75。
- `character/{id}/field`：`pal-sprite-atlas.json + sheet.png`，逐帧映射原 MGO `frame_index`。
- 立绘、战场、战斗动作、过场、语音和 UI 沿用稳定逻辑 ID。
- 一张地图实际引用的 GOP 帧必须全部覆盖，才能启用高清 TileSet；不允许部分高清图块与经典图块拼贴。
- 正式资源优先级：启用 MOD → Private 高清包 → 玩家经典资源 → 占位资源。

## 2DCS + Bitto 人物生产

1. 从原像素 Sprite、立绘、服装和武器整理角色基准板。
2. 2DCS `ct` 使用“角色基准板 + 批准画风参考”：Bitto `nano-banana-2`/`vertex` 生成草案，`gpt-image-2`/`openai-images` 生成母版。
3. 2DCS `p` 使用“批准母版 + 原 MGO 姿势参考”生成正背左右和动作候选；`sq` 只做动作方向探索。
4. Sprite Video Lab 清理绿幕和 Alpha，XSXB Frame Tuner Lite 统一画布、脚底原点与时长。
5. 转换为项目 Atlas，验证帧数、顺序、pivot、透明边缘和 SHA-256 后进入 Private 素材仓。

所有 Bitto 调用显式指定模型，不使用自动路由，不请求原生透明背景，不覆盖已有候选。清单保存 2DCS 模式、模型、协议、输入顺序/哈希、提示词版本、请求/实际尺寸、输出哈希与审核结论。

## 第一章 TTS

MiniMax 当前只生产第一章：

1. `ScriptVM.dialog_round_ready` 提供完整消息 ID 序列；运行时不从显示文字拼文件名。
2. 先生成李逍遥、李大娘、旁白/NPC 三条样音，人工批准后再批量生成第一章。
3. 对白真正翻页、跳过、切场景、进战斗和读档时停止旧语音；缺失音频退回手动推进。
4. 第二至十八章当前不生成 TTS，后续需重新确认范围。

## 里程碑

- [x] 固化旧版 `v0.1.5` 并建立 `release` 分支。
- [x] 建立 1920×1080 展示壳、资源解析器和稳定对白轮次信号。
- [ ] 退役 3D 原型并恢复纯 2D Compatibility 路径。
- [ ] 完成 384×216、5 倍输出和经典 UI 输入映射。
- [ ] 完成地图 TileSet、人物 Atlas、校验器和缺失回退。
- [ ] 完成李逍遥四方向基准与 Map 012 客栈垂直切片。
- [ ] 完成第一章视觉资源、三条样音、全章 TTS 和真实运行验收。
- [ ] 按章节完成第二至十八章视觉重制。

## 发布约束

桌面公开包继续采用“玩家本地导入合法取得的 Data”模式。免费分享和免责声明不等于授权；字体、音乐、音效、生成模型条款、同人声明和下架联系方式未通过检查前，只保留 Private 素材与本地构建。
