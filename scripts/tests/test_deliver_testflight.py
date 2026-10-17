import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import ExitStack
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch

from scripts import deliver_testflight as deliver


def patch_gh(stack, fake):
    """Route every GitHub CLI call made by the command or its review helpers to ``fake``."""
    for module in (deliver, deliver.review_ci):
        stack.enter_context(patch.object(module, "gh", side_effect=fake))
    stack.enter_context(patch.object(deliver, "repo_name", return_value="o/r"))
    deliver.REPO[0] = "o/r"


class FakeGitHub:
    def __init__(self, runs=None, api=None):
        self.runs = runs or {}
        self.api = api or {}
        self.calls = []

    def __call__(self, args, **kwargs):
        self.calls.append(list(args))
        if args[:2] == ["run", "list"]:
            workflow = args[args.index("--workflow") + 1]
            event = args[args.index("--event") + 1] if "--event" in args else None
            listing = [run for run in self.runs.get(workflow, []) if event is None or run.get("event") == event]
            return SimpleNamespace(stdout=json.dumps(listing))
        if args[0] == "api":
            key = " ".join(a for a in args[1:] if not a.startswith("-"))
            if args[1] == "-X":
                key = "POST " + args[3]
            if key not in self.api:
                raise AssertionError(f"unexpected gh api call: {args}")
            return SimpleNamespace(stdout=json.dumps(self.api[key]))
        if args[:2] in (["workflow", "run"], ["run", "download"]):
            return SimpleNamespace(stdout="")
        raise AssertionError(f"unexpected gh call: {args}")


class DeliverTestFlightTests(unittest.TestCase):
    def test_proposal_reports_head_smoke_evidence_and_in_flight_runs(self):
        fake = FakeGitHub(
            runs={"iOS": [
                {"databaseId": 5, "event": "push", "headSha": "ABCDEF", "status": "completed",
                 "conclusion": "success", "createdAt": "2026-10-16T10:00:00Z"},
                {"databaseId": 4, "event": "push", "headSha": "OLD", "status": "completed",
                 "conclusion": "failure", "createdAt": "2026-10-16T09:00:00Z"}],
                "testflight-delivery.yml": [
                    {"databaseId": 9, "event": "workflow_dispatch", "status": "waiting", "createdAt": "2026-10-16T11:00:00Z"},
                    {"databaseId": 8, "event": "push", "status": "completed", "createdAt": "2026-10-16T08:00:00Z"}]},
            api={"repos/o/r/branches/main": {"commit": {"sha": "abcdef"}}})
        with ExitStack() as stack:
            patch_gh(stack, fake)
            proposal = deliver.propose("starter-app-demo")
        self.assertEqual(proposal["head"], "abcdef")
        self.assertEqual(proposal["smoke"], "run 5: success")
        self.assertEqual(proposal["inFlight"], [9])
        text = deliver.render_proposal(proposal, dry_run=True)
        self.assertIn("Dry run; would dispatch: gh workflow run testflight-delivery.yml --ref main "
                      "--field configuration=starter-app-demo --field perform_upload=true", text)
        self.assertIn("Deliveries already in flight: 9.", text)

    def test_dispatched_run_is_the_new_manual_run_only(self):
        since = datetime(2026, 10, 16, 12, 0, tzinfo=timezone.utc)
        listings = [[], [
            {"databaseId": 20, "event": "workflow_dispatch", "createdAt": "2026-10-16T11:00:00Z", "status": "completed"},
            {"databaseId": 21, "event": "workflow_dispatch", "createdAt": "2026-10-16T12:00:10Z", "status": "queued"}]]
        fake = FakeGitHub(runs={"testflight-delivery.yml": []})
        sleeps = []

        def fake_gh(args, **kwargs):
            fake.runs["testflight-delivery.yml"] = listings.pop(0) if listings else []
            return fake(args, **kwargs)

        with ExitStack() as stack:
            patch_gh(stack, fake_gh)
            run = deliver.find_dispatched_run({20}, since, attempts=3, interval=1, sleep=sleeps.append)
        self.assertEqual(run["databaseId"], 21)
        self.assertEqual(sleeps, [1])
        with ExitStack() as stack:
            patch_gh(stack, FakeGitHub(runs={"testflight-delivery.yml": []}))
            with self.assertRaises(deliver.ReviewError):
                deliver.find_dispatched_run(set(), since, attempts=2, interval=1, sleep=lambda _: None)

    def test_wait_until_polls_then_times_out_with_status(self):
        states = iter(["queued", "in_progress", "in_progress"])
        clock_values = iter([0, 10, 70])
        api = {"repos/o/r/actions/runs/7/jobs?per_page=100": {"jobs": []}}
        fake = FakeGitHub(api=api)

        def fake_gh(args, **kwargs):
            if args[0] == "api" and args[1] == "repos/o/r/actions/runs/7":
                return SimpleNamespace(stdout=json.dumps({"id": 7, "status": next(states)}))
            return fake(args, **kwargs)

        seen = []
        with ExitStack() as stack:
            patch_gh(stack, fake_gh)
            with self.assertRaises(deliver.DeliveryTimeout) as context:
                deliver.wait_until(7, deliver.is_waiting, deadline=60, interval=5,
                                   clock=lambda: next(clock_values), sleep=lambda _: None, progress=seen.append)
        self.assertEqual(str(context.exception), "in_progress")
        self.assertEqual([run["status"] for run in seen], ["queued", "in_progress"])

    def test_pending_environment_and_approval_command(self):
        api = {"repos/o/r/actions/runs/7/pending_deployments": [
            {"environment": {"id": 123, "name": "other"}, "current_user_can_approve": True},
            {"environment": {"id": 456, "name": "apple-credentials"}, "current_user_can_approve": False}]}
        with ExitStack() as stack:
            patch_gh(stack, FakeGitHub(api=api))
            self.assertEqual(deliver.pending_environment(7), (456, False))
        self.assertEqual(deliver.approval_command(7, 456),
                         'gh api -X POST repos/o/r/actions/runs/7/pending_deployments '
                         '-F "environment_ids[]=456" -f state=approved -f comment="approved delivery"')
        fake = FakeGitHub(api={"POST repos/o/r/actions/runs/7/pending_deployments": [{}]})
        with ExitStack() as stack:
            patch_gh(stack, fake)
            deliver.approve(7, 456, "starter")
        self.assertEqual(fake.calls[-1][:4], ["api", "-X", "POST", "repos/o/r/actions/runs/7/pending_deployments"])
        self.assertIn("environment_ids[]=456", fake.calls[-1])
        with ExitStack() as stack:
            patch_gh(stack, FakeGitHub(api={"repos/o/r/actions/runs/7/pending_deployments": []}))
            self.assertIsNone(deliver.pending_environment(7))

    def test_stage_reports_read_fixed_fields_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "nested"
            root.mkdir()
            (root / "release-plan.json").write_text(json.dumps({
                "status": "planned", "bundleIdentifier": "com.example.app", "marketingVersion": "1.0",
                "buildNumber": "42", "teamIdentifier": "SECRETTEAM"}))
            (root / "upload-report.json").write_text(json.dumps({"status": "upload_accepted"}))
            (root / "processing-report.json").write_text("not json")
            stages = deliver.read_stages(directory)
        self.assertEqual(stages["release-plan"], "planned")
        self.assertEqual(stages["delivery-validation"], "not_completed")
        self.assertEqual(stages["upload-report"], "upload_accepted")
        self.assertEqual(stages["processing-report"], "not_completed")
        self.assertEqual(stages["build"], {"bundleIdentifier": "com.example.app", "marketingVersion": "1.0", "buildNumber": "42"})
        self.assertNotIn("SECRETTEAM", json.dumps(stages))

    def test_verdict_distinguishes_processed_accepted_and_failures(self):
        build = {"bundleIdentifier": "com.example.app", "marketingVersion": "1.0", "buildNumber": "42"}
        success = {"conclusion": "success", "jobs": []}
        code, text = deliver.verdict(success, {"processing-report": "VALID", "upload-report": "upload_accepted", "build": build})
        self.assertEqual(code, 0)
        self.assertIn("Processed by Apple: com.example.app 1.0 (42) is VALID", text)
        self.assertIn("not verified by this command", text)
        code, text = deliver.verdict(success, {"processing-report": "PROCESSING", "upload-report": "upload_accepted", "build": build})
        self.assertEqual(code, 0)
        self.assertIn("Upload accepted for com.example.app 1.0 (42); Apple reports `PROCESSING`", text)
        failed = {"conclusion": "failure", "jobs": [
            {"name": "preflight", "conclusion": "success", "steps": [{"name": "a", "conclusion": "success"}]},
            {"name": "deliver", "conclusion": "failure", "steps": [
                {"name": "Check out repository", "conclusion": "success"},
                {"name": "Export App Store Connect distribution package", "conclusion": "failure"}]}]}
        code, text = deliver.verdict(failed, {"upload-report": "not_completed", "build": build})
        self.assertEqual(code, 1)
        self.assertIn("at deliver / Export App Store Connect distribution package (failure)", text)
        self.assertIn("nothing was uploaded", text)
        code, text = deliver.verdict(failed, {"upload-report": "upload_accepted", "build": build})
        self.assertEqual(code, 1)
        self.assertIn("upload of com.example.app 1.0 (42) was accepted: check App Store Connect", text)
        self.assertIsNone(deliver.failing_step([{"name": "deliver", "conclusion": "success"}]))
        self.assertEqual(deliver.failing_step([{"name": "deliver", "conclusion": "cancelled"}]), "deliver (cancelled)")

    def test_deliver_end_to_end_approves_waits_and_reports(self):
        run_states = iter([
            {"id": 31, "status": "in_progress"},
            {"id": 31, "status": "waiting"},
            {"id": 31, "status": "completed", "conclusion": "success", "html_url": "https://github.com/o/r/actions/runs/31",
             "head_sha": "abcdef", "run_started_at": "2026-10-16T12:00:00Z", "updated_at": "2026-10-16T12:20:00Z"}])
        api = {
            "repos/o/r/branches/main": {"commit": {"sha": "abcdef"}},
            "repos/o/r/actions/runs/31/jobs?per_page=100": {"jobs": [{"name": "deliver", "conclusion": "success"}]},
            "repos/o/r/actions/runs/31/pending_deployments": [
                {"environment": {"id": 9, "name": "apple-credentials"}, "current_user_can_approve": True}],
            "POST repos/o/r/actions/runs/31/pending_deployments": [{}],
            "repos/o/r/actions/runs/31/artifacts": {"artifacts": [{"name": "testflight-delivery-starter-app-demo", "expired": False}]},
        }
        fake = FakeGitHub(runs={"iOS": [], "testflight-delivery.yml": []}, api=api)
        dispatched = []

        def fake_gh(args, **kwargs):
            if args[:2] == ["workflow", "run"]:
                dispatched.append(list(args))
                fake.runs["testflight-delivery.yml"] = [{"databaseId": 31, "event": "workflow_dispatch",
                                                         "createdAt": datetime.now(timezone.utc).isoformat(),
                                                         "status": "queued", "url": "https://github.com/o/r/actions/runs/31"}]
                return SimpleNamespace(stdout="")
            if args[0] == "api" and args[1] == "repos/o/r/actions/runs/31":
                return SimpleNamespace(stdout=json.dumps(next(run_states)))
            if args[:2] == ["run", "download"]:
                target = Path(args[args.index("--dir") + 1])
                (target / "release-plan.json").write_text(json.dumps({"status": "planned", "bundleIdentifier": "com.example.app",
                                                                       "marketingVersion": "1.0", "buildNumber": "42"}))
                (target / "upload-report.json").write_text(json.dumps({"status": "upload_accepted"}))
                (target / "processing-report.json").write_text(json.dumps({"status": "VALID"}))
                return SimpleNamespace(stdout="")
            return fake(args, **kwargs)

        args = SimpleNamespace(configuration="starter-app-demo", approve=True, dry_run=False, run=None,
                               wait_minutes=1, poll_seconds=5)
        with ExitStack() as stack:
            patch_gh(stack, fake_gh)
            output = stack.enter_context(patch("sys.stdout", new_callable=io.StringIO))
            code = deliver.deliver(args, sleep=lambda _: None, clock=lambda: 0)
        text = output.getvalue()
        self.assertEqual(code, 0)
        self.assertEqual(dispatched[0][:3], ["workflow", "run", "testflight-delivery.yml"])
        self.assertIn("--field", dispatched[0])
        self.assertIn("perform_upload=true", dispatched[0])
        self.assertIn("Dispatched run 31", text)
        self.assertIn("Approved the apple-credentials deployment for run 31.", text)
        self.assertIn("- processing-report: **VALID**", text)
        self.assertIn("Processed by Apple: com.example.app 1.0 (42) is VALID", text)
        self.assertIn("20m 0s", text)
        self.assertTrue(any(call[:3] == ["api", "-X", "POST"] for call in fake.calls))

    def test_deliver_without_approve_prints_command_and_refuses_double_dispatch(self):
        api = {
            "repos/o/r/branches/main": {"commit": {"sha": "abcdef"}},
            "repos/o/r/actions/runs/31": {"id": 31, "status": "waiting"},
            "repos/o/r/actions/runs/31/jobs?per_page=100": {"jobs": []},
            "repos/o/r/actions/runs/31/pending_deployments": [
                {"environment": {"id": 9, "name": "apple-credentials"}, "current_user_can_approve": True}],
        }
        fake = FakeGitHub(runs={"iOS": [], "testflight-delivery.yml": [
            {"databaseId": 31, "event": "workflow_dispatch", "status": "waiting", "createdAt": "2026-10-16T11:00:00Z"}]}, api=api)
        args = SimpleNamespace(configuration="starter", approve=False, dry_run=False, run=None, wait_minutes=1, poll_seconds=5)
        with ExitStack() as stack:
            patch_gh(stack, fake)
            stack.enter_context(patch("sys.stdout", new_callable=io.StringIO))
            with self.assertRaises(deliver.ReviewError) as context:
                deliver.deliver(args, sleep=lambda _: None, clock=lambda: 0)
        self.assertIn("already in flight", str(context.exception))
        self.assertFalse(any(call[:2] == ["workflow", "run"] for call in fake.calls))

        clock_values = iter([0, 0, 100, 100, 100])
        args = SimpleNamespace(configuration="starter", approve=False, dry_run=False, run="31", wait_minutes=1, poll_seconds=5)
        with ExitStack() as stack:
            patch_gh(stack, fake)
            output = stack.enter_context(patch("sys.stdout", new_callable=io.StringIO))
            code = deliver.deliver(args, sleep=lambda _: None, clock=lambda: next(clock_values))
        text = output.getvalue()
        self.assertEqual(code, 3)
        self.assertIn('gh api -X POST repos/o/r/actions/runs/31/pending_deployments -F "environment_ids[]=9"', text)
        self.assertIn("--run 31", text)
        self.assertFalse(any(call[:3] == ["api", "-X", "POST"] for call in fake.calls))

    def test_cli_validates_arguments(self):
        for argv in (["--configuration", "nope"], ["--run", "x", "--configuration", "starter"],
                     ["--run", "1", "--dry-run", "--configuration", "starter"],
                     ["--configuration", "starter", "--poll-seconds", "1"], []):
            with self.subTest(argv=argv), patch.object(sys, "argv", ["deliver_testflight.py", *argv]), \
                    patch("sys.stderr", new_callable=io.StringIO):
                with self.assertRaises(SystemExit) as context:
                    deliver.main()
                self.assertEqual(context.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
