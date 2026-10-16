"""Render xcresulttool output for humans and agents without requiring Xcode to read it.

Reads, when present in the report directory:
- results.json      `xcresulttool get test-results summary`
- tests.json        `xcresulttool get test-results tests` (per-test results and failure messages)
- attachments/manifest.json  `xcresulttool export attachments` (test-produced screenshots)
- xcodebuild.log    full build/test log, mined for compiler and setup errors
Writes summary.md and failures.json next to them.
"""

import json
import os
from pathlib import Path
import re
import sys

FAILURE_MESSAGE_RE = re.compile(r"^(?P<file>[^:\s]+\.(?:swift|m|mm|h|c|cpp)):(?P<line>\d+):\s*(?P<message>.*)$", re.S)
BUILD_ERROR_RE = re.compile(r"^(?P<file>/\S+?\.(?:swift|m|mm|h|c|cpp|plist|yml|yaml|json)):(?P<line>\d+)(?::(?P<column>\d+))?: error: (?P<message>.*)$")
GENERIC_ERROR_RE = re.compile(r"^(?:xcodebuild: )?error: (?P<message>.*)$")
# xcodebuild echoes XCTest assertion failures as "file:line: error: -[Suite test] : message"; those are
# test failures (reported from tests.json/results.json), not build errors.
XCTEST_ASSERTION_RE = re.compile(r"^-\[[^\]]+\] : ")
IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".heic")


def fenced(text):
    return "```text\n" + text.replace("```", "'''") + "\n```\n"


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def summary_counts(data):
    if not isinstance(data, dict):
        return None
    for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests"):
        if type(data.get(key)) is not int or data[key] < 0:
            return None
    return data


def test_failures(tests):
    """Flatten `get test-results tests` into failed test cases with file/line/message."""
    failures = []
    if not isinstance(tests, dict):
        return failures

    def walk(node, suite, target):
        if not isinstance(node, dict):
            return
        kind, name = node.get("nodeType", ""), node.get("name", "")
        if kind in ("Unit test bundle", "UI test bundle"):
            target = name
        elif kind == "Test Suite":
            suite = name
        elif kind == "Test Case" and node.get("result") == "Failed":
            messages = [child.get("name", "") for child in node.get("children", [])
                        if isinstance(child, dict) and child.get("nodeType") == "Failure Message"]
            for text in messages or ["(no failure message recorded)"]:
                match = FAILURE_MESSAGE_RE.match(text.strip())
                failures.append({
                    "test": node.get("nodeIdentifier") or name, "testName": name, "suite": suite, "target": target,
                    "file": match.group("file") if match else None,
                    "line": int(match.group("line")) if match else None,
                    "message": (match.group("message") if match else text).strip(),
                })
            return
        for child in node.get("children", []) or []:
            walk(child, suite, target)

    for node in tests.get("testNodes", []) or []:
        walk(node, None, None)
    return failures


def build_errors(log):
    errors, seen = [], set()
    for raw in log.splitlines():
        line = raw.strip()
        if "[MT]" in line or not line:
            continue
        match = BUILD_ERROR_RE.match(line)
        if match:
            if XCTEST_ASSERTION_RE.match(match.group("message")):
                continue
            key = (match.group("file"), match.group("line"), match.group("message"))
            if key not in seen:
                seen.add(key)
                errors.append({"file": match.group("file"), "line": int(match.group("line")),
                               "column": int(match.group("column")) if match.group("column") else None,
                               "message": match.group("message").strip()})
            continue
        match = GENERIC_ERROR_RE.match(line)
        if match and ("error:", match.group("message")) not in seen:
            seen.add(("error:", match.group("message")))
            errors.append({"file": None, "line": None, "column": None, "message": match.group("message").strip()})
    return errors


def attachments(manifest, directory):
    items = []
    if not isinstance(manifest, list):
        return items
    for entry in manifest:
        if not isinstance(entry, dict):
            continue
        for attachment in entry.get("attachments", []) or []:
            if not isinstance(attachment, dict):
                continue
            exported = attachment.get("exportedFileName") or ""
            path = directory / exported
            items.append({
                "test": entry.get("testIdentifier"), "name": attachment.get("suggestedHumanReadableName") or exported,
                "file": exported, "isImage": exported.lower().endswith(IMAGE_SUFFIXES),
                "forFailure": attachment.get("isAssociatedWithFailure") is True,
                "bytes": path.stat().st_size if path.is_file() else None,
            })
    return items


def classify(status, result, failures, errors):
    if result is not None:
        if status == 0 and result["failedTests"] == 0 and result["passedTests"] > 0 and result.get("result") == "Passed":
            return "passed"
        if result["failedTests"] > 0 or failures:
            return "tests_failed"
        return "unverified"
    if any(error["file"] for error in errors):
        return "build_failed"
    return "setup_failed" if status != 0 else "unverified"


def main():
    report_dir = Path(sys.argv[1])
    status = int(sys.argv[2])
    destination = sys.argv[3]
    result = summary_counts(load_json(report_dir / "results.json"))
    failures = test_failures(load_json(report_dir / "tests.json"))
    if not failures and result is not None:
        raw = result.get("testFailures", [])
        for failure in ([raw] if isinstance(raw, dict) else raw) if isinstance(raw, (list, dict)) else []:
            if isinstance(failure, dict):
                failures.append({"test": failure.get("testIdentifierString") or failure.get("testName", "Unknown test"),
                                 "testName": failure.get("testName", "Unknown test"), "suite": None,
                                 "target": failure.get("targetName"), "file": None, "line": None,
                                 "message": str(failure.get("failureText", "No failure detail"))})
    try:
        log = (report_dir / "xcodebuild.log").read_text(errors="replace")
    except OSError:
        log = ""
    log = re.sub(r"\x1b\[[0-9;]*m", "", log)
    errors = build_errors(log)
    media = attachments(load_json(report_dir / "attachments" / "manifest.json"), report_dir / "attachments")
    stage = classify(status, result, failures, errors)
    verified = stage == "passed"

    lines = ["## iOS tests: " + ("passed" if verified else "failed"), "", "Destination:", fenced(destination),
             f"Build/test command exit status: {status}", f"Stage: `{stage}`", ""]
    if result is not None:
        lines.extend(["| Total | Passed | Failed | Skipped |", "|---|---|---|---|",
                      f"| {result['totalTestCount']} | {result['passedTests']} | {result['failedTests']} | {result['skippedTests']} |", ""])
    else:
        lines.extend(["No readable test counts were produced. Inspect `xcodebuild.log` and "
                      "`xcresulttool.log`; the build or simulator may have failed before tests ran.", ""])
    for failure in failures:
        location = f"{failure['file']}:{failure['line']}" if failure["file"] else "location not recorded"
        lines.extend(["### Test failure", "", f"- Test: `{failure['test']}`" + (f" in `{failure['target']}`" if failure.get("target") else ""),
                      f"- Location: `{location}`", "", fenced(failure["message"])])
    if errors and stage != "passed":
        lines.extend(["### Build errors", ""])
        for error in errors[:20]:
            where = f"`{error['file']}:{error['line']}`" if error["file"] else "(no file)"
            lines.append(f"- {where}: {error['message']}")
        lines.append("")
    images = [item for item in media if item["isImage"]]
    if images:
        lines.extend(["### Screenshots", ""])
        for item in images:
            lines.append(f"- `attachments/{item['file']}` — {item['name']}" + (" (failure)" if item["forFailure"] else "") +
                         (f" for `{item['test']}`" if item.get("test") else ""))
        lines.append("")
    other = [item for item in media if not item["isImage"]]
    if other:
        lines.append("Other attachments (not uploaded): " + ", ".join(f"{item['name']}" for item in other) + ".")
        lines.append("")

    if not verified:
        if status == 0:
            lines.extend(["The command succeeded, but a passing test run could not be verified.", ""])
        if not failures:
            diagnostics = [line for line in log.splitlines()
                           if any(marker in line.lower() for marker in ("error:", "failed", "unable to", "assert"))]
            excerpt = diagnostics[-30:] or log.splitlines()[-40:]
            lines.extend(["### Build/test diagnostics", "", fenced("\n".join(excerpt))])

    artifact_name = os.environ.get('IOS_TEST_ARTIFACT_NAME', 'ios-test-results')
    run_url = "".join((os.environ.get("GITHUB_SERVER_URL", ""), "/", os.environ.get("GITHUB_REPOSITORY", ""),
                       "/actions/runs/", os.environ.get("GITHUB_RUN_ID", "")))
    artifact_link = f"[{artifact_name}]({run_url})" if all((os.environ.get("GITHUB_SERVER_URL"),
                                                            os.environ.get("GITHUB_REPOSITORY"),
                                                            os.environ.get("GITHUB_RUN_ID"))) else f"**{artifact_name}**"
    lines.extend([f"Download {artifact_link} on the Actions run page for `summary.md`, `failures.json`, `results.json`, "
                  "screenshots under `attachments/`, the complete logs, and `Tests.xcresult` when available.",
                  "Locally, these files are in the report directory printed by `test-ios.sh`.", ""])
    summary = "\n".join(lines)
    (report_dir / "summary.md").write_text(summary)
    (report_dir / "failures.json").write_text(json.dumps({
        "stage": stage, "exitStatus": status, "destination": destination,
        "counts": {key: result[key] for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")} if result else None,
        "failures": failures, "buildErrors": errors, "attachments": media,
    }, indent=2) + "\n")
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
            output.write(summary)
    return 0 if verified else 1


if __name__ == "__main__":
    sys.exit(main())
