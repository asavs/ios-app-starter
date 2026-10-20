#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
report_root="${IOS_TEST_OUTPUT_DIR:-$repo_dir/build/test-results}"
mkdir -p "$report_root"
report_dir="$(mktemp -d "$report_root/run.XXXXXX")"
printf 'Test reports: %s\n' "$report_dir"

# Tell the UI tests which modules this build enables (the same reading check-modules.py makes of
# the generated project) so a module's test fails, rather than skips, when its UI is missing.
# Empty when the check cannot run; the tests then skip as before.
enabled_modules="$(python3 - "$repo_dir" <<'PYMOD' 2>/dev/null || true
import importlib.util, pathlib, sys
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("check_modules", root / "scripts/check-modules.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(",".join(module.check(project=root / "StarterApp/StarterApp.xcodeproj").get("enabled", [])))
PYMOD
)"
printf 'Enabled modules: %s\n' "${enabled_modules:-(unknown)}"
export TEST_RUNNER_IOS_ENABLED_MODULES="$enabled_modules"

# The app is signed ad hoc (no certificate or team needed) with an application-identifier
# entitlement: the simulator Keychain returns errSecMissingEntitlement (-34018) to an unsigned
# app, and the Settings UI test stores a secret for real. Release signing is untouched.
# Preserve xcodebuild's failure status even when tee succeeds.
set +e
xcodebuild \
  -project "$repo_dir/StarterApp/StarterApp.xcodeproj" \
  -scheme StarterApp \
  -destination "$destination" \
  -derivedDataPath "$report_dir/DerivedData" \
  -clonedSourcePackagesDirPath "${IOS_SPM_CACHE_DIR:-$report_dir/SourcePackages}" \
  -resultBundlePath "$report_dir/Tests.xcresult" \
  -skip-testing:StarterAppUITests/StarterAppUITests/testLaunchPerformance \
  -skip-testing:StarterAppUITests/StarterAppUITestsLaunchTests \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 300 \
  -maximum-test-execution-time-allowance 300 \
  -collect-test-diagnostics "${IOS_TEST_DIAGNOSTICS:-never}" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_ENTITLEMENTS="$repo_dir/scripts/simulator-tests.entitlements" \
  test 2>&1 | tee "$report_dir/xcodebuild.log"
pipeline_status=("${PIPESTATUS[@]}")
set -e
test_status="${pipeline_status[0]}"
if [[ "$test_status" -eq 0 && "${pipeline_status[1]}" -ne 0 ]]; then
  test_status="${pipeline_status[1]}"
fi
printf '%s\n' "$test_status" > "$report_dir/exit-status.txt"

# Setup or compilation failures may not produce a readable result bundle.
if ! xcrun xcresulttool get test-results summary \
  --path "$report_dir/Tests.xcresult" \
  > "$report_dir/results.json" 2> "$report_dir/xcresulttool.log"; then
  printf 'Result summary unavailable; preserving build log.\n'
fi

# Per-test results (file:line failure messages) and test-produced attachments; both optional.
if ! xcrun xcresulttool get test-results tests \
  --path "$report_dir/Tests.xcresult" \
  > "$report_dir/tests.json" 2>> "$report_dir/xcresulttool.log"; then
  rm -f "$report_dir/tests.json"
fi
if ! xcrun xcresulttool export attachments \
  --path "$report_dir/Tests.xcresult" \
  --output-path "$report_dir/attachments" >> "$report_dir/xcresulttool.log" 2>&1; then
  printf 'Attachment export unavailable; continuing.\n'
fi

report_status=0
python3 "$repo_dir/scripts/report-tests.py" "$report_dir" "$test_status" "$destination" \
  || report_status=$?
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
exit "$report_status"
