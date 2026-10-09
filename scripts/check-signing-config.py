#!/usr/bin/env python3
"""Validate and expose the app target values from a fresh configuration export."""
import argparse
import json
from pathlib import Path
import re
import sys

BUNDLE = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")
TEAM = re.compile(r"[A-Z0-9]{10}\Z")


def read_config(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    records = data.get("configurations")
    if not isinstance(records, list) or {r.get("configuration") for r in records} != {"Debug", "Release"}:
        raise ValueError("Fresh export must include Debug and Release configuration records.")
    if len(records) != 2:
        raise ValueError("Fresh export contains unexpected configuration records.")
    for item in records:
        if not BUNDLE.fullmatch(str(item.get("bundleIdentifier", ""))):
            raise ValueError("Exported bundle identifier is invalid.")
        if not TEAM.fullmatch(str(item.get("teamIdentifier", ""))):
            raise ValueError("Exported Apple Team ID is missing or invalid.")
        if not str(item.get("displayName", "")).strip():
            raise ValueError("Exported display name is missing.")
    for key in ("bundleIdentifier", "teamIdentifier", "displayName", "minimumIOS"):
        if len({str(item.get(key, "")) for item in records}) != 1:
            raise ValueError(f"Debug and Release {key} values differ.")
    return records[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--output", type=Path, help="GitHub output file (otherwise print JSON)")
    args = parser.parse_args()
    try:
        record = read_config(args.configuration)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"Signing configuration check failed: {error}", file=sys.stderr)
        return 1
    safe = {key: record[key] for key in ("bundleIdentifier", "teamIdentifier", "displayName", "minimumIOS")}
    if args.output:
        with args.output.open("a", encoding="utf-8") as stream:
            for key, value in safe.items():
                stream.write(f"{key}={value}\n")
    else:
        print(json.dumps(safe, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
