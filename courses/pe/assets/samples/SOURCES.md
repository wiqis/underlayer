# I5 specimen provenance — pe (2026-11-27)

Every file below was copied byte-for-byte from an existing, already-verified
course corpus in this repository. No byte, offset or format claim was authored
by this bundle: the claims remain those in the lesson text and in the named
verifier. SHA-256 values are in `pe-specimen.json`.

Producer toolchain recorded by the source course:
clang 21.1.8 (--target=x86_64-pc-windows-msvc, x86_64-w64-windows-gnu, i686-pc-windows-msvc), LLVM 21.1.8 llvm-readobj/llvm-objdump (courses/coff/research.md)

Verification performed 2026-11-27: format magic read directly from the copied
bytes; SHA-256 computed with Python hashlib over the copied bytes. Not checked:
execution of any specimen, platform ABI behaviour beyond the source course's
own verifier, and any new claim about a byte or field. The local Windows host
has gcc 13.2.0 / GNU readelf 2.39; those are NOT the producers and were not
used to make a format claim.

Source files:
- `courses/coff/assets/samples/comdat_linked.exe`
- `courses/coff/assets/samples/directive_used.exe`
- `courses/coff/assets/samples/link_prog.exe`
- `courses/coff/assets/samples/sample_msvc.obj`
- `courses/coff/assets/samples/sample_gnu.obj`
- `courses/coff/assets/samples/sample_m32.obj`
- `courses/coff/assets/samples/comdat.obj`
- `courses/coff/assets/samples/coff_parse.py`
- `courses/coff/assets/samples/crosscheck.py`
