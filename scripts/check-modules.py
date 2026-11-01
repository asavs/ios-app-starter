#!/usr/bin/env python3
"""Check the module library layout against the dumped manifest and Xcode's generated project.

Modules are products of the single root package (Package.swift) with sources under
Modules/<Name>/Sources and tests under Modules/<Name>/Tests. Enablement lives in project.yml as
package product dependencies; this script reads the generated project rather than parsed YAML.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MODULE_NAME = re.compile(r"[A-Z][A-Za-z0-9]*\Z")
VERSION = re.compile(r"[0-9]+(?:\.[0-9]+){0,2}\Z")


def command_json(*args):
    result = subprocess.run(args, text=True, capture_output=True)
    if result.returncode:
        raise ValueError(f"{' '.join(args)} failed:\n{result.stderr[-4000:]}")
    return json.loads(result.stdout)


def version(value):
    if not VERSION.fullmatch(str(value)):
        raise ValueError(f"invalid OS version {value!r}")
    parts = tuple(map(int, str(value).split('.')))
    return parts + (0,) * (3 - len(parts))


def check_privacy_manifest(name, target, root=ROOT):
    """A module that touches a required-reason API ships a privacy manifest declaring why.

    UserDefaults is the one the template's modules use (reason CA92.1, the app's own defaults). App
    Store Connect has refused uploads without the declaration since 2024-05-01; see
    docs/research/settings-sections.md.
    """
    sources = root / f"Modules/{name}/Sources"
    uses_defaults = any("UserDefaults" in path.read_text(encoding="utf-8")
                        for path in sources.rglob("*.swift"))
    manifest_path = sources / "PrivacyInfo.xcprivacy"
    declared = any(resource.get("path") == "PrivacyInfo.xcprivacy" for resource in target.get("resources", []))
    if uses_defaults and not manifest_path.is_file():
        raise ValueError(f"Modules/{name} uses UserDefaults: add Sources/PrivacyInfo.xcprivacy with reason CA92.1")
    if manifest_path.is_file() and not declared:
        raise ValueError(f"target {name}: list .process(\"PrivacyInfo.xcprivacy\") in resources so the manifest ships")
    if manifest_path.is_file() and "NSPrivacyAccessedAPICategoryUserDefaults" not in manifest_path.read_text(encoding="utf-8") and uses_defaults:
        raise ValueError(f"Modules/{name}/Sources/PrivacyInfo.xcprivacy must declare NSPrivacyAccessedAPICategoryUserDefaults")


def check_manifest(manifest, module_dirs, root=ROOT):
    """Validate dump-package output against the Modules/ directories; return module records."""
    products = {product["name"]: product for product in manifest.get("products", [])}
    targets = {target["name"]: target for target in manifest.get("targets", [])}
    modules = []
    for name in sorted(module_dirs):
        if not MODULE_NAME.fullmatch(name):
            raise ValueError(f"Modules/{name}: module directories use UpperCamelCase names")
        if name not in products:
            raise ValueError(f"Modules/{name}: add .library(name: \"{name}\", targets: [\"{name}\"]) to Package.swift")
        product = products[name]
        if product.get("type", {}).get("library") is None or product.get("targets") != [name]:
            raise ValueError(f"product {name} must be a library built from the single target {name}")
        target = targets.get(name)
        if not target or target.get("type") != "regular" or target.get("path") != f"Modules/{name}/Sources":
            raise ValueError(f"target {name} must have path: \"Modules/{name}/Sources\"")
        tests = targets.get(f"{name}Tests")
        if not tests or tests.get("type") != "test" or tests.get("path") != f"Modules/{name}/Tests":
            raise ValueError(f"module {name} needs a test target {name}Tests with path: \"Modules/{name}/Tests\"")
        if not any(dependency.get("byName", [None])[0] == name or dependency.get("target", [None])[0] == name
                   for dependency in tests.get("dependencies", [])):
            raise ValueError(f"{name}Tests must depend on {name}")
        for relative in (f"Modules/{name}/Sources", f"Modules/{name}/Tests"):
            directory = root / relative
            if not any(path.suffix == ".swift" for path in directory.rglob("*")) if directory.is_dir() else True:
                raise ValueError(f"{relative} must contain at least one Swift file")
        check_privacy_manifest(name, target, root)
        modules.append({"name": name, "sources": f"Modules/{name}/Sources", "tests": f"Modules/{name}/Tests",
                        "testTarget": f"{name}Tests"})
    for name, product in products.items():
        if name not in module_dirs:
            raise ValueError(f"product {name} has no Modules/{name} directory; one module per product")
    for name, target in targets.items():
        if target.get("type") == "regular" and name not in module_dirs:
            raise ValueError(f"target {name} is not a module; keep every library target under Modules/")
    platforms = {entry["platformName"]: entry["version"] for entry in manifest.get("platforms", [])}
    if "ios" not in platforms:
        raise ValueError("Package.swift must declare platforms: [.iOS(...)] at or below the app minimum")
    return modules, platforms


def check_project(project_objects, products, project_dir, root=ROOT):
    """Validate package references in a generated project; return enabled products and references."""
    references, enabled, remote = {}, [], []
    for identifier, obj in project_objects.items():
        isa = obj.get("isa")
        if isa == "XCLocalSwiftPackageReference":
            resolved = (project_dir / obj.get("relativePath", "")).resolve()
            if resolved != root.resolve():
                raise ValueError(f"local package reference {obj.get('relativePath')!r} resolves to {resolved}, "
                                 f"not this repository; every spec and overlay sets packages.StarterModules.path "
                                 f"relative to the generated project directory (see docs/modules.md)")
            references[identifier] = "StarterModules"
        elif isa == "XCRemoteSwiftPackageReference":
            remote.append(obj.get("repositoryURL", ""))
    for obj in project_objects.values():
        if obj.get("isa") != "XCSwiftPackageProductDependency":
            continue
        name = obj.get("productName", "")
        # Xcode omits the package reference for local package products.
        if obj.get("package") is None or obj.get("package") in references:
            if name not in products:
                raise ValueError(f"project.yml enables product {name!r}, which Package.swift does not define")
            enabled.append(name)
        else:
            remote.append(name)
    return sorted(set(enabled)), remote


def project_minimum(project_objects):
    project_object = project_objects[next(k for k, v in project_objects.items() if v.get("isa") == "PBXProject")]
    minimums = set()
    for reference in project_objects[project_object["buildConfigurationList"]]["buildConfigurations"]:
        minimums.add(str(project_objects[reference]["buildSettings"].get("IPHONEOS_DEPLOYMENT_TARGET", "")))
    if len(minimums) != 1:
        raise ValueError("project-level IPHONEOS_DEPLOYMENT_TARGET must be one explicit value")
    return minimums.pop()


def check(root=ROOT, project=None):
    if not (root / "Package.swift").is_file():
        raise ValueError(f"Package.swift missing at {root}; the module library is a single root package")
    manifest = command_json("swift", "package", "dump-package", "--package-path", str(root))
    modules_dir = root / "Modules"
    module_dirs = {path.name for path in modules_dir.iterdir() if path.is_dir()} if modules_dir.is_dir() else set()
    modules, platforms = check_manifest(manifest, module_dirs, root)
    record = {"package": manifest.get("name"), "platforms": platforms, "modules": modules}
    if project is not None:
        if not project.is_dir():
            raise ValueError(f"project missing at {project}; generate it first")
        native = command_json("plutil", "-convert", "json", "-o", "-", str(project / "project.pbxproj"))
        enabled, remote = check_project(native["objects"], {m["name"] for m in modules}, project.parent, root)
        minimum = project_minimum(native["objects"])
        if version(platforms["ios"]) > version(minimum):
            raise ValueError(f"Package.swift iOS platform {platforms['ios']} is above the app minimum {minimum}; "
                             "lower the package platform or raise options.deploymentTarget.iOS")
        check_usage_strings(enabled, project.parent, root)
        record.update({"minimumIOS": minimum, "enabled": enabled,
                       "disabled": [m["name"] for m in modules if m["name"] not in enabled],
                       "otherPackageDependencies": remote})
    return record


# A module whose feature asks the system for access needs the matching usage string in the app's
# Info.plist, or the system terminates the app at the request. Attachments: the camera (Photos and
# Files pickers run out of process and need none; docs/research/attachments.md).
USAGE_STRINGS = {"Attachments": "NSCameraUsageDescription"}


def check_usage_strings(enabled, project_dir, root=ROOT):
    info = project_dir / "StarterApp/Info.plist"
    text = info.read_text(encoding="utf-8") if info.is_file() else ""
    for module, key in USAGE_STRINGS.items():
        if module in enabled and f"<key>{key}</key>" not in text:
            raise ValueError(f"{module} is enabled but the app's Info.plist has no {key}; add it under "
                             "targets.StarterApp.info.properties in project.yml and regenerate the project")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", type=Path, default=ROOT / "StarterApp/StarterApp.xcodeproj",
                        help="generated project to read enablement from; pass '' to check the package only")
    parser.add_argument("--output", type=Path, help="Save the module inventory as JSON")
    args = parser.parse_args()
    try:
        record = check(project=args.project if str(args.project) else None)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(record, indent=2) + "\n")
        print("Module library verified:\n" + json.dumps(record, indent=2))
    except (ValueError, KeyError, OSError, StopIteration, subprocess.CalledProcessError) as error:
        print(f"Module library error: {error}", file=sys.stderr)
        sys.exit(1)
