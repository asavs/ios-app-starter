#!/usr/bin/env python3
"""Export native Xcode/SDK/runtime inventory; availability is not test coverage."""
import argparse
import json
import os
from pathlib import Path
import subprocess


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError('Native inventory command failed; inspect tool installation/services.')
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    runtimes = json.loads(command('xcrun', 'simctl', 'list', 'runtimes', '--json'))['runtimes']
    devices = json.loads(command('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    report = {'schemaVersion': 1, 'commit': os.environ.get('GITHUB_SHA', 'local'),
              'runner': os.environ.get('RUNNER_OS', 'local'),
              'architecture': command('uname', '-m'),
              'xcode': command('xcodebuild', '-version'),
              'iphoneSDK': command('xcrun', '--sdk', 'iphoneos', '--show-sdk-version'),
              'installedXcodes': sorted(path.name for path in Path('/Applications').glob('Xcode*.app')),
              'runtimes': []}
    for runtime in runtimes:
        if not runtime.get('name', '').startswith('iOS '):
            continue
        report['runtimes'].append({'name': runtime['name'], 'version': runtime['version'],
                                  'available': runtime.get('isAvailable') is True,
                                  'devices': sorted({device['name'] for device in devices.get(runtime['identifier'], [])})})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    lines = ['## iOS runtime inventory', '', report['xcode'].replace('\n', ' / '),
             'iPhone SDK: ' + report['iphoneSDK'], '', 'Availability only; no build, boot or test coverage established.', '']
    for runtime in report['runtimes']:
        lines.append('- ' + runtime['name'] + ': ' + ('available' if runtime['available'] else 'unavailable') +
                     '; device names: ' + ', '.join(runtime['devices']))
    content = '\n'.join(lines) + '\n'
    print(content)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as output:
            output.write(content)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        raise SystemExit('Native inventory incomplete; no coverage claim established.')
