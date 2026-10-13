#!/usr/bin/env python3
"""Review a pull request's hosted CI evidence from Windows using GitHub CLI."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from datetime import datetime


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_PREFIXES = (
    "ios-test-results-",
    "testflight-preflight",
    "testflight-delivery-",
    "signing-preflight",
)
RUN_ID_RE = re.compile(r"/actions/runs/(\d+)")
ARTIFACT_NAME_RE = re.compile(
    r"(?:ios-test-results-[a-z0-9-]+|testflight-preflight|"
    r"testflight-delivery-[a-z0-9-]+|signing-preflight)\Z", re.IGNORECASE
)
TEST_COUNTS_RE = re.compile(r"\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|")


class ReviewError(RuntimeError):
    pass


def gh(args, *, cwd=ROOT, check=True):
    """Run GitHub CLI without exposing environment values or verbose errors."""
    process = subprocess.run(
        ["gh", *args], cwd=cwd, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )
    if check and process.returncode:
        message = process.stderr.strip().splitlines()
        raise ReviewError(message[-1] if message else "GitHub CLI command failed.")
    return process


def git(args, *, cwd=ROOT, check=True):
    process = subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
    )
    if check and process.returncode:
        message = process.stderr.strip().splitlines()
        raise ReviewError(message[-1] if message else "Git command failed.")
    return process


def load_json_file(path):
    try:
        with path.open(encoding="utf-8") as source:
            value = json.load(source)
    except (OSError, ValueError):
        return None
    return value if isinstance(value, (dict, list)) else None


def parse_test_summary(path):
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    runtime = None
    for line in content.splitlines():
        if "platform=iOS Simulator" in line:
            runtime = line.strip().strip("`").replace("platform=iOS Simulator,", "")
            break
    counts = None
    for line in content.splitlines():
        match = TEST_COUNTS_RE.fullmatch(line.strip())
        if match:
            values = tuple(int(value) for value in match.groups())
            if sum(values[1:]) >= 0 and values[0] == sum(values[1:]):
                counts = values
    return {"runtime": runtime, "counts": counts,
            "passed": "## iOS tests: passed" in content,
            "failed": "## iOS tests: failed" in content}


def artifact_evidence(directory, artifact_name):
    """Extract only reviewed, sanitized fields from downloaded artifacts."""
    evidence = {"name": artifact_name, "apps": [], "tests": [], "symbols": []}
    for path in directory.rglob("summary.md"):
        summary = parse_test_summary(path)
        if summary:
            evidence["tests"].append(summary)

    for path in directory.rglob("built-app.json"):
        report = load_json_file(path)
        if report:
            evidence["apps"].append({
                "bundle": report.get("CFBundleIdentifier"),
                "displayName": report.get("CFBundleDisplayName"),
                "minimumOS": report.get("MinimumOSVersion"),
                "deviceFamilies": report.get("UIDeviceFamily"),
            })

    if not evidence["apps"]:
        for path in directory.rglob("configuration.json"):
            report = load_json_file(path)
            if not isinstance(report, list):
                continue
            records = [item for item in report if isinstance(item, dict)]
            if records:
                item = records[0]
                evidence["apps"].append({
                    "bundle": item.get("bundleIdentifier"),
                    "displayName": item.get("displayName"),
                    "minimumOS": item.get("minimumIOS"),
                    "deviceFamilies": item.get("deviceFamilies"),
                })
                break

    for path in directory.rglob("symbols.json"):
        report = load_json_file(path)
        if not report:
            continue
        images = report.get("images", [])
        evidence["symbols"].append({
            "status": report.get("status"),
            "bundle": report.get("bundleIdentifier"),
            "version": report.get("marketingVersion"),
            "build": report.get("buildNumber"),
            "commit": report.get("commit"),
            "images": [
                {"uuid": image.get("uuid"), "architecture": image.get("architecture")}
                for image in images if isinstance(image, dict)
            ] if isinstance(images, list) else [],
            "ipaCompared": artifact_name.startswith("testflight-delivery-"),
        })
    return evidence


def run_id_from_url(url):
    match = RUN_ID_RE.search(url or "")
    return match.group(1) if match else None


def elapsed(started_at, completed_at):
    if not started_at or not completed_at:
        return None
    if started_at.startswith("0001-01-01") or completed_at.startswith("0001-01-01"):
        return None
    try:
        start = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
        end = datetime.fromisoformat(completed_at.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None
    seconds = max(0, int((end - start).total_seconds()))
    return f"{seconds // 60}m {seconds % 60}s"


def artifacts_for_run(repo, run_id):
    result = gh(["api", f"repos/{repo}/actions/runs/{run_id}/artifacts"])
    try:
        body = json.loads(result.stdout)
    except ValueError as error:
        raise ReviewError("GitHub returned an unreadable artifact list.") from error
    artifacts = body.get("artifacts", []) if isinstance(body, dict) else []
    return [item for item in artifacts if isinstance(item, dict)
            and isinstance(item.get("name"), str)
            and item["name"].startswith(ARTIFACT_PREFIXES)
            and ARTIFACT_NAME_RE.fullmatch(item["name"])
            and not item.get("expired", False)]


def run_artifacts(repo, run_id, run_url, stage, temp_root, download):
    records = []
    for artifact in artifacts_for_run(repo, run_id):
        name = artifact["name"]
        record = {
            "name": name,
            "runUrl": run_url,
            "stage": stage,
            "evidence": {"name": name, "apps": [], "tests": [], "symbols": []},
        }
        if download:
            destination = temp_root / f"{run_id}-{name}"
            gh(["run", "download", run_id, "--name", name, "--dir", str(destination)])
            record["evidence"] = artifact_evidence(destination, name)
        else:
            record["downloadSkipped"] = True
        records.append(record)
    return records


def render(report):
    lines = [
        f"# CI evidence for PR #{report['number']}",
        "",
        f"PR: {report['url']}",
        f"Head: `{report['headSha']}` ({report['headBranch']} -> {report['baseBranch']})",
        f"Checkout: `{report['checkoutSha']}` on `{report['checkoutBranch'] or '(detached)'}` - "
        f"**{'MATCH' if report['checkoutMatches'] else 'MISMATCH'}**",
        "",
        "## Checks",
        "",
    ]
    for check in report["checks"]:
        conclusion = check.get("conclusion") or check.get("status") or "unknown"
        label = "policy/job skip" if conclusion.lower() == "skipped" else conclusion
        run_link = f" ({check['detailsUrl']})" if check.get("detailsUrl") else ""
        duration = elapsed(check.get("startedAt"), check.get("completedAt"))
        elapsed_text = f"; {duration}" if duration else ""
        lines.append(f"- **{label}** - {check.get('workflowName') or 'check'} / "
                     f"{check.get('name', 'unnamed check')}{elapsed_text}{run_link}")
    if not report["checks"]:
        lines.append("- No checks are currently reported.")

    lines.extend(["", "## Exact merge-commit workflows", ""])
    if not report["mergeSha"]:
        lines.append("PR is not merged yet; post-merge workflow evidence is not available.")
    elif not report["mainRuns"]:
        lines.append(f"No main workflow runs found yet for merge commit `{report['mergeSha']}`.")
    else:
        lines.append(f"Merge commit: `{report['mergeSha']}`")
        for run in report["mainRuns"]:
            run_duration = elapsed(run.get("run_started_at"), run.get("updated_at"))
            duration_text = f"; {run_duration}" if run_duration else ""
            lines.append(f"- **{run.get('conclusion') or run.get('status')}** - "
                         f"{run.get('name')} ({run.get('html_url')}){duration_text}")
            for job in run.get("jobs", []):
                conclusion = job.get("conclusion") or job.get("status") or "unknown"
                label = "policy/job skip" if conclusion.lower() == "skipped" else conclusion
                job_duration = elapsed(job.get("started_at"), job.get("completed_at"))
                job_time = f"; {job_duration}" if job_duration else ""
                lines.append(f"  - {label} - {job.get('name')}{job_time}")
        if report["mainRuns"]:
            lines.append("Post-merge workflow/artifact links appear below with stage `main merge`.")

    lines.extend(["", "## Evidence artifacts", ""])
    if not report["artifacts"]:
        pending = any((check.get("status") or "").lower() in ("queued", "in_progress", "pending")
                      for check in report["checks"])
        lines.append("No matching artifacts are available yet; checks are still running."
                     if pending else "No matching, unexpired artifacts were found.")
    for artifact in report["artifacts"]:
        lines.append(f"### [{artifact['name']}]({artifact['runUrl']}) - {artifact['stage']}")
        if artifact.get("downloadSkipped"):
            lines.append("- Download skipped by `--no-download`.")
        for app in artifact["evidence"]["apps"]:
            lines.append(
                f"- App: `{app.get('displayName') or 'unknown'}` - "
                f"`{app.get('bundle') or 'unknown'}`; minimum OS "
                f"`{app.get('minimumOS') or 'unknown'}`; device families "
                f"`{app.get('deviceFamilies') or 'unknown'}`"
            )
        for test in artifact["evidence"]["tests"]:
            counts = test["counts"]
            if counts:
                total, passed, failed, skipped = counts
                lines.append(
                    f"- Tests: **{passed}/{total} passed**, {failed} failed, "
                    f"{skipped} skipped; runtime `{test['runtime'] or 'not recorded'}`; "
                    f"report {'passed' if test['passed'] else 'failed/unknown'}"
                )
            else:
                lines.append("- Test counts unavailable; inspect the linked run artifacts/logs.")
        for symbol in artifact["evidence"]["symbols"]:
            scope = "app/dSYM and exported IPA" if symbol["ipaCompared"] else "archive app/dSYM"
            lines.append(
                f"- Symbols: **{symbol.get('status', 'unknown')}** ({scope}); "
                f"`{symbol.get('bundle') or 'unknown'}` {symbol.get('version') or ''} "
                f"({symbol.get('build') or 'unknown'}); commit `{symbol.get('commit') or 'unknown'}`"
            )
            for image in symbol["images"]:
                lines.append(f"  - `{image.get('uuid', 'unknown')}` ({image.get('architecture', 'unknown')})")
        if (not artifact.get("downloadSkipped") and not artifact["evidence"]["apps"]
                and not artifact["evidence"]["tests"] and not artifact["evidence"]["symbols"]):
            lines.append("- No recognized sanitized summary was found in this artifact.")

    lines.extend([
        "",
        "Skipped checks are displayed separately and do not count as passing. "
        "A symbol match from TestFlight preflight covers the archive app/dSYM; "
        "only a delivery artifact establishes the exported-IPA comparison.",
        "",
    ])
    return "\n".join(lines)


def collect(pr_number, download=True):
    repo_result = gh(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"])
    repo = repo_result.stdout.strip()
    pr_result = gh(["pr", "view", str(pr_number), "--json",
                    "headRefOid,headRefName,baseRefName,url,statusCheckRollup,mergeCommit"])
    try:
        pr = json.loads(pr_result.stdout)
    except ValueError as error:
        raise ReviewError("GitHub returned an unreadable pull request summary.") from error

    checkout = git(["rev-parse", "HEAD"])
    branch = git(["branch", "--show-current"], check=False).stdout.strip()
    checks = pr.get("statusCheckRollup", [])
    if not isinstance(checks, list):
        checks = []
    unique_runs = {}
    for check in checks:
        if not isinstance(check, dict):
            continue
        run_id = run_id_from_url(check.get("detailsUrl"))
        if run_id:
            unique_runs[run_id] = f"https://github.com/{repo}/actions/runs/{run_id}"

    merge_sha = (pr.get("mergeCommit") or {}).get("oid")
    main_runs = []
    if merge_sha:
        result = gh(["api", f"repos/{repo}/actions/runs?head_sha={merge_sha}&per_page=100"])
        try:
            candidates = json.loads(result.stdout).get("workflow_runs", [])
        except (ValueError, AttributeError) as error:
            raise ReviewError("GitHub returned an unreadable merge-commit workflow list.") from error
        latest = {}
        for run in candidates:
            if (not isinstance(run, dict) or run.get("head_sha") != merge_sha
                    or run.get("event") != "push" or run.get("head_branch") != "main"):
                continue
            key = run.get("name", "unknown")
            if key not in latest or (run.get("run_attempt", 0), run.get("run_number", 0)) > (
                    latest[key].get("run_attempt", 0), latest[key].get("run_number", 0)):
                latest[key] = run
        for run in latest.values():
            jobs_result = gh(["api", f"repos/{repo}/actions/runs/{run['id']}/jobs?per_page=100"])
            try:
                run["jobs"] = json.loads(jobs_result.stdout).get("jobs", [])
            except (ValueError, AttributeError) as error:
                raise ReviewError("GitHub returned an unreadable workflow job list.") from error
            main_runs.append(run)

    report = {
        "number": pr_number,
        "url": pr.get("url", ""),
        "headSha": pr.get("headRefOid", ""),
        "headBranch": pr.get("headRefName", ""),
        "baseBranch": pr.get("baseRefName", ""),
        "checkoutSha": checkout.stdout.strip(),
        "checkoutBranch": branch,
        "checkoutMatches": checkout.stdout.strip().lower() == pr.get("headRefOid", "").lower(),
        "checks": checks,
        "mergeSha": merge_sha,
        "mainRuns": sorted(main_runs, key=lambda run: run.get("name", "")),
        "artifacts": [],
    }
    with tempfile.TemporaryDirectory(prefix=f"ios-ci-pr-{pr_number}-") as temp:
        temp_root = Path(temp)
        for run_id, run_url in unique_runs.items():
            report["artifacts"].extend(
                run_artifacts(repo, run_id, run_url, "PR", temp_root, download))
        for run in report["mainRuns"]:
            run_id = str(run["id"])
            report["artifacts"].extend(
                run_artifacts(repo, run_id, run.get("html_url", ""), "main merge", temp_root, download))
        return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pr", type=int, required=True, help="Pull request number to review")
    parser.add_argument("--require-checkout-head", action="store_true",
                        help="Exit nonzero when this checkout is not the PR head commit")
    parser.add_argument("--no-download", action="store_true",
                        help="Show checks and artifact links without downloading artifacts")
    args = parser.parse_args()
    if args.pr < 1:
        parser.error("--pr must be a positive integer")
    try:
        report = collect(args.pr, download=not args.no_download)
    except ReviewError as error:
        parser.exit(2, f"CI evidence review failed: {error}\n")
    print(render(report))
    if args.require_checkout_head and not report["checkoutMatches"]:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
