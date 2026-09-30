# The x86-64 Machine: Privilege, Memory and Time — research log

Every number in this course was measured on this machine, with these tools,
**before** it was written. Claims that did not survive measurement were
**retracted rather than softened**, and all ten retractions are printed by the
artifact in section 7 and asserted as text by `crosscheck.py` group J, so that
they can be neither quietly dropped nor edited into being right.

Two of the ten are not about the machine at all. **R4 is a wrong answer the
harness produced** (a `syscall` table that reported all fifteen registers
clobbered, for a reason that had nothing to do with the CPU) and **R5 is a
right answer for a wrong reason** (LAM read from the wrong CPUID subleaf). They
are the argument for the whole collection: the interesting failures in this
course were not in the architecture and not in the kernel, they were in what a
number means.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19 model 0x50 (Zen 3) |
| Topology | 1 socket, 6 cores, 2 threads/core = 12 logical CPUs; **one NUMA node** |
| TSC | 2.2957 GHz busy, 2.2957 GHz across a 300 ms sleep — **invariant to 0.0006 %** |
| Linear addresses | 48 bits. `CPUID.80000008:EAX[21]` LA57 = 0 and `CPUID.7.0:ECX[16]` = 0 |
| PMU | **present in the metal, absent to the process.** `core-PMU` and `L3-PMU` are 1; `RDPMC` is a #GP, `perf_event_open` is `EACCES`, `/dev/cpu/0/msr` is root-only, `perf_event_paranoid` is 4 |
| Kernel | 7.0.0-34-generic, gcc 15.2.0, binutils 2.46, Python 3.14 |
| Noise floor | measured per run and printed **before any claim**, on two bodies: a pointer chase and an arithmetic increment loop, which are 5–10× apart, and the arithmetic one is printed as *the clock*, not as noise |
| Placement | pinned to one CPU, and the CPU that answered is read back from inside the process and printed |

Two facts about the machine decide what this course may claim at all.

1. **There are no readable event counters.** Nothing here counts instructions,
   cycles, branches or mispredictions. Every number in the artifact is either a
   **fault**, a **bit pattern**, a **bisection result** or a **duration** — and a
   duration bounds a count without measuring it.
2. **Everything that matters here is a fault rather than a slowdown.** The
   privilege boundary, the canonical hole, the unmapped IDT, the read-only
   page: every one of them is demonstrated by a process dying, because that is
   the only instrument a user process has.

## Scope: what the twenty-three courses before it left open

The rule that shaped this course is in `docs/x86-64-section-plan.md`:
*"the comparison lives in the neutral courses; the depth lives in the
per-arch ones."* Seven neutral courses already taught exceptions, rings,
paging, canonical addressing and performance counters **neutrally, with x86-64
as the running example** — `priv` with eight concepts, `mem` with seven, `smp`
with seven.

So this course owes **no principle at all**. It owes the exhaustive reference:
the complete 32-vector table with a class and an error-code flag per row, the
complete CR0/CR3/CR4 bit layout, the complete DR7 layout and mask, the complete
paging-entry layout, and the five-width canonical matrix. Every concept links
back to the neutral course that owns the *why*.

What no neutral course owned, and what this course is actually about, is the
**inventory**: a systematic statement of what a ring-3 process can and cannot
learn about the machine it is running on. `priv` established three data points
in that inventory — `SIDT` is readable, the IDT is not, and there is no
`avx512f` — and this course makes them a table of fifty instructions, each in
a forked child, with a partition the harness can check.

## What was measured, and what it changed

| # | Experiment | Recorded result | What it changed |
|---|---|---|---|
| A1 | TSC busy and across a 300 ms sleep | 2.2957 vs 2.2957 GHz, drift −0.0006 % | A tick is TIME. Every figure is a ratio. |
| A2 | Noise floor on two bodies, printed before anything else | pointer chase 5.725, arithmetic loop 1.198, 4.78× apart | The floor is the chase; the increment loop is *the clock*. |
| A3 | Counter absence, three ways | `RDPMC` → #GP, `perf_event_open` → `EACCES`, `/dev/cpu/0/msr` → `EACCES` | **R7.** The draft said "this machine has no PMU". The silicon HAS core and L3 PMUs. The absence is ACCESS, which names the permission to change. |
| A4 | The specification, printed as section 1B and marked **NOT MEASURED** | CR0's 15 rows, CR3's 6 fields, CR4's 31 rows, DR7's 18 rows, the 4 paging indices, 14 entry flags, 7 error-code bits | The only quoted tables in the file, and the harness asserts them **to the bit** — which is possible because a bit position is exact. |
| F1 | **The boundary**: 50 instructions, one forked child each | 39 fault, 11 return, **34 at `si_code` 128**, 5 at `SIGILL` | The set is not the one in the manual. `SIDT`/`SGDT`/`STR`/`SLDT`/`SMSW`/`XGETBV`/`RDFSBASE`/`WRFSBASE` all return. |
| F2 | The set, as a **partition** | the two sets are disjoint; the harness asserts it | A count is a claim; a partition is a check. |
| F3 | `sysret` vs `sysenter` from ring 3 | `si_code 128` vs `SIGILL` `si_code 2` | Two instructions, one word, two different faults, and a boundary *rule* would have had to pick one. |
| F4 | **The syscall register census**: 13 markers, 26 arms | 24 survived, 2 clobbered — and both clobbered are `r11` | **R3, R4.** The first version asked for 14 outputs in one asm block and died with `SIGBUS`; a version that fixed that but not the clobber list reported **all fifteen clobbered**. |
| F5 | The unknown-syscall number | raw `RAX = -38` = `-ENOSYS`; libc turns it into `-1` with `errno 38` | The first version printed libc's `-1` beside a sentence about `-ENOSYS`. A wrapper under test must not be the instrument. |
| F6 | Six arguments to a zero-argument call | accepted, and the return value matched libc's | The kernel reads the argument count from the **call site's** declared arity, so a caller cannot make a syscall dearer. |
| F7 | The 32-vector table, with a source column | 6 MEASURED, 26 QUOTED | The class of every row is quoted, including the six measured: deciding it needs the saved RIP, which the kernel does not put in the `siginfo`. |
| F8 | The vendor census as a **partition** | 20 + 1 + 1 + 9 + 1 = 32 | **The first version printed 21, 1, 0** — it counted row 28 twice, as AMD-only *and* as reserved, and counted #19 as "defined on both" rather than as the renamed row. A census that does not add up is a census of a typo. |
| F9 | Three page faults, three events | `si_code` 1, 2, 2 | One bit of a six-bit error code reaches userspace, and it is the present bit. Bit 1 (write) and bit 4 (instruction) are what a demand-paging system needs. |
| F10 | Nine `int $N` vectors, including DPL-0 and unused ones | all nine `si_code 128`; `int $0x80` returns | A user chooses that a gate's DPL permits entry, not where the vector goes. |
| F11 | The canonical matrix on **five** widths | 20 rows × 5 columns, 5 of 5 bisections | Extends `priv`'s three. The 2-byte arm is the one that separates the rule from a constant. |
| F12 | The upper half's lower edge, bisected on five widths | `0xffff800000000000` on all five, and `2^64 − 2^47` on all five | **The correction.** The draft said the upper half began at `0xffffffff80000000`, which is 2<sup>31</sup> bytes *inside* it. |
| F13 | The 16-byte arm, `movdqa` against `movdqu` | the C form reported 128 at every unaligned offset | **R2.** The sweep was measuring an **alignment** requirement. `objdump` on the body is the only reason it was caught. |
| F14 | The 13 GPR markers and a 14-output asm block | `SIGBUS` | The compiler held the address of an output slot in a register the body had overwritten. **R3.** |
| F15 | `str %w0` and the upper bits of the register | masked to 0xffff; unmasked it read `0x35410040` | Sixteen bits of selector plus whatever the allocator left there. The `%w` form is a contract gcc does not know about. |
| F16 | An untouched `mmap`, then one write, then `mprotect`, then a write | bit 63: 0, 1, 0, 0, 1 | **Demand paging observed from the inside.** The entry is created by the TOUCH; `mprotect` alone changes nothing. |
| F17 | `mprotect` and one write on a `PROT_NONE` page | identical before the write | `PROT_NONE` is a non-present entry, not a special one. |
| F18 | Which pagemap bits move | the harness's first version asserted "only bit 63" and **failed on its first honest run** | One more bit moves in the fourth row and the artifact **declines to name it**, because the kernel's definition of it has changed twice. |
| F19 | Reading one byte of the IDT and of the GDT | `si_code 1`, `si_addr` = the base the instruction printed | **R1.** The boundary is a page-table fact, and the replacement sentence *predicts* the address. |
| F20 | The GDT/IDT placement | bases 2<sup>32</sup> apart, each table exactly 2<sup>16</sup> bytes | The first draft said the tables were adjacent, from reading `base+limit+1` off a hex string. **The retraction is printed with both numbers.** |
| F21 | `CPUID.80000008:EAX[13:12]` | reads **3**, which the manual reserves | A first version read it as a count of bits and printed 51. Three fields in one register and the reserved one is the easiest to misread. |
| F22 | LAM, five CPUID leaves | `7.1:EAX[26]`, not `7.0:ECX[26]` | **R5.** Same number, wrong register, wrong subleaf, right answer. |
| F23 | The `DR7` mask, computed from the printed formula | four cases, all eight fields disjoint, `0xdddd06aa` for four 4-byte write breakpoints | The harness **recomputes** it rather than comparing a constant, so a wrong formula fails even with a right constant. |
| F24 | The all-local `DR7` mask | `0x55550455`; the first version gave `0x55550400` | Clearing the global bits out of a mask that never had them set leaves **zero** enable bits: a debugger that breaks on nothing. |

## The bug that cost twenty minutes, and it is the best one in the file

The first version of the boundary harness stored the child's `si_code` in a
plain global. The signal handler runs in the child, wrote the child's copy, and
the parent read its own — which had never been written.

**Every one of the fifty rows printed `si_code 0`.**

It is worth printing at length because of *what the wrong number was*. Zero is
not a neutral wrong answer. `si_code 0` reads as "the kernel reported no code",
and a table of fifty rows saying that is a **publishable result** — it looks
like a finding about a hardened kernel. Thirty-four of those rows should have
been 128.

The fix is three lines: an `mmap(MAP_SHARED)` page, the handler writing into
it, and a `used` flag so the parent can tell "the instruction returned" from
"the instruction was deleted". That last flag matters more than the shared page,
and it was added for a second reason — **gcc had deleted the divide-by-zero
experiment**, and without a flag the harness would have reported the deleted
probe as a clean run.

## Retractions, all ten

R1 the IDT is unreadable *because it is privileged* · R2 the 16-byte arm
measures the canonical boundary *(it measures an alignment rule)* · R3 one
inline-asm block can read all fourteen registers across a syscall *(SIGBUS)* ·
R4 `syscall` destroys fifteen registers *(the harness talking)* · R5 LAM is
reported in CPUID leaf 7 subleaf 0 *(right answer, wrong field)* · R6 the
canonical boundary is the address 2<sup>47</sup> · R7 this machine has no
performance monitoring hardware *(it has no **access** to it)* · R8 `si_addr` is
the address the CPU faulted on *(it is the address the **kernel** chose)* · R9
`PROT_READ` and `PROT_NONE` are distinguishable *(they are not)* · R10 the
high bit of a pagemap word is the PTE's no-execute bit *(it is PM_PRESENT)*.

**Not one of the ten is a mistake about how a computer works.** Every one is a
mistake about what a *number* is, and that is the argument the course ends on.

## Limits, printed rather than footnoted

* **No cycle counts, and no event counts of any kind.** `RDPMC` is a #GP,
  `perf_event_open` is `EACCES`, and the kernel reports
  `perf_event_paranoid = 4`. Every duration is a *duration*. Settled by
  `perf_event_open` with a paranoid setting below 4 and a PMU passthrough.
* **Whether CR0–CR4 hold the values the kernel reports.** `arch_prctl` returns
  `0x207` and every read of CR0–CR4 and CR0–CR8 is a fault. A consequence is
  not a reading. Settled by a CPL 0 program.
* **Whether SMEP and SMAP are on.** A report; a process cannot execute a
  supervisor page to find out, because there are none.
* **`IA32_STAR`, `IA32_LSTAR`, `IA32_SFMASK`.** `RDMSR` is a fault and
  `/dev/cpu/0/msr` is root-only, both measured. `priv` got the convention from
  the vDSO's bytes, which is a weaker source.
* **The class of any exception.** Read from a manual and marked `QUOTED` on
  every row. Deciding one needs the saved RIP, which the kernel does not put in
  the `siginfo`.
* **The error code the CPU pushed.** `si_code` is the kernel's translation, and
  section 4 measures that one of six bits survives. Settled by reading
  `orig_ax` in `pt_regs`.
* **Which `DR7` layout this CPU implements.** Two descriptions disagree and the
  artifact prints both; `DR7` is unreadable from ring 3. Settled by one
  `PTRACE_PEEKUSER` at DR7, at CPL 0, in five lines.
* **The `PS` bit of a real 2 MiB mapping.** `MAP_HUGETLB` returned `ENOMEM`
  and no transparent huge page collapsed during the run, so the `PS=1` row is
  `QUOTED` and only the 4 KiB path is measured.
* **AArch64, RISC-V, and every other architecture.** Not run, not quoted, and
  deliberately absent.
* **A second run's addresses.** Every address in the artifact moves with ASLR
  and with the heap, so the pages quote the *relation* and the relation is the
  measurement.

## Reproducing

```sh
cd courses/x86sys/assets/samples
./build_samples.sh          # disassemble one function, build, run three times, cross-check
python3 crosscheck.py       # 214 checks against the recorded run
```

`sysdump.out`, `run1.txt` and `run2.txt` ship, so the claims are checkable on
a machine that never ran the benchmark. All three are **214/214** as recorded.
The artifact takes about two seconds end to end, most of it the 390 forked
children in the boundary and exception tables.
