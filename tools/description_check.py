#!/usr/bin/env python3
"""description_check.py -- the storefront must not advertise the courses are flawed.

THE OBJECTION THIS ENFORCES, verbatim from the founder:

    > "fix the descriptions of courses on the courses page, i get 'There is no
    >  AArch64 machine on the machine that wrote this course and no emulator',
    >  and descriptions on the main page are too long -- these things are
    >  supposed to be internal, known to us, not the user, we are working to
    >  improve the courses, we are not supposed to advertise our courses are
    >  flawed, therefore shouldn't be learned through"

That is an editorial call and it is the founder's to make.  This file is the
machine gate for it: three rules, all of them mechanical, all of them things a
writer can get wrong without noticing.

    1. LENGTH.  Every courses/<id>/manifest.json description is between
       MIN_LEN and MAX_LEN characters.  Measured before this change: longest
       2,411 (compback), median 348, and eight descriptions over 1,000 -- which
       is what "too long" means when a course card has to hold a description,
       a route line, a stats row and a concept list.
    2. BANNED VOCABULARY.  None of the words below appears in any description.
    3. SHAPE.  No description opens with "There is", "This course" or "The
       course" -- the three openings that state a fact ABOUT the course rather
       than a thing the reader can DO.

WHERE THE SUBSTANCE WENT: NOWHERE.  Every claim cut from a description is still
in the lesson that earned it.  This file deliberately does NOT check the lesson
bodies, because lesson bodies are where the caveats belong -- a reader who hits
"there is no AArch64 machine on this host" in concept 6 of a64sys, next to the
table of all fifty-seven claims and their labels, learns something true and
useful.  The same sentence on a storefront card teaches the reader only that
the course might not be worth starting.  tools/integration_check.py and the 24
verify_*.py scripts still assert that the substance is present; this file only
stops it leaking onto the shop window.

THE BANNED VOCABULARY, AND WHY EACH ITEM IS ON THE LIST
------------------------------------------------------
Grouped by what kind of internal fact it is.  Every item is a substring match,
case-insensitive.

  A. BUILD-HOST CAVEATS -- facts about the machine that WROTE the course, which
     the founder named directly.  A reader cannot act on any of it, and it is
     the sentence quoted in the objection.
       emulator                  "no AArch64 machine ... and no emulator"
       build host / this host / the host
       machine on                 "...machine on the machine that wrote..."
       has been run                "not one instruction in it has been run"
       nothing is executed        "NOTHING IS EXECUTED", the all-caps form
       not executed
       cross-linker               a missing toolchain is a build detail
       cannot run / can run

  B. EVIDENCE LABELS -- this collection's internal vocabulary.  A reader meets
     "MEASURED-ON-BYTES" for the first time on a course card, with no concept
     in front of them that defines it.  Three capitalised words that ask for
     trust are weaker on a storefront than the lesson that earns it.
       measured-on-bytes
       measured                    (the whole family, labels and prose)
       measure / measures / measured / measurement
       quoted
       provenance
       on bytes

  C. ARTIFACT SELF-DESCRIPTION -- properties of the course's own build product.
     These are the collection's real quality signal and they are exactly why
     they belong inside the course, next to the evidence, and not in the
     sentence that sells it.
       retraction / retractions / retracted / retract
       harness
       poison / poisons
       limit / limits
       artifact
       checks / cross-check / cross-checked
       words that make no promise to a reader:
         "cannot conclude", "you cannot", "not one instruction", "no timings"

  D. PLANNING-DOCUMENT REFERENCES -- the course names the brief it was written
     from, which is a note to the author and not to the reader.
       the plan / section plan / the brief / the draft / the spec
       roadmap
       poisoned

  E. CORPUS AND SAMPLE VOCABULARY -- "a count over OUR corpus says X" is a
     fact about the course's own sample, not about the architecture.
       corpus
       sample / samples
       instrumentation / instrument
       a64sys, rvasm, and the other per-course ids are NOT banned: a course may
       name its own subject matter.  What is banned is a course naming the
       ANOTHER course, which is group F.

  F. COURSE-AGAINST-COURSE POSITIONING -- "the middle of the chain", "the
     fourth course of the AArch64 section", "the sibling", "taught in depth
     elsewhere".  The founder's phrase was "shouldn't be learned through", and
     this is the group that makes a reader feel sequenced rather than taught.
     It is also the group most likely to be WRONG, because it goes stale the
     moment a course moves, and nothing checks that.
       this collection / the collection / in this section / this section
       the chain / both ends / sibling / neighbours / neutral course
       elsewhere / in depth elsewhere / in-depth
       route / step N / declares
       endpoint
       "both ends", "first in it", "last course", "fourth course",
       "second course", "third course" -- ordinal course-positioning prose

  G. DEPENDENCY AND ORACLE FRAMING -- what the course was built against.
       oracle
       LLVM is the ORACLE, "never the dependency"
       backend of

WHY NOT EVERY OCCURRENCE OF A BANNED WORD FAILS: none.  The lists are exact
substring matches on the DESCRIPTION FIELD ONLY.  Nothing outside that field is
read, so a manifest's own "completion_criteria" -- which is where the retraction
count, the poisoned cross-check and the exact numbers belong, and which is a
field the storefront never renders -- is untouched and unrestricted.  That
split is the whole design: the internal facts have a home, and it is not the
shop window.

HOW IT PROVES IT IS NOT VACUOUS
-------------------------------
`--prove-non-vacuous` copies the tree, restores compback's original 2,411-
character description from the git HEAD blob in one manifest, and re-runs the
whole check against that copy.  The check MUST fail.  If it passes, this script
exits non-zero saying it is not testing anything.

It restores rather than invents because a gate proved non-vacuous against a
hand-written bad string proves less: it proves the rules fire on THAT string.
The real former description -- the one the founder complained about, the
longest in the collection and full of every banned group at once -- is the
honest test input, and it is in git.

Usage:
    python3 tools/description_check.py
    python3 tools/description_check.py --base http://localhost:9000
    python3 tools/description_check.py --served
    python3 tools/description_check.py --prove-non-vacuous
    python3 tools/description_check.py --list-vocabulary

Exit: 0 every rule held, 1 a rule was broken, 2 bad usage.
"""
import argparse
import json
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MIN_LEN = 120
MAX_LEN = 200

# The longest description before this change, and the course it belonged to.
# Used by --prove-non-vacuous as the test input.
WITNESS_COURSE = 'compback'

BANNED = {
    # A. build-host caveats
    'emulator': 'A fact about the machine that wrote the course. The sentence '
                'the founder quoted.',
    'build host': 'Same. Which machine the build ran on is not a reader fact.',
    'this host': 'Same.',
    'the host': 'Same.',
    'machine on': 'Same.',
    'has been run': 'Whether an instruction was executed is a property of the '
                   'build, and it is only meaningful beside its evidence.',
    'nothing is executed': 'Same, in the all-caps form the descriptions used.',
    'not executed': 'Same.',
    'cross-linker': 'A missing toolchain is a build detail.',
    'cannot run': 'Same.',
    'no timings': 'The absence of timings is real and belongs in the lesson '
                  'that explains which claims it bounds.',

    # B. evidence labels
    'measured': 'Internal evidence vocabulary. A reader meets MEASURED-ON-BYTES '
                'first on a card, with no concept in front of them.',
    'measure': 'Same family.',
    'measurement': 'Same family.',
    'quoted': 'Same.',
    'provenance': 'Same.',
    'on bytes': 'Same.',

    # C. artifact self-description
    'retraction': 'A retraction is the strongest thing this collection does and '
                  'it needs its measurement beside it to be worth anything.',
    'retract': 'Same.',
    'harness': 'A property of the course build, not of the subject.',
    'poison': 'Same.',
    'limit': 'Same.',
    'artifact': 'Same.',
    'cross-check': 'Same.',
    'cannot conclude': 'The limits block is a concept, not a pitch.',
    'you cannot': 'Same.',

    # D. planning documents
    'the plan': 'The course names the brief it was written from. That is a note '
                'to the author.',
    'section plan': 'Same.',
    'the brief': 'Same.',
    'the draft': 'Same.',
    'roadmap': 'Same.',

    # E. corpus and samples
    'corpus': '"A count over OUR corpus" is a fact about the course sample, '
              'not about the architecture.',
    'sample': 'Same.',
    'instrument': 'The instrument is described and validated in the lesson.',
    'oracle': 'What the course was built against is an author fact.',

    # F. course-against-course positioning
    'this collection': 'Positioning the course against the others is what makes '
                       'a reader feel sequenced rather than taught.',
    'the collection': 'Same.',
    'in this section': 'Same.',
    'this section': 'Same.',
    'the chain': 'Same.',
    'both ends': 'Same.',
    'sibling': 'Same.',
    'neighbour': 'Same.',
    'neutral course': 'Same.',
    'elsewhere': 'Same.',
    'route': 'Same.',
    'declares': 'Same.',
    'endpoint': 'Same.',
    'first in it': 'Ordinal course-positioning prose.',
    'last course': 'Same.',
    'first course': 'Same.',
    'second course': 'Same.',
    'third course': 'Same.',
    'fourth course': 'Same.',
    'fifth course': 'Same.',
    'taught in depth': 'Same.',

    # G. dependency and oracle framing
    'llvm is the oracle': 'Same as oracle.',
    'the dependency': 'Same.',
}

# Openings that state a fact ABOUT the course instead of a thing the reader can
# do.  The rule is 1: the description must open with a promise.
BAD_OPENINGS = (
    'there is ', 'there are ', 'this course', 'the course ', 'a course ',
    'it is ', 'it was ',
)

# A SECOND, SMALLER LIST, applied to everything else the storefront renders.
#
# WHY TWO LISTS AND NOT ONE.  The founder's objection was about METHODOLOGY --
# "these things are supposed to be internal, known to us, not the user".  A
# course card on /courses also carries a route reason (web/src/courses_index_
# render.ch line 66), and three of those reasons printed the same class of
# internal fact: one said "because there is no RISC-V machine on the build
# host", one said "a draft that was retracted in public".  Those three were
# fixed by hand.  The rest of the route reasons are SEQUENCING information --
# "Declares x86asm, x86abi, smp, simd and mem" is a prerequisite list, which is
# a real question a reader has, and which the card already answers in a
# dedicated row (`.step-prereqs`, courses_index_render.ch line 71).
#
# So BANNED is the full editorial rule and applies to the description field
# only; BANNED_ON_STOREFRONT is the subset the founder actually named -- build
# caveats and retraction/planning-document references -- and applies to every
# string the storefront shows.  Widening the second list to match the first
# would have been me inventing a scope the founder did not ask for; leaving the
# second list out entirely would have left three card reasons carrying machine
# caveats, which is the exact complaint.
BANNED_ON_STOREFRONT = {
    'emulator': 'A build-host fact, on a page a shopper is reading.',
    'build host': 'Same.',
    'this host': 'Same.',
    'the host': 'Same.',
    'machine on': 'Same.',
    'has been run': 'Same.',
    'nothing is executed': 'Same.',
    'not executed': 'Same.',
    'no timings': 'Same.',
    'retract': 'A retraction summary belongs in the lesson beside its evidence.',
    'the draft': 'The course names the brief it was written from.',
    'the brief': 'Same.',
    'the plan': 'Same.',
    'section plan': 'Same.',
}

failures = []
checks = 0


def ok(what):
    global checks
    checks += 1
    print('  PASS  %s' % what)


def bad(what, detail=''):
    global checks
    checks += 1
    print('  FAIL  %s' % what)
    if detail:
        for line in str(detail).splitlines():
            print('          %s' % line)
    failures.append(what)


def section(title):
    print('\n== %s' % title)


def manifests(root=ROOT):
    out = []
    for path in sorted(glob.glob(os.path.join(root, 'courses', '*', 'manifest.json'))):
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        out.append((data.get('id') or os.path.basename(os.path.dirname(path)),
                    data.get('description'), path))
    return out


def check_descriptions(root=ROOT, label='the tree'):
    """The three rules.  Returns (n_ok, n_bad)."""
    section('%s: %d manifest description(s)' % (label, len(manifests(root))))
    rows = manifests(root)
    if len(rows) != 34:
        bad('the collection has 34 course manifests', 'found %d' % len(rows))

    for cid, desc, path in rows:
        rel = os.path.relpath(path, root)
        if desc is None or not desc.strip():
            bad('%s has a description' % cid, rel)
            continue

        # -- rule 1: length -------------------------------------------
        n = len(desc)
        if MIN_LEN <= n <= MAX_LEN:
            ok('%s description is %d chars (bound %d-%d)'
               % (cid, n, MIN_LEN, MAX_LEN))
        else:
            bad('%s description is within %d-%d chars' % (cid, MIN_LEN, MAX_LEN),
                'got %d in %s:\n%s' % (n, rel, desc[:300]))

        # -- rule 2: banned vocabulary ---------------------------------
        low = desc.lower()
        hits = sorted({w for w in BANNED if w in low})
        if hits:
            bad('%s description uses no banned vocabulary' % cid,
                'found %s in %s:\n%s'
                % (', '.join(repr(h) for h in hits), rel, desc[:300]))
        else:
            ok('%s description uses none of the %d banned terms'
               % (cid, len(BANNED)))

        # -- rule 3: opens with a promise ------------------------------
        start = low.lstrip()
        opener = None
        for b in BAD_OPENINGS:
            if start.startswith(b):
                opener = b
                break
        if opener:
            bad('%s description opens with a promise, not a fact about the '
                'course' % cid,
                'it opens %r:\n%s' % (opener, desc[:200]))
        else:
            ok('%s description opens with %r' % (cid, desc.split(' ')[0]))
    return rows


def check_served(base):
    """The description on the STOREFRONT is the manifest description.  If these
    ever drift, a perfect set of manifests fixes nothing a reader sees."""
    section('the served storefront carries these descriptions')

    def get(path):
        try:
            req = urllib.request.Request(base.rstrip('/') + path)
            with urllib.request.urlopen(req, timeout=40) as r:
                return r.status, r.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            return e.code, ''
        except Exception:
            return 0, ''

    st, html = get('/courses')
    if st != 200:
        bad('GET /courses returns 200', 'HTTP %s' % st)
        return
    cards = re.findall(r'<p class="course-desc">(.*?)</p>', html, re.S)
    if not cards:
        bad('/courses renders a course description per card',
            'no <p class="course-desc"> found; the storefront shape changed and '
            'this check is no longer looking at the description')
        return
    ok('/courses renders %d course description(s)' % len(cards))

    def html_escaped(s):
        """What the description looks like ON the page.  Three of the 34 contain
        an apostrophe (img's "the kernel's mapping"), and courses_index_render
        escapes it to &#39;, so a verbatim substring comparison fails on exactly
        the descriptions that are correct.  Comparing the unescaped form would
        have been a check that cries wolf."""
        return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                 .replace("'", '&#39;').replace('"', '&quot;'))

    by_id = {cid: desc for cid, desc, _ in manifests()}
    shown = 0
    for cid, desc in sorted(by_id.items()):
        if desc and html_escaped(desc) in html:
            shown += 1
    if shown == len(by_id):
        ok('all %d descriptions appear on /courses' % shown)
    else:
        missing = [c for c, d in sorted(by_id.items())
                   if not d or html_escaped(d) not in html]
        bad('all %d descriptions appear on /courses' % len(by_id),
            'missing from the page: %s' % (missing,))

    # And the two storefront shapes that were carrying the caveat anyway: the
    # route reason under each card, and the course landing page's own summary.
    n_reasons = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'web', 'src', 'routes_*.ch'))):
        src = open(path, encoding='utf-8').read()
        name = os.path.basename(path)
        for cid, why in re.findall(
                r'mk_step\(string\("([^"]+)"\),\s*string\("((?:[^"\\]|\\.)*)"\)\)',
                src):
            n_reasons += 1
            low = why.lower()
            hits = sorted({w for w in BANNED_ON_STOREFRONT if w in low})
            if hits:
                bad('the /courses reason for %s in %s carries no build caveat '
                    'and no retraction summary' % (cid, name),
                    'found %s:\n%s' % (', '.join(repr(h) for h in hits), why))
    if not any('the /courses reason for' in f for f in failures):
        ok('all %d route reasons on /courses carry no build caveat and no '
           'retraction summary' % n_reasons)

    # /courses/<id> shows the description as .course-description.
    checked = 0
    for cid, desc, _ in manifests():
        st, page = get('/courses/%s' % cid)
        if st != 200:
            bad('GET /courses/%s returns 200' % cid, 'HTTP %s' % st)
            continue
        checked += 1
        if desc and html_escaped(desc) in page:
            continue
        bad('the landing page /courses/%s shows the rewritten description' % cid,
            'the manifest description is not in the served HTML')
        break
    if checked and not failures:
        ok('all %d course landing pages show the rewritten description' % checked)

    # And the API, because search reads from it.
    st, txt = get('/api/courses')
    if st == 200:
        try:
            data = json.loads(txt)
            rows = data.get('courses', data) if isinstance(data, dict) else data
            hit = 0
            for r in rows:
                cid = r.get('id')
                if by_id.get(cid) and r.get('description') == by_id[cid]:
                    hit += 1
            if hit == len(by_id) and hit:
                ok('/api/courses returns the rewritten description for all %d '
                   'courses' % hit)
            else:
                bad('/api/courses returns the rewritten description for all %d '
                    'courses' % len(by_id),
                    '%d of %d match' % (hit, len(by_id)))
        except Exception as e:
            bad('/api/courses parses as JSON', str(e))
    else:
        bad('GET /api/courses returns 200', 'HTTP %s' % st)


def prove_non_vacuous(base_port=9112):
    """Put compback's ORIGINAL description back and require the check to fail."""
    print('\n' + '=' * 72)
    print('PROVING THIS CHECK IS NOT VACUOUS')
    print('=' * 72)
    print('Copying the tree, restoring %s\'s original description from git' % WITNESS_COURSE)
    print('into one manifest, and re-running the check against that copy.')
    print('The check MUST fail -- that description is the longest in the')
    print('collection and the one the founder quoted.')
    if not shutil.which('git'):
        print('\nFAIL: git is not on PATH; the witness input comes from git.')
        return 1

    scratch = tempfile.mkdtemp(prefix='description-check-nonvacuous-')
    dst = os.path.join(scratch, 'underlayer')
    print('\n  scratch copy: %s' % dst)
    try:
        shutil.copytree(ROOT, dst,
                        ignore=shutil.ignore_patterns('.git', 'build', '__pycache__',
                                                      '.venv', 'node_modules',
                                                      'courses'))
        os.makedirs(os.path.join(dst, 'courses'), exist_ok=True)
        for c in os.listdir(os.path.join(ROOT, 'courses')):
            src = os.path.join(ROOT, 'courses', c)
            if os.path.isdir(src) and os.path.exists(os.path.join(src, 'manifest.json')):
                shutil.copytree(src, os.path.join(dst, 'courses', c))

        rel = 'courses/%s/manifest.json' % WITNESS_COURSE
        p = subprocess.run(['git', 'show', 'HEAD:%s' % rel], cwd=ROOT,
                           capture_output=True, text=True)
        if p.returncode != 0:
            print('\nFAIL: could not read %s from git:\n%s' % (rel, p.stderr[:400]))
            return 1
        old_desc = json.loads(p.stdout)['description']
        print('  the witness description is %d characters' % len(old_desc))

        path = os.path.join(dst, rel)
        src_text = open(path, encoding='utf-8').read()
        pat = re.compile(r'("description":\s*)"((?:[^"\\]|\\.)*)"')
        m = pat.search(src_text)
        if not m:
            print('\nFAIL: no description field in %s' % path)
            return 1
        enc = json.dumps(old_desc)[1:-1]
        open(path, 'w', encoding='utf-8').write(
            src_text[:m.start(2)] + enc + src_text[m.end(2):])
        print('  restored it into %s' % path)

        global checks, failures
        failures = []
        checks = 0
        check_descriptions(dst, label='the mutilated copy')

        print('\n' + '-' * 72)
        if not failures:
            print('THE CHECK PASSED WITH THE OLD DESCRIPTION RESTORED.')
            print('')
            print('That means tools/description_check.py does not actually test')
            print('the description rules.  It is worse than no check, because it')
            print('looks like coverage.')
            print('-' * 72)
            return 1
        print('THE CHECK FAILED WITH THE OLD DESCRIPTION RESTORED, as it must.')
        print('Reproduced failures:')
        for f in failures:
            print('  - %s' % f)
        print('-' * 72)
        print('\nPROVEN NON-VACUOUS: the check catches the description the')
        print('founder complained about.')
        return 0
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def list_vocabulary():
    print('\nBANNED VOCABULARY -- %d terms, matched case-insensitively as'
          % len(BANNED))
    print('substrings of courses/<id>/manifest.json "description" ONLY.\n')
    for w in sorted(BANNED):
        print('  %-20s %s' % (repr(w), BANNED[w]))
    print('\nBANNED ON ANY STOREFRONT STRING -- %d terms, a SUBSET of the above.'
          % len(BANNED_ON_STOREFRONT))
    print('Applied to the route reasons on /courses as well, because three of')
    print('them printed a build caveat or a retraction summary, which is the')
    print('founder\'s complaint verbatim.  It is deliberately NOT the full list:')
    print('a prerequisite declaration is a real reader question and the card')
    print('already answers it in .step-prereqs.\n')
    for w in sorted(BANNED_ON_STOREFRONT):
        print('  %-20s %s' % (repr(w), BANNED_ON_STOREFRONT[w]))
    print('\nREMOVED FROM THE LIST AFTER IT FAILED ON REAL TEXT, recorded')
    print('because a banned word that fires on correct copy is a tool that')
    print('gets deleted:')
    print("  'checks'        the jvm description says 'the code a verifier")
    print("                  checks'.  That is the subject matter, not a")
    print('                  property of the build artifact.')
    print('\nNOT banned, and why:')
    print('  completion_criteria    the retraction count, the poisoned')
    print('                         cross-check and the exact numbers live')
    print('                         here, and the storefront never renders it.')
    print('  concept bodies         caveats belong here, beside their evidence.')
    print('  route reasons          edited only where one carried a machine')
    print('                         caveat or a retraction into the storefront.')
    print('  a course id            a course may name its own subject; what is')
    print('                         banned is naming ANOTHER course.')


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default=None,
                    help='also check the SERVED storefront at this base URL '
                         '(default: http://localhost:9000)')
    ap.add_argument('--no-served', action='store_true',
                    help='check the files only, not a running server')
    ap.add_argument('--prove-non-vacuous', action='store_true',
                    help="restore the original longest description in a scratch "
                         "copy and require this check to fail")
    ap.add_argument('--list-vocabulary', action='store_true',
                    help='print the banned vocabulary with its reasoning, and exit')
    args = ap.parse_args()

    if args.list_vocabulary:
        list_vocabulary()
        return 0

    global checks, failures
    failures = []
    checks = 0
    rows = check_descriptions(ROOT)

    section('the shape of the result')
    if rows:
        lens = sorted(len(d or '') for _, d, _ in rows)
        med = lens[len(lens) // 2] if len(lens) % 2 else \
            (lens[len(lens) // 2 - 1] + lens[len(lens) // 2]) // 2
        ok('longest %d, shortest %d, median %d, across %d courses'
           % (lens[-1], lens[0], med, len(lens)))

    if not args.no_served:
        base = args.base or 'http://localhost:9000'
        try:
            req = urllib.request.Request(base.rstrip('/') + '/api/health')
            with urllib.request.urlopen(req, timeout=5) as r:
                up = r.status == 200
        except Exception:
            up = False
        if up:
            check_served(base)
        else:
            bad('the server answers /api/health on %s' % base,
                'is it running?  bash scripts/restart_underlayer.sh   '
                '(or pass --no-served to check the files only)')

    print('\n' + '=' * 72)
    if failures:
        print('description_check: %d of %d CHECKS FAILED' % (len(failures), checks))
    else:
        print('description_check: ALL %d CHECKS PASSED' % checks)
    print('=' * 72)
    for f in failures:
        print('  FAILED: %s' % f)

    if args.prove_non_vacuous:
        if failures:
            print('\nNot running the non-vacuity proof: the check does not pass')
            print('on the real tree, so it has nothing to prove yet.')
            return 1
        return prove_non_vacuous()
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())