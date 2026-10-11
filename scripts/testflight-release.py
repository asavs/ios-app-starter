#!/usr/bin/env python3
"""Plan, verify and explicitly upload an internal TestFlight build; redact upstream output."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
from signing_configuration import read_config

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_doctor', ROOT / 'scripts/apple-doctor.py')
doctor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doctor)
Reader = doctor.Reader
MAX_COUNTER = 99_989_999


class ReleaseError(ValueError):
    """Fixed, safe-to-display release diagnosis."""
    pass


def decode_number(value):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}', value):
        raise ReleaseError('Existing build number is unsupported; review it before releasing.')
    parts = [int(part) for part in value.split('.')]
    parts += [0] * (3 - len(parts))
    return (parts[0] - 1) * 10_000 + parts[1] * 100 + parts[2]


def next_number(run_number, run_attempt, existing, base='1'):
    if not 1 <= run_number <= 999_900 or not 1 <= run_attempt <= 99:
        raise ReleaseError('Workflow run number or attempt exceeds the supported build-number range.')
    # A stable base plus run/attempt gives unique proposals even before Apple exposes an earlier upload.
    counter = decode_number(base) + (run_number - 1) * 100 + run_attempt
    highest = max((decode_number(number) for number in existing), default=-1)
    if counter > MAX_COUNTER:
        raise ReleaseError('Build-number range exhausted; review the release numbering policy.')
    if counter <= highest:
        raise ReleaseError('Proposed build number is not above existing builds; review and raise the repository TESTFLIGHT_BUILD_NUMBER_BASE before retrying.')
    return f'{counter // 10_000 + 1}.{counter // 100 % 100}.{counter % 100}'


def configuration(path):
    app = read_config(path)
    version = app.get('marketingVersion', '')
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', version):
        raise ReleaseError('Fresh configuration must include a numeric marketingVersion.')
    decode_number(app.get('buildNumber', ''))
    return app


def prepare_options(app, template, output):
    values = plistlib.loads(Path(template).read_bytes())
    required = {'method': 'app-store-connect', 'destination': 'export', 'signingStyle': 'automatic',
                'manageAppVersionAndBuildNumber': False, 'testFlightInternalTestingOnly': True,
                'uploadSymbols': True}
    if values != required or any(type(values.get(key)) is not type(value) for key, value in required.items()):
        raise ReleaseError('Reviewed TestFlight export policy changed; review before releasing.')
    values['teamID'] = app['teamIdentifier']
    Path(output).write_bytes(plistlib.dumps(values, sort_keys=True))


def read_records(reader, command):
    status, data = reader.read(command)
    if status != 'verified':
        raise ReleaseError('Apple read did not complete; build inventory remains unknown.')
    return data


def app_id(reader, app):
    matches = read_records(reader, ['apps', 'list', '--bundle-id', app['bundleIdentifier']])
    if (len(matches) != 1 or matches[0].get('attributes', {}).get('bundleId') != app['bundleIdentifier']
            or not isinstance(matches[0].get('id'), str)
            or not re.fullmatch(r'[0-9]+', matches[0]['id'])):
        raise ReleaseError('Exactly one verified matching App Store Connect app is required.')
    return matches[0]['id']


def plan(app, run_number, run_attempt, reader=None, base=None):
    existing = [app['buildNumber']]
    if reader:
        records = read_records(reader, ['builds', 'list', '--app', app_id(reader, app),
                                       '--platform', 'IOS', '--processing-state', 'all'])
        for record in records:
            existing.append(record.get('attributes', {}).get('version'))
    return {'status': 'planned' if reader else 'offline_preflight',
            'bundleIdentifier': app['bundleIdentifier'], 'teamIdentifier': app['teamIdentifier'],
            'marketingVersion': app['marketingVersion'],
            'buildNumber': next_number(run_number, run_attempt, existing, base or app['buildNumber']),
            'runNumber': run_number, 'runAttempt': run_attempt, 'buildNumberBase': base or app['buildNumber'],
            'existingBuildCount': len(existing) - 1}


def verify_plan(app, delivery):
    for key in ('bundleIdentifier', 'teamIdentifier', 'marketingVersion'):
        if delivery.get(key) != app[key]:
            raise ReleaseError('Release plan does not match the fresh configuration.')
    if delivery.get('buildNumber') != next_number(delivery.get('runNumber', 0), delivery.get('runAttempt', 0), [], delivery.get('buildNumberBase')):
        raise ReleaseError('Release number does not match its recorded workflow run/attempt/base.')
    if delivery.get('status') not in ('planned', 'offline_preflight'):
        raise ReleaseError('Release plan has an unsupported status.')


def verify_apps(app, delivery, archive, distribution_app=None):
    verify_plan(app, delivery)
    paths = [Path(archive) / 'Products/Applications/StarterApp.app']
    if distribution_app is not None:
        paths.append(Path(distribution_app))
    expected = {'CFBundleIdentifier': app['bundleIdentifier'], 'CFBundleDisplayName': app['displayName'],
                'MinimumOSVersion': app['minimumIOS'], 'CFBundleShortVersionString': delivery['marketingVersion'],
                'CFBundleVersion': delivery['buildNumber']}
    for path in paths:
        info = plistlib.loads((path / 'Info.plist').read_bytes())
        if any(info.get(key) != value for key, value in expected.items()):
            raise ReleaseError('Archive/export identity or version does not match the selected release plan.')
        icon = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {})
        if icon.get('CFBundleIconName') != 'AppIcon' or not any(path.glob('AppIcon*.png')):
            raise ReleaseError('Archive/export has no compiled AppIcon; add the required app icon before delivery.')


def digest(path):
    checksum = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(chunk)
    return checksum.hexdigest()


def validate_package(args):
    # Verify the actual package we will upload, rather than a caller-supplied extracted app.
    app = configuration(args.configuration)
    delivery = json.loads(args.plan.read_text(encoding='utf-8'))
    with tempfile.TemporaryDirectory(prefix='testflight-package-', dir=args.archive.parent) as directory:
        result = subprocess.run(['/usr/bin/ditto', '-x', '-k', str(args.ipa), directory], capture_output=True)
        if result.returncode:
            raise ReleaseError('Could not inspect exported package.')
        exported = Path(directory) / 'Payload/StarterApp.app'
        verify_apps(app, delivery, args.archive, exported)
        validator_spec = importlib.util.spec_from_file_location('release_validator', ROOT / 'scripts/validate-signed-archive.py')
        validator = importlib.util.module_from_spec(validator_spec)
        validator_spec.loader.exec_module(validator)
        signed = validator.validate(args.archive, args.configuration, exported)
    return {**delivery, **signed, 'status': 'validated_for_upload', 'packageSHA256': digest(args.ipa)}


def upload(args, environment):
    if (not args.perform_upload or environment.get('GITHUB_ACTIONS') != 'true'
            or environment.get('GITHUB_REF') != 'refs/heads/main'
            or environment.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise ReleaseError('Upload requires explicit main-branch GitHub manual dispatch authorization.')
    app = configuration(args.configuration)
    delivery = json.loads(args.plan.read_text(encoding='utf-8'))
    verify_plan(app, delivery)
    report = json.loads(args.validation.read_text(encoding='utf-8'))
    if (delivery['status'] != 'planned' or report.get('status') != 'validated_for_upload'
            or report.get('validatedArtifact') != 'app-store-connect-export-from-archive'
            or any(report.get(key) != delivery[key] for key in ('bundleIdentifier', 'teamIdentifier', 'marketingVersion', 'buildNumber'))
            or report.get('packageSHA256') != digest(args.ipa)):
        raise ReleaseError('Upload package is not the validated release artifact.')
    key_id, issuer = environment.get('ASC_KEY_ID', ''), environment.get('ASC_ISSUER_ID', '')
    key_path = Path(environment.get('ASC_PRIVATE_KEY_PATH', ''))
    if (environment.get('ASC_KEY_TYPE') != 'team' or not re.fullmatch(r'[A-Z0-9]{10}', key_id)
            or not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', issuer)
            or not key_path.is_file()):
        raise ReleaseError('Complete approved team-key fields and a temporary key file are required.')
    # Pass a file path, never the private key value. Capture all upstream output; publish only fixed statuses.
    command = ['xcrun', 'altool', '--upload-package', str(args.ipa), '--api-key', key_id,
               '--api-issuer', issuer, '--p8-file-path', str(key_path), '--output-format', 'json']
    result_report = {key: delivery[key] for key in ('bundleIdentifier', 'teamIdentifier', 'marketingVersion', 'buildNumber')}
    try:
        result = subprocess.run(command, capture_output=True, env=environment, timeout=1200)
        status = 'upload_accepted' if result.returncode == 0 else 'upload_failed_or_unknown'
    except (OSError, subprocess.TimeoutExpired):
        status = 'upload_failed_or_unknown'
    result_report.update(status=status, processing='not_verified', installation='not_verified')
    args.output.write_text(json.dumps(result_report, indent=2) + '\n', encoding='utf-8')
    print('Upload accepted; Apple processing and iPhone installation are not yet verified.' if status == 'upload_accepted'
          else 'Upload failed or its result is unknown; check App Store Connect before retrying. Raw output was not logged.')
    return 0 if status == 'upload_accepted' else 1


def processing(app, delivery, reader):
    verify_plan(app, delivery)
    records = read_records(reader, ['builds', 'list', '--app', app_id(reader, app), '--platform', 'IOS',
                                   '--version', delivery['marketingVersion'], '--build-number', delivery['buildNumber'],
                                   '--processing-state', 'all'])
    state = 'not_visible_yet'
    if records:
        if len(records) != 1 or records[0].get('attributes', {}).get('version') != delivery['buildNumber']:
            raise ReleaseError('Processing read did not identify exactly the uploaded build.')
        state = records[0].get('attributes', {}).get('processingState')
        if state not in ('PROCESSING', 'VALID', 'FAILED', 'INVALID'):
            raise ReleaseError('Apple build processing state is unknown.')
    return {key: delivery[key] for key in ('bundleIdentifier', 'marketingVersion', 'buildNumber')} | {
        'status': state, 'testFlightAvailability': 'not_verified', 'installation': 'not_verified'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('prepare', 'plan', 'verify', 'validate', 'upload', 'processing'):
        command = sub.add_parser(name)
        command.add_argument('--configuration', type=Path, required=True)
        command.add_argument('--output', type=Path, required=name != 'verify')
        if name in ('prepare', 'plan', 'processing'):
            if name != 'processing':
                command.add_argument('--run-number', type=int, required=True)
                command.add_argument('--run-attempt', type=int, required=True)
            if name != 'prepare':
                command.add_argument('--account', action='store_true', required=True)
                command.add_argument('--asc', type=Path, required=True)
        if name == 'prepare':
            command.add_argument('--export-options', type=Path, required=True)
            command.add_argument('--template', type=Path, default=ROOT / 'config/ExportOptions-TestFlight.plist')
        if name in ('verify', 'validate', 'upload', 'processing'):
            command.add_argument('--plan', type=Path, required=True)
        if name in ('verify', 'validate'):
            command.add_argument('--archive', type=Path, required=True)
        if name in ('validate', 'upload'):
            command.add_argument('--ipa', type=Path, required=True)
        if name == 'upload':
            command.add_argument('--perform-upload', action='store_true')
            command.add_argument('--validation', type=Path, required=True)
    args = parser.parse_args()
    try:
        app = configuration(args.configuration)
        if args.command == 'upload':
            return upload(args, dict(os.environ))
        if args.command == 'verify':
            verify_apps(app, json.loads(args.plan.read_text(encoding='utf-8')), args.archive)
            print('Unsigned archive identity and version match the release plan.')
            return 0
        if args.command == 'validate':
            report = validate_package(args)
        elif args.command == 'prepare':
            prepare_options(app, args.template, args.export_options)
            report = plan(app, args.run_number, args.run_attempt, base=os.environ.get('TESTFLIGHT_BUILD_NUMBER_BASE'))
        else:
            if not args.asc.is_file():
                raise ReleaseError('Pinned App Store Connect CLI is missing.')
            with tempfile.TemporaryDirectory(prefix='testflight-reads-') as directory:
                reader = Reader(args.asc, os.environ, directory)
                report = plan(app, args.run_number, args.run_attempt, reader, os.environ.get('TESTFLIGHT_BUILD_NUMBER_BASE')) if args.command == 'plan' else processing(
                    app, json.loads(args.plan.read_text(encoding='utf-8')), reader)
        args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print('Wrote sanitized TestFlight report; report status does not establish device installation.')
        if args.command == 'processing' and report['status'] in ('FAILED', 'INVALID'):
            print('Apple processing failed; inspect App Store Connect before another upload.')
            return 1
        return 0
    except (OSError, ValueError, TypeError, KeyError, AttributeError, plistlib.InvalidFileException) as error:
        message = str(error) if isinstance(error, ReleaseError) else 'TestFlight operation could not establish a verified result; raw account/signing output was not logged.'
        parser.exit(1, message + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
