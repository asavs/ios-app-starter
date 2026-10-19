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


def issue_safe_text(value):
    """Reduce a feedback comment to one line and redact common private patterns."""
    if not isinstance(value, str):
        return ''
    text = re.sub(r'[\x00-\x1f\x7f]+', ' ', value)
    text = re.sub(r'\bBearer\s+\S+', '[redacted credential]', text, flags=re.IGNORECASE)
    text = re.sub(r'\b(?:gh[pousr]_[A-Za-z0-9_]{12,}|github_pat_[A-Za-z0-9_]{12,}|sk-[A-Za-z0-9_-]{12,})\b',
                  '[redacted credential]', text)
    text = re.sub(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '[redacted email]', text, flags=re.IGNORECASE)
    text = re.sub(r'https?://\S+', '[redacted link]', text, flags=re.IGNORECASE)
    text = re.sub(r'\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b', '[redacted identifier]', text,
                  flags=re.IGNORECASE)
    text = re.sub(r'(?<!\w)(?:\+?\d[\d ().-]{6,}\d)(?!\w)', '[redacted number]', text)
    return re.sub(r'\s+', ' ', text).strip()


def issue_draft(data):
    """Format reviewable issue-body drafts without identity or unverified build data."""
    drafts = []
    for index, item in enumerate(data, start=1):
        attributes = item.get('attributes', {})
        if not isinstance(attributes, dict):
            raise ValueError('Malformed feedback attributes')
        comment = issue_safe_text(attributes.get('comment')) or '[No comment provided]'
        model = issue_safe_text(attributes.get('deviceModel')) or '[Not provided]'
        os_version = issue_safe_text(attributes.get('osVersion')) or '[Not provided]'
        drafts.append('\n'.join((
            f'Feedback item {index}',
            'Summary: [Triage sanitized feedback]',
            'Expected behavior: [Not provided]',
            f'Observed behavior: {comment}',
            'Steps to reproduce: [Not provided]',
            'App version/build: [Not verified; confirm the related build before filing]',
            f'Device model / iOS: {model} / {os_version}',
            'Reproduced by reviewer: unknown',
            'Impact and priority: [Triage]',
            'Related issue or suspected duplicate: [Check before filing]',
            'Acceptance / targeted retest: [Define during triage]',
        )))
    return '\n\n---\n\n'.join(drafts) + ('\n' if drafts else '')


def private_destination(path, label, parser):
    destination = path.resolve()
    if destination == ROOT or ROOT in destination.parents or os.environ.get('GITHUB_ACTIONS') == 'true':
        parser.error(f'{label} files must be outside the checkout and cannot be written by Actions.')
    if destination.exists():
        parser.error(f'Choose a new {label} path; existing files are not overwritten.')
    return destination


def write_private_text(destination, content):
    # Exclusive creation; Windows ACLs remain the user's responsibility.
    descriptor = os.open(str(destination), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w', encoding='utf-8') as output:
        output.write(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--account', action='store_true', help='Explicitly enable authenticated read-only requests')
    parser.add_argument('--asc', type=Path)
    parser.add_argument('--app-id', required=True, help='Existing App Store Connect numeric app ID')
    parser.add_argument('--build-id', help='Optional Apple build resource ID; not the displayed build number')
    parser.add_argument('--private-report', type=Path, help='Local JSON with comments; outside checkout, never public artifacts')
    parser.add_argument('--issue-draft', type=Path, help='Write reviewable sanitized issue-body drafts outside checkout')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]+', args.app_id):
        parser.error('App ID must be numeric.')
    if args.build_id and not re.fullmatch(r'[A-Za-z0-9-]+', args.build_id):
        parser.error('Invalid build resource ID.')
    private_report = private_destination(args.private_report, 'Private feedback report', parser) if args.private_report else None
    draft_path = private_destination(args.issue_draft, 'Issue draft', parser) if args.issue_draft else None
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
            command = ['testflight', 'feedback', 'list', '--app', args.app_id, '--include', 'build']
            if args.build_id:
                command += ['--build-id', args.build_id]
            with tempfile.TemporaryDirectory(prefix='testflight-feedback-') as temporary:
                status, data = doctor.Reader(args.asc, env, temporary).read(command)
            if status == 'verified':
                status = 'completed'
    report = {'status': status, 'count': len(data) if data is not None else None,
              'scope': 'selected_build' if args.build_id else 'all_accessible_app_feedback'}
    if status == 'completed' and private_report:
        submissions = []
        for item in data:
            attributes = item.get('attributes', {})
            if not isinstance(attributes, dict):
                parser.exit(1, 'Malformed feedback attributes; no private report written.\n')
            submissions.append({'id': item.get('id'), 'attributes': {
                key: attributes.get(key) for key in ('createdDate', 'comment', 'deviceModel', 'osVersion')},
                'build': item.get('relationships', {}).get('build', {}).get('data')})
        # Exclusive creation; macOS mode is restrictive. Windows ACLs remain the user's responsibility.
        write_private_text(private_report, json.dumps({**report, 'submissions': submissions}, indent=2) + '\n')
        report['privateReportWritten'] = True
    if status == 'completed' and draft_path:
        write_private_text(draft_path, issue_draft(data))
        report['issueDraftWritten'] = True
    print(json.dumps(report, indent=2))
    return 0 if status in ('not_requested', 'completed') else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, TypeError, AttributeError):
        raise SystemExit('Feedback read/report failed; raw account data was not logged.')
