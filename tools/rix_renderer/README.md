# RIX 离线转换器

这个辅助工具针对独立的 SDLPal 固定版本进行构建，把指定的 `MUS.MKF` RIX 曲目渲染为 44.1 kHz 单声道 PCM WAV。它不会把原版音乐复制到 Git，输出必须放在已忽略的 `generated/` 下。

```bash
python3 tools/rix_renderer/build.py \
  --upstream ../sdlpal-official \
  --output tools/rix_renderer/build/rix_renderer

tools/rix_renderer/build/rix_renderer /path/to/MUS.MKF 5 generated/pal/audio/rix/005.wav
```

包装代码采用 GPL-3.0-or-later。链接使用的 SDLPal、AdPlug 和 MAME 源码保留各自上游声明与许可证，详情参见固定检出和 `THIRD_PARTY.md`。
