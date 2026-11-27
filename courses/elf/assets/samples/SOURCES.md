# I5 specimen provenance — elf (2026-11-27)

Every file below was copied byte-for-byte from an existing, already-verified
course corpus in this repository. No byte, offset or format claim was authored
by this bundle: the claims remain those in the lesson text and in the named
verifier. SHA-256 values are in `elf-specimen.json`.

Producer toolchain recorded by the source course:
clang 21.1.8 and gcc 15.2.0, binutils/readelf 2.46 (courses/obj/research.md, courses/compback/research.md, courses/dwarf/research.md)

Verification performed 2026-11-27: format magic read directly from the copied
bytes; SHA-256 computed with Python hashlib over the copied bytes. Not checked:
execution of any specimen, platform ABI behaviour beyond the source course's
own verifier, and any new claim about a byte or field. The local Windows host
has gcc 13.2.0 / GNU readelf 2.39; those are NOT the producers and were not
used to make a format claim.

Source files:
- `courses/obj/assets/samples/demo_elf.o`
- `courses/obj/assets/samples/demo_elfgcc.o`
- `courses/obj/assets/samples/demo_arm64elf.o`
- `courses/obj/assets/samples/demo_i386_elf.o`
- `courses/obj/assets/samples/emit_elf.py`
- `courses/compback/assets/samples/cbbench`
- `courses/dwarf/assets/samples/types_O0`
