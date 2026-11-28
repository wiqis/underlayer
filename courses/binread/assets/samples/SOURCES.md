# E6 specimen provenance — binread (2026-11-28)

This course authors **no new byte, offset or format claim**. Every number in its
four lessons is read from the `readelf_*.txt` files in this directory, and those
files were captured by running the local `readelf` against specimens copied
byte-for-byte from the already-verified ELF corpus.

- Copied from `courses/elf/assets/samples/`: `types_O0`, `cbbench`.
- **Toolchain contract:** compiler-toolchain (declared in
  `binread-specimen.json`). The producer versions are inherited, recorded as
  gcc 15.2.0 / clang 21.1.8 / binutils (readelf) 2.46 from
  `courses/elf/assets/samples/SOURCES.md`; they were NOT measured here and no
  new version was invented to satisfy the specimen checker.
- The local reader used to capture the evidence is GNU readelf 2.39
  (`readelf.exe (GNU Binutils) 2.39`). It is a reader, not the producer, and is
  recorded separately as `reader_readelf` in `binread-specimen.json`.
- Captured commands: `readelf -h`, `readelf -lW`, `readelf -SW`, `readelf -sW`.
- SHA-256 values are in `binread-specimen.json`.

Not checked: execution of any specimen on this Windows host, platform ABI
behaviour, and any claim not present in the captured readelf output. The paid
course is a **first module** (four concepts), not a full course; its limitations
are recorded in `courses/binread/manifest.json`.
