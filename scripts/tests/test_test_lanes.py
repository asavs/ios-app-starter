import re
from pathlib import Path
import unittest

REPO = Path(__file__).resolve().parents[2]
LANES = ('shell', 'features', 'tabs')


class TestLanesTests(unittest.TestCase):
    """Every UI test class runs in one of the CI lanes `scripts/test-ios.sh` lists. A class left out of
    them all builds, and passes locally, but CI never runs it (HomeUITests, 2026-11-14)."""

    def lane_classes(self):
        script = (REPO / 'scripts' / 'test-ios.sh').read_text()
        classes = {}
        for lane in LANES:
            block = re.search(rf'^\s*{lane}\)\n(.*?);;', script, re.MULTILINE | re.DOTALL)
            self.assertIsNotNone(block, f'test-ios.sh has no {lane} lane')
            classes[lane] = set(re.findall(r'-only-testing:StarterAppUITests/(\w+)', block.group(1)))
        return classes

    def test_every_ui_test_class_is_in_a_lane(self):
        sources = (REPO / 'StarterApp' / 'StarterAppUITests').glob('*.swift')
        defined = {name for path in sources
                   for name in re.findall(r'^(?:final )?class (\w+)\s*:\s*StarterUITestCase', path.read_text(), re.MULTILINE)}
        self.assertTrue(defined, 'found no UI test classes')
        laned = set().union(*self.lane_classes().values())
        self.assertEqual(defined - laned, set(), 'add these classes to a lane in scripts/test-ios.sh (the shortest one)')

    def test_no_class_runs_in_two_lanes(self):
        lanes = self.lane_classes()
        for i, first in enumerate(LANES):
            for second in LANES[i + 1:]:
                self.assertEqual(lanes[first] & lanes[second], set(), f'{first} and {second} share classes')


if __name__ == '__main__':
    unittest.main()
