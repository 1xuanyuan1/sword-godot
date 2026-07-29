---
name: '2D 高清重制与第一章 TTS 调研结论'
summary: '记录 2D 渲染、2DCS + Bitto 人物生产、素材工具、仓库和离线语音决策。'
keywords: ['2D remaster', '2DCS', 'Bitto', 'XSXB', 'MiniMax']
---

# 阶段 0 调研结论

## 决策：TileMap 权威 + 双 2D 渲染配置

- **理由**：主线、碰撞、坐标、选帧、Y 排序和 149 个视觉基准已建立在 `PalTileMapWorld`。经典与高清配置复用 Snapshot/Layout，能避免第二套规则。
- **备选方案**：继续 3D 视图或重写导航；视觉不符合目标且会破坏 EventObject/脚本坐标语义，拒绝。

## 决策：384×216 逻辑视野 + 5 倍物理像素

- **理由**：384×216 正好 5 倍填满 1920×1080；保持原相机中心即可自然增加左右各 32、上下各 8 个逻辑像素，存档与脚本无需迁移。
- **备选方案**：拉伸 320×200；破坏比例，拒绝。严格信箱边只保留给经典全屏 UI/过场核心区。

## 决策：2DCS 规范 + Bitto 后端

- **理由**：2DCS 明确区分外观参考、目标画风和姿势参考；Bitto Pro 当前提供 `nano-banana-2` 与 `gpt-image-2` 图片模型。
- **路由**：Nano 强制 `vertex`，用于草案；GPT Image 强制 `openai-images`，用于身份和尺寸敏感定稿。Codex 对话仍使用 aicoding。
- **限制**：2DCS `p/sq` 不保证连续帧像素级一致，因此正式图集必须经过抠图、统一画布、脚底校准和人工视觉检查。

## 决策：Sprite Video Lab + XSXB Lite

- **理由**：前者擅长绿幕/Alpha/序列导出，后者擅长统一画布、逐帧偏移与时长。两者均为离线开发工具。
- **边界**：不接入 XSXB gameplay runtime、碰撞框或攻击状态机；SDLPal 原选帧与战斗逻辑保持权威。
- **替代**：Greenscreen Frame Studio 功能重复；Pixel Deck/Pixel OK 与本项目无关，不采用。

## 决策：地图使用编号稳定的高清 TileSet

- **理由**：整张 AI 场景无法可靠支持滚动、重复图块、上层遮挡和事件拓扑。按 GOP 帧编号重制可直接复用 MAP 数据。
- **门禁**：地图实际引用的全部帧覆盖后才启用高清 TileSet；否则整图回退经典，避免新旧风格拼贴。

## 决策：第一章 TTS 门禁

- **理由**：语音与 2D 视觉解耦，但全量生成会消耗额度。先完成三条样音和第一章听检，后续章节当前不生产。
- **实现**：MiniMax 开发期离线生成，运行时按消息 ID 序列索引，不从显示文本拼文件名。

## 已验证环境

- Godot 4.7；当前分支 `release`；经典 TileMap 主线和 223 地图清单已存在。
- Bitto CLI v0.3.0 可用，Pro 目录包含 `nano-banana-2` 和 `gpt-image-2`。
- Node v25.9.0、npm 11.12.1、ffmpeg/ffprobe 8.1、`uv` 可用；系统 Python 3.9，因此 Sprite Video Lab 使用隔离 Python 3.11。
- `sword-assets/` 是独立 Git 仓；现有 Map 012 3D 原型只归档，不作为 2D 定稿来源。
