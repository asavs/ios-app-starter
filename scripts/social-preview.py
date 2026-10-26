#!/usr/bin/env python3
"""Make light and dark 1280x640 social preview cards for the repository.

The card shows the app's own icon (StarterApp/StarterApp/AppIcon.icon, rendered by Icon Composer's
ictool), the title, a tagline, up to four feature rows with drawn icons, one line of chips, and up to
three UI test screenshots. Text and screenshot choice come from `.github/social-preview.json`;
anything it leaves out falls back to the Home Screen name, the repository description, the first three
repository topics and the onboarding, home and settings screenshots.
Screenshots come from the newest local `scripts/test-ios.sh` run, or from `--attachments`, a
downloaded `ios-test-results-*` artifact's `attachments/` folder. Rendering needs macOS with Xcode 26
or later; from Windows, run the manual **Social preview** workflow instead.

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
CONFIG = ROOT / ".github/social-preview.json"
GLYPHS = {"modules", "chat", "bridge", "backend", "lock", "sparkle", "globe", "check"}
DEFAULT_SCREENS = ["onboarding-welcome", "welcome-screen", "settings-screen"]


def newest_attachments(results=ROOT / "build/test-results"):
    """The attachments folder of the newest local test run that exported screenshots, or None."""
    runs = sorted((path for path in results.glob("run.*") if (path / "attachments/manifest.json").is_file()),
                  key=lambda path: path.stat().st_mtime, reverse=True)
    return runs[0] / "attachments" if runs else None


def screenshot_names(attachments):
    """Each PNG attachment's name mapped to its exported file, first export of a name winning.

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
    return exported


def pick_screens(attachments, names):
    """Screenshot paths for the named UI test attachments, in the order asked; missing names are skipped."""
    exported = screenshot_names(attachments)
    missing = [name for name in names if name not in exported]
    if missing:
        print(f"No screenshot named {', '.join(missing)}. Available: {', '.join(sorted(exported)) or 'none'}",
              file=sys.stderr)
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


def load_config(path=CONFIG):
    """The card settings: optional title, tagline, url, chips and features. Missing file means defaults."""
    if not path.is_file():
        return {}
    config = json.loads(path.read_text(encoding="utf-8"))
    for index, feature in enumerate(config.get("features", [])):
        if not isinstance(feature, dict) or not feature.get("label"):
            raise SystemExit(f"{path.name}: features[{index}] needs a label")
        if feature.get("icon", "") not in GLYPHS:
            print(f"{path.name}: features[{index}] icon {feature.get('icon')!r} is not one of {sorted(GLYPHS)}; drawing a dot",
                  file=sys.stderr)
    return config


def feature_flags(features):
    """`glyph|label` or `glyph|label|soon` values for the renderer's --feature."""
    return ["|".join([feature.get("icon", ""), feature["label"]] + (["soon"] if feature.get("soon") else []))
            for feature in features[:4]]


def repository_topics():
    """The repository's GitHub topics through `gh`, in GitHub's order, or [] when gh is unavailable."""
    try:
        output = subprocess.run(["gh", "repo", "view", "--json", "repositoryTopics", "--jq", "[.repositoryTopics[].name]"],
                                cwd=ROOT, capture_output=True, text=True, check=True, timeout=30).stdout
        return json.loads(output or "[]")
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return []


def setting(config, key, flag=None, default=None):
    """One card setting: a command-line value wins; then the config's value, where null or a missing key
    means the default and an empty string or list means leave it off; then `default()`."""
    if flag is not None:
        return flag
    if config.get(key) is not None:
        return config[key]
    return default() if default else None


def choose_chips(flags, config, topics):
    """Chips appear only on a card without feature rows: --chip, then the config's chips (an empty list
    hides them), then the first three topics."""
    if config.get("features"):
        return []
    return list(setting(config, "chips", flags or None, lambda: topics[:3]))


def repository_description():
    """The GitHub repository description through `gh`, or None when gh is unavailable."""
    try:
        return subprocess.run(["gh", "repo", "view", "--json", "description", "--jq", ".description"],
                              cwd=ROOT, capture_output=True, text=True, check=True, timeout=30).stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def render_icon(target, size=1024):
    """Render the app icon document to a square PNG with the same ictool lookup as check-app-icon.py."""
    spec = importlib.util.spec_from_file_location("check_app_icon", ROOT / "scripts/check-app-icon.py")
    check_app_icon = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check_app_icon)
    ictool = check_app_icon.find_ictool()
    if ictool is None:
        raise SystemExit("ictool not found: install Xcode 26 or later, or pass --icon with a PNG")
    subprocess.run([str(ictool), str(ICON), "--export-image", "--output-file", str(target), "--platform", "iOS",
                    "--rendition", "Default", "--width", str(size), "--height", str(size), "--scale", "1"],
                   check=True, capture_output=True)
    return target


def fit_upload_limit(card, limit=1_000_000):
    """GitHub rejects social preview uploads over 1 MB; write a JPEG beside a PNG that is too large."""
    if card.stat().st_size <= limit:
        return card
    for quality in (90, 80, 70, 60):
        jpeg = card.with_suffix(".jpg")
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality), str(card), "--out", str(jpeg)],
                       check=True, capture_output=True)
        if jpeg.stat().st_size <= limit:
            print(f"{card.name} is over GitHub's 1 MB limit; upload {jpeg.name} instead.", file=sys.stderr)
            return jpeg
    print(f"{card.name} is over GitHub's 1 MB limit even as a JPEG; use fewer screenshots.", file=sys.stderr)
    return card


def frame_path(value):
    """The owner's device frame, relative paths from the repository root. Warns when git would commit it:
    frames such as Apple's Product Bezels are licensed to the owner, not to the template."""
    if not value:
        return None
    path = Path(value)
    path = path if path.is_absolute() else ROOT / path
    if not path.is_file():
        raise SystemExit(f"frame {value!r} not found; download it and keep it out of git, for example in build/")
    try:
        inside = path.resolve().relative_to(ROOT)
    except ValueError:
        return path
    ignored = subprocess.run(["git", "-C", str(ROOT), "check-ignore", "-q", str(inside)], capture_output=True).returncode == 0
    if not ignored:
        print(f"warning: {inside} is inside the repository and not ignored by git; keep device frames out of commits",
              file=sys.stderr)
    return path


def renderer_command(theme, output, icon, title, tagline, url, chips, features, screens, frame=None):
    command = ["swift", str(RENDERER), "--theme", theme, "--output", str(output), "--icon", str(icon), "--title", title]
    if tagline:
        command += ["--tagline", tagline]
    if url:
        command += ["--url", url]
    for chip in chips:
        command += ["--chip", chip]
    for feature in features:
        command += ["--feature", feature]
    for screen in screens:
        command += ["--screen", str(screen)]
    if frame:
        command += ["--frame", str(frame)]
    return command


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=ROOT / "build/social-preview", help="folder for the two PNGs")
    parser.add_argument("--attachments", type=Path, help="an attachments/ folder from a test run or downloaded artifact")
    parser.add_argument("--screen", action="append", dest="screens", metavar="NAME",
                        help=f"UI test attachment name, front first (default: the config's screens, else {', '.join(DEFAULT_SCREENS)})")
    parser.add_argument("--title", help="defaults to the Home Screen name in project.yml")
    parser.add_argument("--tagline", help="defaults to the GitHub repository description")
    parser.add_argument("--chip", action="append", default=[],
                        help="a chip label; repeat for more (default: the config's chips, else the first three topics)")
    parser.add_argument("--config", type=Path, default=CONFIG, help="card settings (default: .github/social-preview.json)")
    parser.add_argument("--url", help="defaults to github.com/<owner>/<repo> from the origin remote")
    parser.add_argument("--icon", type=Path, help="a PNG to use instead of rendering AppIcon.icon")
    parser.add_argument("--frame", help="a device frame PNG with a transparent screen, kept out of git (default: the config's frame)")
    parser.add_argument("--readme-icon", type=Path, metavar="PNG",
                        help="only render the app icon at README size (512 px) to this path, then stop")
    args = parser.parse_args(argv)
    if args.readme_icon:
        args.readme_icon.parent.mkdir(parents=True, exist_ok=True)
        render_icon(args.readme_icon, size=512)
        print(args.readme_icon)
        return 0
    config = load_config(args.config)

    attachments = args.attachments or newest_attachments()
    names = setting(config, "screens", args.screens, lambda: DEFAULT_SCREENS)
    screens = pick_screens(attachments, names[:3]) if attachments and names else []
    if not screens:
        print("No UI test screenshots found; the card will have no screens. Run scripts/test-ios.sh or pass --attachments.",
              file=sys.stderr)
    args.output.mkdir(parents=True, exist_ok=True)
    frame = frame_path(setting(config, "frame", args.frame))
    topics = [] if args.chip or config.get("chips") is not None or config.get("features") else repository_topics()
    with tempfile.TemporaryDirectory() as scratch:
        icon = args.icon or render_icon(Path(scratch) / "icon.png")
        if not args.icon:
            render_icon(args.output / "app-icon.png", size=512)  # README size, for docs/images/icon.png
        for theme in ("light", "dark"):
            subprocess.run(renderer_command(
                theme, args.output / f"social-preview-{theme}.png", icon,
                setting(config, "title", args.title) or display_name(),
                setting(config, "tagline", args.tagline, repository_description),
                setting(config, "url", args.url, repository_url),
                choose_chips(args.chip, config, topics), feature_flags(config.get("features", [])), screens, frame), check=True)
            fit_upload_limit(args.output / f"social-preview-{theme}.png")
    print(f"Upload one under Settings > General > Social preview: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
