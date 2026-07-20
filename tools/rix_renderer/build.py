#!/usr/bin/env python3
"""Build the offline RIX renderer against the separate pinned SDLPal checkout.

Copyright (C) 2026 sword-godot contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional


def find_compiler(requested: Optional[str]) -> str:
    candidates = [requested, os.environ.get("CXX"), "clang++", "g++", "c++"]
    if os.name == "nt":
        candidates.append("cl")
    for candidate in candidates:
        if not candidate:
            continue
        discovered = shutil.which(candidate)
        if discovered:
            return discovered
    raise SystemExit(
        "no C++17 compiler found; install LLVM/Visual Studio Build Tools "
        "or set CXX to the compiler path"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compiler")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    upstream = args.upstream.resolve()
    if not (upstream / "adplug" / "rix.cpp").exists():
        raise SystemExit(f"invalid SDLPal checkout: {upstream}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sources = [
        root / "main.cpp",
        upstream / "adplug" / "binfile.cpp",
        upstream / "adplug" / "binio.cpp",
        upstream / "adplug" / "fprovide.cpp",
        upstream / "adplug" / "player.cpp",
        upstream / "adplug" / "rix.cpp",
        upstream / "adplug" / "mame_opls.cpp",
    ]
    compiler = find_compiler(args.compiler)
    compiler_name = Path(compiler).name.casefold()
    if compiler_name in {"cl", "cl.exe"}:
        command = [
            compiler, "/nologo", "/std:c++17", "/O2",
            f"/FI{root / 'compat.h'}", f"/I{upstream}",
            f"/I{upstream / 'adplug'}", *(str(source) for source in sources),
            f"/Fe:{args.output}",
        ]
    else:
        command = [
            compiler, "-std=c++17", "-O2", "-include", str(root / "compat.h"),
            "-I", str(upstream), "-I", str(upstream / "adplug"),
            *(str(source) for source in sources), "-o", str(args.output),
        ]
    subprocess.run(command, check=True)
    print(f"{args.output} ({Path(compiler).name}, {sys.platform})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
