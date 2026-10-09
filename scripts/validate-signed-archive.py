#!/usr/bin/env python3
"""Validate a signed iOS archive against the selected Xcode configuration export."""
import argparse
import datetime as dt
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from signing_configuration import read_config


def run(args, *, stream="stdout"):
    result = subprocess.run(args, capture_output=True, check=False)
    if result.returncode:
        raise ValueError(f"Validation command failed: {Path(args[0]).name}.")
    return getattr(result, stream)


def compatible(allowed, actual):
    if isinstance(allowed, bool):
        return isinstance(actual, bool) and allowed == actual
    if isinstance(allowed, str):
        if allowed.endswith("*"):
            return isinstance(actual, str) and actual.startswith(allowed[:-1])
        return allowed == actual
    if isinstance(allowed, list):
        return isinstance(actual, list) and all(any(compatible(option, value) for option in allowed) for value in actual)
    if isinstance(allowed, dict):
        return isinstance(actual, dict) and all(key in allowed and compatible(allowed[key], value) for key, value in actual.items())
    return allowed == actual


def validate(archive, config_path):
    app_config = read_config(config_path)
    app = Path(archive) / "Products/Applications/StarterApp.app"
    if not app.is_dir():
        raise ValueError("Archive does not contain StarterApp.app.")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    for key, actual in (("CFBundleIdentifier", app_config["bundleIdentifier"]),
                        ("CFBundleDisplayName", app_config["displayName"]),
                        ("MinimumOSVersion", app_config["minimumIOS"])):
        if str(info.get(key, "")) != str(actual):
            raise ValueError(f"Archived app {key} does not match the fresh configuration export.")
    run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)])
    details = run(["/usr/bin/codesign", "-dvv", str(app)], stream="stderr").decode("utf-8", "replace")
    team_match = re.search(r"^TeamIdentifier=([A-Z0-9]{10})$", details, re.M)
    authority_match = re.search(r"^Authority=Apple Distribution: .+ \(([A-Z0-9]{10})\)$", details, re.M)
    team = app_config["teamIdentifier"]
    if not team_match or team_match.group(1) != team or not authority_match or authority_match.group(1) != team:
        raise ValueError("Archive signing certificate team does not match the selected project team.")

    profile_path = app / "embedded.mobileprovision"
    if not profile_path.is_file():
        raise ValueError("Archive has no embedded provisioning profile.")
    profile = plistlib.loads(run(["/usr/bin/security", "cms", "-D", "-i", str(profile_path)]))
    now = dt.datetime.now(dt.timezone.utc)
    expires = profile.get("ExpirationDate")
    if not isinstance(expires, dt.datetime) or expires.replace(tzinfo=dt.timezone.utc) <= now:
        raise ValueError("Embedded provisioning profile is expired or has no valid expiry date.")
    if profile.get("TeamIdentifier") != [team]:
        raise ValueError("Provisioning profile team does not match the selected project team.")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise ValueError("Archive contains an Ad Hoc or enterprise profile; an App Store profile is required.")
    if profile.get("Platform") and "iOS" not in profile["Platform"]:
        raise ValueError("Embedded profile is not an iOS profile.")
    allowed_app_id = profile.get("Entitlements", {}).get("application-identifier", "")
    expected_app_id = f"{team}.{app_config['bundleIdentifier']}"
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    if prefixes and prefixes != [team]:
        raise ValueError("Legacy App ID prefixes are not supported by this signing path; use a reviewed manual signing configuration.")
    if not compatible(allowed_app_id, expected_app_id):
        raise ValueError("Provisioning profile application identifier does not cover the archived app.")

    entitlements = plistlib.loads(run(["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)]))
    profile_entitlements = profile.get("Entitlements", {})
    if entitlements.get("get-task-allow", True) is not False:
        raise ValueError("Archived app has get-task-allow enabled.")
    if profile_entitlements.get("get-task-allow", True) is not False:
        raise ValueError("Embedded profile permits debugging; an App Store distribution profile is required.")
    if (entitlements.get("application-identifier") != expected_app_id
            or entitlements.get("com.apple.developer.team-identifier") != team):
        raise ValueError("Signed application/team identifiers do not match the selected configuration.")
    for name, value in entitlements.items():
        if name in ("application-identifier", "com.apple.developer.team-identifier", "get-task-allow"):
            continue
        if name not in profile_entitlements or not compatible(profile_entitlements[name], value):
            raise ValueError(f"Archived entitlement {name} is not allowed by the embedded profile.")
    for name in ("application-identifier", "com.apple.developer.team-identifier"):
        if not compatible(profile_entitlements.get(name), entitlements[name]):
            raise ValueError(f"Archived entitlement {name} does not match the embedded profile.")

    # The signing identity must also appear in the profile's DeveloperCertificates.
    cert_dir = Path(archive).parent / "signing-certificates"
    cert_dir.mkdir(exist_ok=True)
    result = subprocess.run(["/usr/bin/codesign", "-d", "--extract-certificates", str(app)],
                            cwd=cert_dir, capture_output=True, check=False)
    if result.returncode:
        raise ValueError("Could not extract archive signing certificate.")
    leaf = (cert_dir / "codesign0").read_bytes()
    if leaf not in profile.get("DeveloperCertificates", []):
        raise ValueError("Archive signing certificate is not present in the embedded profile.")
    result = subprocess.run(["/usr/bin/openssl", "x509", "-inform", "DER", "-noout", "-enddate"], input=leaf,
                            capture_output=True, check=False)
    if result.returncode:
        raise ValueError("Could not verify signing certificate expiry.")
    certificate_expiry = dt.datetime.strptime(result.stdout.decode().strip().removeprefix("notAfter="),
                                               "%b %d %H:%M:%S %Y %Z").replace(tzinfo=dt.timezone.utc)
    if certificate_expiry <= now:
        raise ValueError("Archive signing certificate is expired.")
    return {"status": "passed", "bundleIdentifier": app_config["bundleIdentifier"], "teamIdentifier": team,
            "displayName": app_config["displayName"], "profileExpires": expires.astimezone(dt.timezone.utc).isoformat(),
            "certificateExpires": certificate_expiry.isoformat(), "entitlementKeys": sorted(entitlements)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = validate(args.archive, args.configuration)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("Signed archive passed identity, team, certificate, profile, expiry, and entitlement checks.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, plistlib.InvalidFileException):
        print("Signed archive validation failed; raw signing metadata was not logged.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
