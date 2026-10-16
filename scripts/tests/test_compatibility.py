import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


planner = load('plan-compatibility-matrix')
reporter = load('report-compatibility')


def xcode(version, sdk):
    return {'path': f'/Applications/Xcode_{version}.app/Contents/Developer', 'aliases': [f'Xcode_{version}.app'],
            'version': version, 'build': 'TEST', 'iphoneSDK': sdk, 'usable': True}


def runtime(name, version, devices, available=True):
    return {'name': name, 'version': version, 'available': available, 'devices': devices}


MACOS_14 = {'schemaVersion': 2, 'runnerLabel': 'macos-14', 'xcode': 'Xcode 15.4\nBuild version 15F31d', 'iphoneSDK': '17.5',
            'xcodes': [xcode('15.4', '17.5'), xcode('16.1', '18.1'), xcode('16.2', '18.2')],
            'runtimes': [runtime('iOS 17.0', '17.0.1', ['iPhone 15', 'iPhone SE (3rd generation)']),
                         runtime('iOS 17.5', '17.5', ['iPhone 15']),
                         runtime('iOS 18.2', '18.2', ['iPhone 16', 'iPhone SE (3rd generation)'])]}
MACOS_15 = {'schemaVersion': 2, 'runnerLabel': 'macos-15', 'xcode': 'Xcode 16.4\nBuild version 16F6', 'iphoneSDK': '18.5',
            'xcodes': [xcode('16.4', '18.5'), xcode('26.3', '26.3')],
            'runtimes': [runtime('iOS 18.2', '18.2', ['iPhone 16']),
                         runtime('iOS 18.6', '18.6', ['iPhone 16']),
                         runtime('iOS 26.2', '26.2', ['iPhone 17']),
                         runtime('iOS 16.4', '16.4', ['iPhone 14'], available=False)]}
XCODE_27_SCHEMA1 = {'schemaVersion': 1, 'runnerLabel': 'xcode-27', 'xcode': 'Xcode 27.0\nBuild version 27A266a', 'iphoneSDK': '27.0',
                    'runtimes': [runtime('iOS 27.0', '27.0', ['iPad (A16)', 'iPhone 17', 'iPhone Air'])]}


class PlanTests(unittest.TestCase):
    def lanes(self, selection='all', inventories=(MACOS_14, MACOS_15, XCODE_27_SCHEMA1)):
        result = planner.plan(list(inventories), selection)
        return result, {lane['runtime_version']: lane for lane in result['include']}

    def test_all_lanes_sorted_and_deduplicated(self):
        result, by_version = self.lanes()
        self.assertEqual([lane['runtime_version'] for lane in result['include']], ['17.0.1', '17.5', '18.2', '18.6', '26.2', '27.0'])
        # iOS 18.2 exists on both images; the newer toolchain (16.4 on macos-15) wins.
        self.assertEqual(by_version['18.2']['runner'], 'macos-15')
        self.assertIn({'runner': 'macos-14', 'runtime': '18.2', 'reason': 'duplicate runtime; newer toolchain elsewhere'}, result['skipped'])

    def test_swift6_floor_skips_xcode_15_and_uses_nearest_newer_major(self):
        _, by_version = self.lanes()
        lane = by_version['17.0.1']
        self.assertEqual((lane['xcode_version'], lane['sdk'], lane['pairing']), ('16.2', '18.2', 'newer-toolchain'))

    def test_pairing_labels(self):
        _, by_version = self.lanes()
        self.assertEqual(by_version['18.6']['pairing'], 'runtime-newer-than-sdk')
        self.assertEqual(by_version['26.2']['pairing'], 'matched')

    def test_schema1_inventory_uses_default_xcode(self):
        _, by_version = self.lanes()
        lane = by_version['27.0']
        self.assertEqual((lane['xcode_version'], lane['xcode_path'], lane['device']), ('27.0', '', 'iPhone 17'))

    def test_device_preference_and_destination(self):
        _, by_version = self.lanes()
        self.assertEqual(by_version['17.0.1']['device'], 'iPhone SE (3rd generation)')
        self.assertEqual(by_version['17.5']['device'], 'iPhone 15')
        self.assertEqual(by_version['17.0.1']['destination'], 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=17.0.1')
        self.assertEqual(by_version['17.0.1']['lane'], 'ios-17-0-1')

    def test_unavailable_runtime_and_missing_iphone_are_skipped(self):
        inventory = dict(MACOS_15, runtimes=[runtime('iOS 18.5', '18.5', ['iPad (10th generation)']), MACOS_15['runtimes'][3]])
        result = planner.plan([inventory], 'all')
        self.assertEqual(result['include'], [])
        reasons = {item['runtime']: item['reason'] for item in result['skipped']}
        self.assertEqual(reasons, {'18.5': 'no iPhone simulator', '16.4': 'runtime unavailable'})

    def test_no_swift6_toolchain_is_reported(self):
        inventory = dict(MACOS_14, xcodes=[xcode('15.4', '17.5')])
        result = planner.plan([inventory], 'all')
        self.assertEqual(result['include'], [])
        self.assertTrue(all(item['reason'] == 'no-swift6-toolchain' for item in result['skipped']))

    def test_selection_modes(self):
        result, _ = self.lanes('one-per-major')
        self.assertEqual([lane['runtime_version'] for lane in result['include']], ['17.0.1', '18.2', '26.2', '27.0'])
        result, _ = self.lanes('minimum')
        self.assertEqual([lane['runtime_version'] for lane in result['include']], ['17.0.1'])
        with self.assertRaises(ValueError):
            planner.plan([MACOS_14], 'everything')

    def test_cli_writes_github_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'a').mkdir()
            (path / 'a' / 'ios-runtime-inventory.json').write_text(json.dumps(MACOS_14))
            env = dict(os.environ, GITHUB_OUTPUT=str(path / 'out.txt'), GITHUB_STEP_SUMMARY=str(path / 'summary.md'))
            process = subprocess.run([sys.executable, str(SCRIPTS / 'plan-compatibility-matrix.py'), '--inventory-dir', str(path),
                                      '--selection', 'minimum', '--output', str(path / 'plan.json')], env=env, capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            outputs = dict(line.split('=', 1) for line in (path / 'out.txt').read_text().splitlines())
            self.assertEqual(outputs['count'], '1')
            self.assertEqual(json.loads(outputs['matrix'])['include'][0]['lane'], 'ios-17-0-1')
            self.assertIn('| `ios-17-0-1` |', (path / 'summary.md').read_text())


class ReportTests(unittest.TestCase):
    LANE = {'lane': 'ios-17-0-1', 'runner': 'macos-14', 'runtime_name': 'iOS 17.0', 'runtime_version': '17.0.1',
            'device': 'iPhone SE (3rd generation)', 'destination': 'x', 'xcode_path': '', 'xcode_version': '16.2',
            'xcode_build': 'T', 'sdk': '18.2', 'pairing': 'newer-toolchain'}

    def write_run(self, root, status, result):
        run = root / 'run.abc'
        run.mkdir(parents=True)
        (run / 'exit-status.txt').write_text(f'{status}\n')
        if result is not None:
            (run / 'results.json').write_text(json.dumps(result))

    def test_lane_passed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_run(root, 0, dict(result='Passed', totalTestCount=1, passedTests=1, failedTests=0, skippedTests=0))
            record = reporter.lane_outcome(self.LANE, root)
            self.assertEqual((record['status'], record['total'], record['passed']), ('passed', 1, 1))

    def test_lane_failed_and_unverified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_run(root, 65, dict(result='Failed', totalTestCount=1, passedTests=0, failedTests=1, skippedTests=0))
            self.assertEqual(reporter.lane_outcome(self.LANE, root)['status'], 'failed')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_run(root, 0, None)  # exit 0 without readable counts is never a pass
            self.assertEqual(reporter.lane_outcome(self.LANE, root)['status'], 'unverified')
        with tempfile.TemporaryDirectory() as directory:
            record = reporter.lane_outcome(self.LANE, Path(directory))
            self.assertEqual(record['status'], 'unverified')
            self.assertIn('found 0', record['note'])

    def test_aggregate_marks_missing_lanes_and_names_only_verified_runtimes(self):
        plan = {'selection': 'all', 'include': [self.LANE, dict(self.LANE, lane='ios-18-2', runtime_version='18.2', runtime_name='iOS 18.2')]}
        passed = dict(self.LANE, status='passed', exit_status=0, total=1, passed=1, failed=0, skipped=0)
        report = reporter.aggregate(plan, [passed])
        self.assertFalse(report['allPassed'])
        self.assertEqual(report['verifiedRuntimes'], ['17.0.1'])
        self.assertEqual([row['status'] for row in report['lanes']], ['passed', 'missing'])
        text = reporter.summary(report, 'https://example/run')
        self.assertIn('Verified runtimes: 17.0.1', text)
        self.assertIn('**missing**', text)

    def test_aggregate_cli_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'plan.json').write_text(json.dumps({'selection': 'minimum', 'include': [self.LANE]}))
            (path / 'results' / 'ios-compat-starter-ios-17-0-1').mkdir(parents=True)
            (path / 'results' / 'ios-compat-starter-ios-17-0-1' / 'lane-result.json').write_text(
                json.dumps(dict(self.LANE, status='passed', exit_status=0, total=1, passed=1, failed=0, skipped=0)))
            process = subprocess.run([sys.executable, str(SCRIPTS / 'report-compatibility.py'), 'aggregate', '--plan', str(path / 'plan.json'),
                                      '--results-dir', str(path / 'results'), '--output', str(path / 'report.json')], capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertTrue((path / 'report.md').is_file())
            self.assertTrue(json.loads((path / 'report.json').read_text())['allPassed'])


if __name__ == '__main__':
    unittest.main()
