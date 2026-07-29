#!/usr/bin/env python3
"""Validate a private `pal-sprite-atlas.json` without reading image pixels."""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Any


SCHEMA_VERSION = "1.0.0"


def fail(message: str) -> None:
    raise ValueError(message)


def exact_keys(value: dict[str, Any], required: set[str], location: str) -> None:
    missing = sorted(required - value.keys())
    unknown = sorted(value.keys() - required)
    if missing or unknown:
        fail(f"{location}: missing={missing}, unknown={unknown}")


def integer(value: Any, location: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        fail(f"{location}: expected integer >= {minimum}")
    return value


def int_array(value: Any, length: int, location: str) -> list[int]:
    if not isinstance(value, list) or len(value) != length:
        fail(f"{location}: expected {length} integers")
    return [integer(item, f"{location}[{index}]") for index, item in enumerate(value)]


def safe_png(value: Any, location: str) -> str:
    if not isinstance(value, str) or not value.lower().endswith(".png") or "\\" in value:
        fail(f"{location}: expected a relative PNG path")
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts:
        fail(f"{location}: unsafe path")
    return value


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        fail(f"image is not a valid PNG: {path}")
    return struct.unpack(">II", header[16:24])


def validate(path: Path, expected_sprite: int | None, expected_frames: int | None) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        fail("manifest: expected an object")
    fields = {"schema_version", "source_sprite_number", "source_frame_count", "scale", "image", "canvas_size", "frames"}
    exact_keys(data, fields, "manifest")
    if data["schema_version"] != SCHEMA_VERSION or data["scale"] != 5:
        fail("manifest: schema_version must be 1.0.0 and scale must be 5")
    sprite_number = integer(data["source_sprite_number"], "source_sprite_number", 1)
    frame_count = integer(data["source_frame_count"], "source_frame_count", 1)
    if expected_sprite is not None and sprite_number != expected_sprite:
        fail(f"source_sprite_number: expected {expected_sprite}, got {sprite_number}")
    if expected_frames is not None and frame_count != expected_frames:
        fail(f"source_frame_count: expected {expected_frames}, got {frame_count}")
    canvas = int_array(data["canvas_size"], 2, "canvas_size")
    if min(canvas) < 1:
        fail("canvas_size: dimensions must be positive")
    relative_image = safe_png(data["image"], "image")
    image_path = path.parent / relative_image
    width, height = png_size(image_path)
    frames = data["frames"]
    if not isinstance(frames, list) or len(frames) != frame_count:
        fail(f"frames: expected exactly {frame_count} entries")
    seen: set[int] = set()
    frame_fields = {"source_frame_index", "rect", "pivot", "alpha_bounds", "duration_ms"}
    for position, frame in enumerate(frames):
        if not isinstance(frame, dict):
            fail(f"frames[{position}]: expected an object")
        exact_keys(frame, frame_fields, f"frames[{position}]")
        index = integer(frame["source_frame_index"], f"frames[{position}].source_frame_index")
        if index >= frame_count or index in seen:
            fail(f"frames[{position}].source_frame_index: duplicate or out of range")
        seen.add(index)
        rect = int_array(frame["rect"], 4, f"frames[{position}].rect")
        if rect[2:] != canvas or rect[0] + rect[2] > width or rect[1] + rect[3] > height:
            fail(f"frames[{position}].rect: must use the shared canvas inside the PNG")
        pivot = int_array(frame["pivot"], 2, f"frames[{position}].pivot")
        if pivot[0] > canvas[0] or pivot[1] > canvas[1]:
            fail(f"frames[{position}].pivot: outside canvas")
        bounds = int_array(frame["alpha_bounds"], 4, f"frames[{position}].alpha_bounds")
        if min(bounds[2:]) < 1 or bounds[0] + bounds[2] > canvas[0] or bounds[1] + bounds[3] > canvas[1]:
            fail(f"frames[{position}].alpha_bounds: outside canvas")
        duration = integer(frame["duration_ms"], f"frames[{position}].duration_ms", 1)
        if duration > 5000:
            fail(f"frames[{position}].duration_ms: must not exceed 5000")
    if seen != set(range(frame_count)):
        fail("frames: source frame mapping is incomplete")
    print(f"PASS: sprite {sprite_number} atlas maps {frame_count} source frames ({width}x{height})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--expected-sprite", type=int)
    parser.add_argument("--expected-frame-count", type=int)
    args = parser.parse_args()
    try:
        return validate(args.atlas, args.expected_sprite, args.expected_frame_count)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
