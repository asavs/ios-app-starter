#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
report_root="${IOS_TEST_OUTPUT_DIR:-$repo_dir/build/test-results}"
mkdir -p "$report_root"
report_dir="$(mktemp -d "$report_root/run.XXXXXX")"
printf 'Test reports: %s\n' "$report_dir"

# IOS_TEST_ACTION: `test` (the default) builds and tests in one go; `build` only builds for testing and
# leaves the products, with their .xctestrun, under the report's DerivedData/Build/Products; `run` tests
# a build made that way, named by IOS_XCTESTRUN, without building. CI builds each configuration once
# and runs its lanes from that build, since building took 5 to 12 minutes of every lane (2026-11-07).
action="${IOS_TEST_ACTION:-test}"
case "$action" in
  test|build) ;;
  run)
    if [[ -z "${IOS_XCTESTRUN:-}" || ! -f "$IOS_XCTESTRUN" ]]; then
      echo "test-ios: IOS_TEST_ACTION=run needs IOS_XCTESTRUN, the .xctestrun file of a build made with IOS_TEST_ACTION=build" >&2
      exit 2
    fi ;;
  *) echo "test-ios: unknown IOS_TEST_ACTION '$action' (test, build or run)" >&2; exit 2 ;;
esac
printf 'Action: %s\n' "$action"

# Tell the UI tests which modules this build enables (the same reading check-modules.py makes of
# the generated project) so a module's test fails, rather than skips, when its UI is missing.
# Empty when the check cannot run; the tests then skip as before. IOS_ENABLED_MODULES, when set, is
# used as given: a lane running a prebuilt app has the build's list and no generated project.
if [[ -n "${IOS_ENABLED_MODULES+set}" ]]; then
  enabled_modules="$IOS_ENABLED_MODULES"
else
enabled_modules="$(python3 - "$repo_dir" <<'PYMOD' 2>/dev/null || true
import importlib.util, pathlib, sys
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("check_modules", root / "scripts/check-modules.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(",".join(module.check(project=root / "StarterApp/StarterApp.xcodeproj").get("enabled", [])))
PYMOD
)"
fi
printf 'Enabled modules: %s\n' "${enabled_modules:-(unknown)}"
export TEST_RUNNER_IOS_ENABLED_MODULES="$enabled_modules"

# Only Xcode 27 compiles AppIcon.icon as Icon Composer 27 saves it: Xcode 16, which the lanes for
# iOS 17 and 18 simulators need, cannot read an Icon Composer document at all ("None of the input
# catalogs contained a matching ... app icon set named AppIcon"), and Xcode 26's actool crashes on its
# top-level "features" list ("attempt to insert nil object"). Those lanes test behaviour, not the
# icon, so build them without one; the icon users get, including the iOS 17 fallback PNGs, comes from
# Xcode 27's actool.
icon_settings=()
xcode_major="$(xcodebuild -version 2>/dev/null | awk 'NR == 1 { split($2, v, "."); print v[1] }')"
if [[ "$xcode_major" =~ ^[0-9]+$ ]] && (( xcode_major < 27 )); then
  printf 'Xcode %s cannot compile AppIcon.icon; building without an app icon.\n' "$xcode_major"
  icon_settings=(ASSETCATALOG_COMPILER_APPICON_NAME=)
fi

# UI tests run on parallel simulator clones when IOS_TEST_WORKERS is above 1: XCTest hands each test
# class to a clone, which is why StarterAppUITests is split into classes by area. Each clone has its
# own data container, so tests that store defaults, a Keychain secret or a database store don't
# collide. Serial by default: measured on 2026-11-01, two clones ran each test about twice as slowly on
# a Mac and never came up on the hosted runner (docs/ci.md), so the switch is for the next attempt.
workers="${IOS_TEST_WORKERS:-1}"

# IOS_TEST_LANE picks the test classes: `shell` (the unit tests, the shell, theme and deep links, and
# onboarding), `features` (the Timer, Attachments and Settings classes) or `tabs` (the tab chooser, Library
# and Notes); unset or `all` runs everything.
# CI runs the lanes as separate jobs, each with its own simulator, since one runner takes over 25
# minutes for the whole suite (ios-6dd.13). The classes are listed here so the workflow needn't know them.
lane_settings=()
case "${IOS_TEST_LANE:-all}" in
  shell)
    lane_settings=(-only-testing:StarterAppTests -only-testing:StarterAppUITests/StarterAppUITests
      -only-testing:StarterAppUITests/OnboardingUITests) ;;
  features)
    lane_settings=(-only-testing:StarterAppUITests/TimerUITests -only-testing:StarterAppUITests/AttachmentsUITests
      -only-testing:StarterAppUITests/SettingsUITests) ;;
  tabs)
    lane_settings=(-only-testing:StarterAppUITests/TabChoicesUITests -only-testing:StarterAppUITests/LibraryUITests
      -only-testing:StarterAppUITests/NotesUITests) ;;
  identity)
    # Only what depends on the app's own name, bundle identifiers and URL scheme, for a configuration
    # whose content is the starter's (pocket-notes, the template made into someone's app): the scheme
    # registered and round-tripped, a launch that opens a tab by its link, and a secret kept in the
    # Keychain under the app's identity. The build job checks the built app's name and identifiers.
    lane_settings=(-only-testing:StarterAppTests/DeepLinkTests
      -only-testing:StarterAppUITests/StarterAppUITests/testDeepLinkSelectsTab
      -only-testing:StarterAppUITests/SettingsUITests/testSettingsScreen) ;;
  all) ;;
  *) echo "test-ios: unknown IOS_TEST_LANE '$IOS_TEST_LANE' (shell, features, tabs, identity or all)" >&2; exit 2 ;;
esac
printf 'Test lane: %s\n' "${IOS_TEST_LANE:-all}"
parallel_settings=(-parallel-testing-enabled NO)
if [[ "$workers" =~ ^[0-9]+$ ]] && (( workers > 1 )); then
  parallel_settings=(-parallel-testing-enabled YES -parallel-testing-worker-count "$workers")
fi
printf 'Test workers: %s\n' "$workers"

# IOS_TEST_ATTEMPTS above 1 runs a failed test again, up to that many attempts in all; a test passes if
# any attempt does, and the report lists every test that needed a second one ("Passed on retry"), so
# a flaky test stays visible without failing the run. CI sets 2: on loaded hosted runners single UI
# queries have taken 8 to 30 s and failed tests that pass on a quieter runner (2026-11-07). Local runs
# default to one attempt, where a failure is worth seeing at once.
attempts="${IOS_TEST_ATTEMPTS:-1}"
retry_settings=()
if [[ "$attempts" =~ ^[0-9]+$ ]] && (( attempts > 1 )); then
  retry_settings=(-retry-tests-on-failure -test-iterations "$attempts")
fi
printf 'Test attempts: %s\n' "$attempts"

# The app is signed ad hoc (no certificate or team needed) with an application-identifier
# entitlement: the simulator Keychain returns errSecMissingEntitlement (-34018) to an unsigned
# app, and the Settings UI test stores a secret for real. Release signing is untouched.
# Preserve xcodebuild's failure status even when tee succeeds.
source_settings=(
  -project "$repo_dir/StarterApp/StarterApp.xcodeproj"
  -scheme StarterApp
  -derivedDataPath "$report_dir/DerivedData"
  -clonedSourcePackagesDirPath "${IOS_SPM_CACHE_DIR:-$report_dir/SourcePackages}"
)
build_settings=(
  CODE_SIGN_IDENTITY=-
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_ENTITLEMENTS="$repo_dir/scripts/simulator-tests.entitlements"
  ${icon_settings[@]+"${icon_settings[@]}"}
)
test_settings=(
  -skip-testing:StarterAppUITests/StarterAppUITests/testLaunchPerformance
  -skip-testing:StarterAppUITests/StarterAppUITestsLaunchTests
  ${lane_settings[@]+"${lane_settings[@]}"}
  "${parallel_settings[@]}"
  -test-timeouts-enabled YES
  -default-test-execution-time-allowance 300
  -maximum-test-execution-time-allowance 300
  -collect-test-diagnostics "${IOS_TEST_DIAGNOSTICS:-never}"
  ${retry_settings[@]+"${retry_settings[@]}"}
)
case "$action" in
  test) command=("${source_settings[@]}" "${test_settings[@]}" "${build_settings[@]}" test) ;;
  build) command=("${source_settings[@]}" "${build_settings[@]}" build-for-testing) ;;
  run) command=(-xctestrun "$IOS_XCTESTRUN" "${test_settings[@]}" test-without-building) ;;
esac
set +e
xcodebuild -destination "$destination" -resultBundlePath "$report_dir/Tests.xcresult" "${command[@]}" \
  2>&1 | tee "$report_dir/xcodebuild.log"
pipeline_status=("${PIPESTATUS[@]}")
set -e
test_status="${pipeline_status[0]}"
if [[ "$test_status" -eq 0 && "${pipeline_status[1]}" -ne 0 ]]; then
  test_status="${pipeline_status[1]}"
fi
printf '%s\n' "$test_status" > "$report_dir/exit-status.txt"

# A build for testing has no test results to read; the report explains a failed build from its log.
if [[ "$action" == build ]]; then
  if [[ "$test_status" -ne 0 ]]; then
    python3 "$repo_dir/scripts/report-tests.py" "$report_dir" "$test_status" "$destination" || true
  fi
  exit "$test_status"
fi

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

# Export existing session logs after a failure; this does not enable expensive diagnostics collection.
if [[ "$test_status" -ne 0 ]]; then
  if ! xcrun xcresulttool export diagnostics --path "$report_dir/Tests.xcresult" \
    --output-path "$report_dir/diagnostics" >> "$report_dir/xcresulttool.log" 2>&1; then
    printf 'Diagnostic log export unavailable; preserving the failed result.\n'
  fi
fi

report_status=0
python3 "$repo_dir/scripts/report-tests.py" "$report_dir" "$test_status" "$destination" \
  || report_status=$?
if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
exit "$report_status"
