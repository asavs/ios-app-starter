#!/usr/bin/env bash
set -euo pipefail

# Runs on the GitHub macOS runner; Windows users edit project.yml and push.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator_version='2.46.0'
generator_sha256='4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806'
generator_dir="$(mktemp -d)"
trap 'rm -rf "$generator_dir"' EXIT

curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/yonaskolb/XcodeGen/releases/download/${generator_version}/xcodegen.zip" \
  --output "$generator_dir/xcodegen.zip"
printf '%s  %s\n' "$generator_sha256" "$generator_dir/xcodegen.zip" \
  | shasum -a 256 --check
unzip -q "$generator_dir/xcodegen.zip" -d "$generator_dir"
mkdir -p "${IOS_PROJECT_DIR:-$repo_dir/StarterApp}"
"$generator_dir/xcodegen/bin/xcodegen" generate \
  --spec "${IOS_PROJECT_SPEC:-$repo_dir/project.yml}" \
  --project "${IOS_PROJECT_DIR:-$repo_dir/StarterApp}"
