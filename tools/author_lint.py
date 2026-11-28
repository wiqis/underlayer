#!/usr/bin/env python3
"""G12 — lint one structured concept file before generation.

Checks objective wording, takeaway length/question-mark rule, eight-unit
shape, no invented byte/number claims (every numeric token in a unit must be
verbatim present on that unit's cited verified source line) and answer-key
traceability (quote on the cited line, answer equals the keyed option and is
present in the source lesson). Stdlib only; --selftest plants each failure.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KINDS = ('why', 'model', 'reality', 'example', 'interact', 'retrieve',
         'apply', 'connect')
PREFIX = 'In this step you will be able to '
TOKEN_RE = re.compile(r'0x[0-9a-fA-F]+|\b[0-9a-fA-F]{2}\b|\b\d+\b')


def source_line(ref):
    m = re.match(r'^(.*):(\d+)$', ref)
    if not m:
        return None
    path = ROOT / m.group(1)
    if not path.is_file():
        return None
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    n = int(m.group(2))
    return lines[n - 1] if 0 < n <= len(lines) else None


def check(spec):
    problems = []
    objective = spec.get('objective', '')
    if not objective.startswith(PREFIX) or len(objective) <= len(PREFIX) + 8:
        problems.append('objective must say "%s..."' % PREFIX)
    if not objective.endswith('.'):
        problems.append('objective must be a complete sentence ending in a full stop')
    takeaway = spec.get('takeaway', '')
    if not takeaway or len(takeaway) > 180:
        problems.append('takeaway must be non-empty and <= 180 characters')
    if '?' in takeaway:
        problems.append('takeaway must be a statement, not a question')
    units = spec.get('units', [])
    if [u.get('kind') for u in units] != list(KINDS):
        problems.append('expected the eight named units in teaching order')
    for u in units:
        for field in ('heading', 'text'):
            if not str(u.get(field, '')).strip():
                problems.append('empty %s in %s unit' % (field, u.get('kind')))
        ref = '%s:%s' % (spec.get('source_ref', ''), u.get('source_line', 0))
        line = source_line(ref)
        if line is None:
            problems.append('unreadable source line for %s' % u.get('kind'))
            continue
        for token in TOKEN_RE.findall(u.get('text', '')):
            if token not in line:
                problems.append('invented claim %r in %s unit (not on %s)' % (
                    token, u.get('kind'), ref))
    key = spec.get('answer_key', {})
    line = source_line(key.get('source_ref', ''))
    if line is None or key.get('source_quote', '') not in line:
        problems.append('answer-key quote is not on the cited verified line')
    options = key.get('options', [])
    ci = key.get('correct_index', -1)
    if not isinstance(ci, int) or not (0 <= ci < len(options)):
        problems.append('correct_index out of range')
    elif options[ci] != key.get('answer'):
        problems.append('answer != options[correct_index]')
    return problems


def selftest():
    good = json.loads((ROOT / 'content/authoring/elf/bytes.json').read_text(
        encoding='utf-8'))
    ok = not check(good)
    print(('PASS' if ok else 'FAIL') + ': pilot structured file accepted')
    plants = [
        ('bad objective wording', dict(good, objective='Learn about bytes.')),
        ('question takeaway', dict(good, takeaway='What is a byte?')),
        ('long takeaway', dict(good, takeaway='x' * 181)),
        ('invented byte claim', dict(good, units=[
            dict(good['units'][0], text='0xDEADBEEF is the byte we use.')] +
            good['units'][1:])),
        ('answer key not traceable', dict(good, answer_key=dict(
            good['answer_key'], source_quote='DEADBEEF'))),
    ]
    for label, spec in plants:
        bad = check(spec)
        ok = ok and bool(bad)
        print(('%s: %s rejected (%s)' % ('PASS' if bad else 'FAIL', label,
                                         '; '.join(bad) or 'none')))
    print('AUTHOR LINT SELFTEST %s' % ('6/6 — controls accepted, plants rejected'
                                       if ok else 'incomplete'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('file', nargs='?', default='content/authoring/elf/bytes.json')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    path = Path(args.file)
    if not path.is_absolute():
        path = ROOT / path
    spec = json.loads(path.read_text(encoding='utf-8'))
    problems = check(spec)
    for item in problems:
        print('FAIL ' + item)
    print('AUTHOR LINT %d failure(s)' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
