# SIMD and Vector Processing — research log

Every number in the course was measured before it was written, on this machine,
with these tools. Claims that did not survive measurement were **retracted
rather than softened**, and all eight retractions are printed by the artifact in
section 8 and asserted as text by `crosscheck.py` group H so that they can be
neither quietly dropped nor deleted.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19, model 0x50 |
| Caches | L1d 32 KiB, L1i 32 KiB (shared by the sibling pair), L2 512 KiB (same pair), **L3 16 MiB shared by all 12 logical CPUs** |
| NUMA | 1 node, `node0 cpulist = 0-11` |
| TSC | 2.2956 GHz busy, 2.2957 GHz across a 120 ms sleep — **invariant to 0.002 %** |
| Vector ISA | `sse2`, `ssse3`, `sse4_1`, `sse4_2`, `avx`, `f16c`, `fma`, `avx2`, `bmi1`, `bmi2`, `xsave` |
| **AVX-512** | **ABSENT.** `avx512f=0 avx512dq=0 avx512cd=0 avx512bw=0 avx512vl=0` — all five CPUID.7.0 EBX bits read as zero |
| PMU | **absent.** `perf_event_paranoid = 4` |
| Compiler | gcc 15.2.0, built with `-O2 -Wall -mavx2 -mfma` |
| Noise floor | measured per run and **printed before any claim**: 25.1 %, 33.5 %, 62.5 % on the three recorded runs |

Three rows decide what this course may claim at all:

1. **No hardware performance counters.** No instruction, uop, cycle, load, store
   or cache-line split can be *counted* here. Every number is a **duration**, and
   a duration bounds a count without measuring it. Every mechanism in every
   table is therefore marked INFERRED.
2. **No AVX-512.** Five CPUID bits, all zero. This is a *checked fact* and not a
   gap, and it is what licenses the whole of section 7 to be quoted: what a
   ZMM is and what a k0–k7 mask register is comes from the manuals, and
   **nothing about a 512-bit register is measured**.
3. **The core clock moves and is not readable.** A TSC tick is *time*, so there
   is not one cycle count anywhere in the artifact.

## Scope: what the prior courses left open

A word-boundary grep (`grep -rlwi`) over `content/src/` after the fifth
CPU-architecture course:

| Term | Files | Sense |
|---|---|---|
| `lane` | **0** | — the central definition, absent |
| `XMM` / `YMM` / `ZMM` | **0** | never written at all |
| `NEON` | **0** | — |
| `emmintrin` | **0** | — |
| `vectoriz*` | **0** | the word is not used |
| `mask register`, `k register` | **0** | — |
| `FMA`, `avx2`, `float point` | **0** | — |
| `SIMDe`, `scatter`, `horizontal add` | **0** | — |
| `SIMD` | 8 | the **vector-19 exception** in `priv_vectors.ch`, the spelled-out phrase in two landing pages, the **WebAssembly `simd` proposal** in the wasm course, and `exe_deps.ch` / `exe_latency.ch` using the phrase as a known quantity. **Zero teaching.** |
| `AVX` / `AVX-512` | 6 | the ISA course, and **every one is about the `0x62` EVEX prefix versus `BOUND`** — a decoding fact. That course taught what byte introduces an AVX-512 instruction and never said what the instruction does. |
| `gather` | 2 | a reading-comprehension passage about bees gathering nectar, and a linker step that collects symbol tables |
| `shuffle` | 1 | a table of revision techniques telling you to shuffle your topics |
| `MESI` | 2 | both in yesterday's `smp_*` files — **0 before that course** |
| `snoop` | 3 | all three in `smp_*` — **0 before that course** |

The unpaid hand-off is the sharpest thing in the list, and it is not a term
count. `exe_deps.ch` says a loop unrolls into **"multiples of the SIMD width"**
and `exe_latency.ch` says the same work is done **"in SIMD"**. Both use the
phrase as a known quantity and neither defines it — exactly as the memory
course used "SMT siblings" without defining it. **This course discharges that
debt, and the lane table in section 1 is the definition.**

## The findings

### F1 — The ceiling is the memory system, not the lane count

The same statement, the same 4-wide instruction, the same machine, five
working-set sizes. `ns per element`, minimum of 5 interleaved:

| working set | scalar | 2-wide | 4-wide | **4-wide / scalar** | auto-vec | via pointers |
|---|---|---|---|---|---|---|
| 2 KiB (inside L1) | 0.719 | 0.361 | 0.185 | **3.89×** | 3.90× | 0.11× |
| 96 KiB (L1 → L2) | 0.799 | 0.461 | 0.357 | **2.24×** | 2.24× | 0.12× |
| 768 KiB (past L2) | 0.827 | 0.507 | 0.431 | **1.92×** | 1.95× | 0.12× |
| 6 MiB (inside L3) | 0.831 | 0.508 | 0.429 | **1.94×** | 1.90× | 0.12× |
| 24 MiB (past L3) | 1.531 | 1.442 | 1.340 | **1.14×** | 1.18× | 0.23× |

**The lane count did not change between the first row and the last. It is four
in both.** The speedup fell 3.89× → 1.14×, a factor of 3.41, while:

- the **scalar** arm went 0.719 → 1.531, a factor of **2.13**;
- the **4-wide** arm went 0.185 → 1.340, a factor of **7.25**.

**The vector arm's cost went up by seven and the scalar arm's by two, and the
difference is the speedup.** A 4-wide loop does the same work in a quarter of
the instructions, which is worth almost nothing once the bottleneck is
bandwidth rather than the instruction rate. This is the course.

Across the three recorded runs the L1 figure was **3.89×, 3.91× and 3.70×** —
a shape, not a value.

### F2 — The compiler matches the intrinsics, and FMA is worth nothing

Six arms, one loop, 64 doubles, `A[i] = A[i]*B[i] + C[i]`, 20000 iterations,
pinned, interleaved, min-of-7:

| arm | ns/iter | speedup |
|---|---|---|
| A scalar C, `-O2`, auto-vectorised | 11.81 | **3.90×** |
| B scalar C, `no-tree-vectorize` (the floor) | 46.08 | 1.00× |
| C SSE2, 2 doubles per instruction | 23.08 | **2.00×** |
| D AVX, 4 doubles, mul then add | 11.80 | **3.90×** |
| E AVX2+FMA, 4 doubles, one arithmetic instruction | 11.80 | **3.90×** |
| F AVX2+FMA, 4 doubles, A as a memory operand | 13.22 | **3.49×** |

Two nulls that are results:

- **The compiler's arm and the hand-written 4-wide arm are identical** (1.00×).
  A compiler will vectorise a straightforward loop at `-O2` these days and does
  it about as well as you would.
- **FMA contributes 1.00×.** It halves the arithmetic instruction count and the
  time does not move, because the loop is not waiting for the arithmetic.

And a surprise in the last row: **the memory-operand form is 1.12× SLOWER
than the three-load form.** One fewer memory *operation*, a longer dependency —
an instruction with a memory operand must wait for that load to land before it
can multiply. Instruction count is not the cost.

### F3 — The gather instruction is slower than not using it

| arm | ns/iter | vs sequential |
|---|---|---|
| four **consecutive** addresses: 3 loads, 1 store, 1 fma | 13.01 | 1.00× |
| **hand gather**: four scalar loads, then build the vector | 26.81 | **2.06×** |
| **hardware gather**: `vpgatherdd` | 74.54 | **5.73×** |

**`vpgatherdd` is 2.78× four ordinary scalar loads.** It is one instruction
doing four *independent* loads, and independent memory operations cannot be
overlapped — the memory system has no way to know they are unrelated. The
instruction saves the register moves and charges a decode penalty for them.
Both arms are intrinsics in the same translation unit, so this is not a
compiler artefact.

### F4 — A horizontal add costs as much as the vector op that produced it

Five arms, summing the squares of the same 65536 doubles:

| arm | ns per 4 elements | vs arm A | value produced |
|---|---|---|---|
| 4-wide accumulate, reduce **ONCE** at the end | 1.341 | 1.00× | **1.644919** |
| 4-wide, **TREE** horizontal every group | 1.946 | 1.45× | 26948.077729 |
| 4-wide, **EXTRACT** 4 lanes every group | 1.984 | 1.48× | 26948.077729 |
| 4-wide, **VHADDPD** every group | 1.929 | 1.44× | 26948.077729 |
| scalar loop, no vector at all | 5.349 | **3.99×** | **1.644919** |

The first and last rows compute the same number and the 4-wide one is 3.99×
faster. The three middle rows do **not** compute the same number — they are
computing a sum of running totals, which is R5.

`vhaddpd` adds the **corresponding** lanes of its two sources within each
128-bit half, so `vhaddpd(v,v)` **doubles** v. The first version called it
without swapping the halves and reported **exactly twice** the true sum. A
second bug hid behind it (a tree reduction that added an already-paired
register's halves to each other) and gave the same symptom.

### F5 — Alignment is a fault requirement, and the tail's clever answer is slow

**Alignment.** All three arms within 6% of each other, and the spread moves
between runs — one of them came out *faster*. The same comparison at 2 MiB per
stream came out 0.92×, 1.29× and 1.00× on the three runs: **no consistent
direction**, which is what no effect looks like when the loop is
bandwidth-bound anyway.

What *is* real: `_mm256_load_pd` on the same +8 address **raises SIGSEGV**,
measured by forking a child and catching the signal. A duration table is the
wrong instrument for a correctness requirement.

**The tail**, 66 elements with a 4-wide instruction and no mask register:

| arm | ns/iter | vs no-tail |
|---|---|---|
| 64 elements, no tail | 12.71 | 1.00× |
| 66, 4-wide + **scalar remainder** of 2 | 12.94 | **1.02×** |
| 66, 4-wide + one **overlapping** iteration | 22.50 | **1.77×** |
| 68, plain 4-wide — **writes 2 elements past the end** | 13.91 | 1.09× |
| control: **full** 32-byte overlap | 13.95 | 1.10× |
| control: **partial** overlap load, 1 lane stored back | 16.62 | 1.31× |

The scalar remainder is free. The clever overlap is the **worst arm in its own
table**, and the two controls say why: a full overlap is cheap and a partial
overlap load is not, so the cost is the half-overlapping load that cannot be
store-forwarded. **Mechanism INFERRED** — no PMU. The arm that writes past the
end is cheap and is a bug.

## Retractions, recorded

All eight are printed by the artifact in section 8 and asserted as text by
`crosscheck.py`, group H. Five of the eight were found by *running* the
artifact.

**R1 — "The memory-operand arm measured 3.3, so the FMA form is broken."** The
arm was wrong and the **checksum** is what said so. `vfmadd231pd` computes
`B*C+A`, not `A*B+C`; the table was readable and the ratio plausible. The
general form, which has recurred four courses in a row: *an experiment that can
silently compute the wrong thing must print what it computed.*

**R2 — "The absolute nanosecond figures are the result."** The first version
divided by a hard-coded TSC rate. And even measured, the absolute ns/iter for
the same body moved **1.7×** between runs while every ratio moved **<10 %**.

**R3 — "Four lanes is 2.2×, not 4×, because the loop is memory bound."** The
story the course was drafted around, and it **did not reproduce**. At 1536 bytes
it is 3.89×, because 3 loads and 1 store per 4 elements really do get 4×
cheaper when the load ports are the bottleneck. The claim was true of a
*different workload*; the lesson survived and the sentence did not.

**R4 — "vhaddpd adds adjacent lanes."** It does not, and the first version
reported exactly twice the true sum. A second bug hid behind it. Two bugs, one
symptom, one line of output. The general danger: an error that is
*approximately* wrong announces itself; one that is *exactly* wrong is stable
across every re-run.

**R5 — "The reduction table compares four ways of summing."** Three of the five
arms were not summing. The same rule as R1 applies to the *answer* as to the
memory operations, and it was learned twice in one file.

**R6 — "An unaligned vector load is slow."** Not on this machine, at two sizes.
The general form: *check whether the thing faults before asking how slow it is.*

**R7 — "The compiler declined to vectorise because the trip count is a runtime
variable."** **Wrong, and it was an inference from a timing.** The disassembly
of four forms:

| form | verdict |
|---|---|
| `named_const` — named arrays, constant trip count | **VECTORISED** (1 packed-double, 0 scalar) |
| `named_var` — named arrays, runtime trip count | **VECTORISED** (1 packed-double, **1 scalar** = the epilogue) |
| `ptr_const` — through `double *`, constant | **NOT VECTORISED** |
| `ptr_var` — through `double *`, runtime | **NOT VECTORISED** |

The trip count costs a **scalar epilogue** for `n mod 4` — which is the tail
the artifact measures as free. The pointers cost the **vector loop itself**,
because the compiler cannot prove a store to `A[j]` does not change what
`B[j+4]` holds. Two different mechanisms, one harmless and one ruinous, told as
one tidy sentence because a tidy sentence is what a number going the right way
produces. The same draft also claimed the compiler **hoists** the loop-invariant
loads of B and C: the disassembly shows them loaded inside the inner loop. They
are not hoisted.

**R8 — "The control arm came out at 3.91×, so aliasing is not what stopped the
compiler."** **The control was not a control.** It was
`static double *gA = bA, *gB = bB, *gC = bC;` — the same three arrays wearing a
pointer costume, which gcc folded away. *A control that cannot fail is not a
control, and a check that passes on an artefact that was not built is worse than
no check, because it is counted.*

## Retractions of the *harness*, recorded

All found by **running** it.

**H1 — a floor check that failed on the course's own evidence, by 0.03.** The
check required the floor to be "more than twice as slow as any vector arm",
but the 2-wide arm is a 2× speedup by construction, so 45.31 > 2 × 22.67 is
false. Now two checks: the floor is the *slowest* arm, and it is at least twice
the 4-wide arms.

**H2 — one helper, two incompatible jobs.** A single-capture-group extractor
used on a row with a label and a value, handing the label to `float()`. Plus a
third real instance: the section 3 sweep grew from seven columns to nine and
every index shifted by one. There are now `one()` and `grab()`.

**H3 — substring checks that failed on present text because of case.**
`"INSTRUCTION COUNT is not the cost"` cannot match `Instruction COUNT is not
the cost`.

**H4 — new to this collection: a harness group that could not run at all on two
of three recorded runs.** The VERIFY block is appended by `build_samples.sh`,
not by `simdbench`, so a raw `./simdbench > run1.txt` had no disassembly and
group E failed for a reason a reader could not see. Fixed by extracting
`verify_codegen.sh` so the recorded run and the extra runs share one code path.

## What is deliberately not claimed

- **Any count.** `perf_event_paranoid = 4`. Every number is a duration.
- **Anything about AVX-512.** Five CPUID bits, all zero. ZMM and k0–k7 are
  manual claims with a document.
- **Whether the upper-ZMM state costs anything.** Described by the manuals;
  needs a register this CPU does not have.
- **A cross-check of the arithmetic against a second implementation.** The
  checksums prove every arm agrees with every other arm. They do not prove any
  agrees with a compiler — and the two bugs above are why that is worth saying.
- **The other two architectures.** Section 7 is quoted, not run.
- **Whether the compiler vectorised.** The speedups are consequences of the
  codegen, not evidence for it; the disassembly is the evidence.
- **A page-crossing vector load.** "Unaligned is free" is claimed *within a
  page*, and only there.
- **Anything about floating-point correctness.** The fixed point is exact by
  construction, so a checksum of 32.0 proves the right *number of operations*
  happened. It does not prove a vector sum equals a scalar sum, and section 5
  says in the body that a tree reduction reassociates and gives a different
  answer.

## Reproducing

```bash
cd courses/simd/assets/samples
./build_samples.sh            # build, run, dis, cross-check (~4 minutes)
./build_samples.sh --quick    # run the harness on a short run
python3 crosscheck.py         # the harness alone, against simdbench.out
./simdbench                    # the artifact alone, 8 sections
./verify_codegen.sh out.txt    # the disassembly block on its own
```

Tracked: `build_samples.sh`, `verify_codegen.sh`, `simdbench.c`,
`crosscheck.py`, `simdbench.out`, `run1-2.txt`, `.gitignore`. Everything else in
that directory is a build product.
