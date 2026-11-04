#!/usr/bin/env python3
"""Boot the workflow's selected simulator and expose startup diagnostics."""
import json
import os
import subprocess
import sys
import time

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
# Booted isn't settled: on a simulator booted seconds earlier, the UI test runner twice died in XCTest's
# stall detector while bootstrapping ("operation never finished bootstrapping", abort in XCTWaiter
# handleStalledWait), locally and on the hosted runner (2026-11-03, ios-6dd.13); the same simulators
# passed every time once they had been up for half a minute. Launching and quitting a system app
# exercises SpringBoard's launch path, then a short wait lets the daemons finish coming up.
subprocess.run(['xcrun', 'simctl', 'launch', device_id, 'com.apple.Preferences'], check=False,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
subprocess.run(['xcrun', 'simctl', 'terminate', device_id, 'com.apple.Preferences'], check=False,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(int(os.environ.get('IOS_SIMULATOR_SETTLE_SECONDS', '20')))
print('Simulator settled', flush=True)
