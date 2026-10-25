#!/usr/bin/env python3
"""Make light and dark 1280x640 social preview cards for the repository.

The card shows the app's own icon (StarterApp/StarterApp/AppIcon.icon, rendered by Icon Composer's
ictool), the title, a tagline, optional chips, and up to three UI test screenshots. Screenshots come
from the newest local `scripts/test-ios.sh` run, or from `--attachments`, a downloaded
`ios-test-results-*` artifact's `attachments/` folder. Rendering needs macOS with Xcode 26 or later;
from Windows, run the manual **Social preview** workflow instead.

Upload one of the results under Settings > General > Social preview; GitHub has no API for it.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "StarterApp/StarterApp/AppIcon.icon"
RENDERER = ROOT / "scripts/render-social-preview.swift"
DEFAULT_SCREENS = ["onboarding-welcome", "welcome-screen", "settings-screen"]


def newest_attachments(results=ROOT / "build/test-results"):
    """The attachments folder of the newest local test run that exported screenshots, or None."""
    runs = sorted((path for path in results.glob("run.*") if (path / "attachments/manifest.json").is_file()),
                  key=lambda path: path.stat().st_mtime, reverse=True)
    return runs[0] / "attachments" if runs else None


def pick_screens(attachments, names):
    """Screenshot paths for the named UI test attachments, in the order asked; missing names are skipped.

    `xcresulttool` names each export `<attachment name>_<index>_<uuid>.png`; the manifest maps that
    readable name to the exported file.
    """
    manifest = json.loads((attachments / "manifest.json").read_text(encoding="utf-8"))
    exported = {}
    for test in manifest:
        for attachment in test.get("attachments", []):
            readable = attachment.get("suggestedHumanReadableName", "")
            name = re.sub(r"_\d+_[0-9A-Fa-f-]+\.png$", "", readable)
            if name and name not in exported and attachment.get("exportedFileName", "").endswith(".png"):
                exported[name] = attachments / attachment["exportedFileName"]
    return [exported[name] for name in names if name in exported and exported[name].is_file()]


def display_name(manifest=ROOT / "project.yml"):
    """The Home Screen name from project.yml, the default card title."""
    match = re.search(r'INFOPLIST_KEY_CFBundleDisplayName:\s*"?([^"\n$]+)"?\s*$', manifest.read_text(encoding="utf-8"), re.M)
    return match.group(1).strip() if match else "My App"


def repository_url():
    """`github.com/<owner>/<repo>` from the origin remote, or None."""
    try:
        remote = subprocess.run(["git", "-C", str(ROOT), "remote", "get-url", "origin"],
                                capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    match = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", remote)
    return f"github.com/{match.group(1)}" if match else None


def repository_description():
    """The GitHub repository description through `gh`, or None when gh is unavailable."""
    try:
        return subprocess.run(["gh", "repo", "view", "--json", "description", "--jq", ".description"],
                              cwd=ROOT, capture_output=True, text=True, check=True, timeout=30).stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def render_icon(target):
    """Render the app icon document to a 1024 px PNG with the same ictool lookup as check-app-icon.py."""
    spec = importlib.util.spec_from_file_location("check_app_icon", ROOT / "scripts/check-app-icon.py")
    check_app_icon = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check_app_icon)
    ictool = check_app_icon.find_ictool()
    if ictool is None:
        raise SystemExit("ictool not found: install Xcode 26 or later, or pass --icon with a PNG")
    subprocess.run([str(ictool), str(ICON), "--export-image", "--output-file", str(target), "--platform", "iOS",
                    "--rendition", "Default", "--width", "1024", "--height", "1024", "--scale", "1"],
                   check=True, capture_output=True)
    return target


def renderer_command(theme, output, icon, title, tagline, url, chips, planned, screens):
    command = ["swift", str(RENDERER), "--theme", theme, "--output", str(output), "--icon", str(icon), "--title", title]
    if tagline:
        command += ["--tagline", tagline]
    if url:
        command += ["--url", url]
    for chip in chips:
        command += ["--chip", chip]
    for chip in planned:
        command += ["--planned", chip]
    for screen in screens:
        command += ["--screen", str(screen)]
    return command


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=ROOT / "build/social-preview", help="folder for the two PNGs")
    parser.add_argument("--attachments", type=Path, help="an attachments/ folder from a test run or downloaded artifact")
    parser.add_argument("--screen", action="append", dest="screens", metavar="NAME",
                        help=f"UI test attachment name, front first (default: {', '.join(DEFAULT_SCREENS)})")
    parser.add_argument("--title", help="defaults to the Home Screen name in project.yml")
    parser.add_argument("--tagline", help="defaults to the GitHub repository description")
    parser.add_argument("--chip", action="append", default=[], help="a feature label; repeat for more")
    parser.add_argument("--planned", action="append", default=[], help="a planned feature, drawn dashed with '· soon'")
    parser.add_argument("--url", help="defaults to github.com/<owner>/<repo> from the origin remote")
    parser.add_argument("--icon", type=Path, help="a PNG to use instead of rendering AppIcon.icon")
    args = parser.parse_args(argv)

    attachments = args.attachments or newest_attachments()
    screens = pick_screens(attachments, args.screens or DEFAULT_SCREENS) if attachments else []
    if not screens:
        print("No UI test screenshots found; the card will have no screens. Run scripts/test-ios.sh or pass --attachments.",
              file=sys.stderr)
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as scratch:
        icon = args.icon or render_icon(Path(scratch) / "icon.png")
        for theme in ("light", "dark"):
            subprocess.run(renderer_command(theme, args.output / f"social-preview-{theme}.png", icon,
                                            args.title or display_name(), args.tagline or repository_description(),
                                            args.url or repository_url(), args.chip, args.planned, screens), check=True)
    print(f"Upload one under Settings > General > Social preview: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
