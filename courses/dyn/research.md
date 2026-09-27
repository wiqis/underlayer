# Dynamic Linking and Shared Libraries — research record

Every finding was **measured on this machine**. The command is given so a reader
can re-run it and, more usefully, disprove it.

## Environment

    ld / ld.bfd        GNU ld (GNU Binutils for Ubuntu) 2.46
    clang              Ubuntu clang 21.1.8
    glibc / ld.so      2.43  (the loader is the subject here)
    readelf, objdump, nm, objcopy   binutils 2.46
    llvm-nm-21, llvm-objdump-21     LLVM 21.1.8
    x86-64 Linux, PIE by default

**The instrument.** `LD_DEBUG=bindings` makes glibc's loader print every symbol
binding it makes, and `LD_DEBUG=libs` prints every library it searches for, in
order. That turns every claim in this course about what the loader *does* into
a measurement rather than a description of the documentation, and it is used as
the oracle that `dynscope.py` tests itself against.

## Scope boundary — what the neighbouring courses already taught

`elf-ld-so` covers the load sequence (map `DT_NEEDED` libraries, process
relocations, call init functions, jump to `_start`) and the search *paths*
(`DT_RPATH`, `LD_LIBRARY_PATH`, `DT_RUNPATH`, `/etc/ld.so.cache`, the default
directories) plus the environment variables. `elf-shared-libraries` covers the
three-level naming — real name, soname, linker name — and the commands that
build one. `elf-dynamic-section` covers the `Elf64_Dyn` TLV array and the main
tags. The symbol-resolution course covers the PLT, the two hash tables,
`GLOB_DAT` vs `COPY`, `-z now` changing no code, and reading a version
definition block.

**None of them covers the scope**, which is the central mechanism: the ordered
list of objects that the loader searches to answer an undefined symbol. The
search *paths* are about finding a file; the scope is about deciding which of
several found files wins. That is a different question, and `LD_PRELOAD` and
interposition appear in those courses as facts to be stated rather than
mechanisms to be understood.

Also entirely absent from the collection, and therefore in this course:
`dlopen` as a mechanism, the `RTLD_*` mode bits, `dlsym`, `-Bsymbolic`, and
building a library as a subject rather than as an input.

## Finding 1 — the loader will tell you what it decided

    $ LD_DEBUG=bindings ./prog 2>&1 | grep lib_value
      binding file ./prog [0] to .../liba.so [0]: normal symbol `lib_value'
      binding file .../libb.so [0] to .../liba.so [0]: normal symbol `lib_value'

One line per binding, naming the referring object and the resolved one. Every
finding below is either this output or a file that this output predicts.

## Finding 2 — interposition reaches *inside* the library

The same binary, plus one definition in the executable:

    $ ./prog    ->  lib_value()=1    mid_value()=11
    $ ./prog2   ->  prog's lib_value()=100   libb's view of it=110

`mid_value()` returns 110, not 11, because `libb.so`'s **own** call to
`lib_value` was bound to the *executable's* definition:

      binding file .../libb.so [0] to ./prog2 [0]: normal symbol `lib_value'

This is the single most important measured fact in the course. A library does
not need to be sloppy, does not need to be shared-object-unsafe, and does not
do anything unusual: it calls a function by name, and the name resolved
somewhere it did not choose. The mechanism is the scope search finding an
earlier match, nothing more.

## Finding 3 — the scope is built breadth-first from `DT_NEEDED`

    order       [libd2.so] [libdeep.so] [libb.so] [liba.so] [libc.so.6]
    libd2.so    [libdeep.so] [libc.so.6]
    libb.so     [liba.so] [libc.so.6]

`libd2.so` needs `libdeep.so` and `libb.so` needs `liba.so`, so the graph is a
tree. And the load order:

    $ LD_DEBUG=libs ./order 2>&1 | grep 'find library'
      libd2.so  libdeep.so  libb.so  liba.so  libc.so.6

`libdeep.so` is loaded **second**, not fourth. Depth-first would have finished
`libdeep.so` and then `liba.so` before reaching `libb.so`; breadth-first takes
every first-level dependency before any second-level one.

## Finding 4 — `-Bsymbolic` is one instruction

A library that defines and calls its own `helper`, and a program that also
defines `helper` in order to interpose:

    plain        entry(2) = 2001     (the program's helper won)
    -Bsymbolic   entry(2) = 7        (the library's own helper won)

The entire difference in the whole library:

    libself.so       callq  0x1030 <helper@plt>     indirect, interposable
    libself_sym.so   callq  0x1100 <helper>         direct, bound at link time

And `.dynsym` is **identical** in both: `entry helper` either way. So
`-Bsymbolic` is purely a binding change and not an export change.

## Finding 5 — `-Bsymbolic` does *not* affect cross-library references

The first attempt at Finding 4 used a library calling a symbol defined in a
*different* library, and `-Bsymbolic` changed nothing at all — identical
disassembly, identical behaviour, still 110. That is correct, and it is the
part the name hides: **it binds references to symbols the library itself
defines.** A cross-library reference has nothing for it to bind. "Bind my
symbols", read precisely, not "bind symbols".

## Finding 6 — `RTLD_LOCAL` is 0, and `dlopen(path, 0)` fails

    RTLD_LOCAL=0x0   RTLD_GLOBAL=0x100   RTLD_LAZY=0x1   RTLD_NOW=0x2

    $ dlopen("./libplug.so", 0)
    ./libplug.so: invalid mode for dlopen(): Invalid argument

The mode must carry `RTLD_LAZY` or `RTLD_NOW`; the scope bit alone is not
enough, and because `RTLD_LOCAL` is zero the mistake looks like a missing
argument rather than a wrong one. `RTLD_LAZY|RTLD_LOCAL` and
`RTLD_LAZY|RTLD_GLOBAL` both work and both resolve `plug_value` to 55.

A `dlopen`'d library is **not** a `DT_NEEDED` entry — the program records only
`libc.so.6` — which is the entire reason for `dlopen` existing.

## Finding 7 — `-z now` changes data layout, and emits no code

    binary     .plt     .got.plt   .got    dyn entries
    ---------  ------   ---------  ------  -----------
    lazy       0x20     0x20       0x28    28
    -z now     0x20     ABSENT     0x48    29

The Symbol Resolution course said "`-z now` changes **no code**". That is
exactly right — the `.plt` is byte-identical — and this is the part that
sentence did not cover: **`.got.plt` disappears entirely**, because with
eager binding its slots are all filled at load time and need no separate home.
They merge into `.got`, which grows from 0x28 to 0x48. The new entries are
`DT_FLAGS` = `BIND_NOW` and the `NOW` bit in `DT_FLAGS_1`.

And the structural point: the loader makes **exactly one** binding for `libfn`
in all three configurations — lazy, `-z now`, and `LD_BIND_NOW=1` on the lazy
binary. Lazy binding defers the same single decision to the first call. It does
not make more decisions.

**No wall-clock claim is made.** A 2,000,000-call microbenchmark gave 5.1, 3.8
and 4.5 ns/call across the three configurations, which is noise. The structural
facts above are exact; the timing is not, and is not taught.

## Finding 8 — `-fvisibility=hidden` hides your API too

    build                        .dynsym
    ---------------------------- ---------------------------------
    default                      calls_all exported_one exported_two
    -fvisibility=hidden          (nothing at all)
    version script, local: *     exported_one@@V1

Both restricted builds are **correct** and both **fail to link** any caller,
because `calls_all` is not in `.dynsym`. The failure is silent until link
time, and the error names a missing symbol rather than the flag that caused it.

The fix is the same in both cases and there is no alternative: mark the API
explicitly.

    -fvisibility=hidden + __attribute__((visibility("default")))
    version script:  V1 { global: exported_one; calls_all; local: *; };

Both then link, run, and produce the correct answer. A version script also
adds `.gnu.version_d` with a `BASE` entry naming the file and a node naming
`V1`.

## Finding 9 — `DT_NEEDED` records names, and `$ORIGIN` is a token

    $ readelf -dW prog | grep -E 'NEEDED|RUNPATH'
      (NEEDED)   Shared library: [libb.so]
      (NEEDED)   Shared library: [liba.so]
      (NEEDED)   Shared library: [libc.so.6]
      (RUNPATH)  Library runpath: [$ORIGIN]

`$ORIGIN` means "the directory this file is in" and is expanded by the loader
at run time, which is what makes the specimens relocatable without an install
step. No library in this directory has a `SONAME`, because nothing set one —
demonstrated by absence, and the reason `-soname` exists: without it a program
records the *file* name, so renaming the file breaks every dependent binary.

## The artifact

`dynscope.py` rebuilds the scope from the files and resolves symbols the way
`ld.so` does, with no loader involved: it reads `DT_NEEDED` out of `.dynamic`,
walks it breadth-first with a real queue, reads each `.dynsym`, and takes the
first match. It then cross-checks itself against `LD_DEBUG=bindings`.

Writing it produced four bugs worth recording, all of them quiet:

1. `e_shstrndx` was read by unpacking **five** half-words at offset 58 and
   assigning the last three. Only three header fields live there, so the last
   two reads ran past the end of the ELF header into the first section header.
   Every string-table lookup then failed.
2. The dedup compared a `DT_NEEDED` *name* against a list of *paths*, so
   `liba.so` entered the scope three times and `libc.so.6` four times.
3. `resolve_path` used an absolute candidate *as* the path instead of joining
   the name, so `$ORIGIN` resolved to a directory and the scope contained
   directories.
4. The first version was a recursive descent, not a queue — which would have
   produced depth-first order and made the artifact an example of the exact
   error the third concept warns about.

## Deliberately not claimed

- **Any performance difference between lazy and eager binding.** See Finding 7.
  The structural facts are exact; a timing claim on this machine would not be.
- **That `RTLD_GLOBAL` changes what `dlsym(h, ...)` returns.** It does not —
  `dlsym` with a handle always searches that object — and the correct claim is
  that the flag changes what enters the *global* scope for *later* lookups.
  The distinction between the two lookup spaces was not measured here.
- **`dlclose` actually unloading anything.** glibc keeps a loaded object
  resident in practice, so "it unloaded" is not a claim this course makes.
- **A comparison with lld or gold.** `-Bsymbolic` is a GNU ld flag; lld spells
  it `-Bsymbolic` too but the symbol-resolution details differ and were not
  compared.
- **Mach-O two-level namespaces.** The object-files course has measured Mach-O
  object files. This course has no Mach-O dyld, so nothing is claimed about
  running Mach-O, only about the ELF loader's scope.
