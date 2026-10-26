import contextlib
import importlib.util
import io
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
                                                  ["Theme"], ["chat|AI chat|soon"], [Path("a.png")])
        self.assertEqual(command[:2], ["swift", str(social_preview.RENDERER)])
        self.assertNotIn("--tagline", command)
        self.assertNotIn("--url", command)
        for pair in (["--theme", "dark"], ["--chip", "Theme"], ["--feature", "chat|AI chat|soon"], ["--screen", "a.png"]):
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

    def test_chips_show_only_without_features_preferring_flags_then_config_then_topics(self):
        topics = ["accessibility", "github-actions", "imessage", "ios"]
        self.assertEqual(social_preview.choose_chips(["Mine"], {"chips": ["Config"]}, topics), ["Mine"])
        self.assertEqual(social_preview.choose_chips(["Mine"], {"features": [{"label": "Modules"}]}, topics), [])
        self.assertEqual(social_preview.choose_chips([], {"chips": ["Config"]}, topics), ["Config"])
        self.assertEqual(social_preview.choose_chips([], {"chips": []}, topics), [])
        self.assertEqual(social_preview.choose_chips([], {}, topics), ["accessibility", "github-actions", "imessage"])
        self.assertEqual(social_preview.choose_chips([], {"chips": None}, topics), ["accessibility", "github-actions", "imessage"])

    def test_null_means_default_and_empty_means_off(self):
        default = lambda: "from GitHub"
        self.assertEqual(social_preview.setting({"tagline": None}, "tagline", default=default), "from GitHub")
        self.assertEqual(social_preview.setting({}, "tagline", default=default), "from GitHub")
        self.assertEqual(social_preview.setting({"tagline": ""}, "tagline", default=default), "")
        self.assertEqual(social_preview.setting({"tagline": "Mine"}, "tagline", default=default), "Mine")
        self.assertEqual(social_preview.setting({"tagline": "Mine"}, "tagline", "Flag", default), "Flag")

    def test_features_become_renderer_values_and_stop_at_four(self):
        features = [{"icon": "modules", "label": "Modules"}, {"icon": "chat", "label": "AI chat", "soon": True}] * 3
        self.assertEqual(social_preview.feature_flags(features)[:2], ["modules|Modules", "chat|AI chat|soon"])
        self.assertEqual(len(social_preview.feature_flags(features)), 4)

    def test_config_needs_a_label_per_feature_and_is_optional(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "social-preview.json"
            self.assertEqual(social_preview.load_config(path), {})
            path.write_text(json.dumps({"features": [{"icon": "chat"}]}), encoding="utf-8")
            with self.assertRaises(SystemExit):
                social_preview.load_config(path)

    def test_the_repository_config_is_valid(self):
        config = social_preview.load_config()
        self.assertLessEqual(len(config.get("features", [])), 4)
        for feature in config.get("features", []):
            self.assertIn(feature["icon"], social_preview.GLYPHS)


    def test_missing_screen_names_list_what_is_available(self):
        with tempfile.TemporaryDirectory() as root:
            folder = self.attachments(root, [attachment("theme-dark_0_ABCD.png", "D.png")])
            with contextlib.redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(social_preview.pick_screens(folder, ["nope", "theme-dark"])[0].name, "D.png")
        self.assertIn("No screenshot named nope. Available: theme-dark", errors.getvalue())


    def test_frame_paths_resolve_and_missing_frames_stop(self):
        self.assertIsNone(social_preview.frame_path(None))
        with self.assertRaises(SystemExit):
            social_preview.frame_path("build/no-such-frame.png")
        with tempfile.TemporaryDirectory() as root:
            frame = Path(root) / "bezel.png"
            frame.write_bytes(b"png")
            self.assertEqual(social_preview.frame_path(str(frame)), frame)
        command = social_preview.renderer_command("light", Path("o.png"), Path("i.png"), "App", None, None, [], [], [], Path("f.png"))
        self.assertEqual(command[-2:], ["--frame", "f.png"])
        fanned = social_preview.renderer_command("light", Path("o.png"), Path("i.png"), "App", None, None, [], [], [], Path("f.png"), "fan")
        self.assertEqual(fanned[-4:], ["--frame", "f.png", "--layout", "fan"])
        unframed = social_preview.renderer_command("light", Path("o.png"), Path("i.png"), "App", None, None, [], [], [], None, "fan")
        self.assertNotIn("--layout", unframed)


    def test_apple_frames_need_a_known_model_a_color_and_the_license(self):
        self.assertTrue(social_preview.apple_bezel_package("iPhone 17 Pro Max").endswith("Bezel-iPhone-17.dmg"))
        self.assertTrue(social_preview.apple_bezel_package("iPhone Air").endswith("Bezel-iPhone-17.dmg"))
        self.assertIsNone(social_preview.apple_bezel_package("Pixel 9"))
        with tempfile.TemporaryDirectory() as root:
            cache = Path(root)
            with self.assertRaises(SystemExit):
                social_preview.apple_frame("iPhone 17 Pro", accepted=True, cache=cache)  # no colour
            with self.assertRaises(SystemExit) as stopped:
                social_preview.apple_frame("iPhone 17 Pro - Silver", accepted=False, cache=cache)
            self.assertIn("apple_design_resources_license", str(stopped.exception))
            cached = cache / "iPhone 17 Pro - Silver - Portrait.png"
            cached.write_bytes(b"png")
            self.assertEqual(social_preview.apple_frame("iPhone 17 Pro - Silver", accepted=False, cache=cache), cached)


    def test_a_fitting_card_removes_a_stale_jpeg(self):
        with tempfile.TemporaryDirectory() as root:
            card = Path(root) / "social-preview-light.png"
            card.write_bytes(b"x" * 10)
            stale = card.with_suffix(".jpg")
            stale.write_bytes(b"old")
            self.assertEqual(social_preview.fit_upload_limit(card), card)
            self.assertFalse(stale.exists())


if __name__ == "__main__":
    unittest.main()
