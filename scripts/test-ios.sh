#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
report_root="${IOS_TEST_OUTPUT_DIR:-$repo_dir/build/test-results}"
mkdir -p "$report_root"
report_dir="$(mktemp -d "$report_root/run.XXXXXX")"
printf 'Test reports: %s\n' "$report_dir"

# Preserve xcodebuild's failure status even when tee succeeds.
set +e
xcodebuild \
  -project "$repo_dir/StarterApp/StarterApp.xcodeproj" \
  -scheme StarterApp \
  -destination "$destination" \
  -derivedDataPath "$report_dir/DerivedData" \
  -resultBundlePath "$report_dir/Tests.xcresult" \
  -only-testing:StarterAppUITests/StarterAppUITests/testWelcomeScreen \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 \
  -maximum-test-execution-time-allowance 120 \
  CODE_SIGNING_ALLOWED=NO \
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

report_status=0
python3 "$repo_dir/scripts/report-tests.py" "$report_dir" "$test_status" "$destination" \
  || report_status=$?
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
exit "$report_status"
