import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_modules = load("check-modules")
tag_modules = load("tag-modules")


def manifest(*names):
    return {"name": "StarterModules", "platforms": [{"platformName": "ios", "version": "17.0"}],
            "products": [{"name": n, "type": {"library": ["automatic"]}, "targets": [n]} for n in names],
            "targets": [t for n in names for t in (
                {"name": n, "type": "regular", "path": f"Modules/{n}/Sources"},
                {"name": f"{n}Tests", "type": "test", "path": f"Modules/{n}/Tests",
                 "dependencies": [{"byName": [n, None]}]})]}


def layout(root, *names):
    for n in names:
        (root / "Modules" / n / "Sources").mkdir(parents=True)
        (root / "Modules" / n / "Sources" / f"{n}.swift").write_text("public enum X {}\n")
        (root / "Modules" / n / "Tests").mkdir()
        (root / "Modules" / n / "Tests" / "T.swift").write_text("import Testing\n")


def project(relative_path="..", products=("Theme",), remote=False, minimum="17.0"):
    objects = {"P": {"isa": "PBXProject", "buildConfigurationList": "L"},
               "L": {"isa": "XCConfigurationList", "buildConfigurations": ["D", "R"]},
               "D": {"isa": "XCBuildConfiguration", "buildSettings": {"IPHONEOS_DEPLOYMENT_TARGET": minimum}},
               "R": {"isa": "XCBuildConfiguration", "buildSettings": {"IPHONEOS_DEPLOYMENT_TARGET": minimum}}}
    if relative_path is not None:
        objects["PKG"] = {"isa": "XCLocalSwiftPackageReference", "relativePath": relative_path}
    for index, name in enumerate(products):
        objects[f"DEP{index}"] = {"isa": "XCSwiftPackageProductDependency", "productName": name}
    if remote:
        objects["REM"] = {"isa": "XCRemoteSwiftPackageReference", "repositoryURL": "https://example.invalid/x"}
        objects["RDEP"] = {"isa": "XCSwiftPackageProductDependency", "productName": "Other", "package": "REM"}
    return objects


class ManifestLayoutTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="modules-")
        self.root = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)

    def test_valid_layout_lists_modules(self):
        layout(self.root, "Theme", "Settings")
        modules, platforms = check_modules.check_manifest(manifest("Theme", "Settings"), {"Theme", "Settings"}, self.root)
        self.assertEqual([m["name"] for m in modules], ["Settings", "Theme"])
        self.assertEqual(modules[0]["testTarget"], "SettingsTests")
        self.assertEqual(platforms, {"ios": "17.0"})

    def test_directory_without_product_is_rejected(self):
        layout(self.root, "Theme", "Extra")
        with self.assertRaisesRegex(ValueError, r"Modules/Extra: add \.library"):
            check_modules.check_manifest(manifest("Theme"), {"Theme", "Extra"}, self.root)

    def test_product_without_directory_is_rejected(self):
        layout(self.root, "Theme")
        with self.assertRaisesRegex(ValueError, "no Modules/Ghost directory"):
            check_modules.check_manifest(manifest("Theme", "Ghost"), {"Theme"}, self.root)

    def test_missing_test_target_is_rejected(self):
        layout(self.root, "Theme")
        broken = manifest("Theme")
        broken["targets"] = [t for t in broken["targets"] if t["type"] != "test"]
        with self.assertRaisesRegex(ValueError, "needs a test target ThemeTests"):
            check_modules.check_manifest(broken, {"Theme"}, self.root)

    def test_wrong_source_path_is_rejected(self):
        layout(self.root, "Theme")
        broken = manifest("Theme")
        broken["targets"][0]["path"] = "Sources/Theme"
        with self.assertRaisesRegex(ValueError, 'path: "Modules/Theme/Sources"'):
            check_modules.check_manifest(broken, {"Theme"}, self.root)

    def test_empty_sources_are_rejected(self):
        layout(self.root, "Theme")
        (self.root / "Modules/Theme/Sources/Theme.swift").unlink()
        with self.assertRaisesRegex(ValueError, "at least one Swift file"):
            check_modules.check_manifest(manifest("Theme"), {"Theme"}, self.root)

    def test_missing_ios_platform_is_rejected(self):
        layout(self.root, "Theme")
        broken = manifest("Theme")
        broken["platforms"] = []
        with self.assertRaisesRegex(ValueError, "platforms"):
            check_modules.check_manifest(broken, {"Theme"}, self.root)


class ProjectReferenceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="modules-")
        self.root = Path(self.directory.name).resolve()
        self.addCleanup(self.directory.cleanup)
        self.project_dir = self.root / "StarterApp"
        self.project_dir.mkdir()

    def test_enabled_products_are_listed(self):
        enabled, remote = check_modules.check_project(project(products=("Theme",)), {"Theme", "Settings"},
                                                      self.project_dir, self.root)
        self.assertEqual(enabled, ["Theme"])
        self.assertEqual(remote, [])

    def test_no_reference_means_nothing_enabled(self):
        enabled, remote = check_modules.check_project(project(None, products=()), {"Theme"}, self.project_dir, self.root)
        self.assertEqual((enabled, remote), ([], []))

    def test_reference_outside_repository_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "not this repository"):
            check_modules.check_project(project("../.."), {"Theme"}, self.project_dir, self.root)

    def test_unknown_product_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "'Ghost', which Package.swift does not define"):
            check_modules.check_project(project(products=("Ghost",)), {"Theme"}, self.project_dir, self.root)

    def test_remote_packages_are_reported_not_rejected(self):
        enabled, remote = check_modules.check_project(project(remote=True), {"Theme"}, self.project_dir, self.root)
        self.assertEqual(enabled, ["Theme"])
        self.assertEqual(remote, ["https://example.invalid/x", "Other"])

    def test_project_minimum_is_read(self):
        self.assertEqual(check_modules.project_minimum(project(minimum="18.0")), "18.0")


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], text=True, capture_output=True, check=True).stdout.strip()


class TagModulesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="modules-tag-")
        self.repo = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "test@example.invalid")
        git(self.repo, "config", "user.name", "Test")
        self.write("0.1.0")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "init")

    def write(self, version):
        path = self.repo / tag_modules.VERSION_FILE
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'public enum TemplateVersion {{\n    public static let modules = "{version}"\n}}\n')

    def test_tags_matching_version_without_pushing(self):
        self.assertEqual(tag_modules.tag(self.repo, "0.1.0"), "0.1.0")
        self.assertEqual(git(self.repo, "tag", "--list"), "0.1.0")
        self.assertEqual(git(self.repo, "tag", "-l", "-n1", "0.1.0").split(maxsplit=1)[1], "Module library 0.1.0")

    def test_rejects_version_mismatch_and_bad_format(self):
        with self.assertRaisesRegex(ValueError, "declares 0.1.0; set it to 0.2.0"):
            tag_modules.tag(self.repo, "0.2.0")
        with self.assertRaisesRegex(ValueError, "no 'v' prefix"):
            tag_modules.tag(self.repo, "v0.1.0")
        self.assertEqual(git(self.repo, "tag", "--list"), "")

    def test_rejects_dirty_tree_other_branch_and_existing_tag(self):
        self.write("0.1.0\n")
        with self.assertRaisesRegex(ValueError, "declares"):
            tag_modules.tag(self.repo, "0.1.0")
        self.write("0.1.0")
        (self.repo / "stray.txt").write_text("x")
        with self.assertRaisesRegex(ValueError, "not clean"):
            tag_modules.tag(self.repo, "0.1.0")
        (self.repo / "stray.txt").unlink()
        git(self.repo, "switch", "-q", "-c", "feature")
        with self.assertRaisesRegex(ValueError, "tag from main, not feature"):
            tag_modules.tag(self.repo, "0.1.0")
        self.assertEqual(tag_modules.tag(self.repo, "0.1.0", branch="feature"), "0.1.0")
        with self.assertRaisesRegex(ValueError, "already exists"):
            tag_modules.tag(self.repo, "0.1.0", branch="feature")

    def test_rejects_head_behind_origin(self):
        git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        (self.repo / "later.txt").write_text("x")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "later")
        with self.assertRaisesRegex(ValueError, "differs from origin/main"):
            tag_modules.tag(self.repo, "0.1.0")


if __name__ == "__main__":
    unittest.main()
