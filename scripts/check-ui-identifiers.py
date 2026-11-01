#!/usr/bin/env python3
"""Check the UI-test contract in StarterApp/Shared/UITesting/Identifiers.swift.

The app's views and its UI tests share one source of accessibility identifiers, so a renamed
control can't leave a test looking for the old name. This fails when:

- an app source (StarterApp/StarterApp) passes a string literal to `accessibilityIdentifier(...)`
  instead of an `Identifiers` constant;
- a UI test (StarterApp/StarterAppUITests) spells an identifier as a literal: a lowercase dotted
  path such as "timer.ring" (launch arguments and labels are not identifiers and are left alone);
- an `Identifiers` constant is referenced nowhere in the app or the UI tests (the control is gone);
- a `ModuleIdentifiers` constant has no matching literal in the module sources (the module renamed
  it), comparing the part before any `\\(` interpolation.

Run from anywhere; `--root` points at another checkout.
"""
import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = Path("StarterApp/Shared/UITesting/Identifiers.swift")
APP_SOURCES = Path("StarterApp/StarterApp")
TEST_SOURCES = Path("StarterApp/StarterAppUITests")
MODULE_SOURCES = Path("Modules")

LITERAL_IDENTIFIER = re.compile(r'accessibilityIdentifier\(\s*"')
DOTTED_LITERAL = re.compile(r'"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_\\()]+)+)"')
ENUM = re.compile(r'\benum\s+(\w+)\s*\{')
CONSTANT = re.compile(r'static\s+(?:let|func)\s+(\w+)\b[^"]*"([^"]*)"')


def code(line):
    """The line without a trailing `//` comment; a `//` inside a string literal (a URL) stays."""
    in_string = False
    index = 0
    while index < len(line):
        character = line[index]
        if character == "\\" and in_string:
            index += 2
            continue
        if character == '"':
            in_string = not in_string
        elif not in_string and line.startswith("//", index):
            return line[:index]
        index += 1
    return line


def swift_files(directory):
    return sorted(path for path in directory.rglob("*.swift") if "/Tests/" not in str(path).replace("\\", "/"))


def constants(text):
    """(qualified name, literal) for each `static let`/`static func` in the contract, by enum nesting."""
    found = []
    names = {}
    depth = 0
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        enum = ENUM.search(stripped)
        if enum:
            names[depth] = enum.group(1)
        constant = CONSTANT.search(stripped)
        if constant:
            qualified = ".".join(names[level] for level in range(depth) if level in names)
            found.append((f"{qualified}.{constant.group(1)}", constant.group(2)))
        depth += stripped.count("{") - stripped.count("}")
    return found


def check(root=ROOT):
    """Return the list of problems; empty when the contract holds."""
    problems = []
    contract_path = root / CONTRACT
    if not contract_path.is_file():
        return [f"{CONTRACT} is missing"]
    app_text = {path: path.read_text(encoding="utf-8") for path in swift_files(root / APP_SOURCES)}
    test_text = {path: path.read_text(encoding="utf-8") for path in swift_files(root / TEST_SOURCES)}
    module_text = "\n".join(path.read_text(encoding="utf-8")
                            for path in (root / MODULE_SOURCES).rglob("Sources/*.swift")) if (root / MODULE_SOURCES).is_dir() else ""
    module_text += "\n".join(path.read_text(encoding="utf-8")
                             for path in (root / MODULE_SOURCES).rglob("Sources/**/*.swift")) if (root / MODULE_SOURCES).is_dir() else ""

    for path, text in app_text.items():
        for number, line in enumerate(text.splitlines(), 1):
            if LITERAL_IDENTIFIER.search(code(line)):
                problems.append(f"{path.relative_to(root)}:{number}: identifier literal; add it to {CONTRACT} and use the constant")
    for path, text in test_text.items():
        for number, line in enumerate(text.splitlines(), 1):
            for literal in DOTTED_LITERAL.findall(code(line)):
                problems.append(f"{path.relative_to(root)}:{number}: identifier literal \"{literal}\"; use the constant from {CONTRACT}")

    everything = "\n".join(list(app_text.values()) + list(test_text.values()))
    for qualified, literal in constants(contract_path.read_text(encoding="utf-8")):
        if qualified.startswith("Identifiers."):
            if qualified not in everything:
                problems.append(f"{CONTRACT}: {qualified} is used nowhere in the app or its UI tests")
        elif qualified.startswith("ModuleIdentifiers."):
            prefix = literal.split("\\(")[0]
            # A constant ending in "." is a prefix for `BEGINSWITH` queries, like one with an interpolation.
            needle = f'"{prefix}' if "\\(" in literal or literal.endswith(".") else f'"{literal}"'
            if prefix and needle not in module_text:
                problems.append(f"{CONTRACT}: {qualified} = \"{literal}\" matches no module source; the module renamed or removed it")
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this checkout)")
    arguments = parser.parse_args()
    problems = check(arguments.root.resolve())
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        print(f"{len(problems)} problem(s) in the UI-test identifier contract", file=sys.stderr)
        return 1
    print("UI-test identifier contract holds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
