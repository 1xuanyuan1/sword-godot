---
name: '2D 高清重制开发快速开始'
summary: '说明 2DCS + Bitto、Sprite Video Lab、XSXB Lite、Private 素材仓和第一章 TTS 的安全流程。'
keywords: ['quickstart', '2DCS', 'Bitto', 'XSXB', 'MiniMax']
---

# 快速开始

## 仓库与工具

```text
sword/                         # 公开代码仓，release 分支
└── sword-assets/              # Private Git LFS 素材仓
/Users/xuanyuan/Documents/godotwork/sword-tools/
├── sprite-video-lab/
└── xsxb-frame-tuner/
```

- 2DCS 安装到 `~/.codex/skills/2dcs`。
- Sprite Video Lab 使用 `uv` 创建 Python 3.11 虚拟环境；XSXB Lite 使用现有 Node.js。
- `.env.local` 只保存 MiniMax Key，权限为 600；Bitto 使用已有 CLI 登录态，不打印或复制凭据。

## 人物生成

1. `$2DCS ct`：角色基准板 + 已批准目标画风；Nano 草案后用 GPT Image 定稿。
2. `$2DCS p`：批准母版 + 原 MGO 姿势参考，逐方向、逐动作生成候选。
3. 所有 Bitto 调用显式指定 `nano-banana-2` 或 `gpt-image-2`，输出到 `sword-assets/art/source/chapter_XX/characters/{id}/`。
4. 用 Sprite Video Lab 进行绿幕清理，再用 XSXB Lite 统一画布和脚底。
5. 转换并验证 `pal-sprite-atlas.json`，批准后更新 Private Remaster Manifest。

## 清单验证

```bash
python3 tools/validate_remaster_manifest.py --manifest sword-assets/manifests/remaster/chapter_01.json --root sword-assets
python3 tools/validate_pal_sprite_atlas.py --atlas sword-assets/art/runtime/chapter_01/characters/001/pal-sprite-atlas.json
python3 tools/validate_pal_map_tileset.py --tileset sword-assets/art/runtime/chapter_01/maps/map_012/pal-map-tileset.json
python3 tools/scan_public_release.py
```

## 第一章 TTS

```bash
python3 /Users/xuanyuan/.codex/skills/minimax-tts/scripts/minimax_tts.py validate \
  --manifest sword-assets/manifests/tts/chapter-01-samples.json \
  --output-dir sword-assets/tts/runtime

python3 /Users/xuanyuan/.codex/skills/minimax-tts/scripts/minimax_tts.py batch \
  --manifest sword-assets/manifests/tts/chapter-01-samples.json \
  --output-dir sword-assets/tts/runtime \
  --env-file .env.local
```

样音未批准前不得生成第一章全量；当前不得生成第二至十八章语音。

## 常见问题

- **高清地图缺帧**：整张地图回退经典 TileSet，不混搭部分高清帧。
- **人物 Atlas 映射不完整**：该人物回退经典 MGO 帧，不阻断剧情。
- **绿边或脚底跳动**：回到 Sprite Video Lab / XSXB Lite 修正，不能在运行时写逐帧补丁掩盖。
- **公开扫描失败**：从公开仓、日志或构建目录移除私有素材、原版数据、密钥和音频。
