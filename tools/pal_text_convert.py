#!/usr/bin/env python3
"""Convert legally supplied DOS PAL text/font data into ignored local artifacts.

Copyright (C) 2026 sword-godot contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path


def _encoding_penalty(text: str) -> int:
    penalty = 0
    for char in text:
        codepoint = ord(char)
        if 0xE000 <= codepoint <= 0xF8FF:
            penalty += 20
        elif char == "\ufffd":
            penalty += 100
        elif codepoint < 0x20 and char not in "\r\n\t\0":
            penalty += 5
    return penalty


def detect_encoding(sample: bytes) -> str:
    candidates: list[tuple[int, str]] = []
    for encoding in ("cp950", "gb18030"):
        try:
            decoded = sample.decode(encoding)
        except UnicodeDecodeError:
            continue
        candidates.append((_encoding_penalty(decoded), encoding))
    if not candidates:
        raise ValueError("resource text is neither CP950/Big5 nor GB18030/GBK")
    return min(candidates)[1]


def decode_words(data: bytes, encoding: str, record_size: int = 10) -> list[str]:
    words: list[str] = []
    for offset in range(0, len(data), record_size):
        record = data[offset : offset + record_size].rstrip(b" \0")
        word = record.decode(encoding, errors="replace").rstrip("\0")
        if word.endswith("1"):
            word = word[:-1]
        words.append(word)
    return words


def decode_messages(message_data: bytes, offset_data: bytes, encoding: str) -> list[str]:
    if len(offset_data) % 4:
        raise ValueError("message offset table is not uint32-aligned")
    offsets = list(struct.unpack(f"<{len(offset_data) // 4}I", offset_data))
    if len(offsets) < 2 or offsets != sorted(offsets) or offsets[-1] > len(message_data):
        raise ValueError("message offset table is invalid")
    return [
        message_data[offsets[index] : offsets[index + 1]].decode(encoding, errors="replace").rstrip("\0")
        for index in range(len(offsets) - 1)
    ]


def decode_object_descriptions(data: bytes, encoding: str) -> dict[str, str]:
    descriptions: dict[str, str] = {}
    for line in data.decode(encoding, errors="replace").splitlines():
        if "=" not in line:
            continue
        key, description = line.split("=", 1)
        object_id = key.split("(", 1)[0].strip()
        try:
            descriptions[str(int(object_id, 16))] = description.strip()
        except ValueError:
            continue
    return descriptions


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_rgba_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    if len(pixels) != width * height * 4:
        raise ValueError("RGBA pixel buffer has the wrong size")
    scanlines = b"".join(b"\0" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _png_chunk(b"IDAT", zlib.compress(scanlines, 9))
    png += _png_chunk(b"IEND", b"")
    path.write_bytes(png)


def convert_font(font_data: bytes, character_data: bytes, encoding: str, output_dir: Path) -> dict[str, object]:
    characters = list(character_data.decode(encoding, errors="replace"))
    glyph_data = font_data[0x682:]
    glyph_count = min(len(characters), len(glyph_data) // 30)
    columns = 32
    cell_width = 16
    cell_height = 16
    rows = (glyph_count + columns - 1) // columns
    width = columns * cell_width
    height = max(1, rows * cell_height)
    pixels = bytearray(width * height * 4)
    glyphs: dict[str, list[int]] = {}
    for glyph_index in range(glyph_count):
        cell_x = (glyph_index % columns) * cell_width
        cell_y = (glyph_index // columns) * cell_height
        glyph = glyph_data[glyph_index * 30 : glyph_index * 30 + 30]
        for y in range(15):
            for byte_index in range(2):
                bits = glyph[y * 2 + byte_index]
                for bit in range(8):
                    if bits & (1 << (7 - bit)):
                        x = cell_x + byte_index * 8 + bit
                        pixel = (cell_y + y) * width * 4 + x * 4
                        pixels[pixel : pixel + 4] = b"\xff\xff\xff\xff"
        glyphs[characters[glyph_index]] = [cell_x, cell_y, 16, 15]
    write_rgba_png(output_dir / "font_atlas.png", width, height, bytes(pixels))
    (output_dir / "font_glyphs.json").write_text(
        json.dumps({"cell_size": [16, 16], "glyphs": glyphs}, ensure_ascii=False), encoding="utf-8"
    )
    return {"glyphs": glyph_count, "atlas_size": [width, height]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--word", required=True, type=Path)
    parser.add_argument("--message", required=True, type=Path)
    parser.add_argument("--offsets", required=True, type=Path)
    parser.add_argument("--font", required=True, type=Path)
    parser.add_argument("--characters", required=True, type=Path)
    parser.add_argument("--description", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    word_data = args.word.read_bytes()
    encoding = detect_encoding(word_data)
    words = decode_words(word_data, encoding)
    messages = decode_messages(args.message.read_bytes(), args.offsets.read_bytes(), encoding)
    object_descriptions = decode_object_descriptions(args.description.read_bytes(), encoding) if args.description else {}
    font = convert_font(args.font.read_bytes(), args.characters.read_bytes(), encoding, args.output)
    result = {
        "format_version": 1,
        "encoding": encoding,
        "words": words,
        "messages": messages,
        "object_descriptions": object_descriptions,
        "font": font,
    }
    (args.output / "text.json").write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"encoding": encoding, "words": len(words), "messages": len(messages), "descriptions": len(object_descriptions), **font}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
