#!/usr/bin/env python3
"""Write milestone-5 App Store export options from a fresh Xcode configuration export."""
import argparse
import plistlib
from pathlib import Path
from signing_configuration import read_config


def options(configuration):
    app = read_config(configuration)
    if not app["teamIdentifier"]:
        raise ValueError("A configured Apple team is required for an App Store export.")
    return {"destination": "export", "method": "app-store-connect",
            "signingStyle": "automatic", "teamID": app["teamIdentifier"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        args.output.write_bytes(plistlib.dumps(options(args.configuration), sort_keys=True))
        print("Wrote automatic App Store Connect export options with destination=export.")
        return 0
    except (OSError, ValueError, KeyError, TypeError):
        parser.exit(1, "Could not create export options from the selected configuration.\n")


if __name__ == "__main__":
    raise SystemExit(main())
