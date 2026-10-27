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
TEAM_ID = re.compile(r"[A-Z0-9]{10}\Z")
# Web and system schemes another app or the system already handles.
RESERVED_SCHEMES = {"http", "https", "file", "ftp", "mailto", "tel", "sms", "facetime", "maps", "itms-apps", "app-settings"}


def manifest_scalars(path, stack=()):
    """Read the scalar mapping subset used by the checked-in XcodeGen manifests."""
    path = path.resolve()
    if path in stack:
        raise ValueError("manifest include cycle detected")
    values = {}
    parents = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#") or stripped.startswith("-"):
            continue
        indent = len(line) - len(stripped)
        key, separator, raw = stripped.partition(":")
        if not separator or not re.fullmatch(r"[A-Za-z0-9_-]+", key):
            continue
        while parents and parents[-1][0] >= indent:
            parents.pop()
        key_path = tuple(item[1] for item in parents) + (key,)
        raw = raw.strip()
        if not raw:
            parents.append((indent, key))
            continue
        # Strip a YAML inline comment while preserving # inside quoted scalars.
        quote = None
        escaped = False
        for index, char in enumerate(raw):
            if escaped:
                escaped = False
            elif char == "\\" and quote == '"':
                escaped = True
            elif quote and char == quote:
                quote = None
            elif not quote and char in ('"', "'"):
                quote = char
            elif not quote and char == "#" and (index == 0 or raw[index - 1].isspace()):
                raw = raw[:index].rstrip()
                break
        try:
            if raw.startswith('"'):
                value = json.loads(raw)
            elif raw.startswith("'") and raw.endswith("'") and len(raw) >= 2:
                value = raw[1:-1].replace("''", "'")
            elif raw and raw[0] not in "[{|>&*!%`":
                value = raw
            else:
                continue
        except (ValueError, TypeError) as error:
            raise ValueError(f"invalid scalar in manifest at {path.name}:{number}") from error
        values[key_path] = value

    include = values.get(("include",))
    if include:
        included_path = (path.parent / include).resolve()
        inherited = manifest_scalars(included_path, stack + (path,))
        inherited.update(values)
        values = inherited
    return values


def check_manifest(manifest):
    """Export the selected app identity without Xcode for read-only ASC workflows."""
    values = manifest_scalars(manifest)
    app = ("targets", "StarterApp", "settings", "base")
    root_settings = ("settings", "base")

    def required(key):
        value = values.get(app + (key,))
        if value is None:
            raise ValueError(f"manifest is missing targets.StarterApp.settings.base.{key}")
        return str(value)

    bundle_id = required("PRODUCT_BUNDLE_IDENTIFIER")
    display_name = required("INFOPLIST_KEY_CFBundleDisplayName")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        raise ValueError("manifest app bundle identifier is invalid")
    if not display_name.strip() or any(ord(char) < 32 for char in display_name):
        raise ValueError("manifest app display name is missing or invalid")
    minimum = values.get(("options", "deploymentTarget", "iOS"))
    if not minimum:
        raise ValueError("manifest is missing options.deploymentTarget.iOS")
    version(str(minimum))
    team = str(values.get(app + ("DEVELOPMENT_TEAM",),
                          values.get(root_settings + ("DEVELOPMENT_TEAM",), "")))
    records = []
    for configuration in ("Debug", "Release"):
        name = str(values.get(("targets", "StarterApp", "settings", "configs", configuration,
                               "INFOPLIST_KEY_CFBundleDisplayName"), display_name))
        # A per-configuration name may refer to another target setting, as Debug does with $(DEV_DISPLAY_NAME).
        reference = re.fullmatch(r"\$\((\w+)\)", name)
        if reference:
            name = required(reference.group(1))
        records.append({
            "configuration": configuration,
            "displayName": name,
            "bundleIdentifier": bundle_id,
            "teamIdentifier": team,
            "minimumIOS": str(minimum),
            "deviceFamilies": required("TARGETED_DEVICE_FAMILY"),
            "marketingVersion": str(values.get(("settings", "base", "MARKETING_VERSION"), "")),
            "buildNumber": str(values.get(("settings", "base", "CURRENT_PROJECT_VERSION"), "")),
        })
    return records


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
                         "modules are Swift package products (docs/modules.md), and optional platforms "
                         "are pending milestone 14")
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
        minimums, identifiers, teams = set(), set(), set()
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
            team = values.get("DEVELOPMENT_TEAM", "").strip()
            if team and not TEAM_ID.fullmatch(team):
                raise ValueError(f"{prefix}: DEVELOPMENT_TEAM must be a 10-character Apple Team ID")
            teams.add(team)
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
        if len(teams) != 1:
            raise ValueError(f"{config}: all app/test targets must use the same DEVELOPMENT_TEAM")
        app = settings["StarterApp"]
        if app.get("PRODUCT_MODULE_NAME") != "StarterApp" or app.get("PRODUCT_NAME") != "StarterApp":
            raise ValueError(f"{config}: keep PRODUCT_NAME/PRODUCT_MODULE_NAME as StarterApp; "
                             "customize INFOPLIST_KEY_CFBundleDisplayName instead")
        name = app.get("INFOPLIST_KEY_CFBundleDisplayName", "")
        if not name.strip() or any(ord(c) < 32 for c in name):
            raise ValueError(f"{config}: INFOPLIST_KEY_CFBundleDisplayName must contain a name without control characters")
        # RFC 3986 scheme syntax, lowercase; reserved schemes would claim links meant for other apps.
        scheme = app.get("APP_URL_SCHEME", "")
        if not re.fullmatch(r"[a-z][a-z0-9+.-]*", scheme) or scheme in RESERVED_SCHEMES:
            raise ValueError(f"{config}: APP_URL_SCHEME must be the app's own lowercase scheme, such as "
                             "starterapp (letters, digits, +, - and .), not a web or system scheme")
        for flag in ("SUPPORTS_MACCATALYST", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD", "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"):
            if app.get(flag, "NO") != "NO":
                raise ValueError(f"{config}: {flag} is not supported yet; keep it NO")
        records.append({"configuration": config, "displayName": name,
                        "bundleIdentifier": app["PRODUCT_BUNDLE_IDENTIFIER"],
                        "teamIdentifier": app.get("DEVELOPMENT_TEAM", "").strip(),
                        "minimumIOS": app["IPHONEOS_DEPLOYMENT_TARGET"],
                        "deviceFamilies": app["TARGETED_DEVICE_FAMILY"], "sdk": sdk, "urlScheme": scheme,
                        "marketingVersion": app.get("MARKETING_VERSION", ""),
                        "buildNumber": app.get("CURRENT_PROJECT_VERSION", "")})
    return records


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", type=Path, default=ROOT / "StarterApp/StarterApp.xcodeproj")
    parser.add_argument("--output", type=Path, help="Save checked non-secret settings as JSON")
    parser.add_argument("--manifest-only", type=Path,
                        help="Export app identity from an XcodeGen manifest without requiring Xcode")
    args = parser.parse_args()
    try:
        records = check_manifest(args.manifest_only) if args.manifest_only else check(args.project)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(records, indent=2) + "\n")
        print("Configuration verified:\n" + json.dumps(records, indent=2))
    except (ValueError, KeyError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        sys.exit(1)
