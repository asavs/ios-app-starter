#!/usr/bin/env python3
"""Write the GitHub environment private key to a runner-temporary file."""
import os
from pathlib import Path
import sys

BEGIN = b"-----BEGIN PRIVATE KEY-----"
END = b"-----END PRIVATE KEY-----"


def main():
    value = os.environ.get("ASC_PRIVATE_KEY", "").encode("utf-8")
    if not value.strip().startswith(BEGIN) or not value.strip().endswith(END) or len(value) > 64 * 1024:
        print("ASC_PRIVATE_KEY is missing or is not a valid-sized PEM key.", file=sys.stderr)
        return 1
    runner_temp = os.environ.get("RUNNER_TEMP")
    if not runner_temp:
        print("RUNNER_TEMP is required.", file=sys.stderr)
        return 1
    target = Path(runner_temp) / "asc-private-key.p8"
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value.strip() + b"\n")
        target.chmod(0o600)
    except OSError:
        print("Could not materialize ASC_PRIVATE_KEY in runner temporary storage.", file=sys.stderr)
        return 1
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        target.unlink(missing_ok=True)
        print("GITHUB_OUTPUT is required.", file=sys.stderr)
        return 1
    with open(output, "a", encoding="utf-8") as stream:
        stream.write(f"key_path={target}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
