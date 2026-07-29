# PAL 简体补充点阵

`pal_simplified_font.png` 与 `pal_simplified_glyphs.json` 是从 GNU Unifont 17.0.03 提取的 16×16 汉字子集，用于补齐原版 DOS 繁体字库没有的简体 UI 字形。原版字形始终优先；补充点阵只填补缺字，并沿用游戏现有的调色板着色、单像素阴影和整数缩放。

- 上游：<https://unifoundry.com/pub/unifont/unifont-17.0.03/>
- 许可证：GPL-2.0-or-later WITH Font-exception-2.0
- 生成命令：`node tools/build_pal_simplified_font.mjs --unifont /path/to/unifont-17.0.03.hex.gz`

提交的 PNG/JSON 只包含当前 `src/` 与 `scenes/` 使用到的汉字。新增 UI 文案出现缺字时，应重新运行生成命令并提交更新后的两个产物。

Toy 排行榜昵称不属于静态 UI 文案，内容直到 SDK 返回时才知道，因此不加入这个构建期子集。Web 端统一由 `PalWebTextRenderer` 使用浏览器 Canvas 和系统中文字体生成 16px 字形，再把抗锯齿透明度二值化为硬边纹理；桌面视觉回归使用 Godot 系统 fallback。这样任意玩家昵称不需要提前写入点阵图集，在 320×200 画面整数放大后也不会出现灰边模糊。
