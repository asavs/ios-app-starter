#!/usr/bin/env python3
"""Confirm the simulator app actually contains the validated configuration."""
import json
import os
from pathlib import Path
import plistlib
import sys

configuration, report_root = map(Path, sys.argv[1:])
expected = next(record for record in json.loads(configuration.read_text())
                if record['configuration'] == 'Debug')
matches = list(report_root.glob('run.*/DerivedData/Build/Products/Debug-iphonesimulator/StarterApp.app/Info.plist'))
if len(matches) != 1:
    sys.exit(f"Expected one built app Info.plist, found {len(matches)}")
with matches[0].open('rb') as source:
    actual = plistlib.load(source)
checks = {
    'CFBundleDisplayName': expected['displayName'],
    'CFBundleIdentifier': expected['bundleIdentifier'],
    'MinimumOSVersion': expected['minimumIOS'],
    'UIDeviceFamily': sorted(int(part.strip()) for part in expected['deviceFamilies'].split(',')),
}
# Xcode 16.2 does not copy INFOPLIST_KEY_ITSAppUsesNonExemptEncryption into the
# generated plist. Keep checking the declaration on other toolchains; for this
# compatibility lane, report the missing compiled value as unverified.
encryption_key = 'ITSAppUsesNonExemptEncryption'
if actual.get(encryption_key) is not None or os.environ.get('IOS_XCODE_VERSION') != '16.2':
    checks[encryption_key] = False
for key, value in checks.items():
    if actual.get(key) != value:
        sys.exit(f"Built app {key}: expected {value!r}, found {actual.get(key)!r}")
print('Built app configuration verified:\n' + json.dumps(checks, indent=2))
if encryption_key not in actual:
    print(f'{encryption_key} was not verified: Xcode {os.environ["IOS_XCODE_VERSION"]} omitted it from the generated Info.plist')
configuration.with_name('built-app.json').write_text(json.dumps(checks, indent=2) + '\n')
if os.environ.get('GITHUB_STEP_SUMMARY'):
    runtime = os.environ.get('IOS_TEST_DESTINATION', 'not recorded')
    artifact = os.environ.get('IOS_TEST_ARTIFACT_NAME', 'ios-test-results')
    run_url = '/'.join((os.environ.get('GITHUB_SERVER_URL', ''),
                        os.environ.get('GITHUB_REPOSITORY', ''), 'actions', 'runs',
                        os.environ.get('GITHUB_RUN_ID', '')))
    artifact_link = f'[{artifact}]({run_url})' if all((
        os.environ.get('GITHUB_SERVER_URL'), os.environ.get('GITHUB_REPOSITORY'),
        os.environ.get('GITHUB_RUN_ID'))) else f'**{artifact}**'
    summary = (
        '\n## Built app identity\n\n'
        f"- Display name: `{checks['CFBundleDisplayName']}`\n"
        f"- Bundle identifier: `{checks['CFBundleIdentifier']}`\n"
        f"- Minimum OS: `{checks['MinimumOSVersion']}`; device families: `{checks['UIDeviceFamily']}`\n"
        f'- Simulator destination: `{runtime}`\n'
        f'- Test artifacts: {artifact_link}\n'
    )
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as output:
        output.write(summary)
