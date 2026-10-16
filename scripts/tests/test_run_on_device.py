import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import device_selection
from device_selection import (SelectionError, bundle_identifier, development_team,
                              manifest_for, select_device)

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/run-on-device.sh"


def device(identifier, name, *, tunnel="connected", pairing="paired", device_type="iPhone",
           platform="iOS", reality="physical", transport="wired", model="iPhone 14 Pro", os="26.3"):
    """One record in the shape of `devicectl list devices --json-output` (jsonVersion 3)."""
    return {
        "identifier": identifier,
        "connectionProperties": {"pairingState": pairing, "tunnelState": tunnel,
                                 "transportType": transport},
        "deviceProperties": {"name": name, "osVersionNumber": os, "developerModeStatus": "enabled"},
        "hardwareProperties": {"deviceType": device_type, "platform": platform, "reality": reality,
                               "marketingName": model, "udid": f"00008120-{identifier[:8]}"},
    }


def payload(*devices, outcome="success"):
    return {"info": {"commandType": "devicectl.list.devices", "jsonVersion": 3, "outcome": outcome},
            "result": {"devices": list(devices)}}


PHONE = device("9BC454C7-0000-0000-0000-000000000001", "Work iPhone")
OFFLINE = device("DDF3FE73-0000-0000-0000-000000000002", "Old iPhone", tunnel="unavailable",
                 model="iPhone 12", os="18.6.2", transport="")
WIFI_PAD = device("1A2B3C4D-0000-0000-0000-000000000003", "Studio iPad", tunnel="disconnected",
                  device_type="iPad", transport="localNetwork", model="iPad Pro 11-inch")
MAC = device("5E6F7A8B-0000-0000-0000-000000000004", "Mac Studio", device_type="Mac", platform="macOS")
SIMULATOR = device("ABCDEF01-0000-0000-0000-000000000005", "iPhone 17", reality="virtual")
UNPAIRED = device("ABCDEF02-0000-0000-0000-000000000006", "Guest iPhone", pairing="unpaired")


class DeviceSelectionTests(unittest.TestCase):
    def test_single_connected_phone_is_chosen_over_offline_and_non_ios_entries(self):
        chosen = select_device(payload(OFFLINE, MAC, SIMULATOR, UNPAIRED, PHONE))
        self.assertEqual(chosen["identifier"], PHONE["identifier"])
        self.assertEqual(chosen["udid"], PHONE["hardwareProperties"]["udid"])
        self.assertEqual(chosen["name"], "Work iPhone")
        self.assertEqual(chosen["model"], "iPhone 14 Pro")
        self.assertEqual(chosen["os"], "26.3")
        self.assertEqual(chosen["transport"], "wired")

    def test_wifi_device_with_disconnected_tunnel_counts_as_available(self):
        self.assertEqual(select_device(payload(WIFI_PAD))["identifier"], WIFI_PAD["identifier"])

    def test_no_device_explains_usb_wifi_developer_mode_and_trust(self):
        with self.assertRaises(SelectionError) as raised:
            select_device(payload(OFFLINE, MAC))
        message = str(raised.exception)
        for phrase in ("USB", "Wi-Fi", "Developer Mode", "Trust"):
            self.assertIn(phrase, message)

    def test_several_devices_require_ios_device(self):
        with self.assertRaises(SelectionError) as raised:
            select_device(payload(PHONE, WIFI_PAD))
        self.assertIn("IOS_DEVICE", str(raised.exception))
        self.assertIn("Work iPhone", str(raised.exception))
        self.assertIn("Studio iPad", str(raised.exception))

    def test_ios_device_matches_name_identifier_or_udid(self):
        many = payload(PHONE, WIFI_PAD)
        self.assertEqual(select_device(many, "Studio iPad")["identifier"], WIFI_PAD["identifier"])
        self.assertEqual(select_device(many, PHONE["identifier"])["name"], "Work iPhone")
        self.assertEqual(select_device(many, PHONE["hardwareProperties"]["udid"])["name"], "Work iPhone")

    def test_ios_device_naming_an_offline_phone_says_so(self):
        with self.assertRaises(SelectionError) as raised:
            select_device(payload(PHONE, OFFLINE), "Old iPhone")
        self.assertIn("not a connected, paired", str(raised.exception))

    def test_ios_device_with_no_match_lists_candidates(self):
        with self.assertRaises(SelectionError) as raised:
            select_device(payload(PHONE), "Nope")
        self.assertIn("Work iPhone", str(raised.exception))

    def test_duplicate_names_demand_identifier(self):
        twin = dict(PHONE, identifier="9BC454C7-0000-0000-0000-000000000009")
        with self.assertRaises(SelectionError) as raised:
            select_device(payload(PHONE, twin), "Work iPhone")
        self.assertIn("identifier", str(raised.exception))

    def test_failed_devicectl_outcome_is_an_error(self):
        with self.assertRaises(SelectionError):
            select_device(payload(PHONE, outcome="failed"))


class ManifestAndTeamTests(unittest.TestCase):
    def test_configuration_maps_like_the_workflows(self):
        self.assertEqual(manifest_for("starter"), str(ROOT / "project.yml"))
        self.assertEqual(manifest_for("pocket-notes"), str(ROOT / "examples/pocket-notes.yml"))
        self.assertEqual(manifest_for("starter-app-demo"), str(ROOT / "examples/starter-app-demo.yml"))
        self.assertEqual(manifest_for(), str(ROOT / "project.yml"))
        self.assertEqual(manifest_for(spec="/tmp/custom.yml"), "/tmp/custom.yml")
        for name in device_selection.MANIFESTS.values():
            self.assertTrue((ROOT / name).is_file(), name)

    def test_unknown_or_conflicting_selection_fails(self):
        with self.assertRaises(SelectionError):
            manifest_for("release")
        with self.assertRaises(SelectionError):
            manifest_for("starter", spec=str(ROOT / "examples/pocket-notes.yml"))
        self.assertEqual(manifest_for("starter", spec=str(ROOT / "project.yml")), str(ROOT / "project.yml"))

    def test_team_prefers_environment_then_project_settings(self):
        settings = [{"target": "StarterAppTests", "buildSettings": {"DEVELOPMENT_TEAM": "ZZZZZZZZZZ"}},
                    {"target": "StarterApp", "buildSettings": {"DEVELOPMENT_TEAM": "ABCDE12345"}}]
        self.assertEqual(development_team("QWERTY1234", settings), ("QWERTY1234", "IOS_DEVELOPMENT_TEAM"))
        self.assertEqual(development_team("", settings)[0], "ABCDE12345")
        self.assertEqual(development_team(None, [{"target": "StarterApp", "buildSettings": {}}]), (None, None))
        self.assertEqual(development_team(None, None), (None, None))
        with self.assertRaises(SelectionError):
            development_team("not-a-team", None)
        with self.assertRaises(SelectionError):
            development_team("", [{"target": "StarterApp", "buildSettings": {"DEVELOPMENT_TEAM": "short"}}])


class BundleIdentifierTests(unittest.TestCase):
    def test_reads_binary_info_plist(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "StarterApp.app"
            app.mkdir()
            with (app / "Info.plist").open("wb") as stream:
                plistlib.dump({"CFBundleIdentifier": "com.example.StarterApp"}, stream, fmt=plistlib.FMT_BINARY)
            self.assertEqual(bundle_identifier(app), "com.example.StarterApp")

    def test_missing_or_invalid_identifier_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "StarterApp.app"
            app.mkdir()
            with self.assertRaises(SelectionError):
                bundle_identifier(app)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "no dots"}))
            with self.assertRaises(SelectionError):
                bundle_identifier(app)


@unittest.skipUnless(shutil.which("bash"), "bash required")
class DryRunScriptTests(unittest.TestCase):
    """Drive the shell script against a saved device list without xcrun, a device, or a team account."""

    def run_script(self, devices, **env_overrides):
        directory = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, directory)
        devices_json = Path(directory) / "devices.json"
        devices_json.write_text(json.dumps(devices), encoding="utf-8")
        env = {key: value for key, value in os.environ.items()
               if not key.startswith("IOS_")}
        env.update({"IOS_RUN_ON_DEVICE_DRY_RUN": "1", "IOS_DEVICE_LIST_JSON": str(devices_json),
                    "IOS_RUN_ON_DEVICE_OUTPUT_DIR": str(Path(directory) / "out"),
                    "IOS_DEVELOPMENT_TEAM": "ABCDE12345"})
        env.update(env_overrides)
        return subprocess.run(["bash", str(SCRIPT)], env=env, text=True, capture_output=True)

    def test_syntax(self):
        self.assertEqual(subprocess.run(["bash", "-n", str(SCRIPT)], capture_output=True).returncode, 0)

    def test_dry_run_previews_every_step_in_order(self):
        result = self.run_script(payload(PHONE))
        self.assertEqual(result.returncode, 0, result.stderr)
        out = result.stdout
        generate = out.index("scripts/generate-project.sh")
        build = out.index("xcodebuild")
        install = out.index("devicectl device install app")
        launch = out.index("devicectl device process launch")
        self.assertLess(generate, build)
        self.assertLess(build, install)
        self.assertLess(install, launch)
        self.assertIn(f"-destination id={PHONE['hardwareProperties']['udid']}", out)
        self.assertIn(f"--device {PHONE['identifier']}", out)
        self.assertIn("-allowProvisioningUpdates", out)
        self.assertNotIn("-allowProvisioningDeviceRegistration", out)
        self.assertIn("CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=ABCDE12345 build", out)
        self.assertIn("--terminate-existing", out)
        self.assertNotIn("--console", out)
        self.assertIn("run-on-device summary", out)
        self.assertIn("relaunch without rebuilding", out)
        self.assertIn("Work iPhone", out)
        self.assertIn("project.yml", out)
        # Without a console the summary follows the launch command.
        self.assertLess(launch, out.index("run-on-device summary"))

    def test_dry_run_console_and_registration_flags(self):
        result = self.run_script(payload(PHONE), IOS_DEVICE_CONSOLE="1", IOS_REGISTER_DEVICE="1",
                                 IOS_CONFIGURATION="starter-app-demo")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--console", result.stdout)
        self.assertIn("-allowProvisioningDeviceRegistration", result.stdout)
        self.assertIn("examples/starter-app-demo.yml", result.stdout)
        # Options precede the bundle identifier so devicectl does not hand them to the app.
        launch_line = next(line for line in result.stdout.splitlines()
                           if line.startswith("+") and "process launch" in line)
        self.assertLess(launch_line.index("--console"), launch_line.index("CFBundleIdentifier"))
        self.assertLess(launch_line.index("--json-output"), launch_line.index("CFBundleIdentifier"))
        # With a console attached the summary is shown before the blocking launch.
        self.assertLess(result.stdout.index("run-on-device summary"), result.stdout.index("process launch"))

    def test_dry_run_fails_clearly_without_a_device(self):
        result = self.run_script(payload(OFFLINE, MAC))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Developer Mode", result.stderr)
        self.assertNotIn("xcodebuild", result.stdout)

    def test_dry_run_requires_ios_device_for_several_phones(self):
        result = self.run_script(payload(PHONE, WIFI_PAD))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("IOS_DEVICE", result.stderr)
        chosen = self.run_script(payload(PHONE, WIFI_PAD), IOS_DEVICE="Studio iPad")
        self.assertEqual(chosen.returncode, 0, chosen.stderr)
        self.assertIn(f"--device {WIFI_PAD['identifier']}", chosen.stdout)

    def test_invalid_team_or_configuration_fails_before_any_command(self):
        bad_team = self.run_script(payload(PHONE), IOS_DEVELOPMENT_TEAM="nope")
        self.assertNotEqual(bad_team.returncode, 0)
        self.assertIn("Apple Team ID", bad_team.stderr)
        bad_config = self.run_script(payload(PHONE), IOS_CONFIGURATION="release")
        self.assertNotEqual(bad_config.returncode, 0)
        self.assertIn("Unsupported IOS_CONFIGURATION", bad_config.stderr)
        self.assertNotIn("+", bad_config.stdout)


if __name__ == "__main__":
    unittest.main()
