#!/usr/bin/env python3
"""Boot the workflow's selected simulator and expose startup diagnostics."""
import json
import os
import subprocess
import sys

destination = os.environ['IOS_TEST_DESTINATION']
parts = dict(part.split('=', 1) for part in destination.split(','))
if parts.get('platform') != 'iOS Simulator':
    sys.exit('IOS_TEST_DESTINATION must select an iOS Simulator')
if 'id' in parts:
    device_id = parts['id']
else:
    if not {'name', 'OS'} <= parts.keys() or parts['OS'] == 'latest':
        sys.exit('Select an explicit simulator name and OS, or a simulator id')
    runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '--json']))['runtimes']
    runtime_ids = [runtime['identifier'] for runtime in runtimes
                   if runtime.get('isAvailable') and runtime['version'] == parts['OS']
                   and runtime['name'].startswith('iOS ')]
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
    matches = [device['udid'] for runtime in runtime_ids for device in devices.get(runtime, [])
               if device['name'] == parts['name']]
    if len(matches) != 1:
        sys.exit(f'Expected one installed simulator for {destination}, found {len(matches)}; '
                 'check the pinned runner runtime/device inventory')
    device_id = matches[0]
print(f'Preparing simulator {device_id} for {destination}', flush=True)
subprocess.run(['xcrun', 'simctl', 'bootstatus', device_id, '-b'], check=True)
