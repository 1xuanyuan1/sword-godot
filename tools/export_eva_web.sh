#!/usr/bin/env bash

set -euo pipefail

readonly project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly output_dir="${project_dir}/builds/eva"
readonly staging_dir="${project_dir}/builds/eva-project"

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="${GODOT_BIN}"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4 executable not found; set GODOT_BIN." >&2
  exit 1
fi

mkdir -p "${project_dir}/builds" "${output_dir}"
touch "${project_dir}/builds/.gdignore"
find "${output_dir}" -mindepth 1 -delete

"${godot_bin}" --headless --path "${project_dir}" --import

node "${project_dir}/tools/prepare_eva_web_project.mjs"
if ! cp -cR "${project_dir}/.godot" "${staging_dir}/.godot" 2>/dev/null; then
  cp -R "${project_dir}/.godot" "${staging_dir}/.godot"
fi

"${godot_bin}" --headless --path "${staging_dir}" --import

"${godot_bin}" \
  --headless \
  --path "${staging_dir}" \
  --export-release "EVA Web" \
  "${output_dir}/index.html"

test -f "${output_dir}/index.html"
test -f "${output_dir}/index.pck"

node "${project_dir}/tools/prepare_eva_web_bundle.mjs"

echo "EVA Web export compressed and split at ${output_dir}"
