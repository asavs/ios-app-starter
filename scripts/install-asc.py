#!/usr/bin/env python3
"""Download a reviewed release binary without executing a remote installer."""
import argparse
import platform
from pathlib import Path
import subprocess
from tool_download import verified_download

VERSION = "5.14.0"
HASHES = {
    "linux_amd64": "c55ecfbe02d4644bd2982681e1feeee3889e7c98a663bad9f467ae39c9fa8f7f",
    "linux_arm64": "d8c21d5898951ea1536933571565b3c1ca8887ced356c6f1ad1037ab3a5ba282",
    "macOS_amd64": "6c44e234ac6dc0367fb31e9864434f4437568325bdb218f2a26264797739b416",
    "macOS_arm64": "d9c829b50814e7649b9d11f3c056cb8240368287c4d859ca35c17a5b009b7a78",
    "windows_amd64.exe": "a3384d864ffa20f8bd73238cc8dda72c89e10343e7983f077e7fcea7b802d06b",
}


def install(destination, cache_dir=None):
    system = {"Darwin": "macOS", "Linux": "linux", "Windows": "windows"}.get(platform.system())
    arch = {"x86_64": "amd64", "AMD64": "amd64", "arm64": "arm64", "aarch64": "arm64"}.get(platform.machine())
    asset = f"{system}_{arch}" + (".exe" if system == "windows" else "")
    if asset not in HASHES:
        raise ValueError("No reviewed native asc binary for this operating system/architecture")
    url = f"https://github.com/rorkai/App-Store-Connect-CLI/releases/download/{VERSION}/asc_{VERSION}_{asset}"
    cache_dir = cache_dir or Path(__file__).resolve().parents[1] / "build/tool-downloads/asc"
    downloaded = verified_download(url, HASHES[asset], f"asc_{VERSION}_{asset}", cache_dir)
    data = downloaded.read_bytes()
    destination.mkdir(parents=True, exist_ok=True)
    binary = destination / ("asc.exe" if system == "windows" else "asc")
    binary.write_bytes(data)
    binary.chmod(0o755)
    print(f"Verified asc {VERSION}: {binary}")
    return binary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, default=Path("build/tools"))
    parser.add_argument("--cache-dir", type=Path, help="Cache public downloads only; every hit is checksum-verified")
    try:
        args = parser.parse_args()
        install(args.destination, args.cache_dir)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Installation failed: {error}\n")
