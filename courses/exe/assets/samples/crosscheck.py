#!/usr/bin/env python3
"""crosscheck.py -- re-derive every claim the execution course makes.

Run ./build_samples.sh first.

    python3 crosscheck.py        # the summary
    python3 crosscheck.py -v     # every check, passing or not

Almost every check here asserts a SHAPE rather than a value: that a
dependent chain grows monotonically with its length, that the marginal cost
of a dependency exceeds the marginal cost of an independent operation, that
every bench function is 64-byte aligned. Shapes survive a 15% noise floor
and a boost clock; absolute numbers do not, which is why the course quotes
ratios and minima and this file asserts nothing else.

The one check that is an exact value is the alignment, because it is read
out of the ELF symbol table rather than out of a clock.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VERBOSE = '-v' in sys.argv
results = []


def ck(group, label, ok, detail=''):
    results.append((group, label, bool(ok)))
    if not ok or VERBOSE:
        print('  %-4s %-54s %s%s'
              % ('ok' if ok else 'FAIL', label, detail,
                 '' if ok else '   <-- FAILED'))
    return ok


def sh(*args):
    r = subprocess.run(list(args), capture_output=True, text=True, cwd=HERE)
    return r.stdout + r.stderr


# ---------------------------------------------------------------------------
# cycbench's output, parsed into rows so the checks read the SAME numbers a
# reader of the course sees, rather than a second measurement.
# ---------------------------------------------------------------------------
ROW = re.compile(
    r'^\s{2,}(?P<label>\S.*?\S)\s{2,}(?P<num>[\d.]+)\s+(?P<ratio>[\d.]+)x\s*$')
# The `\d+ adds` is load-bearing. Without it this also matches the PROSE
# line "independent ones retire several per cycle", which then overwrites the
# real marginals with an empty list -- and the check that depends on them
# fails for a reason that has nothing to do with the machine.
MARG = re.compile(
    r'^\s*(?P<what>dependent chain|independent)\s+'
    r'(?P<rest>\d+\s+adds\b.*)$')
DELTA = re.compile(r'\+(?P<v>[\d.]+)')


def parse_cycbench():
    out = sh('./cycbench')
    rows, marginals, noise = {}, {'dep': [], 'ind': []}, None
    for line in out.splitlines():
        m = ROW.match(line)
        if m:
            rows[m.group('label')] = (float(m.group('num')),
                                      float(m.group('ratio')))
        m = MARG.match(line.strip())
        if m:
            marginals['dep' if m.group('what').startswith('dep') else 'ind'] \
                = [float(d.group('v')) for d in DELTA.finditer(m.group('rest'))]
        m = re.search(r'spread ([\d.]+)%', line)
        if m and noise is None:
            noise = float(m.group(1))
    spread = None
    m = re.search(r'fastest ([\d.]+)\s+slowest ([\d.]+)\s+ratio ([\d.]+)x', out)
    if m:
        spread = (float(m.group(1)), float(m.group(2)), float(m.group(3)))
    mispred = 'no hardware performance counters in this guest' in out
    return out, rows, marginals, noise, spread, mispred


def main():
    if not os.path.exists(os.path.join(HERE, 'cycbench')):
        print('  cycbench not built -- run ./build_samples.sh first')
        return 2
    out, rows, marg, noise, align_spread, mispred = parse_cycbench()

    print('=' * 78)
    print('  crosscheck -- re-deriving every execution claim')
    print('=' * 78)

    # ---------------------------------------------------------------- A
    ck('A', 'cycbench runs to completion and prints all seven sections',
       all(('  %d.' % i) in out for i in range(1, 8)),
       'sections found: %d' % sum(1 for i in range(1, 8) if ('  %d.' % i) in out))

    # ---------------------------------------------------------------- B
    # The instrument. These are exact because they are read out of the ELF
    # and /proc, not out of a clock.
    m = re.search(r'TSC rate \(vs CLOCK_MONOTONIC\)\s+([\d.]+) GHz', out)
    hz = float(m.group(1)) if m else -1
    ck('B', 'the TSC rate was measured and is plausible', 1.5 < hz < 3.5,
       '%.4f GHz' % hz)
    ck('B', 'the TSC is invariant, so it is usable as a time base',
       'constant_tsc' in sh('grep', '-m1', 'flags', '/proc/cpuinfo')
       and 'nonstop_tsc' in sh('grep', '-m1', 'flags', '/proc/cpuinfo'))
    ck('B', 'the program refuses to call a tick a cycle',
       'unit of TIME' in out and 'stopwatch' in out,
       'the claim is made in the output text itself')
    ck('B', 'the noise floor is measured and reported', noise is not None,
       '%.1f%%' % noise if noise else 'not found')
    ck('B', 'and it is a real, finite, positive spread',
       noise is not None and 0 < noise < 10000,
       '%.1f%%' % noise if noise else '?')
    # NOTE what is deliberately NOT asserted: that the noise floor is below
    # some threshold. It is a measurement of a noisy quantity, so it varies --
    # an early version of this file asserted "< 40%" and failed perhaps one run
    # in five with a spread of 72%, on a machine that had not changed. That is
    # a value claim about a noisy measurement, which is the mistake this
    # course's first concept exists to warn against. The floor is REPORTED
    # and USED as the tolerance below, never bounded.

    # ---------------------------------------------------------------- C
    # THE ALIGNMENT CHECK, which is exact: read the symbol table.
    syms = sh('objdump', '-t', 'cycbench')
    addrs = {}
    for line in syms.splitlines():
        c = line.split()
        if len(c) < 3:
            continue
        name = c[-1]
        if re.match(r'^(b_|aligned_|branchless$|table_walk$)', name):
            addrs[name] = int(c[0], 16)
    ck('C', 'every bench body has a symbol we can check', len(addrs) >= 10,
       '%d symbols' % len(addrs))
    bad = {k: hex(v) for k, v in addrs.items() if v % 64 != 0}
    ck('C', 'EVERY bench body is 64-byte aligned', not bad,
       'misaligned: %s' % bad if bad else '%d bodies, all 0 mod 64' % len(addrs))
    ck('C', 'the aligned bodies include all seven alignment offsets',
       sum(1 for k in addrs if k.startswith('aligned_')) == 8,
       '%d offset variants' % sum(1 for k in addrs if k.startswith('aligned_')))

    # ---------------------------------------------------------------- D
    # SHAPE claims on the latency/throughput table. Monotonicity survives the
    # noise floor; absolute values would not.
    dep = [rows.get(k, (None,))[0] for k in
           ('1 dependent add', '2 dependent adds', '4 dependent adds',
            '8 dependent adds')]
    ind = [rows.get(k, (None,))[0] for k in
           ('1 independent add', '2 independent adds', '4 independent adds',
            '6 independent adds')]
    floor = rows.get('loop floor (empty body)', (None,))[0]
    ck('D', 'every latency/throughput row was parsed',
       all(v is not None for v in dep + ind) and floor is not None,
       'dep %s  ind %s' % (dep, ind))
    ck('D', 'the dependent chain GROWS with its length (monotonic)',
       all(dep[i] < dep[i + 1] for i in range(3)),
       ' -> '.join('%.3f' % v for v in dep))
    ck('D', 'the independent set GROWS once it leaves the floor',
       all(ind[i] < ind[i + 1] for i in range(1, 3)),
       ' -> '.join('%.3f' % v for v in ind))
    # The tolerance is DERIVED from the noise floor the artifact reports,
    # not guessed. The first version hard-coded 15%, which is exactly the
    # measured spread, so a run that landed at 19.7% failed a true claim --
    # and a check that fails at the noise floor is not a check. Any
    # threshold in a harness on a noisy instrument has to be looser than
    # the instrument's own variance, and the only honest source for that
    # number is the measurement.
    tol = max(0.25, 1.5 * (noise or 0) / 100.0)
    ck('D', '1 and 2 independent ops are BOTH at the floor',
       abs(ind[0] - ind[1]) < max(ind[0], ind[1]) * tol,
       '%.3f vs %.3f = %.1f%% apart, tolerance %.0f%% (from a %.0f%% noise floor)'
       % (ind[0], ind[1], 100 * abs(ind[1] - ind[0]) / max(ind[0], ind[1]),
          100 * tol, noise or 0))
    ck('D', 'a 1-operation body is at or near the floor',
       dep[0] < floor * 1.5, '%.3f vs floor %.3f' % (dep[0], floor))
    ck('D', 'a dependent chain of 8 is at least 4x the floor',
       floor and dep[3] > floor * 4,
       '%.2fx' % (dep[3] / floor) if floor else '?')
    ck('D', '8 independent adds cost FAR less than 8 dependent',
       ind[3] * 2 < dep[3],
       'indep %.3f x2 = %.3f  vs  dep %.3f'
       % (ind[3], ind[3] * 2, dep[3]))

    # ---------------------------------------------------------------- E
    # The headline ratio, from the MARGINAL costs.
    dm, im = marg['dep'], marg['ind']
    ck('E', 'the marginal cost of a dependency was measured',
       len(dm) >= 2, ' '.join('%+.3f' % v for v in dm))
    ck('E', 'the marginal cost of an independent op was measured',
       len(im) >= 2, ' '.join('%+.3f' % v for v in im))
    if dm and im:
        dmid = sorted(dm)[len(dm) // 2]
        imid = sorted(im)[len(im) // 2]
        ck('E', 'a dependency costs MORE than an independent operation',
           dmid > imid, 'median marginal dep %+.3f vs indep %+.3f' % (dmid, imid))
        # The factor check uses the TOTALS, not the medians. The totals
        # differ by about 5x, which is far outside any plausible noise; a
        # median of marginals can go near zero on a bad run and produce a
        # ratio of 27x, which is arithmetically true and physically absurd.
        tot_dep = rows.get('8 dependent adds', (0,))[0]
        tot_ind = rows.get('6 independent adds', (0,))[0]
        ck('E', '8 dependent adds cost at least 2x 6 independent adds',
           tot_dep > tot_ind * 2,
           '%.3f vs %.3f = %.2fx -- a 5x effect, far outside the noise'
           % (tot_dep, tot_ind, tot_dep / tot_ind if tot_ind else 0))
        ck('E', 'and by at least 1.5x on the marginals too',
           imid > 0 and dmid > imid * 1.5,
           '%.2fx' % (dmid / imid) if imid else 'indian marginal ~0')

    # ---------------------------------------------------------------- F
    # Branches. The claim is a NEGATIVE one: the period makes no difference.
    br = [rows.get(k, (None, None))[0] for k in
          ('branch never taken (control)', 'branch period 64',
           'branch period 16', 'branch period 4',
           'branch period 1 (alternating)')]
    ck('F', 'every branch row was parsed', all(v is not None for v in br),
       ' '.join('%.3f' % v for v in br if v is not None))
    if all(v is not None for v in br):
        lo, hi = min(br), max(br)
        ck('F', 'the branch period makes NO measurable difference',
           hi / lo < 1.6, 'spread %.2fx across periods 1..64' % (hi / lo))
        ck('F', 'and the control is inside the same spread',
           lo <= br[0] <= hi, 'control %.3f in [%.3f, %.3f]' % (br[0], lo, hi))
    bl = rows.get('BRANCHLESS, same data+work', (None,))[0]
    ck('F', 'the branchless variant is SLOWER than the branch',
       bl is not None and bl > max(br),
       '%.3f vs %.3f' % (bl, max(br)) if bl else '?')
    ck('F', 'and the output says the comparison is NOT clean',
       'NOT A CLEAN COMPARISON' in out and 'UPPER BOUND' in out,
       'the confound is stated in the artifact itself')

    # ---------------------------------------------------------------- G
    # Long-period patterns: the claim is again negative, plus the LIMIT.
    ck('G', 'no mispredict penalty was observed at any table depth',
       'NO mispredict penalty' in out, 'as measured, and as stated')
    ck('G', 'the output calls that a LIMITATION, not a result',
       'THIS IS A LIMITATION' in out)
    ck('G', 'and it says WHY the two explanations cannot be told apart',
       'cannot be' in out and 'COUNTED' in out.upper(),
       'the reason the claim stops where it does')
    ck('G', 'this machine really has no PMU', mispred,
       'perf cannot read branch-misses, so the limit is real')

    # ---------------------------------------------------------------- H
    # Alignment, the effect.
    ck('H', 'the alignment spread was measured', align_spread is not None,
       '%.2fx' % align_spread[2] if align_spread else 'not found')
    if align_spread:
        ck('H', 'byte-identical code differs by at least 1.2x by address alone',
           align_spread[2] > 1.2, '%.2fx' % align_spread[2])
        ck('H', 'and the output declines to claim a mechanism',
           'NOT a simple function' in out and 'NONE of them was measured' in out,
           'the honest form of the claim')

    # ---------------------------------------------------------------- I
    # The retractions, asserted so they cannot be quietly dropped.
    ck('I', 'the 73% noise-floor figure is retracted in the output',
       'A RETRACTION' in out and '73%' in out)
    ck('I', 'and it is explained as alignment leaking into the noise',
       'instrument\'s apparent noise was the phenomenon under study' in out
       or "instrument's apparent noise was the phenomenon under study" in out)
    ck('I', 'the two flags explanations are both retracted in the output',
       out.count('RETRACTION') >= 2 or
       ('A SECOND retraction' in out),
       '%d retraction(s) recorded' % out.count('A RETRACTION'))
    ck('I', 'the flags claim that survives is the narrow one',
       'WRITING the flags is nearly' in out and 'READING them is free' in out)

    print()
    print('=' * 78)
    by = {}
    for g, _, o in results:
        by.setdefault(g, [0, 0])
        by[g][0 if o else 1] += 1
    for g in sorted(by):
        p, f = by[g]
        print('  %-4s %2d passed  %2d failed' % (g, p, f))
    npass = sum(1 for _, _, o in results if o)
    print('-' * 78)
    print('  %d/%d checks passed' % (npass, len(results)))
    print('  %s' % ('ALL CLAIMS HOLD' if npass == len(results)
                    else 'FAILURES -- the course asserts something that no longer holds'))
    return 0 if npass == len(results) else 1


if __name__ == '__main__':
    sys.exit(main())
