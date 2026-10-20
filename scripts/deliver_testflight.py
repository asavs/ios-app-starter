#!/usr/bin/env python3
"""Deliver the current ``main`` branch to internal TestFlight in one approved command.

The command proposes the build (configuration, ``main`` head, the newest ``main`` iOS run
for that head, deliveries already in flight), dispatches **TestFlight delivery** with
``perform_upload``, finds the run it started, waits for the ``apple-credentials`` approval
gate (approving it with ``--approve`` or printing the exact command), waits for the run
to finish and then reports every stage from the sanitized delivery artifact, naming the
exact failing step when something goes wrong. ``--run <id>`` resumes an existing run
instead of dispatching a new one; ``--dry-run`` stops after the proposal; ``--no-wait``
dispatches and prints the run details without waiting for approval or completion.

Only GitHub CLI is used; no Apple credential is read or printed. Blocking in this command
is a shell wait, not a model loop.
"""

import argparse
import json
from pathlib import Path
import re
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review_ci  # noqa: E402

ROOT = review_ci.ROOT
ReviewError = review_ci.ReviewError
gh = review_ci.gh
gh_json = review_ci.gh_json
repo_name = review_ci.repo_name
elapsed = review_ci.elapsed

WORKFLOW_FILE = "testflight-delivery.yml"
WORKFLOW_NAME = "TestFlight delivery"
SMOKE_WORKFLOW = "iOS"
ENVIRONMENT = "apple-credentials"
BRANCH = "main"
CONFIGURATIONS = ("starter", "pocket-notes", "starter-app-demo")
STAGES = ("release-plan", "delivery-validation", "upload-report", "processing-report")
PENDING = set(review_ci.PENDING_STATUSES)
RUN_LIST_FIELDS = "databaseId,createdAt,status,conclusion,event,headSha,url,displayTitle"
RUN_ID_RE = re.compile(r"\d{1,20}\Z")
DISPATCH_WINDOW = timedelta(minutes=5)
FIND_ATTEMPTS = 12
FIND_INTERVAL = 5
REPO = [None]  # owner/name, resolved once per command through gh


class DeliveryTimeout(RuntimeError):
    pass


def parse_time(value):
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


def list_runs(workflow, limit=20, event=None):
    args = ["run", "list", "--repo", REPO[0], "--branch", BRANCH, "--workflow", workflow,
            "--limit", str(limit), "--json", RUN_LIST_FIELDS]
    if event:
        args.extend(["--event", event])
    runs = gh_json(args, "workflow run list")
    return [run for run in runs if isinstance(run, dict) and isinstance(run.get("databaseId"), int)] \
        if isinstance(runs, list) else []


def propose(configuration):
    """Describe what a dispatch would deliver, without changing anything."""
    repo = REPO[0]
    branch = gh_json(["api", f"repos/{repo}/branches/{BRANCH}"], "branch summary")
    head = str((branch.get("commit") or {}).get("sha") or "") if isinstance(branch, dict) else ""
    if not head:
        raise ReviewError(f"The {BRANCH} branch head could not be read.")
    smoke = [run for run in list_runs(SMOKE_WORKFLOW, event="push")
             if str(run.get("headSha") or "").lower() == head.lower()]
    smoke_state = "no push run found for this head"
    if smoke:
        newest = max(smoke, key=lambda run: (str(run.get("createdAt") or ""), run["databaseId"]))
        smoke_state = f"run {newest['databaseId']}: {newest.get('conclusion') or newest.get('status') or 'unknown'}"
    in_flight = [run for run in list_runs(WORKFLOW_FILE, limit=10)
                 if run.get("event") == "workflow_dispatch"
                 and run.get("displayTitle") == "TestFlight delivery upload"
                 and str(run.get("status") or "").lower() in PENDING]
    return {"repo": repo, "configuration": configuration, "head": head,
            "smoke": smoke_state, "inFlight": [run["databaseId"] for run in in_flight],
            "command": dispatch_command(configuration)}


def dispatch_command(configuration):
    return (f"gh workflow run {WORKFLOW_FILE} --ref {BRANCH} --field configuration={configuration} "
            "--field perform_upload=true")


def dispatch(configuration):
    gh(["workflow", "run", WORKFLOW_FILE, "--repo", REPO[0], "--ref", BRANCH,
        "--field", f"configuration={configuration}", "--field", "perform_upload=true"])


def find_dispatched_run(known_ids, since, attempts=FIND_ATTEMPTS, interval=FIND_INTERVAL, sleep=time.sleep):
    """Locate the manual run created by our dispatch; GitHub does not return its ID directly."""
    for attempt in range(attempts):
        candidates = []
        for run in list_runs(WORKFLOW_FILE, limit=5, event="workflow_dispatch"):
            created = parse_time(run.get("createdAt"))
            if run["databaseId"] in known_ids or created is None:
                continue
            if created >= since - DISPATCH_WINDOW:
                candidates.append(run)
        if candidates:
            return max(candidates, key=lambda run: (str(run.get("createdAt") or ""), run["databaseId"]))
        if attempt + 1 < attempts:
            sleep(interval)
    raise ReviewError("The dispatched run did not appear in the run list; check the Actions page before dispatching again.")


def fetch_run(run_id):
    return review_ci.fetch_run(REPO[0], str(run_id))


def wait_until(run_id, done, deadline, interval, clock=time.monotonic, sleep=time.sleep, progress=None):
    """Poll one run until ``done(run)`` holds or the deadline passes; return the run."""
    while True:
        run = fetch_run(run_id)
        if done(run):
            return run
        if clock() >= deadline:
            raise DeliveryTimeout(str(run.get("status") or "unknown"))
        if progress:
            progress(run)
        sleep(interval)


def pending_environment(run_id):
    """Return the pending apple-credentials deployment (environment id, approvable), or None."""
    body = gh_json(["api", f"repos/{REPO[0]}/actions/runs/{run_id}/pending_deployments"], "pending deployment list")
    if not isinstance(body, list):
        return None
    for item in body:
        if not isinstance(item, dict):
            continue
        environment = item.get("environment") or {}
        if environment.get("name") == ENVIRONMENT and isinstance(environment.get("id"), int):
            return environment["id"], bool(item.get("current_user_can_approve"))
    return None


def approval_command(run_id, environment_id):
    return (f"gh api -X POST repos/{REPO[0]}/actions/runs/{run_id}/pending_deployments "
            f"-F \"environment_ids[]={environment_id}\" -f state=approved -f comment=\"approved delivery\"")


def approve(run_id, environment_id, configuration):
    gh(["api", "-X", "POST", f"repos/{REPO[0]}/actions/runs/{run_id}/pending_deployments",
        "-F", f"environment_ids[]={environment_id}", "-f", "state=approved",
        "-f", f"comment=deliver_testflight: {configuration}"])


def is_waiting(run):
    return str(run.get("status") or "").lower() == "waiting"


def is_finished(run):
    return str(run.get("status") or "").lower() == "completed"


def waiting_or_finished(run):
    return is_waiting(run) or is_finished(run)


def failing_step(jobs):
    """Name the first failed job and its first failed step, or None."""
    for job in jobs:
        if not isinstance(job, dict) or str(job.get("conclusion") or "").lower() not in ("failure", "timed_out", "cancelled"):
            continue
        for step in job.get("steps") or []:
            if isinstance(step, dict) and str(step.get("conclusion") or "").lower() in ("failure", "timed_out", "cancelled"):
                return f"{job.get('name')} / {step.get('name')} ({step.get('conclusion')})"
        return f"{job.get('name')} ({job.get('conclusion')})"
    return None


def read_stages(directory):
    """Read only the fixed status fields of the sanitized delivery reports."""
    stages = {}
    for name in STAGES:
        matches = list(Path(directory).rglob(name + ".json"))
        report = review_ci.load_json_file(matches[0]) if matches else None
        stages[name] = str(report.get("status")) if isinstance(report, dict) and report.get("status") else "not_completed"
        if name == "release-plan" and isinstance(report, dict):
            stages["build"] = {key: report.get(key) for key in ("bundleIdentifier", "marketingVersion", "buildNumber")}
    return stages


def download_stages(run_id, configuration):
    name = f"testflight-delivery-{configuration}"
    available = any(item["name"] == name for item in review_ci.artifacts_for_run(REPO[0], str(run_id)))
    with tempfile.TemporaryDirectory(prefix=f"testflight-delivery-{run_id}-") as temp:
        if available:
            gh(["run", "download", str(run_id), "--repo", REPO[0], "--name", name, "--dir", temp])
        return read_stages(temp)


def verdict(run, stages):
    """Return (exit code, headline) from the run conclusion and stage statuses."""
    conclusion = str(run.get("conclusion") or "").lower()
    build = stages.get("build") or {}
    label = f"{build.get('bundleIdentifier') or 'app'} {build.get('marketingVersion') or '?'} ({build.get('buildNumber') or '?'})"
    processing = stages.get("processing-report")
    upload = stages.get("upload-report")
    if conclusion == "success" and processing == "VALID":
        return 0, (f"Processed by Apple: {label} is VALID. Internal groups with automatic distribution "
                   "receive it now; the TestFlight tile and installation are not verified by this command.")
    if conclusion == "success" and upload == "upload_accepted":
        return 0, (f"Upload accepted for {label}; Apple reports `{processing}`. Processing usually takes "
                   "a few minutes; rerun with --run to read it again, or open TestFlight on the phone.")
    step = failing_step(run.get("jobs", [])) or "unknown step"
    if upload == "upload_accepted":
        return 1, (f"Delivery run ended `{conclusion or 'unknown'}` at {step}, but the upload of {label} was "
                   "accepted: check App Store Connect before dispatching again.")
    return 1, f"Delivery run ended `{conclusion or 'unknown'}` at {step}; nothing was uploaded for {label}."


def render(run, stages, headline):
    lines = [f"# TestFlight delivery run {run.get('id')}", "", f"Run: {run.get('html_url') or 'unknown'}",
             f"Head: `{run.get('head_sha') or 'unknown'}`",
             f"Status: {run.get('status')} / **{run.get('conclusion') or 'no conclusion yet'}**"
             + (f"; {elapsed(run.get('run_started_at'), run.get('updated_at'))}" if is_finished(run) else ""),
             "", "## Stages", ""]
    for name in STAGES:
        lines.append(f"- {name}: **{stages.get(name, 'not_completed')}**")
    lines.extend(["", "## Jobs", ""])
    lines.extend(review_ci.job_lines(run.get("jobs", [])) or ["- No jobs are reported yet."])
    lines.extend(["", headline, ""])
    return "\n".join(lines)


def render_proposal(proposal, dry_run):
    lines = [f"Proposal: deliver `{proposal['configuration']}` from `{BRANCH}` @ `{proposal['head'][:12]}` in {proposal['repo']}.",
             f"Smoke evidence for this head ({SMOKE_WORKFLOW} push run): {proposal['smoke']}."]
    if proposal["inFlight"]:
        lines.append(f"Deliveries already in flight: {', '.join(str(i) for i in proposal['inFlight'])}.")
    lines.append(("Dry run; would dispatch: " if dry_run else "Dispatching: ") + proposal["command"])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--configuration", choices=CONFIGURATIONS, required=True, help="Configured app to deliver")
    parser.add_argument("--approve", action="store_true",
                        help="Approve the apple-credentials gate yourself once preflight passes (a conscious upload decision)")
    parser.add_argument("--dry-run", action="store_true", help="Print the proposal and the dispatch command only")
    parser.add_argument("--no-wait", action="store_true",
                        help="Dispatch, print the run ID and resume command, and exit without waiting")
    parser.add_argument("--run", metavar="RUN_ID", help="Resume an existing delivery run instead of dispatching")
    parser.add_argument("--wait-minutes", type=int, default=45, help="Total time to wait for approval and completion")
    parser.add_argument("--poll-seconds", type=int, default=30, help="Seconds between run status reads")
    args = parser.parse_args()
    if args.run is not None and not RUN_ID_RE.fullmatch(args.run):
        parser.error("--run must be a numeric workflow run ID")
    if args.run is not None and args.dry_run:
        parser.error("--dry-run applies only when dispatching")
    if getattr(args, "no_wait", False) and args.approve:
        parser.error("--approve cannot be combined with --no-wait")
    if getattr(args, "no_wait", False) and args.run is not None:
        parser.error("--no-wait applies only when dispatching")
    if args.wait_minutes < 1 or args.poll_seconds < 5:
        parser.error("--wait-minutes must be at least 1 and --poll-seconds at least 5")
    try:
        return deliver(args)
    except ReviewError as error:
        parser.exit(2, f"Delivery stopped: {error}\n")


def deliver(args, sleep=time.sleep, clock=time.monotonic):
    REPO[0] = repo_name()
    if args.run is None:
        proposal = propose(args.configuration)
        print(render_proposal(proposal, args.dry_run))
        if args.dry_run:
            return 0
        if proposal["inFlight"]:
            raise ReviewError("a delivery is already in flight; resume it with --run <id> or wait for it to finish.")
        known_ids = {run["databaseId"] for run in list_runs(WORKFLOW_FILE, limit=20, event="workflow_dispatch")}
        since = datetime.now(timezone.utc)
        dispatch(args.configuration)
        run = find_dispatched_run(known_ids, since, sleep=sleep)
        run_id = run["databaseId"]
        print(f"Dispatched run {run_id}: {run.get('url') or ''}")
        if getattr(args, "no_wait", False):
            print(f"Resume with: python scripts/deliver_testflight.py --configuration {args.configuration} --run {run_id}")
            return 0
    else:
        run_id = int(args.run)
        print(f"Resuming run {run_id}.")

    deadline = clock() + args.wait_minutes * 60
    announced = set()

    def progress(run):
        status = str(run.get("status") or "unknown")
        if status not in announced:
            announced.add(status)
            print(f"Run {run_id} is {status}; waiting (preflight runs first, then the approval gate).")

    try:
        run = wait_until(run_id, waiting_or_finished, deadline, args.poll_seconds, clock, sleep, progress)
        if is_waiting(run):
            pending = pending_environment(run_id)
            if pending is None:
                raise ReviewError(f"run {run_id} is waiting on something other than the {ENVIRONMENT} environment.")
            environment_id, approvable = pending
            if args.approve and approvable:
                approve(run_id, environment_id, args.configuration)
                print(f"Approved the {ENVIRONMENT} deployment for run {run_id}.")
            else:
                reason = "" if approvable else " (your GitHub account is not listed as a reviewer)"
                print(f"Run {run_id} is waiting for {ENVIRONMENT} approval{reason}. Approve it with:\n  "
                      + approval_command(run_id, environment_id) + "\n  or rerun this command with --approve.")
            run = wait_until(run_id, is_finished, deadline, args.poll_seconds, clock, sleep, progress)
    except DeliveryTimeout as timeout:
        print(f"Stopped waiting after {args.wait_minutes} minutes; run {run_id} is still `{timeout}`. "
              f"Resume with: python scripts/deliver_testflight.py --configuration {args.configuration} --run {run_id}")
        return 3

    stages = download_stages(run_id, args.configuration)
    code, headline = verdict(run, stages)
    print(render(run, stages, headline))
    return code


if __name__ == "__main__":
    sys.exit(main())
