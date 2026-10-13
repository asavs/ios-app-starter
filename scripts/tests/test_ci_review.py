import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from scripts import review_ci


class CIReviewTests(unittest.TestCase):
    def test_test_summary_extracts_counts_and_ios_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.md"
            path.write_text(
                "## iOS tests: passed\n\nDestination:\n"
                "```text\nplatform=iOS Simulator,name=iPhone 17,OS=27.0\n```\n\n"
                "| Total | Passed | Failed | Skipped |\n|---|---|---|---|\n"
                "| 1 | 1 | 0 | 0 |\n",
                encoding="utf-8",
            )
            self.assertEqual(
                review_ci.parse_test_summary(path),
                {"runtime": "name=iPhone 17,OS=27.0", "counts": (1, 1, 0, 0),
                 "passed": True, "failed": False},
            )

    def test_artifact_extracts_public_app_and_symbol_fields_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "built-app.json").write_text(json.dumps({
                "CFBundleDisplayName": "Starter App",
                "CFBundleIdentifier": "com.example.StarterApp",
                "MinimumOSVersion": "17.0", "UIDeviceFamily": [1, 2],
                "unrelated": "must not be reported",
            }), encoding="utf-8")
            (root / "symbols.json").write_text(json.dumps({
                "status": "matched", "bundleIdentifier": "com.example.StarterApp",
                "marketingVersion": "1.0", "buildNumber": "2",
                "commit": "abc123", "images": [{
                    "uuid": "B3197B45-3C86-36B4-91A4-6EC891966551",
                    "architecture": "arm64",
                }], "unrelated": "must not be reported",
            }), encoding="utf-8")
            result = review_ci.artifact_evidence(root, "testflight-preflight")
            self.assertEqual(result["apps"][0]["bundle"], "com.example.StarterApp")
            self.assertEqual(result["symbols"][0]["images"][0]["architecture"], "arm64")
            self.assertFalse(result["symbols"][0]["ipaCompared"])
            self.assertNotIn("unrelated", json.dumps(result))

    def test_delivery_artifact_marks_ipa_comparison_and_reads_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "configuration.json").write_text(json.dumps([{
                "configuration": "Debug", "displayName": "Demo",
                "bundleIdentifier": "com.example.demo", "minimumIOS": "17.0",
                "deviceFamilies": "1,2",
            }]), encoding="utf-8")
            (root / "symbols.json").write_text(json.dumps({
                "status": "matched", "images": [],
            }), encoding="utf-8")
            result = review_ci.artifact_evidence(root, "testflight-delivery-demo")
            self.assertEqual(result["apps"][0]["bundle"], "com.example.demo")
            self.assertTrue(result["symbols"][0]["ipaCompared"])

    def test_render_separates_skips_and_labels_checkout_mismatch(self):
        text = review_ci.render({
            "number": 42, "url": "https://github.com/a/b/pull/42",
            "headSha": "abc", "headBranch": "topic", "baseBranch": "main",
            "checkoutSha": "old", "checkoutBranch": "main", "checkoutMatches": False,
            "mergeSha": None, "mainRuns": [],
            "checks": [{"name": "deliver", "workflowName": "TestFlight",
                        "conclusion": "SKIPPED", "detailsUrl": "https://github.com/a/b/actions/runs/123"}],
            "artifacts": [],
        })
        self.assertIn("**MISMATCH**", text)
        self.assertIn("policy/job skip", text)
        self.assertIn("do not count as passing", text)

    def test_elapsed_formats_check_runtime(self):
        self.assertEqual(
            review_ci.elapsed("2026-10-12T10:00:00Z", "2026-10-12T10:08:31Z"),
            "8m 31s",
        )

    def test_artifact_listing_rejects_unsafe_names(self):
        listing = {"artifacts": [
            {"name": "ios-test-results-starter", "expired": False},
            {"name": "ios-test-results-a/../../outside", "expired": False},
            {"name": "testflight-preflight", "expired": True},
        ]}
        with patch.object(review_ci, "gh", return_value=SimpleNamespace(stdout=json.dumps(listing))):
            artifacts = review_ci.artifacts_for_run("owner/repo", "123")
        self.assertEqual([item["name"] for item in artifacts], ["ios-test-results-starter"])

    def test_built_app_check_adds_identity_and_artifact_link_to_job_summary(self):
        checker = Path(__file__).resolve().parents[1] / "check-built-app.py"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / "report"
            app = report / "run.test/DerivedData/Build/Products/Debug-iphonesimulator/StarterApp.app"
            app.mkdir(parents=True)
            config = report / "configuration.json"
            config.write_text(json.dumps([{
                "configuration": "Debug", "displayName": "Starter App",
                "bundleIdentifier": "com.example.StarterApp", "minimumIOS": "17.0",
                "deviceFamilies": "1,2",
            }]), encoding="utf-8")
            with (app / "Info.plist").open("wb") as output:
                plistlib.dump({
                    "CFBundleDisplayName": "Starter App",
                    "CFBundleIdentifier": "com.example.StarterApp",
                    "MinimumOSVersion": "17.0", "UIDeviceFamily": [1, 2],
                }, output)
            summary = root / "step-summary.md"
            env = os.environ.copy()
            env.update({
                "GITHUB_STEP_SUMMARY": str(summary),
                "GITHUB_SERVER_URL": "https://github.com",
                "GITHUB_REPOSITORY": "owner/repo", "GITHUB_RUN_ID": "123",
                "IOS_TEST_DESTINATION": "platform=iOS Simulator,name=iPhone 17,OS=27.0",
                "IOS_TEST_ARTIFACT_NAME": "ios-test-results-starter",
            })
            result = subprocess.run(
                [sys.executable, str(checker), str(config), str(report)],
                capture_output=True, text=True, env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            content = summary.read_text(encoding="utf-8")
            self.assertIn("com.example.StarterApp", content)
            self.assertIn("iPhone 17,OS=27.0", content)
            self.assertIn("[ios-test-results-starter](https://github.com/owner/repo/actions/runs/123)", content)


if __name__ == "__main__":
    unittest.main()
