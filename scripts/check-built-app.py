#!/usr/bin/env python3
"""Confirm the simulator app actually contains the validated configuration."""
import json
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
for key, value in checks.items():
    if actual.get(key) != value:
        sys.exit(f"Built app {key}: expected {value!r}, found {actual.get(key)!r}")
print('Built app configuration verified:\n' + json.dumps(checks, indent=2))
configuration.with_name('built-app.json').write_text(json.dumps(checks, indent=2) + '\n')
