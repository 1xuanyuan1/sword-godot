#!/usr/bin/env python3
"""检查 Sword Godot 的中文模块说明、公开 GDScript API 注释和文档链接。"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def previous_content_line(lines: list[str], index: int) -> str:
    index -= 1
    while index >= 0 and not lines[index].strip():
        index -= 1
    return lines[index].lstrip() if index >= 0 else ""


def check_gdscript() -> list[str]:
    failures: list[str] = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        lines = path.read_text(encoding="utf-8").splitlines()
        relative = path.relative_to(ROOT)
        if "##" not in "\n".join(lines[:10]):
            failures.append(f"{relative}: 文件头缺少中文模块说明")
        for index, line in enumerate(lines):
            stripped = line.lstrip()
            requires_doc = stripped.startswith(("class_name ", "signal "))
            if stripped.startswith(("func ", "static func ")):
                function_name = stripped.split("func ", 1)[1].split("(", 1)[0]
                requires_doc = not function_name.startswith("_")
            if requires_doc and not previous_content_line(lines, index).startswith("##"):
                failures.append(f"{relative}:{index + 1}: 公开声明前缺少 ## 注释：{stripped}")
    return failures


def check_markdown_links() -> list[str]:
    failures: list[str] = []
    for path in sorted((ROOT / "docs").glob("*.md")):
        for target in re.findall(r"\[[^]]+\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            if "://" in target or target.startswith("#"):
                continue
            linked_path = (path.parent / target.split("#", 1)[0]).resolve()
            if not linked_path.exists():
                failures.append(f"{path.relative_to(ROOT)}: 无效链接 {target}")
    return failures


def check_architecture_index() -> list[str]:
    failures: list[str] = []
    project_structure = (ROOT / "docs/PROJECT_STRUCTURE.md").read_text(encoding="utf-8")
    architecture = (ROOT / "docs/ARCHITECTURE.md").read_text(encoding="utf-8")
    for module in ["src/content", "src/formats", "src/game", "src/import", "src/ui", "src/world"]:
        if module not in project_structure:
            failures.append(f"docs/PROJECT_STRUCTURE.md: 缺少核心模块 {module}")
    for component in ["PalDataImporter", "PalContentDatabase", "GameSession", "ScriptVM", "PalTileMapWorld"]:
        if component not in architecture:
            failures.append(f"docs/ARCHITECTURE.md: 缺少核心组件 {component}")
    return failures


def main() -> int:
    failures = check_gdscript() + check_markdown_links() + check_architecture_index()
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: GDScript 公开 API 注释、中文文档索引与内部链接")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
