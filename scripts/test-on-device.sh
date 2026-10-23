#!/usr/bin/env bash
set -euo pipefail

# Runs the unit and UI tests on the connected iPhone/iPad, then removes the UI test runner
# from it; the Debug app stays installed. Same environment as scripts/run-on-device.sh
# (IOS_DEVICE, IOS_DEVELOPMENT_TEAM, IOS_SIGNING_KEYCHAIN, IOS_RUN_ON_DEVICE_DRY_RUN, ...).
IOS_DEVICE_TESTS=1 exec bash "$(dirname "${BASH_SOURCE[0]}")/run-on-device.sh" "$@"
