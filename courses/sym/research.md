# Symbol Resolution and Symbol Tables — research record

Every finding below was **measured on this machine**, not recalled. The command
that produced it is given so a reader can re-run it and, more importantly,
disprove it.

## Environment (measured, not assumed)

    ld                 GNU ld (GNU Binutils for Ubuntu) 2.46
    ld.gold            absent
    ld.lld             absent
    llvm-nm-21         LLVM 21.1.8
    readelf            GNU readelf (GNU Binutils for Ubuntu) 2.46
    gcc                gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0
    clang              Ubuntu clang 21.1.8
    glibc / ld.so      2.43

**Coverage consequence, stated up front:** this course's dynamic half is ELF +
x86-64 + glibc only. There is **no Mach-O linker and no Mach-O runtime on this
machine** (`ld` is bfd-only; `ld64`/`ld64.lld` absent), so Mach-O claims are
either marked as deferred or taken from the object-file course's own measured
Mach-O data. AArch64 is compile-only (no `aarch64-linux-gnu-ld`). The COFF
dynamic story is reachable only through `ld -m i386pe`, which cannot link TLS.

## Module 1 — Identity

### Finding 1 — `hidden` and `internal` do not set a visibility byte, they demote the binding

Measured with `vis.c` defining one function and one datum at each of the four
visibilities, built `-fPIC -shared`, then read with `llvm-nm`:

    def_fn   T   (GLOBAL, in .dynsym)
    def_data D   (GLOBAL, in .dynsym)
    prot_fn  T   (GLOBAL, in .dynsym)
    hid_fn   t   (LOCAL,  NOT in .dynsym)
    hid_data d   (LOCAL,  NOT in .dynsym)
    int_fn   t   (LOCAL,  NOT in .dynsym)

    $ readelf --dyn-syms -W libvis.so | grep -cE 'hid_fn|int_fn|hid_data'
    0

So `STV_HIDDEN` and `STV_INTERNAL` end up as **local binding** in the finished
object, not as a GLOBAL symbol carrying a visibility byte. Only `PROTECTED`
keeps the name global *and* exported. This is the sharpest available
counter-example to "`st_other` holds the visibility" — for two of the four
values the answer is not in `st_other` at all.

### Finding 2 — visibility is not a second, weaker binding

`PROTECTED` is the only value that both stays in `.dynsym` and forbids
preemption. The three-way split is the lesson:

| value     | in `.dynsym` | preemptible by an earlier DSO |
|-----------|--------------|-------------------------------|
| DEFAULT   | yes          | yes                           |
| PROTECTED | yes          | **no**                        |
| HIDDEN    | **no**       | no (nothing to preempt)       |
| INTERNAL  | **no**       | no (nothing to preempt)       |

## Module 2 — The algorithm

### Finding 3 — two strong definitions: the diagnostic names depend on link order

    $ clang -o t a.o b.o m.o
    b.o: in function `dup': b.c:(.text+0x0): multiple definition of `dup';
        a.o:a.c:(.text+0x0): first defined here

    $ clang -o t b.o a.o m.o
    a.c:(.text+0x0): multiple definition of `dup';
        b.o:b.c:(.text+0x0): first defined here

The *rule* is symmetric (two strong definitions is an error) but the *message*
is not: "first defined here" means first **on the command line**, so the
diagnostic reads differently for what is the same defect. Worth teaching: do not
read the order of the two filenames as a priority.

### Finding 4 — `-r` does not relax the rule

    $ ld -r -o partial.o a.o b.o
    b.o: in function `dup': multiple definition of `dup'; ... first defined here

A partial link still enforces one-definition-per-name. Useful to know because
"it's only relocatable, nothing is being decided yet" is a natural assumption.

### Finding 5 — COMMON is the whole reason `int x;` in a header ever worked

Three translation units, two writing `int cvar;` (a *tentative* definition),
one writing `int cvar = 5;`.

With `-fcommon` (the old default):

    x.o  2: ... OBJECT GLOBAL DEFAULT  COM cvar      <- SHN_COMMON
    y.o  2: ... OBJECT GLOBAL DEFAULT  COM cvar
    z.o  4: ... OBJECT GLOBAL DEFAULT    4 cvar      <- a real .data definition
    $ clang -o t x.o y.o z.o && ./t   ->  5          <- links silently

With `-fno-common` (the default since GCC 10):

    x.o  2: ... OBJECT GLOBAL DEFAULT    3 cvar      <- a real .bss definition
    $ clang -o t x.o y.o z.o
    yn.o:(.bss+0x0): multiple definition of `cvar'; xn.o:(.bss+0x0): first defined here
    zn.o:(.data+0x0): multiple definition of `cvar'; ...

So the tentative definition is not a weaker *kind* of definition — it is a
**different storage class** (`SHN_COMMON`, an unallocated run in `.bss`) whose
entire purpose is to be merged away. The moment it becomes real storage
(`-fno-common`) it collides like any other definition, which is why a codebase
can start failing with dozens of "multiple definition of `x`" errors after a
compiler upgrade and nothing in its own source changed.

### Finding 6 — archive extraction is demand-driven and left-to-right, one pass

Two archives with a mutual reference, built to link but *not* to recurse:
`libMA.a` provides `a_fn` (which reads `b_data`) and `a_data`; `libMB.a`
provides `b_fn` and `b_data`.

    MA.a MB.a                ->  links, exit 21      (1 + b_data=20)
    MB.a MA.a                ->  FAILS: undefined reference to `b_data`
    --start-group MB.a MA.a  ->  links, exit 21

The map file for the group case shows what actually happened:

    libMA.a(ma.o)      mm.o            (a_fn)
    libMB.a(db.o)      libMA.a(ma.o)   (b_data)

**`libMB.a(mb.o)` was never extracted.** The linker pulled `db.o` because
`ma.o` wanted `b_data`; `mb.o` was never needed, so it cost nothing. An archive
member that satisfies no pending undefined symbol is not merely unused — it is
never read.

## Module 3 — Runtime

### Finding 7 — `-z now` changes no code at all

Both binaries built from identical sources, one with `-Wl,-z,now`. The `.plt`
section is **0x30 bytes in both**, and the disassembly is identical
instruction-for-instruction:

    lazy                                  eager (-z now)
    401020: push 0x2fca(%rip)  # GOT+8    401020: push 0x2f9a(%rip)  # GOT+8
    401026: jmp  *0x2fcc(%rip)  # GOT+16   401026: jmp  *0x2f9c(%rip)  # GOT+16
    401030: jmp  *0x2fca(%rip)  # GOT+24   401030: jmp  *0x2f9a(%rip)  # GOT+24
    401036: push $0x0                      401036: push $0x0
    40103b: jmp  401020                   40103b: jmp  401020

Only the GOT addresses differ, because the GOT moved. The entire difference is
in the dynamic section:

    lazy:  (no BIND_NOW, no FLAGS_1)
    eager: DT_FLAGS    BIND_NOW
           DT_FLAGS_1  Flags: NOW

`.got.plt` (0x28 bytes, separate section) disappears under `-z now` and its
slots are merged into `.got`, which grows 0x20 -> 0x48.

**This is the finding worth teaching:** eager binding is a *dynamic-section
flag*, and the lazy PLT is left in the binary as dead code. Nothing rewrites the
PLT; the loader simply never falls through into it.

### Finding 8 — the behavioural proof, not the structural one

A program containing `if(argc > 99) { lib_fn(1); }` — the call **exists** in the
code and is **never executed**. Both binaries have both PLT entries. Which
symbols does the loader actually resolve?

    $ LD_DEBUG=bindings ./lt_lazy 2>&1 | grep 'binding file ./lt_lazy'
    calloc free __libc_start_main malloc printf _r_debug realloc

    $ LD_DEBUG=bindings ./lt_now 2>&1 | grep 'binding file ./lt_now'
    calloc free __libc_start_main lib_fn malloc printf _r_debug realloc
                                              ^^^^^^^

`lib_fn` is resolved under `-z now` and never resolved lazily. That is the whole
of lazy binding, measured: **a symbol the program never calls is never looked
up.** (Filter on `binding file ./<exe>` — `LD_DEBUG` otherwise emits ~80
bindings for ld.so's own internals, which drowns the signal.)

### Finding 9 — the code model silently decides who owns a datum

The same source, `extern int lib_data;` with the definition in a shared library,
built two ways. The only difference is the *code model of the executable's main
translation unit*:

    -fPIE  -pie      ->  R_X86_64_GLOB_DAT   (the library's storage is used)
    -fno-pie -no-pie ->  R_X86_64_COPY       (the EXECUTABLE gets its own copy)

and the access sequence differs to match:

    GLOB_DAT:  mov 0x2e90(%rip),%rax  # 403fd8 <lib_data>   ; load the ADDRESS
               mov (%rax),%ebx                            ; then the value
    COPY:      mov 0x2ed9(%rip),%ebx  # 404020 <lib_data>   ; load the VALUE

Nothing in the source says which one you get. `-no-pie` at *link* time is not
enough — the compile must also be `-fno-pie`, and a link-time-only flag leaves
`main.o` compiled as PIE and still yields `GLOB_DAT`. That is a real trap.

### Finding 10 — R_X86_64_COPY means one storage, not two

`COPY` is routinely described as "the executable gets a copy, so there are two
copies and they can diverge". Measured, that is not what happens here:

    before:            exe sees lib_data=7
    after exe writes:  exe sees 999
    library's lib_fn(0) = 999          <- the library reads the EXECUTABLE's copy

The loader redirects the library's own references to the executable's copy, so
there is one storage under two names. I then built the case that is supposed to
produce divergence — a definer plus *two* referencing libraries plus the
executable, in both code models:

    PIE  :  initial shared=7 a=7 b=7   after exe write 555: 555 555 555
    nopie:  initial shared=7 a=7 b=7   after exe write 555: 555 555 555

**I could not produce divergence on x86-64 / glibc 2.43.** The classic
"two copies with different values" failure is real historically and on other
targets (PowerPC, 32-bit ARM), but on this platform the loader keeps them
coherent. The course therefore teaches the *mechanism* and explicitly declines
to claim a bug that does not reproduce here.

## Module 4 — Versioning

### Finding 11 — `vd_cnt` counts the node's own name PLUS its parent

Decoded from the bytes, because `readelf -V`'s `Cnt:` did not match what the
script listed:

    ndx=1  flags=BASE  cnt=1  verdaux[0]='lib_vmap4.so'
    ndx=2  flags=none  cnt=1  verdaux[0]='V1'
    ndx=3  flags=none  cnt=2  verdaux[0]='V2'   verdaux[1]='V1'  <- PARENT
    ndx=4  flags=none  cnt=2  verdaux[0]='V3'   verdaux[1]='V2'  <- PARENT

So `vd_cnt` is not "how many names this version has". The **last verdaux of a
node is its parent version name**, and that entry is counted. A node with a
parent always has `cnt >= 2`. Anyone reading `Cnt:` as a name count will expect
`V2` to have one name and see two.

### Finding 12 — the version-name hash is the standard ELF hash

`vd_hash` for the same file: V1 = 0x591, V2 = 0x592, V3 = 0x593, and the BASE
node (the SONAME) = 0x04acf34f. Re-deriving with the SysV ELF hash function
(`h = h<<4 + c`, then fold the top nibble back down):

    elf_hash('V1')          = 0x00000591   MATCH
    elf_hash('V2')          = 0x00000592   MATCH
    elf_hash('V3')          = 0x00000593   MATCH
    elf_hash('lib_vmap4.so')= 0x04acf34f   MATCH

The *same function* `.hash` uses. It is there so the loader can reject a version
requirement with a 32-bit compare before doing any string comparison. Note the
consecutive values are not evidence of anything (V1/V2/V3 differ in one
character) — the proof is the SONAME.

### Finding 13 — a symbol may belong to only ONE version node; the first wins

Version script listing `compute` in V1 and again in V3:

    V1 { global: compute; local: *; };
    V2 { global: added_in_v2; } V1;
    V3 { global: compute; removed_in_v3; vtag; } V2;

Result: exactly one `compute` entry, `compute@@V1`. V3's `Cnt: 2` accounts for
`removed_in_v3` and `vtag` — the repeat of `compute` was **silently dropped**.
No diagnostic. The same script with `compute` in three nodes behaves the same.

### Finding 14 — a version script can only narrow visibility, never widen it

    clang -fPIC -shared -fvisibility=hidden -Wl,--version-script=vmap3 -o lib.so vlib.c
    $ llvm-nm -D --defined-only lib.so
    0000000000000000 A V1@@V1
    0000000000000000 A V2@@V2
    0000000000000000 A V3@@V3

`compute`, `added_in_v2`, `removed_in_v3`, `vtag` are all **absent**. The
script says `global: compute;` and compute is still not exported. Rebuilding
without `-fvisibility=hidden` gives all four, with `@@`/`@` suffixes. So the
`global:` clause filters; it does not confer default visibility.

### Finding 15 — `name@version` is not version-script syntax

    V1 { global: compute@V1; local: *; };
    /usr/bin/ld.bfd:vmap1:1: ignoring invalid character `@' in script
    syntax error in VERSION script

`name@version` / `name@@version` is assembly `.symver` directive syntax. In a
version script you list bare names and the linker decides the default version.
Anyone arriving from `.symver` will get this wrong.

## Module 5 — Linker-defined symbols

### Finding 16 — the classic four, and where they come from

    $ readelf -sW lddef | grep -E ' _end$| __bss_start$| etext$| edata$'
    18: 0000000000004018  0 NOTYPE GLOBAL DEFAULT 25 edata
    29: 0000000000004020  0 NOTYPE GLOBAL DEFAULT 26 _end
    31: 0000000000004018  0 NOTYPE GLOBAL DEFAULT 26 __bss_start
    33: 00000000000011b9  0 NOTYPE GLOBAL DEFAULT 14 etext

They are `NOTYPE`, size **0**, and absent from every input file — the linker
synthesises them. `edata` and `__bss_start` share the address 0x4018 here
because `.bss` begins exactly where `.data` ends, which is the common case and
makes them easy to mistake for one symbol measured twice.

### Finding 17 — `__start_SEC` / `__stop_SEC` are PROTECTED

    $ readelf -sW segmark | grep -E '__start_mysecd|__stop_mysecd'
    24: 0000000000002040  0 NOTYPE GLOBAL PROTECTED 16 __start_mysecd
    25: 0000000000002060  0 NOTYPE GLOBAL PROTECTED 16 __stop_mysecd

    __start=0x2040  __stop=0x2060  count=4   values 10 20 30 40

Exact section bounds, computed by the linker, with no linker script. And they
are **PROTECTED** — which is the correct visibility for a per-output-file
boundary: a second shared object on the command line must not be able to
preempt the first one's `__start_mysecd`.

## Hash tables

### Finding 18 — modern GNU ld emits `.gnu.hash` only

    --hash-style=sysv   .hash
    --hash-style=gnu    .gnu.hash
    --hash-style=both   .hash + .gnu.hash

Default is `gnu`, so `.hash` is absent from a default build. Any course text
that says "the hash table" and then reads `.hash` is describing a build that
`ld` will not produce by default.

### Finding 19 — the hash is of the BASE name, so all versions share a chain

Both `.hash` and `.gnu.hash` hash the symbol name with any `@version` suffix
**stripped**. Verified by reconstructing the SysV chain from
`elf_hash(name) % nbucket` for every entry of a real binary: 6/6 consistent.
Consequence: one chain holds `printf`, `printf@@GLIBC_2.2.5` and any other
version, and the version check happens *after* the name match.

### Finding 20 — `.gnu.hash` bucket heads are NOT in dynsym-index order

Found while writing the decoder's self-checks, and it is counter-intuitive
enough to be worth stating as a finding rather than a footnote.

Each `.gnu.hash` bucket is a **contiguous run of adjacent dynsym indices**; the
low bit of a chain word marks the last member of the run, and the walk is simply
`i, i+1, i+2, ...` until a set bit. The natural next guess — that the *bucket
heads* are therefore sorted, since the runs are laid out per bucket — is
**false**. Measured on six real binaries:

| file | adjacent bucket pairs out of index order |
|------|-----------------------------------------|
| `/bin/ls` | many |
| `libc.so.6` | many |
| `gcc` | many |
| `bash` | many |
| `libm.so.6` | many |

`/bin/ls` with 3 buckets makes it unmistakable: `buckets = [268, 272, 275]`
with `symoffset = 268` is sorted, but `libc.so.6` with 1017 buckets has
`buckets[0] = 2620` and `buckets[1] = 977`. The runs are grouped per bucket;
**the buckets themselves are in hash order, not index order.**

Consequence for a reader: you cannot binary-search a `.gnu.hash` bucket array,
and the fact that a bucket's members are adjacent is a property of the *symbol
order in `.dynsym`*, not of the bucket array.

## Deliberately not claimed

- **Mach-O two-level namespace / interposition rules.** No Mach-O linker on this
  machine. Deferred; the object-file course's measured Mach-O data is the only
  Mach-O material available.
- **A copy-relocation divergence bug.** Attempted three ways (Finding 10); did
  not reproduce. Not claimed.
- **The exact number of `--start-group` iterations.** The map file shows which
  member satisfied which reference, not a pass count. The *fixed-point* claim is
  supported by behaviour (order-independent success), not by a pass counter.
