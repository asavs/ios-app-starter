import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_module_strings", SCRIPTS / "check-module-strings.py")
check_module_strings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_module_strings)

SOURCE = '''
Text("Choose one", bundle: .module)
let status = String(localized: "Could not save: \\(String(describing: error))", bundle: .module)
static let skip = LocalizedStringResource("Skip", bundle: .module)
Text("Not looked up")  // App text: no bundle argument.
Text(verbatim: "Never translated")
'''


class ModuleStringsTests(unittest.TestCase):
    def module(self, root, source=SOURCE, catalog=None):
        module = Path(root) / 'Demo'
        (module / 'Sources' / 'Resources').mkdir(parents=True)
        (module / 'Sources' / 'Demo.swift').write_text(source)
        if catalog is not None:
            (module / 'Sources' / 'Resources' / 'Localizable.xcstrings').write_text(json.dumps(
                {'sourceLanguage': 'en', 'strings': catalog, 'version': '1.0'}))
        return module

    def test_keys_are_literals_followed_by_the_module_bundle(self):
        with tempfile.TemporaryDirectory() as root:
            keys = check_module_strings.used_keys(self.module(root) / 'Sources')
        self.assertEqual(keys, {'Choose one', 'Could not save: %@', 'Skip'})

    def test_missing_and_unused_keys_are_reported(self):
        with tempfile.TemporaryDirectory() as root:
            problems = check_module_strings.check(self.module(root, catalog={'Skip': {}, 'Stale': {}}))
        self.assertEqual(len(problems), 3)
        self.assertTrue(any("'Choose one' is looked up but missing" in problem for problem in problems))
        self.assertTrue(any("'Stale' is in the catalog but no source looks it up" in problem for problem in problems))

    def test_update_adds_english_values_and_keeps_translations(self):
        german = {'localizations': {'de': {'stringUnit': {'state': 'translated', 'value': 'Überspringen'}}}}
        with tempfile.TemporaryDirectory() as root:
            module = self.module(root, catalog={'Skip': german, 'Stale': {}})
            self.assertEqual(check_module_strings.check(module, update=True), [])
            self.assertEqual(check_module_strings.check(module), [])
            strings = json.loads((module / 'Sources/Resources/Localizable.xcstrings').read_text())['strings']
        self.assertEqual(sorted(strings), ['Choose one', 'Could not save: %@', 'Skip'])
        self.assertEqual(strings['Skip'], german)
        self.assertEqual(strings['Choose one']['localizations']['en']['stringUnit']['value'], 'Choose one')

    def test_repository_catalogs_match_their_sources(self):
        self.assertEqual(check_module_strings.main([]), 0)


if __name__ == '__main__':
    unittest.main()
