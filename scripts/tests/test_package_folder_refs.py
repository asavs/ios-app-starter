import importlib.util
from pathlib import Path
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("drop_package_folder_refs", SCRIPTS / "drop-package-folder-refs.py")
drop_package_folder_refs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drop_package_folder_refs)

FOLDER = ("\t\t129A8E94265460CFE54956DA /* checkout */ = {{isa = PBXFileReference; lastKnownFileType = folder; "
          "name = checkout; path = {path}; sourceTree = SOURCE_ROOT; }};\n")
SOURCE = ("\t\tBD60802B2CF34042A128A2F5 /* App.swift */ = {isa = PBXFileReference; "
          "lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = \"<group>\"; };\n")


def pbxproj(folder_path="../..", package_path=".."):
    return (
        "/* Begin PBXFileReference section */\n"
        + SOURCE
        + FOLDER.format(path=folder_path)
        + "/* End PBXFileReference section */\n"
        "/* Begin PBXGroup section */\n"
        "\t\t86E543BF154DCFCE66B61433 = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
        "\t\t\t\tC924432133D7BD8B0AC7ECB2 /* Packages */,\n"
        "\t\t\t\t28D9222601D1F6EC7EFB0606 /* Empty */,\n"
        "\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
        "\t\t28D9222601D1F6EC7EFB0606 /* Empty */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
        "\t\t\t);\n\t\t\tpath = Empty;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
        "\t\tC924432133D7BD8B0AC7ECB2 /* Packages */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
        "\t\t\t\t129A8E94265460CFE54956DA /* checkout */,\n"
        "\t\t\t);\n\t\t\tname = Packages;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
        "/* End PBXGroup section */\n"
        "\t\t892CE24144575EC8CBA29FFE /* XCLocalSwiftPackageReference \"..\" */ = {\n"
        f"\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = {package_path};\n\t\t}};\n"
    )


class PackageFolderReferenceTests(unittest.TestCase):
    def test_folder_above_the_package_is_removed_with_its_group(self):
        text, removed = drop_package_folder_refs.drop_folder_refs(pbxproj())
        self.assertEqual(removed, 1)
        self.assertNotIn("129A8E94265460CFE54956DA", text)
        self.assertNotIn("C924432133D7BD8B0AC7ECB2", text)
        self.assertIn("XCLocalSwiftPackageReference;", text)
        self.assertIn("App.swift", text)
        # An empty group the generator did not touch stays.
        self.assertIn("28D9222601D1F6EC7EFB0606 /* Empty */ = {", text)

    def test_folder_at_the_package_is_removed(self):
        _, removed = drop_package_folder_refs.drop_folder_refs(pbxproj(folder_path=".."))
        self.assertEqual(removed, 1)

    def test_unrelated_folder_is_kept(self):
        original = pbxproj(folder_path="Resources")
        text, removed = drop_package_folder_refs.drop_folder_refs(original)
        self.assertEqual((text, removed), (original, 0))

    def test_committed_project_has_no_package_folder(self):
        project = SCRIPTS.parent / "StarterApp" / "StarterApp.xcodeproj"
        text = (project / "project.pbxproj").read_text()
        _, removed = drop_package_folder_refs.drop_folder_refs(text, project.parent.as_posix())
        self.assertEqual(removed, 0)


if __name__ == "__main__":
    unittest.main()
