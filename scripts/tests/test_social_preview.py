import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("social_preview", SCRIPTS / "social-preview.py")
social_preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(social_preview)


def attachment(readable, exported):
    return {"suggestedHumanReadableName": readable, "exportedFileName": exported}


class SocialPreviewTests(unittest.TestCase):
    def attachments(self, root, entries):
        folder = Path(root) / "attachments"
        folder.mkdir()
        for entry in entries:
            (folder / entry["exportedFileName"]).write_bytes(b"png")
        (folder / "manifest.json").write_text(json.dumps([{"attachments": entries}]), encoding="utf-8")
        return folder

    def test_screens_come_back_in_the_order_asked_and_skip_missing_names(self):
        with tempfile.TemporaryDirectory() as root:
            folder = self.attachments(root, [
                attachment("settings-screen_0_43713AD4-B724-4FB5-9BEC-7810C0090161.png", "A.png"),
                attachment("onboarding-welcome_0_154805DE-3B01-4589-8EEF-2060140D7FB1.png", "B.png"),
                attachment("large-welcome-screen_0_1BEBB23B-7E66-4FC6-AEF9-ECB639D584D6.png", "C.png"),
            ])
            screens = social_preview.pick_screens(folder, ["onboarding-welcome", "welcome-screen", "settings-screen"])
        self.assertEqual([path.name for path in screens], ["B.png", "A.png"])

    def test_the_first_export_of_a_repeated_name_wins(self):
        with tempfile.TemporaryDirectory() as root:
            folder = self.attachments(root, [
                attachment("welcome-screen_0_1111.png", "first.png"),
                attachment("welcome-screen_0_2222.png", "second.png"),
            ])
            self.assertEqual(social_preview.pick_screens(folder, ["welcome-screen"])[0].name, "first.png")

    def test_the_default_title_is_the_home_screen_name(self):
        with tempfile.TemporaryDirectory() as root:
            manifest = Path(root) / "project.yml"
            manifest.write_text('settings:\n  base:\n    INFOPLIST_KEY_CFBundleDisplayName: "Pocket Notes"\n'
                                '    debug:\n      INFOPLIST_KEY_CFBundleDisplayName: $(DEV_DISPLAY_NAME)\n', encoding="utf-8")
            self.assertEqual(social_preview.display_name(manifest), "Pocket Notes")

    def test_the_template_title_is_read_from_this_repository(self):
        self.assertTrue(social_preview.display_name())

    def test_renderer_command_passes_only_what_was_given(self):
        command = social_preview.renderer_command("dark", Path("out.png"), Path("icon.png"), "My App", None, None,
                                                  ["Theme"], ["AI chat"], [Path("a.png")])
        self.assertEqual(command[:2], ["swift", str(social_preview.RENDERER)])
        self.assertNotIn("--tagline", command)
        self.assertNotIn("--url", command)
        for pair in (["--theme", "dark"], ["--chip", "Theme"], ["--planned", "AI chat"], ["--screen", "a.png"]):
            index = command.index(pair[0])
            self.assertEqual(command[index:index + 2], pair)

    def test_newest_attachments_ignores_runs_without_a_manifest(self):
        with tempfile.TemporaryDirectory() as root:
            results = Path(root)
            (results / "run.empty").mkdir()
            with_manifest = results / "run.full" / "attachments"
            with_manifest.mkdir(parents=True)
            (with_manifest / "manifest.json").write_text("[]", encoding="utf-8")
            self.assertEqual(social_preview.newest_attachments(results), with_manifest)
            self.assertIsNone(social_preview.newest_attachments(results / "missing"))


if __name__ == "__main__":
    unittest.main()
