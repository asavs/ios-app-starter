#!/usr/bin/env bash
set -euo pipefail

# Inner loop for a Mac with a phone attached: regenerate the project, build a
# Debug app for one connected iPhone/iPad, install it with devicectl, launch
# it, and optionally stream its console. No commit, no upload, no TestFlight.
#
# Environment:
#   IOS_CONFIGURATION       starter | pocket-notes | starter-app-demo (manifest shortcut)
#   IOS_PROJECT_SPEC        explicit manifest path (default project.yml); not with IOS_CONFIGURATION
#   IOS_DEVICE              device name, identifier, or UDID when more than one phone is connected
#   IOS_DEVELOPMENT_TEAM    10-character Apple Team ID; otherwise read from the generated project
#   IOS_DEVICE_CONSOLE=1    attach the app's standard streams to this terminal until it exits
#   IOS_REGISTER_DEVICE=1   also let xcodebuild register this device in the team's portal
#   IOS_SIGNING_KEYCHAIN    keychain file whose certificates alone may sign this build; the user
#                           keychain search list is narrowed to it for xcodebuild and restored after
#   IOS_RUN_ON_DEVICE_DRY_RUN=1  print the commands that would run instead of running them
#   IOS_DEVICE_LIST_JSON    reuse a saved `devicectl list devices --json-output` file (tests, previews)
#   IOS_RUN_ON_DEVICE_OUTPUT_DIR  where logs and DerivedData go (default build/run-on-device, gitignored)
#   IOS_XCODE_VERSION       Xcode version to assume instead of asking xcodebuild (tests)
#
# Signing: a physical device needs a development team. With CODE_SIGN_STYLE=Automatic
# and -allowProvisioningUpdates, xcodebuild signs in with the Apple account already
# added to Xcode and will CREATE OR REFRESH a development certificate, App ID and
# provisioning profile for this team and device. That is an account-side change;
# expect it the first time, and set IOS_REGISTER_DEVICE=1 only when the phone is not
# yet registered in the team. Bundle identifiers are global across Apple developer
# accounts, so the default com.example.StarterApp from project.yml may not be
# provisionable under an arbitrary team. Use IOS_CONFIGURATION=starter-app-demo or a
# manifest with your own reverse-DNS identifier and DEVELOPMENT_TEAM.
#
# Signing from an SSH session: codesign reports errSecInternalComponent when the login
# keychain is locked or a key only allows use after a GUI prompt. Unlock it once per session
# (`security unlock-keychain ~/Library/Keychains/login.keychain-db`) and let Apple's tools use
# the keys without a dialog (`security set-key-partition-list -S apple-tool:,apple:,codesign:
# -s ~/Library/Keychains/login.keychain-db`); both prompt for the login password. When another
# keychain in the search list holds a development certificate for the same team whose key is
# not usable here, automatic signing may still pick it: set IOS_SIGNING_KEYCHAIN to the keychain
# that holds the working identity.

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_dir/scripts/device_selection.py"
dry_run="${IOS_RUN_ON_DEVICE_DRY_RUN:-0}"
out_dir="${IOS_RUN_ON_DEVICE_OUTPUT_DIR:-$repo_dir/build/run-on-device}"
project_dir="${IOS_PROJECT_DIR:-$repo_dir/StarterApp}"
project="$project_dir/StarterApp.xcodeproj"
derived="$out_dir/DerivedData"
build_log="$out_dir/xcodebuild.log"
mkdir -p "$out_dir"

log() { printf 'run-on-device: %s\n' "$*"; }
fail() { printf 'run-on-device: %s\n' "$*" >&2; exit 1; }
run() {
  if [[ "$dry_run" == "1" ]]; then
    printf '+'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

command -v python3 >/dev/null || fail "python3 is required."
if [[ -z "${IOS_DEVICE_LIST_JSON:-}" ]]; then
  xcrun devicectl --version >/dev/null 2>&1 \
    || fail "xcrun devicectl is unavailable; install Xcode 15 or later and select it with xcode-select."
fi

# Refraction in the app icon is an iOS 27 setting: Xcode 26's actool crashes on it
# ("attempt to insert nil object") long after the build starts, so stop here instead.
icon_json="$project_dir/StarterApp/AppIcon.icon/icon.json"
xcode_version="${IOS_XCODE_VERSION:-$(xcodebuild -version 2>/dev/null | awk 'NR == 1 { print $2 }')}"
if [[ "$xcode_version" =~ ^[0-9]+ ]] && (( ${xcode_version%%.*} < 27 )) \
  && [[ -f "$icon_json" ]] && grep -q '"refractivity"' "$icon_json"; then
  fail "AppIcon.icon uses refraction, which needs Xcode 27; Xcode $xcode_version is selected. \
Install Xcode 27 and select it with xcode-select, or remove refractivity from icon.json (docs/app-icon.md)."
fi

# 1. Manifest selection, matching the workflows' IOS_CONFIGURATION mapping.
manifest_args=()
[[ -n "${IOS_CONFIGURATION:-}" ]] && manifest_args+=(--configuration "$IOS_CONFIGURATION")
[[ -n "${IOS_PROJECT_SPEC:-}" ]] && manifest_args+=(--spec "$IOS_PROJECT_SPEC")
manifest="$(python3 "$helper" manifest "${manifest_args[@]+"${manifest_args[@]}"}")"
[[ -f "$manifest" ]] || fail "manifest not found: $manifest"
log "manifest: ${manifest#"$repo_dir/"}"

# 2. Device discovery. The JSON file is the only devicectl output meant for scripts;
#    the list is read-only, so it also runs in dry-run mode unless a saved file is given.
devices_json="${IOS_DEVICE_LIST_JSON:-$out_dir/devices.json}"
if [[ -z "${IOS_DEVICE_LIST_JSON:-}" ]]; then
  xcrun devicectl list devices --quiet --timeout 30 --json-output "$devices_json" \
    || fail "devicectl could not list devices (see output above)."
fi
select_args=()
[[ -n "${IOS_DEVICE:-}" ]] && select_args+=(--device "$IOS_DEVICE")
IFS=$'\t' read -r device_id device_udid device_name device_model device_os device_transport \
  < <(python3 "$helper" select "$devices_json" "${select_args[@]+"${select_args[@]}"}")
[[ -n "$device_id" ]] || exit 1
log "device: $device_name ($device_model, iOS $device_os, $device_transport) $device_id"

# 3. Regenerate the Xcode project from the selected manifest.
run env IOS_PROJECT_SPEC="$manifest" IOS_PROJECT_DIR="$project_dir" bash "$repo_dir/scripts/generate-project.sh"
if [[ "$dry_run" != "1" && ! -d "$project" ]]; then
  fail "project missing after generation at $project"
fi

# 4. Development team: environment first, then the generated project's DEVELOPMENT_TEAM.
settings_json="$out_dir/build-settings.json"
if [[ -z "${IOS_DEVELOPMENT_TEAM:-}" && -d "$project" ]]; then
  xcodebuild -project "$project" -scheme StarterApp -configuration Debug \
    -showBuildSettings -json > "$settings_json" 2> "$out_dir/build-settings.log" \
    || fail "xcodebuild -showBuildSettings failed; see $out_dir/build-settings.log"
  [[ "$dry_run" == "1" ]] && log "dry run: team read from the project as currently generated, not from $manifest"
fi
team_line="$(python3 "$helper" team --environment-value "${IOS_DEVELOPMENT_TEAM:-}" --build-settings-json "$settings_json")"
team="${team_line%%$'\t'*}"
team_source="${team_line#*$'\t'}"
team_help="Set IOS_DEVELOPMENT_TEAM=<10-character Apple Team ID> or put DEVELOPMENT_TEAM in the manifest. \
Xcode automatic signing (-allowProvisioningUpdates) will then create or refresh a development \
profile for that team and this device, which changes the team's account state."
if [[ -z "$team" ]]; then
  if [[ "$dry_run" == "1" ]]; then
    log "warning: no development team found. $team_help"
    team='<IOS_DEVELOPMENT_TEAM>'; team_source='placeholder'
  else
    fail "no development team found. $team_help"
  fi
fi
log "team: $team (from $team_source)"

# 5. Build for the device SDK with automatic signing. xcodebuild identifies a
#    physical device by UDID (see -showdestinations); devicectl uses its own identifier.
provisioning_args=(-allowProvisioningUpdates)
[[ "${IOS_REGISTER_DEVICE:-0}" == "1" ]] && provisioning_args+=(-allowProvisioningDeviceRegistration)
build_cmd=(xcodebuild
  -project "$project"
  -scheme StarterApp
  -configuration Debug
  -destination "id=$device_udid"
  -derivedDataPath "$derived"
  "${provisioning_args[@]}"
  CODE_SIGN_STYLE=Automatic
  "DEVELOPMENT_TEAM=$team"
  build)
# Optionally narrow the user keychain search list to one keychain while xcodebuild signs, so
# automatic signing cannot pick a same-team certificate whose key lives in another keychain.
# The previous list is restored on every exit path, including a failed build.
saved_keychains=()
restore_keychains() {
  if (( ${#saved_keychains[@]} )); then
    run security list-keychains -d user -s "${saved_keychains[@]}"
    saved_keychains=()
  fi
}
if [[ -n "${IOS_SIGNING_KEYCHAIN:-}" ]]; then
  [[ "$dry_run" == "1" || -f "$IOS_SIGNING_KEYCHAIN" ]] || fail "IOS_SIGNING_KEYCHAIN not found: $IOS_SIGNING_KEYCHAIN"
  if [[ "$dry_run" == "1" ]]; then
    saved_keychains=('<current user keychain search list>')
  else
    while IFS= read -r line; do
      line="${line#"${line%%[![:space:]]*}"}"; line="${line%\"}"; line="${line#\"}"
      [[ -n "$line" ]] && saved_keychains+=("$line")
    done < <(security list-keychains -d user)
    (( ${#saved_keychains[@]} )) || fail "could not read the user keychain search list"
  fi
  log "signing keychain: $IOS_SIGNING_KEYCHAIN (search list restored after the build)"
  trap restore_keychains EXIT
  run security list-keychains -d user -s "$IOS_SIGNING_KEYCHAIN"
fi
if [[ "$dry_run" == "1" ]]; then
  run "${build_cmd[@]}"
  log "build log would be written to $build_log"
else
  log "building; log: $build_log"
  set +e
  "${build_cmd[@]}" 2>&1 | tee "$build_log"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  build_status="${pipeline_status[0]}"
  if [[ "$build_status" -eq 0 && "${pipeline_status[1]}" -ne 0 ]]; then
    build_status="${pipeline_status[1]}"
  fi
  if [[ "$build_status" -ne 0 ]]; then
    fail "build failed (exit $build_status). Signing errors usually mean the team cannot provision \
this bundle identifier or device, or that codesign cannot use the key from this session; see the \
header of this script and $build_log"
  fi
fi
restore_keychains
trap - EXIT

# 6. Locate the device (.app) product and read its bundle identifier.
app="$derived/Build/Products/Debug-iphoneos/StarterApp.app"
if [[ ! -d "$app" && -d "$derived/Build/Products" ]]; then
  app="$(find "$derived/Build/Products" -maxdepth 2 -type d -name '*.app' -path '*-iphoneos/*' | head -n 1)"
fi
if [[ -d "$app" ]]; then
  bundle_id="$(python3 "$helper" bundle-id "$app")"
elif [[ "$dry_run" == "1" ]]; then
  app="$derived/Build/Products/Debug-iphoneos/StarterApp.app"
  bundle_id='<CFBundleIdentifier from the built Info.plist>'
else
  fail "no device .app found under $derived/Build/Products"
fi

# 7. Install, then launch (foreground, replacing any running instance).
run xcrun devicectl device install app --device "$device_id" --json-output "$out_dir/install.json" "$app"
# Options go before the bundle identifier; anything after it is passed to the app.
launch_cmd=(xcrun devicectl device process launch --device "$device_id" --terminate-existing
  --json-output "$out_dir/launch.json")
[[ "${IOS_DEVICE_CONSOLE:-0}" == "1" ]] && launch_cmd+=(--console)
launch_cmd+=("$bundle_id")

summary() {
  cat <<EOF

run-on-device summary
  device:      $device_name ($device_model, iOS $device_os) $device_id
  app:         $app
  bundle id:   $bundle_id
  build log:   $build_log
  relaunch without rebuilding:
    xcrun devicectl device process launch --device $device_id --terminate-existing $bundle_id
  reinstall without rebuilding:
    xcrun devicectl device install app --device $device_id "$app"
EOF
}

if [[ "${IOS_DEVICE_CONSOLE:-0}" == "1" ]]; then
  summary
  log "console attached; Ctrl-C stops the app and returns."
  run "${launch_cmd[@]}"
else
  run "${launch_cmd[@]}"
  summary
fi
