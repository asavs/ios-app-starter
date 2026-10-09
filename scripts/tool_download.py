#!/usr/bin/env python3
"""Reuse public tool downloads, verifying the pinned digest on every use."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile


def verified_download(url, digest, filename, cache_dir):
    if not re.fullmatch(r"[0-9a-f]{64}", digest) or Path(filename).name != filename or filename in ("", ".", ".."):
        raise ValueError("Expected a SHA-256 digest and plain download filename")
    if not url.startswith("https://"):
        raise ValueError("Tool downloads require HTTPS")
    target = Path(cache_dir) / digest / filename
    if target.is_file():
        if hashlib.sha256(target.read_bytes()).hexdigest() == digest:
            print(f"Verified cached download: {filename}", file=sys.stderr)
            return target
        print(f"Cached checksum mismatch; fetching pinned download again: {filename}", file=sys.stderr)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Only verified bytes are published; independent invocations may safely race.
    with tempfile.TemporaryDirectory(prefix="download-", dir=target.parent) as temporary:
        downloaded = Path(temporary) / filename
        subprocess.run(["curl.exe" if platform.system() == "Windows" else "curl", "--fail", "--silent",
                        "--show-error", "--location", "--retry", "3", "--max-time", "120",
                        "--output", str(downloaded), url], check=True)
        if hashlib.sha256(downloaded.read_bytes()).hexdigest() != digest:
            raise ValueError("Tool download checksum mismatch; downloaded bytes were not published")
        os.replace(downloaded, target)
    print(f"Downloaded and verified: {filename}", file=sys.stderr)
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--filename", required=True)
    parser.add_argument("--cache-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(verified_download(args.url, args.sha256, args.filename, args.cache_dir))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Download failed: {error}\n")
