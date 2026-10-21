#!/usr/bin/env python3
"""Remove the folder references XcodeGen adds next to local Swift packages.

XcodeGen 2.46 writes a local package's XCLocalSwiftPackageReference relative to the
project directory but resolves its navigator folder reference relative to the spec
file. With project.yml at the repository root and the project in StarterApp/, the
folder points at the repository's parent (or, for examples/*.yml, at the package
itself). Xcode 27.2 refuses to open a package that is already open as a folder, so
drop every folder reference at or above a local package; the package still appears
under Package Dependencies.
"""

import argparse
import os
from pathlib import Path
import posixpath
import re
import sys

FOLDER_REF = re.compile(
    r"^\t\t(?P<id>[0-9A-F]{24}) /\* [^*]* \*/ = \{isa = PBXFileReference; "
    r"lastKnownFileType = folder; (?:name = [^;]*; )?path = (?P<path>[^;]*); sourceTree = SOURCE_ROOT; \};\n",
    re.MULTILINE,
)
LOCAL_PACKAGE = re.compile(r"isa = XCLocalSwiftPackageReference;\s*relativePath = (?P<path>[^;]*);")
GROUP = re.compile(
    r"^\t\t(?P<id>[0-9A-F]{24}) /\* (?P<name>[^*]*) \*/ = \{\n\t\t\tisa = PBXGroup;\n"
    r"\t\t\tchildren = \(\n(?P<children>(?:\t\t\t\t[^\n]*\n)*)\t\t\t\);\n(?:\t\t\t[^\n]*\n)*?\t\t\};\n",
    re.MULTILINE,
)


def unquote(value):
    return value[1:-1] if value.startswith('"') and value.endswith('"') else value


def contains(folder, package):
    """Whether `package` is `folder` or inside it, by file identity when both exist."""
    if Path(folder).exists() and Path(package).exists():
        package = Path(package).resolve()
        return any(os.path.samefile(folder, p) for p in (package, *package.parents))
    folder, package = posixpath.normpath(folder), posixpath.normpath(package)
    return package == folder or package.startswith(folder.rstrip("/") + "/")


def child_line(object_id):
    return re.compile(rf"^\t\t\t\t{object_id} /\* [^*]* \*/,\n", re.MULTILINE)


def drop_folder_refs(text, root="/project"):
    """Return the edited pbxproj text and the number of folder references removed.

    Both kinds of path are relative to the project directory, `root`.
    """
    packages = [posixpath.join(root, unquote(m["path"])) for m in LOCAL_PACKAGE.finditer(text)]
    doomed = [m for m in FOLDER_REF.finditer(text)
              if any(contains(posixpath.join(root, unquote(m["path"])), p) for p in packages)]
    ids = {m["id"] for m in doomed}
    parents = {g["id"] for g in GROUP.finditer(text) if any(i in g["children"] for i in ids)}
    for match in doomed:
        text = text.replace(match[0], "")
        text = child_line(match["id"]).sub("", text)
    # A Packages group left with no children would show as an empty folder.
    for group in list(GROUP.finditer(text)):
        if group["id"] in parents and not group["children"]:
            text = text.replace(group[0], "")
            text = child_line(group["id"]).sub("", text)
    return text, len(doomed)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("project", type=Path, help="path to the .xcodeproj")
    args = parser.parse_args()
    pbxproj = args.project / "project.pbxproj"
    text, removed = drop_folder_refs(pbxproj.read_text(), args.project.absolute().parent.as_posix())
    if removed:
        pbxproj.write_text(text)
    print(f"Removed {removed} local package folder reference(s) from {args.project.name}.", file=sys.stderr)


if __name__ == "__main__":
    main()
