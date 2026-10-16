import io
import json
import os
from pathlib import Path
import plistlib
import shutil
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
        self.assertIsNone(review_ci.elapsed("2026-10-12T10:00:00Z", "0001-01-01T00:00:00Z"))

    def test_artifact_listing_rejects_unsafe_names(self):
        listing = {"artifacts": [
            {"name": "ios-test-results-starter", "expired": False},
            {"name": "ios-test-results-a/../../outside", "expired": False},
            {"name": "testflight-preflight", "expired": True},
        ]}
        with patch.object(review_ci, "gh", return_value=SimpleNamespace(stdout=json.dumps(listing))):
            artifacts = review_ci.artifacts_for_run("owner/repo", "123")
        self.assertEqual([item["name"] for item in artifacts], ["ios-test-results-starter"])

    def test_artifact_listing_accepts_compatibility_names_and_rejects_unsafe_variants(self):
        listing = {"artifacts": [
            {"name": "compatibility-report", "expired": False},
            {"name": "ios-compat-starter-ios-17-0-1", "expired": False},
            {"name": "compatibility-plan", "expired": False},
            {"name": "compat-inventory-macos-14", "expired": False},
            {"name": "ios-compat-starter/../escape", "expired": False},
            {"name": "compatibility-report.zip", "expired": False},
            {"name": "ios-compat-starter-ios-27-0", "expired": True},
        ]}
        with patch.object(review_ci, "gh", return_value=SimpleNamespace(stdout=json.dumps(listing))):
            artifacts = review_ci.artifacts_for_run("owner/repo", "123")
        self.assertEqual([item["name"] for item in artifacts],
                         ["compatibility-report", "ios-compat-starter-ios-17-0-1"])

    def test_compatibility_report_summarizes_verified_runtimes_and_lane_statuses(self):
        fixture = Path(__file__).resolve().parent / "fixtures" / "compatibility-report.json"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy(fixture, root / "compatibility-report.json")
            evidence = review_ci.artifact_evidence(root, "compatibility-report")
        self.assertEqual(evidence["compatibility"]["verifiedRuntimes"], ["17.0.1"])
        self.assertFalse(evidence["compatibility"]["allPassed"])
        self.assertEqual([lane["status"] for lane in evidence["compatibility"]["lanes"]],
                         ["passed", "missing"])
        serialized = json.dumps(evidence)
        self.assertNotIn("xcode_path", serialized)
        self.assertNotIn("destination", serialized)
        text = "\n".join(review_ci.artifact_lines([{
            "name": "compatibility-report", "runUrl": "https://github.com/a/b/actions/runs/9",
            "stage": "run", "evidence": evidence,
        }], pending=False))
        self.assertIn("verified runtimes **17.0.1**; some planned lanes did not pass", text)
        self.assertIn("**passed** - ios-17-0-1: iOS 17.0 (17.0.1) on `iPhone SE (3rd generation)`; "
                      "Xcode 16.2 / SDK 18.2; runner `macos-14`; tests 1/1 passed, 0 failed, 0 skipped", text)
        self.assertIn("**missing** - ios-27-0: iOS 27.0 (27.0) on `iPhone 17`; Xcode 27.0 / SDK 27.0; "
                      "runner `xcode-27`; test counts unavailable", text)

    def test_compatibility_markdown_fallback_reads_verified_runtimes_line(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "compatibility-report.md").write_text(
                "## iOS compatibility coverage\n\nAll planned lanes passed.\n\n"
                "Verified runtimes: 17.0.1, 27.0\n", encoding="utf-8")
            evidence = review_ci.artifact_evidence(root, "compatibility-report")
        self.assertEqual(evidence["compatibility"],
                         {"verifiedRuntimes": ["17.0.1", "27.0"], "allPassed": True, "lanes": []})

    def test_compat_lane_artifact_reuses_test_result_extraction_and_lane_result(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            run = root / "run.abc"
            run.mkdir()
            (run / "summary.md").write_text(
                "## iOS tests: passed\n\n`platform=iOS Simulator,name=iPhone SE (3rd generation),OS=17.0.1`\n\n"
                "| Total | Passed | Failed | Skipped |\n|---|---|---|---|\n| 1 | 1 | 0 | 0 |\n",
                encoding="utf-8")
            (root / "built-app.json").write_text(json.dumps({
                "CFBundleIdentifier": "com.example.StarterApp", "CFBundleDisplayName": "Starter App",
                "MinimumOSVersion": "17.0", "UIDeviceFamily": [1, 2]}), encoding="utf-8")
            (root / "lane-result.json").write_text(json.dumps({
                "lane": "ios-17-0-1", "runner": "macos-14", "runtime_name": "iOS 17.0",
                "runtime_version": "17.0.1", "device": "iPhone SE (3rd generation)",
                "xcode_version": "16.2", "sdk": "18.2", "status": "passed", "exit_status": 0,
                "total": 1, "passed": 1, "failed": 0, "skipped": 0,
                "xcode_path": "/Applications/Xcode_16.2.app"}), encoding="utf-8")
            (run / "xcodebuild.log").write_text("secret-looking log line\n", encoding="utf-8")
            evidence = review_ci.artifact_evidence(root, "ios-compat-starter-ios-17-0-1")
        self.assertEqual(evidence["tests"][0]["counts"], (1, 1, 0, 0))
        self.assertEqual(evidence["apps"][0]["bundle"], "com.example.StarterApp")
        self.assertEqual(evidence["lanes"][0]["status"], "passed")
        self.assertNotIn("xcode_path", json.dumps(evidence))
        self.assertNotIn("secret-looking", json.dumps(evidence))
        self.assertIsNone(evidence["compatibility"])

    def test_render_run_lists_jobs_with_skips_elapsed_and_checkout_mismatch(self):
        text = review_ci.render({
            "mode": "run", "runId": "555", "selection": None,
            "run": {
                "id": 555, "name": "iOS", "event": "push", "head_branch": "topic",
                "head_sha": "abc", "status": "completed", "conclusion": "success",
                "run_attempt": 2, "html_url": "https://github.com/a/b/actions/runs/555",
                "run_started_at": "2026-10-16T10:00:00Z", "updated_at": "2026-10-16T10:09:30Z",
                "jobs": [
                    {"name": "scripts", "conclusion": "success",
                     "started_at": "2026-10-16T10:00:10Z", "completed_at": "2026-10-16T10:01:12Z"},
                    {"name": "test (starter)", "conclusion": "skipped",
                     "started_at": "0001-01-01T00:00:00Z", "completed_at": "0001-01-01T00:00:00Z"},
                    {"name": "slow", "status": "in_progress", "conclusion": None},
                ],
            },
            "checkoutSha": "def", "checkoutBranch": "topic", "checkoutMatches": False,
            "artifacts": [{"name": "ios-test-results-starter", "stage": "run",
                           "runUrl": "https://github.com/a/b/actions/runs/555",
                           "downloadSkipped": True,
                           "evidence": review_ci.empty_evidence("ios-test-results-starter")}],
        })
        self.assertIn("# CI evidence for run 555", text)
        self.assertIn("Workflow: iOS; event `push`; branch `topic`; attempt 2", text)
        self.assertIn("Status: completed / **success**; 9m 30s", text)
        self.assertIn("**MISMATCH**", text)
        self.assertIn("- success - scripts; 1m 2s", text)
        self.assertIn("- policy/job skip - test (starter)\n", text)
        self.assertIn("- in_progress - slow\n", text)
        self.assertIn("### [ios-test-results-starter](https://github.com/a/b/actions/runs/555) - run", text)
        self.assertIn("Download skipped by `--no-download`.", text)
        self.assertIn("do not count as passing", text)

    def test_latest_run_selection_filters_by_workflow_and_picks_newest(self):
        listing = [
            {"databaseId": 2, "workflowName": "iOS", "event": "push", "status": "completed",
             "conclusion": "failure", "createdAt": "2026-10-16T09:00:00Z"},
            {"databaseId": 3, "workflowName": "iOS", "event": "pull_request", "status": "in_progress",
             "conclusion": None, "createdAt": "2026-10-16T11:00:00Z"},
            {"databaseId": 1, "workflowName": "iOS", "event": "push", "status": "completed",
             "conclusion": "success", "createdAt": "2026-10-16T10:00:00Z"},
        ]
        calls = []

        def fake_gh(args, **kwargs):
            calls.append(list(args))
            return SimpleNamespace(stdout=json.dumps(listing))

        with patch.object(review_ci, "gh", side_effect=fake_gh):
            run_id, reason = review_ci.select_latest_run("topic", workflow="iOS", limit=5)
        self.assertEqual(run_id, "3")
        self.assertIn("Selected run 3 (iOS, `pull_request`, in_progress, created 2026-10-16T11:00:00Z)", reason)
        self.assertIn("newest of 3 run(s) listed for branch `topic`, workflow `iOS` (limit 5)", reason)
        self.assertEqual(calls[0][:5], ["run", "list", "--branch", "topic", "--limit"])
        self.assertEqual(calls[0][-2:], ["--workflow", "iOS"])

    def test_latest_run_selection_reports_no_runs(self):
        with patch.object(review_ci, "gh", return_value=SimpleNamespace(stdout="[]")):
            with self.assertRaises(review_ci.ReviewError) as context:
                review_ci.select_latest_run("empty-branch")
        self.assertEqual(str(context.exception), "No workflow runs were found for branch `empty-branch`.")
        with patch.object(review_ci, "gh", return_value=SimpleNamespace(stdout=json.dumps([{"databaseId": 1}]))):
            run_id, reason = review_ci.select_latest_run("topic")
        self.assertEqual(run_id, "1")
        self.assertNotIn("--workflow", reason)
        self.assertNotIn("workflow `", reason)

    def test_collect_run_assembles_metadata_jobs_and_allowlisted_artifacts(self):
        responses = {
            "repos/o/r/actions/runs/777": {
                "id": 777, "name": "iOS compatibility matrix", "event": "workflow_dispatch",
                "head_branch": "main", "head_sha": "ABC", "status": "completed",
                "conclusion": "success", "html_url": "https://github.com/o/r/actions/runs/777"},
            "repos/o/r/actions/runs/777/jobs?per_page=100": {"jobs": [
                {"name": "plan", "conclusion": "success"}, "not-a-job"]},
            "repos/o/r/actions/runs/777/artifacts": {"artifacts": [
                {"name": "compatibility-report", "expired": False},
                {"name": "compat-inventory-macos-14", "expired": False},
                {"name": "ios-compat-starter-ios-17-0-1", "expired": False}]},
        }
        downloads = []

        def fake_gh(args, **kwargs):
            if args[:2] == ["repo", "view"]:
                return SimpleNamespace(stdout="o/r\n")
            if args[0] == "api":
                return SimpleNamespace(stdout=json.dumps(responses[args[1]]))
            if args[:2] == ["run", "download"]:
                downloads.append(list(args))
                return SimpleNamespace(stdout="")
            raise AssertionError(f"unexpected gh call: {args}")

        def fake_git(args, **kwargs):
            return SimpleNamespace(stdout="abc\n" if args == ["rev-parse", "HEAD"] else "main\n")

        with patch.object(review_ci, "gh", side_effect=fake_gh), \
                patch.object(review_ci, "git", side_effect=fake_git):
            report = review_ci.collect_run("777", download=False, selection="Selected run 777: test")
        self.assertEqual(report["mode"], "run")
        self.assertTrue(report["checkoutMatches"])
        self.assertEqual(report["run"]["jobs"], [{"name": "plan", "conclusion": "success"}])
        self.assertEqual([item["name"] for item in report["artifacts"]],
                         ["compatibility-report", "ios-compat-starter-ios-17-0-1"])
        self.assertTrue(all(item["downloadSkipped"] for item in report["artifacts"]))
        self.assertEqual(downloads, [])
        text = review_ci.render(report)
        self.assertIn("Selected run 777: test", text)
        self.assertIn("- success - plan", text)
        self.assertIn("**MATCH**", text)

    def test_cli_modes_are_mutually_exclusive_and_validated(self):
        cases = (
            ["--pr", "1", "--run", "2"],
            ["--run", "abc"],
            ["--run", "1", "--branch", "main"],
            ["--pr", "0"],
            [],
        )
        for argv in cases:
            with self.subTest(argv=argv), patch.object(sys, "argv", ["review_ci.py", *argv]), \
                    patch("sys.stderr", new_callable=io.StringIO):
                with self.assertRaises(SystemExit) as context:
                    review_ci.main()
                self.assertEqual(context.exception.code, 2)

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
                    "MinimumOSVersion": "17.0", "UIDeviceFamily": [1, 2], "ITSAppUsesNonExemptEncryption": False,
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
