import importlib.util
import colorsys
import io
import json
from pathlib import Path
import random
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


personalize_icon = load("personalize_icon", "personalize-icon.py")
check_app_icon = load("check_app_icon", "check-app-icon.py")


class PersonalizeIconTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.icon = Path(self.temp.name) / "AppIcon.icon"
        shutil.copytree(personalize_icon.DEFAULT_ICON, self.icon)

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, *args):
        with redirect_stdout(io.StringIO()) as out:
            status = personalize_icon.main(["--icon", str(self.icon), *args])
        return status, out.getvalue()

    def document(self):
        return json.loads((self.icon / "icon.json").read_text())

    def test_template_document_is_personalized_and_still_valid(self):
        before = self.document()
        status, out = self.run_script("--seed", "7")
        self.assertEqual(status, 0)
        self.assertIn("seed 7", out)
        after = self.document()
        discs = after["groups"][:3]
        self.assertEqual({group["layers"][0]["image-name"] for group in discs}, set(personalize_icon.BAKED_CENTRES))
        self.assertEqual(after["groups"][3:], before["groups"][3:])  # the grid group stays at the back, untouched
        for group in discs:
            fills = {entry.get("appearance", "default"): entry["value"] for entry in group["layers"][0]["fill-specializations"]}
            self.assertIn("solid", fills["default"])
            self.assertIn("solid", fills["dark"])
            self.assertIn("tinted", fills)  # Apple's grey tinted variants are kept
            self.assertIn("translation-in-points", group["position"])
        check_app_icon.check_document(self.icon)

    def test_same_seed_repeats_and_assets_are_untouched(self):
        assets = {path.name: path.read_bytes() for path in (self.icon / "Assets").iterdir()}
        self.run_script("--seed", "42")
        first = self.document()
        shutil.rmtree(self.icon)
        shutil.copytree(personalize_icon.DEFAULT_ICON, self.icon)
        self.run_script("--seed", "42")
        self.assertEqual(self.document(), first)
        self.assertEqual({path.name: path.read_bytes() for path in (self.icon / "Assets").iterdir()}, assets)

    def test_discs_stay_on_a_guide_line_inside_the_outer_circle(self):
        for seed in range(50):
            centres = personalize_icon.arrangement(random.Random(seed))
            middle = centres[1]
            self.assertEqual(middle, (512, 512))
            for x, y in (centres[0], centres[2]):
                distance = ((x - 512) ** 2 + (y - 512) ** 2) ** 0.5
                self.assertAlmostEqual(distance, personalize_icon.SPACING, delta=1)
                self.assertLessEqual(distance + 256, 411)  # disc radius plus offset stays within the grid's 410 circle

    def test_colours_are_distinct_hues(self):
        for seed in range(50):
            hues = sorted(colorsys.rgb_to_hls(*light)[0] for light, _ in personalize_icon.palette(random.Random(seed)))
            gaps = [hues[1] - hues[0], hues[2] - hues[1], 1 - hues[2] + hues[0]]
            self.assertGreater(min(gaps), 0.2)

    def test_replaced_icon_is_refused(self):
        document = self.document()
        document["groups"] = document["groups"][3:]
        (self.icon / "icon.json").write_text(json.dumps(document))
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()) as err:
            status = personalize_icon.main(["--icon", str(self.icon)])
        self.assertEqual(status, 1)
        self.assertIn("three disc groups", err.getvalue())


if __name__ == "__main__":
    unittest.main()
