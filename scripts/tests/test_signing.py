import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from signing_configuration import read_config

spec = importlib.util.spec_from_file_location("archive_validator", ROOT / "scripts/validate-signed-archive.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
TEAM = "TESTTEAM01"
CANARY = b"SIGNING-METADATA-CANARY"


def records():
    export = os.environ.get("IOS_SIGNING_CONFIGURATION_EXPORT")
    if export:
        return json.loads(Path(export).read_text(encoding="utf-8"))
    return [dict(configuration=c, bundleIdentifier="org.example.fixture", teamIdentifier=TEAM,
                 displayName="Fixture", minimumIOS="17.0") for c in ("Debug", "Release")]


class SigningTests(unittest.TestCase):
    def test_native_list_contract_and_rejection_of_malformed_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "configuration.json"
            valid = records()
            path.write_text(json.dumps(valid), encoding="utf-8")
            self.assertEqual(read_config(path), valid[1])
            cases = [{"configurations": valid}, [valid[0]], [None, valid[1]],
                     [valid[0], {**valid[1], "configuration": {"unexpected": "value"}}],
                     [valid[0], {**valid[1], "configuration": "Debug"}],
                     [valid[0], {**valid[1], "teamIdentifier": "OTHERTEAM1"}],
                     [dict(item, teamIdentifier="") for item in valid],
                     [dict(item, displayName="bad\nteamIdentifier=OTHERTEAM1") for item in valid],
                     [dict(item, minimumIOS="bad") for item in valid]]
            for value in cases:
                with self.subTest(value=value):
                    path.write_text(json.dumps(value), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        read_config(path)

    def test_signing_config_command_consumes_export_and_emits_safe_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "configuration.json"
            output = Path(directory) / "outputs"
            path.write_text(json.dumps(records()), encoding="utf-8")
            result = subprocess.run([sys.executable, str(ROOT / "scripts/check-signing-config.py"),
                                     str(path), "--output", str(output)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("teamIdentifier=" + records()[1]["teamIdentifier"], output.read_text())

    def test_entitlement_coverage_supports_array_subsets_and_rejects_extra_access(self):
        self.assertTrue(validator.compatible(["TEAM.*", "SHARED.group"], ["TEAM.app", "SHARED.group"]))
        self.assertFalse(validator.compatible(["TEAM.*"], ["TEAM.app", "OTHER.app"]))
        self.assertFalse(validator.compatible(["TEAM.*"], "TEAM.app"))
        self.assertFalse(validator.compatible(False, 0))
        self.assertTrue(validator.compatible({"feature": True}, {"feature": True}))
        self.assertFalse(validator.compatible({"feature": True}, {"extra": True}))

    def test_native_codesign_display_uses_stderr(self):
        if sys.platform != "darwin":
            self.skipTest("Native codesign stream probe requires macOS")
        details = validator.run(["/usr/bin/codesign", "-dvv", "/usr/bin/true"], stream="stderr")
        self.assertIn(b"Executable=", details)

    def fixture(self, directory):
        selected = records()[1]
        team = selected["teamIdentifier"]
        identity = team + "." + selected["bundleIdentifier"]
        archive = Path(directory) / "Fixture.xcarchive"
        app = archive / "Products/Applications/StarterApp.app"
        app.mkdir(parents=True)
        info = {"CFBundleIdentifier": selected["bundleIdentifier"], "CFBundleDisplayName": selected["displayName"],
                "MinimumOSVersion": selected["minimumIOS"]}
        (app / "Info.plist").write_bytes(plistlib.dumps(info))
        (app / "embedded.mobileprovision").write_bytes(b"fixture CMS")
        config = Path(directory) / "configuration.json"
        config.write_text(json.dumps(records()), encoding="utf-8")
        profile = {"TeamIdentifier": [team], "ApplicationIdentifierPrefix": [team], "Platform": ["iOS"],
                   "ExpirationDate": dt.datetime(2099, 1, 1), "DeveloperCertificates": [CANARY],
                   "Entitlements": {"application-identifier": identity, "com.apple.developer.team-identifier": team,
                                    "get-task-allow": False, "keychain-access-groups": [team + ".*"]}}
        entitlements = {"application-identifier": identity, "com.apple.developer.team-identifier": team,
                        "get-task-allow": False, "keychain-access-groups": [identity]}
        return archive, config, profile, entitlements

    def commands(self, profile, entitlements, *, signature_ok=True, expiry="Jan  1 00:00:00 2099 GMT"):
        def command(args, **kwargs):
            stdout, stderr, code = b"", b"", 0
            if args[0].endswith("security"):
                stdout = plistlib.dumps(profile)
            elif "--verify" in args:
                code = 0 if signature_ok else 1
                stderr = CANARY
            elif "-dvv" in args:
                team = records()[1]["teamIdentifier"]
                stderr = f"TeamIdentifier={team}\nAuthority=Apple Distribution: Fixture ({team})\n".encode() + CANARY
            elif "--entitlements" in args:
                stdout = plistlib.dumps(entitlements)
                stderr = CANARY
            elif "--extract-certificates" in args:
                (Path(kwargs["cwd"]) / "codesign0").write_bytes(CANARY)
            elif args[0].endswith("openssl"):
                stdout = ("notAfter=" + expiry + "\n").encode()
            else:
                raise AssertionError("Unexpected validation command")
            return subprocess.CompletedProcess(args, code, stdout, stderr)
        return command

    def test_valid_archive_fixture_checks_native_export_without_leaking_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, config, profile, entitlements = self.fixture(directory)
            with patch.object(validator.subprocess, "run", side_effect=self.commands(profile, entitlements)):
                report = validator.validate(archive, config)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["bundleIdentifier"], records()[1]["bundleIdentifier"])
            self.assertNotIn(CANARY.decode(), json.dumps(report))

    def test_invalid_signature_profile_certificate_and_entitlements_are_rejected(self):
        for case in ("signature", "profile_expired", "certificate_expired", "certificate_mismatch",
                     "profile_debug", "ad_hoc", "legacy_prefix", "wrong_signed_id", "missing_team", "extra_group"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                archive, config, profile, entitlements = self.fixture(directory)
                signature_ok, expiry = True, "Jan  1 00:00:00 2099 GMT"
                if case == "signature": signature_ok = False
                if case == "profile_expired": profile["ExpirationDate"] = dt.datetime(2000, 1, 1)
                if case == "certificate_expired": expiry = "Jan  1 00:00:00 2000 GMT"
                if case == "certificate_mismatch": profile["DeveloperCertificates"] = [b"other certificate"]
                if case == "profile_debug": profile["Entitlements"]["get-task-allow"] = True
                if case == "ad_hoc": profile["ProvisionedDevices"] = ["fixture device"]
                if case == "legacy_prefix": profile["ApplicationIdentifierPrefix"] = ["OTHERTEAM1"]
                if case == "wrong_signed_id":
                    profile["Entitlements"]["application-identifier"] = records()[1]["teamIdentifier"] + ".*"
                    entitlements["application-identifier"] = records()[1]["teamIdentifier"] + ".org.other.app"
                if case == "missing_team": del entitlements["com.apple.developer.team-identifier"]
                if case == "extra_group": entitlements["keychain-access-groups"].append("OTHERTEAM1.extra")
                with patch.object(validator.subprocess, "run", side_effect=self.commands(profile, entitlements, signature_ok=signature_ok, expiry=expiry)):
                    with self.assertRaises(ValueError):
                        validator.validate(archive, config)

    def test_changed_archive_bundle_is_rejected_before_signing_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, config, _, _ = self.fixture(directory)
            info = archive / "Products/Applications/StarterApp.app/Info.plist"
            data = plistlib.loads(info.read_bytes()); data["CFBundleIdentifier"] = "org.other.app"
            info.write_bytes(plistlib.dumps(data))
            with patch.object(validator.subprocess, "run") as command:
                with self.assertRaises(ValueError): validator.validate(archive, config)
                command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
