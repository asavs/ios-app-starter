import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPORTER = Path(__file__).resolve().parents[1] / "report-tests.py"


class ReportTests(unittest.TestCase):
    def report(self, result, status, log="", tests=None, manifest=None, images=()):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "results.json").write_text(json.dumps(result))
            (path / "xcodebuild.log").write_text(log)
            if tests is not None:
                (path / "tests.json").write_text(json.dumps(tests))
            if manifest is not None:
                (path / "attachments").mkdir()
                (path / "attachments" / "manifest.json").write_text(json.dumps(manifest))
                for name in images:
                    (path / "attachments" / name).write_bytes(b"png")
            env = os.environ.copy()
            env["GITHUB_STEP_SUMMARY"] = str(path / "github-summary.md")
            env["IOS_TEST_ARTIFACT_NAME"] = "ios-test-results-starter"
            env["GITHUB_SERVER_URL"] = "https://github.com"
            env["GITHUB_REPOSITORY"] = "owner/repo"
            env["GITHUB_RUN_ID"] = "123"
            process = subprocess.run(
                [sys.executable, str(REPORTER), directory, str(status), "test simulator"],
                env=env, capture_output=True, text=True,
            )
            summary = (path / "summary.md").read_text()
            self.assertEqual(summary, (path / "github-summary.md").read_text())
            self.last_failures = json.loads((path / "failures.json").read_text())
            return process.returncode, summary

    def test_passing_run_has_counts(self):
        code, summary = self.report(dict(result="Passed", totalTestCount=1,
                                        passedTests=1, failedTests=0, skippedTests=0), 0)
        self.assertEqual(code, 0)
        self.assertIn("| 1 | 1 | 0 | 0 |", summary)
        self.assertIn("[ios-test-results-starter](https://github.com/owner/repo/actions/runs/123)", summary)

    def test_assertion_failure_has_test_name_and_detail(self):
        code, summary = self.report(dict(result="Failed", totalTestCount=1,
                                        passedTests=0, failedTests=1, skippedTests=0,
                                        testFailures=[dict(testName="testWelcomeScreen",
                                                           failureText="XCTAssertTrue failed")]), 65)
        self.assertEqual(code, 1)
        self.assertIn("testWelcomeScreen", summary)
        self.assertIn("XCTAssertTrue failed", summary)

    def test_build_failure_without_results_keeps_diagnostic(self):
        code, summary = self.report(None, 65, "error: Simulator unavailable")
        self.assertEqual(code, 1)
        self.assertIn("error: Simulator unavailable", summary)
        self.assertIn("No readable test counts", summary)

    def test_success_without_results_is_not_verified(self):
        code, summary = self.report(None, 0)
        self.assertEqual(code, 1)
        self.assertIn("could not be verified", summary)

    def test_zero_executed_tests_is_not_verified(self):
        code, _ = self.report(dict(result="Passed", totalTestCount=0,
                                   passedTests=0, failedTests=0, skippedTests=0), 0)
        self.assertEqual(code, 1)

    RED_TESTS = {"testNodes": [{"nodeType": "Test Plan", "name": "StarterApp", "result": "Failed", "children": [
        {"nodeType": "UI test bundle", "name": "StarterAppUITests", "result": "Failed", "children": [
            {"nodeType": "Test Suite", "name": "StarterAppUITests", "result": "Failed", "children": [
                {"nodeType": "Test Case", "name": "testWelcomeScreen()", "result": "Failed",
                 "nodeIdentifier": "StarterAppUITests/testWelcomeScreen()", "children": [
                    {"nodeType": "Failure Message", "name": "StarterAppUITests.swift:31: failed - Deliberate failure probe"}]}]}]}]}]}
    MANIFEST = [{"testIdentifier": "StarterAppUITests/testWelcomeScreen()", "attachments": [
        {"exportedFileName": "A1.png", "suggestedHumanReadableName": "welcome-screen", "isAssociatedWithFailure": False},
        {"exportedFileName": "B2.mp4", "suggestedHumanReadableName": "Screen Recording.mp4", "isAssociatedWithFailure": False}]}]

    def test_per_test_results_give_file_and_line(self):
        code, summary = self.report(dict(result="Failed", totalTestCount=1, passedTests=0, failedTests=1, skippedTests=0,
                                         testFailures=[dict(testName="testWelcomeScreen()", failureText="failed - Deliberate failure probe")]),
                                    65, tests=self.RED_TESTS)
        self.assertEqual(code, 1)
        self.assertIn("`StarterAppUITests.swift:31`", summary)
        self.assertIn("Stage: `tests_failed`", summary)
        failure = self.last_failures["failures"][0]
        self.assertEqual((failure["file"], failure["line"], failure["target"]), ("StarterAppUITests.swift", 31, "StarterAppUITests"))
        self.assertEqual(failure["message"], "failed - Deliberate failure probe")

    def test_screenshots_listed_and_videos_noted(self):
        code, summary = self.report(dict(result="Passed", totalTestCount=1, passedTests=1, failedTests=0, skippedTests=0), 0,
                                    manifest=self.MANIFEST, images=("A1.png",))
        self.assertEqual(code, 0)
        self.assertIn("### Screenshots", summary)
        self.assertIn("`attachments/A1.png` — welcome-screen", summary)
        self.assertIn("Other attachments listed in the manifest: Screen Recording.mp4", summary)
        images = [item for item in self.last_failures["attachments"] if item["isImage"]]
        self.assertEqual((images[0]["file"], images[0]["bytes"]), ("A1.png", 3))

    def test_compiler_errors_are_structured(self):
        log = ("/Users/runner/work/app/StarterApp/StarterApp/ContentView.swift:12:9: error: cannot find 'foo' in scope\n"
               "2026-10-13 17:11:18 xcodebuild[1:2] [MT] IDELaunch failed for path\n"
               "xcodebuild: error: Unable to find a destination matching the provided destination specifier\n"
               "/Users/runner/work/app/StarterApp/StarterApp/ContentView.swift:12:9: error: cannot find 'foo' in scope\n"
               "/Users/runner/work/app/StarterApp/StarterAppUITests/StarterAppUITests.swift:31: error: -[StarterAppUITests.StarterAppUITests testWelcomeScreen] : failed - probe\n")
        code, summary = self.report(None, 65, log)
        self.assertEqual(code, 1)
        self.assertIn("Stage: `build_failed`", summary)
        self.assertIn("### Build errors", summary)
        errors = self.last_failures["buildErrors"]
        self.assertEqual(len(errors), 2, "assertion-failure echo lines are not build errors")
        self.assertEqual((errors[0]["file"].rsplit("/", 1)[-1], errors[0]["line"], errors[0]["column"]), ("ContentView.swift", 12, 9))
        self.assertEqual(errors[0]["message"], "cannot find 'foo' in scope")
        self.assertIsNone(errors[1]["file"])

    def test_setup_failure_without_compiler_errors(self):
        code, summary = self.report(None, 70, "Simulator boot timed out")
        self.assertEqual(code, 1)
        self.assertIn("Stage: `setup_failed`", summary)
        self.assertIn("### Build/test diagnostics", summary)

    LIFECYCLE_MESSAGE = "Failed to terminate org.example.notes:14090: Failed to terminate org.example.notes:0"
    LIFECYCLE_CASE = "testOnboardingNotShownAgainAfterCompletion"
    LIFECYCLE_FILE = "/Users/runner/work/app/StarterApp/StarterAppUITests/StarterAppUITests.swift"

    def lifecycle_report(self, log):
        tests = {"testNodes": [{"nodeType": "UI test bundle", "name": "StarterAppUITests", "children": [
            {"nodeType": "Test Suite", "name": "StarterAppUITests", "children": [
            {"nodeType": "Test Case", "name": self.LIFECYCLE_CASE + "()", "result": "Failed",
             "nodeIdentifier": "StarterAppUITests/" + self.LIFECYCLE_CASE + "()", "children": [
                 {"nodeType": "Failure Message", "name": self.LIFECYCLE_MESSAGE}]}]}]}]}
        return self.report(dict(result="Failed", totalTestCount=1, passedTests=0, failedTests=1, skippedTests=0),
                           65, log=log, tests=tests)

    def lifecycle_log(self, line=183, suite="StarterAppUITests.StarterAppUITests", method=None, message=None):
        return (f"{self.LIFECYCLE_FILE}:{line}: error: -[{suite} {method or self.LIFECYCLE_CASE}] : "
                f"{message or self.LIFECYCLE_MESSAGE}\n")

    def test_lifecycle_failure_recovers_source_without_becoming_build_error(self):
        code, summary = self.lifecycle_report(self.lifecycle_log() * 2)
        self.assertEqual(code, 1, "A recovered location must not turn the failed test green")
        self.assertIn("Stage: `tests_failed`", summary)
        self.assertIn(f"{self.LIFECYCLE_FILE}:183", summary)
        failure, = self.last_failures["failures"]
        self.assertEqual((failure["file"], failure["line"]), (self.LIFECYCLE_FILE, 183))
        self.assertEqual(failure["message"], self.LIFECYCLE_MESSAGE)
        self.assertEqual(self.last_failures["buildErrors"], [])

    def test_source_fallback_requires_both_case_and_message(self):
        for log in (self.lifecycle_log(suite="AnotherSuite"),
                    self.lifecycle_log(suite="AnotherBundle.StarterAppUITests"),
                    self.lifecycle_log(method="testAnotherMethod"),
                    self.lifecycle_log(message="A different failure")):
            with self.subTest(log=log):
                self.lifecycle_report(log)
                failure, = self.last_failures["failures"]
                self.assertIsNone(failure["file"])
                self.assertIsNone(failure["line"])

    def test_ambiguous_log_locations_stay_unknown(self):
        self.lifecycle_report(self.lifecycle_log(183) + self.lifecycle_log(184))
        failure, = self.last_failures["failures"]
        self.assertIsNone(failure["file"])
        self.assertIsNone(failure["line"])

    def test_log_fallback_preserves_xcresult_location(self):
        log = (f"{self.LIFECYCLE_FILE}:99: error: -[StarterAppUITests.StarterAppUITests testWelcomeScreen] : "
               "failed - Deliberate failure probe\n")
        self.report(dict(result="Failed", totalTestCount=1, passedTests=0, failedTests=1, skippedTests=0),
                    65, log=log, tests=self.RED_TESTS)
        failure, = self.last_failures["failures"]
        self.assertEqual((failure["file"], failure["line"]), ("StarterAppUITests.swift", 31))

    def test_log_echo_does_not_create_a_failure_in_a_passing_result(self):
        code, _ = self.report(dict(result="Passed", totalTestCount=1, passedTests=1, failedTests=0, skippedTests=0),
                              0, log=self.lifecycle_log())
        self.assertEqual(code, 0)
        self.assertEqual(self.last_failures["failures"], [])


if __name__ == "__main__":
    unittest.main()
