#!/usr/bin/env python3
"""Validate and expose the app target values from a fresh configuration export."""
import argparse
import json
from pathlib import Path
import sys
from signing_configuration import read_config


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
