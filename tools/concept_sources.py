#!/usr/bin/env python3
"""concept_sources.py -- map a manifest concept id to its verified lesson text.

The verified text of a concept is NOT in courses/*/src (those files are only
build entry points).  It is in content/src/<render_fn>.ch, inside the #html
block of the concept's render function.  The mapping is recovered from each
course's build entry, where a render call is immediately followed by the
write_page of the concept's output slug:

    html = underlayer_content::render_a64_aapcs()
    course_writer::write_page("output/a64-aapcs.html", &html)

Read-only helper shared by the bank generator and the bank verifier.  It never
writes and never imports third-party modules.
"""
import glob
import html
import json
import os
import re

RENDER_RE = re.compile(r'underlayer_content::render_([A-Za-z0-9_]+)\s*\(')
WRITE_RE = re.compile(r'write_page\(\s*"output/([^"]+)\.html"')


def _strip_comments(text):
    return re.sub(r'//[^\n]*', '', text)


HTML_TAGS = {'p', 'code', 'div', 'span', 'strong', 'em', 'b', 'i', 'pre',
             'table', 'thead', 'tbody', 'tr', 'td', 'th', 'a', 'br', 'h1',
             'h2', 'h3', 'ul', 'ol', 'li', 'button', 'section', 'header',
             'main', 'footer', 'details', 'summary', 'sup', 'sub', 'small'}
TAG_ONLY_RE = re.compile(r'</?([A-Za-z][A-Za-z0-9-]*)\b[^>]*>')


def html_plain(fragment):
    """Normalise an HTML fragment to display text.

    Only real HTML tags are removed; a literal such as `/proc/<pid>/maps` in
    lesson prose must survive (a naive `<[^>]+>` regex deleted `<pid>` and
    made a valid generated answer look untraceable, measured 2026-11-27).
    """
    def repl(m):
        return '' if m.group(1).lower() in HTML_TAGS else m.group(0)
    return re.sub(r'\s+', ' ', html.unescape(TAG_ONLY_RE.sub(repl, fragment))).strip()


def course_map(course):
    """Return {concept_id: 'content/src/<file>.ch'} for one course."""
    manifest = os.path.join('courses', course, 'manifest.json')
    main = os.path.join('courses', course, 'src', 'main.ch')
    if not (os.path.isfile(manifest) and os.path.isfile(main)):
        return {}
    m = json.load(open(manifest, encoding='utf-8'))
    text = _strip_comments(open(main, encoding='utf-8', errors='replace').read())
    # Pair by sequence, not by two independent lists: the landing page has a
    # render call whose write is `output/index.html`, and dropping that write
    # from a zipped list would shift every concept onto the previous render
    # (measured 2026-11-27: a64-aapcs pointed at a64abi_landing.ch).  Prose
    # comments are stripped first so a mention of `render_concept()` cannot
    # become a phantom render.
    pairs = {}
    last_render = None
    for line in text.splitlines():
        rr = RENDER_RE.search(line)
        if rr:
            last_render = rr.group(1)
        wr = WRITE_RE.search(line)
        if wr and wr.group(1) != 'index' and last_render:
            pairs[wr.group(1)] = last_render
            last_render = None
    result = {}
    for concept in m.get('concepts', []):
        cid = concept['id']
        fn = pairs.get(cid, cid.replace('-', '_'))
        path = os.path.join('content', 'src', fn + '.ch')
        result[cid] = path if os.path.isfile(path) else None
    return result


def all_courses():
    return sorted(os.path.basename(os.path.dirname(p))
                  for p in glob.glob('courses/*/manifest.json'))


def all_maps():
    return {c: course_map(c) for c in all_courses()}


if __name__ == '__main__':
    maps = all_maps()
    total = sum(len(m) for m in maps.values())
    missing = [(c, cid) for c, m in maps.items() for cid, p in m.items() if p is None]
    print('courses=%d concepts=%d unmapped=%d' % (len(maps), total, len(missing)))
    for c, cid in missing:
        print('  UNMAPPED %s/%s' % (c, cid))
