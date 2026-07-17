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

## 2026-07-17

### [BF-018] 场外仙术页误显示物品并遮挡左上信息

- **来源**: 用户试玩反馈
- **关联需求**: M3 菜单与仙术系统
- **问题描述**: 场外仙术视觉测试遍历了物品与仙术共用的整个 `OBJECT` 表，导致标志位碰巧满足场外使用条件的物品“银杏子”被误选为仙术；同时左上角在绘制仙术说明时仍叠加金钱和 MP 信息，造成文字遮挡。
- **涉及文件**:
  - `src/ui/pal_game_menu.gd`
  - `tests/run_local_menu_visual_test.gd`
- **修复内容**: 视觉测试的候选对象改为仅来自 `PLAYERROLES` 初始仙术和升级习得表，并校验对应仙术定义；有仙术说明时，左上信息栏只绘制“所需 MP / 当前 MP”，说明从右侧独立区域开始绘制。真实资源样板现使用气疗术，不再出现银杏子或文字重叠。
- **状态**: ✅ 已修复

---

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
