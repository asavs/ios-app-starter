#!/usr/bin/env python3
"""Generate the starter's blueprint app icon as an Icon Composer document, using only Python's standard library.

Writes StarterApp/StarterApp/AppIcon.icon (SVG layers over a native gradient, with Dark and Tinted variants) and a
flattened design/starter-icon.svg preview. Xcode 26+ compiles the .icon and generates the older-iOS PNGs from it.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
INK = '#ffffff'
LIGHT = ('#4aa8f5', '#1459c7')  # blueprint paper, top to bottom
DARK = ('#163566', '#07122d')


def svg(body, background=''):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
            f'{background}{body}</svg>\n')


def grid():
    lines = []
    for i in range(0, SIZE + 1, 64):
        major = i % 256 == 0
        attrs = f'stroke="{INK}" stroke-opacity="{0.26 if major else 0.12}" stroke-width="{3 if major else 2}"'
        lines.append(f'<line x1="{i}" y1="0" x2="{i}" y2="{SIZE}" {attrs}/><line x1="0" y1="{i}" x2="{SIZE}" y2="{i}" {attrs}/>')
    return ''.join(lines)


def construction(cx=512, cy=512, r=360):
    """Dashed construction circle, dash-dot centre lines, a measured radial slice and a dimension arrow beneath."""
    x1, x2, y, head = 160, 864, 880, 30
    return (angle(cx, cy, r) + f'<g fill="none" stroke="{INK}" stroke-opacity="0.72" stroke-width="10">'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke-dasharray="58 36"/>'
            f'<line x1="{cx - r - 60}" y1="{cy}" x2="{cx + r + 60}" y2="{cy}" stroke-dasharray="96 28 20 28"/>'
            f'<line x1="{cx}" y1="{cy - r - 60}" x2="{cx}" y2="{cy + r + 60}" stroke-dasharray="96 28 20 28"/></g>'
            f'<g stroke="{INK}" stroke-opacity="0.9" stroke-width="10" fill="none" stroke-linecap="round">'
            f'<line x1="{x1}" y1="{y - 38}" x2="{x1}" y2="{y + 38}"/><line x1="{x2}" y1="{y - 38}" x2="{x2}" y2="{y + 38}"/>'
            f'<line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}"/></g>'
            f'<g fill="{INK}" fill-opacity="0.9">'
            f'<polygon points="{x1},{y} {x1 + head * 1.8},{y - head / 2} {x1 + head * 1.8},{y + head / 2}"/>'
            f'<polygon points="{x2},{y} {x2 - head * 1.8},{y - head / 2} {x2 - head * 1.8},{y + head / 2}"/></g>')


def angle(cx, cy, r, degrees=40, arc=170, head=30):
    """A radius at `degrees` above the horizontal centre line, the slice it cuts and an arrowed arc measuring it."""
    t = math.radians(degrees)
    ex, ey = cx + r * math.cos(t), cy - r * math.sin(t)
    ax, ay = cx + arc * math.cos(t), cy - arc * math.sin(t)
    # Arrowhead at the arc's end, pointing along the arc's tangent (counter-clockwise on screen).
    tx, ty = -math.sin(t), -math.cos(t)
    nx, ny = math.cos(t), -math.sin(t)
    tip = (ax, ay)
    back = (ax - tx * head * 1.8, ay - ty * head * 1.8)
    wings = [(back[0] + nx * head / 2, back[1] + ny * head / 2), (back[0] - nx * head / 2, back[1] - ny * head / 2)]
    points = ' '.join(f'{x:.1f},{y:.1f}' for x, y in (tip, *wings))
    return (f'<path d="M {cx} {cy} L {cx + r} {cy} A {r} {r} 0 0 0 {ex:.1f} {ey:.1f} Z" fill="{INK}" fill-opacity="0.16"/>'
            f'<g fill="none" stroke="{INK}" stroke-opacity="0.9" stroke-width="10" stroke-linecap="round">'
            f'<line x1="{cx}" y1="{cy}" x2="{ex:.1f}" y2="{ey:.1f}"/>'
            f'<path d="M {cx + arc} {cy} A {arc} {arc} 0 0 0 {back[0]:.1f} {back[1]:.1f}"/></g>'
            f'<polygon points="{points}" fill="{INK}" fill-opacity="0.9"/>'
            f'<circle cx="{cx}" cy="{cy}" r="14" fill="{INK}" fill-opacity="0.9"/>')


def srgb(hex_color):
    return 'extended-srgb:' + ','.join(f'{int(hex_color[i:i + 2], 16) / 255:.5f}' for i in (1, 3, 5)) + ',1.00000'


def gradient(colors, appearance=None):
    spec = {'value': {'linear-gradient': [srgb(c) for c in colors],
                      'orientation': {'start': {'x': 0.5, 'y': 0}, 'stop': {'x': 0.5, 'y': 1}}}}
    return {'appearance': appearance, **spec} if appearance else spec


def group(name, opacity):
    return {'name': name, 'layers': [{'name': name, 'image-name': f'{name.lower()}.svg', 'glass': False, 'fill': 'none',
                                      'opacity-specializations': opacity}],
            'shadow': {'kind': 'none', 'opacity': 0.5}, 'translucency': {'enabled': False, 'value': 0.5}, 'specular': False}


def main():
    document = ROOT / 'StarterApp/StarterApp/AppIcon.icon'
    (document / 'Assets').mkdir(parents=True, exist_ok=True)
    (document / 'Assets/construction.svg').write_text(svg(construction()))
    (document / 'Assets/grid.svg').write_text(svg(grid()))
    (document / 'icon.json').write_text(json.dumps({
        'fill-specializations': [gradient(LIGHT), gradient(DARK, 'dark')],
        'groups': [
            group('Construction', [{'value': 1}, {'appearance': 'tinted', 'value': 0.6}]),
            group('Grid', [{'value': 1}, {'appearance': 'dark', 'value': 0.7}, {'appearance': 'tinted', 'value': 0.4}]),
        ],
        'supported-platforms': {'squares': 'shared'},
    }, indent=2) + '\n')
    paper = (f'<defs><linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{LIGHT[0]}"/>'
             f'<stop offset="1" stop-color="{LIGHT[1]}"/></linearGradient></defs><rect width="{SIZE}" height="{SIZE}" fill="url(#paper)"/>')
    design = ROOT / 'design'; design.mkdir(exist_ok=True)
    (design / 'starter-icon.svg').write_text(svg(grid() + construction(), paper))
    print('Generated StarterApp/StarterApp/AppIcon.icon and the flattened design/starter-icon.svg preview.')


if __name__ == '__main__': main()
