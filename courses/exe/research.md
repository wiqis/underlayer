# How a CPU Executes Instructions — research log

Every number was measured before it was written, on this machine, with these
tools. Claims that did not survive measurement were retracted rather than
softened, and the retractions are recorded below.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U (Zen 3), 6 cores / 12 threads, 423–4390 MHz |
| Environment | **a virtualised guest** (`AMD-V`) |
| L1d / L1i | 32 KiB each, 8-way, 64-byte lines |
| L2 | 512 KiB, 8-way, 64-byte lines |
| L3 | 16 MiB, 16-way, 64-byte lines |
| TSC | `constant_tsc` and `nonstop_tsc` present — invariant, so usable as a time base |
| PMU | **absent.** `perf_event_paranoid = 4`; `/sys/bus/event_source/devices` has no `cpu_core`; `perf stat -e branch-misses` fails |
| Toolchain | gcc 15.2.0, GNU objdump 2.46 |

Two of those rows decide what this course may claim at all, and both were
discovered by measurement rather than assumed:

1. **The TSC is not the core clock.** The TSC measures **2.2959 GHz**,
   invariant. The core measured **2389–2837 MHz idle and 3216 MHz under
   load**. So a TSC tick is a unit of *time*, not a count of core clocks, and
   any "cycles" figure derived from `rdtsc` alone is a stopwatch reading.
2. **There is no hardware performance counter.** Branch mispredictions
   cannot be *counted* here, only inferred from timing — and the two
   explanations for an observation cannot be told apart.

## Scope: what the prior courses left open

`word-boundary` grep over the ~52 concept files written before this one:

| Term | Files |
|---|---|
| `microarchitecture`, `pipel` | **0** |
| `branch predict` | **0** |
| `superscalar`, `in-order` | **0** |
| `reorder buffer`, `store buffer`, `write-back` | **0** |
| `register renaming`, `false depend` | **0** |
| `throughput`, `IPC`, `clock cycle` | **0** |
| `4K alias`, `store-to-load`, `memory disambigu` | **0** |
| `out-of-order` | 3 (DWARF, wasm, symbol hashing — unrelated senses) |
| `cache` | 13 (DWARF package caching, `dlopen` — unrelated senses) |

So the coverage is not thin, it is **zero**. The ISA course ended at "these
bytes spell this instruction"; nothing covered what the hardware does with
them.

## The findings

### F1 — The instrument's apparent noise was the phenomenon under study

The first draft claimed a **73% run-to-run noise floor**. That number was
measured on a bench function that was **not 64-byte aligned**, so it was the
alignment penalty of F5 leaking into the noise estimate. Measured properly,
on an aligned body, the spread is **~15%**.

This is the single most useful thing found, because it is a methodological
result rather than a hardware one: **you cannot measure alignment effects
until you have controlled for alignment, and the first attempt conflated
them.**

### F2 — Alignment is worth up to 2.5×, and byte-identical code proves it

Two functions in one binary, **instruction for instruction identical**,
differing only in address:

```
0000000000002c00 <b_dep1>:     64-byte aligned
0000000000002dc0 <b_ind1>:     32-byte aligned
```

measured **0.79** and **2.13** ticks/iteration — a 2.7× difference for
identical code. The same body emitted at eight offsets (0, 8, … 56 mod 64)
spans **1.00× to 2.51×** of the fastest.

And the slowest offset is **32**, not 56 — the one that actually crosses the
64-byte line. **So the cost is not a simple function of the offset, and this
course does not claim a mechanism.** An operation cache, a loop stream
detector and per-address predictor state are all plausible; none was measured.

The fix was to mark every bench function `aligned(64)`, and *that single
change* is what turned the rest of the numbers from noise into signal.

### F3 — Dependency costs 2.7× independent execution

With every body 64-byte aligned, the numbers became monotonic and the
marginals converged:

| | 1 | 2 | 4 | 6/8 | marginal |
|---|---|---|---|---|---|
| dependent `add r8,r8` | 0.739 | 1.539 | 3.312 | 7.475 | **~0.75–1.03** |
| independent adds | 0.739 | 0.675 | 0.880 | 1.410 | **~0.10–0.48** |

**A dependent chain costs 2.7× an independent operation.** That ratio is the
measurable shape of the execution width, and — because both sides divide by
the same clock — it survives the boost clock and the noise floor.

### F4 — The branch is free at every period this machine can be given

| pattern | ticks/iter |
|---|---|
| never taken (control) | 0.826 |
| period 64 | 0.692 |
| period 16 | 0.802 |
| period 4 | 0.743 |
| period 1 (alternating) | 0.768 |
| **table of 2 pseudorandom bits** | 1.779 |
| **table of 65 536 pseudorandom bits** | 1.677 |

**The direction period makes no difference**, from alternating to a 65536-bit
random pattern. And no mispredict penalty was observed at any depth.

### F5 — And the textbook advice is wrong here, with a caveat

The "branchless" replacement for an unpredictable branch — same data, same
conditional work, `ADC` instead of a branch — measured **2.40× the cost of
the branch it replaces**.

**And that is not a clean comparison**, which the artifact says in its own
output: the branching body performs its conditional add *half* the time
because the branch skips it, while the branchless body performs the
equivalent work *every* time. So 2.40× is an **upper bound** on the cost of
branchless coding here, not a measurement of it.

## Retractions, recorded

**R1 — "The noise floor is 73%."** It is ~15%. The 73% figure was measured on
a misaligned function. Asserted by crosscheck check I1 so it cannot return.

**R2 — "The flags register has no rename, so a chain of flag-writing
instructions serialises."** **Wrong.** Four `TEST`s, which all write the
flags, cost **1.43–1.53× the floor**. Writing the flags repeatedly is nearly
free.

**R3 — "…and reading them is what makes the branchless form slow."** **Also
wrong**, and it was the obvious replacement for R2. Four `ROR`+`ADC` pairs
measured 3.71 against 3.53 for four `ROR`s alone — **1.05×**, i.e. reading
the flags costs nothing extra.

What survives is narrower than either: the four-`ROR` row is expensive
(4.23× the floor) because those four `ROR`s all target **one register** and
so form an ordinary loop-carried chain. **Three candidate explanations were
measured and two were wrong**, and the third — an ordinary dependency — is
the boring one.

## Errors in the tooling, kept because they are the lesson

**E1 — a benchmark the compiler deleted.** The first unpredictable-branch
measurement returned **0.0000 ticks**. The loop was written in C with a
deterministic xorshift; the compiler *proved the sum was constant* and
removed the loop. The fix is to put the data and the branch inside inline
asm, where the compiler cannot see either. The same discipline as the ISA
course's decoder, for the same reason.

**E2 — `test $1, $1` does not exist.** x86 has no
immediate-to-immediate `test`; the assembler rejected it. The constant-flag
instruction that does exist is `and $0, %eax`, which sets ZF
unconditionally. And `floor()` collides with the libc builtin of that name —
a benchmark function shadowing a maths function is a confusing way to lose an
hour.

**E3 — padding a benchmark with something the CPU will not decode.** The
alignment experiment originally padded with 64 bytes of `0x66`, i.e. 64
consecutive operand-size prefixes. **x86-64 permits at most 15 bytes of
prefixes before an instruction**, so byte 16 is a `#GP` and the program
**segfaulted**. `0x90` is one byte and one instruction, so a run of any
length is legal. The multi-byte NOP `0F 1F 00` is what compilers actually
emit, and the ISA course measured its encoding.

**E4 — the noise floor was measured on the phenomenon.** Covered in R1, but
the *bug* is worth naming separately: the instrument's variance was not the
machine's variance, it was a fixed per-address penalty being rediscovered on
every run. Nothing about that is obvious in advance, and it is why F2 has to
come before any of the arithmetic results.

**E5 — a prose line matched a data regex.** The crosscheck's marginal-cost
pattern also matched the sentence *"independent ones retire several per
cycle"*, which then overwrote the parsed marginals with an empty list. The
`\d+\s+adds` anchor is what fixed it. A parser that accepts prose is a parser
that will eventually be right by accident.

**E6 — the crosscheck was flaky, and it was this course's own lesson.** An
early version asserted that the measured noise floor was *below 40%*. The
noise floor is a measurement of a noisy quantity, so it varies: one run in
five reported 72% on a machine that had not changed, and the harness failed.
That is a **value claim about a noisy measurement**, which is precisely the
mistake <a href>the instrument concept exists to warn against</a> — committed
in the course about it. Two fixes, both correct rather than merely looser:

1. The floor is now **reported and used as the tolerance** for the
   value-shaped checks, and **never bounded**. The check asserts that it was
   measured and is finite and positive; nothing asserts what it is.
2. The ratio check was moved off the medians of marginal costs and onto the
   **totals**, which differ by about 5× and are therefore far outside any
   plausible noise. A median of marginals can go near zero on a bad run and
   produce a ratio of 27×, which is arithmetically true and physically
   absurd.

After the fix: **10 consecutive runs, 37/37 every time.** A harness that
fails one run in five is a harness people learn to re-run, and a harness
people learn to re-run verifies nothing.

**E7 — a stale kernel sample treated as a live reading.** An earlier version
sampled `/proc/cpuinfo`'s `cpu MHz` around every measurement and converted
ticks to cycles with it. That value is updated far more slowly than a
measurement takes, and the resulting "cycles" were wrong by up to 3×. The
sample is now printed for orientation and **explicitly not used**.

## What is deliberately not claimed

- **Any absolute cycle count.** The TSC is a time base and the core clock
  varies; the course reports ratios and minima, and the crosscheck asserts
  *shapes* (monotonicity, ordering, bounds) rather than values.
- **A mispredict penalty.** None was observed, and with no PMU there is no way
  to distinguish "the predictor learned it" from "the cost is hidden". The
  course says so rather than quoting a number from elsewhere.
- **The mechanism behind the alignment effect.** The effect is measured; the
  cause is not, and the course names three candidates and declines to choose.
- **Any claim about another microarchitecture.** One machine, one ISA. The
  *method* — measure the instrument, then the machine — is the transferable
  part, and this course's own numbers are not.
- **Out-of-order execution, store buffers, memory disambiguation.** Not
  measured, and not inferable from timing on this machine without a PMU.
  Named as existing, not described as if known.

## Reproducing

```bash
cd courses/exe/assets/samples
./build_samples.sh     # the machine, the build, the run, the noise floor
python3 crosscheck.py  # 37 checks
./cycbench             # the artifact, 7 sections
./cycbench --quick     # faster and noisier
```

Tracked: `build_samples.sh`, `cycbench.c`, `crosscheck.py`, `.gitignore`.
`build_samples.sh` writes nothing; the two `.c` files are the source of the
two things that are measured.
