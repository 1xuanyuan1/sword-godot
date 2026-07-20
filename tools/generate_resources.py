#!/usr/bin/env python3
"""Generate local runtime resources from a legally obtained PAL Data directory.

Copyright (C) 2026 sword-godot contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Set


REQUIRED_DATA_FILES = {
    "abc.mkf", "ball.mkf", "data.mkf", "f.mkf", "fbp.mkf", "fire.mkf",
    "gop.mkf", "map.mkf", "mgo.mkf", "mus.mkf", "pat.mkf", "rgm.mkf",
    "rng.mkf", "sss.mkf", "voc.mkf", "m.msg", "word.dat", "wor16.fon",
    "wor16.asc",
}
DEFAULT_SDLPAL_REPOSITORY = "https://github.com/sdlpal/sdlpal.git"


class GenerationError(RuntimeError):
    """A user-actionable resource generation error."""


def _normalized_path(value: str) -> Path:
    return Path(value.strip().strip('"')).expanduser().resolve()


def _casefolded_file_names(path: Path) -> Set[str]:
    if not path.is_dir():
        return set()
    try:
        return {entry.name.casefold() for entry in path.iterdir() if entry.is_file()}
    except OSError:
        return set()


def _is_data_directory(path: Path) -> bool:
    return REQUIRED_DATA_FILES <= _casefolded_file_names(path)


def _data_variants(path: Path) -> Iterable[Path]:
    yield path
    yield path / "Data"
    yield path / "data"


def find_data_directory(project_root: Path, requested: Optional[str]) -> Path:
    """Resolve original game Data without treating an SDLPal checkout as game data."""
    explicit = requested or os.environ.get("PAL_DATA_DIR")
    if explicit:
        base = _normalized_path(explicit)
        for candidate in _data_variants(base):
            if _is_data_directory(candidate):
                return candidate.resolve()
        missing = sorted(REQUIRED_DATA_FILES - _casefolded_file_names(base))
        detail = ", ".join(missing[:5])
        if len(missing) > 5:
            detail += " ..."
        raise GenerationError(
            f"找不到有效的 PAL Data 目录：{base}\n"
            f"可以传入 Data 本身或包含 Data 的 SDLPal/游戏目录。缺少：{detail or '必需文件'}"
        )

    candidates = [project_root / "Data", project_root / "data"]
    for candidate in candidates:
        if _is_data_directory(candidate):
            return candidate.resolve()
    raise GenerationError(
        "没有找到本机原版 PAL Data。官方 SDLPal 仓库不包含原版资源；"
        "请把合法取得的 Data 放在本项目内，或显式传入 Data 路径。"
    )


def _resolve_executable(value: str) -> Optional[Path]:
    unquoted = value.strip().strip('"')
    direct = Path(unquoted).expanduser()
    if direct.is_file():
        return direct.resolve()
    discovered = shutil.which(unquoted)
    return Path(discovered).resolve() if discovered else None


def find_godot(requested: Optional[str]) -> Path:
    """Find Godot from an argument, GODOT_BIN, PATH, or standard macOS path."""
    explicit = requested or os.environ.get("GODOT_BIN")
    if explicit:
        executable = _resolve_executable(explicit)
        if executable:
            return executable
        raise GenerationError(f"找不到 Godot 可执行文件：{explicit}")

    command_names = (
        ("godot4.7.exe", "godot4.exe", "godot.exe")
        if os.name == "nt"
        else ("godot4.7", "godot4", "godot")
    )
    for command_name in command_names:
        executable = _resolve_executable(command_name)
        if executable:
            return executable

    if sys.platform == "darwin":
        application = Path("/Applications/Godot.app/Contents/MacOS/Godot")
        if application.is_file():
            return application
    raise GenerationError(
        "找不到 Godot 4.7。请将 Godot 加入 PATH，或设置 GODOT_BIN 指向可执行文件。"
    )


def find_git(requested: Optional[str]) -> Path:
    explicit = requested or os.environ.get("GIT_BIN")
    if explicit:
        executable = _resolve_executable(explicit)
        if executable:
            return executable
        raise GenerationError(f"找不到 Git 可执行文件：{explicit}")
    executable = _resolve_executable("git.exe" if os.name == "nt" else "git")
    if executable:
        return executable
    raise GenerationError("找不到 Git；首次运行需要 Git 来克隆官方 SDLPal 源码。")


def _is_sdlpal_source(path: Path) -> bool:
    return (path / "adplug" / "rix.cpp").is_file()


def sdlpal_target(project_root: Path, requested: Optional[str]) -> Path:
    configured = requested or os.environ.get("SDLPAL_DIR")
    return (
        _normalized_path(configured)
        if configured
        else (project_root.parent / "sdlpal-official").resolve()
    )


def _display_command(command: List[str]) -> str:
    return subprocess.list2cmdline(command) if os.name == "nt" else shlex.join(command)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="从本机合法取得的 PAL Data 一键生成 generated/pal 运行资源。"
    )
    parser.add_argument(
        "source",
        nargs="?",
        help="原版 Data 目录，或包含 Data 的游戏目录；省略时使用项目内 Data/",
    )
    parser.add_argument("--godot", help="Godot 4.7 可执行文件；也可设置 GODOT_BIN")
    parser.add_argument(
        "--sdlpal",
        help="SDLPal 源码目录/克隆目标（默认：相邻 sdlpal-official）；也可设置 SDLPAL_DIR",
    )
    parser.add_argument(
        "--repository",
        default=DEFAULT_SDLPAL_REPOSITORY,
        help=f"首次运行克隆的 SDLPal 仓库（默认：{DEFAULT_SDLPAL_REPOSITORY}）",
    )
    parser.add_argument("--git", help="Git 可执行文件；也可设置 GIT_BIN")
    parser.add_argument(
        "--output",
        default="res://generated/pal",
        help="Godot 输出路径（默认：res://generated/pal）",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="只显示解析结果和将执行的命令"
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    project_root = Path(__file__).resolve().parent.parent
    try:
        data_directory = find_data_directory(project_root, args.source)
        godot = find_godot(args.godot)
        sdlpal = sdlpal_target(project_root, args.sdlpal)
        clone_command: Optional[List[str]] = None
        if sdlpal.exists():
            if not _is_sdlpal_source(sdlpal):
                raise GenerationError(
                    f"相邻 SDLPal 目录无效（缺少 adplug/rix.cpp）：{sdlpal}"
                )
        else:
            git = find_git(args.git)
            clone_command = [
                str(git), "clone", "--depth", "1", args.repository, str(sdlpal)
            ]
    except GenerationError as error:
        print(f"错误：{error}", file=sys.stderr)
        return 2

    command = [
        str(godot),
        "--headless",
        "--path",
        str(project_root),
        "--script",
        "res://tools/import_cli.gd",
        "--",
        "--source",
        str(data_directory),
        "--output",
        args.output,
    ]
    environment = os.environ.copy()
    environment["SDLPAL_DIR"] = str(sdlpal)

    print(f"PAL Data：{data_directory}", flush=True)
    print(f"Godot：{godot}", flush=True)
    print(f"SDLPal 源码：{sdlpal}", flush=True)
    if clone_command:
        print(f"克隆：{_display_command(clone_command)}", flush=True)
    print(f"执行：{_display_command(command)}", flush=True)
    if args.dry_run:
        return 0

    if clone_command:
        try:
            sdlpal.parent.mkdir(parents=True, exist_ok=True)
            cloned = subprocess.run(clone_command, cwd=sdlpal.parent, check=False)
        except OSError as error:
            print(f"错误：无法启动 Git：{error}", file=sys.stderr)
            return 2
        if cloned.returncode != 0:
            print(f"错误：SDLPal 克隆失败，退出码 {cloned.returncode}", file=sys.stderr)
            return cloned.returncode
        if not _is_sdlpal_source(sdlpal):
            print(f"错误：克隆结果缺少 adplug/rix.cpp：{sdlpal}", file=sys.stderr)
            return 2

    try:
        completed = subprocess.run(command, cwd=project_root, env=environment, check=False)
    except OSError as error:
        print(f"错误：无法启动 Godot：{error}", file=sys.stderr)
        return 2
    if completed.returncode == 0:
        print(f"完成：资源已生成到 {args.output}")
    else:
        print(f"失败：Godot 导入器退出码 {completed.returncode}", file=sys.stderr)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
