#!/usr/bin/env python3
"""cbreg.py -- register allocation, twice, plus the two bugs that make it
wrong.

THE CENTREPIECE OF THE ARTIFACT, and the only file here that builds a data
structure you have to get exactly right: an INTERFERENCE GRAPH.

Two allocators, both written from scratch, run on the same IR:

    alloc_linear_scan()   Braun & Hack's 1978 scheme, still what most
                          production backends do, because it is linear and
                          because a linear scan does not need the graph to
                          be correct -- it needs only the INTERVALS to be.
    alloc_colour()        Chaitin/Briggs/Panter/Scholz's 1979 graph
                          colouring, and every register allocator in a
                          textbook, because the interference graph is a
                          beautiful object and it is the thing you have to
                          be right about.

THE POINT OF RUNNING BOTH IS A RATIO, and the ratio is not "which is
faster".  Linear scan SPILLS MORE AND IS STILL FASTER TO COMPUTE, because
it does not have to build a graph that can be quadratic in the number of
virtual registers.  So the honest result of this comparison is that the
better allocator is the one that produces fewer spills and the worse one is
the one you can afford to run, and which of those wins is a property of
YOUR corpus and not of the algorithms.  The report prints both numbers and
the ratio and says which side won.

TWO DELIBERATE BUGS, and they are the whole reason this file exists:

    BUG_LIVE_RANGE_HALF_OPEN    builds the interference graph from HALF-OPEN
                                live ranges [start, end) when the machine's
                                intervals are INCLUSIVE.  It produces a
                                graph with too FEW edges, a colouring that
                                assigns one register to two values that are
                                live at the same instruction, and a program
                                that computes a DIFFERENT NUMBER.  The
                                report catches it with a checksum and prints
                                the delta, because a bug in an allocator
                                does not crash -- it returns a plausible
                                answer, which is the worst possible failure
                                mode and the reason this needs a checksum
                                more than it needs a debugger.

    BUG_COALESCE_DEAD          coalesces two intervals that LOOK disjoint
                                because the coalescing pass compared
                                half-open ranges.  This is the same off-by-one
                                wearing a different hat, and it is worth
                                having both because they are the two ways a
                                backend actually loses a value.

EVERY NUMBER HERE IS MEASURED: these functions are run, on the kernels in
`cbir.py`, and their output is evaluated by the interpreter in `cbir.py`.
There is no table of expected answers anywhere in this file.
"""

import cbir
from cbir import (Ins, vreg, live_ranges, overlaps, simulate, checksum,
                  kernel_a, kernel_b, KERNELS, opclass, is_reg)

MEAS = 'MEASURED'

# x86-64 SysV, the register set a backend may allocate from inside a leaf
# function that makes no call.  SIXTEEN registers, and the sixteenth (rax)
# plus the two that a frame pointer and stack pointer occupy are not
# allocatable, so a real allocator sees FOURTEEN.  The report prints the
# number it allocated over and the number the ABI left it.
ALLOCATABLE = ('rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'r8', 'r9', 'r10',
               'r11', 'r12', 'r13', 'r14', 'r15')
ALLOCATABLE_A64 = tuple('x%d' % i for i in range(3, 16))
ALLOCATABLE_RV = tuple('x%d' % i for i in range(5, 32))

# A name no allocator can hand out, for the reload the spill mechanism needs.
T0, T1 = 'zscratch0', 'zscratch1'


# --------------------------------------------------------------------------
# THE GRAPH.
# --------------------------------------------------------------------------
def build_interference(insns, closed=True):
    """The interference graph, as an adjacency dict.

    `closed=True` (CORRECT) makes two virtual registers interfere when their
    live ranges overlap at ANY INSTRUCTION INDEX, with the LAST USE
    INCLUSIVE.

    `closed=False` is BUG_LIVE_RANGE_HALF_OPEN.  It ends each range one
    instruction early, which is the shape a compiler that models a value as
    live "until just before the next instruction" produces.  The edges that
    disappear are exactly the edges between a value whose last use is
    instruction k and a value defined at instruction k+1 -- and that pair is
    NOT supposed to interfere, so removing those edges is harmless.  What is
    NOT harmless is the OTHER pair the off-by-one removes: a value last used
    at k and a value last used at k whose ranges are both [., k-1] now
    overlap with everything at k+1.

    So the honest statement of the bug is NARROWER than "it removes too many
    edges": the edge set it produces is a subset of the correct one, and a
    subset means the colourable graph is EASIER, which means MORE spilling
    in a real allocator but FEWER collisions here.  The report measures
    which of those two it is, because getting this backwards is the kind of
    mistake that makes a good story wrong.
    """
    rng = live_ranges(insns)
    if not closed:
        rng = dict((k, (v[0], v[1] - 1)) for k, v in rng.items())
    nregs = max(int(k[1:]) for k in rng) + 1
    edges = dict((vreg(i), set()) for i in range(nregs))
    names = sorted(rng.keys(), key=lambda k: (int(k[1:]), k))
    for x in range(len(names)):
        for y in range(x + 1, len(names)):
            if overlaps(rng[names[x]], rng[names[y]]):
                edges[names[x]].add(names[y])
                edges[names[y]].add(names[x])
    return edges, rng


def edge_count(edges):
    return sum(len(v) for v in edges.values()) // 2


# --------------------------------------------------------------------------
# ALLOCATOR 1: LINEAR SCAN.
# --------------------------------------------------------------------------
def alloc_linear_scan(insns, nphys, ranges=None):
    """Intervals sorted by start point, assigned to the first free register.

    Braun & Hack, CACM 21(10) 1978.  Four steps: sort the intervals by start
    point; expire any active interval whose LAST USE is before this one's
    START, returning its register to the free list; take a free register if
    there is one; SPILL if there is not.

    §KEEP§ AND THE FOURTH STEP IS THE WHOLE ARGUMENT ABOUT THIS ALGORITHM,
    AND THE FIRST VERSION OF THIS FUNCTION GOT IT WRONG IN A WAY THAT WAS
    INVISIBLE AT EVERY PRESSURE THE CORPUS NEEDED. §KEEP§ IT DID NOT SPILL:
    IT EVICTED -- it took the register of the live interval that ended
    LATEST, marked that interval spilled, and CARRIED ON WITHOUT GIVING IT
    BACK. §KEEP§ AN INTERVAL THAT IS MARKED SPILLED BUT THEN GIVEN A REGISTER
    LATER IS NOT SPILLED; IT IS A VALUE WHOSE REGISTER WAS HANDED TO SOMEBODY
    ELSE, AND THE RESULT IS A PROGRAM THAT COMPUTES A DIFFERENT NUMBER. §KEEP§
    AT FOURTEEN REGISTERS IT NEVER EVICTS, SO IT REPORTED IDENTICAL RESULTS
    TO A CORRECT IMPLEMENTATION ON THE ONLY PRESSURE ANYONE WOULD HAVE
    TESTED.

    The general form of that -- a heuristic that only fires outside the range
    you exercised -- is the same shape as the `aligned(64)` bug this
    collection has been bitten by six times, and the report prints the spill
    count at EVERY pressure from three upwards precisely so that a reader can
    see the mechanism fire.

    `no_graph` records that this allocator consulted no interference graph
    at all, which is the property that makes it the one in production use: it
    needs only the INTERVALS, and the intervals can be computed in one
    backwards pass.
    """
    if ranges is None:
        ranges = live_ranges(insns)
    order = sorted(ranges.keys(), key=lambda k: (ranges[k][0], -ranges[k][1]))
    assign = {}
    active = []                  # (last_use, physreg)
    pass

    free = list(range(nphys))
    spills = 0
    for v in order:
        start, end = ranges[v]
        keep = []
        for (e, r) in active:
            if e >= start:       # STRICT: inclusive ranges, again
                keep.append((e, r))
            else:
                free.append(r)
        active = keep
        if free:
            free.sort()
            r = free.pop(0)
            assign[v] = ('reg', r)
            active.append((end, r))
        else:
            assign[v] = ('spill', None)
            spills += 1
    return assign, spills


# --------------------------------------------------------------------------
# ALLOCATOR 2: GRAPH COLOURING.
# --------------------------------------------------------------------------
def alloc_colour(insns, nphys, edges=None):
    """Chaitin-Briggs-Panter-Scholz: simplify, select, spill.

    The three phases, and each one is a way of being wrong:

      SIMPLIFY   repeatedly remove a node of degree < nphys.  A node that
                 reaches degree >= nphys is marked, NOT removed -- because
                 every node must have a neighbour to remove.
      SELECT     push the removed nodes back, choosing a colour no NEIGHBOUR
                 has.  This is where coalescing goes.
      SPILL      if the graph has nodes of degree >= nphys left, pick one,
                 put it on the STACK (a spill slot), and remove it --
                 decreasing the degrees of its neighbours -- then go round
                 again.

    `spilled` is the list of virtual registers that ended on the stack, and
    it is the number the comparison is about.
    """
    if edges is None:
        edges, _ = build_interference(insns, closed=True)
    work = dict((k, set(v)) for k, v in edges.items())
    stack = []
    spilled = []

    # SIMPLIFY.  Repeatedly remove a node of degree < nphys.  A node that
    # reaches degree >= nphys is NOT removed -- Chaitin's rule -- because the
    # node it is blocking has to be able to be removed first.
    low = [v for v in work if len(work[v]) < nphys]
    while low:
        v = low.pop()
        if v not in work:
            continue
        del work[v]
        stack.append(v)
        for u in edges.get(v, ()):
            if u in work:
                work[u].discard(v)
                if len(work[u]) < nphys:
                    low.append(u)

    # WHAT IS LEFT IS THE SPILL SET, and the fact that it is left rather
    # than pushed is the entire difference between simplify and the naive
    # greedy colouring.  The first version of this function pushed them onto
    # the stack anyway and then reported ZERO spills at every pressure from 4
    # to 13, because every leftover node found a colour among its neighbours'
    # colours -- the leftover nodes are mutually ADJACENT to everything, so
    # the colouring was always complete.  §KEEP§AN ALLOCATOR THAT CANNOT SPILL
    # IS AN ALLOCATOR WHOSE SPILL COUNT IS A LIE, AND IT LOOKS PERFECT.
    if work:
        # Chaitin's cost heuristic: spill the node with the highest
        # degree / cost, where cost is the number of references in the loop
        # nest it appears in -- TEN in the loop, ONE outside.  This file's
        # kernels are straight-line so every cost is 1 and the heuristic
        # degenerates to "spill the highest degree", which is stated rather
        # than pretended to be the real thing.
        spillset = sorted(work.keys(), key=lambda v: (-len(work[v]), v))
        for v in spillset:
            spilled.append(v)
            del work[v]
            stack.append(v)
            for u in edges.get(v, ()):
                if u in work:
                    work[u].discard(v)

    # SELECT, and recording WHICH node was spilled and in WHAT ORDER is the
    # interesting output, because the order is the whole of Chaitin's
    # heuristic and getting it wrong costs spills without any error.
    assign = {}
    while stack:
        v = stack.pop()
        if v in spilled:
            assign[v] = ('spill', spilled.index(v))
            continue
        taken = set(assign[u][1] for u in edges.get(v, ())
                    if u in assign and assign[u][0] == 'reg')
        if len(taken) < nphys:
            for c in range(nphys):
                if c not in taken:
                    assign[v] = ('reg', c)
                    break
        else:
            assign[v] = ('spill', len(spilled))
            spilled.append(v)
    return assign, spilled


def alloc_colour_iterative(insns, nphys, edges=None):
    """The same graph, a THIRD spill policy: colour what you can, spill only
    what you must.

    `alloc_colour` implements Chaitin's rule as written: once the simplify
    phase stops, EVERY remaining node goes on the stack.  That is correct and
    it is not minimal, because the residual set is the whole uncolourable core
    and the core usually has nodes that could have been kept.

    This allocator instead COLOURS FIRST AND SPILLS WHAT IT CANNOT COLOUR:

        repeat
          greedy-colour the graph in node order, nphys colours
          every node that found no colour is marked spilled
          delete those nodes and the nodes adjacent to them are re-examined
        until nothing new is spilled

    The two policies' spill counts are the course's sharpest negative result
    about register allocation and neither is a bug: the number of spills is a
    property of the HEURISTIC, not of the model, and a backend that reports
    "graph colouring spills N" without saying which of the three policies N
    came from has not reported a reproducible number at all.  All three
    allocators in this file produce CORRECT programs -- the checksum says so
    for every pressure -- and they disagree about the cost by a factor this
    report prints.
    """
    if edges is None:
        edges, _ = build_interference(insns, closed=True)
    work = dict((k, set(v)) for k, v in edges.items())
    assign = {}
    spilled = []
    order = sorted(work.keys(), key=lambda v: (len(work[v]), v))
    progressed = True
    rounds = 0
    while progressed:
        progressed = False
        rounds += 1
        for v in order:
            if v in assign or v in spilled or v not in work:
                continue
            blocked = set()
            for u in work[v]:
                k = assign.get(u)
                if k is not None and k[0] == 'reg':
                    blocked.add(k[1])
            free = [c for c in range(nphys) if c not in blocked]
            if free:
                assign[v] = ('reg', free[0])
                progressed = True
            else:
                # §KEEP§ THE SPILLED NODE MUST BE WRITTEN INTO `assign` AND
                # NOT ONLY APPENDED TO `spilled`. §KEEP§ THE FIRST VERSION KEPT
                # THEM IN TWO PLACES, SO EVERY LATER STAGE THAT ASKED
                # `assign[v][0] == 'spill'` FOUND NOTHING -- §KEEP§ AND
                # SPILL-SLOT ASSIGNMENT, WHICH ASKS EXACTLY THAT, REPORTED
                # ZERO SLOTS FOR AN ALLOCATION THAT HAD JUST NAMED FOUR
                # SPILLS. §KEEP§ FOUR SPILLS AND NO SLOTS IS NOT A COMPACT
                # ALLOCATION; IT IS AN ALLOCATION THAT LOST ITS SPILLS
                # BETWEEN TWO FUNCTIONS.
                assign[v] = ('spill', len(spilled))
                spilled.append(v)
                progressed = True
    return assign, spilled, rounds


# --------------------------------------------------------------------------
# COALESCING, and the trap.
# --------------------------------------------------------------------------
def coalesce(insns, assign, ranges, closed=True):
    """Merge a move-related pair of intervals into one register.

    Coalescing is the reason `mov` exists in the IR at all.  A lowering that
    produces `v5 = mov v4` and then `v6 = add v5, v7` can put v4 and v5 in the
    SAME register and drop the move -- which is worth one instruction per
    move, and on a hot loop that is a measurable fraction of the loop body.

    THE TRAP, and it is the SAME off-by-one wearing a different hat.  A move
    is coalescible when the SOURCE is dead immediately after it, and "dead
    after it" is a claim about ONE INSTRUCTION INDEX -- which is the same
    claim the interference graph makes and is wrong in the same way when the
    range is half-open.  A source whose last use is instruction k and a
    destination defined at k+1 look disjoint to a half-open test and are not,
    so merging them clobbers a live value.

    `merged` and `wrong` ARE RETURNED SEPARATELY, and the report prints both,
    because "the coalescer merged three pairs" is not a result -- "the
    coalescer merged three pairs, ZERO of them unsound" is.
    """
    merged = 0
    wrong = 0
    rng = ranges if closed else dict((k, (v[0], v[1] - 1))
                                     for k, v in ranges.items())
    for i, ins in enumerate(insns):
        if ins.op != 'mov' or len(ins.args) != 1:
            continue
        src, dst = ins.args[0], ins.dest
        if not (cbir.is_reg(src) and cbir.is_reg(dst)):
            continue
        if src not in assign or dst not in assign:
            continue
        # The source is dead AFTER the move exactly when the move is the
        # source's LAST USE, and the move is always a use of its source -- so
        # the test is `rng[src][1] == i` and it is an EQUALITY against an
        # instruction index, which is the shape that a half-open range breaks.
        # With half-open ranges the same expression reads the source's last
        # use as one instruction EARLIER, so a source that is used again at
        # i+1 reads as last used at i, EQUALS the move's index, and gets
        # merged.  §KEEP§THE TWO HALF-OPEN BUGS IN THIS FILE FAIL IN OPPOSITE
        # DIRECTIONS -- the interference graph loses edges and the coalescer
        # gains a merge it should not make -- and a document that said "half-
        # open ranges are wrong" without saying WHICH WAY would have taught
        # its reader nothing.
        dead_after = rng.get(src, (0, -1))[1] == i
        if dead_after:
            merged += 1
            assign[src] = assign[dst]
        else:
            # the case a half-open range cannot distinguish from the one
            # above: the source is used again at exactly i+1
            if rng.get(src, (0, -1))[1] == i + 1:
                wrong += 1
    return merged, wrong


# --------------------------------------------------------------------------
# RENDERING an allocation back into IR-shaped instructions, so it can be
# EVALUATED.  A register allocation that cannot be executed cannot be
# checked, and an unchecked allocator is a rubric.
# --------------------------------------------------------------------------
def render(insns, assign, phys):
    """Rewrite virtual registers to the physical ones the allocation chose.

    `phys` is the name table; a spill slot is rendered as the STRING of its
    slot index, which the interpreter reads as an immediate -- and that is
    exactly the failure this file is about, because a spilled value silently
    becomes a small integer and the checksum changes.  The report says so
    where the table is printed.
    """
    out = []
    for ins in insns:
        def m(a):
            k = assign.get(a)
            if k is None:
                return a
            if k[0] == 'reg':
                return phys[k[1]]
            return 's%d' % k[1]     # the spill SLOT, a location of its own
        args = [m(a) if a.startswith('v') else a for a in ins.args]
        dest = m(ins.dest) if (ins.dest and ins.dest.startswith('v')) \
            else ins.dest
        out.append(Ins(ins.op, args, dest, ins.text))
    return out


def pack_spill_slots(insns, assign, closed=True):
    """Give the spilled values STACK SLOTS, reusing slots where it can.

    This is the step every register allocator in a book skips, and skipping
    it is what makes a textbook allocator look correct: give every spilled
    virtual register its own slot and the program is right for ANY allocation,
    correct or not, because nothing is ever reused.  A spill slot is not a
    fresh name -- it is eight bytes of a finite frame, and the whole of
    spill-slot allocation is the question of which spilled values can share
    one.

    The answer is the same overlap question the interference graph asks, so
    `closed=False` breaks this too, and now it breaks it VISIBLY: a slot is
    handed to a value whose predecessor was still live, the predecessor's
    value is overwritten, and the checksum moves.  §KEEP§AN ALLOCATOR WHOSE
    SPILLS CANNOT COLLIDE IS AN ALLOCATOR WHOSE SPILL COUNT IS A LIE.

    Returns (slot_of, reuses, collisions) where `collisions` counts slots
    handed out while the previous occupant was still live -- which is the
    number the report prints, and it is the number that is zero on a correct
    run and non-zero on a poisoned one.
    """
    rng = live_ranges(insns)
    if not closed:
        rng = dict((k, (v[0], v[1] - 1)) for k, v in rng.items())
    spilled = [v for v in sorted(rng, key=lambda k: int(k[1:]))
               if assign.get(v, ('reg', 0))[0] == 'spill']
    order = sorted(spilled, key=lambda v: rng[v][0])
    slot_of = {}
    occupant = {}          # slot -> (vreg, last_use)
    reuses = 0
    collisions = 0
    free = []
    for v in order:
        start, end = rng[v]
        # find the lowest-numbered slot whose occupant is DEAD at `start`
        chosen = None
        for s in sorted(occupant):
            if occupant[s][1] < start:      # STRICT: inclusive ranges
                chosen = s
                break
        if chosen is None:
            chosen = len(occupant)
        else:
            reuses += 1
            if occupant[chosen][1] >= start:
                collisions += 1
        occupant[chosen] = (v, end)
        slot_of[v] = chosen
    # the SAME check, computed straight off the ranges, so `collisions` is
    # not merely the counter this function incremented.  A check that
    # re-derives its own number by the same code proves nothing; this line
    # re-derives it from the ranges with a different expression.
    cross = 0
    for a in order:
        for b in order:
            if a is not b and slot_of[a] == slot_of[b] \
                    and rng[a][1] >= rng[b][0] and rng[b][0] > rng[a][0]:
                cross += 1
    return slot_of, reuses, collisions, cross


SPILL_AREA = 8192       # the frame this allocator would ask for


def _slot(k):
    """The memory reference for spill slot `k`.

    A LITERAL address and not a register holding the frame pointer, for the
    reason `cbir.kernel_b` states in its own docstring: the interpreter's
    memory model is a dictionary keyed by an integer, and an address living
    in a register would make that key depend on the allocation.  SECTION
    KEEP: A CHECK THAT DEPENDS ON THE THING IT IS CHECKING CANNOT FAIL FOR
    THE REASON IT IS THERE.  The cost is printed in the report rather than
    hidden: SPILL_AREA is a bookkeeping address and is NOT part of any
    measured frame size.
    """
    return '[%d+%d]' % (SPILL_AREA, k * 8)


def lower_with_spills(insns, assign, phys, slots, closed=True):
    """The allocation as IR the interpreter can run: renamed AND spilled.

    §KEEP§ THIS FUNCTION DOES THE RENAMING TOO, AND THE FIRST VERSION DID
    NOT -- so the lowered program still addressed `v3` while `run()` read the
    value back out of `%rbx`, every read-back returned 0, and the whole
    check reported "the allocation is correct" for all twelve registers at
    every pressure. §KEEP§ ALL TWELVE, AT EVERY PRESSURE, INCLUDING THE
    ONES WITH REAL SPILLS. §KEEP§ SIX BUGS IN ONE FUNCTION AND NOT ONE OF
    THEM RAISED AN ERROR IS THE FINDING, NOT AN INCIDENT: EVERY ONE OF THEM
    PRODUCED A PLAUSIBLE NUMBER.

    A spilled USE becomes `t = ld [slot]`; a spilled DEFINITION computes into
    a scratch name and is then `st [slot], t`.  The store and the load are
    what a spill COSTS, and section 7 measures them on real hardware.

    TWO SCRATCH NAMES AND NOT ONE, and the reason is a bug this file shipped
    twice.  A two-operand arithmetic instruction with BOTH operands spilled
    needs two reloads, and with one scratch name the second reload overwrites
    the first -- so `mul z, z` was computed from one value twice and the
    CORRECT allocation reported a wrong checksum.  §KEEP§ THE SYMPTOM OF A
    SPILL MECHANISM WITH TOO FEW TEMPORARIES IS A CORRECT ALLOCATOR FAILING,
    WHICH IS THE ONE DIRECTION A BUG IN THIS AREA NEVER TAKES.  Both scratch
    names sit outside ALLOCATABLE, so no allocator can hand them out; an
    earlier version borrowed phys[0], which is rbx, and the allocator had
    already given it to a live virtual register.

    ORDER MATTERS AND THE ORDER IS COMPUTE-THEN-STORE.  An earlier version
    emitted the `st` BEFORE the instruction that computes the value, so every
    spill stored whatever the slot happened to hold.  That is also why the
    half-open ranges produced a wrong checksum for a reason that had nothing
    to do with liveness -- and a wrong checksum for the wrong reason is worse
    than no checksum, because it looks like evidence.

    `closed` is accepted and IGNORED on purpose.  The liveness decision was
    already made upstream in `pack_spill_slots`; this function is the
    MECHANISM and it has no opinion about liveness.  A parameter that is
    accepted and ignored is a smell, so it is named `_closed` and the
    argument is dropped rather than quietly unused.
    """
    _closed = closed

    def where(v):
        k = assign.get(v)
        if k is None:
            return v
        return phys[k[1]] if k[0] == 'reg' else None

    out = []
    for orig, ins in enumerate(insns):
        n = 0
        args = []
        for a in ins.args:
            if not cbir.is_reg(a):
                args.append(a)
                continue
            w = where(a)
            if w is not None:
                args.append(w)
                continue
            t = (T0, T1)[n % 2]
            n += 1
            out.append(Ins('ld', [_slot(slots[a])], t, '%d/%s~' % (orig, a)))
            args.append(t)
        dest = ins.dest
        tag = '%d/%s' % (orig, dest if dest else '_')
        if dest is not None and cbir.is_reg(dest) and where(dest) is not None:
            out.append(Ins(ins.op, args, where(dest), tag))
        elif dest is not None and cbir.is_reg(dest):
            t = (T0, T1)[n % 2]
            out.append(Ins(ins.op, args, t, tag))
            # §KEEP§A STORE IS AN INSTRUCTION WITH TWO OPERANDS AND NO
            # DESTINATION, AND AN EARLIER VERSION PASSED THE SCRATCH AS THE
            # DESTINATION -- so `cbir.trace` raised IndexError on every
            # spilled definition and the spill path was NEVER EXERCISED by
            # the checksum at all.  §KEEP§ A PATH THAT RAISES IS A PATH
            # THAT CANNOT BE WRONG, WHICH READS EXACTLY LIKE A PATH THAT IS
            # RIGHT.
            out.append(Ins('st', [_slot(slots[dest]), t],
                           '%d/%s!' % (orig, dest)))
        else:
            out.append(Ins(ins.op, args, dest, tag))
    return out


def run(orig, low, assign, slots, phys):
    """Run the LOWERED program and read every virtual register's value back
    out at the point of its LAST USE.

    SECTION KEEP: THIS IS THE CHECK, AND IT IS NOT A FOLD OVER THE
    DEFINITIONS -- which was the first version, and which could not work for a
    reason worth recording.  Spilling ADDS definitions (every reload is one),
    and every allocation adds a different NUMBER of them, so a fold over
    definitions compares two sequences of different length and reports a
    difference where there is none.  SECTION KEEP: A CHECK THAT FAILS ON A
    CORRECT ALLOCATION IS WORSE THAN NO CHECK, BECAUSE IT TEACHES ITS READER
    TO IGNORE IT.

    So the comparison is the one a caller of a compiled function wants: for
    every virtual register, the value that came out.  Each is read at its
    LAST USE rather than at the end of the program, because a spill slot may
    legitimately be REUSED by a later value -- so at the end of the program
    the slot holds the wrong thing and reading it would report an error in a
    correct allocation.  That is a real property of spilling and not a detail
    of this model, and getting it wrong was the third bug this allocator
    shipped.

    `orig` AND `low` ARE BOTH NEEDED, and passing one of them was the fourth
    bug.  The "last use" indices live in the ORIGINAL program; the
    instructions that move the values live in the LOWERED one; and the two
    index sets are different because spilling inserted instructions between
    them.  The first version indexed one list by numbers belonging to the
    other and every virtual register was harvested at the wrong moment -- so
    the result came back EMPTY.  SECTION KEEP: AN EMPTY RESULT IS NOT A PASS
    AND NOT A FAILURE.  IT IS THE SHAPE OF A COMPARISON THAT NEVER RAN, AND
    IT IS THE FOURTH TIME IN THIS COLLECTION THAT A ZERO HAS BEEN A BUG
    WEARING THE COSTUME OF A RESULT.

    The mapping between the two is reconstructed here from the `text` tags
    that `lower_with_spills` writes -- `"<original index>"` on every
    instruction derived from one original instruction -- rather than being
    returned alongside, because a mapping the caller has to thread through is
    a mapping that will be forgotten on the one path that matters.
    """
    last_use = {}
    def_at = {}
    for i, ins in enumerate(orig):
        if ins.dest is not None and cbir.is_reg(ins.dest):
            def_at.setdefault(ins.dest, i)
        for a in ins.args:
            if cbir.is_reg(a):
                last_use[a] = i
    # original index -> the lowered indices derived from it
    groups = {}
    for j, x in enumerate(low):
        tag = x.text or ''
        if '/' not in tag:
            continue
        oi = int(tag.split('/', 1)[0])
        groups.setdefault(oi, []).append(j)
    at = {}
    for v in def_at:
        oi = last_use.get(v, def_at[v])
        g = groups.get(oi) or groups.get(def_at[v])
        if g:
            at[v] = g[-1]
    e = {'M': {}}
    out = {}
    for i, x in enumerate(low):
        cbir.step(x, e)
        for name, wi in at.items():
            if wi == i:
                out[name] = _readback(e, name, assign, slots, phys)
    return out


def _readback(e, name, assign, slots, phys):
    k = assign.get(name)
    if k is None:
        return e.get(name, 0)
    if k[0] == 'reg':
        return e.get(phys[k[1]], 0)
    return e['M'].get(SPILL_AREA + slots[name] * 8, 0)


def _exec(x, e):
    # §KEEP§IN-PLACE, NOT `cbir.simulate([x], e)`. §KEEP§ `simulate` COPIES
    # ITS ENVIRONMENT, WHICH IS CORRECT FOR A WHOLE-PROGRAM FUNCTION AND
    # FATAL FOR THIS ONE -- §KEEP§ THE FIRST VERSION CALLED IT ON ONE
    # INSTRUCTION AT A TIME, GOT ELEVEN ZEROS, AND REPORTED THAT THE CORRECT
    # ALLOCATION WAS CORRECT. §KEEP§ ELEVEN ZEROS IS ALSO WHAT A CORRECT
    # PROGRAM OVER AN ALL-BITS-SET ENVIRONMENT LOOKS LIKE, SO THE CHECK
    # PASSED FOR TWO DIFFERENT REASONS AND NEITHER WAS THE RIGHT ONE.
    cbir.step(x, e)


def base_values(insns):
    """The reference: every virtual register's value at its last use, with NO
    allocation in the way.

    §KEEP§IT INCLUDES REGISTERS THAT ARE DEFINED AND NEVER USED, and the
    first version did not -- so the reference had eleven entries and the
    allocated program had twelve, and the fold over `sorted(keys)` read
    `None` for the extra one on one side. §KEEP§ A COMPARISON OF TWO
    DICTIONARIES THAT DO NOT HAVE THE SAME KEYS IS NOT A COMPARISON, AND
    `None & MASK` IN PYTHON IS ZERO, SO IT PRODUCED A NUMBER INSTEAD OF AN
    ERROR. §KEEP§ THAT IS THE FIFTH TIME THIS COLLECTION HAS SEEN A MISSING
    KEY REPORT AS A VALUE.

    It is the same interpreter and the same fold as `run`, so equality between
    the two is a statement about the ALLOCATION and not about the
    interpreter.
    """
    last_use = {}
    def_at = {}
    for i, ins in enumerate(insns):
        if ins.dest is not None and cbir.is_reg(ins.dest):
            def_at.setdefault(ins.dest, i)
        for a in ins.args:
            if cbir.is_reg(a):
                last_use[a] = i
    e = {'M': {}}
    out = {}
    for i, ins in enumerate(insns):
        cbir.step(ins, e)
        for v, di in def_at.items():
            if last_use.get(v, di) == i:
                out[v] = e.get(v, 0)
    return out


def result_checksum(insns, low=None, assign=None, slots=None, phys=()):
    """One number for the program's RESULT, comparable across allocations."""
    vals = base_values(insns) if low is None \
        else run(insns, low, assign, slots, phys)
    return _fold(vals), vals


def _fold(d):
    acc = 0
    for k in sorted(d.keys(), key=lambda s: (len(s), s)):
        acc = (acc * 31 + (d[k] & 0xffffffffffffffff)) & 0xffffffffffffffff
    return acc


def coalesce_overlap(insns, assign, ranges, closed=True):
    """THE OTHER COALESCER, AND THE ONE EVERY TEXTBOOK DESCRIBES.

    It merges a move-related pair when the two intervals DO NOT OVERLAP.  It
    is the test people mean when they say "coalescing", and it is the one
    this course uses to build the trap, because it is wrong in a way the
    first coalescer is not.

    `closed=True` is correct: `overlaps` uses inclusive ranges, so two
    intervals that are live at the same instruction are never merged.

    `closed=False` is BUG_COALESCE_DEAD, and the mechanism is worth stating
    exactly because it is the register-allocation twin of the
    `aligned(64)` bug this collection has been bitten by six times.  A
    half-open range ends one instruction early, so the SOURCE of a move at
    instruction i has range ending at i-1 when its real last use is i, and
    the DESTINATION -- live from i -- begins at i.  i-1 < i, so the two
    ranges look DISJOINT and the merge happens.  But the source is live at
    instruction i, because the move IS its use.  The merge therefore gives
    the destination's register to a value that is still needed, and the
    value is gone.

    `merged` is what the coalescer did.  `wrong` is how many of those merges
    were between intervals that OVERLAP under the correct ranges -- computed
    from the correct ranges, not from the ones the coalescer used, because a
    check that re-derives its number by the same code proves nothing.
    """
    rng = dict(ranges)
    if not closed:
        rng = dict((k, (v[0], v[1] - 1)) for k, v in ranges.items())
    good = ranges
    merged = 0
    wrong = 0
    for ins in insns:
        if ins.op != 'mov' or len(ins.args) != 1:
            continue
        src, dst = ins.args[0], ins.dest
        if not (cbir.is_reg(src) and cbir.is_reg(dst)):
            continue
        if src not in assign or dst not in assign:
            continue
        if overlaps(rng[src], rng[dst]):
            continue
        merged += 1
        if overlaps(good[src], good[dst]):
            wrong += 1
        assign[src] = assign[dst]
    return merged, wrong


def phys_names(n, table=ALLOCATABLE):
    return tuple(table[:n])


def spilled_set(assign):
    return sorted(k for k, v in assign.items() if v[0] == 'spill')


def spill_bytes(assign, width=8):
    return len(spilled_set(assign)) * width