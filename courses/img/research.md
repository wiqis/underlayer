# Executable Images and OS Loading — research log

Everything the course asserts about the kernel was measured before it was
written, on this machine, with these tools. Where a claim did not survive
measurement it was retracted rather than softened, and the retractions are
recorded below in the order they happened.

## Toolchain actually used

| Tool | Version | Why it matters to the claims |
|---|---|---|
| Linux | x86-64, PIE by default | `AT_ENTRY` and `AT_PHDR` are absolute, so a PIE's file offsets are only recoverable through the difference |
| clang | 21.1.8 (LLVM) | Only used to build specimens |
| glibc + loader | 2.43 | The loader that reads the auxv |
| binutils `readelf` | 2.46 | The independent oracle for every ELF field |
| `/proc` | procfs | The kernel's own live view of a running process |

**Not available, and therefore not claimed:** no AArch64 machine and no AArch64
kernel, so the auxv is not cross-checked on a second architecture. No Mach-O
kernel, so nothing here says anything about `dyld`. The vDSO's *contents* are
architecture-specific and are not claimed — only that it is a well-formed ELF
image with the header properties measured here.

## Scope: what the previous five courses leave open

`grep -rl` over all 30 concept files in `obj`, `sym`, `reloc`, `link` and `dyn`:

| Term | Files mentioning it |
|---|---|
| `auxv`, `AT_PHDR`, `AT_ENTRY`, `AT_BASE`, `AT_RANDOM` | **0** |
| `auxiliary vector` | **0** |
| `vDSO` | 0 (one mention of the *filename* `linux-vdso.so.1` in `ld_so.ch`) |
| `demand paging` | **0** |
| `mmap_min_addr` | **0** |
| `set_tid_address` | **0** |
| `ASLR` entropy | **0** |

Five courses cover the toolchain end to end: object files, symbols, relocations,
static linking, dynamic linking. Every one of them is about how a *file* is
produced. None of them is about what the *kernel* does when the file is run.
`dyn` ends at the loader's userspace work. This course starts one layer down.

## The findings, and how each was established

### F1 — The auxv is the kernel's only handoff, and nothing exposes it

Full dump of a live process: 22 entries. Established by walking the initial
stack by hand. `AT_PHDR` 3, `AT_PHENT` 4, `AT_PHNUM` 5, `AT_PAGESZ` 6,
`AT_BASE` 7, `AT_FLAGS` 8, `AT_ENTRY` 9, `AT_UID`/`EUID`/`GID`/`EGID` 11–14,
`AT_PLATFORM` 15, `AT_HWCAP` 16, `AT_CLKTCK` 17, `AT_SECURE` 23,
`AT_RANDOM` 25, `AT_HWCAP2` 26, `AT_RSEQ_FEATURE_SIZE` 27, `AT_RSEQ_ALIGN` 28,
`AT_EXECFN` 31, `AT_SYSINFO_EHDR` 33, `AT_MINSIGSTKSZ` 51.

The names come from `/usr/include/elf.h`, which is the kernel's UAPI header —
which is the point. The C library does not re-export them because the C library
has no reason to: `main()` receives `argc`/`argv` and nothing else.

`AT_MINSIGSTKSZ` (51) = 3376 on this kernel. It was 2048 for most of Linux's
history and rose for the new signal unwinder. Claimed only as "the number the
kernel reports", cross-checked for plausibility, not attributed to a specific
kernel version in the course text.

### F2 — `AT_ENTRY - AT_PHDR == e_entry - e_phoff`

The load-bearing arithmetic fact of the course. Both values are in the file's
own units and must be equal:

```
AT_ENTRY - AT_PHDR   = 0x10f0
e_entry - e_phoff    = 0x10f0
```

This is what makes the auxv a *translation* rather than a recomputation: the
kernel loaded the file at some base and the two absolute addresses differ by
exactly what the file says they differ by. `stackwalk.py` asserts it on every
run, alongside a second check that maps `AT_ENTRY` through `/proc/<pid>/maps`
back to the file offset of `e_entry`.

### F3 — The vDSO is a real ELF image with no file on disk

Read 64 bytes out of `/proc/self/mem` at the address `/proc/self/maps` labels
`[vdso]`:

```
magic = 7f 45 4c 46        e_type = 3 (ET_DYN)
e_machine = 62 (EM_X86_64) e_phentsize = 56, e_phnum = 6, e_phoff = 64
size = 8192
```

`AT_SYSINFO_EHDR` (33) equals the vDSO's mapped base — **verified within a
single process**, because comparing across two runs fails: ASLR puts the vDSO
somewhere different every time. The first version of the build script made
exactly that mistake and printed two unrelated addresses; the corrected version
has the measuring program read its own auxv and compare in-process, and prints
`EHDREQ_VDSO=1`.

### F4 — `mmap_min_addr` is `0x10000`, and a hint is not a request

```
MAP_FIXED  0x100000 = 0x100000    ok
MAP_FIXED   0x10000 = 0x10000     ok
MAP_FIXED    0x8000 = EPERM
MAP_FIXED    0x1000 = EPERM
hint         0x1000 = 0x7...000   ok        <-- relocated, not refused
```

The floor is 64 KB. The same low addresses *without* `MAP_FIXED` succeed, at
somewhere else. This is the whole `mmap` contract in one table and is the
reason `MAP_FIXED` exists as a separate flag.

### F5 — Demand paging: about one minor fault per page, once

1 MB of `.bss`, touched a page at a time:

```
startup   = 122
touched   = 377   (+255)
rewritten = 377   (+0)
```

256 pages, 255 faults (one page was already resident). The second pass costs
zero. The course claims exactly this and nothing about the internal mechanism
of the write fault, which was not separately isolated.

## Errors made during this research, kept because they are the good parts

**E1 — The first auxv walk segfaulted.** The walk skipped *one*
NULL-terminated array after `argv` instead of two, landing inside `envp` and
reading a string pointer as an auxv tag. The layout is `argc | argv | NULL |
envp | NULL | auxv`, so auxv is two arrays past `argv`, not one. This became
`img-stack`'s central trap, because a learner will hit it.

**E2 — `%rsp` inside `main` is not the initial stack pointer.** libc's `_start`
has already pushed a return address and `main`'s frame. The kernel's own
answer is `/proc/self/stat` field 28, `startstack`, which exists for exactly
this purpose. Both `imgdump.c` and `stackwalk.py` read it, and the artifact
asserts that the child's own reading equals the parent's reading of `/proc`.

**E3 — `/proc/self/maps` in a shell pipeline reads the wrong process.** The
first version of I7 piped `awk '{...}' /proc/self/maps`, which printed
**mawk's** address space. It looked entirely plausible: a PIE binary, a heap, a
loader, all in the right places. `self` means *the process doing the reading*,
and in a pipeline that is `awk`. The corrected version has a 3-line C program
print its own maps, and then deliberately runs the broken `awk` version
alongside it as a demonstration. This is kept as a real finding, not tidied
away, because it is the single most misleading thing in this area.

**E4 — A hardcoded stack dump window segfaults, and so does a bigger one.**
`startstack` sits at the *low* end of the frame the kernel built, with the
strings above it and the top of the stack just above those. An 8 KB window
truncates the strings on a large environment (`AT_EXECFN`'s string was measured
10368 bytes above `startstack` in one run). A 64 KB window reads past the end
of the stack mapping and segfaults on *every* process. The fix is to ask the
kernel: read `/proc/self/maps`, find the mapping containing `startstack`, and
dump exactly up to its high end. That is what `imgdump.c` does, and the
result — 11920 bytes in one run — is the real size of the kernel's frame.

**E5 — The crosscheck caught the course's own parser.** `#%018lx` prints a
value of zero with **no** `0x` prefix, only leading zeros. The first auxv
regex required `0x`, so it silently lost `AT_SECURE` and `AT_FLAGS` — the two
entries that confirm the process is not privileged. The harness failed with
`41/40` and the fix was one character class. This is the strongest argument for
having the harness: the bug was in the tooling written to check the tooling.

## What is deliberately not claimed

- **The contents of the vDSO.** Which symbols it exports, what
  `__vdso_clock_gettime` does, how it is generated. That is a large subject
  and this course only establishes that it is a well-formed ELF image.
- **The exact ASLR entropy in bits.** Not measured. The course says the
  addresses differ between runs, which is measured, and stops there.
- **AArch64.** No second architecture was available. The auxv constants are
  architecture-independent, but that is not asserted as measured.
- **Why the kernel chooses the specific addresses it does.** Observed and
  characterised (below the loader, stack at the top, gap between), not
  explained from kernel source, which was not read.

## Reproducing all of it

```bash
cd courses/img/assets/samples
./build_samples.sh     # builds every specimen from an empty directory
python3 crosscheck.py  # re-derives every claim: 41 checks
python3 stackwalk.py   # the artifact: 18 internal checks
```

Tracked in git: `build_samples.sh`, `stackwalk.py`, `crosscheck.py`,
`.gitignore`. Everything else in that directory — every `.c` file, every
binary — is a build product, and `build_samples.sh` writes the `.c` files
itself, so there is exactly one source of truth.
