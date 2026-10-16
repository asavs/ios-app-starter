#!/usr/bin/env python3
"""Plan, then apply, an internal TestFlight group with automatic distribution using the pinned CLI.

Reads are the only default. `apply` performs exactly two kinds of change, each previewed first:
create the named internal group with access to all builds, and add App Store Connect users holding
the chosen role to it. Nothing is deleted or modified. Console output and reports carry counts and
statuses only; tester identities stay inside the process.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / 'scripts') not in sys.path:  # testflight-release imports sibling helpers by module name
    sys.path.insert(0, str(ROOT / 'scripts'))


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


doctor = load('apple-doctor')
release = load('testflight-release')
ROLES = ('ACCOUNT_HOLDER', 'ADMIN', 'APP_MANAGER')
GROUP_NAME_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9 ._-]{0,49}\Z')


class GroupsError(Exception):
    pass


class Writer(doctor.Reader):
    """Fixed mutation interface with the Reader's credential isolation; never paginates, never echoes output."""

    def write(self, command):
        try:
            result = subprocess.run([self.binary, *command, '--output', 'json'], env=self.env, capture_output=True,
                                    text=True, encoding='utf-8', errors='replace', timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return 'not_verified', None
        if result.returncode:
            error = result.stderr.lower()
            if any(s in error for s in ('forbidden', 'not authorized', 'access denied')):
                return 'inaccessible', None
            if any(s in error for s in ('unauthorized', 'authentication credentials', 'not authenticated')):
                return 'authentication_failed', None
            return 'failed', None
        try:
            payload = json.loads(result.stdout)
        except ValueError:
            return 'not_verified', None
        record = payload.get('data', payload) if isinstance(payload, dict) else None
        return ('completed', record) if isinstance(record, dict) else ('not_verified', None)


def read(reader, command):
    status, data = reader.read(command)
    if status != 'verified':
        raise GroupsError(f'Apple read did not complete ({status}); nothing was changed.')
    return data


def attributes(record):
    value = record.get('attributes', {}) if isinstance(record, dict) else {}
    return value if isinstance(value, dict) else {}


def plan(app, reader, group_name, role):
    if not GROUP_NAME_RE.fullmatch(group_name):
        raise GroupsError('Group name must be 1-50 characters: letters, digits, space, dot, underscore or hyphen.')
    if role not in ROLES:
        raise GroupsError('Choose a supported tester role.')
    app_id = release.app_id(reader, app)
    groups = [g for g in read(reader, ['testflight', 'groups', 'list', '--app', app_id, '--name', group_name])
              if attributes(g).get('name') == group_name and isinstance(g.get('id'), str)]
    if len(groups) > 1:
        raise GroupsError('More than one TestFlight group has this name; choose a unique name.')
    existing = groups[0] if groups else None
    group_state = None
    if existing:
        group_state = {'id': existing['id'], 'internal': attributes(existing).get('isInternalGroup') is True,
                       'accessAllBuilds': attributes(existing).get('hasAccessToAllBuilds') is True}
    users = read(reader, ['users', 'list', '--role', role, '--fields', 'username,roles'])
    emails = sorted({attributes(u).get('username') for u in users if isinstance(attributes(u).get('username'), str)})
    members = set()
    if existing:
        testers = read(reader, ['testflight', 'testers', 'list', '--app', app_id, '--group', existing['id']])
        members = {attributes(t).get('email') for t in testers if isinstance(attributes(t).get('email'), str)}
    missing = [email for email in emails if email not in members]
    actions = []
    if existing is None:
        actions.append({'action': 'create_group', 'name': group_name, 'internal': True, 'accessAllBuilds': True})
    elif not (group_state['internal'] and group_state['accessAllBuilds']):
        actions.append({'action': 'manual_review', 'reason': 'existing group is not an internal group with access to all '
                        'builds; that setting is fixed at creation, so choose a new group name and retire this one by hand'})
    actions.extend({'action': 'add_tester', 'role': role} for _ in missing)
    return {'schemaVersion': 1, 'status': 'planned', 'appId': app_id, 'bundleIdentifier': app['bundleIdentifier'],
            'groupName': group_name, 'existingGroup': group_state, 'testerRole': role,
            'candidateTesters': len(emails), 'alreadyMembers': len(emails) - len(missing),
            'actions': actions, '_emails': missing}


def apply(planned, writer, reader, environment):
    if (environment.get('GITHUB_ACTIONS') != 'true' or environment.get('GITHUB_REF') != 'refs/heads/main'
            or environment.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise GroupsError('Apply requires an explicit main-branch GitHub manual dispatch; nothing was changed.')
    if any(action['action'] == 'manual_review' for action in planned['actions']):
        raise GroupsError('The existing group needs manual review; nothing was changed.')
    results = []
    group_id = planned['existingGroup']['id'] if planned['existingGroup'] else None
    if group_id is None:
        status, record = writer.write(['testflight', 'groups', 'create', '--app', planned['appId'], '--name',
                                       planned['groupName'], '--internal', '--access-all-builds'])
        if status != 'completed' or not isinstance(record.get('id'), str):
            results.append({'action': 'create_group', 'status': status})
            return finish(planned, results, reader, None)
        group_id = record['id']
        results.append({'action': 'create_group', 'status': 'completed'})
    for email in planned['_emails']:
        status, _ = writer.write(['testflight', 'testers', 'add', '--app', planned['appId'], '--email', email,
                                  '--group', group_id])
        results.append({'action': 'add_tester', 'status': status})
    return finish(planned, results, reader, group_id)


def finish(planned, results, reader, group_id):
    verified = None
    if group_id:
        try:
            groups = [g for g in read(reader, ['testflight', 'groups', 'list', '--app', planned['appId'], '--name',
                                               planned['groupName']]) if g.get('id') == group_id]
            testers = read(reader, ['testflight', 'testers', 'list', '--app', planned['appId'], '--group', group_id])
            if groups:
                verified = {'internal': attributes(groups[0]).get('isInternalGroup') is True,
                            'accessAllBuilds': attributes(groups[0]).get('hasAccessToAllBuilds') is True,
                            'testerCount': len(testers)}
        except GroupsError:
            verified = None
    ok = all(item['status'] == 'completed' for item in results) and verified is not None and verified['internal'] and verified['accessAllBuilds']
    return {key: value for key, value in planned.items() if key != '_emails'} | {
        'status': 'applied' if ok else 'incomplete', 'results': results, 'verifiedGroup': verified}


def summary(report):
    lines = ['## TestFlight group ' + ('plan' if report['status'] == 'planned' else report['status']), '',
             f"- App: `{report['bundleIdentifier']}`; group `{report['groupName']}`; tester role `{report['testerRole']}`",
             f"- Existing group: {report['existingGroup'] or 'none'}",
             f"- Candidate testers with that role: {report['candidateTesters']}; already members: {report['alreadyMembers']}",
             '- Planned actions: ' + (', '.join(sorted({a['action'] for a in report['actions']})) or 'none')]
    if report['status'] != 'planned':
        lines.append('- Results: ' + (', '.join(f"{r['action']}={r['status']}" for r in report['results']) or 'none'))
        lines.append(f"- Verified group: {report['verifiedGroup'] or 'not verified'}")
    lines += ['', 'Tester identities are not printed. Automatic distribution is fixed at group creation; a build reaches '
              'members of an all-builds internal group without manual assignment once Apple finishes processing.']
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--configuration', type=Path, required=True, help='Native configuration export')
    parser.add_argument('--account', action='store_true', required=True, help='Explicitly enable authenticated reads')
    parser.add_argument('--asc', type=Path, required=True)
    parser.add_argument('--group-name', default='dev-auto')
    parser.add_argument('--tester-role', choices=ROLES, default='ACCOUNT_HOLDER')
    parser.add_argument('--apply', action='store_true', help='Perform the planned create/add actions (main dispatch only)')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        if not args.asc.is_file():
            raise GroupsError('Pinned App Store Connect CLI is missing.')
        app = release.configuration(args.configuration)
        with tempfile.TemporaryDirectory(prefix='testflight-groups-') as directory:
            reader = doctor.Reader(args.asc, os.environ, directory)
            report = plan(app, reader, args.group_name, args.tester_role)
            if args.apply:
                report = apply(report, Writer(args.asc, os.environ, directory), reader, dict(os.environ))
            else:
                report = {key: value for key, value in report.items() if key != '_emails'}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        text = summary(report)
        print(text)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as output:
                output.write(text)
        return 0 if report['status'] in ('planned', 'applied') else 1
    except (GroupsError, release.ReleaseError) as error:
        parser.exit(1, f'TestFlight groups stopped: {error}\n')
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        parser.exit(1, 'TestFlight groups could not establish a verified result; raw account output was not logged.\n')


if __name__ == '__main__':
    raise SystemExit(main())
