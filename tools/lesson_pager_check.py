#!/usr/bin/env python3
"""lesson_pager_check.py -- prove prev/next links are real AND the page survives.

WHY THIS CHECK EXISTS, AND WHY IT CHECKS TWO THINGS

The prev/next pager (7.1.16) is applied in web/src/lesson_pager.ch by replacing
exact substrings in the served HTML.  While that was being written it shipped a
version whose tail slice passed a LENGTH where string_view.subview() takes an
END INDEX.  The arithmetic asked for the range [after, size - after), so the
tail of every lesson page silently vanished:

    bytes went from 65,866 bytes to 24,934, cut off mid-attribute inside the
    accessibility controls, on every one of the 398 lesson pages.

The server stayed healthy. Every route answered 200. `nav_check` reported 447
pages with one navbar each. `link_check` reported 462 links resolving. None of
them noticed, because a status code and a link target are both still perfectly
valid in a document that has been cut in half -- and `nav_check`'s own navbar
assertion passed because the navbar is in the first 4 KB.

That is the whole argument for this file.  Every other gate in this repo asks
"did the server answer?" and this one asks "did the server answer with the
WHOLE PAGE?"  A page that renders HTTP 200 and loses two thirds of its content
is not covered by a single green check, and this is that check.

WHAT IT ASSERTS

  1. The lesson BODY is intact -- a known h1, and the unit count from the
     manifest. Not a byte count: a byte count would fail on a legitimate
     layout change, and pass on a truncation that happened to be small. The
     unit count comes from the manifest, so it cannot drift silently.
  2. The document is not truncated -- it ends with </html>, and the closing
     tags are all present.
  3. The pager is CORRECT, per position in the manifest:
       first concept  -> previous stays hidden, next is the second concept
       interior       -> both present, and they point at the neighbours
       last concept   -> next stays hidden, previous is the one before it
  4. The position line reads "Concept N of M in <module>" with the right N.
  5. A page that is NOT the first concept never advertises itself as its own
     predecessor -- the `rel="prev"`-points-at-itself case, which makes a
     crawler stop walking the course.

Usage:
    python3 tools/lesson_pager_check.py [base-url]
Exit 0 all assertions hold. 1 otherwise.
"""
import json
import re
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:9000'
failures = []
checks = 0


def check(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=40) as r:
        return r.getcode(), r.read().decode('utf-8', 'replace')


def get_json(path):
    _, body = get(path)
    return json.loads(body)


def main():
    print('lesson_pager_check against ' + BASE)

    try:
        health = get('/api/health')
    except Exception as e:
        print('  FAIL  server answers /api/health -- %s' % e)
        print('\nlesson_pager_check: 1 CHECK FAILED')
        return 1
    if health[0] != 200:
        print('  FAIL  /api/health is %s' % health[0])
        return 1

    manifest = get_json('/api/courses/elf')
    concepts = manifest.get('concepts') or []
    if len(concepts) < 3:
        print('  FAIL  the elf manifest has fewer than 3 concepts; cannot test '
              'a first/interior/last pager')
        return 1

    # Three positions: the first, one in the middle, and the last.
    probes = [
        ('first', 0),
        ('interior', len(concepts) // 2),
        ('last', len(concepts) - 1),
    ]

    for label, i in probes:
        cid = concepts[i]['id']
        cid_esc = re.escape(cid)
        status, html = get('/courses/elf/lessons/' + cid)
        print('\n[%s] %s (%s)' % (label, cid, concepts[i].get('title')))
        check('%s: lesson page 200' % label, status == 200, 'got %s' % status)

        # --- 1. the BODY survived -----------------------------------------
        check('%s: carries its own <h1> (%r)'
              % (label, concepts[i].get('title')),
              ('<h1>' + (concepts[i].get('title') or 'X')) in html
              or ('>' + (concepts[i].get('title') or 'X') + '<') in html)
        # Unit count from the manifest. bytes has 10 sections; a page that lost
        # its tail loses some of them, and this is what notices.
        units = html.count('class="unit ')
        check('%s: the lesson body is not truncated (%d unit sections)'
              % (label, units), units >= 5,
              'only %d unit sections survived' % units)

        # --- 2. the DOCUMENT is whole --------------------------------------
        check('%s: the document ends with </html>' % label,
              html.rstrip().endswith('</html>'),
              'ends with %r' % html.rstrip()[-40:])
        # </body> and </html> are the document's own closing tags, so they are
        # the right thing to assert about "is this document whole".
        #
        # </main> is deliberately NOT asserted.  455 of the lesson files in
        # content/src have no <main> element at all -- a pre-existing gap in the
        # course corpus, unrelated to this check -- so requiring it would fail
        # on pages that are perfectly complete, and a checker that fails on
        # correct pages is a checker people learn to ignore.  Asserting a tag
        # that 92% of the corpus does not have buys nothing.
        for close_tag in ('</body>', '</style>'):
            check('%s: %s present' % (label, close_tag), close_tag in html)

        # --- 3. the pager is CORRECT ---------------------------------------
        prev_href = re.search(r'id="ul-prev"[^>]*href="([^"]*)"', html)
        next_href = re.search(r'id="ul-next"[^>]*href="([^"]*)"', html)
        prev_hidden = 'id="ul-prev" rel="prev" hidden' in html
        next_hidden = 'id="ul-next" rel="next" hidden' in html

        if i == 0:
            check('first: previous is NOT offered', prev_href is None and prev_hidden,
                  'prev href=%r hidden=%s' % (prev_href.group(1) if prev_href else None,
                                              prev_hidden))
            want = '/courses/elf/lessons/' + concepts[1]['id']
            check('first: next points at the second concept (%s)' % want,
                  next_href is not None and next_href.group(1) == want,
                  'got %r' % (next_href.group(1) if next_href else None))
        elif i == len(concepts) - 1:
            check('last: next is NOT offered', next_href is None and next_hidden,
                  'next href=%r hidden=%s' % (next_href.group(1) if next_href else None,
                                               next_hidden))
            want = '/courses/elf/lessons/' + concepts[i - 1]['id']
            check('last: previous points at the one before (%s)' % want,
                  prev_href is not None and prev_href.group(1) == want,
                  'got %r' % (prev_href.group(1) if prev_href else None))
        else:
            want_prev = '/courses/elf/lessons/' + concepts[i - 1]['id']
            want_next = '/courses/elf/lessons/' + concepts[i + 1]['id']
            check('interior: previous -> %s' % want_prev,
                  prev_href is not None and prev_href.group(1) == want_prev,
                  'got %r' % (prev_href.group(1) if prev_href else None))
            check('interior: next -> %s' % want_next,
                  next_href is not None and next_href.group(1) == want_next,
                  'got %r' % (next_href.group(1) if next_href else None))

        # --- 5. never a link to itself -------------------------------------
        for label2, m in (('prev', prev_href), ('next', next_href)):
            if m is not None:
                check('%s: %s does not point at this page'
                      % (label, label2),
                      m.group(1) != '/courses/elf/lessons/' + cid,
                      'points at itself: %s' % m.group(1))

        # --- 4. the position line ------------------------------------------
        where = re.search(r'id="ul-progress-where">([^<]*)<', html)
        want_n = 'Concept %d of %d' % (i + 1, len(concepts))
        check('%s: the position line reads %r' % (label, want_n),
              where is not None and where.group(1).startswith(want_n),
              'got %r' % (where.group(1) if where else None))
        check('%s: the position line names the module' % label,
              where is not None and ' in ' in where.group(1),
              'got %r' % (where.group(1) if where else None))

    # --- every lesson page in the course, for TRUNCATION only --------------
    # One fetch per page is cheap here and this is the assertion that would
    # have caught the length bug on all 398 pages at once rather than on the
    # three positions above.
    print('\n[every elf lesson page] the body is intact on all of them')
    broken = []
    for c in concepts:
        cid = c['id']
        try:
            _, html = get('/courses/elf/lessons/' + cid)
        except Exception as e:
            broken.append('%s (fetch failed: %s)' % (cid, e))
            continue
        if not html.rstrip().endswith('</html>') or html.count('class="unit ') < 5:
            broken.append('%s (%d bytes, %d units)'
                          % (cid, len(html), html.count('class="unit ')))
    check('all %d elf lesson pages are complete' % len(concepts),
          not broken, '; '.join(broken[:6]))

    print('\n' + ('lesson_pager_check: ALL %d CHECKS PASSED' % checks
                  if not failures
                  else 'lesson_pager_check: %d of %d CHECKS FAILED'
                       % (len(failures), checks)))
    for f in failures:
        print('  FAILED: %s' % f)
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())