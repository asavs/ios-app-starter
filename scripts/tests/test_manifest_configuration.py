#!/usr/bin/env python3
"""Portable app identity exports from XcodeGen manifests."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_configuration", ROOT / "scripts/check-configuration.py")
configuration = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(configuration)
SIGNING_SPEC = importlib.util.spec_from_file_location("signing_configuration", ROOT / "scripts/signing_configuration.py")
signing = importlib.util.module_from_spec(SIGNING_SPEC)
SIGNING_SPEC.loader.exec_module(signing)


class ManifestConfigurationTests(unittest.TestCase):
    def test_checked_in_manifests_export_the_selected_app_identity(self):
        cases = {
            "project.yml": ("com.example.StarterApp", "Starter App", ""),
            "examples/pocket-notes.yml": ("org.example.pocketnotes", "Pocket Notes", ""),
            "examples/starter-app-demo.yml": (
                "com.asaschaeffer.starterappdemo", "Starter App", "9L6Y9T3PPW"),
        }
        for manifest, expected in cases.items():
            with self.subTest(manifest=manifest):
                records = configuration.check_manifest(ROOT / manifest)
                self.assertEqual(len(records), 2)
                self.assertEqual({record["configuration"] for record in records}, {"Debug", "Release"})
                for record in records:
                    self.assertEqual((record["bundleIdentifier"], record["displayName"],
                                      record["teamIdentifier"]), expected)
                    self.assertEqual(record["minimumIOS"], "17.0")

    def test_rejects_include_cycles(self):
        with tempfile.TemporaryDirectory(prefix="manifest-cycle-") as directory:
            first, second = Path(directory) / "first.yml", Path(directory) / "second.yml"
            first.write_text("include: second.yml\n", encoding="utf-8")
            second.write_text("include: first.yml\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "include cycle"):
                configuration.manifest_scalars(first)

    def test_rejects_invalid_bundle_identifier(self):
        with tempfile.TemporaryDirectory(prefix="manifest-invalid-") as directory:
            manifest = Path(directory) / "project.yml"
            manifest.write_text(
                'options:\n  deploymentTarget:\n    iOS: "17.0"\n'
                'targets:\n  StarterApp:\n    settings:\n      base:\n'
                '        PRODUCT_BUNDLE_IDENTIFIER: "not an identifier"\n'
                '        INFOPLIST_KEY_CFBundleDisplayName: "Demo"\n'
                '        TARGETED_DEVICE_FAMILY: "1,2"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "bundle identifier is invalid"):
                configuration.check_manifest(manifest)

    def test_demo_export_matches_the_account_workflow_configuration_contract(self):
        records = configuration.check_manifest(ROOT / "examples/starter-app-demo.yml")
        with tempfile.TemporaryDirectory(prefix="manifest-export-") as directory:
            output = Path(directory) / "configuration.json"
            output.write_text(json.dumps(records), encoding="utf-8")
            app = signing.read_config(output)
        self.assertEqual(app["bundleIdentifier"], "com.asaschaeffer.starterappdemo")
        self.assertEqual(app["teamIdentifier"], "9L6Y9T3PPW")


if __name__ == "__main__":
    unittest.main()
