#!/usr/bin/env python3
"""G5 — served-artifact contract for the four new graded types and six labs.

Checks the running server, not the source: GET /api/exercises/<concept> must
report the new type ids, and POST /api/exercises/submit must grade a key copied
from verified text as correct and a perturbed key as incorrect. Every specimen
lab's bundle must exist on disk. Stdlib only, explicit timeouts, local base
unless --allow-remote, negative plants via --selftest.
"""
import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / 'content' / 'authoring' / 'g5_exercises.json'
TYPES = {'order_steps', 'byte_range', 'decode_field', 'output_match',
         'specimen_lab'}
TIMEOUT = 20


def fetch(base, path, method='GET'):
    req = urllib.request.Request(base.rstrip('/') + path, method=method,
                                 headers={'User-Agent': 'g5-check/1'})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.status, json.loads(resp.read().decode('utf-8', 'replace'))


def local(base):
    return (urllib.parse.urlsplit(base).hostname or '') in (
        'localhost', '127.0.0.1', '::1')


def served_types(concept_payload):
    return {item.get('id'): item.get('type')
            for item in concept_payload.get('exercises', [])}


def evaluate(items, banks, submissions):
    problems = []
    for item in items:
        bank = banks.get(item['concept_id'], {})
        expected_id = None
        for eid, typ in bank.items():
            if typ == item['type']:
                expected_id = eid
                break
        if expected_id is None:
            problems.append('%s: type %s not served' % (
                item['concept_id'], item['type']))
            continue
        key = '%s/%s' % (item['concept_id'], item['type'])
        if submissions.get(key) != (True, False):
            problems.append('%s: right/wrong grading = %r' % (
                key, submissions.get(key)))
        if item['type'] == 'specimen_lab':
            bundle = (ROOT / 'courses' / item['course'] / 'assets' / 'samples' /
                      ('%s-specimen.zip' % item['course']))
            if not bundle.is_file():
                problems.append('bundle missing: %s' % bundle.name)
    if set(i['type'] for i in items) != TYPES:
        problems.append('expected types not all present')
    return problems


def selftest():
    good_item = {'concept_id': 'bytes', 'type': 'byte_range', 'course': 'elf'}
    all_items = [dict(good_item, concept_id=c, type=t)
                 for c, t in (('bytes', 'byte_range'), ('link-order', 'order_steps'),
                              ('x86-frame', 'decode_field'),
                              ('jvm-header', 'output_match'),
                              ('a64-aapcs', 'specimen_lab'))]
    banks = {'bytes': {'elf_bytes_32': 'byte_range'},
             'link-order': {'link_link-order_10': 'order_steps'},
             'x86-frame': {'x86abi_x86-frame_6': 'decode_field'},
             'jvm-header': {'jvm_jvm-header_18': 'output_match'},
             'a64-aapcs': {'a64abi_a64-aapcs_5': 'specimen_lab'}}
    good_sub = {'%s/%s' % (i['concept_id'], i['type']): (True, False)
                for i in all_items}
    good = not evaluate(all_items, banks, good_sub)
    print(('PASS' if good else 'FAIL') + ': good G5 served contract accepted')
    plants = [
        ('type missing from served bank', all_items, {}, good_sub),
        ('wrong answer graded as right', all_items, banks,
         dict(good_sub, **{'bytes/byte_range': (False, False)})),
        ('missing bundle', all_items[:-1] + [dict(all_items[-1], course='nosuch')],
         banks, good_sub),
    ]
    ok = good
    for label, items, b, s in plants:
        bad = evaluate(items, b, s)
        ok = ok and bool(bad)
        print(('%s: %s rejected (%s)' % ('PASS' if bad else 'FAIL', label,
                                         '; '.join(bad) or 'none')))
    print('G5 SELFTEST %s' % ('4/4 — controls accepted, plants rejected'
                              if ok else 'incomplete'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', default='http://127.0.0.1:9066')
    ap.add_argument('--allow-remote', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not local(args.base) and not args.allow_remote:
        print('REFUSED: non-local base (pass --allow-remote)')
        return 2
    items = json.loads(SPEC.read_text(encoding='utf-8'))['items']
    banks = {}
    problems = []
    for cid in sorted(set(i['concept_id'] for i in items)):
        try:
            status, payload = fetch(args.base, '/api/exercises/' + cid)
        except (urllib.error.URLError, OSError, ValueError) as exc:
            problems.append('GET %s: %s' % (cid, exc))
            continue
        if status != 200:
            problems.append('GET %s: HTTP %s' % (cid, status))
            continue
        banks[cid] = served_types(payload)

    submissions = {}
    for item in items:
        correct = item['answer']
        wrong = ('zz-' + correct[:12]) if correct else 'zz-wrong'
        key = '%s/%s' % (item['concept_id'], item['type'])
        outcomes = []
        for answer in (correct, wrong):
            query = urllib.parse.urlencode({'exercise_id': '', 'answer': answer})
            # Find the id the server actually served for this type.
            eid = None
            for e, typ in banks.get(item['concept_id'], {}).items():
                if typ == item['type']:
                    eid = e
                    break
            if not eid:
                outcomes.append(None)
                continue
            query = urllib.parse.urlencode({'exercise_id': eid, 'answer': answer})
            try:
                status, body = fetch(args.base, '/api/exercises/submit?' + query,
                                     method='POST')
            except (urllib.error.URLError, OSError, ValueError) as exc:
                outcomes.append('transport: %s' % exc)
                continue
            outcomes.append(body.get('correct') if status == 200 else 'HTTP %s' % status)
        submissions[key] = tuple(outcomes)
        print('%-34s right=%r wrong=%r' % (key, outcomes[0], outcomes[1]))

    problems.extend(evaluate(items, banks, submissions))
    for item in problems:
        print('FAIL ' + item)
    print('G5 TYPES CHECK %d failure(s)' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
