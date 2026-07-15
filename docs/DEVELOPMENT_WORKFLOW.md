# 开发工作流

## 运行项目

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

首次运行先在资源实验室选择本机合法取得的 `Data` 目录并执行导入。导入器只读取源目录，所有产物写入 `generated/pal/`。

## 命令行导入

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/import_cli.gd -- --source /path/to/Data
```

当导入格式版本、TileSet 生成规则或本机原版资源发生变化时，应重新导入，不能手工修改 `generated/` 中的结果来掩盖转换问题。

## 测试层级

### 合成测试

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_tests.gd
```

这些测试只使用代码构造的字节和状态，可以在 GitHub CI 执行，必须覆盖格式边界、ScriptVM 基础行为、TileSet 坐标和自定义数据。

### 本地资源测试

`tests/run_local_*.gd` 读取 `generated/pal/`，用于验证完整导入数据、剧情流程、菜单和像素截图。它们可以提交测试代码，但不得提交输出截图、原版文字转储或资源文件。

### 人工剧情检查点

资源实验室的“剧情测试”只用于尚未验收、必须人工观察的问题。验证完成后删除按钮和检查点，保留对应的自动回归，避免测试界面持续膨胀。

## 地图像素对照

迁移 TileMapLayer 时，同一 `GameSession` 状态分别交给 CPU 基准和 Godot 原生渲染路径，在 320×200、最近邻、整数相机坐标下截图比较。重点检查透明边缘、调色板、床沿、门框、楼梯、门口 NPC 和屋檐。

若 Godot Y 排序无法逐像素表达 SDLPal 覆盖块规则，地图主体仍保持 TileMapLayer，只让特殊覆盖块进入兼容 Sprite2D 层。

## Git 与提交

- 修改前先检查 `git status`，用户已有修改不得覆盖或顺带提交。
- 功能达到可运行、测试通过并同步中文文档后再 commit。
- 每个可验证里程碑独立提交并 push 到 `origin/main`。
- `Data/`、`generated/`、存档、构建产物和本地日志不得加入 Git。
- 开发待办完成后归档到功能变更记录，并回填关联编号。

## 注释和文档检查

新增 GDScript 文件必须有中文模块说明；公开类、信号和公开函数使用 `##` 文档注释。复杂私有函数解释数据来源、坐标公式或兼容原因，不复述显而易见的语句。

修改目录职责、公开接口、资源格式、输入方式或测试命令时，必须同步更新 `docs/README.md` 及对应专题文档。
