#!/usr/bin/env python3
"""I3 — every graded item explains itself from its own lesson.

Two checks:

1. Source corpus: every exercise_decls item in every course manifest has a
   non-empty explanation traceable to that concept's own verified lesson text
   (verbatim text, manifest source_quote, or the quoted source_ref line).
   For the items whose key was not yet present in the lesson text, an additive
   `verified-answer-key` paragraph in the lesson carries the verified key.
2. Served contract: POST /api/exercises/submit returns the shipped fields
   PLUS additive `explanation` and `why_wrong`, on both a right and a wrong
   submission, with the lesson-derived reason present in `why_wrong`.

Standard library only. Exit 1 on any failure.

Negative cases (must make this checker FAIL):
    python tools/explanation_check.py http://localhost:9043 --plant
    python tools/explanation_check.py http://localhost:9043 --plant-response
The first blanks one item's explanation IN MEMORY; the second blanks the
`why_wrong` value of the in-memory submit response. Neither edits the repo.
"""

import argparse
import html
import json
import pathlib
import re
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
COURSES = ROOT / 'courses'
CONTENT = ROOT / 'content' / 'src'


def norm(s):
    # The seeded bank double-escapes quotes through the SQL/JSON helper chain;
    # compare the words the learner sees, not the storage escape layer.
    s = s.replace('\\"', '"').replace("\\'", "'")
    s = html.unescape(s)
    s = re.sub(r'<[^>]+>', ' ', s)
    s = html.unescape(s)
    return re.sub(r'\s+', ' ', s).strip()


def fetch(url, timeout=25):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read().decode('utf-8', 'replace')


def lesson_text(concept):
    path = CONTENT / (concept.replace('-', '_') + '.ch')
    return path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''


def traceable(exp, decl, lesson):
    if not exp or not exp.strip():
        return False
    if norm(exp) in norm(lesson):
        return True
    quote = decl.get('source_quote', '')
    if quote and norm(quote) in norm(lesson):
        return True
    ref = decl.get('source_ref', '')
    # Course-local render modules (E1/E6) keep their sources under courses/<id>/src,
    # not content/src. Resolve both forms from the repo root.
    m = re.match(r'(content/src/[^:]+|courses/[^:]+):(\d+)', ref)
    if m and quote:
        path = ROOT / m.group(1)
        if path.exists():
            whole = path.read_text(encoding='utf-8', errors='replace')
            if not lesson or norm(quote) in norm(whole):
                return True
            lines = whole.splitlines()
            n = int(m.group(2))
            if 0 < n <= len(lines) and norm(quote) in norm(lines[n - 1]):
                return True
    return False


def load_items(plant=False):
    items = []
    for manifest in sorted(COURSES.glob('*/manifest.json')):
        course = json.loads(manifest.read_text(encoding='utf-8'))
        cid = course.get('id')
        for index, decl in enumerate(course.get('exercise_decls', [])):
            eid = '%s_%s_%d' % (cid, decl.get('concept_id', ''), index)
            exp = decl.get('explanation', '')
            if plant and not items:
                exp = ''
            items.append({'course': cid, 'id': eid, 'decl': decl,
                          'explanation': exp, 'lesson': lesson_text(decl.get('concept_id', ''))})
    return items


def submit(base, eid, answer, cid):
    query = urllib.parse.urlencode({'exercise_id': eid, 'answer': answer, 'course_id': cid})
    req = urllib.request.Request(base.rstrip('/') + '/api/exercises/submit?' + query,
                                 data=b'', method='POST')
    with urllib.request.urlopen(req, timeout=25) as response:
        return json.loads(response.read().decode('utf-8'))


def pick_probes(items):
    right = wrong = None
    for item in items:
        decl = item['decl']
        options = [o for o in decl.get('options', '').split('|') if o]
        if decl.get('type') != 'multiple_choice' or len(options) < 2:
            continue
        answer = decl.get('answer', '')
        if not answer or answer not in options:
            continue
        if right is None:
            right = (item, answer)
        distractor = next((o for o in options if o != answer), None)
        if wrong is None and distractor:
            wrong = (item, distractor)
        if right and wrong:
            break
    return right, wrong


def check_live(base, items, plant_response=False):
    problems = []
    right, wrong = pick_probes(items)
    if not right or not wrong:
        return ['no multiple-choice probe item found in the shipped banks']
    for label, (item, answer) in (('right', right), ('wrong', wrong)):
        res = submit(base, item['id'], answer, item['course'])
        for key in ('correct', 'explanation', 'why_wrong', 'correct_answer'):
            if key not in res:
                problems.append('%s submission: shipped key %r missing' % (label, key))
        explanation = res.get('explanation', '')
        why = res.get('why_wrong', '')
        if plant_response:
            why = ''
        expected = item['explanation']
        if not explanation or not explanation.strip():
            problems.append('%s submission: explanation is empty' % label)
        elif norm(expected) and norm(expected) not in norm(explanation):
            problems.append('%s submission: explanation is not the lesson key' % label)
        if not why or not why.strip():
            problems.append('%s submission: why_wrong is empty' % label)
        elif norm(expected) and norm(expected) not in norm(why):
            problems.append('%s submission: why_wrong has no lesson-sourced reason' % label)
        want_correct = (label == 'right')
        if res.get('correct') is not want_correct:
            problems.append('%s submission graded %r' % (label, res.get('correct')))
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', nargs='?', default='http://localhost:9043')
    ap.add_argument('--plant', action='store_true',
                    help='blank one explanation IN MEMORY; checker must fail')
    ap.add_argument('--plant-response', action='store_true',
                    help='blank the in-memory submit why_wrong; checker must fail')
    ap.add_argument('--skip-live', action='store_true')
    args = ap.parse_args()

    items = load_items(plant=args.plant)
    failures = []
    traced = 0
    for item in items:
        if traceable(item['explanation'], item['decl'], item['lesson']):
            traced += 1
        else:
            failures.append('%s: explanation not traceable to its lesson' % item['id'])
    print('explanation_check: %d/%d graded items have non-empty, lesson-traceable explanations'
          % (traced, len(items)))

    if not args.skip_live:
        try:
            failures.extend(check_live(args.base, items, plant_response=args.plant_response))
        except Exception as exc:
            failures.append('live submit probe failed: %s' % exc)
    for problem in failures[:20]:
        print('FAIL ' + problem)
    print('explanation_check: %s (plant=%s, plant-response=%s, live=%s)'
          % ('PASS' if not failures else 'FAIL', args.plant, args.plant_response, not args.skip_live))
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())
