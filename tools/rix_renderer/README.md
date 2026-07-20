# RIX 离线转换器

这个辅助工具针对独立的 SDLPal 源码检出进行构建，把指定的 `MUS.MKF` RIX 曲目渲染为 44.1 kHz 单声道 PCM WAV。`PalDataImporter` 会扫描剧情脚本的场景/战斗音乐编号并逐首调用它。工具不会把原版音乐复制到 Git，输出必须放在已忽略的 `generated/` 下。官方 SDLPal 仓库只提供转换所需的代码，不包含原版游戏 Data。

```bash
python3 tools/rix_renderer/build.py \
  --upstream ../sdlpal-official \
  --output tools/rix_renderer/build/rix_renderer

tools/rix_renderer/build/rix_renderer /path/to/MUS.MKF 5 generated/pal/audio/rix/005.wav
```

构建脚本支持 macOS、Linux 和 Windows，会依次查找 `CXX`、Clang、GCC；Windows 还支持在 Developer Command Prompt 中使用 MSVC。Windows 输出文件名应使用 `rix_renderer.exe`。正常情况下无需手工构建，项目的一键资源命令会自动完成：

```bash
# macOS
./tools/generate_resources.sh /path/to/game/Data
```

```bat
rem Windows
tools\generate_resources.cmd "D:\games\PAL\Data"
```

正常项目开发优先运行完整导入命令，不需要手工列曲目：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/import_cli.gd -- --source /path/to/Data
```

包装代码采用 GPL-3.0-or-later。链接使用的 SDLPal、AdPlug 和 MAME 源码保留各自上游声明与许可证，详情参见固定检出和 `THIRD_PARTY.md`。
