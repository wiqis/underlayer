#!/usr/bin/env python3
"""E6: generate the paid course's graded bank with the EXISTING bank pipeline.

The shared generator (generate_graded_banks.py) derives every key from a lesson's
own verified text and carries the citation in source_ref/source_quote. Its
`concept_sources` helper only looks in content/src/, which is owned by other
work packages, so this wrapper feeds it the E6 lesson files directly instead:
it calls the same `qualified_quiz_items` / `table_items` / `dump_items` readers
on courses/binread/src/<concept>.ch. No new claim is authored here and nothing
outside the paid course is written.

Stdlib only. No network, no shell, no production URL.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_graded_banks as bank  # existing, verified extraction rules

COURSE = 'binread'


def manifest_path():
    return os.path.join('courses', COURSE, 'manifest.json')


def lesson_path(concept_id):
    return os.path.join('courses', COURSE, 'src', concept_id.replace('-', '_') + '.ch')


def generate():
    with open(manifest_path(), encoding='utf-8') as handle:
        manifest = json.load(handle)
    items = []
    for concept in manifest.get('concepts', []):
        cid = concept['id']
        path = lesson_path(cid)
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
        rel = path.replace(os.sep, '/')
        found = list(bank.qualified_quiz_items(text, rel))
        if not found:
            found = list(bank.table_items(text, rel))
        if not found:
            found = list(bank.dump_items(text, rel))
        if not found:
            raise SystemExit('no verified source for concept %s' % cid)
        for item, method in found:
            item['concept_id'] = cid
            items.append(item)
    return items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', help='write JSON here instead of stdout')
    args = parser.parse_args()
    items = generate()
    payload = json.dumps(items, indent=2, ensure_ascii=False) + '\n'
    if args.out:
        with open(args.out, 'w', encoding='utf-8') as handle:
            handle.write(payload)
        print('wrote %d items to %s' % (len(items), args.out))
    else:
        sys.stdout.write(payload)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
