import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_ui_identifiers = load("check-ui-identifiers")

CONTRACT = '''import Foundation

/// The app's identifiers.
enum Identifiers {
    enum Timer {
        static let ring = "timer.ring"
        /// A row: `timer.presets.row.<name>`.
        static func row(_ name: String) -> String { "timer.presets.row.\\(name)" }
    }
}

enum ModuleIdentifiers {
    enum Settings {
        static let appearance = "settings.appearance"
        static func field(_ key: String) -> String { "settings.secure.\\(key).field" }
    }
}
'''


def write(root, relative, text):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def layout(root, app="", test="", module=""):
    write(root, "StarterApp/Shared/UITesting/Identifiers.swift", CONTRACT)
    write(root, "StarterApp/StarterApp/View.swift",
          app or 'Text("x").accessibilityIdentifier(Identifiers.Timer.ring)\nlet r = Identifiers.Timer.row("a")\n')
    write(root, "StarterApp/StarterAppUITests/T.swift",
          test or 'app.buttons[ModuleIdentifiers.Settings.appearance]\napp.secureTextFields[ModuleIdentifiers.Settings.field("k")]\n'
                  'XCTAssert(app.staticTexts["Hello, world!"].exists) // "timer.ring" in a comment is fine\n')
    write(root, "Modules/Settings/Sources/SettingsView.swift",
          module or '.accessibilityIdentifier("settings.appearance")\n.accessibilityIdentifier("settings.secure.\\(key).field")\n')
    write(root, "Modules/Settings/Tests/SettingsTests.swift", '#expect("settings.unrelated" == "settings.unrelated")\n')


class ContractTests(unittest.TestCase):
    def test_constants_are_qualified_by_enum_nesting(self):
        found = dict(check_ui_identifiers.constants(CONTRACT))
        self.assertEqual(found["Identifiers.Timer.ring"], "timer.ring")
        self.assertEqual(found["Identifiers.Timer.row"], "timer.presets.row.\\(name)")
        self.assertEqual(found["ModuleIdentifiers.Settings.field"], "settings.secure.\\(key).field")

    def test_consistent_tree_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layout(root)
            self.assertEqual(check_ui_identifiers.check(root), [])

    def test_literal_in_app_view_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layout(root, app='Text("x").accessibilityIdentifier("timer.ring")\nlet r = Identifiers.Timer.row("a")\nIdentifiers.Timer.ring\n')
            problems = check_ui_identifiers.check(root)
            self.assertEqual(len(problems), 1)
            self.assertIn("View.swift:1: identifier literal", problems[0])

    def test_dotted_literal_in_test_fails_but_labels_and_arguments_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layout(root, test='app.buttons["settings.appearance"]\napp.buttons[ModuleIdentifiers.Settings.appearance]\n'
                              'ModuleIdentifiers.Settings.field("k")\n'
                              'let extra = ["-timer.intervals", "20,10,3", "Hello, world!", "www.example.com/plan", "Modules 0.3.1"]\n')
            problems = check_ui_identifiers.check(root)
            self.assertEqual(len(problems), 1)
            self.assertIn('T.swift:1: identifier literal "settings.appearance"', problems[0])

    def test_unused_app_constant_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layout(root, app='Text("x").accessibilityIdentifier(Identifiers.Timer.ring)\n')
            problems = check_ui_identifiers.check(root)
            self.assertEqual(len(problems), 1)
            self.assertIn("Identifiers.Timer.row is used nowhere", problems[0])

    def test_renamed_module_identifier_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layout(root, module='.accessibilityIdentifier("settings.appearancePicker")\n.accessibilityIdentifier("settings.secure.\\(key).field")\n')
            problems = check_ui_identifiers.check(root)
            self.assertEqual(len(problems), 1)
            self.assertIn('ModuleIdentifiers.Settings.appearance = "settings.appearance" matches no module source', problems[0])

    def test_missing_contract_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(check_ui_identifiers.check(Path(directory)), ["StarterApp/Shared/UITesting/Identifiers.swift is missing"])


if __name__ == "__main__":
    unittest.main()
