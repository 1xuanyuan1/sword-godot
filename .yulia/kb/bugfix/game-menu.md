---
name: '游戏菜单 Bug 修复记录'
summary: '记录经典主菜单、物品选择页及相关交互问题和修复'
keywords:
  - game-menu
  - inventory
  - 菜单
  - 物品
---

# 游戏菜单 Bug 修复记录

## 修复记录

## 2026-07-15

### [BF-006] 物品页缺少选中物品说明

- **来源**: 用户试玩反馈
- **关联需求**: M3 菜单与物品系统
- **问题描述**: 原版物品选择页会在左下物品图标右侧显示当前物品说明，Godot 版首次还原时只实现了列表、数量、光标和图标，遗漏了 `desc.dat` 的导入与说明绘制。
- **涉及文件**:
  - `tools/pal_text_convert.py`
  - `src/import/pal_data_importer.gd`
  - `src/content/pal_content_database.gd`
  - `src/ui/pal_game_menu.gd`
  - `tests/run_tests.gd`
  - `tests/run_local_menu_visual_test.gd`
  - `README.md`
  - `docs/CLASSIC_UI.md`
- **修复内容**: 将本地 `desc.dat` 按当前资源编码转换为对象说明表，选中物品后从官方坐标 `(75, 150)` 绘制黄色说明文字；原文 `*` 按官方规则拆为多行并保持 16 像素行距，移动选择时说明实时更新。原版说明继续只生成到被 Git 忽略的 `generated/`。
- **状态**: ✅ 已修复
