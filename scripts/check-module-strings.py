#!/usr/bin/env python3
"""Check that each module's string catalog holds exactly the strings its sources look up.

Module code looks up user-facing text in its own bundle, always written as a literal followed
directly by `bundle: .module`, for example `Text("Choose one", bundle: .module)`,
`String(localized: "Not set.", bundle: .module)` or `LocalizedStringResource("Skip", bundle: .module)`.
Those keys must be in `Modules/<Name>/Sources/Resources/Localizable.xcstrings`, and the catalog must
hold no others. `--update` adds missing keys, with their English value, and drops unused ones,
keeping existing translations.
String interpolations become `%@` (the template interpolates strings only).
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LOOKUP = re.compile(r'"((?:[^"\\\n]|\\.)*)"\s*,\s*bundle:\s*\.module\b')
INTERPOLATION = re.compile(r'\\\((?:[^()]|\([^()]*\))*\)')


def key(literal):
    return INTERPOLATION.sub('%@', literal).replace('\\"', '"').replace('\\\\', '\\')


def source_entry(name):
    """A new key with its English value spelled out; an entry without one compiles to nothing."""
    return {'extractionState': 'manual',
            'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': name}}}}


def used_keys(sources):
    keys = set()
    for path in sorted(sources.rglob('*.swift')):
        keys.update(key(match) for match in LOOKUP.findall(path.read_text(encoding='utf-8')))
    return keys


def check(module, update=False):
    """Problems for one module folder; with `update`, rewrite its catalog instead."""
    sources = module / 'Sources'
    catalog_path = sources / 'Resources' / 'Localizable.xcstrings'
    keys = used_keys(sources)
    catalog = (json.loads(catalog_path.read_text(encoding='utf-8')) if catalog_path.exists()
               else {'sourceLanguage': 'en', 'strings': {}, 'version': '1.0'})
    stored = set(catalog['strings'])
    if update:
        if keys or catalog_path.exists():
            catalog['strings'] = {name: catalog['strings'].get(name) or source_entry(name) for name in sorted(keys)}
            catalog_path.parent.mkdir(parents=True, exist_ok=True)
            catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        return []
    problems = [f'{module.name}: {name!r} is looked up but missing from Modules/{module.name}/Sources/Resources/Localizable.xcstrings'
                for name in sorted(keys - stored)]
    problems += [f'{module.name}: {name!r} is in the catalog but no source looks it up'
                 for name in sorted(stored - keys)]
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--update', action='store_true', help='rewrite the catalogs to match the sources')
    parser.add_argument('--modules', type=Path, default=ROOT / 'Modules')
    args = parser.parse_args(argv)
    problems = []
    for module in sorted(path for path in args.modules.iterdir() if (path / 'Sources').is_dir()):
        problems += check(module, update=args.update)
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        print('Run python scripts/check-module-strings.py --update, then translate any new keys.', file=sys.stderr)
        return 1
    print('Module string catalogs match their sources.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
