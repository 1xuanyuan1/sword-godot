# 状态图标

`status_condition_icons.png` 是 10 格、每格 16×16 的透明 PNG 图集，顺序固定为：

1. 中毒
2. 混乱
3. 定身
4. 昏睡
5. 封咒
6. 傀儡
7. 勇气
8. 防护
9. 加速
10. 双击

源图于 2026-07-22 通过已登录的 Bitto CLI 自动路由到 `gpt-image-2`（`openai-images` 协议）生成。提示词要求 5×2 网格、1995 年 DOS 中文 RPG 像素风、洋红色键背景及 14×14 可读性；随后使用 Codex imagegen 的色键工具移除背景，并按透明像素包围盒缩放、整理为本图集。运行时仍由 `PalRoleConditionDisplay` 统一决定毒与九种状态到图集格子的映射。
