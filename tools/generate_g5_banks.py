#!/usr/bin/env python3
"""G5 — append the four new graded types + six specimen labs to manifests.

The generator is a *second reader* of structured authoring data: it refuses to
write any item whose answer (or each pipe-separated part of an order answer)
is not verbatim present in the cited verified lesson file, whose quoted line
does not contain the quote, whose explanation is not in that lesson, or whose
specimen bundle does not exist on disk. It is idempotent via `g5_id`.

Stdlib only. No network, no shell, no production DB. `--check` validates
without writing; `--selftest` plants a wrong quote/key and must reject them.
"""
import argparse
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / 'content' / 'authoring' / 'g5_exercises.json'
TYPES = {'order_steps', 'byte_range', 'decode_field', 'output_match',
         'specimen_lab'}


def norm(text):
    text = html.unescape(text)
    text = re.sub(r'<[^>]+>', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def source_text(ref):
    """Resolve a content/src or courses/<id>/src reference to lesson text."""
    m = re.match(r'^(content/src/[^:]+|courses/[^:]+):(\d+)(?:-\d+)?$', ref)
    if not m:
        return None, None
    path = ROOT / m.group(1)
    if not path.is_file():
        return None, None
    return path.read_text(encoding='utf-8', errors='replace'), int(m.group(2))


def validate(item):
    problems = []
    typ = item.get('type')
    if typ not in TYPES:
        problems.append('unknown type %r' % typ)
    if not item.get('g5_id'):
        problems.append('missing g5_id')
    if not item.get('question') or not item.get('explanation'):
        problems.append('empty question or explanation')
    ref = item.get('source_ref') or item.get('g5_source', '')
    text, lineno = source_text(ref)
    if text is None:
        problems.append('unreadable source_ref %r' % ref)
        return problems
    quote = item.get('source_quote', '')
    if quote and quote not in text.splitlines()[lineno - 1]:
        problems.append('source_quote not on cited line')
    parts = item.get('answer_parts')
    if parts is None:
        parts = [item.get('answer', '')]
    for part in parts:
        if not part or part not in text:
            problems.append('answer part not in verified text: %r' % part[:40])
    if norm(item.get('explanation', '')) not in norm(text):
        problems.append('explanation not traceable to lesson')
    if typ == 'specimen_lab':
        course = item.get('course')
        bundle = ROOT / 'courses' / course / 'assets' / 'samples' / (
            '%s-specimen.zip' % course)
        if not bundle.is_file():
            problems.append('specimen bundle missing: %s' % bundle.name)
    return problems


def load_spec():
    return json.loads(SPEC.read_text(encoding='utf-8'))['items']


def apply(items, write):
    report = []
    for item in items:
        problems = validate(item)
        report.append((item.get('g5_id'), problems))
        if problems:
            continue
        if not write:
            continue
        path = ROOT / 'courses' / item['course'] / 'manifest.json'
        manifest = json.loads(path.read_text(encoding='utf-8'))
        decls = manifest.setdefault('exercise_decls', [])
        if any(d.get('g5_id') == item['g5_id'] for d in decls):
            continue
        ids = [c['id'] for c in manifest.get('concepts', [])]
        if item['concept_id'] not in ids:
            raise SystemExit('unknown concept %s in %s' % (
                item['concept_id'], item['course']))
        decl = {k: v for k, v in item.items() if k != 'course'}
        decl['difficulty'] = float(item.get('difficulty', 0.5))
        decls.append(decl)
        path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return report


def selftest():
    items = load_spec()
    good = items[1]  # byte_range, has a cited quote and key
    plants = [
        ('wrong quote', dict(good, source_quote='DEADBEEF')),
        ('wrong key', dict(good, answer='ff ff ff ff')),
        ('missing bundle', dict(good, type='specimen_lab', course='nosuch')),
        ('untraceable explanation', dict(good, explanation='a made up fact')),
    ]
    ok = not validate(good)
    print(('PASS' if ok else 'FAIL') + ': good G5 item accepted')
    for label, planted in plants:
        bad = validate(planted)
        ok = ok and bool(bad)
        print(('%s: %s rejected (%s)' % ('PASS' if bad else 'FAIL', label,
                                         '; '.join(bad) or 'none')))
    print('G5 SELFTEST %s' % ('5/5 — controls accepted, plants rejected'
                              if ok else 'incomplete'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    report = apply(load_spec(), not args.check)
    bad = [(gid, p) for gid, p in report if p]
    print('G5 items validated: %d/%d' % (len(report) - len(bad), len(report)))
    print('G5 items written: %d' % (0 if args.check else len(report) - len(bad)))
    for gid, problems in bad:
        print('FAIL %s: %s' % (gid, '; '.join(problems)))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
