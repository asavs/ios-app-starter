import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "sync-skills.py"
SPEC = importlib.util.spec_from_file_location("sync_skills", SCRIPT)
sync_skills = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync_skills)


class SyncSkillsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.locations = (self.root / ".agents" / "skills", self.root / ".claude" / "skills")
        for location in self.locations:
            location.mkdir(parents=True)
        self.lock = self.root / "skills.lock"

    def tearDown(self):
        self.temp.cleanup()

    def test_verify_accepts_matching_copies_and_names_drift(self):
        skills = []
        for location in self.locations:
            folder = location / "sample"
            folder.mkdir()
            (folder / "SKILL.md").write_text("sample skill\n", encoding="utf-8")
        digest = sync_skills.content_hash(self.locations[0] / "sample")
        data = {"version": 1, "skills": [{"name": "sample", "commit": "a" * 40, "content_sha256": digest}]}
        with patch.multiple(sync_skills, ROOT=self.root, LOCK=self.lock, LOCATIONS=self.locations):
            self.assertEqual(sync_skills.verify(data), 0)
            (self.locations[1] / "sample" / "SKILL.md").write_text("drift\n", encoding="utf-8")
            self.assertEqual(sync_skills.verify(data), 1)

    def test_update_uses_local_git_fixture_without_network(self):
        source = self.root / "fixture"
        source.mkdir()
        subprocess.run(["git", "init", "--initial-branch=main"], cwd=source, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Skill Fixture"], cwd=source, check=True)
        subprocess.run(["git", "config", "user.email", "fixture@example.invalid"], cwd=source, check=True)
        (source / "LICENSE").write_text("MIT fixture license\n", encoding="utf-8")
        skill_folder = source / "skills" / "sample"
        skill_folder.mkdir(parents=True)
        (skill_folder / "SKILL.md").write_text("local fixture\n", encoding="utf-8")
        (source / "shared" / "refs").mkdir(parents=True)
        (source / "shared" / "refs" / "guide.md").write_text("linked reference\n", encoding="utf-8")
        (skill_folder / "references").write_text("../../shared/refs", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=source, check=True)
        link_blob = subprocess.run(["git", "hash-object", "-w", "--stdin"], cwd=source,
                                   input=b"../../shared/refs", check=True, capture_output=True).stdout.decode().strip()
        subprocess.run(["git", "update-index", "--add", "--cacheinfo", f"120000,{link_blob},skills/sample/references"],
                       cwd=source, check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "fixture"], cwd=source, check=True, capture_output=True)
        data = {
            "version": 1,
            "skills": [{"name": "sample", "repository": "fixture/repository", "url": str(source),
                        "path": "skills/sample", "commit": "", "content_sha256": ""}],
        }
        with patch.multiple(sync_skills, ROOT=self.root, LOCK=self.lock, LOCATIONS=self.locations):
            self.lock.write_text(json.dumps(data), encoding="utf-8")
            self.assertEqual(sync_skills.update(data, "sample"), 0)
            stored = json.loads(self.lock.read_text(encoding="utf-8"))
            self.assertEqual(len(stored["skills"][0]["commit"]), 40)
            for location in self.locations:
                folder = location / "sample"
                self.assertEqual((folder / "SKILL.md").read_text(encoding="utf-8"), "local fixture\n")
                self.assertTrue((folder / "LICENSE").is_file())
                self.assertEqual((folder / "references" / "guide.md").read_text(encoding="utf-8"), "linked reference\n")
                self.assertFalse(any(path.is_symlink() for path in folder.rglob("*")))
            self.assertEqual(sync_skills.verify(stored), 0)


    def test_update_accepts_a_skill_at_the_repository_root(self):
        source = self.root / "root-fixture"
        source.mkdir()
        subprocess.run(["git", "init", "--initial-branch=main"], cwd=source, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Skill Fixture"], cwd=source, check=True)
        subprocess.run(["git", "config", "user.email", "fixture@example.invalid"], cwd=source, check=True)
        (source / "LICENSE").write_text("MIT fixture license\n", encoding="utf-8")
        (source / "SKILL.md").write_text("root fixture\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=source, check=True)
        subprocess.run(["git", "commit", "-m", "fixture"], cwd=source, check=True, capture_output=True)
        data = {
            "version": 1,
            "skills": [{"name": "rooted", "repository": "fixture/rooted", "url": str(source),
                        "path": ".", "commit": "", "content_sha256": ""}],
        }
        with patch.multiple(sync_skills, ROOT=self.root, LOCK=self.lock, LOCATIONS=self.locations):
            self.lock.write_text(json.dumps(data), encoding="utf-8")
            self.assertEqual(sync_skills.update(data, "rooted"), 0)
            for location in self.locations:
                self.assertEqual((location / "rooted" / "SKILL.md").read_text(encoding="utf-8"), "root fixture\n")
            self.assertEqual(sync_skills.verify(json.loads(self.lock.read_text(encoding="utf-8"))), 0)


if __name__ == "__main__":
    unittest.main()
