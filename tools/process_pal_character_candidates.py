#!/usr/bin/env python3
"""Use the locked Sprite Video Lab chroma-key implementation on 2DCS frames."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "1.0.0"
FRAME_PATTERN = re.compile(r"^frame_(\d{3})_.*\.png$", re.IGNORECASE)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_sprite_video_lab(root: Path) -> Any:
    server_path = root / "server.py"
    if not server_path.is_file():
        raise ValueError(f"Sprite Video Lab server.py is missing: {server_path}")
    spec = importlib.util.spec_from_file_location("sword_sprite_video_lab", server_path)
    if spec is None or spec.loader is None:
        raise ValueError(f"cannot load Sprite Video Lab: {server_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    for name in (
        "chroma_key_frame",
        "auto_key_color",
        "despill_alpha_edges",
        "enforce_hard_alpha",
        "green_desaturate_image",
        "Image",
        "ImageFilter",
    ):
        if not hasattr(module, name):
            raise ValueError(f"Sprite Video Lab is missing {name}")
    return module


def git_commit(root: Path) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def alpha_bounds(image: Any) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("chroma key removed the complete character")
    left, top, right, bottom = bounds
    return left, top, right - left, bottom - top


def image_data(image: Any) -> Any:
    flattened = getattr(image, "get_flattened_data", None)
    if flattened is not None:
        return flattened()
    return image.getdata()


def residual_green_pixels(image: Any, threshold: int, dominance: int) -> int:
    count = 0
    for red, green, blue, alpha in image_data(image.convert("RGBA")):
        if alpha > 0 and green >= threshold and green - max(red, blue) >= dominance:
            count += 1
    return count


def neutralize_green_edge_spill(
    image: Any,
    edge_width: int,
    threshold: int,
    dominance: int,
    image_module: Any,
    image_filter: Any,
) -> tuple[Any, int]:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if edge_width <= 0:
        return rgba, 0
    inner = alpha.filter(image_filter.MinFilter((edge_width * 2) + 1))
    output_pixels: list[tuple[int, int, int, int]] = []
    changed = 0
    for (red, green, blue, alpha_value), inner_alpha in zip(
        image_data(rgba), image_data(inner)
    ):
        green_excess = green - max(red, blue)
        if (
            alpha_value > 0
            and inner_alpha == 0
            and green >= threshold
            and green_excess >= dominance
        ):
            green = round((red + blue) / 2)
            changed += 1
        output_pixels.append((red, green, blue, alpha_value))
    cleaned = image_module.new("RGBA", rgba.size)
    cleaned.putdata(output_pixels)
    return cleaned, changed


def residual_green_edge_pixels(
    image: Any,
    edge_width: int,
    threshold: int,
    dominance: int,
    image_filter: Any,
) -> int:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if edge_width <= 0:
        return 0
    inner = alpha.filter(image_filter.MinFilter((edge_width * 2) + 1))
    count = 0
    for (red, green, blue, alpha_value), inner_alpha in zip(
        image_data(rgba), image_data(inner)
    ):
        if (
            alpha_value > 0
            and inner_alpha == 0
            and green >= threshold
            and green - max(red, blue) >= dominance
        ):
            count += 1
    return count


def process(args: argparse.Namespace) -> int:
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    if not input_dir.is_dir():
        raise ValueError(f"input directory is missing: {input_dir}")
    if output_dir.exists():
        raise ValueError(f"refusing to overwrite output directory: {output_dir}")
    candidates: list[tuple[int, Path]] = []
    for path in sorted(input_dir.glob("*.png")):
        match = FRAME_PATTERN.match(path.name)
        if match is not None:
            candidates.append((int(match.group(1)), path))
    if not candidates:
        raise ValueError("input directory contains no frame_NNN PNG candidates")
    frame_indices = [frame_index for frame_index, _path in candidates]
    if len(frame_indices) != len(set(frame_indices)):
        raise ValueError("input directory contains duplicate source frame indices")

    svl = load_sprite_video_lab(args.sprite_video_lab.resolve())
    output_dir.mkdir(parents=True)
    records: list[dict[str, Any]] = []
    for frame_index, source_path in candidates:
        source = svl.Image.open(source_path).convert("RGBA")
        key_rgb = tuple(int(value) for value in svl.auto_key_color(source))
        keyed = svl.chroma_key_frame(
            source,
            key_rgb,
            threshold=args.threshold,
            softness=0,
            despill_strength=args.despill,
            halo_pixels=0,
        )
        keyed = svl.despill_alpha_edges(keyed, key_rgb, args.despill)
        keyed, desaturated = svl.green_desaturate_image(
            keyed,
            threshold=args.green_threshold,
            dominance=args.green_dominance,
            alpha_floor=1,
        )
        keyed = svl.enforce_hard_alpha(keyed, cutoff=128)
        keyed, neutralized_edge_green = neutralize_green_edge_spill(
            keyed,
            edge_width=args.edge_width,
            threshold=args.edge_green_threshold,
            dominance=args.edge_green_dominance,
            image_module=svl.Image,
            image_filter=svl.ImageFilter,
        )
        residue = residual_green_pixels(keyed, args.green_threshold, args.green_dominance)
        if residue > args.max_green_pixels:
            raise ValueError(f"frame {frame_index:03d} retains {residue} visible green pixels")
        edge_residue = residual_green_edge_pixels(
            keyed,
            edge_width=args.edge_width,
            threshold=args.edge_green_threshold,
            dominance=args.edge_green_dominance,
            image_filter=svl.ImageFilter,
        )
        if edge_residue > args.max_edge_green_pixels:
            raise ValueError(
                f"frame {frame_index:03d} retains {edge_residue} dark green edge pixels"
            )
        bounds = alpha_bounds(keyed)
        if (
            bounds[0] == 0
            or bounds[1] == 0
            or bounds[0] + bounds[2] == keyed.width
            or bounds[1] + bounds[3] == keyed.height
        ):
            raise ValueError(f"frame {frame_index:03d} alpha touches the canvas border: {bounds}")
        output_path = output_dir / f"frame_{frame_index:03d}_transparent.png"
        keyed.save(output_path, format="PNG")
        records.append(
            {
                "source_frame_index": frame_index,
                "source_path": source_path.name,
                "source_sha256": sha256_file(source_path),
                "output_path": output_path.name,
                "output_sha256": sha256_file(output_path),
                "canvas_size": [keyed.width, keyed.height],
                "sampled_key_rgb": list(key_rgb),
                "alpha_bounds": list(bounds),
                "desaturated_green_pixels": desaturated,
                "neutralized_edge_green_pixels": neutralized_edge_green,
                "residual_green_pixels": residue,
                "residual_edge_green_pixels": edge_residue,
            }
        )
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "tool": "sprite-video-lab",
        "tool_commit": git_commit(args.sprite_video_lab.resolve()),
        "mode": "chroma_key_hard_alpha",
        "settings": {
            "key_color": "#00FF00",
            "threshold": args.threshold,
            "softness": 0,
            "despill_strength": args.despill,
            "halo_pixels": 0,
            "alpha_cutoff": 128,
            "green_desaturate_threshold": args.green_threshold,
            "green_desaturate_dominance": args.green_dominance,
            "max_green_pixels": args.max_green_pixels,
            "edge_cleanup_width": args.edge_width,
            "edge_green_threshold": args.edge_green_threshold,
            "edge_green_dominance": args.edge_green_dominance,
            "max_edge_green_pixels": args.max_edge_green_pixels,
        },
        "frames": records,
    }
    (output_dir / "processed-frames.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"PASS: Sprite Video Lab processed {len(records)} character frames: {output_dir}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--sprite-video-lab", type=Path, required=True)
    parser.add_argument("--threshold", type=int, default=42)
    parser.add_argument("--despill", type=float, default=1.6)
    parser.add_argument("--green-threshold", type=int, default=42)
    parser.add_argument("--green-dominance", type=int, default=24)
    parser.add_argument("--max-green-pixels", type=int, default=0)
    parser.add_argument("--edge-width", type=int, default=3)
    parser.add_argument("--edge-green-threshold", type=int, default=2)
    parser.add_argument("--edge-green-dominance", type=int, default=2)
    parser.add_argument("--max-edge-green-pixels", type=int, default=0)
    args = parser.parse_args()
    try:
        if not 0 <= args.threshold <= 255:
            raise ValueError("threshold must be between 0 and 255")
        if not 0.0 <= args.despill <= 2.5:
            raise ValueError("despill must be between 0 and 2.5")
        if not 0 <= args.green_threshold <= 255 or not 0 <= args.green_dominance <= 255:
            raise ValueError("green threshold and dominance must be between 0 and 255")
        if args.max_green_pixels < 0:
            raise ValueError("max-green-pixels must not be negative")
        if not 0 <= args.edge_width <= 32:
            raise ValueError("edge-width must be between 0 and 32")
        if not 0 <= args.edge_green_threshold <= 255:
            raise ValueError("edge-green-threshold must be between 0 and 255")
        if not 0 <= args.edge_green_dominance <= 255:
            raise ValueError("edge-green-dominance must be between 0 and 255")
        if args.max_edge_green_pixels < 0:
            raise ValueError("max-edge-green-pixels must not be negative")
        return process(args)
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
