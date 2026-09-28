# Multiprocessor Architecture — research log

Every number in the course was measured before it was written, on this machine,
with these tools. Claims that did not survive measurement were **retracted
rather than softened**, and all six retractions are printed by the artifact in
section 7 and asserted as text by `crosscheck.py` group G so that they can be
neither quietly dropped nor deleted.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19 model 0x50, microcode 0xa500012 |
| Topology | **1 socket, 6 cores, 2 threads/core = 12 logical CPUs** |
| L1d / L1i | 32 KiB each, **shared by exactly the sibling pair** |
| L2 | 512 KiB, **shared by exactly the sibling pair** |
| L3 | 16 MiB, **1 instance, shared by all 12** |
| NUMA | **1 node**, `node0 cpulist = 0-11` |
| TSC | 2.2957 GHz busy, 2.2957 GHz across an 80 ms sleep — **invariant to 0.000 %** |
| PMU | **absent.** `perf_event_paranoid = 4` |
| Kernel | 7.0.0-34-generic, gcc 15.2.0, Python 3.14.4 |
| Noise floor | measured per run and printed; the artifact flags it as an **upper bound** because the body is frequency-sensitive |

Three rows decide what this course may claim at all:

1. **No hardware performance counters.** No miss, no snoop, no line transfer
   and no directory notification can be *counted* here. Every number in the
   course is a **duration**, and a duration bounds a count without measuring
   it. This is a weaker position than the memory course, which could at least
   bound a miss count from two sides.
2. **One NUMA node.** The distance half of the course cannot be measured, and
   section 5 says so rather than skipping it.
3. **The core clock moves and is not readable.** A TSC tick is *time*, so every
   figure is a ratio.

## Scope: what the prior courses left open

A word-boundary grep over every concept file the four preceding CPU-architecture
courses left behind:

| Term | Files | Sense |
|---|---|---|
| `MESI` | **0** | — |
| `snoop` | **0** | — |
| `cache coherency` | **0** | — |
| `memory barrier` | **0** | — |
| `total store order` | **0** | — |
| `lock xadd` / `cmpxchg` | **0** | — |
| `spinlock` / `rseq` / `sched_setaffinity` | **0** | — |
| `hyperthreading` | **0** | — |
| `coherence` / `coherent` | 13 | **every one unrelated**: "a coherent one", "the story would be coherent", "a coherent design", and one **forward reference** in `mem_writes.ch` to this course |
| `NUMA` | 3 | a **deferral** in the memory course, and this course's two siblings naming the deferral |
| `SMT` | 2 | both in the memory course, both as an **exclusion criterion** |
| `core_id` | 3 | the memory course using it as a **validity check** |
| `false sharing` | 4 | the memory course's **61.9×**, and nothing else |
| `fence` | 5 | `exe_instrument.ch` and `mem_instrument.ch` as a **timing technique**, never as ordering |

The unpaid hand-off is the sharpest thing in the list. The memory course
measured false sharing at 61.9× and then **excluded every row where both
threads landed on the same physical core**, giving as its reason:

> "two SMT siblings share L1 and L2 and are a different measurement, not a
> noisy version of the same one"

It used the term four times across two concept files and never once defined
it, never said what an SMT sibling is, and never said what sharing an L1
would cost. It also named this course in its own limits block — *"cache
coherence, NUMA, and multiprocessor memory"* — and never returned. **This
course discharges both debts, and the topology table in section 1 is the
definition the memory course was missing.**

## The findings

### F1 — The topology, read twice from two kernel files

12 online CPUs, 6 `core_id` values, 2 logical CPUs per core, and **6 × 2 = 12
exactly**. Six sibling pairs, every relation mutual, no CPU its own sibling.

The load-bearing part is not the numbers but the **cross-check**: for every
cache level that names a sharing set, the artifact parses that set and counts
how many of the named CPUs the *topology* subsystem places in one `core_id`
group.

```
L1 data names [0-1] = 2 CPU(s); the topology puts 2 of them in one core_id group.  AGREE
L1 instr names [0-1] = 2 CPU(s); the topology puts 2 of them in one core_id group.  AGREE
L2 names [0-1] = 2 CPU(s); the topology puts 2 of them in one core_id group.  AGREE
cross-check: thread_siblings_list AGREE (3 of 3 levels agreed)
```

Two kernel files, two subsystems, one fact. `shared_cpu_list` is written by
the cache layer and `thread_siblings_list` by the topology layer, so a check
that read the same file twice would agree with a wrong answer.

### F2 — The result: true and false sharing cost the same

Seven rows, one program, five repetitions each, 2 000 000 iterations, arms
interleaved, both threads pinned and **verified with `sched_getcpu()`**.

| row | what | ticks/op | vs A |
|---|---|---|---|
| A | one **private** line each, 2 cores | 4.46 | 1.00× |
| B | **ONE shared line**, 2 cores | 58.21 | **13.05×** |
| C | **8 bytes apart, one line**, 2 cores | 48.68 | **10.92×** |
| D | one private line each, **2 SMT siblings** | 4.78 | 1.07× |
| E | one private line each, **1 core** | 8.21 | 1.84× |
| F | each opaque-loads the peer's line | 2.86 | 0.64× |
| G | plain store, nothing shared | 3.65 | 0.82× |

**B / C = 1.19×.** Across three recorded runs: **0.97, 1.03, 1.19**.

B and C use the *identical instruction* on the *identical machine*, and the
only difference is whether the two workers update the same long or two longs 8
bytes apart. If the cost of true sharing were in the data, C would be near A.
It is not: C is 10.92× A. **The cost is in the cache line.** This is the
course, and it is a single ratio.

### F3 — A `lock` with nothing to lock against is not free

Two threads, two **separate** lines, no other thread running:

| body | ticks/op | vs plain store |
|---|---|---|
| plain store | 1.04 | 1.00× |
| `lock xadd` | 2.64 | **2.54×** |
| `lock cmpxchg` loop | 2.99 | 2.88× |

The same bodies, both threads on **one** line: `lock xadd` 22.03 = **21.20×**
the floor.

**The cost of contention, by subtraction:**

```
lock xadd,  one line    22.03
lock xadd,  own line     2.64
                     ---------
contention             19.39 ticks  =  7.33x the uncontended cost
```

A subtraction is worth more than either number: the **uncontended** part
(2.54× a plain store) is the barrier the prefix implies, paid by a thread with
no reason to pay it, and it is **not** a coherence cost. The **contended** part
is the line changing hands, and it is seven times larger.

### F4 — The row that refused to reproduce its expected shape

Row F writes a worker's own line and then opaque-loads the peer's. Written
naively that is a ping-pong: two lines, two owners, a transfer per iteration.
Measured, F is **0.64×** row A — *cheaper* than no sharing at all.

**A store does not invalidate the other core's copy when it executes.** It
goes into the store buffer and the peer's copy stays valid until the store
*retires*, so two unsynchronised threads do not take turns; each runs ahead and
the transfers that do happen are spread out rather than serialised.

This is worth more than the number, because **the fast path and the slow path
look the same on average.** A program with a race runs at full speed and gives
the wrong answer once in a million times. That is the profile of a heisenbug,
and it is why data races are hard to find rather than easy.

### F5 — NUMA, absent, and its absence a measurement

`/sys/devices/system/node/online` = `"0"`; `node0 cpulist` = `"0-11"`. One
memory domain. Every core is the same distance from every address, so every
ratio above is a **coherence** ratio and none is a NUMA ratio.

The portable content is the distinction, which is why the section exists rather
than being deleted as unmeasurable:

- **cache coherence** — a question between two **caches**. One line, one owner
  at a time. Solved by a protocol. The cost is a line transfer. *This is what
  the course measured.*
- **NUMA** — a question between a **core and a memory controller**. Nothing is
  shared and nothing is owned; the address just decodes differently. The cost
  is latency and bandwidth, not ownership transfer.

They are confused constantly and the confusion has a name: "the memory is
remote". On a one-node machine that sentence is meaningless.

### F6 — Two of the five rows are identical on every desktop CPU

| | x86-64 | AArch64 | RISC-V |
|---|---|---|---|
| unit of sharing | cache line | cache line | location |
| state machine | MESI | MESI | MESI |
| noticing a change | snoop | snoop | snoop |
| atomic update | `LOCK` prefix | `LDAR`/`STLR`, `LDAXR`/`STLXR` | `LR`/`SC` |
| ordering | the prefix | the access mode | `FENCE` with edges |

Rows 1–3 have not changed in thirty years, which is why "cache coherence"
feels like one thing. Rows 4–5 are where the architectures genuinely differ —
and they are exactly the two rows that decide whether a lock-free algorithm
written on x86-64 is correct elsewhere. See R5.

## Retractions, recorded

All six are printed by the artifact in section 7 and asserted as text by
`crosscheck.py`, group G.

**R1 — "The plain-store arm measured 1.75 ticks per operation."** It measured
**nothing**. Written in C as a relaxed atomic store to a variable nothing ever
read, the compiler proved the whole four-million-iteration loop dead and
removed it, and the result was a plausible number for four million operations
that did not happen. An `asm volatile` store has no such door. This is the
third course in a row to hit this bug in this form, and the general rule is
now in the artifact's header: **when two things measure as similar, the first
hypothesis is that your optimiser deleted the difference.**

**R2 — "Two threads on unspecified CPUs is a measurement."** No, and the memory
course already knew it. The difference is that here the check is the
**mechanism** rather than a filter: every worker calls `sched_getcpu()` and the
repetition is discarded if either thread is anywhere but where it was pinned.
See R6 for why that ordering matters.

**R3 — "False sharing is a 61.9× effect."** The number is the memory course's
and it is correct *there*. It is not restated here as a property of this
machine's protocol, because the ratio depends on the body, the width and the
clock, and re-publishing it as a fixed number would be exactly the
remembered-number mistake the harness exists to prevent.

**R4 — "An uncontended lock is expensive because of coherence."** Retracted to
the **wrong reason**. It is expensive — 2.54× — and section 3 separates the two
costs cleanly, but it is not coherence: there is no other thread and nothing to
be coherent with. It is the barrier the prefix implies, paid by a thread that
had no reason to pay it.

**R5 — "`lock` is one idea that could have been three."** The x86-64 design
ties atomicity *and* ordering to one prefix, so every atomic operation is also
a full barrier. AArch64 makes them separate instructions; RISC-V makes them a
fence with chosen edges. **A lock-free algorithm written on x86-64 is therefore
correct partly by accident** — it relies on an ordering guarantee it never
asked for, because the hardware supplied it for free. Port it to a
weakly-ordered machine and it is wrong, and the tests that passed will not find
it.

**R6 — "A placement check is a filter you apply afterwards."** No. Applied
afterwards it cannot tell you *why* a thread was in the wrong place, and on a
loaded machine it silently converts every row into a discarded row while the
run still looks like it worked. Reading `sched_getcpu()` from inside the worker
is the only version that reports the number of discards.

## Retractions of the *harness*, recorded

The same disease the three previous courses documented. **None of these was
found by reading the harness; all were found by running it.**

**H1 — a check that asserted something the data contradicted.** The first
version required SMT row D and the two-core row A to *differ*, because the
artifact's prose said SMT costs a modest penalty. Measured, D/A came out at
1.07, 1.08 and 1.01 on the three recorded runs — the rows are the same. The
check was wrong and the measurement was right. It is now a check on the
**shape** (D close to A, both far below B and C), and the artifact's prose was
rewritten to report the honest and narrower conclusion: *this experiment does
not show what SMT costs.*

**H2 — an ordering the measurement did not support.** The check required the
plain-store row G to be the cheapest row in the table. It is not — G/A came out
at 0.82, so A was cheaper. The check is now on closeness rather than ordering,
because a check that fails whenever the noise is unlucky is worse than no
check. The underlying measurement is not lost: section 3 measures the
locked-versus-unlocked difference properly, with nothing else in the run, and
gets 2.54×.

**H3 — one helper, two incompatible jobs.** The row extractor returned a
single capture group, so a row with a *label* and a *value* handed the label to
`float()` and raised. The same error appeared in the previous course's harness
as a hex extractor returning floats. Two extractors now, with the reason in a
comment.

**H4 — a comparison that uppercased only one side.**
`"IDENTICAL instruction" in FLAT.upper()` can never be true, because the
search string keeps its lower-case *i*. It failed on text that was
demonstrably present, which is the failure mode that trains a reader to
distrust a harness that was right.

**And one committed by the harness about itself:** the first draft of this
harness's *comments* transposed the B/C and D/A sequences. Nothing polices a
harness's prose, only its output — which is why `smp_harness.ch` teaches that
as a point rather than fixing it silently.

## What is deliberately not claimed

- **Any count of coherence traffic.** No PMU: `perf_event_paranoid = 4`. Every
  number is a duration, and a duration bounds a count without measuring it.
- **That the protocol is MESI.** It is what the manuals say and what the state
  names in every profiler imply. No user-space experiment distinguishes MESI
  from MOESI from a directory protocol.
- **Anything about NUMA.** One node, one domain. Section 5 explains why the
  distinction is still measurable even though the second half of it is not.
- **The memory ordering rules.** Section 4 measures a fence's *duration* and
  explicitly not its *correctness*, and says why: a loop that runs the same
  either way is also what a no-op fence would look like. **No timing
  measurement on any machine can establish it.**
- **The other two architectures.** Section 6 is quoted, not run.
- **Anything past two threads.** A pair is the smallest thing with a coherence
  cost at all, and a measurement of N > 2 on this machine would be a
  measurement of the other ten threads.
- **Whether the compiler inserted a fence.** Section 4 counts what the source
  asked for, which is an upper bound.
- **A gap in this harness, named in the artifact and not hidden:** nothing here
  checks the NUMA node. On a two-socket machine the same code and the same
  pinning would measure remote memory and the harness would still go green.

## Reproducing

```bash
cd courses/smp/assets/samples
./build_samples.sh            # build, run, cross-check (about 2 minutes)
./build_samples.sh --quick    # fewer repetitions
python3 crosscheck.py         # the harness alone, against smpbench.out
./smpbench                    # the artifact alone, 8 sections
```

`smpbench.out` is the recorded reference run and `run1.txt` / `run2.txt` are
two more, so the claims are checkable on a machine that never ran the
benchmark. Tracked: `build_samples.sh`, `smpbench.c`, `crosscheck.py`,
`smpbench.out`, `run1-2.txt`, `.gitignore`. Everything else in that directory
is a build product.
