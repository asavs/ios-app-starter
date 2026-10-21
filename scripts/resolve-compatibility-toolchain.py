#!/usr/bin/env python3
"""Resolve the exact planned compatibility toolchain on this executing runner."""
import importlib.util
import json
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location('inventory', Path(__file__).with_name('inventory-ios-runtimes.py'))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def resolve(lane, xcodes):
    matches = [x for x in xcodes if x.get('usable') and
               (x.get('version'), x.get('build'), x.get('iphoneSDK')) ==
               (lane['xcode_version'], lane['xcode_build'], lane['sdk'])]
    if not matches:
        raise ValueError('Planned Xcode version/build/SDK unavailable on executing runner; rerun inventory and plan. No upgrade attempted.')
    return next((x for x in matches if x['path'] == lane['xcode_path']), matches[0])


def main():
    lane = json.loads(os.environ['LANE_JSON'])
    xcodes = inventory.xcode_details()
    output = Path(os.environ['RUNNER_TEMP']) / 'ios-test-results/toolchain-resolution.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {'planned': lane, 'available': xcodes, 'diagnostics': inventory.DIAGNOSTICS}
    try:
        selected = resolve(lane, xcodes)
        report['selected'] = selected
    finally:
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as env:
        env.write('DEVELOPER_DIR=' + selected['path'] + '\n')
    print('Resolved exact planned Xcode ' + selected['version'] + ' (' + selected['build'] + ') at ' + selected['path'])


if __name__ == '__main__':
    main()
