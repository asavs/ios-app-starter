import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "setup.py"


class SetupCommandTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.state = Path(self.temporary.name) / "state.json"

    def tearDown(self):
        self.temporary.cleanup()

    def run_setup(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--state", str(self.state), *args],
            capture_output=True, text=True, check=False,
        )

    def test_state_is_created_and_status_reports_first_stage(self):
        result = self.run_setup("--status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("A. Repository setup: next", result.stdout)
        self.assertFalse(self.state.exists())

    def test_completion_requires_grant_and_is_sequential(self):
        denied = self.run_setup("--complete", "A")
        self.assertEqual(denied.returncode, 1)
        self.assertIn("requires an explicit github-settings grant", denied.stderr)

        granted = self.run_setup("--grant", "github-settings")
        self.assertEqual(granted.returncode, 0, granted.stderr)
        complete = self.run_setup("--complete", "A")
        self.assertEqual(complete.returncode, 0, complete.stderr)
        leap = self.run_setup("--complete", "C")
        self.assertEqual(leap.returncode, 1)
        self.assertIn("Only the next stage", leap.stderr)

    def test_checkpoint_contains_no_credential_fields(self):
        self.assertEqual(self.run_setup("--grant", "apple-read").returncode, 0)
        state = json.loads(self.state.read_text(encoding="utf-8"))
        self.assertEqual(state, {"schema": 1, "consent": {"apple-read": True}, "completed": []})

    def test_invalid_checkpoint_stops_without_overwriting(self):
        self.state.write_text('{"schema": 1, "consent": {"password": "do-not-store"}, "completed": []}', encoding="utf-8")
        original = self.state.read_bytes()
        result = self.run_setup("--status")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Setup state is invalid", result.stderr)
        self.assertEqual(self.state.read_bytes(), original)

    def test_interactive_flow_saves_declines_and_pauses_before_stage(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--state", str(self.state)],
            input="n\n" * 6,
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Stage A (Repository setup) is paused", result.stdout)
        state = json.loads(self.state.read_text(encoding="utf-8"))
        self.assertFalse(state["consent"]["github-settings"])
        self.assertEqual(state["completed"], [])


if __name__ == "__main__":
    unittest.main()
