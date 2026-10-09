import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("credential_bootstrap", ROOT / "scripts/bootstrap-apple-credentials.py")
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)

KEY = b"-----BEGIN PRIVATE KEY-----\nPRIVATE-CREDENTIAL-CANARY\n-----END PRIVATE KEY-----\n"
KEY_ID = "85ZVCWMRWD"
ISSUER = "790b5187-535d-49f5-95a9-b299ec1da35a"


def environment(branches=None, reviewers=None, prevent_self_review=True):
    return {
        "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True},
        "protection_rules": [{"type": "required_reviewers", "reviewers": reviewers if reviewers is not None else [{"type": "User", "reviewer": {"login": "reviewer"}}],
                              "prevent_self_review": prevent_self_review}],
        "branches": branches or [{"name": "main", "type": "branch"}],
    }


class CredentialBootstrapTests(unittest.TestCase):
    def test_key_is_sent_only_over_stdin_and_only_secret_names_are_verified(self):
        calls = []

        def fake_gh(args, stdin=None):
            calls.append((args, stdin))
            if args[:2] == ["api", "repos/team/app/environments/apple-credentials"]:
                return json.dumps(environment()).encode()
            if args[:2] == ["api", "repos/team/app/environments/apple-credentials/deployment-branch-policies"]:
                return json.dumps({"branch_policies": environment()["branches"]}).encode()
            if "secrets?per_page=100" in args[-1]:
                count = sum("secrets?per_page=100" in call[0][-1] for call in calls)
                names = [] if count == 1 else bootstrap.SECRET_NAMES
                return json.dumps({"secrets": [{"name": name} for name in names]}).encode()
            return b""

        with tempfile.TemporaryDirectory() as directory:
            key_path = Path(directory) / "AuthKey.p8"
            key_path.write_bytes(KEY)
            args = type("Args", (), dict(repo="team/app", key_id=KEY_ID, issuer_id=ISSUER,
                                          key_type="team", private_key_file=key_path,
                                          replace_existing=False))()
            with patch.object(bootstrap, "gh", side_effect=fake_gh):
                bootstrap.bootstrap(args)

        key_calls = [(command, data) for command, data in calls if command[:2] == ["secret", "set"]]
        self.assertEqual([call[0][2] for call in key_calls], ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"])
        self.assertEqual(key_calls[-1][1], KEY)
        self.assertNotIn(KEY.decode(), " ".join(calls[-1][0]))

    def test_refuses_key_file_inside_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            key_path = repo / "AuthKey.p8"
            key_path.write_bytes(KEY)
            with self.assertRaisesRegex(bootstrap.BootstrapError, "outside the repository"):
                bootstrap.read_key(key_path, repo)

    def test_requires_main_only_policy_and_independent_review(self):
        cases = [
            (environment(branches=[{"name": "*", "type": "branch"}]), "exactly the main branch"),
            (environment(reviewers=[], prevent_self_review=True), "required reviewers"),
            (environment(prevent_self_review=False), "self-review prevented"),
        ]
        for metadata, error in cases:
            with self.subTest(error=error), patch.object(bootstrap, "gh_json", side_effect=[metadata, {"branch_policies": metadata["branches"]}]):
                with self.assertRaisesRegex(bootstrap.BootstrapError, error):
                    bootstrap.verify_protections("team/app")

    def test_does_not_replace_existing_secrets_without_explicit_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            key_path = Path(directory) / "AuthKey.p8"
            key_path.write_bytes(KEY)
            args = type("Args", (), dict(repo="team/app", key_id=KEY_ID, issuer_id=ISSUER,
                                          key_type="team", private_key_file=key_path,
                                          replace_existing=False))()
            with patch.object(bootstrap, "verify_protections"), \
                    patch.object(bootstrap, "existing_secret_names", return_value={"ASC_PRIVATE_KEY"}), \
                    patch.object(bootstrap, "gh") as set_secret:
                with self.assertRaisesRegex(bootstrap.BootstrapError, "already exist"):
                    bootstrap.bootstrap(args)
                set_secret.assert_not_called()

    def test_gh_errors_do_not_echo_upstream_content(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"", KEY)):
            with self.assertRaises(bootstrap.BootstrapError) as error:
                bootstrap.gh(["secret", "set", "ASC_PRIVATE_KEY"], stdin=KEY)
        self.assertNotIn(KEY.decode(), str(error.exception))


if __name__ == "__main__":
    unittest.main()

