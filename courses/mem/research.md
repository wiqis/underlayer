# The Memory Hierarchy — research log

Every number here was measured before it was written, on this machine, with
these tools. Claims that did not survive measurement were **retracted rather
than softened**, and all nine retractions are printed by the artifact itself so
that they cannot be quietly dropped — and asserted by `crosscheck.py` so that
they cannot be *deleted* either.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U (Zen 3), 6 cores / 12 threads |
| Environment | **a virtualised guest** (`AMD-V`) |
| L1d / L1i | 32 KiB each, **8-way**, 64 sets, 64-byte lines |
| L2 | 512 KiB, 8-way, 1024 sets, 64-byte lines |
| L3 | 16 MiB, 16-way, 16 384 sets, 64-byte lines |
| TSC | 2.2960 GHz across a sleep, 2.2957 GHz across a busy loop — **invariant** |
| Core clock | sampled **1427–2745 MHz inside one run** — a 92% swing |
| PMU | **absent.** A forked child executing `RDPMC` dies of SIGSEGV; `perf_event_paranoid = 4` |
| Transparent huge pages | `enabled = madvise`, `defrag = madvise` — **and the collapse is asynchronous, which turned out to matter** |
| Toolchain | gcc 15.2.0, Python 3.14.4 |

Three of those rows decide what this course may claim at all:

1. **There is no hardware performance counter.** No miss, no fill, no page walk
   and no stall can be *counted* here. Every number below is bounded by timing
   from two sides, and the artifact proves the absence by forking a child that
   executes `RDPMC` and reporting the signal it died from.
2. **The clock moves inside a single run.** An L1 hit costs a fixed number of
   core cycles, so its cost *in nanoseconds* moves with the clock — which is why
   the absolute columns are bands and every load-bearing number is a **ratio**.
3. **`MADV_HUGEPAGE` is a hint, not a command.** The run this course was first
   validated on had all **786 432 KiB** of the madvised mapping collapsed,
   i.e. 384 × 2 MiB pages. A run on the same machine twenty minutes later had
   **0 KiB**, because khugepaged is asynchronous and opportunistic. So the
   instrument now *proves* the collapse before making a huge-page claim, and
   withdraws the claim when it cannot. This is recorded in F5 and R10 below.

## Scope: what the prior courses left open

A word-boundary grep over the ~52 concept files written before this one:

| Term | Files |
|---|---|
| `prefetch` | **0** |
| `cache miss` | **0** |
| `set associat` | **0** |
| `write-allocate` | **0** |
| `non-temporal` | **0** |
| `false sharing` | **0** |
| `bandwidth` | **0** |
| `NUMA` | **0** |
| `huge page`, `hugepage`, `MADV_HUGEPAGE` | **0** |
| `TLB` / `page table` | 1 — a **forward reference**, in `obj_no_segments.ch`, to this course |
| `memory hierarchy` | 3 — all **forward references** to this course, in the obj and exe courses |
| `cache line` | 4 — 3 in the exe course (as the *instruction fetch* block) and 1 in `obj_sections.ch` |
| `associativ` | 3 — all `COMDAT` **associative sections**, a different sense of the word |

So five earlier courses *point at* this one and none of them answers it. The
`obj_sections.ch` reference is the sharpest: it says a page is 4096 bytes and an
L1 cache line is 64, and asks whether a header field that says "alignment 4"
means one or the other. This course is where that number stops being a stated
constant and becomes something with a measured cost attached.

## The findings

### F1 — A chase and a sweep are different questions, and the gap is the prefetcher

Over the **same 64 MiB**, entirely outside every level of the cache, in the same
binary, on the same machine:

| access pattern | ns per line | GB/s |
|---|---|---|
| pointer chase, random order | **132.4** | 0.48 |
| sequential sweep, `+64` each time | **3.49** | 18.3 |

**38× for byte-identical traffic.** The only difference is whether the address
of the next access can be computed before the current one has returned. The
chase measures **latency**; the sweep measures **bandwidth**; and the 38×
between them *is* the prefetcher, which cannot be observed directly without a
PMU and can only be subtracted.

This is the most useful number in the course, and the first draft of it was
wrong in a way that looked perfectly plausible — see R3.

### F2 — The hierarchy is a band, not four numbers

A random-permutation chase over N lines of 64 bytes, one line per access, with
the reference taken as the fastest L1-resident row rather than the first row:

| footprint | lines | ns/access | vs L1 |
|---|---|---|---|
| 512 B | 8 | 1.77 | 1.12× |
| 32 KiB | 512 | **1.59** | **1.00×** ← L1d is 32 KiB |
| 64 KiB | 1024 | 4.77 | 3.01× ← the L2 step |
| 512 KiB | 8192 | 11.64 | 7.34× ← the L2 *is* 512 KiB |
| 16 MiB | 262144 | 78.1 | 49.2× ← the L3 step |
| 256 MiB | 4194304 | 149.9 | 94.5× |

The step lands within a **factor of two** of the size `/sys` reports, and that
is the only agreement a cache size can have, because the last line of a level
is always a miss.

**The plateau is a band, and it widens**: 1.8 ns at 128 bytes, 5.0 ns across
the L2, 24.6 ns across the L3, 149.9 ns at 256 MiB. A single number called "the
L3 latency" would be wrong by a factor of **5.5** depending on where in the L3
you happened to ask. Why it widens is **not explained** — that is a limit.

### F3 — Associativity, predicted from `/sys` and then measured

`/sys` gives **capacity**, so the prediction is arithmetic: 8 ways × 64 bytes =
512 bytes per set, lines a multiple of 4096 bytes apart share a set, and 9 of
them cannot coexist in 8 ways. The prediction was written down **before** the
measurement:

| lines | aliased (stride 4096) | spread (stride 4160) | ratio |
|---|---|---|---|
| 8 | 1.77 | 1.47 | **1.21×** |
| 9 | **7.72** | 1.56 | **4.94×** |
| 32 | 6.32 | 1.56 | 4.06× |

**The onset is between 8 and 9 and nowhere else**, and the control layout —
which spans the same 128 KiB with the same number of lines, differing only in
*which set* each line lands in — never slows down at all. A working set of
**576 bytes** costs L2 latency in the aliased layout.

What `/sys` does *not* give is the **replacement policy**, so the shape *inside*
the thrashing regime is not explained: the worst row is 9 lines and not 32.

### F4 — Translation, and a cliff at exactly 64 pages

Two layouts with the same line count, the same footprint, the same access order
and the same L1 set for every line. The only difference is how many pages they
are spread over:

| pages | packed | spread | ratio |
|---|---|---|---|
| 64 | 1.67 | 1.38 | 0.83× |
| **72** | 1.24 | 4.08 | **3.29×** |
| 512 | 1.30 | 3.91 | 3.00× |

Fast up to **64** pages, slow from **72**. A 512-line layout costs up to 2.90×
its packed control; both are 32 KiB of data, so this is a translation cost and
not a capacity one. This is also how the fictitious "cliff at 32 pages" was
disproved — see R2.

### F5 — The 512× a huge page buys, and the run where it bought nothing

The same layout, on a mapping that was `madvise`d with `MADV_HUGEPAGE`:

| run | AnonHugePages (smaps) | 4 KiB arm | huge-page arm | outcome |
|---|---|---|---|---|
| validation, 2026-09-27 20:54 | **786 432 KiB** = 384 × 2 MiB | 2.94× packed | **1.13× packed** | 2.6× smaller penalty |
| validation, 2026-09-28 19:16 | **0 KiB** | 2.54× packed | 2.62× packed | **claim withdrawn** |

**The mapping does not always collapse.** khugepaged is asynchronous, a host may
disable THP entirely, and a mapping that did not collapse is
*indistinguishable* from one that did to every other number in the table — the
line counts, footprints and L1 sets are identical by construction. So the
artifact reads `/proc/self/smaps` at the moment of the claim, reports which of
the two happened, and **withdraws the claim** rather than averaging over it.
That is the third limit in the artifact's header, and the harness asserts the
withdrawal as a check.

### F6 — Write-allocate: 2.4× above the cache, and NT stores never allocate

| footprint | read | st64 | st4 | NT full | NT part | st64/rd |
|---|---|---|---|---|---|---|
| 256 KiB | 0.90 | 0.99 | 0.99 | 17.19 | 4.29 | 1.10× |
| 16 MiB (= L3) | 2.53 | 2.97 | 2.85 | 15.75 | 2.81 | 1.17× |
| 32 MiB | 2.89 | 6.27 | 6.85 | 14.50 | 3.74 | **2.17×** |
| 64 MiB | 3.48 | 8.47 | 8.91 | 15.81 | 3.91 | **2.44×** |

Three results in one table:

1. **A store to a line the CPU does not hold costs ~2.4× a read to it, and only
   above the last-level cache.** Write-allocate predicts exactly this: the line
   must be fetched before it can be written, so a store-only sweep moves twice
   the DRAM traffic.
2. **`st4` and `st64` are the same cost at every size.** The transaction is the
   **line**: you are charged for fetching all 64 bytes and writing all 64 back,
   whatever you used. This is the sharpest claim in the section and it is
   machine-independent.
3. **Non-temporal stores are expensive at *every* footprint and flat** — 17.2 ns
   per line at 16 KiB, 16.6 at 64 MiB. The folklore is that an NT store is
   expensive when it cannot help and cheap when streaming to DRAM. Measured, the
   smaller footprint is *not* cheaper, and **the flatness is the proof of
   non-allocation**: nothing on that path consults the cache, so no footprint can
   help it.

### F7 — False sharing, with no data shared at all

Two threads, each incrementing **its own** counter 5 000 000 times. Nothing is
shared. The only difference is whether the two counters are 8 bytes apart or 64:

| | near (8 B apart) | far (64 B apart) | ratio |
|---|---|---|---|
| minimum over 7 verified runs | 23.9 ns | 0.386 ns | **61.9×** |
| worst of the verified runs | — | — | 40.5× |

Every run is checked against `core_id` in `/sys`, and a row that put both
threads on one core would be *excluded* — two SMT siblings sharing a core is a
different measurement. **7 of 7 runs were on two cores**, so no row was
excluded, and the claim does not rest on a lucky minimum.

### F8 — The noise floor of the *estimator*, and a refuted hypothesis

The quantity the tolerances are applied to is not one run's spread but the
spread of the **min-of-3 estimator, repeated 14 times**:

| quantity | spread |
|---|---|
| 14 min-of-3 values, same 64-line chase | **14.3%** ← the noise floor |
| the 42 individual runs behind them | 34.0% (2.4× worse) |

Quoting the second number is the mistake the previous course made, and the fix
is the same: measure the estimator, not the runs.

And a hypothesis that **failed**: ratios are supposed to cancel common-mode
error, so a ratio should be steadier than its operands. It is not, always —

| estimator | spread (validation run 1) |
|---|---|
| arm A alone (L1) | 7.0% |
| arm B alone (L2) | 7.2% |
| `min(B)/min(A)` | 11.9% |
| min of **paired** ratios | 17.3% |

Here the *paired* estimator — divide inside the iteration, then take a minimum —
was **worse** than the ratio of minima. Across the runs this section has been
through it was steadier about twenty times out of twenty-four and worse the
other four. So the ordering is a property of how hard the clock was moving, not
of the estimator, and the artifact **quotes the widest of the three** as its
tolerance rather than naming one, while the harness asserts the *reason* and not
the ordering. That is the single most important methodological result after F1.

## Retractions, recorded

All nine are printed by the artifact in section 8 and asserted as text by
`crosscheck.py`, group H.

**R1 — "The L1d aliasing stride means 256 lines at 4096 bytes show a 5.28× TLB
cost."** The 5.28× was real; the **interpretation** was wrong. The layout put
those lines at offsets `64*(i mod 8)`, so 256 lines shared **8 sets of an 8-way
cache**. It was the section-4 conflict miss, measured one page at a time. A real
effect given a false cause is the most dangerous kind of wrong number, because
the reproduction works.

**R2 — "There is a TLB cliff at 32 pages."** Also wrong, same cause: one line per
4096-byte page *is* the aliasing stride, so every page's line landed in L1 set 0.
When the offset spread over all 64 sets the cliff vanished and a **bisection**
placed the real one at **64 pages** (F4).

**R3 — "Sequential reads sustain 64 GB/s."** Two bugs, both in the *units* and
neither in the memory. The loop did one line per iteration, so the measured
"3.30 ns per line" was identical at every footprint from 256 KiB to 64 MiB — and
*a rate that is the same for L2-resident and for DRAM data is the rate of a loop,
not of a memory*. With four lines per iteration the same sweep reports 0.700 ns
per line over a 4 MiB L2-resident region and 3.800 ns over 64 MiB of DRAM:
**91.4 GB/s and 16.8 GB/s**. And the sweep **saturates**, which is the honest
limit of the measurement: at 3 ns for four 16-byte loads the loop is a real part
of the cost, so this instrument **cannot report the bandwidth of an L2-resident
region**. The DRAM figure it does report is 16.8 GB/s.

**R4 — "A non-temporal store is 16.4 ns per 16 bytes."** Real, and a bug: the
navigation load and the NT store **shared a cache line**, so the load allocated
the very line the NT store was supposed to bypass. Moving the target 2 MiB away
kept the number high *for a different reason* — the flat line in F6.

**R5 — "False sharing has no effect here."** The two threads were reading **one**
counter. Then two barriers of count two with one waiter each **deadlocked** the
benchmark. Fixed twice; the result is the 61.9× in F7.

**R6 — Three benchmark segfaults**, all from writing past a mapping: an element
at `i*4096 + 64*(i mod 512)` runs off the end of the last page, and a size loop
that computed `reps = MAXL/lines` with `lines > MAXL` produced `reps = 0` and an
infinite loop that walked forward until it faulted.

**R7 — `rdpmc` does not exist as a thing you can just call.** The first version
of section 0 executed it in the parent and killed the benchmark, taking every
measurement with it. It now runs in a forked child and reports the signal.

**R8 — "The 256 MiB row measures 8 ns."** Physically absurd, and the reason was
an **offset**: the layout added `64*(i mod 64)` bytes to line *i*, which is
`128i` for `i < 64`, so line 32 landed on line 64's address and line 64 on line
128's. A "256 MiB" layout really touched a few megabytes. **The permutation
still visited every *index*, so every self-check passed and the table was
nonsense** — the only thing that caught it was that a 256 MiB footprint cannot
be an 8 ns access. The check that now catches it walks the cycle and **counts
distinct addresses** instead of trusting the index count. The same bug then
reappeared as `4096*(i mod 64)` — a stray `* 64` in the same expression — and
produced a TLB table whose cost was HIGH for 32 pages and LOW for 72: **the
exact inverse of the truth. A non-monotonic table is not noise; it is a signal
that the layout is not what the caption says it is.**

**R9 — A register named in an asm template is not a scratch register.**
`movl (%[p]), %%eax` was, and `%eax` is whatever the register allocator already
gave to an operand — here `%rax`, the loop counter:

```
mov    -0x18(%rbp),%rax      <- the counter, 4194304
mov    (%rdx),%eax           <- CLOBBERS the counter every iteration
add    $0x4,%rdx
dec    %rax
```

so the walk ran until some 4-byte word happened to be zero. Two earlier
"fixes" made it worse: an earlyclobber marker on `p` *moved* the collision rather
than removing it, and a literal-immediate stride removed one hazard and left
this one. **The rule, learned in three attempts: every register an asm template
NAMES must be a declared operand or a declared clobber, and there is no third
case.**

## Retractions of the *harness*, recorded

The nine above are about the machine. These are about the checks, and they are
the same disease the previous course spent a concept on: a check that fails for
the wrong reason teaches its reader to ignore it.

**H1 — a value claim about a noisy measurement.** The huge-page check compared
`max(hp/pk)` over five deep rows against `1.0 + 2 × noise`. It failed at
**1.38× against a bound of 1.34×** on a machine where the effect was plainly
there, because a maximum of five ratios each carrying the same 17% spread is
biased high by construction, and the winning row happened to divide two arms
measured at different moments. **Fixed by making the claim comparative and
about the deepest footprint**, which is the form the harness already asserted.

**H2 — "the useful rate falls monotonically with the stride."** The artifact
printed that sentence and it is **false**: two runs out of four measured stride
8 *faster* than stride 4 (8.05 GB/s against 4.71), because at the dense end both
strides use every byte of every line they fetch, so those two rows differ only
in the loop's own per-element overhead. The artifact now claims what holds —
the rate **collapses across the range** (23× dense to sparse), and the **line**
rate is the monotonic one **within** the dense range — and the harness checks
that instead.

**H3 — a band that included the loop.** The write-allocate check compared the
largest store/read ratio *below* the L3 against the largest *above* it, and took
the below-band maximum from the **16 KiB row**, where a read sweep completes a
line in 0.196 ns. That is the loop, not the memory, and including it made the
band 1.80× and made a real 2.44× step fail a check about a step. The band's
floor is now a **stated exclusion** at 256 KiB — "cache-resident but not
loop-limited" — and the step passes with room.

After these three fixes: **three consecutive runs, 21/21 checks in the artifact
and 109/109 in the harness, plus both branches of the huge-page claim exercised
(109/109 on the captured runs where the mapping did collapse).**

## What is deliberately not claimed

- **Any absolute cycle count.** The clock moves 92% inside one run; the course
  reports ratios and minima, and the harness asserts shapes.
- **How many lines were missed, filled, or walked.** There is no PMU, so there
  are no counts — only two-sided bounds by timing.
- **The replacement policy.** `/sys` gives capacity and not policy, and the
  shape *inside* the thrashing regime (worst row at 9 lines, not 32) is not
  explained.
- **Why the L3 band widens** from 21.2 to 24.6 ns as the footprint grows inside
  it, and why the row at exactly the L3 size is the least stable number in the
  section.
- **The bandwidth of an L2-resident region.** R3: the sweep saturates. The DRAM
  figure (16.8 GB/s) is the one the instrument can report.
- **A huge-page effect when the mapping did not collapse.** The claim is
  withdrawn and the withdrawal is asserted.
- **Cache coherence, NUMA, and multiprocessor memory.** Named in the roadmap as
  the *Multiprocessor Architecture* course's subject and not measured here.
  False sharing is the one coherence-adjacent effect this course measures, and
  it is measured as a *contention* cost on one socket.
- **Anything about another microarchitecture.** One machine, one ISA. The
  *method* — measure the instrument, then measure the machine — is what
  transfers.

## Reproducing

```bash
cd courses/mem/assets/samples
./build_samples.sh            # build, run, and cross-check (about 40 s)
./build_samples.sh --quick    # fewer repetitions, noisier
python3 crosscheck.py         # the harness alone, against membench.out
./membench                    # the artifact alone, 9 sections
```

`run1.txt`, `run2.txt` and `run3.txt` are three consecutive runs of the artifact
as shipped, all **21/21 and 109/109**.

Tracked: `build_samples.sh`, `membench.c`, `crosscheck.py`, `run1-3.txt`,
`.gitignore`. Everything else in that directory is a build product.
