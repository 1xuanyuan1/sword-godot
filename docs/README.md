# Sword Godot 中文文档

本目录说明项目如何从本机合法取得的 PAL 数据构建 Godot 运行时，以及各模块之间怎样协作。第一次阅读项目时，建议按下面的顺序开始。

## 推荐阅读顺序

1. [项目目录结构](PROJECT_STRUCTURE.md)：先找到入口场景、源码模块、测试和本地生成目录。
2. [整体架构](ARCHITECTURE.md)：理解资源导入、游戏状态、脚本虚拟机、地图和 UI 的数据流。
3. [资源与版权边界](RESOURCE_POLICY.md)：确认哪些内容可以提交 Git，哪些内容只能保留在本机。
4. [场景角色与遮挡渲染](SCENE_RENDERING.md)：理解 PAL 等距地图、half 格、TileSet、人物锚点和遮挡。
5. [脚本虚拟机](SCRIPT_VM.md)：理解原版事件脚本、对话、自动行走和场景切换。
6. [音乐、音效与音量](AUDIO.md)：理解 RIX/VOC 离线转换、脚本曲目切换和系统菜单音量。
7. [经典菜单与物品页](CLASSIC_UI.md)：理解原版菜单布局、点阵字和物品资源。
8. [开发工作流](DEVELOPMENT_WORKFLOW.md)：运行、导入、测试、剧情检查点、提交和排错。
9. [SDLPal 上游基准](UPSTREAM.md)：查看固定参考提交和 Godot 模块到 SDLPal 源文件的映射。

RNG 动画格式另见 [RNG 增量动画](RNG_FORMAT.md)，文档和源码注释约定见 [文档语言与注释规范](DOCUMENTATION.md)。

## 当前开发记录

- [开发待办](../.yulia/kb/changelog/todo.md)
- [功能变更记录](../.yulia/kb/changelog/changelog.md)
- [地图探索问题归档](../.yulia/kb/bugfix/map-explorer.md)
- [对话问题归档](../.yulia/kb/bugfix/dialog.md)

文档默认使用中文。代码标识符、命令、许可证原文和第三方名称保留原文，以免产生技术或法律歧义。
