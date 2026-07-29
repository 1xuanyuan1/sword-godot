---
name: '【PLAN】精致国风像素 2D 高清重制与 2DCS + Bitto 实施方案'
summary: '退役 3D 原型，以双配置 PalTileMapWorld、5 倍高清像素资源、2DCS + Bitto 人物生产链和第一章离线 TTS 逐章实施。'
keywords: ['2D remaster', '2DCS', 'Bitto', 'Godot 4.7', 'MiniMax TTS']
---

# 实施方案：精致国风像素 2D 高清重制与第一章 TTS

**需求 ID**: `2d-remaster-tts` | **日期**: 2026-07-29 | **规格说明**: [spec.md](spec.md)

## 技术上下文

- **运行时**：Godot 4.7、GDScript、Compatibility、TileMapLayer、Sprite2D、CanvasItem Shader。
- **素材工具**：2DCS、Bitto CLI、Sprite Video Lab、XSXB Frame Tuner Lite、Git LFS、ffmpeg。
- **仓库**：公开代码仓 + 嵌套 Private `sword-assets/` + `user://mods/`。
- **规模**：18 章、223 地图、294 剧情场景、636 MGO、88 立绘、72 战场、227 战斗/法术组、12 RNG、12880 条消息。
- **边界**：经典存档与剧情语义兼容；无 Key 入包；CPU 地图渲染不回到正式路径。

## 实施阶段

### 0. 方向切换与基础设施

1. 用本需求目录替换旧 HD-2D 规格，更新架构和重制文档。
2. 退役 Camera3D、Sprite3D、3D 环境和 Forward+ 专用配置；保留 Git 历史并归档 Private 3D 素材。
3. 安装并锁定 2DCS、Sprite Video Lab 和 XSXB Lite；禁止 XSXB gameplay runtime 接管 SDLPal 逻辑。
4. 更新资源 Schema、锁文件、敏感内容扫描与缺失回退。

### 1. 384×216 2D 展示底座

1. `PalPresentationMetrics` 定义 384×216 逻辑视野、5 倍输出与 320×200 核心区。
2. `PalTileMapWorld` 复用同一 Snapshot/Layout，支持经典与高清渲染配置。
3. `PalWorldPresentationSnapshot` 删除 3D 字段，只保留 PAL 世界位置、帧、方向、层级、镜头与调色板状态。
4. 统一窗口→高清逻辑→经典 UI 坐标换算，验证边界外点击不误触。
5. 实现地图 TileSet、人物 Atlas 加载、哈希校验和经典回退。

### 2. 第一章垂直切片

1. 先完成李逍遥角色基准板、2DCS `ct` 草案、`gpt-image-2` 母版和四方向待机/行走图集。
2. 完成 Map 012 客栈 TileSet，严格复刻家具和遮挡拓扑，人物不烘焙进地图。
3. 完成余杭/十里坡室外与梦境代表战斗，锁定地图、人物、战斗、特效和 UI 像素密度。
4. 生成三条 TTS 样音，人工批准后完成第一章全部对白与旁白。
5. 通过主线、TileMap、1920×1080 截图、性能、听检和仓库扫描后，代码仓与素材仓分别打第一章 Tag。

### 3. 第二至十八章

- 逐章完成地图、人物/NPC、立绘表情、战场、战斗动作、法术、过场和 UI 资源。
- 每章从上一章存档自然进入，运行对应主线、正式 TileMap、真实窗口、性能和权利检查。
- 第二至十八章当前不生成 TTS；第十三章桃源村支线单独完整验收。
- 每个边界清晰的基础设施、章节和 Bug 修复独立提交；素材仓同步提交并打 Tag。
## 工具与资源流

```text
原版角色基准板 + 批准画风
  → 2DCS ct / Bitto nano-banana-2 草案
  → 2DCS ct / Bitto gpt-image-2 母版
  → 2DCS p 四方向与动作候选
  → Sprite Video Lab 绿幕清理
  → XSXB Lite 画布/脚底/时长校准
  → pal-sprite-atlas.json + sheet.png
  → Manifest/哈希/视觉校验
  → PalTileMapWorld Sprite2D
```

地图不使用整张 AI 图作为可行走背景。先导出原图块 Atlas、完整地图拼图、上下层遮挡、阻挡和事件参考，再制作 160×80 高清图块并按原 GOP 编号回填。

## 每章完成定义

- 高清资产完整或有明确经典回退，不出现导入错误和剧情中断。
- 地图、人物、UI、战斗和过场保持原布局与交互语义。
- 运行该章主线回归、TileMap 正式路径回归、1080p 带窗口截图和性能检查。
- 代码仓与素材仓分别创建独立提交；通过门禁后分别打章节 Tag。
