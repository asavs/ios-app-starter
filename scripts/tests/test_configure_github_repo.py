import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("configure_github_repo", ROOT / "scripts/configure-github-repo.py")
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)


class ConfigureGitHubRepoTests(unittest.TestCase):
    def run_environment_plan(self, required_reviewer):
        calls = []

        def fake_gh_api(path, method="GET", body=None):
            calls.append((path, method, body))
            if path == "repos/o/r":
                return {"owner": {"type": "User", "login": "owner"}}
            if path == "user":
                return {"login": "owner", "id": 7}
            if path == "repos/o/r/environments":
                return {"environments": []}
            if path.endswith("/deployment-branch-policies"):
                return {"branch_policies": []}
            return {}

        with patch.object(configure, "gh_api", side_effect=fake_gh_api):
            current, intended, apply = configure.apple_environment_plan("o/r", required_reviewer)
            apply()
        return current, intended, calls

    def test_default_environment_has_main_only_and_no_reviewer(self):
        current, intended, calls = self.run_environment_plan(required_reviewer=False)
        self.assertEqual(current, {"exists": False})
        self.assertEqual(intended["reviewers"], [])
        self.assertEqual(intended["branches"], [{"name": "main", "type": "branch"}])
        self.assertFalse(any(path == "user" for path, _, _ in calls))
        applied = next(body for path, method, body in calls
                       if path == "repos/o/r/environments/apple-credentials" and method == "PUT")
        self.assertEqual(applied["reviewers"], [])

    def test_flag_adds_authenticated_reviewer_without_changing_main_rule(self):
        _, intended, calls = self.run_environment_plan(required_reviewer=True)
        self.assertEqual(intended["reviewers"], [{"type": "User", "login": "owner", "id": 7}])
        self.assertEqual(intended["branches"], [{"name": "main", "type": "branch"}])
        self.assertTrue(any(path == "user" for path, _, _ in calls))


if __name__ == "__main__":
    unittest.main()
