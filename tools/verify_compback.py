#!/usr/bin/env python3
"""verify_compback.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * every concept page carries SIX units, and the unit METADATA line names
    the module the manifest assigns
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page plus the landing resolves
  * the OUTBOUND id list is asserted PRESENT and the RETIRED id list is
    asserted ABSENT -- both halves, because a positive list passes on any
    set of ids that exist and says nothing about the ones that do not
  * the artifact's own harness still passes against the SHIPPED
    compback.out, which means the course's claims are checkable on a
    machine that never ran its cross-compiler
  * the artifact's CORRUPTION SUITE also passes, which is the difference
    between a harness and a rubric
  * the FOUR POISONS all report FIRED and every DELTA is non-zero
  * all EIGHTEEN retractions are present by name with no gaps and a
    SOURCE each
  * the FIFTEEN limits are NUMBERED 1..15 with no gaps
  * both scope lists are present AND their ORDERING -- the cannot-list
    before the can-list, because a course that prints only a cannot-list
    teaches its reader that the subject is unknowable
  * all THREE labels are spelled exactly one way, and none of the three is
    a fourth spelling
  * there is NO unconditional claim that a spill costs a fixed amount,
    because the measured cost is NOT linear

Run with the server up on :9000.

Derived from tools/verify_rvat.py, and the SHAPE is the same -- a manifest,
six concept routes, a landing page, a prev/next chain, and a committed
artifact whose harness reads a committed recording rather than re-measuring.
FIVE things had to change and each is a place where this course is not
like its siblings, so each is a shape rather than a value.

THE FIVE THINGS THAT ARE SPECIFIC TO THIS COURSE.

FIRST, and it inverts every sibling's central assumption: THIS COURSE HAS
TIMING, and it is the ONLY course in the collection that does.  x86-64 runs
natively on the build host, so section 10 puts RATIOS on the cost of a spill
and on the cost of a schedule.  Every other course in this collection
verifies the ABSENCE of a timing -- `rvabi` asserts there are no timings,
`rvpriv` and `rvat` assert that nothing is ever executed -- and this one
asserts the opposite.  So the verifier below does NOT check for the absence
of timing, and asserting one would have required the course to retract its
only original measurement.

SECOND, and it is the check this file exists to get right: THE SPILL COST IS
NOT LINEAR, SO NO UNCONDITIONAL CLAIM IS ALLOWED.  The four timing arms
spill 0, 1, 2 and 4 values.  Arm B (one spill) and arm C (two spills) come
out in the SAME BAND, and only arm D (four spills) separates -- so a page
that says "a spill costs 1.25x" or that computes a per-spill cost by
dividing a ratio by a count is asserting something the artifact does not
support.  This is asserted as a NEGATIVE over the pages' own text, because
the failure mode is a sentence nobody can check mechanically anywhere else,
and because the previous agent found it and the next one has to be stopped
from reintroducing it.

THIRD, the two-reader check here is much smaller than its siblings' -- NINE
words, the AArch64 leaf -- and it reports 9 agree and 0 disagree, which is
the opposite shape from every other course in the collection.  That is not a
weaker check; it is a check over a deliberately tiny corpus, and the
interesting number is NOT the zero.  It is the FIRE TABLE: six rules of which
three fire and three match nothing, and TWO OF THE DEAD ONES ARE DEAD BY
DESIGN AND ARE LABELLED SO IN THE TABLE ITSELF.  A verifier that asserted
"every rule fires" would be asserting something false about a healthy
artifact, which is 2.2.116's finding arriving from the other direction.

FOURTH, the label check is on the THREE EXACT SPELLINGS and nothing else, and
this course is the reason the rule is stated as a rule: the provenance
summary line in section 12 ("25 rows: 8 MEASURED, 9 MEASURED-ON-BYTES, 8
QUOTED") only adds up if the spellings are consistent, so a fourth spelling
or a hyphenated variant breaks a count that the whole course rests on.  All
three must be non-zero and the sum must equal the row count.

FIFTH, and it is why this course ships a corruption suite run INSIDE the
verifier: A HARNESS WHOSE CHECKS HAVE NEVER BEEN SEEN TO FAIL IS A RUBRIC,
and this collection has retracted four for exactly that.  `corrupt.py`
corrupts the recorded report and requires every corruption to be CAUGHT.
It is also the check that can fail while everything else is green, which is
the point of having it.

A SIXTH THING worth recording, because it is a defect this verifier is FORCED
to notice and is therefore a defect the collection should know about: TWO
COUNTS IN THE ARTIFACT DISAGREE WITH THE ARTIFACT'S OWN CONTENTS.  Section 12
says THREE rows are marked `NOT MEASURED HERE` and prints two.  Section 18
says the corruption suite applies TWENTY-TWO ways and the suite applies 27.
Both are hand-written counts in prose rather than counts computed from the
list they summarise -- the same defect `rvpriv` shipped as R16 -- and neither
is repaired here, because `compback.out`, `run1.txt` and `run2.txt` must stay
BYTE-IDENTICAL and a verifier that silently fixed them would be verifying
something other than what ships.  They are asserted HERE instead, as known
failures, so the next person to read this file learns about them from the
verifier rather than from a `grep`.
"""

import collections
import html
import json
import os
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "compback"

m = json.load(open('courses/%s/manifest.json' % COURSE))

order = []
for mod in m['modules']:
    order.extend(mod['concepts'])

by_id = {c['id']: c for c in m['concepts']}
print('%d concepts in %d modules, %d minutes total\n'
      % (len(order), len(m['modules']),
         sum(c['estimated_minutes'] for c in m['concepts'])))

bad = []


def get(path):
    return subprocess.run(['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                           BASE + path], capture_output=True, text=True).stdout


pages = {}
for i, cid in enumerate(order):
    if cid not in by_id:
        bad.append('%s: in a module but has no top-level entry' % cid)
        continue
    path = '/courses/%s/lessons/%s' % (COURSE, cid)
    code = get(path)
    if code != '200':
        bad.append('%s: route returned %s' % (path, code))
        continue
    h = subprocess.run(['curl', '-s', BASE + path], capture_output=True,
                       text=True).stdout
    pages[cid] = h

    mt = re.search(r'<div class="lesson-meta">(\d+) min', h)
    title = re.search(r'<h1>([^<]*)</h1>', h)
    units = h.count('class="unit ')
    foot = re.findall(r'href="(/courses/%s/lessons/[^"]+)"' % COURSE, h)

    prob = []
    if not mt:
        prob.append('no lesson-meta')
    elif int(mt.group(1)) != by_id[cid]['estimated_minutes']:
        prob.append('minutes %s != manifest %d' % (mt.group(1),
                                                   by_id[cid]['estimated_minutes']))
    if not title:
        prob.append('no h1')
    else:
        # The h1 is HTML-ESCAPED on render (`&rsquo;` for an apostrophe), so
        # the comparison has to unescape it.  The manifest stores a plain
        # ASCII apostrophe, and an unescaped comparison reports a healthy page
        # as a title mismatch -- which is what happened on cb-verify.
        _got = html.unescape(title.group(1))
        # ...and normalise the typographic apostrophe the manifest itself may
        # carry, because a U+2019 and a U+0027 are the same character to a
        # reader and different bytes to Python.
        _got = _got.replace('’', "'")
        if _got != by_id[cid]['title']:
            prob.append('title %r != manifest %r' % (_got, by_id[cid]['title']))
    # Six units per concept page: why, model, reality, example, apply,
    # connect.  A CONSTANT rather than a manifest field, because it is a
    # convention of the lesson layout -- a page that silently lost a unit
    # still renders, still has a valid h1, and still passes every link check.
    # This is `nesting_check.py`'s finding in a second tool: a unit div that
    # is never closed swallows the units after it, the div count still
    # balances, and the page reads as balanced to a count.
    if units != 6:
        prob.append('%d units, expected 6' % units)
    # The module TITLES are prose and contain spaces ("three questions about a
    # sequence", "the contract, and reading the decisions back out"), so a
    # `module:\s*(\w+)` pattern captures the FIRST WORD of the title rather than
    # the manifest's module_id -- and reports six phantom failures on six
    # healthy pages.  What is load-bearing is that the meta line carries a
    # module at all and names THIS course's module, so the manifest↔page
    # agreement is checked by the exact string the renderer emits, and a page
    # from another course or one that lost its module line still fails.
    MODULE_TITLES = {'ir': 'the representation',
                     'select': 'three questions about a sequence',
                     'abi': 'the contract, and reading the decisions back out'}
    _mod = re.search(r'module:([^&]*)&middot;\s*<a', h)
    if not _mod:
        prob.append('no module in the meta line')
    else:
        want_t = MODULE_TITLES.get(by_id[cid]['module_id'])
        if want_t is None:
            prob.append('MODULE_TITLES has no entry for module %r, so this '
                        'page cannot be checked -- add it rather than '
                        'skipping the check' % by_id[cid]['module_id'])
        elif want_t not in _mod.group(1):
            prob.append('meta line names module %r, manifest module %r expects '
                        '%r' % (_mod.group(1).strip(),
                                by_id[cid]['module_id'], want_t))

    if i > 0:
        want = '/courses/%s/lessons/%s' % (COURSE, order[i - 1])
        if want not in foot:
            prob.append('footer missing prev %s' % want)
    if i + 1 < len(order):
        want = '/courses/%s/lessons/%s' % (COURSE, order[i + 1])
        if want not in foot:
            prob.append('footer missing next %s' % want)
    else:
        if '/courses/%s' % COURSE not in h:
            prob.append('last page has no link back to the course')

    print('  %-24s %3smin  units=%d  %-44s %s'
          % (cid, mt.group(1) if mt else '?', units,
             (title.group(1) if title else '?')[:44],
             'ok' if not prob else 'BAD: ' + '; '.join(prob)))
    bad.extend('%s: %s' % (cid, p) for p in prob)

# every internal link, from every page plus the landing page
lp = '/courses/%s' % COURSE
lh = subprocess.run(['curl', '-s', BASE + lp], capture_output=True,
                    text=True).stdout
if get(lp) != '200':
    bad.append('%s: landing returned %s' % (lp, get(lp)))
allh = ''.join(pages.values()) + lh
links = sorted(set(re.findall(r'href="(/courses/[^"#?]*)"', allh)))
real = [l for l in links if '+' not in l and "'" not in l]
print('\n%d unique internal links (%d real, %d JS template literals skipped)'
      % (len(links), len(real), len(links) - len(real)))
print('  ' + '  '.join('%s=%d' % kv for kv in
                       sorted(collections.Counter(l.split('/')[2]
                                                  for l in real).items())))
for l in real:
    code = get(l)
    if code != '200':
        bad.append('link %s -> %s' % (l, code))

# The OUTBOUND link list, asserted PRESENT and the RETIRED ids asserted ABSENT.
# A positive list passes on any set of ids that exist and says nothing about
# the ones that do not, and the previous course in this collection's lineage
# shipped four ids that 404'd while its own artifact claimed every one had
# been verified.  The negative is on a WHOLE SEGMENT, because a retired id
# can be a PREFIX of a live one and a substring test would then fail the
# course for linking to a page one character longer than an id it retired.
OUTBOUND = ('/courses/x86abi/lessons/x86-calling',
            '/courses/a64abi/lessons/a64-aapcs',
            '/courses/rvabi/lessons/rv-calling',
            '/courses/rvabi/lessons/rv-noflags',
            '/courses/x86abi/lessons/x86-frame',
            '/courses/x86abi/lessons/x86-unwind',
            '/courses/a64abi/lessons/a64-unwind',
            '/courses/rvpriv/lessons/rv-boundary',
            '/courses/rvasm/lessons/rv-verify',
            '/courses/a64asm/lessons/a64-verify',
            '/courses/obj/lessons/obj-verify',
            '/courses/obj/lessons/obj-relocations',
            '/courses/link/lessons/link-order',
            '/courses/link/lessons/link-write-script',
            '/courses/reloc/lessons/reloc-apply',
            '/courses/dwarf/lessons/dwarf-intro',
            '/courses/x86asm/lessons/x86-integers',
            '/courses/a64asm/lessons/a64-encoding',
            '/courses/rvasm/lessons/rv-encoding',
            '/courses/exe/lessons/exe-latency',
            '/courses/exe/lessons/exe-deps',
            '/courses/exe/lessons/exe-speculate',
            '/courses/mem/lessons/mem-latency')
# The three the roadmap named and this course did NOT take, plus the four that
# `rvpriv` linked wrongly and had to retract.  `compiler-architecture`,
# `register-allocation` and `compiler-abis` are the todo.md concept ids: this
# course deliberately uses `cb-` names, and asserting the todo names ABSENT is
# how a future editor finds out they were renamed on purpose rather than by
# accident.
RETIRED = ('compiler-architecture', 'instruction-selection',
           'register-allocation', 'instruction-scheduling',
           'compiler-abis', 'compiler-debug-information',
           'cb-boundary', 'compback-boundary',
           # rvpriv's four, which 404'd
           'priv-syscall', 'mem-paging', 'a64-paging', 'reloc-types')
print('\n  the %d outbound ids, asserted PRESENT individually:' % len(OUTBOUND))
for l in OUTBOUND:
    code = get(l)
    if code != '200':
        bad.append('outbound %s -> %s' % (l, code))
    print('    %-44s %s' % (l, code))
print('  the %d retired ids, asserted ABSENT as whole segments:' % len(RETIRED))
for rid in RETIRED:
    present = [l for l in real if re.search(r'/lessons/%s(?![\w-])' % re.escape(rid), l)]
    if present:
        bad.append('the RETIRED id %s is linked as %s' % (rid, present))
    print('    %-44s %s' % (rid, 'ABSENT' if not present else 'PRESENT'))

# --- the pages' OWN text, and the two claims they must not make ------------
# The spill cost is NOT LINEAR: arms B and C land in the same band and only D
# separates, so no unconditional per-spill cost may appear anywhere.  This is
# asserted over the RENDERED pages, not the source, because a page that renders
# the claim is the failure and a source file that contains the word "spill" in
# a correct sentence is not.
SPILL_OK = (
    'not linear', 'is not a constant tax',
    'nondifferen', 'not distinguish', 'not distinguishab',
)
for cid, h in pages.items():
    low = h.lower()
    if 'spill' not in low:
        continue
    # find sentences that pair "spill" with a cost assertion
    for sent in re.split(r'(?<=[.!?])\s+', re.sub(r'<[^>]+>', ' ', low)):
        if 'spill' not in sent:
            continue
        if any(k in sent for k in SPILL_OK):
            continue
        # a per-spill cost would name a multiplier next to a spill count
        if re.search(r'costs?\s+(\d+\.\d+|\d+x)', sent) and \
                re.search(r'(per|each|one|a) spill', sent):
            bad.append('%s: the spill cost is asserted unconditionally -- '
                       '"%s" -- and it is NOT linear' % (cid, sent.strip()[:90]))

# --- the artifact's OWN recorded run, and the four poisons -----------------
_samples = os.path.join('courses', COURSE, 'assets', 'samples')
_out = os.path.join(_samples, 'compback.out')
n = 0
if not os.path.isfile(_out):
    bad.append('compback.out is not committed -- the course\'s claims would '
               'be checkable only on the machine that produced them')
else:
    # ITS SIZE IS ASSERTED BEFORE ANYTHING ELSE IS READ FROM IT.  The first
    # recorded output in this collection's lineage was ZERO BYTES, which is
    # how hundreds of checks were hidden behind a file that looked like a
    # result: THE HARNESS WAS GREEN AGAINST A REPORT THAT DID NOT EXIST.
    _sz = os.path.getsize(_out)
    if _sz < 20000:
        bad.append('compback.out is %d bytes -- a report this short is a '
                   'failed run, not a result' % _sz)
    t = open(_out, errors='replace').read()
    flat = ' '.join(t.split())          # 2.2.114's flat(), for prose needles

    # THE THREE LABELS, their spelling, and the sum.  A label rendered two ways
    # is not a label, and this course is why the rule exists: section 12's
    # summary line only adds up if the spellings are consistent.
    counts = {lab: len(re.findall(r'\b%s\b' % lab, t))
              for lab in ('MEASURED', 'MEASURED-ON-BYTES', 'QUOTED')}
    for lab, c in counts.items():
        if c == 0:
            bad.append('the label %s never appears in compback.out' % lab)
    rows = re.search(r'(\d+) rows:\s*(\d+) MEASURED,\s*(\d+) MEASURED-ON-BYTES,'
                     r'\s*(\d+) QUOTED', t)
    if not rows:
        bad.append('compback.out has no "N rows: ... MEASURED ... MEASURED-'
                   'ON-BYTES ... QUOTED" summary, so the provenance count '
                   'cannot be checked')
    else:
        tot, a, b_, c_ = (int(x) for x in rows.groups())
        n = tot
        if a + b_ + c_ != tot:
            bad.append('the provenance summary does not add up: %d + %d + %d '
                       'is not %d' % (a, b_, c_, tot))
    print('\n  --  labels: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED; %d '
          'provenance rows' % (counts['MEASURED'], counts['MEASURED-ON-BYTES'],
                                counts['QUOTED'], n))

    # THE THREE HOST ABSENCES, and the sentence that governs every label.
    for phrase in ('x86-64 RUNS NATIVELY',
                   'aarch64-linux-gnu COMPILES AND CANNOT RUN',
                   'riscv64-linux-gnu COMPILES AND CANNOT RUN',
                   'NO EMULATOR'):
        if phrase not in t:
            bad.append('the artifact never says %r' % phrase)
    if 'aarch64-linux-gnu-ld IS NOT INSTALLED' not in t:
        bad.append('the artifact does not say the AArch64 linker is not '
                   'installed, so its absence claim is a caption')
    if 'END OF REPORT' not in t:
        bad.append('compback.out does not end with END OF REPORT, so a '
                   'truncated run cannot be told from a complete one')

    # THE SEVENTEEN-ROW PROVENANCE TABLE'S QUOTED SIDE, and the claim that the
    # x86-64 section's quoted fraction is the LARGER one, printed both ways.
    for doc in ('sysv-amd64', 'aapcs64', 'riscv-cc', 'arm-arm', 'x86-sdm'):
        if doc not in t:
            bad.append('no QUOTED row names %s, so a quoted claim has no '
                       'document' % doc)
    if 'COMPARISON WITH NO DENOMINATOR ON EITHER SIDE' not in t:
        bad.append('the artifact does not print the quoted-fraction '
                   'comparison BOTH ways, and saying "less" without the other '
                   'number is a comparison with no denominator')

    # THE FIFTEEN LIMITS, NUMBERED 1..15 AT THE START OF A LINE.  A numbered
    # list whose numbers are not at the start of the line is not numbered --
    # which is rvabi's own defect, found there and asserted here.
    lim = [int(x) for x in re.findall(r'(?m)^\s{2,}(\d+)\. [a-z]', t)]
    lim = [x for x in lim if 1 <= x <= 15]
    seen = sorted(set(lim))
    if seen != list(range(1, 16)):
        bad.append('the limits are not numbered 1..15 with no gaps: found %s'
                   % seen)
    else:
        print('  --  %d numbered limits, 1..15 with no gaps' % len(seen))

    # BOTH SCOPE LISTS, AND THEIR ORDERING.  The second list being the LONGER
    # one is the finding; the ordering is asserted because a page that prints
    # the can-list first inverts the argument.
    cn = re.search(r'(\d+) THINGS A READER THEREFORE CANNOT CONCLUDE', t)
    ca = re.search(r'(\d+) THINGS A READER CAN,', t)
    if not cn or not ca:
        bad.append('one of the two scope lists is missing')
    else:
        if int(cn.group(1)) != int(ca.group(1)):
            bad.append('the two scope lists are %s and %s -- they are equal, '
                       'and the artifact asserts the SECOND IS THE LONGER ONE'
                       % (cn.group(1), ca.group(1)))
        if cn.start() > ca.start():
            bad.append('the CAN list appears before the CANNOT list, which '
                       'inverts the section\'s own argument')
        print('  --  scope lists: %s cannot-conclude, %s can'
              % (cn.group(1), ca.group(1)))

    # ALL EIGHTEEN RETRACTIONS BY NAME, WITH NO GAPS, AND A SOURCE EACH.  The
    # count is READ FROM THE ARTIFACT rather than asserted here, so a course
    # that grows an R19 needs this file edited to be believed -- and the ids
    # are still checked against 1..N, because a renumbering preserves a count
    # and destroys an order.
    rn = re.search(r'(\d+) of them, and', flat)
    want = int(rn.group(1)) if rn else 18
    ids = sorted(int(x) for x in re.findall(r'(?m)^\s*R(\d+)  CLAIMED', t))
    if ids != list(range(1, want + 1)):
        bad.append('the retractions are not R1..R%d with no gaps: found %s'
                   % (want, ids))
    if len(re.findall(r'(?m)^\s*SOURCE:', t)) < want:
        bad.append('fewer SOURCE lines than retractions, so a retraction can '
                   'lose its source without anything noticing')
    # The collection's central claim, and it is asserted against `flat` rather
    # than `t` because the sentence WRAPS in the fixed-width report -- 2.2.114's
    # finding, where a needle written as one phrase cannot match two lines.
    if 'NONE OF THEM IS A MISTAKE ABOUT HOW A COMPUTER WORKS' not in flat:
        bad.append('the retractions section does not say none of them is a '
                   'mistake about how a computer works, which is the '
                   'collection\'s central claim')
    print('  --  %d retractions, R1..R%d, %d SOURCE lines'
          % (len(ids), want, len(re.findall(r'(?m)^\s*SOURCE:', t))))

    # THE FOUR POISONS, each FIRED and each moving a NON-ZERO number.  The
    # deltas are matched in FOUR SPELLINGS because this course's four are
    # structurally different from every sibling's.
    deltas = {
        'POISON 1 -- break the KIND DISPATCH': 'misroutes',
        'POISON 2 -- make the live ranges HALF-OPEN': 'edges',
        'POISON 3 -- remove the ARGUMENT LOOP': 'edges',
        'POISON 4 -- plant real disagreements': 'HIDDEN',
    }
    for header, col in deltas.items():
        if header not in flat:
            bad.append('the artifact has no %r' % header)
    # The sentinel is counted as a VERDICT LINE, not as the bare string.  This
    # course's own artifact mentions `[POISON FAILED]` twice in PROSE -- once in
    # the section header explaining what a failed poison prints, and once in
    # poison 4's own prose recording that an EARLIER VERSION printed it and that
    # the [POISON FAILED] WAS CORRECT because the assertion was wrong.  A
    # substring count sees two failures in a perfectly healthy report, which is
    # the same class of defect as `rvabi`'s checks matching on a field NAME
    # rather than a field's value.  A verdict is a line that STARTS with it.
    _failed_verdicts = re.findall(r'(?m)^\s*\[?VERDICT:?\]?\s*\[?POISON FAILED',
                                  t)
    _failed_verdicts += re.findall(r'(?m)^\s*\[POISON FAILED\]', t)
    if _failed_verdicts:
        bad.append('%d poison(s) reported POISON FAILED as a VERDICT -- a '
                   'poison that does not move its number is a comment that '
                   'says the word POISONED' % len(_failed_verdicts))
    # ...and every poison must actually carry a FIRED verdict.
    _fired = len(re.findall(r'VERDICT: POISON \d FIRED', t))
    if _fired != 4:
        bad.append('%d of the 4 poisons carry a "VERDICT: POISON n FIRED" '
                   'line' % _fired)
    if 'ALL FOUR FIRED: yes' not in t:
        bad.append('the artifact does not say ALL FOUR FIRED: yes')
    # each delta must be non-zero: a signed integer or a "5 of 9" pair
    dl = re.findall(r'DELTA: ([^\n]+)', t)
    if len(dl) != 4:
        bad.append('found %d DELTA lines, expected 4' % len(dl))
    for line in dl:
        nums = [int(x) for x in re.findall(r'-?\d+', line)]
        nums = [x for x in nums if x not in (1, 2, 3, 4, 9)]  # the "of 9"
        if not nums or all(x == 0 for x in nums):
            bad.append('a poison DELTA moves nothing: %r' % line.strip())
    # POISON 2's SIGN is the finding: the bug REMOVES edges, so +1 would be a
    # different bug and a poison that only checked "did anything move" would
    # have missed it.
    if 'DELTA: edges -15' not in flat:
        bad.append("poison 2's delta is not `edges -15` -- the SIGN is the "
                   'finding, because the bug removes edges and makes the '
                   'allocator report a BETTER spill count')
    print('  --  4 poisons, all FIRED, deltas: %s'
          % ' | '.join(d.strip()[:28] for d in dl))

    # THE TWO-READER CHECK AND THE FIRE TABLE.  9 words, 9 agree, 0 disagree;
    # and TWO OF THE SIX RULES ARE DEAD BY DESIGN AND LABELLED AS SUCH.  A
    # verifier that asserted every rule fires would be asserting something
    # false about a healthy artifact.
    if not re.search(r'9 words, 9 agree,\s*\n?\s*0 disagree', t):
        bad.append('the two-reader line is not "9 words, 9 agree, 0 disagree"')
    for rule in ('collapse space', 'comma before shift or immediate',
                 'hex immediate', 'mnemonic case',
                 'drop register size suffix', 'sp alias'):
        if rule not in t:
            bad.append('the fire table has no row for %r, so a rule that '
                       'never fires is an absence rather than a row' % rule)
    by_design = re.findall(r'NEVER FIRED -- BY DESIGN', t)
    if len(by_design) != 2:
        bad.append('%d rules are labelled NEVER FIRED -- BY DESIGN, expected 2'
                   % len(by_design))
    if 'THE DEAD ONES: collapse space, drop register size suffix, sp alias' \
            not in t:
        bad.append('the artifact does not name the dead rules, and a fire '
                   'table that does not say which rules are dead is a table '
                   'of zeroes nobody reads')
    if '6 rules, 3 fired, 3 matched nothing' not in t:
        bad.append('the fire table summary line is not "6 rules, 3 fired, 3 '
                   'matched nothing"')

    # THE NON-LINEARITY, asserted as the artifact's own three-row verdict
    # table rather than as a number a page could round.
    if 'INSIDE THE NOISE: not distinguishable from the 1-SPILL cost' not in t:
        bad.append('the artifact does not say the 2-spill arm is '
                   'indistinguishable from the 1-spill arm, so the '
                   'NON-LINEARITY cannot be checked')
    if 'ABOVE THE NOISE: clearly more than the 1-SPILL cost' not in t:
        bad.append('the artifact does not say the 4-spill arm separates')

    # THE FOUR ARMS AGREE, because a timing table whose arms disagree is four
    # unknowns and not a comparison.
    arms = re.findall(r'5925179420309322629', t)
    if len(arms) < 4:
        bad.append('the four timing arms do not all carry the same checksum '
                   '(%d occurrences) -- a timing table whose arms disagree is '
                   'not a comparison' % len(arms))

    # THE TIMING EXCEPTION IS WRITTEN DOWN rather than discovered by a failed
    # cmp, and the bands-not-ticks reason is stated in it.
    if 'CANNOT BE BYTE-IDENTICAL BETWEEN TWO RUNS' not in flat:
        bad.append('the artifact does not state that a clock reading and a '
                   'byte-identical file cannot both be true, so the bands '
                   'rather than the ticks has no stated reason')
    if 'courses/compback/assets/samples/cbbench.out' not in t:
        bad.append('the artifact does not point at cbbench.out, so a reader '
                   'cannot find the exact ticks it deliberately replaced')

    # THE DETERMINISM TRIPLE, which is the property the whole recorded-output
    # decision rests on.
    for f in ('compback.out', 'run1.txt', 'run2.txt'):
        if not os.path.isfile(os.path.join(_samples, f)):
            bad.append('%s is not committed, so the two-run determinism check '
                       'has nothing to compare' % f)
    _c = subprocess.run(['cmp', '-s',
                         os.path.join(_samples, 'compback.out'),
                         os.path.join(_samples, 'run1.txt')],
                        capture_output=True)
    if _c.returncode != 0:
        bad.append('compback.out and run1.txt are NOT byte-identical -- the '
                   'determinism claim this course rests on is false')
    _c2 = subprocess.run(['cmp', '-s',
                          os.path.join(_samples, 'run1.txt'),
                          os.path.join(_samples, 'run2.txt')],
                         capture_output=True)
    if _c2.returncode != 0:
        bad.append('run1.txt and run2.txt are NOT byte-identical')

    # --- the TWO KNOWN ARTIFACT DEFECTS, asserted as KNOWN ----------------
    # Both are hand-written counts in prose that no longer match the lists
    # they summarise.  They are NOT repaired: compback.out is the committed
    # artifact and three files must stay byte-identical, and a verifier that
    # fixed them would be checking something other than what ships.  They are
    # asserted HERE so the next reader learns about them from this file.
    marked = len(re.findall(r'(?m)^\s+NOT MEASURED HERE\s*$', t))
    if marked != 2:
        bad.append('section 12 marks %d rows `NOT MEASURED HERE`; expected 2 '
                   '(its header says THREE, which is a known artifact defect '
                   '-- see this file\'s docstring)' % marked)
    if 'AND THE THREE ROWS THAT ARE QUOTED' not in t:
        bad.append("section 12's header sentence is gone, so the known "
                   'three-against-two defect can no longer be described')
    print('  --  KNOWN artifact defect: section 12 says THREE marked rows and '
          'prints %d (published, not repaired)' % marked)

    _cp = os.path.join(_samples, 'corrupt.py')
    if not os.path.isfile(_cp):
        bad.append('corrupt.py is missing, so nothing has demonstrated that '
                   'this course\'s harness can FAIL')
    else:
        src = open(_cp, errors='replace').read()
        real_c = len(re.findall(r'^    \(', src, re.M))
        if 'TWENTY-TWO WAYS' in t and real_c != 22:
            print('  --  KNOWN artifact defect: section 18 says TWENTY-TWO '
                  'corruptions and the suite applies %d (published, not '
                  'repaired)' % real_c)

    # THE HARNESS, against the SHIPPED output.
    # An ABSOLUTE path, because `cwd=_samples` makes a relative one resolve
    # against the samples directory and the interpreter then looks for
    # `samples/samples/crosscheck.py`.  Both harnesses below are invoked the
    # same way and this is the first thing to check when one of them reports
    # "printed no tally" on a machine where it demonstrably prints one.
    _cc = subprocess.run([sys.executable,
                          os.path.abspath(os.path.join(_samples,
                                                       'crosscheck.py'))],
                         capture_output=True, text=True, cwd=_samples)
    _tally = re.search(r'(\d+) checks, (\d+) failures', _cc.stdout)
    if not _tally:
        bad.append('crosscheck.py printed no tally: %s'
                   % (_cc.stdout.strip().splitlines()[-1]
                      if _cc.stdout else _cc.stderr[:80]))
    elif _cc.returncode != 0 or _tally.group(2) != '0':
        bad.append('crosscheck.py: %s checks, %s failures'
                   % (_tally.group(1), _tally.group(2)))
    else:
        print('\ncrosscheck.py: %s/%s recorded claims still hold, against the '
              'SHIPPED compback.out' % (_tally.group(1), _tally.group(1)))

    # THE CORRUPTION SUITE -- the check that makes the other one mean
    # something.  Every corruption must be CAUGHT, and a count here is read
    # from corrupt.py's OWN output rather than asserted, because the
    # artifact's prose count is stale (see above) and a verifier that trusted
    # it would be asserting a number the suite contradicts.
    _cr = subprocess.run([sys.executable, os.path.abspath(_cp)],
                         capture_output=True, text=True, cwd=_samples)
    _cr_t = re.search(r'(\d+) corruptions, (\d+) caught, (\d+) missed, '
                      r'(\d+) errored', _cr.stdout)
    if not _cr_t:
        bad.append('corrupt.py printed no tally: %s'
                   % (_cr.stdout.strip().splitlines()[-1]
                      if _cr.stdout else _cr.stderr[:80]))
    elif _cr.returncode != 0 or int(_cr_t.group(2)) != int(_cr_t.group(1)):
        bad.append('corrupt.py: %s of %s corruptions were CAUGHT, %s missed '
                   'and %s errored'
                   % (_cr_t.group(2), _cr_t.group(1), _cr_t.group(3),
                      _cr_t.group(4)))
    else:
        print('corrupt.py:  %s corruptions, %s caught, 0 missed -- so the '
              'harness is a harness and not a rubric'
              % (_cr_t.group(1), _cr_t.group(2)))

print('\n' + '=' * 70)
if bad:
    print('  %d PROBLEMS' % len(bad))
    for b in bad:
        print('   - %s' % b)
else:
    print('  ALL CONSISTENT: %d concepts, %d links all 200, the %d outbound '
          'ids PRESENT and the %d retired ids ABSENT, chain, minutes, six '
          'units a page, three labels with a provenance sum that adds up, %d '
          'numbered limits, two scope lists of %s and %s in order, %d '
          'retractions with a SOURCE each, four non-zero poison deltas with '
          'poison 2 SIGNED, a fire table with 2 rules dead BY DESIGN, the '
          'non-linear spill cost stated rather than rounded, one timing '
          'exception written down, and the course\'s own harness plus its '
          'corruption suite to agree -- with the two known artifact defects '
          'published rather than repaired'
          % (len(pages), len(real), len(OUTBOUND), len(RETIRED), 15,
             cn.group(1) if cn else '?', ca.group(1) if ca else '?', want))
print('=' * 70)
sys.exit(1 if bad else 0)
