#!/usr/bin/env python3
"""Export native Xcode/SDK/runtime inventory; availability is not test coverage."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def command(*args, env=None):
    result = subprocess.run(args, capture_output=True, text=True, timeout=60, env=env)
    if result.returncode:
        raise ValueError('Native inventory command failed; inspect tool installation/services.')
    return result.stdout.strip()


def xcode_details():
    """Describe every installed Xcode once, with the SDK its toolchain exposes."""
    seen = {}
    for path in sorted(Path('/Applications').glob('Xcode*.app')):
        real = path.resolve()
        developer = real / 'Contents/Developer'
        if not developer.is_dir():
            continue
        if str(real) in seen:
            seen[str(real)]['aliases'].append(path.name)
            continue
        entry = {'path': str(developer), 'aliases': [path.name], 'usable': False}
        env = dict(os.environ, DEVELOPER_DIR=str(developer))
        try:
            version_text = command('xcodebuild', '-version', env=env)
            match = re.match(r'Xcode (\S+)\s+Build version (\S+)', version_text)
            if match:
                entry.update(version=match.group(1), build=match.group(2),
                             iphoneSDK=command('xcrun', '--sdk', 'iphoneos', '--show-sdk-version', env=env),
                             usable=True)
        except (ValueError, subprocess.TimeoutExpired):
            pass
        seen[str(real)] = entry
    return sorted(seen.values(), key=lambda item: item['path'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runner-label', default=os.environ.get('IOS_RUNNER_LABEL', 'local'),
                        help='Hosted runner label this inventory describes, e.g. macos-14')
    args = parser.parse_args()
    runtimes = json.loads(command('xcrun', 'simctl', 'list', 'runtimes', '--json'))['runtimes']
    devices = json.loads(command('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    report = {'schemaVersion': 2, 'commit': os.environ.get('GITHUB_SHA', 'local'),
              'runner': os.environ.get('RUNNER_OS', 'local'),
              'runnerLabel': args.runner_label,
              'architecture': command('uname', '-m'),
              'xcode': command('xcodebuild', '-version'),
              'iphoneSDK': command('xcrun', '--sdk', 'iphoneos', '--show-sdk-version'),
              'installedXcodes': sorted(path.name for path in Path('/Applications').glob('Xcode*.app')),
              'xcodes': xcode_details(),
              'runtimes': []}
    for runtime in runtimes:
        if not runtime.get('name', '').startswith('iOS '):
            continue
        report['runtimes'].append({'name': runtime['name'], 'version': runtime['version'],
                                  'available': runtime.get('isAvailable') is True,
                                  'devices': sorted({device['name'] for device in devices.get(runtime['identifier'], [])})})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    lines = ['## iOS runtime inventory', '', f"Runner label: `{report['runnerLabel']}`",
             report['xcode'].replace('\n', ' / '), 'iPhone SDK: ' + report['iphoneSDK'], '',
             'Availability only; no build, boot or test coverage established.', '', 'Installed toolchains:']
    for xcode in report['xcodes']:
        lines.append('- ' + (f"Xcode {xcode['version']} ({xcode['build']}), iPhone SDK {xcode['iphoneSDK']}" if xcode['usable']
                             else 'unusable toolchain') + ': ' + ', '.join(xcode['aliases']))
    lines.append('')
    for runtime in report['runtimes']:
        lines.append('- ' + runtime['name'] + ' (' + runtime['version'] + '): ' + ('available' if runtime['available'] else 'unavailable') +
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
