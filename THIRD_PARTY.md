# 第三方声明

## SDLPal

本项目学习并移植了 SDLPal 的部分架构、数据格式和运行逻辑。

- 官方仓库：<https://github.com/sdlpal/sdlpal>
- 本项目固定基准所用镜像：<https://gitee.com/sdlpal/sdlpal>
- 许可证：GNU GPL version 3
- 固定提交：`79718a1aa2fb889994d1d084765025994d429706`
- Copyright (c) 2009–2011 Wei Mingzhi
- Copyright (c) 2011–2026 SDLPal development team

具体改写自 SDLPal 的文件会在文件头保留 `Adapted from SDLPal` 说明。英文版权名称和许可证名称按原文保留。

## AdPlug 与 MAME OPL

离线 RIX 音乐转换器调用固定 SDLPal 检出中的 AdPlug 播放器和 MAME OPL 模拟核心。相关源码不会复制进本仓库，构建时从同级 `sdlpal-official` 目录引用，并沿用其原始许可证和版权声明。

## 原版游戏

本仓库不分发任何原版游戏资源。《仙剑奇侠传》的名称、美术、音乐、文本、游戏数据和商标权利归各自权利人所有。

## PalResearch

存档页使用的中文地点目录依据 PalResearch 的 `PalScript/SceneID.txt` 整理，只保存场景编号与地点名称的研究对照，不复制原版资源。

- 仓库：<https://github.com/palxex/palresearch>
- 参考提交：`dc4b063ffc0029a1e0046da738f0e65a6daa9c50`
- 原始研究资料及作者鸣谢见该仓库的 `AUTHORS.txt`
