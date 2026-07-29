#!/usr/bin/env python3
"""Verify the locally installed, version-locked 2D remaster art tools."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = ROOT / "remaster-toolchain.lock.json"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_local_path(value: str) -> Path:
    expanded = Path(value).expanduser()
    return expanded if expanded.is_absolute() else (ROOT / expanded).resolve()


def verify_git_checkout(tool: dict[str, object], path: Path) -> list[str]:
    failures: list[str] = []
    if not (path / ".git").exists():
        return [f"{tool['id']}: Git checkout not found at {path}"]
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    expected = str(tool["commit"])
    actual = result.stdout.strip()
    if result.returncode != 0 or actual != expected:
        failures.append(f"{tool['id']}: expected Git commit {expected}, got {actual or 'unreadable'}")
    runtime = tool.get("runtime", {})
    if isinstance(runtime, dict):
        entrypoint = runtime.get("entrypoint")
        if isinstance(entrypoint, str) and not (path / entrypoint).is_file():
            failures.append(f"{tool['id']}: missing entrypoint {entrypoint}")
        environment = runtime.get("environment")
        if isinstance(environment, str) and not (path / environment).is_dir():
            failures.append(f"{tool['id']}: missing isolated environment {environment}")
    return failures


def verify_skill(tool: dict[str, object], path: Path) -> list[str]:
    failures: list[str] = []
    files = tool.get("files", {})
    if not isinstance(files, dict):
        return [f"{tool['id']}: files must be an object"]
    for relative, expected in files.items():
        target = path / str(relative)
        if not target.is_file():
            failures.append(f"{tool['id']}: missing {relative} at {path}")
        elif sha256_file(target) != expected:
            failures.append(f"{tool['id']}: SHA-256 mismatch for {relative}")
    return failures


def main() -> int:
    data = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    failures: list[str] = []
    tools = data.get("tools", [])
    if not isinstance(tools, list):
        print("FAIL: tools must be an array", file=sys.stderr)
        return 1
    for raw_tool in tools:
        if not isinstance(raw_tool, dict):
            failures.append("tool entry must be an object")
            continue
        path = resolve_local_path(str(raw_tool.get("local_path", "")))
        kind = raw_tool.get("kind")
        if kind == "git_checkout":
            failures.extend(verify_git_checkout(raw_tool, path))
        elif kind == "codex_skill":
            failures.extend(verify_skill(raw_tool, path))
        else:
            failures.append(f"{raw_tool.get('id', 'unknown')}: unsupported kind {kind}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print(f"PASS: {len(tools)} remaster tools match remaster-toolchain.lock.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
