#!/usr/bin/env python3
"""Validate remaster asset, TTS, art, MOD, and content-lock manifests.

This validator intentionally uses only Python's standard library so a clean
checkout can run the release gate without installing packages. It enforces the
runtime-sensitive subset of the canonical JSON Schema contracts and optionally
verifies every referenced file hash.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Callable


SCHEMA_VERSION = "1.0.0"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PACK_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
ASSET_ID_RE = re.compile(
    r"^(map/[^/]+/environment|character/[^/]+/field|portrait/[^/]+/[^/]+|"
    r"battlefield/[^/]+|battle/[^/]+/[^/]+|cutscene/[^/]+/[^/]+|"
    r"voice/[^/]+|ui/[^/]+)$"
)


class ManifestError(ValueError):
    """Raised when a manifest violates a public content contract."""


def fail(location: str, message: str) -> None:
    raise ManifestError(f"{location}: {message}")


def require_object(value: Any, location: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(location, "must be an object")
    return value


def require_array(value: Any, location: str) -> list[Any]:
    if not isinstance(value, list):
        fail(location, "must be an array")
    return value


def require_string(value: Any, location: str, *, allow_empty: bool = False) -> str:
    if not isinstance(value, str) or (not allow_empty and not value):
        fail(location, "must be a non-empty string")
    return value


def require_integer(value: Any, location: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        fail(location, "must be an integer")
    if value < minimum or value > maximum:
        fail(location, f"must be between {minimum} and {maximum}")
    return value


def require_number(value: Any, location: str, minimum: float, maximum: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(location, "must be a number")
    if value < minimum or value > maximum:
        fail(location, f"must be between {minimum} and {maximum}")
    return float(value)


def require_keys(
    obj: dict[str, Any], location: str, required: set[str], allowed: set[str]
) -> None:
    missing = sorted(required - obj.keys())
    unknown = sorted(obj.keys() - allowed)
    if missing:
        fail(location, f"missing fields: {', '.join(missing)}")
    if unknown:
        fail(location, f"unknown fields: {', '.join(unknown)}")


def require_enum(value: Any, location: str, allowed: set[str]) -> str:
    string = require_string(value, location)
    if string not in allowed:
        fail(location, f"must be one of: {', '.join(sorted(allowed))}")
    return string


def require_sha256(value: Any, location: str) -> str:
    digest = require_string(value, location)
    if not SHA256_RE.fullmatch(digest):
        fail(location, "must be a lowercase SHA-256 digest")
    return digest


def require_relative_path(value: Any, location: str) -> str:
    path = require_string(value, location)
    pure_path = PurePosixPath(path)
    if pure_path.is_absolute() or ".." in pure_path.parts or "\\" in path or "\x00" in path:
        fail(location, "must be a safe POSIX path relative to the pack root")
    return path


def require_schema_version(obj: dict[str, Any], location: str = "manifest") -> None:
    if obj.get("schema_version") != SCHEMA_VERSION:
        fail(f"{location}.schema_version", f"must equal {SCHEMA_VERSION}")


def require_unique_strings(values: Any, location: str) -> list[str]:
    array = require_array(values, location)
    result = [require_string(value, f"{location}[{index}]") for index, value in enumerate(array)]
    if len(result) != len(set(result)):
        fail(location, "must not contain duplicates")
    return result


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_file(root: Path | None, relative: str, digest: str, location: str) -> None:
    if root is None:
        return
    path = root / relative
    if not path.is_file():
        fail(location, f"referenced file does not exist: {relative}")
    actual = sha256_file(path)
    if actual != digest:
        fail(location, f"SHA-256 mismatch for {relative}: expected {digest}, got {actual}")


def validate_asset_manifest(data: dict[str, Any], root: Path | None) -> None:
    required = {"schema_version", "pack_id", "asset_version", "assets"}
    allowed = required | {"chapter", "generated_at"}
    require_keys(data, "manifest", required, allowed)
    require_schema_version(data)
    pack_id = require_string(data["pack_id"], "manifest.pack_id")
    if not PACK_ID_RE.fullmatch(pack_id):
        fail("manifest.pack_id", "contains unsupported characters")
    require_string(data["asset_version"], "manifest.asset_version")
    if data.get("chapter") is not None:
        require_integer(data["chapter"], "manifest.chapter", 0, 18)
    if "generated_at" in data:
        require_string(data["generated_at"], "manifest.generated_at")

    ids: set[str] = set()
    allowed_types = {
        "environment", "field_sprite", "portrait", "battlefield",
        "battle_action", "cutscene", "voice", "ui_theme",
    }
    statuses = {"draft", "generated", "technical_review", "approved", "rejected"}
    for index, raw_entry in enumerate(require_array(data["assets"], "manifest.assets")):
        location = f"manifest.assets[{index}]"
        entry = require_object(raw_entry, location)
        entry_required = {"id", "type", "path", "sha256", "chapter", "source_references", "review_status"}
        entry_allowed = entry_required | {"generation", "fallback_asset_id", "notes"}
        require_keys(entry, location, entry_required, entry_allowed)
        asset_id = require_string(entry["id"], f"{location}.id")
        if not ASSET_ID_RE.fullmatch(asset_id):
            fail(f"{location}.id", "does not match a supported logical resource ID")
        if asset_id in ids:
            fail(f"{location}.id", f"duplicate asset ID: {asset_id}")
        ids.add(asset_id)
        require_enum(entry["type"], f"{location}.type", allowed_types)
        relative = require_relative_path(entry["path"], f"{location}.path")
        digest = require_sha256(entry["sha256"], f"{location}.sha256")
        if entry["chapter"] is not None:
            require_integer(entry["chapter"], f"{location}.chapter", 0, 18)
        require_unique_strings(entry["source_references"], f"{location}.source_references")
        require_enum(entry["review_status"], f"{location}.review_status", statuses)
        if entry.get("fallback_asset_id") is not None:
            require_string(entry["fallback_asset_id"], f"{location}.fallback_asset_id")
        if "notes" in entry:
            require_string(entry["notes"], f"{location}.notes", allow_empty=True)
        if "generation" in entry:
            generation = require_object(entry["generation"], f"{location}.generation")
            generation_required = {"provider", "model", "prompt_manifest_id"}
            generation_allowed = generation_required | {"protocol_version", "width", "height"}
            require_keys(generation, f"{location}.generation", generation_required, generation_allowed)
            for name in generation_required:
                require_string(generation[name], f"{location}.generation.{name}")
            for name in ("width", "height"):
                if name in generation:
                    require_integer(generation[name], f"{location}.generation.{name}", 1, 65536)
        verify_file(root, relative, digest, f"{location}.path")


def validate_tts_manifest(data: dict[str, Any], root: Path | None) -> None:
    required = {"schema_version", "chapter", "model", "audio_profile", "entries"}
    allowed = required | {"pronunciation_dictionary_version"}
    require_keys(data, "manifest", required, allowed)
    require_schema_version(data)
    require_integer(data["chapter"], "manifest.chapter", 1, 18)
    if data["model"] != "speech-2.8-hd":
        fail("manifest.model", "must equal speech-2.8-hd")
    profile = require_object(data["audio_profile"], "manifest.audio_profile")
    expected_profile = {
        "sample_rate_hz": 32000,
        "bitrate_bps": 128000,
        "channels": 1,
        "intermediate_format": "mp3",
        "runtime_format": "ogg_vorbis_q5",
    }
    require_keys(profile, "manifest.audio_profile", set(expected_profile), set(expected_profile))
    for key, expected in expected_profile.items():
        if profile[key] != expected:
            fail(f"manifest.audio_profile.{key}", f"must equal {expected!r}")
    if data.get("pronunciation_dictionary_version") is not None:
        require_string(data["pronunciation_dictionary_version"], "manifest.pronunciation_dictionary_version")

    round_ids: set[str] = set()
    message_keys: set[tuple[int, ...]] = set()
    statuses = {"pending", "generated", "listened", "approved", "rejected"}
    for index, raw_entry in enumerate(require_array(data["entries"], "manifest.entries")):
        location = f"manifest.entries[{index}]"
        entry = require_object(raw_entry, location)
        entry_required = {
            "dialog_round_id", "message_ids", "speaker_id", "role", "text",
            "text_sha256", "voice_id", "voice_settings", "output_path",
            "audio_sha256", "review_status",
        }
        require_keys(entry, location, entry_required, entry_required | {"notes"})
        round_id = require_string(entry["dialog_round_id"], f"{location}.dialog_round_id")
        if not PACK_ID_RE.fullmatch(round_id):
            fail(f"{location}.dialog_round_id", "contains unsupported characters")
        if round_id in round_ids:
            fail(f"{location}.dialog_round_id", f"duplicate dialog round ID: {round_id}")
        round_ids.add(round_id)
        raw_ids = require_array(entry["message_ids"], f"{location}.message_ids")
        if not raw_ids:
            fail(f"{location}.message_ids", "must contain at least one message ID")
        message_ids = tuple(
            require_integer(value, f"{location}.message_ids[{item_index}]", 0, 2**31 - 1)
            for item_index, value in enumerate(raw_ids)
        )
        if len(message_ids) != len(set(message_ids)):
            fail(f"{location}.message_ids", "must not contain duplicates")
        if message_ids in message_keys:
            fail(f"{location}.message_ids", "duplicates another runtime dialogue key")
        message_keys.add(message_ids)
        require_string(entry["speaker_id"], f"{location}.speaker_id")
        require_enum(entry["role"], f"{location}.role", {"dialogue", "narration"})
        dialogue_text = require_string(entry["text"], f"{location}.text")
        text_digest = require_sha256(entry["text_sha256"], f"{location}.text_sha256")
        actual_text_digest = hashlib.sha256(dialogue_text.encode("utf-8")).hexdigest()
        if text_digest != actual_text_digest:
            fail(f"{location}.text_sha256", f"does not match UTF-8 text (got {actual_text_digest})")
        require_string(entry["voice_id"], f"{location}.voice_id")
        settings = require_object(entry["voice_settings"], f"{location}.voice_settings")
        setting_keys = {"speed", "pitch", "volume", "emotion"}
        require_keys(settings, f"{location}.voice_settings", setting_keys, setting_keys)
        require_number(settings["speed"], f"{location}.voice_settings.speed", 0.5, 2.0)
        require_integer(settings["pitch"], f"{location}.voice_settings.pitch", -12, 12)
        require_number(settings["volume"], f"{location}.voice_settings.volume", 0.1, 10.0)
        require_string(settings["emotion"], f"{location}.voice_settings.emotion")
        output = require_relative_path(entry["output_path"], f"{location}.output_path")
        if not output.startswith("tts/runtime/") or not output.endswith(".ogg"):
            fail(f"{location}.output_path", "must be tts/runtime/*.ogg")
        audio_digest = require_sha256(entry["audio_sha256"], f"{location}.audio_sha256")
        status = require_enum(entry["review_status"], f"{location}.review_status", statuses)
        if root is not None and status in {"generated", "listened", "approved"}:
            verify_file(root, output, audio_digest, f"{location}.output_path")


def validate_art_manifest(data: dict[str, Any], _root: Path | None) -> None:
    required = {"schema_version", "style_guide_version", "prompts"}
    require_keys(data, "manifest", required, required)
    require_schema_version(data)
    require_string(data["style_guide_version"], "manifest.style_guide_version")
    prompt_ids: set[str] = set()
    for index, raw_prompt in enumerate(require_array(data["prompts"], "manifest.prompts")):
        location = f"manifest.prompts[{index}]"
        prompt = require_object(raw_prompt, location)
        required_prompt = {
            "id", "asset_id", "phase", "provider", "model", "prompt",
            "negative_prompt", "width", "height", "background",
            "source_references", "review_status",
        }
        allowed_prompt = required_prompt | {"seed", "output_sha256", "notes"}
        require_keys(prompt, location, required_prompt, allowed_prompt)
        prompt_id = require_string(prompt["id"], f"{location}.id")
        if not PACK_ID_RE.fullmatch(prompt_id):
            fail(f"{location}.id", "contains unsupported characters")
        if prompt_id in prompt_ids:
            fail(f"{location}.id", f"duplicate prompt ID: {prompt_id}")
        prompt_ids.add(prompt_id)
        require_string(prompt["asset_id"], f"{location}.asset_id")
        require_enum(prompt["phase"], f"{location}.phase", {"concept", "final"})
        require_string(prompt["provider"], f"{location}.provider")
        require_enum(prompt["model"], f"{location}.model", {"nano-banana-2", "gpt-image-2"})
        require_string(prompt["prompt"], f"{location}.prompt")
        require_string(prompt["negative_prompt"], f"{location}.negative_prompt", allow_empty=True)
        require_integer(prompt["width"], f"{location}.width", 128, 65536)
        require_integer(prompt["height"], f"{location}.height", 128, 65536)
        require_enum(prompt["background"], f"{location}.background", {"opaque", "solid_key_color"})
        require_unique_strings(prompt["source_references"], f"{location}.source_references")
        status = require_enum(prompt["review_status"], f"{location}.review_status", {"draft", "generated", "approved", "rejected"})
        if prompt.get("seed") is not None:
            require_integer(prompt["seed"], f"{location}.seed", -(2**63), 2**63 - 1)
        if prompt.get("output_sha256") is not None:
            require_sha256(prompt["output_sha256"], f"{location}.output_sha256")
        elif status in {"generated", "approved"}:
            fail(f"{location}.output_sha256", f"is required when review_status is {status}")


def validate_mod_manifest(data: dict[str, Any], root: Path | None) -> None:
    required = {"schema_version", "pack_id", "version", "priority", "entries"}
    require_keys(data, "manifest", required, required)
    require_schema_version(data)
    pack_id = require_string(data["pack_id"], "manifest.pack_id")
    if not PACK_ID_RE.fullmatch(pack_id):
        fail("manifest.pack_id", "contains unsupported characters")
    require_string(data["version"], "manifest.version")
    require_integer(data["priority"], "manifest.priority", -1000, 1000)
    logical_ids: set[str] = set()
    for index, raw_entry in enumerate(require_array(data["entries"], "manifest.entries")):
        location = f"manifest.entries[{index}]"
        entry = require_object(raw_entry, location)
        required_entry = {"logical_id", "type", "path"}
        require_keys(entry, location, required_entry, required_entry | {"sha256"})
        logical_id = require_string(entry["logical_id"], f"{location}.logical_id")
        if logical_id in logical_ids:
            fail(f"{location}.logical_id", f"duplicate logical ID: {logical_id}")
        logical_ids.add(logical_id)
        require_enum(entry["type"], f"{location}.type", {"portrait", "field_sprite", "voice", "ui_theme"})
        relative = require_relative_path(entry["path"], f"{location}.path")
        if "sha256" in entry:
            digest = require_sha256(entry["sha256"], f"{location}.sha256")
            verify_file(root, relative, digest, f"{location}.path")


def validate_content_lock(data: dict[str, Any], root: Path | None) -> None:
    required = {"schema_version", "asset_repository", "asset_commit", "manifests"}
    require_keys(data, "manifest", required, required)
    require_schema_version(data)
    if data["asset_repository"] != "sword-assets":
        fail("manifest.asset_repository", "must equal sword-assets")
    commit = require_string(data["asset_commit"], "manifest.asset_commit")
    if commit != "unlocked" and not re.fullmatch(r"[0-9a-f]{40}", commit):
        fail("manifest.asset_commit", "must be unlocked or a full lowercase Git commit")
    paths: set[str] = set()
    for index, raw_entry in enumerate(require_array(data["manifests"], "manifest.manifests")):
        location = f"manifest.manifests[{index}]"
        entry = require_object(raw_entry, location)
        require_keys(entry, location, {"path", "sha256"}, {"path", "sha256"})
        relative = require_relative_path(entry["path"], f"{location}.path")
        if not relative.startswith("manifests/") or not relative.endswith(".json"):
            fail(f"{location}.path", "must be manifests/*.json")
        if relative in paths:
            fail(f"{location}.path", f"duplicate manifest path: {relative}")
        paths.add(relative)
        digest = require_sha256(entry["sha256"], f"{location}.sha256")
        verify_file(root, relative, digest, f"{location}.path")


VALIDATORS: dict[str, Callable[[dict[str, Any], Path | None], None]] = {
    "asset": validate_asset_manifest,
    "tts": validate_tts_manifest,
    "art": validate_art_manifest,
    "mod": validate_mod_manifest,
    "lock": validate_content_lock,
}


def detect_kind(data: dict[str, Any]) -> str:
    if "asset_repository" in data:
        return "lock"
    if "audio_profile" in data:
        return "tts"
    if "style_guide_version" in data:
        return "art"
    if "assets" in data:
        return "asset"
    if "priority" in data and "entries" in data:
        return "mod"
    fail("manifest", "cannot determine manifest kind")
    raise AssertionError("unreachable")


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail("manifest", f"duplicate JSON key: {key}")
        result[key] = value
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path, help="JSON manifest or lock file")
    parser.add_argument("--root", type=Path, help="pack root used to verify paths and hashes")
    parser.add_argument("--schema-only", action="store_true", help="validate structure without checking files")
    parser.add_argument("--kind", choices=["auto", *VALIDATORS], default="auto")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        with args.manifest.open("r", encoding="utf-8") as stream:
            data = json.load(stream, object_pairs_hook=reject_duplicate_keys)
        manifest = require_object(data, "manifest")
        kind = detect_kind(manifest) if args.kind == "auto" else args.kind
        root = None if args.schema_only else (args.root.resolve() if args.root else None)
        VALIDATORS[kind](manifest, root)
    except (OSError, json.JSONDecodeError, ManifestError) as exc:
        print(f"FAIL: {args.manifest}: {exc}", file=sys.stderr)
        return 1
    mode = "schema" if args.schema_only or args.root is None else "schema + files"
    print(f"PASS: {args.manifest} ({kind}, {mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
