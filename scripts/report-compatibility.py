#!/usr/bin/env python3
"""Record one compatibility lane's outcome, or aggregate all lanes into a single coverage report."""
import argparse
import json
import os
from pathlib import Path


def verified(result, status):
    return (status == 0 and isinstance(result, dict) and result.get('result') == 'Passed'
            and all(type(result.get(key)) is int for key in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests'))
            and result['totalTestCount'] > 0 and result['passedTests'] > 0 and result['failedTests'] == 0)


def lane_outcome(lane, report_root):
    runs = sorted(report_root.glob('run.*'))
    record = dict(lane, status='unverified', exit_status=None, total=None, passed=None, failed=None, skipped=None)
    if len(runs) != 1:
        record['note'] = f'expected one test run directory, found {len(runs)}'
        return record
    run = runs[0]
    try:
        record['exit_status'] = int((run / 'exit-status.txt').read_text().strip())
    except (OSError, ValueError):
        record['note'] = 'exit status missing'
        return record
    try:
        result = json.loads((run / 'results.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        result = None
    if isinstance(result, dict):
        for key, source in (('total', 'totalTestCount'), ('passed', 'passedTests'), ('failed', 'failedTests'), ('skipped', 'skippedTests')):
            record[key] = result.get(source) if type(result.get(source)) is int else None
    record['status'] = 'passed' if verified(result, record['exit_status']) else ('failed' if record['exit_status'] else 'unverified')
    built = report_root / 'built-app.json'
    if built.is_file():
        try:
            record['built_app'] = json.loads(built.read_text(encoding='utf-8'))
        except ValueError:
            pass
    return record


def aggregate(plan, results):
    by_lane = {record['lane']: record for record in results}
    rows = []
    for lane in plan['include']:
        rows.append(by_lane.get(lane['lane']) or dict(lane, status='missing', exit_status=None, total=None, passed=None, failed=None, skipped=None))
    verified_versions = sorted((row['runtime_version'] for row in rows if row['status'] == 'passed'),
                               key=lambda v: [int(p) for p in v.split('.')])
    return {'schemaVersion': 1, 'selection': plan.get('selection'), 'lanes': rows,
            'verifiedRuntimes': verified_versions,
            'allPassed': bool(rows) and all(row['status'] == 'passed' for row in rows)}


def summary(report, run_url=''):
    lines = ['## iOS compatibility coverage', '',
             ('All planned lanes passed.' if report['allPassed'] else 'Some planned lanes did not pass; coverage below names only verified runtimes.'), '',
             'Verified runtimes: ' + (', '.join(report['verifiedRuntimes']) or 'none'), '',
             '| Runtime | Device | Xcode / SDK | Runner | Status | Tests (total/passed/failed/skipped) | Exit |', '|---|---|---|---|---|---|---|']
    for row in report['lanes']:
        counts = '/'.join('-' if row.get(key) is None else str(row[key]) for key in ('total', 'passed', 'failed', 'skipped'))
        lines.append(f"| {row['runtime_name']} ({row['runtime_version']}) | {row['device']} | {row['xcode_version']} / {row['sdk']} | "
                     f"`{row['runner']}` | **{row['status']}** | {counts} | {'-' if row.get('exit_status') is None else row['exit_status']} |")
    lines += ['', 'Simulator results verify UI and logic on the named runtime and toolchain, not physical devices. '
              'A lane marked unverified or missing establishes nothing.']
    if run_url:
        lines.append(f'Per-lane artifacts (`ios-compat-*`): {run_url}')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    lane = sub.add_parser('lane', help='Write lane-result.json for one matrix entry from its test report directory')
    lane.add_argument('--lane-json', required=True, help='The matrix entry as JSON (toJSON(matrix))')
    lane.add_argument('--report-dir', type=Path, required=True)
    agg = sub.add_parser('aggregate', help='Combine lane-result.json files into one coverage report')
    agg.add_argument('--plan', type=Path, required=True)
    agg.add_argument('--results-dir', type=Path, required=True, help='Directory searched for **/lane-result.json')
    agg.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'lane':
        entry = json.loads(args.lane_json)
        record = lane_outcome(entry, args.report_dir)
        args.report_dir.mkdir(parents=True, exist_ok=True)
        (args.report_dir / 'lane-result.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        print(f"Lane {record['lane']}: {record['status']}")
        return 0 if record['status'] == 'passed' else 1
    plan = json.loads(args.plan.read_text(encoding='utf-8'))
    results = [json.loads(path.read_text(encoding='utf-8')) for path in sorted(args.results_dir.glob('**/lane-result.json'))]
    report = aggregate(plan, results)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    run_url = '/'.join((os.environ.get('GITHUB_SERVER_URL', ''), os.environ.get('GITHUB_REPOSITORY', ''), 'actions', 'runs',
                        os.environ.get('GITHUB_RUN_ID', ''))) if os.environ.get('GITHUB_RUN_ID') else ''
    text = summary(report, run_url)
    args.output.with_suffix('.md').write_text(text, encoding='utf-8')
    print(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as output:
            output.write(text)
    return 0 if report['allPassed'] else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f'Compatibility report failed: {error}')
