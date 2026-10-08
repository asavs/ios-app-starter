import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPORTER = Path(__file__).resolve().parents[1] / "report-tests.py"


class ReportTests(unittest.TestCase):
    def report(self, result, status, log=""):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "results.json").write_text(json.dumps(result))
            (path / "xcodebuild.log").write_text(log)
            env = os.environ.copy()
            env["GITHUB_STEP_SUMMARY"] = str(path / "github-summary.md")
            process = subprocess.run(
                [sys.executable, str(REPORTER), directory, str(status), "test simulator"],
                env=env, capture_output=True, text=True,
            )
            summary = (path / "summary.md").read_text()
            self.assertEqual(summary, (path / "github-summary.md").read_text())
            return process.returncode, summary

    def test_passing_run_has_counts(self):
        code, summary = self.report(dict(result="Passed", totalTestCount=1,
                                        passedTests=1, failedTests=0, skippedTests=0), 0)
        self.assertEqual(code, 0)
        self.assertIn("| 1 | 1 | 0 | 0 |", summary)

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


if __name__ == "__main__":
    unittest.main()
