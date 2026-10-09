#!/usr/bin/env python3
"""Transfer an existing Apple .p8 key into a protected GitHub environment."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


ENVIRONMENT = "apple-credentials"
SECRET_NAMES = {"ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"}
REPO_NAME = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")
KEY_ID = re.compile(r"[A-Z0-9]{10}\Z")
ISSUER_ID = re.compile(r"[A-Fa-f0-9-]{36}\Z")
PEM_BEGIN = b"-----BEGIN PRIVATE KEY-----"
PEM_END = b"-----END PRIVATE KEY-----"


class BootstrapError(Exception):
    pass


def gh(args, *, stdin=None):
    """Run gh without ever rendering request bodies or upstream errors."""
    try:
        result = subprocess.run(["gh", *args], input=stdin, capture_output=True, check=False)
    except OSError as error:
        raise BootstrapError("GitHub CLI (`gh`) could not be started.") from error
    if result.returncode:
        operation = args[1] if len(args) > 1 else "request"
        raise BootstrapError(f"GitHub CLI {operation} failed (exit {result.returncode}); no secret contents were displayed.")
    return result.stdout


def gh_json(args):
    try:
        return json.loads(gh(args).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise BootstrapError("GitHub returned an unreadable metadata response; no secrets were changed.") from error


def environment_path(repo):
    return f"repos/{repo}/environments/{ENVIRONMENT}"


def verify_protections(repo):
    environment = gh_json(["api", environment_path(repo)])
    policy = environment.get("deployment_branch_policy") or {}
    if policy != {"protected_branches": False, "custom_branch_policies": True}:
        raise BootstrapError("apple-credentials must use custom deployment branch policies before credentials can be stored.")

    policies = gh_json(["api", environment_path(repo) + "/deployment-branch-policies"])
    branches = policies.get("branch_policies", [])
    if len(branches) != 1 or branches[0].get("name") != "main" or branches[0].get("type") != "branch":
        raise BootstrapError("apple-credentials must allow exactly the main branch before credentials can be stored.")

    rules = environment.get("protection_rules", [])
    review = next((rule for rule in rules if rule.get("type") == "required_reviewers"), None)
    if not review or not review.get("reviewers") or review.get("prevent_self_review") is not True:
        raise BootstrapError("apple-credentials needs required reviewers with self-review prevented before credentials can be stored.")


def read_key(path, repository_root):
    try:
        resolved = path.expanduser().resolve(strict=True)
    except OSError as error:
        raise BootstrapError("The local private-key file could not be opened.") from error
    try:
        resolved.relative_to(repository_root.resolve())
    except ValueError:
        pass
    else:
        raise BootstrapError("Keep the private-key file outside the repository checkout.")
    if not resolved.is_file():
        raise BootstrapError("The provided private-key path is not a file.")
    try:
        value = resolved.read_bytes()
    except OSError as error:
        raise BootstrapError("The local private-key file could not be opened.") from error
    if len(value) > 64 * 1024 or not value.strip().startswith(PEM_BEGIN) or not value.strip().endswith(PEM_END):
        raise BootstrapError("The selected file is not a valid-sized PEM private-key file.")
    return value.strip() + b"\n"


def existing_secret_names(repo):
    response = gh_json(["api", environment_path(repo) + "/secrets?per_page=100"])
    return {secret.get("name") for secret in response.get("secrets", []) if isinstance(secret, dict)}


def set_secret(repo, name, value):
    gh(["secret", "set", name, "--env", ENVIRONMENT, "--repo", repo], stdin=value)


def bootstrap(args):
    if not REPO_NAME.fullmatch(args.repo):
        raise BootstrapError("Use an explicit GitHub destination in owner/repository form.")
    if not KEY_ID.fullmatch(args.key_id):
        raise BootstrapError("The App Store Connect key ID format is invalid.")
    if args.key_type == "team" and not args.issuer_id:
        raise BootstrapError("A team API key requires its issuer ID.")
    if args.issuer_id and not ISSUER_ID.fullmatch(args.issuer_id):
        raise BootstrapError("The issuer ID format is invalid.")

    key_bytes = read_key(args.private_key_file, Path(__file__).resolve().parents[1])
    verify_protections(args.repo)
    existing = existing_secret_names(args.repo)
    if existing.intersection(SECRET_NAMES) and not args.replace_existing:
        raise BootstrapError("Credential secret names already exist; review them first or rerun with --replace-existing.")
    if args.key_type == "individual" and "ASC_ISSUER_ID" in existing:
        raise BootstrapError("An issuer secret already exists; remove or replace the stale team-key configuration before using an individual key.")

    # The discriminator is non-sensitive. The key file is sent only on gh's stdin;
    # it never appears in command arguments, stdout, stderr, logs, or artifacts.
    set_secret(args.repo, "ASC_KEY_ID", args.key_id.encode("ascii"))
    if args.key_type == "team":
        set_secret(args.repo, "ASC_ISSUER_ID", args.issuer_id.encode("ascii"))
    set_secret(args.repo, "ASC_PRIVATE_KEY", key_bytes)

    stored = existing_secret_names(args.repo)
    expected = {"ASC_KEY_ID", "ASC_PRIVATE_KEY"}
    if args.key_type == "team":
        expected.add("ASC_ISSUER_ID")
    if not expected <= stored:
        raise BootstrapError("GitHub did not confirm all expected secret names; secret values were not read back.")
    gh(["variable", "set", "ASC_KEY_TYPE", "--env", ENVIRONMENT,
        "--repo", args.repo, "--body", args.key_type])
    print(f"Configured {ENVIRONMENT} for {args.repo}; GitHub confirms the expected secret names only.")
    print("The private-key value was sent through gh stdin and was not read back or displayed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="GitHub destination in owner/repository form")
    parser.add_argument("--key-type", choices=("team", "individual"), required=True)
    parser.add_argument("--key-id", required=True, help="Non-secret App Store Connect key ID")
    parser.add_argument("--issuer-id", help="Required for a team key; omit for an individual key")
    parser.add_argument("--private-key-file", required=True, type=Path,
                        help="Existing securely stored .p8 path outside this checkout")
    parser.add_argument("--replace-existing", action="store_true",
                        help="Explicitly replace matching Apple credential secret names")
    args = parser.parse_args()
    try:
        bootstrap(args)
    except BootstrapError as error:
        print(f"Credential setup stopped: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
