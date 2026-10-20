import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_app_icon", SCRIPTS / "check-app-icon.py")
check_app_icon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_app_icon)


def document(groups=None, fills=None, platforms=None):
    if groups is None:
        groups = [{"name": "Radius", "layers": [{"name": "radius", "image-name": "radius.svg", "glass": True}]},
                  {"name": "Grid", "layers": [{"name": "grid", "image-name": "grid.svg"}]}]
    if fills is None:
        fills = [{"value": {"automatic-gradient": "extended-srgb:0.05,0.55,1.0,1.0"}},
                 {"appearance": "dark", "value": {"automatic-gradient": "extended-srgb:0.04,0.16,0.38,1.0"}}]
    return {"fill-specializations": fills, "groups": groups,
            "supported-platforms": {"squares": "shared"} if platforms is None else platforms}


class AppIconTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.icon = Path(self.temp.name) / "AppIcon.icon"
        (self.icon / "Assets").mkdir(parents=True)
        for name in ("radius.svg", "grid.svg"):
            (self.icon / "Assets" / name).write_text("<svg xmlns='http://www.w3.org/2000/svg'/>")
        self.write(document())

    def tearDown(self):
        self.temp.cleanup()

    def write(self, doc):
        (self.icon / "icon.json").write_text(json.dumps(doc, indent=2))

    def test_valid_document_is_described(self):
        record = check_app_icon.check_document(self.icon)
        self.assertEqual(record["groups"], 2)
        self.assertEqual([layer["image"] for layer in record["layers"]], ["radius.svg", "grid.svg"])
        self.assertTrue(record["layers"][0]["glass"])
        self.assertEqual(record["fillAppearances"], ["default", "dark"])

    def test_template_document_is_valid(self):
        record = check_app_icon.check_document(check_app_icon.DEFAULT_ICON)
        self.assertEqual({layer["image"] for layer in record["layers"]}, {"grid.svg", "construction.svg", "sweep.svg", "radius.svg"})
        self.assertIn("dark", record["fillAppearances"])

    def test_missing_layer_file_names_the_fix(self):
        self.write(document(groups=[{"name": "Radius", "layers": [{"name": "radius", "image-name": "missing.svg"}]},
                                    {"name": "Grid", "layers": [{"name": "grid", "image-name": "grid.svg"}]}]))
        (self.icon / "Assets" / "radius.svg").unlink()
        with self.assertRaisesRegex(check_app_icon.IconError, r"Assets/missing\.svg, which does not exist"):
            check_app_icon.check_document(self.icon)

    def test_unreferenced_asset_is_reported(self):
        (self.icon / "Assets" / "stray.svg").write_text("<svg/>")
        with self.assertRaisesRegex(check_app_icon.IconError, "no layer references .*stray.svg"):
            check_app_icon.check_document(self.icon)

    def test_missing_dark_fill_is_reported(self):
        self.write(document(fills=[{"value": {"automatic-gradient": "extended-srgb:0.05,0.55,1.0,1.0"}}]))
        with self.assertRaisesRegex(check_app_icon.IconError, '"appearance": "dark"'):
            check_app_icon.check_document(self.icon)

    def test_invalid_json_and_missing_groups_are_reported(self):
        (self.icon / "icon.json").write_text("{\"groups\": [}")
        with self.assertRaisesRegex(check_app_icon.IconError, "not valid JSON"):
            check_app_icon.check_document(self.icon)
        self.write({"fill-specializations": [], "supported-platforms": {}})
        with self.assertRaisesRegex(check_app_icon.IconError, '"groups"'):
            check_app_icon.check_document(self.icon)

    def test_render_exports_each_rendition_and_reports_failures(self):
        calls = []

        def fake_run(command, capture_output, text):
            calls.append(command)
            Path(command[command.index("--output-file") + 1]).write_bytes(b"png")
            return mock.Mock(returncode=0, stdout="", stderr="")

        output = Path(self.temp.name) / "out"
        with mock.patch.object(check_app_icon.subprocess, "run", fake_run):
            renders = check_app_icon.render(Path("/fake/ictool"), self.icon, output)
        self.assertEqual([r["rendition"] for r in renders], ["Default", "Dark", "TintedLight", "Default"])
        self.assertEqual([Path(r["file"]).name for r in renders], ["Default-1024.png", "Dark-1024.png", "TintedLight-1024.png", "Default-120.png"])
        self.assertTrue(all(Path(r["file"]).is_file() for r in renders))
        self.assertEqual(calls[0][:3], ["/fake/ictool", str(self.icon), "--export-image"])
        self.assertIn("--rendition", calls[1])

        def failing_run(command, capture_output, text):
            return mock.Mock(returncode=255, stdout="", stderr="The data couldn't be read because it isn't in the correct format.")

        with mock.patch.object(check_app_icon.subprocess, "run", failing_run):
            with self.assertRaisesRegex(check_app_icon.IconError, "could not render Default.*correct format"):
                check_app_icon.render(Path("/fake/ictool"), self.icon, output)

    def test_main_without_ictool_skips_render_unless_required(self):
        output = Path(self.temp.name) / "report"
        with mock.patch.object(check_app_icon, "find_ictool", return_value=None):
            self.assertEqual(check_app_icon.main([str(self.icon), "--output", str(output)]), 0)
            report = json.loads((output / "app-icon.json").read_text())
            self.assertIsNone(report["ictool"])
            self.assertIn("ictool not found", report["renderSkipped"])
            self.assertEqual(check_app_icon.main([str(self.icon), "--require-render"]), 1)

    def test_find_ictool_prefers_explicit_then_environment(self):
        fake = Path(self.temp.name) / "ictool"
        fake.write_text("#!/bin/sh\n")
        fake.chmod(0o755)
        self.assertEqual(check_app_icon.find_ictool(fake, environ={}), fake)
        self.assertEqual(check_app_icon.find_ictool(None, environ={"ICTOOL": str(fake)}), fake)
        with mock.patch.object(check_app_icon.platform, "system", return_value="Windows"), \
                mock.patch.object(check_app_icon.shutil, "which", return_value=None):
            self.assertIsNone(check_app_icon.find_ictool(None, environ={}))


if __name__ == "__main__":
    unittest.main()
