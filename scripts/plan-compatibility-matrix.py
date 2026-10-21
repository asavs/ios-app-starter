#!/usr/bin/env python3
"""Turn hosted runtime inventories into a test matrix; a planned lane is not coverage until it passes."""
import argparse
import json
import os
from pathlib import Path
import re

MIN_SWIFT6_XCODE_MAJOR = 16
DEVICE_PREFERENCE = ('iPhone SE (3rd generation)', 'iPhone 15', 'iPhone 16', 'iPhone 17')
SELECTIONS = ('all', 'one-per-major', 'minimum')


def version_tuple(text):
    parts = [int(part) for part in re.findall(r'\d+', str(text))[:3]]
    return tuple(parts + [0] * (3 - len(parts)))


def toolchains(inventory, min_xcode_major):
    """Swift 6-capable Xcodes on this image; schema 1 inventories expose only the default Xcode."""
    found = []
    for xcode in inventory.get('xcodes') or []:
        if xcode.get('usable') and version_tuple(xcode['version'])[0] >= min_xcode_major:
            found.append({'path': xcode['path'], 'version': xcode['version'], 'build': xcode.get('build', ''),
                          'sdk': xcode['iphoneSDK']})
    if not found and 'xcodes' not in inventory:
        match = re.match(r'Xcode (\S+)\s+Build version (\S+)', inventory.get('xcode', ''))
        if match and version_tuple(match.group(1))[0] >= min_xcode_major:
            found.append({'path': '', 'version': match.group(1), 'build': match.group(2), 'sdk': inventory['iphoneSDK']})
    return found


def pair(runtime_version, candidates):
    """Prefer the newest toolchain whose SDK major matches the runtime; else the oldest newer one."""
    major = version_tuple(runtime_version)[0]
    matching = [x for x in candidates if version_tuple(x['sdk'])[0] == major]
    if matching:
        chosen = max(matching, key=lambda x: version_tuple(x['sdk']))
        pairing = 'matched' if version_tuple(runtime_version) <= version_tuple(chosen['sdk']) else 'runtime-newer-than-sdk'
        return chosen, pairing
    newer = [x for x in candidates if version_tuple(x['sdk'])[0] > major]
    if newer:
        nearest_major = min(version_tuple(x['sdk'])[0] for x in newer)
        within = [x for x in newer if version_tuple(x['sdk'])[0] == nearest_major]
        return max(within, key=lambda x: version_tuple(x['sdk'])), 'newer-toolchain'
    return None, 'no-swift6-toolchain'


def choose_device(devices, preference):
    for name in preference:
        if name in devices:
            return name
    return next((name for name in devices if name.startswith('iPhone')), None)


def plan(inventories, selection='one-per-major', min_xcode_major=MIN_SWIFT6_XCODE_MAJOR, preference=DEVICE_PREFERENCE):
    if selection not in SELECTIONS:
        raise ValueError('Unknown selection')
    lanes, skipped = {}, []
    for inventory in inventories:
        label = inventory.get('runnerLabel') or 'unknown'
        if inventory.get('complete') is False:
            skipped.append({'runner': label, 'runtime': 'unknown', 'reason': 'inventory incomplete; inspect diagnostics'})
            continue
        candidates = toolchains(inventory, min_xcode_major)
        for runtime in inventory.get('runtimes', []):
            version = runtime['version']
            if not runtime.get('available'):
                skipped.append({'runner': label, 'runtime': version, 'reason': 'runtime unavailable'})
                continue
            xcode, pairing = pair(version, candidates)
            if xcode is None:
                skipped.append({'runner': label, 'runtime': version, 'reason': pairing})
                continue
            device = choose_device(runtime.get('devices', []), preference)
            if device is None:
                skipped.append({'runner': label, 'runtime': version, 'reason': 'no iPhone simulator'})
                continue
            lane = {'lane': 'ios-' + version.replace('.', '-'), 'runner': label,
                    'runtime_name': runtime['name'], 'runtime_version': version, 'device': device,
                    'destination': f'platform=iOS Simulator,name={device},OS={version}',
                    'xcode_path': xcode['path'], 'xcode_version': xcode['version'], 'xcode_build': xcode['build'],
                    'sdk': xcode['sdk'], 'pairing': pairing}
            previous = lanes.get(version)
            if previous is None or version_tuple(xcode['version']) > version_tuple(previous['xcode_version']):
                if previous is not None:
                    skipped.append({'runner': previous['runner'], 'runtime': version, 'reason': 'duplicate runtime; newer toolchain elsewhere'})
                lanes[version] = lane
            else:
                skipped.append({'runner': label, 'runtime': version, 'reason': 'duplicate runtime; newer toolchain elsewhere'})
    ordered = sorted(lanes.values(), key=lambda lane: version_tuple(lane['runtime_version']))
    if selection == 'minimum':
        ordered = ordered[:1]
    elif selection == 'one-per-major':
        seen, kept = set(), []
        for lane in ordered:
            major = version_tuple(lane['runtime_version'])[0]
            if major not in seen:
                seen.add(major)
                kept.append(lane)
        ordered = kept
    return {'schemaVersion': 1, 'selection': selection, 'include': ordered, 'skipped': skipped}


def summary(result):
    lines = ['## Compatibility matrix plan', '', f"Selection: `{result['selection']}`; {len(result['include'])} lane(s). "
             'Planned lanes are not coverage until their tests pass.', '',
             '| Lane | Runner | Runtime | Device | Xcode | SDK | Pairing |', '|---|---|---|---|---|---|---|']
    for lane in result['include']:
        lines.append(f"| `{lane['lane']}` | `{lane['runner']}` | {lane['runtime_name']} ({lane['runtime_version']}) | {lane['device']} | "
                     f"{lane['xcode_version']} | {lane['sdk']} | {lane['pairing']} |")
    if result['skipped']:
        lines += ['', 'Skipped:'] + [f"- `{item['runner']}` iOS {item['runtime']}: {item['reason']}" for item in result['skipped']]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', action='append', type=Path, default=[], help='Inventory JSON file; repeatable')
    parser.add_argument('--inventory-dir', type=Path, help='Directory searched for */ios-runtime-inventory.json')
    parser.add_argument('--selection', choices=SELECTIONS, default='one-per-major')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    paths = list(args.inventory)
    if args.inventory_dir:
        paths += sorted(args.inventory_dir.glob('*/ios-runtime-inventory.json')) + sorted(args.inventory_dir.glob('ios-runtime-inventory*.json'))
    if not paths:
        raise ValueError('No inventory files found')
    inventories = [json.loads(path.read_text(encoding='utf-8')) for path in paths]
    result = plan(inventories, args.selection)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    text = summary(result)
    print(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as output:
            output.write(text)
    if os.environ.get('GITHUB_OUTPUT'):
        with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as output:
            output.write('matrix=' + json.dumps({'include': result['include']}) + '\n')
            output.write(f"count={len(result['include'])}\n")
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f'Compatibility plan failed: {error}')
