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
KEY_ID = "TESTKEY001"
ISSUER = "00000000-1111-2222-3333-444444444444"


def environment(branches=None, reviewers=None, prevent_self_review=True):
    return {
        "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True},
        "protection_rules": [{"type": "required_reviewers", "reviewers": reviewers if reviewers is not None else [{"type": "User", "reviewer": {"login": "reviewer"}}],
                              "prevent_self_review": prevent_self_review}],
        "branches": branches or [{"name": "main", "type": "branch"}],
    }


class CredentialBootstrapTests(unittest.TestCase):
    def test_solo_owner_policy_requires_actual_owner_and_self_review_allowed(self):
        valid = environment(reviewers=[{"type": "User", "reviewer": {"login": "owner"}}], prevent_self_review=False)
        def responses(metadata=valid, owner="owner", caller="owner", owner_type="User"):
            return [metadata, {"branch_policies": metadata["branches"]},
                    {"owner": {"login": owner, "type": owner_type}}, {"login": caller}]
        with patch.object(bootstrap, "gh_json", side_effect=responses()):
            bootstrap.verify_protections("owner/app", "solo-owner")
        cases = [responses(caller="collaborator"), responses(owner_type="Organization"),
                 responses(metadata=environment(prevent_self_review=False)),
                 responses(metadata=environment(reviewers=valid["protection_rules"][0]["reviewers"], prevent_self_review=True))]
        for response in cases:
            with self.subTest(response=response), patch.object(bootstrap, "gh_json", side_effect=response):
                with self.assertRaisesRegex(bootstrap.BootstrapError, "Solo-owner"):
                    bootstrap.verify_protections("owner/app", "solo-owner")

    def test_policy_failure_precedes_key_file_access_and_secret_writes(self):
        args = type("Args", (), dict(repo="owner/app", key_id=KEY_ID, issuer_id=ISSUER,
                    key_type="team", private_key_file=Path("unused.p8"), replace_existing=False,
                    approval_policy="solo-owner"))()
        with patch.object(bootstrap, "verify_protections", side_effect=bootstrap.BootstrapError("missing approval")), \
                patch.object(bootstrap, "read_key") as read, patch.object(bootstrap, "set_secret") as write:
            with self.assertRaisesRegex(bootstrap.BootstrapError, "missing approval"):
                bootstrap.bootstrap(args)
            read.assert_not_called()
            write.assert_not_called()

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
                                          replace_existing=False, approval_policy="independent"))()
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
                                          replace_existing=False, approval_policy="independent"))()
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
