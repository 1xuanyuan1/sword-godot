#!/usr/bin/env python3
"""Fail when public source or export settings can leak private remaster data."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_ROOTS = {"Data", "data", "local_data", "generated", "sword-assets"}
FORBIDDEN_FILES = {".env.local"}
PRIVATE_BINARY_SUFFIXES = {".mkf", ".rpg", ".mp3", ".ogg", ".wav", ".glb", ".gltf"}
PRIVATE_KEY_HEADER = "-----BEGIN " + "PRIVATE KEY-----"
SECRET_VARIABLES = ("MINIMAX_" + "API_KEY", "TRIPO_" + "API_KEY")


def git_candidates() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
    return [ROOT / os.fsdecode(raw) for raw in result.stdout.split(b"\0") if raw]


def check_paths(paths: list[Path]) -> list[str]:
    failures: list[str] = []
    for path in paths:
        relative = path.relative_to(ROOT)
        if relative.name in FORBIDDEN_FILES or (relative.parts and relative.parts[0] in FORBIDDEN_ROOTS):
            failures.append(f"private path would enter public Git: {relative}")
        if path.suffix.lower() in PRIVATE_BINARY_SUFFIXES:
            failures.append(f"private/generated binary would enter public Git: {relative}")
    return failures


def check_text(paths: list[Path]) -> list[str]:
    failures: list[str] = []
    assignment = re.compile(
        rf"(?:{'|'.join(map(re.escape, SECRET_VARIABLES))})\s*=\s*['\"]?([^\s#'\"]{{12,}})"
    )
    for path in paths:
        if not path.is_file() or path.stat().st_size > 2 * 1024 * 1024:
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        relative = path.relative_to(ROOT)
        if PRIVATE_KEY_HEADER in content:
            failures.append(f"private-key material detected: {relative}")
        if assignment.search(content):
            failures.append(f"API credential assignment detected: {relative}")
    return failures


def check_export_presets() -> list[str]:
    path = ROOT / "export_presets.cfg"
    if not path.is_file():
        return ["export_presets.cfg is missing"]
    failures: list[str] = []
    preset_name = "unnamed"
    preset_count = 0
    exclude_count = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("[preset.") and not line.endswith(".options]"):
            preset_count += 1
            preset_name = line
        elif line.startswith('name="'):
            preset_name = line.removeprefix('name="').removesuffix('"')
        elif line.startswith("exclude_filter="):
            exclude_count += 1
            if "sword-assets/*" not in line or "sword-assets/**/*" not in line:
                failures.append(f"export preset {preset_name} does not exclude sword-assets recursively")
    if exclude_count != preset_count:
        failures.append(f"expected one exclude_filter for each of {preset_count} export presets, found {exclude_count}")
    return failures


def check_local_guards() -> list[str]:
    failures: list[str] = []
    probes = ["sword-assets/.public-release-probe", ".env.local"]
    result = subprocess.run(
        ["git", "check-ignore", "--no-index", "--stdin"],
        cwd=ROOT,
        input="\n".join(probes) + "\n",
        text=True,
        stdout=subprocess.PIPE,
    )
    ignored = set(result.stdout.splitlines())
    for probe in probes:
        if probe not in ignored:
            failures.append(f".gitignore does not protect {probe}")
    env_path = ROOT / ".env.local"
    if env_path.exists() and env_path.stat().st_mode & 0o077:
        failures.append(".env.local permissions must be 600")
    return failures


def main() -> int:
    try:
        paths = git_candidates()
        failures = check_paths(paths) + check_text(paths) + check_export_presets() + check_local_guards()
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"FAIL: release scan could not run: {exc}", file=sys.stderr)
        return 1
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print(f"PASS: public release scan ({len(paths)} source paths, private assets and credentials excluded)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
