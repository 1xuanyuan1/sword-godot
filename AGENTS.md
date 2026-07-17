# SDLPal Godot 复刻开发约束

## 地图渲染基准

- 正式运行和新增测试以 `TileMapLayer + PalTileMapWorld` 为准；不要把 CPU 合成画面当作功能完成依据。
- 人物选帧、坐标换算、调色板、Y 排序和遮挡规则应提取为共享逻辑，禁止在 CPU 与 TileMap 渲染器中各写一套容易分叉的实现。
- 修改地图、人物动作、镜头或遮挡后，至少验证 TileMap 正式路径；真实画面问题必须使用带窗口运行和实际像素截图检查，不能只断言 CPU 状态。

## CPU 对照渲染器

- `PalSceneRenderer` 的整屏 CPU 合成只用于开发期诊断、像素基准和临时回退，不再扩展为新的正式运行能力。
- 复刻画面出现差异时，可以把同一个 `GameSession` 分别交给 TileMap 和 CPU 路径，以 320×200、最近邻、整数相机坐标进行对照；截图只能写入被 Git 忽略的 `generated/pal/visual_tests/`。
- 对照发现差异后，应修复 TileMap 正式路径或共享规则；不能为了让 CPU 测试通过而遗漏 `PalTileMapWorld`。

## 最终退役条件

- 全部有效地图、主线剧情、特殊遮挡和完整通关均通过 TileMap 验收后，移除正式运行中的 CPU 地图渲染路径。
- 退役范围包括 `MapExplorer` 的 `_map_view`、`_use_legacy_renderer`、`--pal-map-backend=legacy` 以及生产流程中的整屏 CPU 合成与纹理上传。
- 如仍需要像素基准，只在 `tests/` 或 `tools/` 中保留最小对照能力，不随正式游戏运行。
