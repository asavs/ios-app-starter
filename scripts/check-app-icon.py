#!/usr/bin/env python3
"""Check the app's Icon Composer document and render previews of it.

The template icon is a hand-authored ``AppIcon.icon`` (an ``icon.json`` plus flat SVG layers under
``Assets/``); there is no generator. Icon Composer's own renderer, ``ictool``, reports a malformed
document only as "The data couldn't be read because it isn't in the correct format", so this script
first checks the structure with a named fix for each problem, then renders the Default, Dark and
TintedLight renditions when ``ictool`` is available (Icon Composer ships inside Xcode 26 and later,
or standalone) and writes a JSON report. Without ``ictool`` the render is reported as skipped, not
failed, unless ``--require-render`` is given; the document check itself runs on any platform.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ICON = ROOT / "StarterApp/StarterApp/AppIcon.icon"
RENDITIONS = ("Default", "Dark", "TintedLight")
PREVIEW_SIZE = 1024
HOME_SCREEN_SIZE = 60  # points; rendered at scale 2 like an iPhone home screen
ICTOOL_RELATIVE = Path("Contents/Executables/ictool")


class IconError(ValueError):
    pass


def load_document(icon):
    icon = Path(icon)
    if not icon.is_dir() or icon.suffix != ".icon":
        raise IconError(f"{icon}: an Icon Composer document is a directory named <Name>.icon")
    manifest = icon / "icon.json"
    if not manifest.is_file():
        raise IconError(f"{manifest}: missing; Icon Composer documents keep their layers and fills in icon.json")
    try:
        document = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise IconError(f"{manifest}: not valid JSON ({error}); fix the syntax or re-save from Icon Composer") from error
    if not isinstance(document, dict):
        raise IconError(f"{manifest}: the top level must be a JSON object")
    return document


def check_document(icon):
    """Validate the document's structure; return a record of what it declares."""
    icon = Path(icon)
    document = load_document(icon)
    groups = document.get("groups")
    if not isinstance(groups, list) or not groups:
        raise IconError(f"{icon.name}: icon.json needs a non-empty \"groups\" list; each group holds \"layers\"")
    assets_dir = icon / "Assets"
    available = {path.name for path in assets_dir.iterdir() if path.is_file()} if assets_dir.is_dir() else set()
    layers, referenced = [], set()
    for index, group in enumerate(groups):
        if not isinstance(group, dict) or not isinstance(group.get("layers"), list) or not group["layers"]:
            raise IconError(f"{icon.name}: group {index} ({group.get('name', 'unnamed') if isinstance(group, dict) else '?'}) "
                            "needs a non-empty \"layers\" list")
        for layer in group["layers"]:
            if not isinstance(layer, dict):
                raise IconError(f"{icon.name}: group {group.get('name', index)!r} has a layer that is not an object")
            # A layer names one file, or one per appearance; Icon Composer then lists the default in the specializations too.
            names = [layer["image-name"]] if layer.get("image-name") else []
            names += [entry.get("value") for entry in layer.get("image-name-specializations", []) if isinstance(entry, dict)]
            if not names or not all(names):
                raise IconError(f"{icon.name}: a layer in group {group.get('name', index)!r} has no \"image-name\"; "
                                "point it at a file under Assets/")
            for name in names:
                if name not in available:
                    raise IconError(f"{icon.name}: layer {layer.get('name', name)!r} references Assets/{name}, which does not exist; "
                                    "add the file or fix \"image-name\"")
                if Path(name).suffix.lower() not in {".svg", ".png"}:
                    raise IconError(f"{icon.name}: Assets/{name} is not an SVG or PNG layer")
                referenced.add(name)
            layers.append({"group": group.get("name", f"group {index}"), "name": layer.get("name", names[0]), "image": names[0],
                           "glass": bool(layer.get("glass", True))})  # Icon Composer adds Liquid Glass to layers by default.
    unused = sorted(available - referenced)
    if unused:
        raise IconError(f"{icon.name}: Assets/ contains files no layer references ({', '.join(unused)}); "
                        "reference them from a layer or remove them")
    fill, fills = document.get("fill"), document.get("fill-specializations")
    if fill is not None and fills is None:
        # One background for every appearance, such as Icon Composer's "system-light" preset, which adapts by itself.
        if not fill:
            raise IconError(f"{icon.name}: icon.json \"fill\" is empty; use a preset such as \"system-light\" or a gradient")
        appearances = ["all"]
    else:
        if not isinstance(fills, list) or not fills:
            raise IconError(f"{icon.name}: icon.json needs a background: \"fill\" (for example \"system-light\") or "
                            "\"fill-specializations\" with a default and a dark fill")
        appearances = []
        for entry in fills:
            if not isinstance(entry, dict) or not isinstance(entry.get("value"), (dict, str)) or not entry["value"]:
                raise IconError(f"{icon.name}: every fill specialization needs a \"value\" (for example an automatic-gradient)")
            appearances.append(entry.get("appearance", "default"))
        if "default" not in appearances:
            raise IconError(f"{icon.name}: add a fill specialization without \"appearance\" for the default (light) background")
        if "dark" not in appearances:
            raise IconError(f"{icon.name}: add a fill specialization with \"appearance\": \"dark\"; without one the Dark rendition "
                            "paints the background black and fills enclosed shapes with the light colour")
    platforms = document.get("supported-platforms")
    if not isinstance(platforms, dict) or not platforms:
        raise IconError(f"{icon.name}: icon.json needs \"supported-platforms\" (Icon Composer writes {{\"squares\": \"shared\"}} for iOS)")
    return {"document": str(icon), "groups": len(groups), "layers": layers, "fillAppearances": appearances,
            "supportedPlatforms": platforms}


def find_ictool(explicit=None, environ=None):
    """The ictool executable to use, or None: --ictool, $ICTOOL, Icon Composer inside the selected Xcode, standalone."""
    environ = os.environ if environ is None else environ
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if environ.get("ICTOOL"):
        candidates.append(Path(environ["ICTOOL"]))
    if platform.system() == "Darwin":
        developer = environ.get("DEVELOPER_DIR")
        if not developer:
            try:
                developer = subprocess.run(["xcode-select", "-p"], capture_output=True, text=True, check=True).stdout.strip()
            except (OSError, subprocess.CalledProcessError):
                developer = ""
        if developer:
            candidates.append(Path(developer).parent / "Applications/Icon Composer.app" / ICTOOL_RELATIVE)
        candidates.append(Path("/Applications/Icon Composer.app") / ICTOOL_RELATIVE)
        bundled = sorted(Path("/Applications").glob("Xcode*.app/Contents/Applications/Icon Composer.app"), reverse=True)
        candidates.extend(app / ICTOOL_RELATIVE for app in bundled)
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    found = shutil.which("ictool")
    return Path(found) if found else None


def render(ictool, icon, output_dir):
    """Export each rendition at preview size plus the Default home-screen size; return the files written."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    jobs = [(rendition, PREVIEW_SIZE, 1) for rendition in RENDITIONS] + [("Default", HOME_SCREEN_SIZE, 2)]
    renders = []
    for rendition, size, scale in jobs:
        target = output_dir / f"{rendition}-{size * scale}.png"
        command = [str(ictool), str(icon), "--export-image", "--output-file", str(target), "--platform", "iOS",
                   "--rendition", rendition, "--width", str(size), "--height", str(size), "--scale", str(scale)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode or not target.is_file():
            message = (result.stderr or result.stdout).strip().splitlines()[-1:] or ["no output"]
            raise IconError(f"ictool could not render {rendition} at {size}@{scale}x: {message[0]}; "
                            "open the document in Icon Composer to see which layer or fill it rejects")
        renders.append({"rendition": rendition, "points": size, "scale": scale, "file": str(target)})
    return renders


def ictool_version(ictool):
    try:
        return subprocess.run([str(ictool), "--version"], capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("icon", nargs="?", type=Path, default=DEFAULT_ICON, help="the <Name>.icon document")
    parser.add_argument("--output", type=Path, help="directory for the rendered previews and app-icon.json")
    parser.add_argument("--ictool", type=Path, help="path to Icon Composer's ictool (default: find it)")
    parser.add_argument("--require-render", action="store_true", help="fail when ictool is unavailable")
    args = parser.parse_args(argv)
    try:
        record = check_document(args.icon)
        ictool = find_ictool(args.ictool)
        record["ictool"] = str(ictool) if ictool else None
        record["ictoolVersion"] = ictool_version(ictool) if ictool else None
        if ictool and args.output:
            record["renders"] = render(ictool, args.icon, args.output)
            record["renderSkipped"] = None
        else:
            record["renders"] = []
            record["renderSkipped"] = ("no --output directory" if ictool else
                                      "ictool not found: install Icon Composer (inside Xcode 26+) or pass --ictool")
            if args.require_render and not ictool:
                raise IconError(record["renderSkipped"])
        if args.output:
            args.output.mkdir(parents=True, exist_ok=True)
            (args.output / "app-icon.json").write_text(json.dumps(record, indent=2) + "\n")
        print("App icon verified:\n" + json.dumps(record, indent=2))
        return 0
    except IconError as error:
        print(f"App icon error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
