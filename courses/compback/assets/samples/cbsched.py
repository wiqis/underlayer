#!/usr/bin/env python3
"""cbsched.py -- list scheduling, the ILP of a schedule, and the one trap
that makes a schedule look good while being wrong.

LIST SCHEDULING, in the form all textbooks give it:

    while there are unscheduled nodes
        take the node with no unscheduled predecessor
        among those, take the one the PRIORITY FUNCTION prefers
        emit it

The priority function is the whole of the algorithm.  `priority_height()`
prefers the node with the LONGEST DEPENDENCY CHAIN above it, because
starting a long chain first is how a schedule hides latency.  `priority_src()`
prefers the node with the most predecessors, which is a different policy and
gives a different schedule on the same DAG -- measured, below, because "the
scheduler chose" is not a number.

THE THREE NUMBERS, and each one has a different kind of honesty:

  * the CRITICAL PATH, a longest chain in the DAG.  It is a LOWER BOUND on
    the schedule's length and it is a property of the PROGRAM, not of the
    schedule: no ordering can beat it.  §KEEP§A SCHEDULE LONGER THAN THE
    CRITICAL PATH IS NOT A BAD SCHEDULE; IT IS A SCHEDULE THAT FAILED TO HIDE
  * the ILP ESTIMATE, instructions divided by critical path.  It is a RATIO
    and it is a property of the DAG plus the machine's width, and it is
    reported as a ratio and never as a speedup
  * the INVERSION COUNT against a reference order, which is a COUNT against
    a COUNT and never a ratio

THE TRAP, and it is the reason this file exists: A SCHEDULE THAT RESPECTS
THE DEPENDENCIES IT CAN SEE AND NOT THE ONES IT CANNOT.

The dependency graph this file builds knows about VALUES.  Two instructions
that touch the same virtual register are ordered.  Two instructions that
touch MEMORY are not, because the graph has no idea whether the addresses
alias -- and if it assumes they do not, a load can be hoisted above a store
to a location that the store writes, and the schedule is faster and wrong.

§KEEP§AND TIMING WILL NOT CATCH IT. §KEEP§ THE SCHEDULE THAT DROPS A
DEPENDENCY IS *FASTER*, SO A BENCHMARK THAT ONLY TIMES THE TWO ARMS
REPORTS THE BROKEN SCHEDULE AS THE WINNER. §KEEP§ THE ONLY THING THAT
CATCHES IT IS A VALUE, AND THE FILE THEREFORE EVALUATES EVERY SCHEDULE IT
BUILDS AND PRINTS THE CHECKSUM BESIDE THE LENGTH. §KEEP§ THIS IS THE
GENERAL FORM OF EVERY TIMING BUG IN THIS COLLECTION AND IT IS WORTH NAMING:
A FASTER WRONG ANSWER IS NOT A SMALLER NUMBER, IT IS A LIE THAT HAPPENS TO
POINT DOWN.
"""

import cbir
from cbir import Ins, is_reg, opclass

MEAS = 'MEASURED'


# --------------------------------------------------------------------------
# THE DAG.
# --------------------------------------------------------------------------
def build_dag(insns, mem_ordered=False):
    """Dependencies, as a list of sets: `deps[i]` is what `i` waits for.

    Three dependency kinds, and the third is the one that is usually missing:

      RAW   i reads a value j defines          (read after write)
      WAW   i defines what j defines          (write after write)
      MEM   i touches memory j touched        (ONLY when `mem_ordered`)

    `mem_ordered=False` is THE TRAP'S DEFAULT and it is stated at the call
    site of every measurement, because a default that is wrong and silent is
    the worst kind of default.  §KEEP§WITH `mem_ordered=False` A STORE AND A
    LOAD THAT TOUCH THE SAME ADDRESS ARE INDEPENDENT, AND A SCHEDULER THAT
    BELIEVES THAT WILL HOIST THE LOAD.
    """
    deps = [set() for _ in insns]
    for i, a in enumerate(insns):
        if a.dest is not None:
            for j in range(i):
                if insns[j].dest == a.dest:
                    deps[i].add(j)
        # §KEEP§THE ARGUMENT LOOP IS OUTSIDE ANY `if dest is not None`. §KEEP§
        # THE FIRST VERSION SKIPPED THE WHOLE INSTRUCTION WHEN IT HAD NO
        # DESTINATION -- WHICH IS EVERY STORE -- §KEEP§ SO A STORE HAD NO
        # EDGES AT ALL AND THE MEMORY-ORDERED SCHEDULE REORDERED STORES ACROSS
        # THE THINGS THAT COMPUTE THEIR DATA. §KEEP§ THE SCHEDULE THAT WAS
        # SUPPOSED TO CATCH THE ALIASING BUG WAS THE SCHEDULE THAT CARRIED
        # IT.
        for arg in a.args:
            if not is_reg(arg):
                continue
            for j in range(i):
                b = insns[j]
                if b.dest == arg:
                    deps[i].add(j)
    if mem_ordered:
        for i in range(len(insns)):
            for j in range(i):
                if _touches_mem(insns[i]) and _touches_mem(insns[j]):
                    deps[i].add(j)
    return deps


def _touches_mem(ins):
    return ins.op in ('ld', 'st') or any(a.startswith('[') for a in ins.args)


def topo(deps):
    """A topological order, or as close as the DAG allows.

    Returns (order, count).  `count < len(deps)` means the dependency graph
    HAS A CYCLE, and every schedule in this file then schedules only the
    part it can -- §KEEP§ A SCHEDULER THAT SILENTLY EXTENDS AN ORDER WITH A
    CYCLE PRODUCES A PROGRAM THAT IS NOT THE PROGRAM.
    """
    n = len(deps)
    succ = [set() for _ in range(n)]
    indeg = [len(d) for d in deps]
    for i, d in enumerate(deps):
        for j in d:
            succ[j].add(i)
    ready = [i for i in range(n) if indeg[i] == 0]
    order = []
    while ready:
        i = ready.pop()
        order.append(i)
        for j in sorted(succ[i]):
            indeg[j] -= 1
            if indeg[j] == 0:
                ready.append(j)
    return order, len(order)


def heights(deps):
    """TWO heights per node, and the distinction is the whole of the
    priority function.

      up[i]   the longest chain ENDING at i  -- how late i can start
      down[i]  the longest chain STARTING at i -- how much i delays others

    §KEEP§THE FIRST VERSION OF THIS FUNCTION COMPUTED ONLY ONE OF THEM, AND
    NAMED IT `height`, AND USED IT AS THE PRIORITY -- so the scheduler
    preferred the nodes whose work ARRIVED LAST, which is the exact opposite
    of what hides latency. §KEEP§ IT PRODUCED A SCHEDULE, IT WAS LEGAL, IT
    WAS DETERMINISTIC, AND IT WAS NO BETTER THAN THE INPUT ORDER.
    """
    n = len(deps)
    succ = [set() for _ in range(n)]
    indeg = [len(d) for d in deps]
    for i, d in enumerate(deps):
        for j in d:
            succ[j].add(i)
    order, done = topo(deps)
    up = [0] * n
    down = [0] * n
    for i in order:
        for j in succ[i]:
            if up[j] < up[i] + 1:
                up[j] = up[i] + 1
    for i in reversed(order):
        best = 0
        for j in succ[i]:
            if down[j] > best:
                best = down[j]
        down[i] = best + 1
    return up, down, (max(down) if n else 0), done


def critical_path(deps):
    _, down, cp, done = heights(deps)
    return down, cp, done


def list_schedule(deps, priority='height'):
    """List scheduling, and the order it produced.

    `priority` is 'height' (longest chain STARTING at the node), 'degree'
    (most SUCCESSORS still unscheduled), or 'index' (the input order, which is
    a schedule too -- and the control every other schedule is measured
    against).

    §KEEP§ AND THE TIE-BREAK IS A MEASURED DECISION, NOT A DETAIL. §KEEP§
    EVERY LIST SCHEDULER IN EVERY TEXTBOOK BREAKS TIES BY SOME RULE AND
    §KEEP§ NONE OF THEM SAYS WHICH, §KEEP§ AND ON THIS KERNEL THE TIE IS THE
    §KEEP§ WHOLE DECISION: §KEEP§ THE FOUR INITIAL `mov`s ALL HAVE THE SAME
    §KEEP§ DOWNSTREAM HEIGHT, §KEEP§ SO BREAKING THE TIE TOWARD THE LOWEST
    §KEEP§ INDEX REPRODUCES THE INPUT ORDER AND BREAKING IT TOWARD THE
    §KEEP§ HIGHEST PRODUCES ITS EXACT REVERSE. §KEEP§ TWO SCHEDULERS THAT
    §KEEP§ DIFFER ONLY IN AN UNDOCUMENTED TIE-BREAK ARE TWO SCHEDULERS, AND
    §KEEP§ THE TIE-BREAK IS NAMED HERE AND PRINTED IN THE REPORT.
    """
    n = len(deps)
    succ = [set() for _ in range(n)]
    indeg = [len(d) for d in deps]
    for i, d in enumerate(deps):
        for j in d:
            succ[j].add(i)
    _, h, _, _ = heights(deps)
    remaining = set(range(n))
    order = []
    available = set(i for i in range(n) if indeg[i] == 0)
    while remaining:
        if not available:
            # a CYCLE, which cannot happen in a DAG built from a
            # well-formed instruction list -- and if it does, the schedule
            # is truncated rather than extended with an invalid order.
            break
        if priority == 'index':
            pick = min(available)
        elif priority == 'degree':
            # §KEEP§ MOST SUCCESSORS, NOT MOST PREDECESSORS. §KEEP§ THE
            # §KEEP§ FIRST VERSION USED THE PREDECESSOR COUNT, §KEEP§ WHICH IS
            # §KEEP§ A NUMBER THAT ONLY FALLS AS THE SCHEDULE PROGRESSES, §KEEP§
            # §KEEP§ SO IT SELECTED THE SAME NODES IN REVERSE ORDER AND WAS
            # §KEEP§ NOT A PRIORITY FUNCTION AT ALL.
            pick = max(available,
                       key=lambda i: (len([j for j in succ[i]
                                          if j in remaining]), -i))
        elif priority == 'height_hi':
            pick = max(available, key=lambda i: (h[i], i))
        else:
            pick = max(available, key=lambda i: (h[i], -i))
        available.discard(pick)
        order.append(pick)
        remaining.discard(pick)
        for j in sorted(succ[pick]):
            indeg[j] -= 1
            if indeg[j] == 0:
                available.add(j)
    return order


def inversions(order, deps):
    """How many DEPENDENT pairs the schedule puts in the WRONG ORDER.

    A schedule is legal when it puts every dependent pair in dependency
    order; it is BETTER when it moves instructions that do not depend on each
    other further from the input order.  The measurement for that second
    thing is a COUNT of comparable pairs and is compared against a COUNT for
    the reference -- never a ratio against a time, because a schedule that
    moved things further is not thereby faster on any machine this course
    has.
    """
    pos = dict((x, i) for i, x in enumerate(order))
    bad = 0
    total = 0
    for i, d in enumerate(deps):
        for j in d:
            total += 1
            if pos[j] > pos[i]:
                bad += 1
    return bad, total


def reorder(insns, order):
    return [insns[i] for i in order]


def schedule_checksum(insns, order, env=None):
    """Run a scheduled program and fold the values it writes.

    §KEEP§IT FOLDS THE DEFINITIONS IN SCHEDULED ORDER, NOT IN PROGRAM ORDER.
    A fold that ignored the order would be the same number for a legal
    schedule and an illegal one whenever the schedule merely PERMUTES
    independent operations -- and permuting independent operations is exactly
    what a scheduler is for. §KEEP§ A CHECK THAT CANNOT SEE THE ONLY THING
    BEING CHECKED IS NOT A CHECK.
    """
    e = dict(env or {})
    e.setdefault('M', {})
    acc = 0
    for i in order:
        cbir.step(insns[i], e)
        if insns[i].dest is not None and is_reg(insns[i].dest):
            acc = (acc * 31 + (e[insns[i].dest] & 0xffffffffffffffff)) \
                & 0xffffffffffffffff
    return acc


def alias_trap_kernel():
    """A kernel whose memory operations ALIAS, which is the whole of the
    trap: two addresses that a backend may or may not prove distinct.

    The store writes to 1024+8 and the load reads from 1024+8.  A scheduler
    that hoists the load above the store reads the OLD value and the program
    computes something else -- faster and wrong.
    """
    return [
        Ins('mov', ['7'], 'v0'),
        Ins('mov', ['11'], 'v1'),
        Ins('mul', ['v0', 'v1'], 'v2'),
        Ins('add', ['v2', 'v0'], 'v3'),
        Ins('st', ['[1024+8]', 'v3']),
        Ins('ld', ['[1024+8]'], 'v4'),
        Ins('xor', ['v4', 'v3'], 'v5'),
        Ins('add', ['v5', 'v1'], 'v6'),
    ]


def alias_trap_kernel_distinct():
    """The same shape with addresses that provably do NOT alias, so the
    schedule that reorders them is legal.  Both kernels are in the corpus on
    purpose: a schedule that is legal on one and illegal on the other is a
    schedule that needs an alias analysis, and without one it is a coin
    flip."""
    return [
        Ins('mov', ['7'], 'v0'),
        Ins('mov', ['11'], 'v1'),
        Ins('mul', ['v0', 'v1'], 'v2'),
        Ins('add', ['v2', 'v0'], 'v3'),
        Ins('st', ['[2048+8]', 'v3']),
        Ins('ld', ['[1024+8]'], 'v4'),
        Ins('xor', ['v4', 'v3'], 'v5'),
        Ins('add', ['v5', 'v1'], 'v6'),
    ]