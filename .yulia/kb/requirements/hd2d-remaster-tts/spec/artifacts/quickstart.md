---
name: 'HD-2D 重构开发快速开始'
summary: '说明公开代码仓、Private 素材仓、Bitto 与 MiniMax 的安全开发流程。'
keywords: ['quickstart', 'Godot', 'Bitto', 'MiniMax', 'Git LFS']
---

# 快速开始

## 仓库

```text
sword/                  # 公开代码仓，release 分支
└── sword-assets/       # Private Git LFS 仓，被父仓忽略
```

1. 克隆公开代码仓并切换 `release`。
2. 把 Private `sword-assets` 克隆到项目根目录的同名目录。
3. 安装 Git LFS，进入素材仓执行 `git lfs install --local`。
4. 在项目根目录创建被忽略的 `.env.local`，只写 `MINIMAX_API_KEY`，权限设为 `600`。

## 验证清单

```bash
python3 tools/validate_remaster_manifest.py --manifest sword-assets/manifests/remaster/chapter-01.json --root sword-assets
python3 tools/validate_remaster_manifest.py --manifest remaster-content.lock.json --kind lock --schema-only
python3 tools/scan_public_release.py
```

## 生成图片

- 草案：Bitto `nano-banana-2`，用于构图和风格探索。
- 定稿：Bitto `gpt-image-2`，保存最终提示词、模型、协议、尺寸和 SHA-256。
- 所有输出先进入 `sword-assets/source/bitto/chapter-XX/`，审核后复制到 `runtime/` 并更新清单。

## 可选生成 3D 模型

Tripo 只使用 Studio 网站会员，不接开发者 API。先用 Bitto 生成背景干净的单体或多视图参考，再在 Tripo Studio 中手动生成并导出 GLB。GLB 放入 `sword-assets/source/tripo/chapter-XX/`，记录源图、导出时间、面数和哈希；通过 Godot 比例、材质、轴向与性能检查后才复制到 `runtime/models/`。

## 生成 TTS

```bash
python3 /Users/xuanyuan/.codex/skills/minimax-tts/scripts/minimax_tts.py validate \
  --manifest sword-assets/manifests/tts/chapter-01-samples.json \
  --output-dir sword-assets/runtime/tts

python3 /Users/xuanyuan/.codex/skills/minimax-tts/scripts/minimax_tts.py batch \
  --manifest sword-assets/manifests/tts/chapter-01-samples.json \
  --output-dir sword-assets/runtime/tts \
  --env-file .env.local
```

样音必须先试听；未批准前不得生成第一章全量或后续章节。

## 常见问题

- **没有 Private 素材仓**：游戏回退本地经典导入或占位资源，不阻断主线。
- **清单哈希不匹配**：资源被修改；更新清单前先确认是有意替换。
- **语音缺失**：对白继续手动推进，不显示资源导入错误。
- **公开构建扫描失败**：移除私有素材、原版数据、密钥或音频后再构建。
