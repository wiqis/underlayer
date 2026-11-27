#!/usr/bin/env python3
"""generate_graded_banks.py -- C1 graded-bank authoring pipeline.

For every concept that has NO graded item today, derive one graded item from
THAT concept's own verified lesson text (content/src/<render>.ch).  No byte,
offset or spec claim is authored here: every option and every answer is a
verbatim string taken from a cited lesson line, and the citation travels with
the item in `source_ref` / `source_quote`.

Sources, in priority order:
  1. the lesson's own in-page graded quiz (one correct option, its own
     data-explain becomes the key's explanation);
  2. the lesson's own field/value table (answer = a real cell, distractors =
     other cells from the same column);
  3. the lesson's own worked hex dump (answer = the documented bytes);
  4. verbatim statement recognition, last resort only.

Determinism: courses and concepts are visited in sorted order, the first
eligible source in file order wins, and no timestamps or random values are
emitted.  `--out DIR` writes the generated decks as JSON (two runs into two
directories are byte-identical).  `--write` appends the same decks to each
course manifest's `exercise_decls`, leaving existing items untouched.

Usage:
    python tools/generate_graded_banks.py                 # summary only
    python tools/generate_graded_banks.py --out DIR       # deterministic decks
    python tools/generate_graded_banks.py --write         # update manifests
"""
import argparse
import html
import json
import os
import re
import sys

from concept_sources import all_maps, all_courses, html_plain

QUIZ_RE = re.compile(
    r'<div\s+class="quiz"\s+id="([^"]+)"[^>]*>(.*?)</div>', re.S)
BUTTON_RE = re.compile(r'<button\s+class="quiz-option"([^>]*)>(.*?)</button>', re.S)
CORRECT_ATTR_RE = re.compile(r'data-correct="(true|false)"')
EXPLAIN_RE = re.compile(r'data-explain="([^"]*)"')
CORRECT_JS_RE = re.compile(r'checkQuiz\([^)]*,\s*(true|false)\s*\)')
TAG_RE = re.compile(r'<[^>]+>')
P_RE = re.compile(r'<p(?:\s[^>]*)?>(.*?)</p>', re.S)
H2_RE = re.compile(r'<h2(?:\s[^>]*)?>(.*?)</h2>', re.S)
TABLE_RE = re.compile(r'<table(?:\s[^>]*)?>(.*?)</table>', re.S)
TR_RE = re.compile(r'<tr(?:\s[^>]*)?>(.*?)</tr>', re.S)
CELL_RE = re.compile(r'<t[dh](?:\s[^>]*)?>(.*?)</t[dh]>', re.S)
PRE_RE = re.compile(r'<pre(?:\s[^>]*)?>(.*?)</pre>', re.S)
DUMP_RE = re.compile(r'\b([0-9a-fA-F]{4}|[0-9a-fA-F]{8}):\s+((?:[0-9a-fA-F]{2,4}\s+){2,})')


def plain(raw):
    """HTML fragment -> display text, without changing the cited raw string."""
    return html_plain(raw)


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def nearest(text, pos, regex):
    """Last regex match strictly before pos, or None."""
    best = None
    for m in regex.finditer(text, 0, pos):
        best = m
    return best


def qualified_quiz_items(text, relpath):
    """Yield (item_dict, method) from the lesson's own in-page quizzes."""
    for qm in QUIZ_RE.finditer(text):
        buttons = list(BUTTON_RE.finditer(qm.group(2)))
        if len(buttons) < 2:
            continue
        parsed = []
        for bm in buttons:
            attrs, raw_label = bm.group(1), bm.group(2)
            ca = CORRECT_ATTR_RE.search(attrs)
            ja = CORRECT_JS_RE.search(attrs)
            if ca:
                correct = ca.group(1) == 'true'
            elif ja:
                correct = ja.group(1) == 'true'
            else:
                continue
            ex = EXPLAIN_RE.search(attrs)
            label = plain(raw_label)
            parsed.append({
                'correct': correct,
                'label': label,
                'raw_label': raw_label.strip(),
                'explain': plain(ex.group(1)) if ex else '',
                'line': line_of(text, qm.start(2) + bm.start()),
            })
        correct = [p for p in parsed if p['correct']]
        if len(correct) != 1:
            continue
        labels = [p['label'] for p in parsed]
        if len(set(labels)) != len(labels) or any('|' in x or not x for x in labels):
            continue
        key = correct[0]
        prompt = nearest(text, qm.start(), P_RE)
        question = plain(prompt.group(1)) if prompt else \
            'Which answer does this lesson give for its own check question?'
        section = nearest(text, qm.start(), H2_RE)
        hint = ('Re-read the lesson section ' + repr(plain(section.group(1))) + '.') \
            if section else 'Re-read this lesson before answering.'
        ci = labels.index(key['label'])
        explanation = key['explain'] or (question + ' ' + key['label'])
        yield {
            'type': 'multiple_choice',
            'question': question,
            'answer': key['label'],
            'options': '|'.join(labels),
            'correct_index': ci,
            'explanation': explanation,
            'hint1': hint,
            'difficulty': 0.5,
            'source_ref': '%s:%d' % (relpath, key['line']),
            'source_quote': key['raw_label'],
        }, 'quiz'


def table_items(text, relpath):
    """Yield items whose key is a verbatim cell of the lesson's own table."""
    for tm in TABLE_RE.finditer(text):
        rows = list(TR_RE.finditer(tm.group(1)))
        if len(rows) < 2:
            continue
        head = [plain(c) for c in CELL_RE.findall(rows[0].group(1))]
        body = []
        for r in rows[1:]:
            cells = CELL_RE.findall(r.group(1))
            vals = [plain(c) for c in cells]
            if len(vals) == len(head) and vals[0] and all(vals):
                body.append((vals, r, cells))
        if len(body) < 2 or len(set(v[0][0] for v in body)) != len(body):
            continue
        for col in range(1, len(head)):
            values = [v[0][col] for v in body]
            if len(set(values)) < 2 or any(len(v) > 80 or '|' in v for v in values):
                continue
            row, row_match, cells = body[0]
            answer = row[col]
            options = list(dict.fromkeys(values))
            yield {
                'type': 'multiple_choice',
                'question': "According to this lesson's table, what is the %s for %s?" %
                            (head[col], row[0]),
                'answer': answer,
                'options': '|'.join(options),
                'correct_index': options.index(answer),
                'explanation': "The lesson's table gives %s = %s for %s." %
                               (head[col], answer, row[0]),
                'hint1': "Re-read the %s column of this lesson's table." % head[col],
                'difficulty': 0.5,
                'source_ref': '%s:%d' % (relpath, line_of(text, tm.start(1) + row_match.start())),
                'source_quote': plain(cells[col]),
            }, 'table'
            break


def dump_items(text, relpath):
    """Yield items whose key is the bytes of the lesson's own worked dump."""
    found = []
    for pm in PRE_RE.finditer(text):
        pre_line = line_of(text, pm.start(1))
        for li, line in enumerate(pm.group(1).splitlines()):
            m = DUMP_RE.search(line)
            if not m:
                continue
            hexes = re.findall(r'[0-9a-fA-F]{2,4}', m.group(2))
            if len(hexes) < 2:
                continue
            value = ' '.join(h.lower() for h in hexes)
            found.append((m.group(1), value, pre_line + li))
    seen = set()
    for offset, value, line in found:
        if value in seen:
            continue
        seen.add(value)
        others = [v for _, v, _ in found if v != value]
        if not others:
            continue
        options = [value] + others[:2]
        yield {
            'type': 'multiple_choice',
            'question': 'Which bytes does this lesson show in its worked dump at offset %s?' % offset,
            'answer': value,
            'options': '|'.join(options),
            'correct_index': 0,
            'explanation': "The lesson's worked dump at offset %s reads %s." % (offset, value),
            'hint1': 'Look up the offset in this lesson\'s worked hex dump.',
            'difficulty': 0.5,
            'source_ref': '%s:%d' % (relpath, line),
            'source_quote': re.sub(r'<[^>]+>', '', value),
        }, 'dump'


CODE_RE = re.compile(r'<code(?:\s[^>]*)?>(.*?)</code>', re.S)


def cloze_items(text, relpath):
    """Recall item: complete a sentence from this lesson with its own term.

    The correct term is a verbatim <code> term in the cited lesson sentence;
    the distractors are other <code> terms from the SAME lesson.  No value is
    invented and the key is recoverable from the citation alone.
    """
    terms = []
    for m in CODE_RE.finditer(text):
        t = plain(m.group(1))
        if 1 <= len(t) <= 60 and '|' not in t and t not in terms:
            terms.append(t)
    if len(terms) < 3:
        return
    for pm in P_RE.finditer(text):
        raw = pm.group(1)
        cm = CODE_RE.search(raw)
        if not cm:
            continue
        term = plain(cm.group(1))
        if term not in terms or len(term) < 2:
            continue
        sentence = plain(raw)
        if not (50 <= len(sentence) <= 400):
            continue
        masked = plain(raw[:cm.start()] + '______' + raw[cm.end():])
        others = [t for t in terms if t != term][:2]
        if not others:
            continue
        options = [term] + others
        yield {
            'type': 'multiple_choice',
            'question': 'Complete this sentence from the lesson: ' + masked,
            'answer': term,
            'options': '|'.join(options),
            'correct_index': 0,
            'explanation': 'The lesson states: ' + sentence,
            'hint1': 'Find this sentence in the lesson and read the highlighted term.',
            'difficulty': 0.5,
            'source_ref': '%s:%d' % (relpath, line_of(text, pm.start(1) + cm.start())),
            'source_quote': cm.group(1),
        }, 'cloze'
        return


def statement_items(text, relpath, donors):
    """Last resort: identify a sentence quoted verbatim from this lesson."""
    candidates = []
    for unit in ('unit-model', 'unit-reality', 'unit-why'):
        for m in re.finditer(r'<div\s+class="unit\s+%s".*?</div>' % unit, text, re.S):
            for pm in P_RE.finditer(m.group(0)):
                raw = pm.group(1)
                val = plain(raw)
                if 45 <= len(val) <= 260 and '|' not in val:
                    candidates.append((val, raw.strip(),
                                       line_of(text, m.start() + pm.start())))
    if not candidates:
        return
    answer, raw_quote, line = candidates[0]
    pool = [c[0] for c in candidates if c[0] != answer][:2]
    for donor in donors:
        if len(pool) >= 3:
            break
        for val in donor:
            if val != answer and val not in pool:
                pool.append(val)
                if len(pool) >= 3:
                    break
    if len(pool) < 2:
        return
    options = [answer] + pool[:2]
    yield {
        'type': 'multiple_choice',
        'question': 'Which statement is made in this lesson?',
        'answer': answer,
        'options': '|'.join(options),
        'correct_index': 0,
        'explanation': 'This sentence is stated verbatim in this lesson: ' + answer,
        'hint1': 'Re-read the model and detail sections of this lesson.',
        'difficulty': 0.5,
        'source_ref': '%s:%d' % (relpath, line),
        'source_quote': raw_quote,
    }, 'statement'


def build_decks(ignore_generated=False):
    """Return (decks, methods, uncovered) for every concept needing an item.

    ignore_generated is used by the determinism check: it treats already
    generated items as absent so two runs emit the same decks even after the
    banks have been written into the manifests.
    """
    maps = all_maps()
    texts = {}
    for course, cmap in maps.items():
        for path in set(p for p in cmap.values() if p):
            texts[path] = open(path, encoding='utf-8', errors='replace').read()
    decks, methods, uncovered = {}, {}, []
    for course in all_courses():
        m = json.load(open(os.path.join('courses', course, 'manifest.json'),
                           encoding='utf-8'))
        covered = set(e['concept_id'] for e in m.get('exercise_decls', [])
                      if not (ignore_generated and 'source_ref' in e))
        deck = []
        for cid in sorted(maps[course]):
            if cid in covered:
                continue
            path = maps[course][cid]
            if not path:
                uncovered.append((course, cid, 'no source file'))
                continue
            text = texts[path]
            rel = path.replace('\\', '/')
            chosen = None
            for factory in (lambda: qualified_quiz_items(text, rel),
                            lambda: table_items(text, rel),
                            lambda: dump_items(text, rel),
                            lambda: cloze_items(text, rel)):
                for item, method in factory():
                    chosen = (item, method)
                    break
                if chosen:
                    break
            if not chosen:
                donors = []
                for other_cid, other_path in maps[course].items():
                    if other_path and other_path != path and other_cid != cid:
                        donors.append([plain(pm.group(1)) for pm in
                                       P_RE.finditer(texts[other_path])])
                for item, method in statement_items(text, rel, donors):
                    chosen = (item, method)
                    break
            if not chosen:
                uncovered.append((course, cid, 'no extractable verified fact'))
                continue
            item, method = chosen
            item['concept_id'] = cid
            deck.append(item)
            methods[(course, cid)] = method
        if deck:
            decks[course] = deck
    return decks, methods, uncovered


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', help='write deterministic decks to this directory')
    ap.add_argument('--write', action='store_true',
                    help='append generated decks to course manifests')
    ap.add_argument('--reset-generated', action='store_true',
                    help='remove only items carrying source_ref before writing')
    ap.add_argument('--ignore-existing-generated', action='store_true',
                    help='rebuild decks even when manifests already carry them '
                         '(use with --out for a non-vacuous determinism diff)')
    args = ap.parse_args()

    if args.reset_generated:
        n = 0
        for course in all_courses():
            path = os.path.join('courses', course, 'manifest.json')
            with open(path, encoding='utf-8') as f:
                m = json.load(f)
            kept = [e for e in m.get('exercise_decls', []) if 'source_ref' not in e]
            n += len(m.get('exercise_decls', [])) - len(kept)
            m['exercise_decls'] = kept
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(m, f, indent=2, ensure_ascii=False)
                f.write('\n')
        print('removed %d previously generated items' % n)
        if not args.write:
            return 0

    decks, methods, uncovered = build_decks(args.ignore_existing_generated)
    from collections import Counter
    print('generated items: %d across %d courses' %
          (sum(len(v) for v in decks.values()), len(decks)))
    print('methods: ' + ', '.join('%s=%d' % kv for kv in
                                 sorted(Counter(methods.values()).items())))
    if uncovered:
        print('UNCOVERED: %d' % len(uncovered))
        for c, cid, why in uncovered:
            print('  %s/%s: %s' % (c, cid, why))
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        for course in sorted(decks):
            path = os.path.join(args.out, course + '.bank.json')
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(decks[course], f, indent=2, ensure_ascii=False, sort_keys=True)
                f.write('\n')
        print('wrote %d deterministic bank files to %s' % (len(decks), args.out))
    if args.write:
        for course in sorted(decks):
            path = os.path.join('courses', course, 'manifest.json')
            with open(path, encoding='utf-8') as f:
                m = json.load(f)
            existing = m.get('exercise_decls', [])
            existing.extend(decks[course])
            m['exercise_decls'] = existing
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(m, f, indent=2, ensure_ascii=False)
                f.write('\n')
        print('updated %d manifests' % len(decks))
    return 1 if uncovered else 0


if __name__ == '__main__':
    sys.exit(main())
