import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import shutil
import test_signing as signing
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('release', ROOT / 'scripts/testflight-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
CANARY = 'PRIVATE-RELEASE-CANARY'


def records():
    export = os.environ.get('IOS_SIGNING_CONFIGURATION_EXPORT')
    if export:
        return json.loads(Path(export).read_text())
    return [dict(configuration=c, bundleIdentifier='org.example.fixture', teamIdentifier='TESTTEAM01',
                 displayName='Fixture', minimumIOS='17.0', marketingVersion='1.0', buildNumber='1')
            for c in ('Debug', 'Release')]


class FakeReader:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.commands = []

    def read(self, command):
        self.commands.append(command)
        return next(self.responses)


def identity(app):
    return {'id': '12345', 'attributes': {'bundleId': app['bundleIdentifier']}}


class TestFlightTests(unittest.TestCase):
    def test_numbers_advance_across_reruns_remote_builds_and_component_boundaries(self):
        self.assertEqual(release.next_number(1, 1, ['1']), '1.0.1')
        self.assertEqual(release.next_number(1, 2, ['1.0.1']), '1.0.2')
        self.assertGreater(release.decode_number(release.next_number(2, 1, [])), release.decode_number('1.0.99'))
        self.assertEqual(release.next_number(1, 1, ['20.99.99'], base='20.99.99'), '21.0.0')
        self.assertEqual(release.next_number(1, 1, ['1.02.03'], base='1.2.3'), '1.2.4')
        with self.assertRaisesRegex(ValueError, 'BASE'): release.next_number(1, 1, ['500'])
        self.assertNotEqual(release.next_number(1, 1, [], base='500'), release.next_number(1, 2, [], base='500'))
        for value in ('0', '10000', '1.100.0', '1.0.100', '1.0beta', None):
            with self.subTest(value=value), self.assertRaises(ValueError): release.next_number(1, 1, [value])
        for args in ((0, 1, []), (1, 100, []), (999901, 1, []), (1, 1, ['9999.99.99'])):
            with self.subTest(args=args), self.assertRaises(ValueError): release.next_number(*args)

    def test_remote_inventory_requires_verified_reads_and_exact_existing_identity(self):
        app = records()[1]
        reader = FakeReader([('verified', [identity(app)]), ('verified', [{'attributes': {'version': '500'}}])])
        plan = release.plan(app, 1, 1, reader, base='500')
        self.assertEqual(plan['buildNumber'], '500.0.1')
        self.assertNotIn('12345', json.dumps(plan))
        self.assertEqual(reader.commands[1], ['builds', 'list', '--app', '12345', '--platform', 'IOS', '--processing-state', 'all'])
        cases = [[('inaccessible', None)], [('verified', [])], [('verified', [identity(app), identity(app)])],
                 [('verified', [dict(identity(app), attributes={'bundleId': 'org.other.app'})])],
                 [('verified', [identity(app)]), ('not_verified', None)],
                 [('verified', [identity(app)]), ('verified', [{'attributes': {}}])]]
        for responses in cases:
            with self.subTest(responses=responses), self.assertRaises(ValueError): release.plan(app, 1, 1, FakeReader(responses))

    def test_reviewed_export_options_keep_internal_testing_and_preserve_build_number(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'options.plist'
            release.prepare_options(records()[1], ROOT / 'config/ExportOptions-TestFlight.plist', output)
            options = plistlib.loads(output.read_bytes())
            self.assertEqual(options['destination'], 'export')
            self.assertIs(options['manageAppVersionAndBuildNumber'], False)
            self.assertIs(options['testFlightInternalTestingOnly'], True)
            self.assertEqual(options['teamID'], records()[1]['teamIdentifier'])
            for key, value in (('destination', 'upload'), ('manageAppVersionAndBuildNumber', True),
                               ('testFlightInternalTestingOnly', False), ('manageAppVersionAndBuildNumber', 0)):
                invalid = dict(options); invalid.pop('teamID'); invalid[key] = value
                template = Path(directory) / 'invalid.plist'; template.write_bytes(plistlib.dumps(invalid))
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    release.prepare_options(records()[1], template, output)

    def fixture(self, directory):
        base = Path(directory)
        config = base / 'configuration.json'; config.write_text(json.dumps(records()))
        app = release.configuration(config)
        delivery = release.plan(app, 1, 1)
        delivery['status'] = 'planned'
        plan = base / 'plan.json'; plan.write_text(json.dumps(delivery))
        archive = base / 'Fixture.xcarchive'
        product = archive / 'Products/Applications/StarterApp.app'; product.mkdir(parents=True)
        info = {'CFBundleIdentifier': app['bundleIdentifier'], 'CFBundleDisplayName': app['displayName'],
                'MinimumOSVersion': app['minimumIOS'], 'CFBundleShortVersionString': app['marketingVersion'],
                'CFBundleVersion': delivery['buildNumber'],
                'ITSAppUsesNonExemptEncryption': False,
                'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon'}}}
        (product / 'Info.plist').write_bytes(plistlib.dumps(info))
        (product / 'AppIcon60x60@2x.png').write_bytes(b'fixture icon')
        ipa = base / 'Fixture.ipa'; ipa.write_bytes(b'fixture package')
        validation = base / 'validation.json'
        report = dict(delivery, status='validated_for_upload', validatedArtifact='app-store-connect-export-from-archive',
                      packageSHA256=release.digest(ipa))
        validation.write_text(json.dumps(report))
        key = base / 'fixture.p8'; key.write_text(CANARY)
        environment = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                       'ASC_KEY_TYPE': 'team', 'ASC_KEY_ID': 'TESTKEY001',
                       'ASC_ISSUER_ID': '00000000-1111-2222-3333-444444444444', 'ASC_PRIVATE_KEY_PATH': str(key)}
        args = SimpleNamespace(configuration=config, plan=plan, archive=archive, ipa=ipa, validation=validation,
                               perform_upload=True, output=base / 'upload.json')
        return args, app, delivery, product, environment

    def test_archive_and_export_must_keep_planned_identity_and_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            args, app, plan, product, _ = self.fixture(directory)
            release.verify_apps(app, plan, args.archive, product)
            info = plistlib.loads((product / 'Info.plist').read_bytes())
            for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'MinimumOSVersion'):
                altered = dict(info); altered[key] = 'unexpected'
                (product / 'Info.plist').write_bytes(plistlib.dumps(altered))
                with self.subTest(key=key), self.assertRaises(ValueError): release.verify_apps(app, plan, args.archive, product)
                (product / 'Info.plist').write_bytes(plistlib.dumps(info))

    def test_missing_compiled_icon_blocks_delivery(self):
        with tempfile.TemporaryDirectory() as directory:
            args, app, plan, product, _ = self.fixture(directory)
            (product / 'AppIcon60x60@2x.png').unlink()
            with self.assertRaisesRegex(ValueError, 'AppIcon'): release.verify_apps(app, plan, args.archive)

    def test_exact_package_validation_binds_signature_version_and_digest(self):
        for signature_ok in (True, False):
            with self.subTest(signature_ok=signature_ok), tempfile.TemporaryDirectory() as directory:
                fixture = signing.SigningTests()
                archive, config, profile, entitlements, source = fixture.fixture(directory)
                config.write_text(json.dumps(records()))
                app = release.configuration(config)
                delivery = release.plan(app, 1, 1); delivery['status'] = 'planned'
                plan = Path(directory) / 'plan.json'; plan.write_text(json.dumps(delivery))
                for product in (archive / 'Products/Applications/StarterApp.app', source):
                    path = product / 'Info.plist'; info = plistlib.loads(path.read_bytes())
                    info.update(CFBundleVersion=delivery['buildNumber'], CFBundleShortVersionString=delivery['marketingVersion'],
                                ITSAppUsesNonExemptEncryption=False,
                                CFBundleIcons={'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon'}})
                    (product / 'AppIcon60x60@2x.png').write_bytes(b'fixture icon')
                    path.write_bytes(plistlib.dumps(info))
                ipa = Path(directory) / 'Fixture.ipa'; ipa.write_bytes(b'fixture package')
                args = SimpleNamespace(configuration=config, plan=plan, archive=archive, ipa=ipa)
                native = fixture.commands(profile, entitlements, signature_ok=signature_ok)
                def commands(command, **kwargs):
                    if command[0].endswith('ditto'):
                        shutil.copytree(source, Path(command[-1]) / 'Payload/StarterApp.app')
                        return subprocess.CompletedProcess(command, 0, b'', b'')
                    return native(command, **kwargs)
                with patch.object(release.subprocess, 'run', side_effect=commands):
                    if signature_ok:
                        report = release.validate_package(args)
                        self.assertEqual(report['status'], 'validated_for_upload')
                        self.assertEqual(report['packageSHA256'], release.digest(ipa))
                        self.assertEqual(report['buildNumber'], delivery['buildNumber'])
                        self.assertNotIn(CANARY, json.dumps(report))
                    else:
                        with self.assertRaises(ValueError): release.validate_package(args)

    def test_upload_requires_explicit_manual_main_and_exact_validated_package(self):
        cases = ('no_opt_in', 'pr', 'branch', 'local', 'offline_plan', 'wrong_hash', 'failed_validation', 'wrong_build', 'changed_ipa')
        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                args, _, _, _, env = self.fixture(directory)
                if case == 'no_opt_in': args.perform_upload = False
                if case == 'pr': env['GITHUB_EVENT_NAME'] = 'pull_request'
                if case == 'branch': env['GITHUB_REF'] = 'refs/heads/other'
                if case == 'local': env.pop('GITHUB_ACTIONS')
                if case == 'offline_plan':
                    value = json.loads(args.plan.read_text()); value['status'] = 'offline_preflight'; args.plan.write_text(json.dumps(value))
                if case == 'changed_ipa': args.ipa.write_bytes(b'different package')
                if case in ('wrong_hash', 'failed_validation', 'wrong_build'):
                    value = json.loads(args.validation.read_text())
                    value[{'wrong_hash': 'packageSHA256', 'failed_validation': 'status', 'wrong_build': 'buildNumber'}[case]] = 'wrong'
                    args.validation.write_text(json.dumps(value))
                with patch.object(release.subprocess, 'run') as command, self.assertRaises(ValueError): release.upload(args, env)
                command.assert_not_called()

    def test_upload_reports_acceptance_separately_and_never_forwards_raw_output(self):
        for result in (subprocess.CompletedProcess([], 0, CANARY.encode(), CANARY.encode()),
                       subprocess.CompletedProcess([], 1, CANARY.encode(), CANARY.encode()),
                       subprocess.TimeoutExpired('altool', 1200, output=CANARY.encode())):
            with self.subTest(result=result), tempfile.TemporaryDirectory() as directory:
                args, _, _, _, env = self.fixture(directory)
                capture = io.StringIO()
                kwargs = {'side_effect': result} if isinstance(result, Exception) else {'return_value': result}
                with patch.object(release.subprocess, 'run', **kwargs) as command, contextlib.redirect_stdout(capture):
                    status = release.upload(args, env)
                report = json.loads(args.output.read_text())
                self.assertEqual(status, 0 if not isinstance(result, Exception) and result.returncode == 0 else 1)
                self.assertEqual(report['installation'], 'not_verified')
                self.assertEqual(report['processing'], 'not_verified')
                self.assertNotIn(CANARY, capture.getvalue() + args.output.read_text())
                self.assertNotIn(CANARY, ' '.join(command.call_args.args[0]))
                self.assertIn('--p8-file-path', command.call_args.args[0])

    def test_processing_checks_do_not_claim_testflight_availability_or_installation(self):
        app = records()[1]; plan = release.plan(app, 1, 1)
        for state in ('PROCESSING', 'VALID', 'FAILED', 'INVALID', None):
            records_response = [] if state is None else [{'attributes': {'version': plan['buildNumber'], 'processingState': state}}]
            reader = FakeReader([('verified', [identity(app)]), ('verified', records_response)])
            result = release.processing(app, plan, reader)
            self.assertEqual(result['status'], state or 'not_visible_yet')
            self.assertEqual(result['testFlightAvailability'], 'not_verified')
            self.assertEqual(result['installation'], 'not_verified')

    def test_failed_processing_makes_command_fail_while_preserving_report(self):
        with tempfile.TemporaryDirectory() as directory:
            args, app, plan, _, _ = self.fixture(directory)
            reader = FakeReader([('verified', [identity(app)]), ('verified', [
                {'attributes': {'version': plan['buildNumber'], 'processingState': 'INVALID'}}])])
            argv = ['testflight-release.py', 'processing', '--account', '--asc', str(args.ipa),
                    '--configuration', str(args.configuration), '--plan', str(args.plan), '--output', str(args.output)]
            with patch.object(sys, 'argv', argv), patch.object(release, 'Reader', return_value=reader), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(release.main(), 1)
            self.assertEqual(json.loads(args.output.read_text())['status'], 'INVALID')

    def test_native_cli_supports_fixed_release_read_flags_without_credentials(self):
        binary = ROOT / ('build/tools/asc.exe' if sys.platform == 'win32' else 'build/tools/asc')
        if not binary.is_file(): self.skipTest('Pinned CLI is not installed')
        help_result = subprocess.run([str(binary), 'builds', 'list', '--help'], capture_output=True, text=True)
        self.assertEqual(help_result.returncode, 0)
        for flag in ('--build-number', '--platform', '--version', '--processing-state', '--paginate'):
            self.assertIn(flag, help_result.stdout + help_result.stderr)


if __name__ == '__main__': unittest.main()
