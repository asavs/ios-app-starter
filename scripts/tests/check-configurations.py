#!/usr/bin/env python3
"""Integration probes: actual XcodeGen manifests and Xcode-resolved settings."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
cases = [
    ("missing-identifier", {"targets": {"StarterApp": {"settings": {"base": {
        "PRODUCT_BUNDLE_IDENTIFIER": ""}}}}}, "PRODUCT_BUNDLE_IDENTIFIER"),
    ("invalid-identifier", {"targets": {"StarterApp": {"settings": {"base": {
        "PRODUCT_BUNDLE_IDENTIFIER": "bad identifier!"}}}}}, "PRODUCT_BUNDLE_IDENTIFIER"),
    ("invalid-team-id", {"settings": {"base": {"DEVELOPMENT_TEAM": "not-a-team"}}}, "DEVELOPMENT_TEAM"),
    ("mismatched-team-id", {"settings": {"base": {"DEVELOPMENT_TEAM": "AAAAAAAAAA"}},
                             "targets": {"StarterAppUITests": {"settings": {"base": {
                                 "DEVELOPMENT_TEAM": "BBBBBBBBBB"}}}}}, "same DEVELOPMENT_TEAM"),
    ("empty-name", {"targets": {"StarterApp": {"settings": {"base": {
        "INFOPLIST_KEY_CFBundleDisplayName": " "}}}}}, "CFBundleDisplayName"),
    ("mismatched-minimum", {"targets": {"StarterAppUITests": {"deploymentTarget": "18.0"}}},
     "deployment targets must match"),
    ("invalid-minimum", {"options": {"deploymentTarget": {"iOS": "banana"}}}, "explicit minimum iOS"),
    ("too-old-minimum", {"options": {"deploymentTarget": {"iOS": "16.0"}}}, "minimum iOS must be"),
    ("unsupported-devices", {"targets": {"StarterApp": {"settings": {"base": {"TARGETED_DEVICE_FAMILY": "3"}}}}},
     "TARGETED_DEVICE_FAMILY"),
    ("unsupported-platform", {"targets": {"WatchApp": {"type": "application", "platform": "watchOS",
                                                   "sources": []}}}, "only StarterApp"),
    ("missing-scheme", {"schemes:REPLACE": {}}, "scheme"),
    ("missing-ui-test", {"schemes": {"StarterApp": {"test": {"targets:REPLACE": ["StarterAppTests"]}}}},
     "scheme must include"),
    ("unconfigured-capability", {"targets": {"StarterApp": {"attributes": {
        "SystemCapabilities": {"com.apple.Push": {"enabled": 1}}}}}}, "account capabilities"),
    ("missing-source", {"targets": {"StarterApp": {"sources:REPLACE": ["not-a-real-source"]}}}, None),
]
if sys.argv[1:]:
    selected = set(sys.argv[1:])
    unknown = selected - {case[0] for case in cases}
    if unknown:
        sys.exit(f"Unknown configuration probes: {sorted(unknown)}")
    cases = [case for case in cases if case[0] in selected]
with tempfile.TemporaryDirectory(prefix="ios-config-probes-") as directory:
    root = Path(directory)
    for name, override, diagnostic in cases:
        spec = root / f"{name}.json"
        spec.write_text(json.dumps({"include": str(ROOT / "project.yml"), **override}))
        env = dict(os.environ, IOS_PROJECT_SPEC=str(spec), IOS_PROJECT_DIR=str(root / name))
        generation = subprocess.run(["bash", str(ROOT / "scripts/generate-project.sh")],
                                    env=env, text=True, capture_output=True)
        if generation.returncode:
            if diagnostic is not None:
                raise RuntimeError(f"{name}: generation failed before expected policy check:\n{generation.stdout}\n{generation.stderr}")
            # Native XcodeGen validation must fail, rather than download/setup errors.
            if "Spec validation error" not in generation.stdout + generation.stderr and "Decoding" not in generation.stdout + generation.stderr:
                raise RuntimeError(f"{name}: unexpected generator failure:\n{generation.stdout}\n{generation.stderr}")
        else:
            checked = subprocess.run(["python3", str(ROOT / "scripts/check-configuration.py"),
                                      str(root / name / "StarterApp.xcodeproj")], text=True, capture_output=True)
            if checked.returncode == 0 or (diagnostic and diagnostic not in checked.stderr):
                raise RuntimeError(f"{name}: expected rejection {diagnostic!r}, got:\n{checked.stdout}\n{checked.stderr}")
        print(f"PASS: rejected {name}", flush=True)
