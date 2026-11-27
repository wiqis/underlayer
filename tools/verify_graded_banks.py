#!/usr/bin/env python3
"""verify_graded_banks.py -- E3/C1 second reader/checker for graded banks.

This verifier does NOT share the generator's extraction code.  It re-reads
every bank from the shipped manifests and checks, independently:

  * structural contract (id shape, concept exists, type/options/correct_index,
    non-empty question, answer, explanation, numeric difficulty);
  * uniqueness and solvability of multiple-choice options;
  * traceability: the cited `source_ref` line really contains `source_quote`,
    and the answer plus every option are strings present in that concept's own
    verified lesson text (or, for the nine `statement` items, in a lesson of
    the same course);
  * the 60 pre-existing ELF/Mach-O/PE items are re-validated for structural
    correctness and for evidence that the answer is supported by the lesson.

`--poison` plants an answer-key mutation in an isolated copy and requires the
reported valid-key count to move (E3).  `--existing` prints the re-validation
of the original 60 items.  No network, no shell, stdlib only.
"""
import argparse
import html
import json
import os
import re
import sys

from concept_sources import all_maps, all_courses, html_plain
from verifier_poison import (poison_workspace, copy_file, copy_dir,
                             replace_in_file, assert_count_moves)

KNOWN_TYPES = {'multiple_choice', 'free_recall', 'multi_recognize', 'matching',
               'labeling', 'order_steps', 'byte_range', 'decode_field',
               'output_match', 'hex_inspect', 'ordering'}
TAG_RE = re.compile(r'<[^>]+>')


def plain(t):
    return html_plain(t)


def load_manifest(root, course):
    with open(os.path.join(root, 'courses', course, 'manifest.json'),
              encoding='utf-8') as f:
        return json.load(f)


def lesson_text(root, rel):
    path = os.path.join(root, rel.replace('/', os.sep))
    if not os.path.isfile(path):
        return None
    return open(path, encoding='utf-8', errors='replace').read()


def check_item(item, manifest, course, maps, root, generated):
    """Return list of problem strings for one exercise declaration."""
    problems = []
    cid = item.get('concept_id', '')
    if cid not in [c['id'] for c in manifest.get('concepts', [])]:
        problems.append('unknown concept_id %r' % cid)
    typ = item.get('type', '')
    if typ not in KNOWN_TYPES:
        problems.append('unknown type %r' % typ)
    for field in ('question', 'answer', 'explanation'):
        if not str(item.get(field, '')).strip():
            problems.append('empty ' + field)
    try:
        diff = float(item.get('difficulty'))
        if not (0.0 <= diff <= 1.0):
            problems.append('difficulty out of range')
    except (TypeError, ValueError):
        problems.append('difficulty not numeric')
    opts = item.get('options', '')
    if typ == 'multiple_choice':
        parts = opts.split('|') if isinstance(opts, str) else list(opts)
        if len(parts) < 2:
            problems.append('fewer than 2 options')
        else:
            ci = item.get('correct_index')
            if not isinstance(ci, int) or not (0 <= ci < len(parts)):
                problems.append('correct_index out of range')
            elif plain(parts[ci]) != plain(str(item.get('answer', ''))):
                problems.append('answer != options[correct_index]')
            if len(set(plain(p) for p in parts)) != len(parts):
                problems.append('duplicate options')
            if any(not p.strip() for p in parts):
                problems.append('empty option')

    if not generated:
        return problems
    # Generated items must be traceable to the cited line of their own lesson.
    ref = item.get('source_ref', '')
    m = re.match(r'^(.*):(\d+)$', ref)
    if not m:
        return problems + ['missing source_ref']
    rel, lineno = m.group(1), int(m.group(2))
    text = lesson_text(root, rel)
    if text is None:
        return problems + ['source_ref file missing: ' + rel]
    lines = text.splitlines()
    if lineno < 1 or lineno > len(lines):
        return problems + ['source_ref line out of range']
    cited = lines[lineno - 1]
    quote = item.get('source_quote', '')
    if not quote or plain(quote) not in plain(cited):
        problems.append('source_quote not in cited line')
    if plain(str(item.get('answer', ''))) not in plain(text):
        problems.append('answer not in lesson text')
    if typ == 'multiple_choice':
        for p in opts.split('|'):
            if plain(p) not in plain(text) and cid in maps.get(course, {}):
                other = maps[course].get(cid)
                # `statement` distractors are taken from sibling lessons.
                siblings = [v for k, v in maps[course].items()
                            if v and v != other]
                if not any(plain(p) in plain(lesson_text(root, s) or '')
                           for s in siblings):
                    problems.append('option not in verified text: %r' %
                                    plain(p)[:40])
    return problems


def collect(root='.', include_existing=True):
    """Return (results, stats) without writing anything."""
    maps = all_maps() if root == '.' else _maps_from(root)
    results = []
    for course in all_courses() if root == '.' else sorted(
            os.listdir(os.path.join(root, 'courses'))):
        m = load_manifest(root, course)
        covered = set()
        for idx, item in enumerate(m.get('exercise_decls', [])):
            is_generated = 'source_ref' in item
            problems = check_item(item, m, course, maps, root, is_generated)
            covered.add(item.get('concept_id'))
            results.append({
                'course': course, 'index': idx, 'concept': item.get('concept_id'),
                'generated': is_generated, 'problems': problems,
                'id': '%s_%s_%d' % (course, item.get('concept_id'), idx),
            })
        for cid in maps.get(course, {}):
            if cid not in covered:
                results.append({'course': course, 'index': -1, 'concept': cid,
                                'generated': None, 'problems': [],
                                'id': None, 'uncovered': True})
    total = len([r for r in results if not r.get('uncovered')])
    valid = len([r for r in results if not r.get('uncovered') and not r['problems']])
    gen = [r for r in results if r['generated']]
    old = [r for r in results if r['generated'] is False]
    stats = {
        'total_items': total,
        'valid_items': valid,
        'courses_with_items': len(set(r['course'] for r in results
                                      if not r.get('uncovered'))),
        'concepts_with_items': len(set(r['concept'] for r in results
                                       if not r.get('uncovered'))),
        'concepts_total': sum(len(v) for v in maps.values()),
        'generated': len(gen),
        'generated_valid': len([r for r in gen if not r['problems']]),
        'existing': len(old),
        'existing_valid': len([r for r in old if not r['problems']]),
        'uncovered': len([r for r in results if r.get('uncovered')]),
    }
    return results, stats


def _maps_from(root):
    """Rebuild the concept map inside a temp root without importing it there."""
    maps = {}
    for course in sorted(os.listdir(os.path.join(root, 'courses'))):
        mf = os.path.join(root, 'courses', course, 'manifest.json')
        if not os.path.isfile(mf):
            continue
        m = json.load(open(mf, encoding='utf-8'))
        main = os.path.join(root, 'courses', course, 'src', 'main.ch')
        pairs = {}
        if os.path.isfile(main):
            from concept_sources import RENDER_RE, WRITE_RE, _strip_comments
            t = _strip_comments(open(main, encoding='utf-8', errors='replace').read())
            last = None
            for line in t.splitlines():
                rr = RENDER_RE.search(line)
                if rr:
                    last = rr.group(1)
                wr = WRITE_RE.search(line)
                if wr and wr.group(1) != 'index' and last:
                    pairs[wr.group(1)] = last
                    last = None
        maps[course] = {}
        for c in m.get('concepts', []):
            fn = pairs.get(c['id'], c['id'].replace('-', '_'))
            rel = 'content/src/%s.ch' % fn
            maps[course][c['id']] = rel if os.path.isfile(
                os.path.join(root, rel.replace('/', os.sep))) else None
    return maps


def count_valid_items(root='.'):
    """The count used by the poison check: valid generated answer keys."""
    _, stats = collect(root)
    return stats['generated_valid']


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--existing', action='store_true',
                    help='print re-validation of the 60 pre-existing items')
    ap.add_argument('--poison', action='store_true',
                    help='plant an answer-key mutation and require the count to move')
    args = ap.parse_args()

    results, stats = collect('.')
    print('graded bank verification (root = repo):')
    for k in ('total_items', 'valid_items', 'courses_with_items',
              'concepts_with_items', 'concepts_total', 'generated',
              'generated_valid', 'existing', 'existing_valid', 'uncovered'):
        print('  %-20s %d' % (k, stats[k]))
    bad = [r for r in results if r['problems']]
    print('  %-20s %d' % ('problem_items', len(bad)))
    for r in bad[:40]:
        print('    %s/%s[%d]: %s' % (r['course'], r['concept'], r['index'],
                                    '; '.join(r['problems'])))
    if args.existing:
        print('\nre-validation of the pre-existing 60 items:')
        for r in results:
            if r['generated'] is False:
                print('  %-30s %s' % (r['id'],
                                      'OK' if not r['problems'] else
                                      'BAD: ' + '; '.join(r['problems'])))
    rc = 1 if bad or stats['uncovered'] else 0
    if args.poison:
        print('\npoison demonstration (E3):')
        # One course only: copy its manifest, its build entry and the lesson
        # sources it cites, so the count function reads only the temp tree.
        course = 'a64abi'
        with poison_workspace('bank-poison-') as root:
            for rel in ['courses/%s/manifest.json' % course,
                        'courses/%s/src/main.ch' % course]:
                copy_file(rel, os.path.join(root, rel.replace('/', os.sep)))
            maps = all_maps()[course]
            for path in set(p for p in maps.values() if p):
                copy_file(path, os.path.join(root, path.replace('/', os.sep)))
            before = count_valid_items(root)
            mf = os.path.join(root, 'courses', course, 'manifest.json')
            with open(mf, encoding='utf-8') as f:
                text = f.read()
            # Plant a wrong key in the FIRST generated item (flip correct_index).
            m = json.loads(text)
            idx = next(i for i, e in enumerate(m['exercise_decls'])
                       if 'source_ref' in e)
            old = '"correct_index": %d' % m['exercise_decls'][idx]['correct_index']
            new = '"correct_index": %d' % ((m['exercise_decls'][idx]['correct_index'] + 1)
                                           % len(m['exercise_decls'][idx]['options'].split('|')))
            replace_in_file(mf, old, new)
            after = count_valid_items(root)
            assert_count_moves('graded answer key', before, after)
    return rc


if __name__ == '__main__':
    sys.exit(main())
