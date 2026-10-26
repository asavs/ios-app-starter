#!/usr/bin/env python3
"""Show, then apply, the recommended GitHub repository settings for the fast pull-request loop.

Dry run by default: prints each setting's current and intended value. `--apply` changes only
the settings that differ. Uses the authenticated GitHub CLI; never prints tokens.
"""
import argparse
import json
import re
import subprocess
import sys

REPO_NAME = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")
RULESET_NAME = "main: pull requests with passing gate"
APPLE_ENVIRONMENT = "apple-credentials"
REQUIRED_CHECKS = ["ios-gate", "portable (ubuntu-latest)", "portable (windows-latest)", "portable (macos-latest)"]


class ConfigError(Exception):
    pass


def gh_api(path, method="GET", body=None):
    command = ["gh", "api", "-X", method, path]
    if body is not None:
        command += ["--input", "-"]
    try:
        result = subprocess.run(command, input=json.dumps(body).encode() if body is not None else None,
                                capture_output=True, check=False)
    except OSError as error:
        raise ConfigError("GitHub CLI (`gh`) could not be started.") from error
    if result.returncode:
        detail = result.stderr.decode(errors="replace").strip().splitlines()
        raise ConfigError(f"GitHub API {method} {path} failed: {detail[-1] if detail else 'no detail'}")
    text = result.stdout.decode(errors="replace").strip()
    return json.loads(text) if text else {}


def ruleset_body():
    return {
        "name": RULESET_NAME, "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
        "bypass_actors": [],
        "rules": [
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            {"type": "pull_request", "parameters": {
                "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": False,
                "require_code_owner_review": False, "require_last_push_approval": False,
                "required_review_thread_resolution": False, "allowed_merge_methods": ["merge", "squash"]}},
            {"type": "required_status_checks", "parameters": {
                "strict_required_status_checks_policy": False, "do_not_enforce_on_create": False,
                "required_status_checks": [{"context": name} for name in REQUIRED_CHECKS]}},
        ],
    }


def apple_environment_plan(repo, required_reviewer=False):
    """Return a preview and apply function for the protected Apple credential environment."""
    base = f"repos/{repo}"
    metadata = gh_api(base)
    owner = metadata.get("owner") or {}
    login = ""
    reviewer_id = None
    prevent_self_review = False
    if required_reviewer:
        caller = gh_api("user")
        login = str(caller.get("login", ""))
        reviewer_id = caller.get("id")
        if not login or not isinstance(reviewer_id, int):
            raise ConfigError("GitHub did not return the authenticated user's reviewer identity.")

        # A personal repository owner may approve their own deployment. In every other
        # case, prevent the workflow initiator from also approving the environment.
        solo_owner = (owner.get("type") == "User"
                      and str(owner.get("login", "")).casefold() == login.casefold())
        prevent_self_review = not solo_owner
    environments = gh_api(f"{base}/environments").get("environments", [])
    current = next((item for item in environments if item.get("name") == APPLE_ENVIRONMENT), None)
    if current:
        policies = gh_api(f"{base}/environments/{APPLE_ENVIRONMENT}/deployment-branch-policies")
        protection = next((rule for rule in current.get("protection_rules", [])
                           if rule.get("type") == "required_reviewers"), {})
        reviewers = []
        for reviewer in protection.get("reviewers", []):
            identity = reviewer.get("reviewer", {})
            reviewers.append({"type": reviewer.get("type"), "login": identity.get("login"),
                              "id": identity.get("id")})
        current_value = {
            "exists": True,
            "reviewers": reviewers,
            "prevent_self_review": protection.get("prevent_self_review"),
            "deployment_branch_policy": current.get("deployment_branch_policy"),
            "branches": [{"name": item.get("name"), "type": item.get("type")}
                         for item in policies.get("branch_policies", [])],
        }
    else:
        current_value = {"exists": False}

    intended = {
        "exists": True,
        "reviewers": ([{"type": "User", "login": login, "id": reviewer_id}]
                      if required_reviewer else []),
        "prevent_self_review": prevent_self_review,
        "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True},
        "branches": [{"name": "main", "type": "branch"}],
    }

    def apply():
        gh_api(f"{base}/environments/{APPLE_ENVIRONMENT}", "PUT", {
            "reviewers": ([{"type": "User", "id": reviewer_id}]
                          if required_reviewer else []),
            "prevent_self_review": prevent_self_review,
            "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True},
        })
        path = f"{base}/environments/{APPLE_ENVIRONMENT}/deployment-branch-policies"
        policies = gh_api(path).get("branch_policies", [])
        for policy in policies:
            if policy.get("name") != "main" or policy.get("type") != "branch":
                gh_api(f"{path}/{policy['id']}", "DELETE")
        if not any(policy.get("name") == "main" and policy.get("type") == "branch"
                   for policy in policies):
            gh_api(path, "POST", {"name": "main"})

    return current_value, intended, apply


def plan(repo, required_reviewer=False):
    """Return (label, current, intended, apply_callable) for every managed setting."""
    base = f"repos/{repo}"
    meta = gh_api(base)
    security = meta.get("security_and_analysis") or {}
    actions = gh_api(f"{base}/actions/permissions")
    selected = gh_api(f"{base}/actions/permissions/selected-actions") if actions.get("allowed_actions") == "selected" else {}
    fork = gh_api(f"{base}/actions/permissions/fork-pr-contributor-approval")
    workflow = gh_api(f"{base}/actions/permissions/workflow")
    rulesets = gh_api(f"{base}/rulesets")
    existing = next((item for item in rulesets if item.get("name") == RULESET_NAME), None)
    environment_current, environment_intended, apply_environment = apple_environment_plan(repo, required_reviewer)

    items = [
        ("Auto-merge allowed", meta.get("allow_auto_merge"), True,
         lambda: gh_api(base, "PATCH", {"allow_auto_merge": True})),
        ("Delete head branches after merge", meta.get("delete_branch_on_merge"), True,
         lambda: gh_api(base, "PATCH", {"delete_branch_on_merge": True})),
        ("Secret scanning", (security.get("secret_scanning") or {}).get("status"), "enabled",
         lambda: gh_api(base, "PATCH", {"security_and_analysis": {"secret_scanning": {"status": "enabled"}}})),
        ("Secret scanning push protection", (security.get("secret_scanning_push_protection") or {}).get("status"), "enabled",
         lambda: gh_api(base, "PATCH", {"security_and_analysis": {"secret_scanning_push_protection": {"status": "enabled"}}})),
        ("Allowed actions", actions.get("allowed_actions"), "selected",
         lambda: gh_api(f"{base}/actions/permissions", "PUT", {"enabled": True, "allowed_actions": "selected"})),
        ("Selected actions: GitHub-owned and verified creators",
         (selected.get("github_owned_allowed"), selected.get("verified_allowed"), tuple(selected.get("patterns_allowed") or [])),
         (True, True, ()),
         lambda: gh_api(f"{base}/actions/permissions/selected-actions", "PUT",
                        {"github_owned_allowed": True, "verified_allowed": True, "patterns_allowed": []})),
        ("Fork pull request workflow approval", fork.get("approval_policy"), "all_external_contributors",
         lambda: gh_api(f"{base}/actions/permissions/fork-pr-contributor-approval", "PUT", {"approval_policy": "all_external_contributors"})),
        # Lets a workflow that asks for write access open a pull request (the README icon sync); the
        # default token stays read-only and the ruleset still requires checks before anything merges.
        ("Workflows may open pull requests", workflow.get("can_approve_pull_request_reviews"), True,
         lambda: gh_api(f"{base}/actions/permissions/workflow", "PUT",
                        {"default_workflow_permissions": workflow.get("default_workflow_permissions", "read"),
                         "can_approve_pull_request_reviews": True})),
        (f"Ruleset '{RULESET_NAME}' on the default branch",
         "present" if existing else "absent", "present (pull request + required checks: " + ", ".join(REQUIRED_CHECKS) + ")",
         lambda: gh_api(f"{base}/rulesets", "POST", ruleset_body())),
        (f"Environment '{APPLE_ENVIRONMENT}' (main only; "
         f"{'required reviewer' if required_reviewer else 'no required reviewer'})",
         environment_current, environment_intended, apply_environment),
    ]
    return items


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", required=True, help="owner/repository to configure")
    parser.add_argument("--require-reviewer", action="store_true",
                        help="Require the authenticated GitHub user to review apple-credentials deployments (default: off; main-only policy still applies)")
    parser.add_argument("--apply", action="store_true", help="Change settings that differ; default is a dry run")
    args = parser.parse_args()
    if not REPO_NAME.fullmatch(args.repo):
        raise ConfigError("Use owner/repository form.")
    items = plan(args.repo, args.require_reviewer)
    changes = 0
    for label, current, intended, apply in items:
        differs = current != intended and not (isinstance(intended, str) and intended.startswith("present") and current == "present")
        marker = "CHANGE" if differs else "ok"
        print(f"[{marker}] {label}: current={current!r} intended={intended!r}")
        if differs and args.apply:
            apply()
            changes += 1
            print(f"         applied")
    if not args.apply:
        print("\nDry run. Re-run with --apply to change the settings marked CHANGE. "
              "The ruleset blocks direct pushes to the default branch for everyone, including the owner; "
              "every change then goes through a pull request whose required checks must pass.")
    else:
        print(f"\nApplied {changes} change(s). Verify with a dry run.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ConfigError as error:
        print(f"Repository configuration stopped: {error}", file=sys.stderr)
        raise SystemExit(1)
