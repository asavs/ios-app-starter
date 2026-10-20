#!/usr/bin/env bash
set -euo pipefail

# Builds the module library and runs one module's tests on an iOS simulator, with the same
# report layout as scripts/test-ios.sh. Usage: bash scripts/test-module.sh <Module>
# Xcode derives schemes from Package.swift: with one product, a single scheme named after the
# package; with several, one scheme per product plus "<Package>-Package". Only the package-wide
# scheme has a test action (per-product schemes report "not currently configured for the test
# action"), so the module is selected with -only-testing on that scheme's <Module>Tests target.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="${1:-}"
if [[ -z "$module" || ! -d "$repo_dir/Modules/$module" ]]; then
  printf 'Usage: %s <Module>\nModules:\n' "$0" >&2
  ls "$repo_dir/Modules" >&2
  exit 2
fi
destination="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
report_root="${IOS_TEST_OUTPUT_DIR:-$repo_dir/build/test-results}"
mkdir -p "$report_root"
report_dir="$(mktemp -d "$report_root/module-$module.XXXXXX")"
printf 'Test reports: %s\n' "$report_dir"

cd "$repo_dir" # xcodebuild reads Package.swift from the working directory; there is no project here.
scheme="$(xcodebuild -list -json 2>/dev/null | python3 -c '
import json, sys
schemes = json.load(sys.stdin).get("workspace", {}).get("schemes", [])
for candidate in ("StarterModules-Package", "StarterModules"):
    if candidate in schemes:
        print(candidate)
        break
else:
    sys.exit("no package-wide scheme among " + ", ".join(schemes))
')"
printf 'Scheme: %s\n' "$scheme"
set +e
xcodebuild \
  -scheme "$scheme" \
  -destination "$destination" \
  -derivedDataPath "$report_dir/DerivedData" \
  -clonedSourcePackagesDirPath "${IOS_SPM_CACHE_DIR:-$report_dir/SourcePackages}" \
  -resultBundlePath "$report_dir/Tests.xcresult" \
  -only-testing:"${module}Tests" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 300 \
  -maximum-test-execution-time-allowance 300 \
  CODE_SIGNING_ALLOWED=NO \
  test 2>&1 | tee "$report_dir/xcodebuild.log"
pipeline_status=("${PIPESTATUS[@]}")
set -e
test_status="${pipeline_status[0]}"
if [[ "$test_status" -eq 0 && "${pipeline_status[1]}" -ne 0 ]]; then
  test_status="${pipeline_status[1]}"
fi
printf '%s\n' "$test_status" > "$report_dir/exit-status.txt"

if ! xcrun xcresulttool get test-results summary \
  --path "$report_dir/Tests.xcresult" \
  > "$report_dir/results.json" 2> "$report_dir/xcresulttool.log"; then
  printf 'Result summary unavailable; preserving build log.\n'
fi
if ! xcrun xcresulttool get test-results tests \
  --path "$report_dir/Tests.xcresult" \
  > "$report_dir/tests.json" 2>> "$report_dir/xcresulttool.log"; then
  rm -f "$report_dir/tests.json"
fi

report_status=0
python3 "$repo_dir/scripts/report-tests.py" "$report_dir" "$test_status" "$destination" \
  || report_status=$?
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
exit "$report_status"
