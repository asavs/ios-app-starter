"""Render xcresulttool summary JSON for humans without requiring Xcode to read it."""

import json
import os
from pathlib import Path
import re
import sys


def fenced(text):
    return "```text\n" + text.replace("```", "'''") + "\n```\n"


def main():
    report_dir = Path(sys.argv[1])
    status = int(sys.argv[2])
    destination = sys.argv[3]
    result = None
    try:
        data = json.loads((report_dir / "results.json").read_text())
        if not isinstance(data, dict):
            raise ValueError("Expected an object")
        for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests"):
            if type(data.get(key)) is not int or data[key] < 0:
                raise ValueError("Missing test counts")
        result = data
    except (OSError, ValueError):
        pass

    verified = (
        status == 0
        and result is not None
        and result["totalTestCount"] > 0
        and result["passedTests"] > 0
        and result["failedTests"] == 0
        and result.get("result") == "Passed"
    )
    lines = [
        "## iOS tests: " + ("passed" if verified else "failed"),
        "",
        "Destination:",
        fenced(destination),
        f"Build/test command exit status: {status}",
        "",
    ]
    if result is not None:
        lines.extend([
            "| Total | Passed | Failed | Skipped |",
            "|---|---|---|---|",
            f"| {result['totalTestCount']} | {result['passedTests']} | "
            f"{result['failedTests']} | {result['skippedTests']} |",
            "",
        ])
        failures = result.get("testFailures", [])
        if isinstance(failures, dict):
            failures = [failures]
        for failure in failures:
            if isinstance(failure, dict):
                lines.extend([
                    "### Test failure",
                    "",
                    fenced(f"{failure.get('testName', 'Unknown test')}\n"
                           f"{failure.get('failureText', 'No failure detail')}"),
                ])
    else:
        lines.extend([
            "No readable test counts were produced. Inspect `xcodebuild.log` and "
            "`xcresulttool.log`; the build or simulator may have failed before tests ran.",
            "",
        ])

    if not verified:
        if status == 0:
            lines.extend(["The command succeeded, but a passing test run could not be verified.", ""])
        log = (report_dir / "xcodebuild.log").read_text(errors="replace")
        log = re.sub(r"\x1b\[[0-9;]*m", "", log)
        diagnostics = [line for line in log.splitlines()
                       if any(marker in line.lower() for marker in
                              ("error:", "failed", "unable to", "assert"))]
        excerpt = diagnostics[-30:] or log.splitlines()[-40:]
        lines.extend(["### Build/test diagnostics", "", fenced("\n".join(excerpt))])

    lines.extend([
        "Download the **ios-test-results** artifact on the Actions run page for "
        "`summary.md`, `results.json`, the complete logs, and `Tests.xcresult` when available.",
        "Locally, these files are in the report directory printed by `test-ios.sh`.",
        "",
    ])
    summary = "\n".join(lines)
    (report_dir / "summary.md").write_text(summary)
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
            output.write(summary)
    return 0 if verified else 1


if __name__ == "__main__":
    sys.exit(main())
