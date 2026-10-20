#!/usr/bin/env python3
"""Verify or refresh repository-local copies of the pinned agent skills."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "skills.lock"
LOCATIONS = (ROOT / ".agents" / "skills", ROOT / ".claude" / "skills")


def load_lock() -> dict:
    data = json.loads(LOCK.read_text(encoding="utf-8"))
    if data.get("version") != 1 or not isinstance(data.get("skills"), list):
        raise ValueError("skills.lock must have version 1 and a skills list")
    names = [entry.get("name") for entry in data["skills"]]
    if len(names) != len(set(names)) or any(not name for name in names):
        raise ValueError("skills.lock contains missing or duplicate skill names")
    return data


def content_hash(folder: Path) -> str:
    digest = hashlib.sha256()
    # pathlib sorts WindowsPath case-insensitively and PosixPath case-sensitively.
    # Sort the repository-relative POSIX names so pinned hashes agree on both.
    paths = sorted(folder.rglob("*"), key=lambda path: path.relative_to(folder).as_posix())
    for path in paths:
        if path.is_symlink():
            raise ValueError(f"symlink is not allowed in a pinned skill copy: {path}")
    for file in (p for p in paths if p.is_file()):
        relative = file.relative_to(folder).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        raw = file.read_bytes()
        digest.update(len(raw).to_bytes(8, "big"))
        digest.update(raw)
    return digest.hexdigest()


def verify(data: dict) -> int:
    failures = []
    for skill in data["skills"]:
        name = skill["name"]
        expected = skill.get("content_sha256", "")
        if not skill.get("commit") or not expected:
            failures.append(f"{name}: lock entry is not pinned; run --update")
            continue
        for location in LOCATIONS:
            folder = location / name
            if not folder.is_dir():
                failures.append(f"{name}: missing copy at {folder.relative_to(ROOT)}")
                continue
            if not (folder / "SKILL.md").is_file():
                failures.append(f"{name}: missing root SKILL.md at {folder.relative_to(ROOT)}")
                continue
            actual = content_hash(folder)
            if actual != expected:
                failures.append(f"{name}: drift at {folder.relative_to(ROOT)}")
    if failures:
        print("Skill verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"Verified {len(data['skills'])} pinned skills in both discovery locations.")
    return 0


def git(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def git_tree(source: Path) -> dict[PurePosixPath, tuple[str, str]]:
    result = subprocess.run(["git", "ls-files", "-s", "-z"], cwd=source, check=True, capture_output=True)
    entries = {}
    for record in result.stdout.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, object_id, _stage = metadata.split()
        entries[PurePosixPath(os.fsdecode(raw_path))] = (mode.decode("ascii"), object_id.decode("ascii"))
    return entries


def git_blob(source: Path, object_id: str) -> bytes:
    return subprocess.run(["git", "cat-file", "blob", object_id], cwd=source, check=True, capture_output=True).stdout


def materialize_directory(source: Path, entries: dict, repo_dir: PurePosixPath, destination: Path, chain=()) -> None:
    prefix = "" if repo_dir == PurePosixPath(".") else f"{repo_dir.as_posix()}/"
    children = set()
    for path in entries:
        value = path.as_posix()
        if value.startswith(prefix):
            remainder = value[len(prefix):]
            if remainder:
                children.add(remainder.split("/", 1)[0])
    destination.mkdir(parents=True, exist_ok=True)
    for child in sorted(children):
        entry = PurePosixPath(child) if repo_dir == PurePosixPath(".") else repo_dir / child
        target = destination / child
        if entry in entries:
            materialize_entry(source, entries, entry, target, chain)
        else:
            materialize_directory(source, entries, entry, target, chain)


def materialize_entry(source: Path, entries: dict, entry: PurePosixPath, destination: Path, chain=()) -> None:
    mode, object_id = entries[entry]
    if mode == "120000":
        if entry in chain:
            raise ValueError(f"symlink cycle in skill source: {entry}")
        link_target = git_blob(source, object_id).decode("utf-8").strip()
        if "\\" in link_target:
            raise ValueError(f"non-portable symlink target in skill source: {entry}")
        resolved = PurePosixPath(posixpath.normpath(posixpath.join(entry.parent.as_posix(), link_target)))
        if resolved.is_absolute() or ".." in resolved.parts:
            raise ValueError(f"symlink escapes source repository in skill source: {entry}")
        next_chain = (*chain, entry)
        if resolved in entries:
            materialize_entry(source, entries, resolved, destination, next_chain)
        elif any(path.as_posix().startswith(f"{resolved.as_posix()}/") for path in entries):
            materialize_directory(source, entries, resolved, destination, next_chain)
        else:
            raise ValueError(f"dangling symlink in skill source: {entry}")
        return
    if mode not in {"100644", "100755"}:
        raise ValueError(f"unsupported Git entry mode {mode} in skill source: {entry}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(git_blob(source, object_id))


def source_tree(skill: dict, temp: Path, latest: bool) -> tuple[str, Path]:
    repository = skill["repository"]
    local_or_url = skill.get("url") or f"https://github.com/{repository}.git"
    checkout = temp / "repo"
    checkout.parent.mkdir(parents=True, exist_ok=True)
    git("clone", "--quiet", "--filter=blob:none", "--no-checkout", local_or_url, str(checkout))
    ref = skill.get("ref")
    if ref:
        git("fetch", "--quiet", "origin", f"refs/tags/{ref}", cwd=checkout)
        commit = git("rev-parse", "FETCH_HEAD^{commit}", cwd=checkout)
    elif latest:
        commit = git("rev-parse", "origin/HEAD", cwd=checkout)
    else:
        commit = skill["commit"]
        git("fetch", "--quiet", "origin", commit, cwd=checkout)
        commit = git("rev-parse", "FETCH_HEAD", cwd=checkout)
    git("checkout", "--quiet", "--detach", commit, cwd=checkout)
    return commit, checkout


def copy_skill(skill: dict, source: Path, name: str) -> str:
    source_path = skill["path"]
    if "\\" in source_path:
        raise ValueError(f"source path must use forward slashes for {name}: {source_path}")
    relative = PurePosixPath(source_path)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"unsafe source path for {name}: {skill['path']}")
    entries = git_tree(source)
    skill_path = PurePosixPath(".") if str(relative) == "." else relative
    if not any(path == skill_path or path.as_posix().startswith(f"{skill_path.as_posix()}/") for path in entries):
        raise ValueError(f"source directory does not exist for {name}: {skill['path']}")
    skill_manifest = skill_path / "SKILL.md" if skill_path != PurePosixPath(".") else PurePosixPath("SKILL.md")
    if skill_manifest not in entries:
        raise ValueError(f"source directory has no root SKILL.md for {name}: {skill['path']}")
    license_path = next((path for path in entries if len(path.parts) == 1 and path.name.lower().startswith("license")), None)
    if license_path is None:
        raise ValueError(f"source repository has no root LICENSE file: {skill['repository']}")
    license_blob = git_blob(source, entries[license_path][1])
    for location in LOCATIONS:
        target = location / name
        if target.exists():
            shutil.rmtree(target)
        materialize_directory(source, entries, skill_path, target)
        (target / license_path.name).write_bytes(license_blob)
        if any(p.is_symlink() for p in target.rglob("*")):
            raise ValueError(f"copy contains a symlink: {target}")
    return content_hash(LOCATIONS[0] / name)


def update(data: dict, selected: str | None) -> int:
    entries = data["skills"] if selected is None else [s for s in data["skills"] if s["name"] == selected]
    if not entries:
        print(f"Unknown skill: {selected}", file=sys.stderr)
        return 2
    with tempfile.TemporaryDirectory(prefix="sync-skills-") as temp_name:
        temp = Path(temp_name)
        for index, skill in enumerate(entries):
            print(f"Updating {skill['name']} from {skill['repository']}...")
            commit, checkout = source_tree(skill, temp / str(index), latest=True)
            digest = copy_skill(skill, checkout, skill["name"])
            skill["commit"] = commit
            skill["content_sha256"] = digest
    LOCK.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"Updated {len(entries)} skill lock entr{'y' if len(entries) == 1 else 'ies'}.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update", nargs="?", const="*", metavar="NAME", help="refresh all skills, or one named skill")
    args = parser.parse_args()
    try:
        data = load_lock()
        if args.update is None:
            return verify(data)
        return update(data, None if args.update == "*" else args.update)
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"sync-skills: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
