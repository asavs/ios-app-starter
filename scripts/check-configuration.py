#!/usr/bin/env python3
"""Check template policies against Xcode's resolved project, not parsed YAML."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {"StarterApp", "StarterAppTests", "StarterAppUITests"}


def command_json(*args):
    result = subprocess.run(args, text=True, capture_output=True)
    if result.returncode:
        raise ValueError(f"{' '.join(args)} failed:\n{result.stderr[-4000:]}")
    return json.loads(result.stdout)


def version(value):
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value):
        raise ValueError(f"invalid OS version {value!r}; use a number such as 17.0")
    parts = tuple(map(int, value.split('.')))
    return parts + (0,) * (3 - len(parts))


def check(project):
    if not project.is_dir():
        raise ValueError(f"project missing at {project}; generate it first and keep name: StarterApp")
    native = command_json("plutil", "-convert", "json", "-o", "-", str(project / "project.pbxproj"))
    objects = native["objects"]
    project_object = objects[native["rootObject"]]
    # XcodeGen can silently discard an invalid options.deploymentTarget value;
    # Xcode then defaults to the SDK version. Require an explicit generated minimum.
    configurations = objects[project_object["buildConfigurationList"]]["buildConfigurations"]
    for reference in configurations:
        configuration = objects[reference]
        minimum = configuration["buildSettings"].get("IPHONEOS_DEPLOYMENT_TARGET", "")
        if not minimum:
            raise ValueError("explicit minimum iOS missing from generated project; set "
                             "options.deploymentTarget.iOS to a numeric value such as 17.0")
        version(str(minimum))
    for obj in objects.values():
        if obj.get("isa") == "XCBuildConfiguration" and "IPHONEOS_DEPLOYMENT_TARGET" in obj.get("buildSettings", {}):
            version(str(obj["buildSettings"]["IPHONEOS_DEPLOYMENT_TARGET"]))
    for attributes in project_object.get("attributes", {}).get("TargetAttributes", {}).values():
        capabilities = attributes.get("SystemCapabilities", {})
        if capabilities and (not isinstance(capabilities, dict) or
                             any(not isinstance(capability, dict) or capability.get("enabled") in (1, "1", "YES")
                                 for capability in capabilities.values())):
            raise ValueError("account capabilities require later Apple setup/signing milestones; "
                             "remove enabled SystemCapabilities for the unsigned starter")
    listing = command_json("xcodebuild", "-project", str(project), "-list", "-json")["project"]
    if set(listing["targets"]) != TARGETS:
        raise ValueError("only StarterApp, StarterAppTests, and StarterAppUITests targets are supported; "
                         "Watch, Mac, TV, and Vision Pro modules are pending milestone 9")
    if "StarterApp" not in listing["schemes"]:
        raise ValueError("StarterApp scheme missing; keep the template scheme name and its test targets")
    scheme = project / "xcshareddata/xcschemes/StarterApp.xcscheme"
    if not scheme.is_file():
        raise ValueError("StarterApp scheme must be shared for GitHub Actions")
    test_targets = {node.get("BlueprintName") for node in
                    ET.parse(scheme).findall("./TestAction/Testables/TestableReference/BuildableReference")}
    if test_targets != TARGETS - {"StarterApp"}:
        raise ValueError("StarterApp scheme must include StarterAppTests and StarterAppUITests")
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True).strip()
    records = []
    for config in ("Debug", "Release"):
        # -derivedDataPath requires a scheme, which excludes -alltargets.
        # This per-invocation Xcode user default also permits all-target inspection.
        with tempfile.TemporaryDirectory(prefix="ios-settings-") as derived:
            resolved = command_json("xcodebuild", "-project", str(project), "-alltargets",
                                    f"-IDECustomDerivedDataLocation={derived}",
                                    "-configuration", config, "-showBuildSettings", "-json")
        for entry in resolved:
            if entry.get("error"):
                raise ValueError(f"Xcode could not resolve {config}/{entry['target']}: {entry['error']}")
        settings = {entry["target"]: entry["buildSettings"] for entry in resolved}
        if set(settings) != TARGETS:
            raise ValueError(f"{config}: cannot inspect all template targets")
        minimums, identifiers = set(), set()
        for target, values in settings.items():
            prefix = f"{config}/{target}"
            identifier = values.get("PRODUCT_BUNDLE_IDENTIFIER", "")
            # Reverse-DNS is our template policy; Apple permits these characters.
            if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", identifier):
                raise ValueError(f"{prefix}: PRODUCT_BUNDLE_IDENTIFIER must be a nonempty reverse-DNS "
                                 "identifier using letters, numbers, hyphens, and periods")
            if identifier in identifiers:
                raise ValueError(f"{prefix}: each app/test bundle needs a distinct PRODUCT_BUNDLE_IDENTIFIER")
            identifiers.add(identifier)
            minimum = values.get("IPHONEOS_DEPLOYMENT_TARGET", "")
            parsed = version(minimum)
            if not version("17.0") <= parsed <= version(sdk):
                raise ValueError(f"{prefix}: minimum iOS must be between 17.0 and installed SDK {sdk}; "
                                 "change options.deploymentTarget.iOS in project.yml")
            minimums.add(parsed)
            if set(values.get("SUPPORTED_PLATFORMS", "").split()) != {"iphoneos", "iphonesimulator"}:
                raise ValueError(f"{prefix}: only iOS device/simulator platforms are implemented")
            families = {part.strip() for part in values.get("TARGETED_DEVICE_FAMILY", "").split(',')}
            if not families or not families <= {"1", "2"}:
                raise ValueError(f"{prefix}: TARGETED_DEVICE_FAMILY must be 1, 2, or 1,2")
            if values.get("CODE_SIGN_ENTITLEMENTS", ""):
                raise ValueError(f"{prefix}: entitlements require capability/signing setup in later milestones; "
                                 "remove CODE_SIGN_ENTITLEMENTS for the unsigned starter")
        if len(minimums) != 1:
            raise ValueError(f"{config}: app and test deployment targets must match; "
                             "remove target overrides and use options.deploymentTarget.iOS")
        app = settings["StarterApp"]
        if app.get("PRODUCT_MODULE_NAME") != "StarterApp" or app.get("PRODUCT_NAME") != "StarterApp":
            raise ValueError(f"{config}: keep PRODUCT_NAME/PRODUCT_MODULE_NAME as StarterApp; "
                             "customize INFOPLIST_KEY_CFBundleDisplayName instead")
        name = app.get("INFOPLIST_KEY_CFBundleDisplayName", "")
        if not name.strip() or any(ord(c) < 32 for c in name):
            raise ValueError(f"{config}: INFOPLIST_KEY_CFBundleDisplayName must contain a name without control characters")
        for flag in ("SUPPORTS_MACCATALYST", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD", "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"):
            if app.get(flag, "NO") != "NO":
                raise ValueError(f"{config}: {flag} is not supported yet; keep it NO")
        records.append({"configuration": config, "displayName": name,
                        "bundleIdentifier": app["PRODUCT_BUNDLE_IDENTIFIER"],
                        "minimumIOS": app["IPHONEOS_DEPLOYMENT_TARGET"],
                        "deviceFamilies": app["TARGETED_DEVICE_FAMILY"], "sdk": sdk})
    return records


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", type=Path, default=ROOT / "StarterApp/StarterApp.xcodeproj")
    parser.add_argument("--output", type=Path, help="Save checked non-secret settings as JSON")
    args = parser.parse_args()
    try:
        records = check(args.project)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(records, indent=2) + "\n")
        print("Configuration verified:\n" + json.dumps(records, indent=2))
    except (ValueError, KeyError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        sys.exit(1)
