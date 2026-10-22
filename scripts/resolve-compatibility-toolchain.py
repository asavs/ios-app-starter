#!/usr/bin/env python3
"""Plan and resolve an exact compatibility toolchain on the executing runner."""
import importlib.util
import json
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location('inventory', Path(__file__).with_name('inventory-ios-runtimes.py'))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


spec = importlib.util.spec_from_file_location('planner', Path(__file__).with_name('plan-compatibility-matrix.py'))
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)


def local_lane(requested, native):
    """Keep the requested runtime; select its toolchain and device from this runner only."""
    if native.get('runnerLabel') != requested['runner']:
        raise ValueError('Executing inventory runner label does not match requested lane')
    lanes = planner.plan([native], 'all')['include']
    for lane in lanes:
        if lane['runtime_version'] == requested['runtime_version']:
            return lane
    raise ValueError('Requested runtime has no usable local pairing; no runtime substitution attempted')


def resolve(lane, xcodes):
    matches = [x for x in xcodes if x.get('usable') and
               (x.get('version'), x.get('build'), x.get('iphoneSDK')) ==
               (lane['xcode_version'], lane['xcode_build'], lane['sdk'])]
    if not matches:
        raise ValueError('Planned Xcode version/build/SDK unavailable on executing runner; rerun inventory and plan. No upgrade attempted.')
    return next((x for x in matches if x['path'] == lane['xcode_path']), matches[0])


def main():
    lane = json.loads(os.environ['LANE_JSON'])
    native = json.loads((Path(os.environ['RUNNER_TEMP']) / 'ios-test-results/executing-inventory.json').read_text(encoding='utf-8'))
    xcodes = native.get('xcodes', [])
    output = Path(os.environ['RUNNER_TEMP']) / 'ios-test-results/toolchain-resolution.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {'planned': lane, 'available': xcodes, 'diagnostics': inventory.DIAGNOSTICS}
    try:
        lane = local_lane(lane, native)
        report['executing_plan'] = lane
        selected = resolve(lane, xcodes)
        report['selected'] = selected
    finally:
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as env:
        env.write('DEVELOPER_DIR=' + selected['path'] + '\n')
        env.write('IOS_TEST_DESTINATION=' + lane['destination'] + '\n')
    print('Resolved exact planned Xcode ' + selected['version'] + ' (' + selected['build'] + ') at ' + selected['path'])


if __name__ == '__main__':
    main()
