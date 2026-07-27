---
name: 'HD-2D 重构与 TTS 调研结论'
summary: '记录渲染架构、资产生产、仓库边界与离线语音的阶段 0 决策。'
keywords: ['HD-2D', 'research', 'MiniMax', 'Bitto', 'Godot']
---

# 阶段 0 调研结论

## 决策：TileMap 权威 + 3D 视图适配器

- **理由**：现有主线、碰撞、坐标、选帧、Y 排序和 149 个视觉基准均建立在 `PalTileMapWorld`。共享快照能避免 2D/3D 两套规则分叉。
- **备选方案**：完全重写为 3D 导航；风险是 5332 个 EventObject 与 42292 条脚本坐标语义失效，拒绝。

## 决策：Godot 原生模块化 HD-2D

- **理由**：本机没有 Blender；固定镜头允许使用 GridMap/ArrayMesh、MultiMesh、Sprite3D、Decal 和分层景物卡片达到 HD-2D 表现，并保持地图拓扑。
- **备选方案**：每张地图用整张 AI 图；无法提供可靠可行走几何、遮挡和剧情镜头，拒绝。

## 决策：Bitto 图片、MiniMax TTS

- **理由**：Bitto v0.3.0 实时目录提供 `nano-banana-2` 与 `gpt-image-2` 图片能力，没有 TTS 命令。MiniMax skill 提供可复现清单、`speech-2.8-hd`、Ogg 转换和哈希索引。
- **备选方案**：客户端在线生成；会暴露 Key、增加网络故障和不可复现性，拒绝。

## 决策：Tripo Studio 只作可选网页 3D 工坊

- **理由**：官方文档确认图片/多视图转模型、低模、PBR 和 GLB 对 Godot 静态建筑/道具有用；但开发者 API 需要独立 Key 与积分，用户当前只有 Studio 网站会员。
- **使用方式**：Bitto 先提供干净的单体或多视图参考；通过 Studio 网页生成并人工导出 GLB；私仓记录 Studio、导出时间、源图、面数和 SHA-256。
- **备选方案**：接入 Tripo API；会产生额外费用且不是阶段 0 必需，拒绝。整张地图直接转 3D 也会破坏 TileMap 拓扑，拒绝。

## 决策：公开代码仓 + Private `sword-assets/`

- **理由**：高清 PNG/WebP/Ogg/GLB 规模不适合普通 Git，且同人衍生素材不应直接进入公开代码仓。嵌套 Private 仓可以独立 LFS、Tag 和撤回。
- **备选方案**：公开仓普通 Git 直存；二进制历史和分发风险过高，拒绝。

## 决策：第一章先行门禁

- **理由**：用户不进行手工美术修图，必须先锁定模型、人物比例、提示词、相机、材质和角色选声，避免 18 章批量返工及 TTS 额度浪费。
- **备选方案**：全量生成后统一复盘；返工范围不可接受，拒绝。

## 已验证环境

- Godot 项目版本为 4.7；当前默认 Compatibility 渲染。
- `.env.local` 存在、权限为 `600`、已被父仓忽略且不在 Git 历史中。
- `sword-assets/` 已克隆为独立 Private 仓，当前 `main` 为空仓。
- `ffmpeg` 可用；Git LFS 尚未安装，需要在阶段 0 安装并初始化。
- Bitto CLI v0.3.0 可用；图片模型为 `nano-banana-2` 和 `gpt-image-2`，无音频/视频模型。
- `agent-browser` 0.33.0 与配套 Chrome 已安装，可在明确用户操作时协助 Tripo Studio 网页；不会自动消耗会员额度。
