#!/usr/bin/env python3
"""Give an app created from the template its own placeholder icon.

The template's AppIcon.icon is Apple's Icon Composer demo (three discs) on Apple's guide grid. This rewrites only
icon.json: each disc gets a random colour (a dimmer one in dark mode) and the three are re-arranged at Apple's
spacing along one of the grid's guide lines, in a random order and stacking. The SVGs stay as Apple made them.
Run it once after setting the app identity; run it again for another look, or pass --seed to repeat one.
"""
from __future__ import annotations

import argparse
import colorsys
import json
from pathlib import Path
import random
import secrets
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ICON = ROOT / "StarterApp" / "StarterApp" / "AppIcon.icon"
CANVAS_CENTRE = 512
SPACING = 154  # Apple's demo spaces the discs this far apart; 256 (radius) + 154 meets the grid's outer circle.
BAKED_CENTRES = {"1.circle.svg": (512, 666), "2.circle.svg": (512, 512), "3.circle.svg": (512, 358)}
DIRECTIONS = ((0, 1), (1, 0), (1, 1), (1, -1))  # the grid's vertical, horizontal and diagonal guides


class IconError(Exception):
    pass


def srgb(rgb, alpha=1.0):
    return "srgb:" + ",".join(f"{channel:.5f}" for channel in (*rgb, alpha))


def palette(rng):
    """Three pastel colours whose hues sit at least 60 degrees apart, each with a dimmer dark-mode partner."""
    base = rng.random()
    hues = [(base + offset + rng.uniform(-0.04, 0.04)) % 1 for offset in (0, 1 / 3, 2 / 3)]
    rng.shuffle(hues)
    colours = []
    for hue in hues:
        lightness, saturation = rng.uniform(0.6, 0.7), rng.uniform(0.45, 0.68)
        light = colorsys.hls_to_rgb(hue, lightness, saturation)
        dark = colorsys.hls_to_rgb(hue, lightness - 0.16, saturation * 0.85)
        colours.append((light, dark))
    return colours


def arrangement(rng):
    """Target centres for the three discs: Apple's spacing along one guide line through the centre."""
    dx, dy = rng.choice(DIRECTIONS)
    step = SPACING / (2 ** 0.5) if dx and dy else SPACING  # keep diagonal neighbours 154 apart, as on the axes
    sign = rng.choice((1, -1))
    return [(round(CANVAS_CENTRE + sign * k * dx * step), round(CANVAS_CENTRE + sign * k * dy * step)) for k in (-1, 0, 1)]


def disc_groups(document):
    discs, others = [], []
    for group in document.get("groups", []):
        names = {layer.get("image-name") for layer in group.get("layers", [])}
        (discs if len(names) == 1 and names <= BAKED_CENTRES.keys() else others).append(group)
    if len(discs) != 3:
        raise IconError("AppIcon.icon no longer has Apple's three disc groups (1.circle.svg, 2.circle.svg, 3.circle.svg); "
                        "this script only personalizes the template's placeholder. Your own icon needs no personalizing.")
    return discs, others


def personalize(document, rng):
    discs, others = disc_groups(document)
    targets = arrangement(rng)
    rng.shuffle(discs)  # front-to-back order
    summary = []
    for group, (light, dark), target in zip(discs, palette(rng), targets):
        layer = group["layers"][0]
        baked = BAKED_CENTRES[layer["image-name"]]
        group.pop("position-specializations", None)
        group["position"] = {"scale": 1, "translation-in-points": [target[0] - baked[0], target[1] - baked[1]]}
        kept = [entry for entry in layer.get("fill-specializations", []) if entry.get("appearance") not in (None, "dark")]
        layer["fill-specializations"] = ([{"value": {"solid": srgb(light)}},
                                          {"appearance": "dark", "value": {"solid": srgb(dark)}}] + kept)
        layer.pop("fill", None)
        summary.append({"layer": layer.get("name"), "centre": list(target),
                        "colour": "#" + "".join(f"{round(c * 255):02x}" for c in light)})
    document["groups"] = discs + others
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--icon", type=Path, default=DEFAULT_ICON, help="Icon Composer document (default: the app's AppIcon.icon)")
    parser.add_argument("--seed", type=int, help="repeat a previous result; omit for a new random look")
    args = parser.parse_args(argv)
    seed = args.seed if args.seed is not None else secrets.randbelow(2 ** 31)
    manifest = args.icon / "icon.json"
    try:
        document = json.loads(manifest.read_text(encoding="utf-8"))
        summary = personalize(document, random.Random(seed))
    except FileNotFoundError:
        print(f"Icon error: {manifest} not found", file=sys.stderr)
        return 1
    except (IconError, json.JSONDecodeError) as error:
        print(f"Icon error: {error}", file=sys.stderr)
        return 1
    manifest.write_text(json.dumps(document, indent=2, sort_keys=True, separators=(",", " : ")) + "\n", encoding="utf-8")
    print(f"Personalized {args.icon.name} with seed {seed} (front to back):")
    for disc in summary:
        print(f"  {disc['layer']}: {disc['colour']} at {tuple(disc['centre'])}")
    print("Check it with: python3 scripts/check-app-icon.py --output build/icon")
    return 0


if __name__ == "__main__":
    sys.exit(main())
