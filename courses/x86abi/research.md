# The x86-64 ABI — research log

Every number in this course was measured on this machine, with these tools,
**before** it was written. Claims that did not survive measurement were
**retracted rather than softened**, and all ten retractions are printed by the
artifact in section 10 and asserted as text by `crosscheck.py` group I, so that
they can be neither quietly dropped nor edited into being right.

Two of the ten are not about code at all. **R9 is a retracted estimate** (a
figure written into a page before anything had been compiled to check it) and
**R10 is retracted arithmetic** (a subtraction performed on two counts without
measuring whether they overlap). Together they are the argument for the whole
collection: the interesting failures in this course were not in the compiler
and not in glibc, they were in sentences.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19 model 0x50 (Zen 3) |
| Topology | 1 socket, 6 cores, 2 threads/core = 12 logical CPUs |
| TSC | 2.2957 GHz busy, 2.2957 GHz across a 300 ms sleep — **invariant to 0.0003 %** |
| PMU | **absent.** `perf_event_paranoid = 4`, and a forked child that executed `RDPMC` was killed with **signal 11** |
| Kernel | 5.15.0-*, gcc 15.2.0, binutils 2.46, glibc 2.43, Python 3.14 |
| Noise floor | measured per run and printed **before any claim**, on two bodies: a pointer chase and an arithmetic increment loop, which are always 4–7× apart and the arithmetic one is printed as *the clock*, not as noise |
| Placement | pinned to one CPU, and the CPU that answered is read back from inside the worker and printed (`pinned cpu observed: 3`) |

Two facts about the machine decide what this course may claim at all:

1. **No hardware performance counters.** Nothing here counts instructions,
   cycles, branches or mispredictions. Every number in the artifact is either a
   **fault**, a **bit pattern**, a **word of disassembly**, or a **duration** —
   and a duration bounds a count without measuring it.
2. **Everything that matters here is a fault rather than a slowdown.** The
   alignment rule, the tail-call rule, the red-zone rule and the varargs rule are
   all demonstrated by a process dying or by a bit pattern coming back wrong.
   That is not a stylistic preference: it is what the instruments on this
   machine are good enough to establish.

## Scope: what the twenty-two courses before it left open

The rule that shaped this course is in `docs/x86-64-section-plan.md`:
*"The comparison lives in the neutral courses; the depth lives in the per-arch
ones."* A word-boundary scan over the **379** concept files of the 22 shipped
courses, taken before this one was written:

| Term | Files | Note |
|---|---|---|
| `red zone` `callee-saved` `GPR` | **0** concept files | the only hits are one row of the assembly course's own scan table, which reports this same zero |
| `caller-saved` `psABI` `MXCSR` | **0** | owed to this course |
| `System V` | 4 | all as a *name* in a passing clause, never as a register list |
| `frame pointer` | 3 | all as a debugging convenience, never as a callee-saved register |
| `varargs` | 2 | both in the JVM course, about a class file attribute |
| `struct passing` | **0** | |

So the debt this course pays is narrow: the **exhaustive x86-64 reference** for
the frame. The *why* of a canary belongs to `sec`, the *why* the stack is set up
that way belongs to `dyn`, and the instruction semantics belong to `x86asm` and
`isa`. What was missing everywhere was the contract itself.

## What was measured, and what it changed

| # | Experiment | Recorded result | What it changed |
|---|---|---|---|
| A1 | TSC busy and across a 300 ms sleep | 2.2957 vs 2.2957 GHz, drift 0.0003 % | A tick is TIME. Every figure is a ratio. |
| A2 | Noise floor on two bodies, printed before anything else | pointer chase and arithmetic loop, 4–7× apart | The floor is the chase; the increment loop is *the clock*, and saying so stops a reader treating it as noise. |
| A3 | PMU absence | `RDPMC` in a child → **signal 11**; `perf_event_paranoid = 4` | No count of anything. Stated before any claim, not footnoted. |
| A4 | The specification, printed as section 1B and marked **NOT MEASURED** | six integer registers, `xmm0..xmm7`, 176-byte save area, gp_offset 8, fp_offset 48 | The only quoted table in the file, and it is separated from every measurement so a reader can check the oracle against the psABI without a compiler in the way. |
| F1 | **The audit**: 16 call sites × 4 optimisation levels, each argument in its own `volatile` global so the disassembly *names* it | **16/16 at every one of -O0, -O1, -O2, -Os. 64 of 64.** | **The course's distinctive idea.** A census would say "six registers were written"; an audit says *which argument was in which register, by name*, checked against a written oracle. |
| F2 | The callee side at -O2, the order each callee first *reads* its arguments | `f7`: six registers then `stack=0x10`; `mx`: `rsi rdx rcx rdi xmm0..xmm3` | Two rows that are two whole concepts. `f7` is the register/stack boundary (the seventh argument is at `[rsp+0x10]` = the caller's `[rsp]` + 8 pushed + 8 outgoing). `mx` is the **independence of the two sequences**, measured by name: four doubles went first and the integers still started at `%rdi`. |
| F3 | Where the return address is, read by the callee at its first instruction | `%rsp` is a stack address, `0(%rsp)` is a text address, both from **one** call | **R1.** The return RIP is *on the stack*. `call` pushes it, `ret` pops it, and nothing in the instruction needs a register. |
| F4 | A bare `syscall`, four registers around it | `%rcx` after = the address of the next instruction, **bit for bit**; `%r11` = the saved RFLAGS; `%r10` = the caller's own marker, **untouched** | The other half of **R1**: `%r10` *is* the system call's fourth argument, and the reason is that `%rcx` is busy. **The draft welded these two facts into one false sentence and the course exists to take them apart.** |
| F5 | `%rsp mod 16` at a callee's first instruction, four ways in | conforming `call` → 8; `subq $8` deleted → 0; tail `jmp` → 8; tail `jmp` after `subq $8` → **process killed** | **The alignment rule is TWO rules, not one (R4).** A `call` pushes 8 so the caller's `%rsp` must be 16-aligned at the call; a tail `jmp` pushes nothing so it must be 8 (mod 16), which for a function entered at 8 (mod 16) means *no adjustment at all*. A PLT stub is `endbr64; jmp *GOT(%rip)` and nothing else, and it is right for this reason. |
| F6 | One callee (gcc's own `-O0` prologue, a 16-byte vector local at `-16(%rbp)`), three arms | `movaps` through a conforming call returns `0x3ff8000000000000`; through a violating call **signal 11**; `movups` through the same violating call returns the same value | **A misaligned 16-byte store on this machine is not slow, it is a fault.** The `simd` course measured unaligned accesses as *free* here, so the rule cannot have been written for a penalty on this silicon. |
| F7 | The red zone, a leaf writing `-8(%rsp)` and `-128(%rsp)`, checksummed | leaf alone: both intact; leaf + one `call`: destroyed; leaf + framed callee: all four slots destroyed | **R2.** 128 bytes is a real number; the LEAF restriction is the whole of the content. |
| F8 | **The mechanism**, read rather than asserted: a leaf stores a magic word at its own `-8(%rsp)` and calls a function that reports its `%rsp` and `0(%rsp)` | the callee's `%rsp` is **exactly 8 below** the caller's, and `0(%rsp)` there is a text address | **The first eight bytes of the red zone are the return-address slot and `call` writes them.** Not a style guideline: arithmetic about where a push lands. |
| F9 | Callee-saved, by experiment rather than by table | a trampling callee → `%r12` CLOBBERED `0x2222222222222222`; a conforming one → SURVIVED `0x0b0b0b0b0b0b0b0b`; arithmetic through `%rbx` and `%r12` → `0x9999999999999a99` EXACT | The table established by **behaviour**, with the conforming arm as the control and the marker differing in every digit from the payload. |
| F10 | The direction flag, measured and then **repaired in place** | DF = 0 inside a conforming callee; DF = 1 after a non-conforming one; 0 again after `cld` | See the bug below. This arm is the one the artifact itself got wrong, and it is the most instructive result in the file. |
| F11 | `%rbp` clobbered | **signal 7 (SIGBUS)**, with a conforming callee returning normally | The sixth callee-saved register is a special case, because the caller's `leave` is `movq %rbp,%rsp; popq %rbp`. |
| F12 | MXCSR and the x87 control word across the same call | MXCSR `0x00001fa0` → `0x00006000` (RC 0 → 3) and restored by the caller; x87 CW `0x037f` → `0x0250` (PC 63 → 16) and **not** restored | **The direction reverses and it is measured, not quoted.** MXCSR's control bits are caller-saved; the x87 control word is callee-saved. Two floating-point control registers, one ISA, two directions. |
| F13 | `%al` claimed honestly twice, then lied | `al=2` → `0x3ff8…`/`0x4004…`; `al=2` → `0x4059…`/`0x4069…`; **`al=0` with 3.5 and 4.5 passed → `0x4059500000000000` (101.25) and `0x000000000000000a`**; `al=1` → both recovered | **The sharpest result in the course.** The caller's values were not corrupted: **they were never looked at.** The consumer read a save area that still held the last *honest* call. |
| F14 | The same failure through glibc's own `printf` | `al=2` → `1.500000 2.500000`; `al=2` → `101.250000 202.500000`; `al=0` → **`101.250000 0.000000`** | A number nobody passed, printed as though somebody had. This is not a slow path; it is a wrong answer on the code path of every `printf` with a double in it. |
| F15 | What `%al` actually means to gcc | `testb %al, %al` — a **boolean**, not a count (**R5**) | A self-describing convention is still a convention. `al=1` recovers *both* values, so a callee that trusts the count as an upper bound breaks where one that tests for zero does not. |
| F16 | `.cfi_*` directives in a 33-function corpus | 71 `cfi_def_cfa_offset`, 5 `cfi_offset`, 0 `cfi_def_cfa_register`, 142 total | The cheapest possible complete answer to "where is the CFA" is one instruction: *it is `%rsp` plus this number*. |
| F17 | A real unwinder (`backtrace()` from glibc `execinfo`) on a program built twice | **FRAMES 7** with `-fasync-unwind-tables`, **FRAMES 1** without | Not a wrong answer — *no* answer. The unwinder stopped at the frame it was called from, because nothing told it where the CFA is. A profiler with holes in exactly the places hardest to look at. |
| F18 | `.eh_frame` size, the same 33 functions compiled **three** ways | 358 bytes (default), **358 again** (`-fomit-frame-pointer`, byte-identical), **428** (`-fno-omit-frame-pointer`) | **R9.** The draft said "about eleven bytes without a frame pointer and about **forty** with one". The first half was measured. The second was a guess, and the measurement is **thirteen** — a frame pointer costs about **two** bytes of table, not thirty. Also: one of the three builds teaches that a flag can confirm a default without changing anything. |
| F19 | `abilint.py` over glibc's **static** library | 4,561 functions; census `%rbx` 1670/1598, `%rbp` 2555/2503, `%r12` 1242/1193, `%r13` 981/945, `%r14` 885/850, `%r15` 627/600 | **The census column is the point.** A checker reporting no violations and a checker examining nothing print the same line; the second column is what tells them apart. |
| F20 | The flags, and the two exemptions | 271 flags in 94 functions; 26 in leaves; 97 in context restorers; **3 in both**; true remainder **151** | **R10.** `271 − 26 − 97 = 148` is only valid if the exemptions are disjoint, and `setjmp` is both a leaf and a context restorer. The page said 148 and was wrong by three, invisibly. |
| F21 | The **positive control**, `control.s`, run through the same linter | `ct_clobber_r12`, `ct_clobber_r13`, `ct_clobber_rbx` flagged; `ct_ok_leaf`, `ct_ok_leaf4` **not** flagged; the one intended alignment violation found | A linter that flags everything is caught as loudly as one that flags nothing. Without this row, every zero above is hollow — and they were, once (**R8**). |
| F22 | The alignment half of the linter | 775 of 9,980 call sites "misaligned" | **R6.** The number is a fact about the **checker**. `abilint.py` loses track of `%rsp` at `pushfq`, at `enter`, and at any write it does not model, and a checker that cannot account for a mismatch is not evidence of a mismatch. The half is shipped and labelled unreliable where it is printed. |

## The bug that cost twenty-five minutes, and it is the best one in the file

`abi_df_dirty()` is a **non-conforming** callee: it sets `DF` and does not clear
it, which is exactly the violation F10 exists to measure. The first version of
`abidump` called it, read the flag, printed the number, and moved on.

Then the artifact **hung**. Not crashed — hung. Twenty-five minutes of user
time, no signal, no diagnostic, no output, at section 9, in a program whose
every other failure mode in the file is loud.

The non-conforming callee had set `DF` in the artifact's own process, and with
`DF` set every `rep`-based string routine in the C library scans **backwards** —
so the first `strstr` the artifact made after that point never returned. The
whole run now takes **1.4 seconds**.

Three things make this worth printing rather than quietly fixing:

* **The caller in ARM 5 was this program.** Every other arm measures a
  hypothetical callee. This one broke the measurement.
* **No compiler can warn about it.** `DF` is not in any register, so there is
  no callee-saved slot it could have been preserved in. The ABI's remedy is a
  sentence in a document.
* **A hang is the worst possible symptom.** A program that stops with no output
  looks like a slow machine, not like a broken contract. The diagnosis took a
  marker-bisect down to a single libc call.

## Retractions, all ten

R1 the fourth argument of a function call goes in `%r10` · R2 the red zone is 128
bytes of free scratch · R3 the red zone costs nothing because the memory was
going to be cache lines anyway *(not claimed)* · R4 the stack must be 16-byte
aligned at every control transfer · R5 `%al` is the number of vector registers
used *(half true, wrong half interesting)* · R6 glibc keeps `%rsp` aligned at
99.2 % of its call sites *(a fact about the checker)* · R7 a conforming program
cannot be miscompiled by a wrong calling convention *(not claimed and not
refuted)* · R8 the audit found no violations in a real library, so the library is
conformant · **R9 a frame description costs about forty bytes with a frame
pointer** *(an estimate, retracted with the measurement beside it)* · **R10 the
other 148 flags are unclassified** *(retracted arithmetic: the two exemptions
overlap by 3)*.

## Limits, printed rather than footnoted

* **No cycle counts.** No PMU, proved by a child that ran `RDPMC` and died.
  Every duration bounds a count without measuring it.
* **No claim about gcc's intent.** The corpus is real compiled code and the
  register assignments are real; a claim about *why* the bytes are the bytes is
  not a claim about bytes.
* **No observation of the cost of a violation.** The alignment rule is
  demonstrated with a *fault*, which is the right instrument; what merely
  misaligning something that does not fault costs is not measured here.
* **Whether a signal handler respects the 128-byte red-zone reservation** — the
  psABI's stated reason the red zone exists — is a kernel property, and this
  process cannot observe it.
* **Why the psABI says 16 and not 8.** The 1997 drafts argued from SSE2's
  16-byte moves. This file can show the fault that makes 16 necessary on *this*
  machine; it has no instrument for a drafting argument.
* **Windows x64 and every other ABI are quoted, not measured.** Four integer
  registers instead of six, a 32-byte shadow space, a different return
  convention. There is no such machine in the room.

## Reproducing

```sh
cd courses/x86abi/assets/samples
./build_samples.sh          # assemble, compile the corpus three ways, probe, audit, run, cross-check
python3 crosscheck.py       # 143 checks against the recorded run
```

`abidump.out`, `run1.txt` and `run2.txt` ship, so the claims are checkable on a
machine that never ran the benchmark. All three are **143/143** as recorded.

`build_samples.sh` takes about eight seconds end to end. That number is itself
worth keeping: for most of this course's life the same script did not finish,
and the reason was a contract violation the course was in the middle of
teaching.
