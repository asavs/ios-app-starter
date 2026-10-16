#!/usr/bin/env python3
"""Pure helpers behind scripts/run-on-device.sh: device choice, manifest, team, bundle id.

Everything here reads files the shell script already produced (a devicectl
JSON export, an xcodebuild -showBuildSettings export, a built .app) so the
decisions are unit-testable without a Mac, a device, or an Apple account.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = {
    "starter": "project.yml",
    "pocket-notes": "examples/pocket-notes.yml",
    "starter-app-demo": "examples/starter-app-demo.yml",
}
TEAM_ID = re.compile(r"[A-Z0-9]{10}\Z")
DEVICE_TYPES = {"iPhone", "iPad"}

NO_DEVICE_HELP = (
    "No connected, paired iPhone or iPad was found.\n"
    "  - Connect the device over USB, or make sure it is on the same Wi-Fi network and\n"
    "    was previously paired with this Mac (devicectl lists Wi-Fi devices as\n"
    "    'localNetwork' transport).\n"
    "  - Unlock the phone and tap 'Trust' if it asks whether to trust this computer.\n"
    "  - Turn on Developer Mode on the phone: Settings > Privacy & Security >\n"
    "    Developer Mode (iOS 16+), then restart the phone when asked.\n"
    "  - Re-check with: xcrun devicectl list devices"
)


class SelectionError(Exception):
    """A clear, user-facing reason no single device could be chosen."""


def manifest_for(configuration=None, spec=None):
    """Map IOS_CONFIGURATION / IOS_PROJECT_SPEC to one manifest path, as the workflows do."""
    if configuration:
        if configuration not in MANIFESTS:
            raise SelectionError(
                f"Unsupported IOS_CONFIGURATION {configuration!r}; use one of: "
                + ", ".join(sorted(MANIFESTS)))
        if spec and Path(spec).resolve() != (ROOT / MANIFESTS[configuration]).resolve():
            raise SelectionError(
                "IOS_CONFIGURATION and IOS_PROJECT_SPEC disagree; set only one of them.")
        return str(ROOT / MANIFESTS[configuration])
    if spec:
        return spec
    return str(ROOT / MANIFESTS["starter"])


def summarize(device):
    connection = device.get("connectionProperties", {})
    properties = device.get("deviceProperties", {})
    hardware = device.get("hardwareProperties", {})
    return {
        "identifier": str(device.get("identifier", "")),
        # xcodebuild -showdestinations lists physical devices by UDID, devicectl by its own identifier.
        "udid": str(hardware.get("udid") or device.get("identifier", "")),
        "name": str(properties.get("name", "")),
        "model": str(hardware.get("marketingName") or hardware.get("productType") or ""),
        "os": str(properties.get("osVersionNumber", "")),
        "transport": str(connection.get("transportType", "")),
        "developerMode": str(properties.get("developerModeStatus", "")),
    }


def _is_candidate(device):
    """A physical iPhone/iPad that is paired and currently reachable.

    devicectl's table prints 'available' when the JSON tunnelState is anything
    other than 'unavailable' (observed with Xcode 26.6: a reachable Wi-Fi phone
    reports 'disconnected' until a tunnel is opened). Pairing and the hardware
    class come straight from the JSON record.
    """
    connection = device.get("connectionProperties", {})
    hardware = device.get("hardwareProperties", {})
    return (connection.get("pairingState") == "paired"
            and connection.get("tunnelState", "unavailable") != "unavailable"
            and hardware.get("reality", "physical") == "physical"
            and hardware.get("platform") == "iOS"
            and hardware.get("deviceType") in DEVICE_TYPES
            and bool(device.get("identifier")))


def _describe(device):
    summary = summarize(device)
    return f"{summary['name']} ({summary['model']}, iOS {summary['os']}, {summary['identifier']})"


def select_device(payload, requested=None):
    """Choose the device to use from a `devicectl list devices --json-output` payload."""
    if payload.get("info", {}).get("outcome", "success") != "success":
        raise SelectionError("devicectl could not list devices; run 'xcrun devicectl list devices' to see why.")
    devices = payload.get("result", {}).get("devices", [])
    if not isinstance(devices, list):
        raise SelectionError("devicectl JSON output did not contain a device list.")
    candidates = [device for device in devices if isinstance(device, dict) and _is_candidate(device)]
    if requested:
        wanted = requested.strip()
        matches = [device for device in candidates
                   if wanted in (str(device.get("identifier")),
                                 str(device.get("deviceProperties", {}).get("name", "")),
                                 str(device.get("hardwareProperties", {}).get("udid", "")))]
        if len(matches) == 1:
            return summarize(matches[0])
        known = [device for device in devices if isinstance(device, dict)
                 and wanted in (str(device.get("identifier")),
                                str(device.get("deviceProperties", {}).get("name", "")),
                                str(device.get("hardwareProperties", {}).get("udid", "")))]
        if known and not matches:
            raise SelectionError(
                f"IOS_DEVICE={wanted!r} matches {_describe(known[0])}, but it is not a connected, "
                "paired iPhone/iPad right now.\n" + NO_DEVICE_HELP)
        if len(matches) > 1:
            raise SelectionError(
                f"IOS_DEVICE={wanted!r} matches several devices; use the identifier instead:\n  "
                + "\n  ".join(_describe(device) for device in matches))
        raise SelectionError(
            f"IOS_DEVICE={wanted!r} does not match any device. Connected, paired devices:\n  "
            + ("\n  ".join(_describe(device) for device in candidates) or "(none)"))
    if not candidates:
        raise SelectionError(NO_DEVICE_HELP)
    if len(candidates) > 1:
        raise SelectionError(
            "Several connected, paired devices were found; set IOS_DEVICE to a name or identifier:\n  "
            + "\n  ".join(_describe(device) for device in candidates))
    return summarize(candidates[0])


def development_team(environment_value=None, build_settings=None):
    """Return the Apple Team ID from IOS_DEVELOPMENT_TEAM or an xcodebuild -showBuildSettings -json export."""
    value = (environment_value or "").strip()
    source = "IOS_DEVELOPMENT_TEAM"
    if not value and build_settings is not None:
        source = "the generated project's DEVELOPMENT_TEAM"
        for entry in build_settings:
            if isinstance(entry, dict) and entry.get("target") == "StarterApp":
                value = str(entry.get("buildSettings", {}).get("DEVELOPMENT_TEAM", "")).strip()
                break
    if not value:
        return None, None
    if not TEAM_ID.fullmatch(value):
        raise SelectionError(f"{source} must be a 10-character Apple Team ID (letters and digits).")
    return value, source


def bundle_identifier(app_path):
    """Read CFBundleIdentifier from a built .app's Info.plist (binary or XML)."""
    info = Path(app_path) / "Info.plist"
    if not info.is_file():
        raise SelectionError(f"Info.plist missing from built app at {app_path}")
    with info.open("rb") as stream:
        identifier = plistlib.load(stream).get("CFBundleIdentifier", "")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", str(identifier)):
        raise SelectionError(f"Built app has an invalid CFBundleIdentifier {identifier!r}")
    return str(identifier)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    select = commands.add_parser("select", help="print identifier, udid, name, model, os, transport (tab separated)")
    select.add_argument("devices_json", type=Path)
    select.add_argument("--device", help="IOS_DEVICE: name, identifier, or UDID")
    manifest = commands.add_parser("manifest", help="print the manifest path for a configuration/spec pair")
    manifest.add_argument("--configuration")
    manifest.add_argument("--spec")
    team = commands.add_parser("team", help="print the team ID and where it came from (tab separated)")
    team.add_argument("--environment-value")
    team.add_argument("--build-settings-json", type=Path)
    bundle = commands.add_parser("bundle-id", help="print CFBundleIdentifier of a built .app")
    bundle.add_argument("app", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "select":
            device = select_device(json.loads(args.devices_json.read_text(encoding="utf-8")), args.device)
            print("\t".join(device[key] for key in ("identifier", "udid", "name", "model", "os", "transport")))
        elif args.command == "manifest":
            print(manifest_for(args.configuration, args.spec))
        elif args.command == "team":
            settings = None
            if args.build_settings_json and args.build_settings_json.is_file():
                settings = json.loads(args.build_settings_json.read_text(encoding="utf-8"))
            value, source = development_team(args.environment_value, settings)
            if value:
                print(f"{value}\t{source}")
        elif args.command == "bundle-id":
            print(bundle_identifier(args.app))
    except (SelectionError, OSError, json.JSONDecodeError, plistlib.InvalidFileException) as error:
        print(f"run-on-device: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
