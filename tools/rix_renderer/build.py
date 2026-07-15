#!/usr/bin/env python3
"""Build the offline RIX renderer against the separate pinned SDLPal checkout.

Copyright (C) 2026 sword-godot contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
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
    command = [
        "clang++", "-std=c++17", "-O2", "-include", str(root / "compat.h"),
        "-I", str(upstream), "-I", str(upstream / "adplug"),
        *(str(source) for source in sources), "-o", str(args.output),
    ]
    subprocess.run(command, check=True)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

