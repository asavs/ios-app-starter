#!/usr/bin/env python3
"""Tag a module library release: a semantic-version git tag apps depend on with `from:`.

Tags on this repository are module library versions, never app builds. The tag must equal
TemplateVersion.modules so an app can show which library it was built against. Run from a clean
`main` checkout after the release pull request merged; the script only prints the push command
unless --push is given.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = Path("Modules/TemplateVersion/Sources/TemplateVersion.swift")
SEMVER = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z")
CONSTANT = re.compile(r'public static let modules = "([^"]*)"')


def git(repo, *args, check=True):
    result = subprocess.run(["git", "-C", str(repo), *args], text=True, capture_output=True)
    if check and result.returncode:
        raise ValueError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def declared_version(repo):
    source = (repo / VERSION_FILE).read_text()
    match = CONSTANT.search(source)
    if not match:
        raise ValueError(f"{VERSION_FILE} must declare public static let modules = \"x.y.z\"")
    return match.group(1)


def plan(repo, version, branch="main"):
    """Validate the release and return the tag name; raise ValueError with the fix otherwise."""
    if not SEMVER.fullmatch(version):
        raise ValueError(f"{version!r} is not a semantic version such as 0.2.0 (no 'v' prefix)")
    declared = declared_version(repo)
    if declared != version:
        raise ValueError(f"{VERSION_FILE} declares {declared}; set it to {version} in a pull request first")
    if git(repo, "status", "--porcelain"):
        raise ValueError("working tree is not clean; commit or stash before tagging")
    current = git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    if branch and current != branch:
        raise ValueError(f"tag from {branch}, not {current} (or pass --branch)")
    upstream = git(repo, "rev-parse", "--verify", "--quiet", f"origin/{branch}", check=False) if branch else ""
    if upstream and upstream != git(repo, "rev-parse", "HEAD"):
        raise ValueError(f"HEAD differs from origin/{branch}; run git fetch and check out the merged commit")
    if git(repo, "tag", "--list", version):
        raise ValueError(f"tag {version} already exists; bump {VERSION_FILE} to the next version")
    return version


def tag(repo, version, push=False, branch="main"):
    name = plan(repo, version, branch)
    git(repo, "tag", "-a", name, "-m", f"Module library {name}")
    if push:
        git(repo, "push", "origin", name)
    return name


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="semantic version to tag, equal to TemplateVersion.modules")
    parser.add_argument("--push", action="store_true", help="push the tag to origin after creating it")
    parser.add_argument("--branch", default="main", help="branch the tag must be cut from (default main)")
    parser.add_argument("--repo", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        name = tag(args.repo, args.version, push=args.push, branch=args.branch)
    except ValueError as error:
        print(f"Tag error: {error}", file=sys.stderr)
        sys.exit(1)
    print(f"Created tag {name}." + ("" if args.push else f" Publish it with: git push origin {name}"))
    print(f"Apps consume it with packages.StarterModules.url plus from: \"{name}\" (docs/modules.md).")
