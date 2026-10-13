#!/usr/bin/env python3
"""Verify archive app/dSYM UUIDs; optionally copy only symbols for controlled retention."""
import argparse
import json
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path


def uuids(path):
    result = subprocess.run(['xcrun', 'dwarfdump', '--uuid', str(path)], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError('Unable to inspect binary UUIDs.')
    pairs = re.findall(r'^UUID: ([0-9A-Fa-f-]{36}) \(([^)]+)\)', result.stdout, re.MULTILINE)
    if not pairs:
        raise ValueError('No binary UUIDs found.')
    return sorted(set((uuid.upper(), arch) for uuid, arch in pairs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--retain', type=Path, help='New directory for symbols only; treat as sensitive build material.')
    parser.add_argument('--ipa', type=Path, help='Also match the exported package executable UUIDs.')
    parser.add_argument('--commit', default='unknown')
    args = parser.parse_args()
    try:
        apps = list((args.archive / 'Products/Applications').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('Expected exactly one archived app.')
        app = apps[0]
        # This starter supports one app; extensions/frameworks need their own checks.
        if (app / 'PlugIns').exists() or list((app / 'Frameworks').glob('*.framework')):
            raise ValueError('Embedded extensions/frameworks require additional symbol validation.')
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        executable = info['CFBundleExecutable']
        if Path(executable).name != executable:
            raise ValueError('Invalid executable name.')
        binary_ids = uuids(app / executable)
        dsym = args.archive / 'dSYMs' / (app.name + '.dSYM')
        dwarf = dsym / 'Contents/Resources/DWARF' / executable
        if uuids(dwarf) != binary_ids:
            raise ValueError('App and dSYM UUIDs do not match.')
        if args.ipa:
            with zipfile.ZipFile(args.ipa) as package, tempfile.TemporaryDirectory() as temporary:
                candidates = [name for name in package.namelist()
                              if re.fullmatch(r'Payload/[^/]+\.app/Info.plist', name)]
                if len(candidates) != 1:
                    raise ValueError('Expected exactly one package app.')
                package_info = plistlib.loads(package.read(candidates[0]))
                for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleExecutable'):
                    if package_info.get(key) != info.get(key):
                        raise ValueError('Package and archive identities differ.')
                packaged_binary = Path(temporary) / 'executable'
                packaged_binary.write_bytes(package.read(candidates[0].rsplit('/', 1)[0] + '/' + executable))
                if uuids(packaged_binary) != binary_ids:
                    raise ValueError('Package and archive UUIDs differ.')
        report = {'status': 'matched', 'bundleIdentifier': info['CFBundleIdentifier'],
                  'marketingVersion': info['CFBundleShortVersionString'], 'buildNumber': info['CFBundleVersion'],
                  'commit': args.commit, 'images': [{'uuid': u, 'architecture': a} for u, a in binary_ids]}
        if args.retain:
            if args.retain.exists():
                raise ValueError('Symbol retention directory must not already exist.')
            args.retain.mkdir(parents=True, mode=0o700)
            shutil.copytree(dsym, args.retain / dsym.name, symlinks=False)
            (args.retain / 'symbols.json').write_text(json.dumps(report, indent=2) + '\n')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
        print('Archived app and debug symbol UUIDs match.')
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        parser.exit(1, 'Release symbol verification failed: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
