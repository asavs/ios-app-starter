#!/usr/bin/env python3
"""Lint the GitHub Actions workflows with a pinned, checksum-verified actionlint.

A workflow GitHub can't load fails without running any job ("This run likely failed because of a
workflow file issue"), and a plain YAML parser misses most of what causes it: a context used where
it isn't available, an unknown key, a bad expression. actionlint checks those. The release archive
is downloaded through tool_download.py like the other pinned tools, its digest checked on every use,
and only the `actionlint` binary is taken out of it. With no arguments every workflow is linted;
extra arguments go to actionlint as they are.
"""
import argparse
import io
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import zipfile

from tool_download import verified_download

VERSION = "1.7.12"
# From the release's actionlint_1.7.12_checksums.txt; they match GitHub's own digests of the assets.
HASHES = {
    "darwin_amd64.tar.gz": "5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644",
    "darwin_arm64.tar.gz": "aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f",
    "linux_amd64.tar.gz": "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8",
    "linux_arm64.tar.gz": "325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6",
    "windows_amd64.zip": "6e7241b51e6817ea6a047693d8e6fed13b31819c9a0dd6c5a726e1592d22f6e9",
    "windows_arm64.zip": "cadcf7ea4efe3a68728893813643cebe1185e5b1d4be5b96245f65c9a4d5ea41",
}
ROOT = Path(__file__).resolve().parents[1]


def asset_name():
    system = {"Darwin": "darwin", "Linux": "linux", "Windows": "windows"}.get(platform.system())
    arch = {"x86_64": "amd64", "AMD64": "amd64", "arm64": "arm64", "aarch64": "arm64", "ARM64": "arm64"}.get(platform.machine())
    asset = f"{system}_{arch}." + ("zip" if system == "windows" else "tar.gz")
    if asset not in HASHES:
        raise ValueError("No reviewed actionlint release for this operating system/architecture")
    return asset


def extract_binary(archive, asset):
    """The binary's bytes from the archive, read by member name; nothing else is extracted."""
    name = "actionlint.exe" if asset.endswith(".zip") else "actionlint"
    data = archive.read_bytes()
    if asset.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            return name, bundle.read(name)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as bundle:
        member = bundle.getmember(name)
        if not member.isfile():
            raise ValueError("The actionlint archive's binary is not a regular file")
        return name, bundle.extractfile(member).read()


def install(destination, cache_dir=None):
    asset = asset_name()
    filename = f"actionlint_{VERSION}_{asset}"
    url = f"https://github.com/rhysd/actionlint/releases/download/v{VERSION}/{filename}"
    cache_dir = cache_dir or ROOT / "build/tool-downloads/actionlint"
    archive = verified_download(url, HASHES[asset], filename, cache_dir)
    name, data = extract_binary(archive, asset)
    destination.mkdir(parents=True, exist_ok=True)
    binary = destination / name
    binary.write_bytes(data)
    binary.chmod(0o755)
    print(f"Verified actionlint {VERSION}: {binary}", file=sys.stderr)
    return binary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--destination", type=Path, default=ROOT / "build/tools")
    parser.add_argument("--cache-dir", type=Path, help="Cache public downloads only; every hit is checksum-verified")
    parser.add_argument("--install-only", action="store_true", help="Install the binary without linting")
    args, extra = parser.parse_known_args()
    try:
        binary = install(args.destination, args.cache_dir)
    except (OSError, ValueError, KeyError, tarfile.TarError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f"actionlint installation failed: {error}\n")
    if args.install_only:
        sys.exit(0)
    if not shutil.which("shellcheck"):
        # actionlint checks `run:` scripts only through shellcheck, which ubuntu-latest has; without it a
        # clean result here says nothing about them (2026-11-07: clean on a Mac, seven findings in CI).
        print("shellcheck not found: run scripts are not checked here; the Workflow lint job checks them.",
              file=sys.stderr)
    # Run from the repository root so actionlint finds .github/workflows and reports repository paths.
    sys.exit(subprocess.run([str(binary), *extra], cwd=ROOT).returncode)
