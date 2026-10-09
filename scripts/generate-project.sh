#!/usr/bin/env bash
set -euo pipefail

# Runs on the GitHub macOS runner; Windows users edit project.yml and push.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator_version='2.46.0'
generator_sha256='4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806'
generator_dir="$(mktemp -d)"
trap 'rm -rf "$generator_dir"' EXIT

# Cache the original archive, not mutable extracted executables. Every reuse
# verifies its checksum, then extracts into this invocation's clean directory.
archive="$(python3 "$repo_dir/scripts/tool_download.py" \
  --url "https://github.com/yonaskolb/XcodeGen/releases/download/${generator_version}/xcodegen.zip" \
  --sha256 "$generator_sha256" \
  --filename "xcodegen-${generator_version}.zip" \
  --cache-dir "${IOS_XCODEGEN_CACHE_DIR:-$repo_dir/build/tool-downloads/xcodegen}")"
unzip -q "$archive" -d "$generator_dir"
mkdir -p "${IOS_PROJECT_DIR:-$repo_dir/StarterApp}"
"$generator_dir/xcodegen/bin/xcodegen" generate \
  --spec "${IOS_PROJECT_SPEC:-$repo_dir/project.yml}" \
  --project "${IOS_PROJECT_DIR:-$repo_dir/StarterApp}"
