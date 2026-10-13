#!/usr/bin/env python3
"""Read TestFlight feedback with isolated credentials; print only status/counts."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('feedback_doctor', ROOT / 'scripts/apple-doctor.py')
doctor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doctor)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--account', action='store_true', help='Explicitly enable authenticated read-only requests')
    parser.add_argument('--asc', type=Path)
    parser.add_argument('--app-id', required=True, help='Existing App Store Connect numeric app ID')
    parser.add_argument('--build-id', help='Optional Apple build resource ID; not the displayed build number')
    parser.add_argument('--private-report', type=Path, help='Local JSON with comments; outside checkout, never public artifacts')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]+', args.app_id):
        parser.error('App ID must be numeric.')
    if args.build_id and not re.fullmatch(r'[A-Za-z0-9-]+', args.build_id):
        parser.error('Invalid build resource ID.')
    if args.private_report:
        destination = args.private_report.resolve()
        if destination == ROOT or ROOT in destination.parents or os.environ.get('GITHUB_ACTIONS') == 'true':
            parser.error('Private feedback reports must be outside the checkout and cannot be written by Actions.')
        if destination.exists():
            parser.error('Choose a new private report path; existing files are not overwritten.')
    status, data = 'not_requested', None
    if args.account:
        env = os.environ
        kind = env.get('ASC_KEY_TYPE', 'team')
        complete = bool(env.get('ASC_KEY_ID')) and kind in ('team', 'individual') and bool(
            env.get('ASC_PRIVATE_KEY') or env.get('ASC_PRIVATE_KEY_PATH') or env.get('ASC_PRIVATE_KEY_B64')) and (
            kind == 'individual' or bool(env.get('ASC_ISSUER_ID')))
        if not complete:
            status = 'not_configured'
        elif not args.asc or not args.asc.is_file():
            status = 'missing_tool'
        else:
            command = ['testflight', 'feedback', 'list', '--app', args.app_id]
            if args.build_id:
                command += ['--build-id', args.build_id]
            with tempfile.TemporaryDirectory(prefix='testflight-feedback-') as temporary:
                status, data = doctor.Reader(args.asc, env, temporary).read(command)
            if status == 'verified':
                status = 'completed'
    report = {'status': status, 'count': len(data) if data is not None else None,
              'scope': 'selected_build' if args.build_id else 'all_accessible_app_feedback'}
    if status == 'completed' and args.private_report:
        submissions = []
        for item in data:
            attributes = item.get('attributes', {})
            if not isinstance(attributes, dict):
                parser.exit(1, 'Malformed feedback attributes; no private report written.\n')
            submissions.append({'id': item.get('id'), 'attributes': {
                key: attributes.get(key) for key in ('createdDate', 'comment', 'deviceModel', 'osVersion')},
                'build': item.get('relationships', {}).get('build', {}).get('data')})
        # Exclusive creation; macOS mode is restrictive. Windows ACLs remain the user's responsibility.
        descriptor = os.open(str(args.private_report.resolve()), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w', encoding='utf-8') as output:
            json.dump({**report, 'submissions': submissions}, output, indent=2)
            output.write('\n')
        report['privateReportWritten'] = True
    print(json.dumps(report, indent=2))
    return 0 if status in ('not_requested', 'completed') else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, TypeError, AttributeError):
        raise SystemExit('Feedback read/report failed; raw account data was not logged.')
