import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("doctor", ROOT / "scripts/apple-doctor.py")
doctor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doctor)
CANARY = "PRIVATE-CREDENTIAL-CANARY"
RECORDS = [dict(configuration=c, bundleIdentifier="org.example.notes", minimumIOS="17.0") for c in ("Debug", "Release")]
ENV = dict(ASC_KEY_ID=CANARY, ASC_ISSUER_ID=CANARY, ASC_PRIVATE_KEY=CANARY)


class FakeReader:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.commands = []

    def read(self, command):
        self.commands.append(command)
        return next(self.responses)


class DiagnosticsTests(unittest.TestCase):
    def test_account_summary_distinguishes_skips_failures_and_completed_reads(self):
        cases = [
            ({"environment": {}}, "not_configured", 0),
            ({"environment": ENV, "records": None}, "missing_configuration", 0),
            ({"environment": ENV}, "missing_tool", 0),
            ({"environment": ENV, "reader": FakeReader([("authentication_failed", None)] * 3)}, "authentication_failed", 0),
            ({"environment": ENV, "reader": FakeReader([("inaccessible", None)] * 3)}, "inaccessible", 0),
            ({"environment": ENV, "reader": FakeReader([("verified", []), ("verified", []), ("verified", [])])}, "incomplete", 3),
            ({"environment": ENV, "reader": FakeReader([("verified", []), ("verified", [{"id": "B123"}]), ("verified", []), ("verified", [])])}, "completed", 4),
        ]
        for overrides, status, count in cases:
            with self.subTest(status=status):
                report = doctor.diagnose(**{"records": RECORDS, "account": True, **overrides})
                self.assertEqual(report["accountSummary"]["status"], status)
                self.assertEqual(report["accountSummary"]["successfulChecks"], count)
                self.assertNotIn(CANARY, json.dumps(report) + doctor.markdown(report))
        self.assertEqual(doctor.diagnose(environment={})["accountSummary"]["status"], "not_requested")

    def test_github_summary_and_warning_are_sanitized_and_completed_reads_do_not_warn(self):
        with tempfile.TemporaryDirectory() as directory:
            summary = Path(directory) / "summary.md"
            report = doctor.diagnose(RECORDS, True, environment={})
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                doctor.publish_summary(report, doctor.markdown(report), {
                    "GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(summary), "ASC_PRIVATE_KEY": CANARY})
            self.assertIn("::warning::Account reads were requested but skipped", stdout.getvalue())
            self.assertIn("**Account checks: not_configured**", summary.read_text(encoding="utf-8"))
            self.assertNotIn(CANARY, summary.read_text(encoding="utf-8") + stdout.getvalue())
            reader = FakeReader([("verified", []), ("verified", [{"id": "B123"}]), ("verified", []), ("verified", [])])
            report = doctor.diagnose(RECORDS, True, environment=ENV, reader=reader)
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                doctor.publish_summary(report, doctor.markdown(report), {"GITHUB_ACTIONS": "true"})
            self.assertEqual(stdout.getvalue(), "")

    def test_offline_does_not_contact_apple_or_read_private_key(self):
        with patch.object(subprocess, "run", side_effect=AssertionError("network command")):
            report = doctor.diagnose(RECORDS, environment=ENV)
        self.assertNotIn(CANARY, json.dumps(report) + doctor.markdown(report))
        self.assertIn("not_verified", [f["status"] for f in report["findings"]])

    def test_forbidden_is_not_missing_and_other_reads_continue(self):
        reader = FakeReader([("verified", []), ("inaccessible", None), ("authentication_failed", None)])
        findings = doctor.account_checks(reader, "org.example.notes")
        self.assertEqual([f["status"] for f in findings], ["missing", "inaccessible", "authentication_failed", "not_verified"])
        self.assertEqual(len(reader.commands), 3)

    def test_matching_profiles_use_resource_id_and_do_not_export_account_data(self):
        reader = FakeReader([("verified", [{"id": CANARY}]), ("verified", [{"id": "BUNDLE123", "secret": CANARY}]),
                             ("verified", [{"certificateContent": CANARY}]), ("verified", [{"profileContent": CANARY}])])
        result = doctor.account_checks(reader, "org.example.notes")
        self.assertEqual(reader.commands[-1], ["bundle-ids", "profiles", "list", "--id", "BUNDLE123"])
        self.assertNotIn(CANARY, json.dumps(result))
        self.assertTrue(all(f["status"] == "present" for f in result))

    def test_untrusted_errors_and_malformed_responses_are_not_logged(self):
        with tempfile.TemporaryDirectory() as directory:
            reader = doctor.Reader("asc", {**ENV, "ASC_PROFILE": "unrelated", "ASC_DEBUG": "1"}, directory)
            self.assertNotIn("ASC_PROFILE", reader.env)
            self.assertNotIn("ASC_DEBUG", reader.env)
            self.assertEqual(reader.env["ASC_BYPASS_KEYCHAIN"], "1")
            self.assertEqual(reader.env["ASC_TELEMETRY_DISABLED"], "1")
            self.assertEqual(reader.env["TEMP"], str(Path(directory).resolve()))
            self.assertEqual(reader.env["TMPDIR"], reader.env["TEMP"])
            for code, output, error, expected in [(1, "", "Forbidden " + CANARY, "inaccessible"),
                                                (1, "", "HTTP 404 " + CANARY, "not_verified"),
                                                (0, CANARY, "", "not_verified"),
                                                (0, '{"data": {}}', "", "not_verified"),
                                                (0, '{"data": []}', "", "verified")]:
                with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], code, output, error)):
                    status, data = reader.read(["apps", "list"])
                self.assertEqual(status, expected)
                self.assertNotIn(CANARY, json.dumps((status, data)))

    def test_timeout_remains_unverified(self):
        with tempfile.TemporaryDirectory() as directory:
            reader = doctor.Reader("asc", ENV, directory)
            with patch.object(subprocess, "run", side_effect=subprocess.TimeoutExpired("asc", 120)):
                self.assertEqual(reader.read(["apps", "list"]), ("not_verified", None))

    def test_wrapper_cleans_child_key_material_after_timeout(self):
        files = []
        def interrupted_child(*args, **kwargs):
            path = Path(kwargs["env"]["TEMP"]) / "asc-key-timeout.p8"
            path.write_text(CANARY)
            files.append(path)
            raise subprocess.TimeoutExpired("asc", 120)
        with patch.object(subprocess, "run", side_effect=interrupted_child):
            report = doctor.diagnose(RECORDS, True, "asc", environment=ENV)
        self.assertTrue(files)
        self.assertTrue(all(not path.exists() for path in files))
        self.assertNotIn(CANARY, json.dumps(report))

    def test_malformed_or_mismatched_configuration_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "configuration.json"
            for records in [[], [RECORDS[0]], [RECORDS[0], {**RECORDS[1], "bundleIdentifier": "org.other.app"}],
                            [RECORDS[0], {**RECORDS[1], "minimumIOS": CANARY}]]:
                path.write_text(json.dumps(records), encoding="utf-8")
                with self.assertRaises(ValueError):
                    doctor.configuration(path)
            path.write_text(json.dumps(RECORDS), encoding="utf-8")
            self.assertEqual(doctor.configuration(path), RECORDS)

    def test_native_cli_invalid_credentials_are_isolated_and_redacted(self):
        binary = ROOT / "build/tools" / ("asc.exe" if os.name == "nt" else "asc")
        if not binary.exists():
            self.skipTest("Install the pinned binary to exercise native credential rejection")
        with tempfile.TemporaryDirectory() as directory:
            reader = doctor.Reader(binary, {**os.environ, **ENV}, directory)
            findings = doctor.account_checks(reader, "org.example.notes")
            self.assertTrue(all(f["status"] == "not_verified" for f in findings))
            self.assertNotIn(CANARY, json.dumps(findings))
            self.assertFalse((Path(directory) / "absent-config.json").exists())

    def test_incomplete_credentials_do_not_run_reads(self):
        reader = FakeReader([])
        report = doctor.diagnose(RECORDS, True, environment={"ASC_KEY_ID": CANARY}, reader=reader)
        self.assertEqual(reader.commands, [])
        self.assertNotIn(CANARY, json.dumps(report))


if __name__ == "__main__":
    unittest.main()
