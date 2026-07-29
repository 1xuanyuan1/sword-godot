#!/usr/bin/env python3
"""Validate a private `pal-map-tileset.json` and referenced-frame coverage."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Any


SCHEMA_VERSION = "1.0.0"


def fail(message: str) -> None:
    raise ValueError(message)


def exact_keys(value: dict[str, Any], allowed: set[str], required: set[str], location: str) -> None:
    missing = sorted(required - value.keys())
    unknown = sorted(value.keys() - allowed)
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


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(path: Path, expected_map: int | None, expected_frames: int | None, required_frames: set[int]) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        fail("manifest: expected an object")
    required = {"schema_version", "map_number", "source_frame_count", "scale", "tile_cell_px", "content_px", "image", "image_sha256", "frames"}
    exact_keys(data, required | {"night_image", "night_image_sha256"}, required, "manifest")
    if data["schema_version"] != SCHEMA_VERSION or data["scale"] != 5:
        fail("manifest: schema_version must be 1.0.0 and scale must be 5")
    map_number = integer(data["map_number"], "map_number")
    frame_count = integer(data["source_frame_count"], "source_frame_count", 1)
    if expected_map is not None and map_number != expected_map:
        fail(f"map_number: expected {expected_map}, got {map_number}")
    if expected_frames is not None and frame_count != expected_frames:
        fail(f"source_frame_count: expected {expected_frames}, got {frame_count}")
    if int_array(data["tile_cell_px"], 2, "tile_cell_px") != [160, 80] or int_array(data["content_px"], 2, "content_px") != [160, 75]:
        fail("manifest: tile_cell_px must be [160,80] and content_px must be [160,75]")
    image_path = path.parent / safe_png(data["image"], "image")
    if not isinstance(data["image_sha256"], str) or data["image_sha256"] != sha256_file(image_path):
        fail("image_sha256: does not match image")
    image_size = png_size(image_path)
    if data.get("night_image") is not None:
        night_path = path.parent / safe_png(data["night_image"], "night_image")
        if not isinstance(data.get("night_image_sha256"), str) or data["night_image_sha256"] != sha256_file(night_path):
            fail("night_image_sha256: does not match night_image")
        if png_size(night_path) != image_size:
            fail("night_image: dimensions do not match image")
    elif data.get("night_image_sha256") is not None:
        fail("night_image_sha256: requires night_image")
    frames = data["frames"]
    if not isinstance(frames, list) or not frames:
        fail("frames: expected a non-empty array")
    seen: set[int] = set()
    for position, frame in enumerate(frames):
        if not isinstance(frame, dict):
            fail(f"frames[{position}]: expected an object")
        exact_keys(frame, {"source_frame_index", "rect"}, {"source_frame_index", "rect"}, f"frames[{position}]")
        index = integer(frame["source_frame_index"], f"frames[{position}].source_frame_index")
        if index >= frame_count or index in seen:
            fail(f"frames[{position}].source_frame_index: duplicate or out of range")
        seen.add(index)
        rect = int_array(frame["rect"], 4, f"frames[{position}].rect")
        if rect[2:] != [160, 80] or rect[0] + 160 > image_size[0] or rect[1] + 80 > image_size[1]:
            fail(f"frames[{position}].rect: must be a 160x80 region inside the PNG")
    missing = sorted(required_frames - seen)
    if missing:
        fail(f"frames: missing referenced GOP frames {missing}")
    print(f"PASS: map {map_number:03d} tileset provides {len(seen)} frames ({image_size[0]}x{image_size[1]})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tileset", type=Path, required=True)
    parser.add_argument("--expected-map", type=int)
    parser.add_argument("--expected-frame-count", type=int)
    parser.add_argument("--required-frames", default="", help="comma-separated GOP frame indices")
    args = parser.parse_args()
    try:
        required = {int(value) for value in args.required_frames.split(",") if value.strip()}
        return validate(args.tileset, args.expected_map, args.expected_frame_count, required)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
