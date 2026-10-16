#!/usr/bin/env python3
"""Review hosted CI evidence from Windows using GitHub CLI.

Modes: ``--pr <number>`` reviews a pull request's checks, merge-commit workflows and
artifacts; ``--run <id>`` reviews one workflow run's jobs and artifacts; ``--latest``
picks the most recent run for a branch (default: the current checkout branch),
optionally filtered by workflow name, and reviews it like ``--run``.
"""

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
    "ios-compat-",
    "testflight-preflight",
    "testflight-delivery-",
    "signing-preflight",
    "compatibility-report",
)
RUN_ID_RE = re.compile(r"/actions/runs/(\d+)")
RUN_ID_ARG_RE = re.compile(r"\d{1,20}\Z")
ARTIFACT_NAME_RE = re.compile(
    r"(?:ios-test-results-[a-z0-9-]+|ios-compat-[a-z0-9-]+|testflight-preflight|"
    r"testflight-delivery-[a-z0-9-]+|signing-preflight|compatibility-report)\Z", re.IGNORECASE
)
TEST_COUNTS_RE = re.compile(r"\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|")
LANE_FIELDS = ("lane", "runtime_name", "runtime_version", "device", "xcode_version",
               "sdk", "runner", "status", "total", "passed", "failed", "skipped")
LATEST_RUN_LIMIT = 20
PENDING_STATUSES = ("queued", "in_progress", "pending", "waiting", "requested")
RUN_LIST_FIELDS = "databaseId,workflowName,event,headSha,status,conclusion,createdAt,url,attempt,number"


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


def gh_json(args, description):
    """Run a GitHub CLI command and parse its JSON output."""
    result = gh(args)
    try:
        return json.loads(result.stdout)
    except ValueError as error:
        raise ReviewError(f"GitHub returned an unreadable {description}.") from error


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


def lane_fields(record):
    """Keep only the reviewed, non-sensitive fields of a compatibility lane record."""
    return {key: record.get(key) for key in LANE_FIELDS}


def compatibility_fields(report):
    lanes = report.get("lanes", [])
    runtimes = report.get("verifiedRuntimes", [])
    return {
        "verifiedRuntimes": [str(item) for item in runtimes] if isinstance(runtimes, list) else [],
        "allPassed": bool(report.get("allPassed")),
        "lanes": [lane_fields(lane) for lane in lanes if isinstance(lane, dict)]
        if isinstance(lanes, list) else [],
    }


def parse_compatibility_markdown(path):
    """Fallback when only compatibility-report.md is present: read the verified-runtimes line."""
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    for line in content.splitlines():
        if line.startswith("Verified runtimes:"):
            value = line.partition(":")[2].strip()
            runtimes = [] if value == "none" else [item.strip() for item in value.split(",") if item.strip()]
            return {"verifiedRuntimes": runtimes, "allPassed": "All planned lanes passed." in content,
                    "lanes": []}
    return None


def empty_evidence(artifact_name):
    return {"name": artifact_name, "apps": [], "tests": [], "symbols": [], "lanes": [],
            "compatibility": None}


def has_evidence(evidence):
    return bool(evidence["apps"] or evidence["tests"] or evidence["symbols"]
                or evidence["lanes"] or evidence["compatibility"])


def artifact_evidence(directory, artifact_name):
    """Extract only reviewed, sanitized fields from downloaded artifacts."""
    evidence = empty_evidence(artifact_name)
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

    for path in directory.rglob("lane-result.json"):
        record = load_json_file(path)
        if isinstance(record, dict):
            evidence["lanes"].append(lane_fields(record))

    for path in directory.rglob("compatibility-report.json"):
        report = load_json_file(path)
        if isinstance(report, dict):
            evidence["compatibility"] = compatibility_fields(report)
            break
    if evidence["compatibility"] is None:
        for path in directory.rglob("compatibility-report.md"):
            evidence["compatibility"] = parse_compatibility_markdown(path)
            if evidence["compatibility"]:
                break
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


def conclusion_label(record):
    """Label skipped checks/jobs as policy skips so they never read as passes."""
    conclusion = record.get("conclusion") or record.get("status") or "unknown"
    return "policy/job skip" if str(conclusion).lower() == "skipped" else str(conclusion)


def job_lines(jobs, indent=""):
    lines = []
    for job in jobs:
        if not isinstance(job, dict):
            continue
        duration = elapsed(job.get("started_at"), job.get("completed_at"))
        job_time = f"; {duration}" if duration else ""
        lines.append(f"{indent}- {conclusion_label(job)} - {job.get('name')}{job_time}")
    return lines


def artifacts_for_run(repo, run_id):
    body = gh_json(["api", f"repos/{repo}/actions/runs/{run_id}/artifacts"], "artifact list")
    artifacts = body.get("artifacts", []) if isinstance(body, dict) else []
    return [item for item in artifacts if isinstance(item, dict)
            and isinstance(item.get("name"), str)
            and item["name"].startswith(ARTIFACT_PREFIXES)
            and ARTIFACT_NAME_RE.fullmatch(item["name"])
            and not item.get("expired", False)]


def run_artifacts(repo, run_id, run_url, stage, temp_root, download):
    records = []
    for artifact in sorted(artifacts_for_run(repo, run_id), key=lambda item: item["name"]):
        name = artifact["name"]
        record = {
            "name": name,
            "runUrl": run_url,
            "stage": stage,
            "evidence": empty_evidence(name),
        }
        if download:
            destination = temp_root / f"{run_id}-{name}"
            gh(["run", "download", run_id, "--name", name, "--dir", str(destination)])
            record["evidence"] = artifact_evidence(destination, name)
        else:
            record["downloadSkipped"] = True
        records.append(record)
    return records


def fetch_run_jobs(repo, run_id):
    body = gh_json(["api", f"repos/{repo}/actions/runs/{run_id}/jobs?per_page=100"],
                   "workflow job list")
    jobs = body.get("jobs", []) if isinstance(body, dict) else []
    return [job for job in jobs if isinstance(job, dict)]


def fetch_run(repo, run_id):
    run = gh_json(["api", f"repos/{repo}/actions/runs/{run_id}"], "workflow run")
    if not isinstance(run, dict) or "id" not in run:
        raise ReviewError(f"Workflow run {run_id} was not found in {repo}.")
    run["jobs"] = fetch_run_jobs(repo, run_id)
    return run


def repo_name():
    return gh(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).stdout.strip()


def checkout_state():
    checkout = git(["rev-parse", "HEAD"]).stdout.strip()
    branch = git(["branch", "--show-current"], check=False).stdout.strip()
    return checkout, branch


def lane_text(lane):
    counts = [lane.get(key) for key in ("total", "passed", "failed", "skipped")]
    if all(isinstance(value, int) for value in counts):
        total, passed, failed, skipped = counts
        count_text = f"; tests {passed}/{total} passed, {failed} failed, {skipped} skipped"
    else:
        count_text = "; test counts unavailable"
    return (f"**{lane.get('status') or 'unknown'}** - {lane.get('lane') or 'lane'}: "
            f"{lane.get('runtime_name') or 'unknown runtime'} ({lane.get('runtime_version') or '?'}) "
            f"on `{lane.get('device') or 'unknown device'}`; Xcode {lane.get('xcode_version') or '?'} / "
            f"SDK {lane.get('sdk') or '?'}; runner `{lane.get('runner') or '?'}`{count_text}")


def artifact_lines(artifacts, pending):
    lines = ["## Evidence artifacts", ""]
    if not artifacts:
        lines.append("No matching artifacts are available yet; the run is still in progress."
                     if pending else "No matching, unexpired artifacts were found.")
    for artifact in artifacts:
        lines.append(f"### [{artifact['name']}]({artifact['runUrl']}) - {artifact['stage']}")
        if artifact.get("downloadSkipped"):
            lines.append("- Download skipped by `--no-download`.")
        evidence = artifact["evidence"]
        for app in evidence["apps"]:
            lines.append(
                f"- App: `{app.get('displayName') or 'unknown'}` - "
                f"`{app.get('bundle') or 'unknown'}`; minimum OS "
                f"`{app.get('minimumOS') or 'unknown'}`; device families "
                f"`{app.get('deviceFamilies') or 'unknown'}`"
            )
        for test in evidence["tests"]:
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
        for symbol in evidence["symbols"]:
            scope = "app/dSYM and exported IPA" if symbol["ipaCompared"] else "archive app/dSYM"
            lines.append(
                f"- Symbols: **{symbol.get('status', 'unknown')}** ({scope}); "
                f"`{symbol.get('bundle') or 'unknown'}` {symbol.get('version') or ''} "
                f"({symbol.get('build') or 'unknown'}); commit `{symbol.get('commit') or 'unknown'}`"
            )
            for image in symbol["images"]:
                lines.append(f"  - `{image.get('uuid', 'unknown')}` ({image.get('architecture', 'unknown')})")
        for lane in evidence["lanes"]:
            lines.append(f"- Lane: {lane_text(lane)}")
        compatibility = evidence.get("compatibility")
        if compatibility:
            runtimes = ", ".join(compatibility["verifiedRuntimes"]) or "none"
            outcome = ("all planned lanes passed" if compatibility["allPassed"]
                       else "some planned lanes did not pass; only verified runtimes count")
            lines.append(f"- Compatibility: verified runtimes **{runtimes}**; {outcome}")
            for lane in compatibility["lanes"]:
                lines.append(f"  - {lane_text(lane)}")
        if not artifact.get("downloadSkipped") and not has_evidence(evidence):
            lines.append("- No recognized sanitized summary was found in this artifact.")
    return lines


FOOTER = (
    "Skipped checks are displayed separately and do not count as passing. "
    "A symbol match from TestFlight preflight covers the archive app/dSYM; "
    "only a delivery artifact establishes the exported-IPA comparison. "
    "Compatibility lanes verify simulator runtimes only; an unverified or missing lane establishes nothing."
)


def render_pr(report):
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
        run_link = f" ({check['detailsUrl']})" if check.get("detailsUrl") else ""
        duration = elapsed(check.get("startedAt"), check.get("completedAt"))
        elapsed_text = f"; {duration}" if duration else ""
        lines.append(f"- **{conclusion_label(check)}** - {check.get('workflowName') or 'check'} / "
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
            lines.extend(job_lines(run.get("jobs", []), indent="  "))
        lines.append("Post-merge workflow/artifact links appear below with stage `main merge`.")

    pending = any((check.get("status") or "").lower() in PENDING_STATUSES
                  for check in report["checks"])
    lines.append("")
    lines.extend(artifact_lines(report["artifacts"], pending))
    lines.extend(["", FOOTER, ""])
    return "\n".join(lines)


def render_run(report):
    run = report["run"]
    status = str(run.get("status") or "unknown")
    duration = elapsed(run.get("run_started_at"), run.get("updated_at"))
    lines = [f"# CI evidence for run {report['runId']}", ""]
    if report.get("selection"):
        lines.extend([report["selection"], ""])
    lines.extend([
        f"Run: {run.get('html_url') or 'unknown'}",
        f"Workflow: {run.get('name') or 'unknown'}; event `{run.get('event') or 'unknown'}`; "
        f"branch `{run.get('head_branch') or 'unknown'}`; attempt {run.get('run_attempt') or '?'}",
        f"Head: `{run.get('head_sha') or 'unknown'}`",
        f"Status: {status} / **{run.get('conclusion') or 'no conclusion yet'}**"
        + (f"; {duration}" if duration and status == "completed" else ""),
        f"Checkout: `{report['checkoutSha']}` on `{report['checkoutBranch'] or '(detached)'}` - "
        f"**{'MATCH' if report['checkoutMatches'] else 'MISMATCH'}**",
        "",
        "## Jobs",
        "",
    ])
    lines.extend(job_lines(run.get("jobs", [])) or ["- No jobs are reported yet."])
    lines.append("")
    lines.extend(artifact_lines(report["artifacts"], status.lower() in PENDING_STATUSES))
    lines.extend(["", FOOTER, ""])
    return "\n".join(lines)


def render(report):
    return render_run(report) if report.get("mode") == "run" else render_pr(report)


def collect(pr_number, download=True):
    repo = repo_name()
    pr = gh_json(["pr", "view", str(pr_number), "--json",
                  "headRefOid,headRefName,baseRefName,url,statusCheckRollup,mergeCommit"],
                 "pull request summary")
    if not isinstance(pr, dict):
        raise ReviewError("GitHub returned an unreadable pull request summary.")

    checkout, branch = checkout_state()
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
        body = gh_json(["api", f"repos/{repo}/actions/runs?head_sha={merge_sha}&per_page=100"],
                       "merge-commit workflow list")
        candidates = body.get("workflow_runs", []) if isinstance(body, dict) else []
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
            run["jobs"] = fetch_run_jobs(repo, run["id"])
            main_runs.append(run)

    report = {
        "mode": "pr",
        "number": pr_number,
        "url": pr.get("url", ""),
        "headSha": pr.get("headRefOid", ""),
        "headBranch": pr.get("headRefName", ""),
        "baseBranch": pr.get("baseRefName", ""),
        "checkoutSha": checkout,
        "checkoutBranch": branch,
        "checkoutMatches": checkout.lower() == pr.get("headRefOid", "").lower(),
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


def collect_run(run_id, download=True, selection=None):
    """Review one workflow run: metadata, jobs, and recognized artifacts."""
    run_id = str(run_id)
    repo = repo_name()
    run = fetch_run(repo, run_id)
    checkout, branch = checkout_state()
    head_sha = str(run.get("head_sha") or "")
    report = {
        "mode": "run",
        "runId": run_id,
        "run": run,
        "selection": selection,
        "checkoutSha": checkout,
        "checkoutBranch": branch,
        "checkoutMatches": bool(head_sha) and checkout.lower() == head_sha.lower(),
        "artifacts": [],
    }
    with tempfile.TemporaryDirectory(prefix=f"ios-ci-run-{run_id}-") as temp:
        report["artifacts"] = run_artifacts(
            repo, run_id, run.get("html_url", ""), "run", Path(temp), download)
        return report


def current_branch():
    branch = git(["rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
    if not branch or branch == "HEAD":
        raise ReviewError("This checkout is detached; pass --branch <name> to choose a branch.")
    return branch


def select_latest_run(branch, workflow=None, limit=LATEST_RUN_LIMIT):
    """Choose the most recently created run for a branch, optionally one workflow only."""
    args = ["run", "list", "--branch", branch, "--limit", str(limit), "--json", RUN_LIST_FIELDS]
    if workflow:
        args.extend(["--workflow", workflow])
    runs = gh_json(args, "workflow run list")
    runs = [run for run in runs if isinstance(run, dict) and isinstance(run.get("databaseId"), int)] \
        if isinstance(runs, list) else []
    scope = f"branch `{branch}`" + (f", workflow `{workflow}`" if workflow else "")
    if not runs:
        raise ReviewError(f"No workflow runs were found for {scope}.")
    chosen = max(runs, key=lambda run: (str(run.get("createdAt") or ""), run["databaseId"]))
    state = chosen.get("conclusion") or chosen.get("status") or "unknown"
    reason = (f"Selected run {chosen['databaseId']} ({chosen.get('workflowName') or 'unknown workflow'}, "
              f"`{chosen.get('event') or 'unknown'}`, {state}, created {chosen.get('createdAt') or 'unknown'}): "
              f"newest of {len(runs)} run(s) listed for {scope} (limit {limit}).")
    return str(chosen["databaseId"]), reason


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--pr", type=int, help="Pull request number to review")
    target.add_argument("--run", metavar="RUN_ID", help="Workflow run ID to review")
    target.add_argument("--latest", action="store_true",
                        help="Review the most recent run for a branch (default: current checkout branch)")
    parser.add_argument("--branch", help="With --latest: branch whose runs are listed")
    parser.add_argument("--workflow", help="With --latest: only runs of this workflow name")
    parser.add_argument("--require-checkout-head", action="store_true",
                        help="Exit nonzero when this checkout is not the reviewed head commit")
    parser.add_argument("--no-download", action="store_true",
                        help="Show checks and artifact links without downloading artifacts")
    args = parser.parse_args()
    if args.pr is not None and args.pr < 1:
        parser.error("--pr must be a positive integer")
    if args.run is not None and not RUN_ID_ARG_RE.fullmatch(args.run):
        parser.error("--run must be a numeric workflow run ID")
    if (args.branch or args.workflow) and not args.latest:
        parser.error("--branch and --workflow apply only with --latest")
    download = not args.no_download
    try:
        if args.pr is not None:
            report = collect(args.pr, download=download)
        elif args.run is not None:
            report = collect_run(args.run, download=download)
        else:
            branch = args.branch or current_branch()
            run_id, reason = select_latest_run(branch, args.workflow)
            report = collect_run(run_id, download=download, selection=reason)
    except ReviewError as error:
        parser.exit(2, f"CI evidence review failed: {error}\n")
    print(render(report))
    if args.require_checkout_head and not report["checkoutMatches"]:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
