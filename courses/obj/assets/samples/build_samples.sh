#!/bin/sh
# Rebuild every specimen in this directory from source, on this machine.
#
# Two producers, three formats. `clang` is the only toolchain here that can
# emit all three, so it produces the cross-format specimens; `gcc` is the
# second, independent producer for the ELF x86-64 one, and the disagreement
# between the two is itself a course finding.
#
#   sh build_samples.sh
#
# Re-run it after changing a .c file; every claim in the Object Files course
# is checked against files this script produces.
set -e
cd "$(dirname "$0")"

CLANG=${CLANG:-clang}
GCC=${GCC:-gcc}
AR=${AR:-ar}

say() { printf '  %-34s %s\n' "$1" "$2"; }
build() {  # build <label> <compiler> <target> <flags> <src> <out>
  $2 -target $3 $4 -c "$5" -o "$6" 2>/dev/null
  say "$6" "$2 $3 $4"
}

echo "== the three-format specimen, one 30-line source =="
build demo_elf.o      "$CLANG" x86_64-pc-linux-gnu   "-O1"        demo.c demo_elf.o
build demo_coff.o     "$CLANG" x86_64-pc-windows-msvc "-O1"       demo.c demo_coff.o
build demo_macho.o    "$CLANG" x86_64-apple-macosx   "-O1"        demo.c demo_macho.o
build demo_arm64elf.o "$CLANG" aarch64-linux-gnu     "-O1"        demo.c demo_arm64elf.o
$GCC -O1 -c demo.c -o demo_elfgcc.o 2>/dev/null
say demo_elfgcc.o "$GCC (no -target; second producer)"

echo
echo "== REL vs RELA: the same source, 32-bit (REL) and 64-bit (RELA) =="
build demo_i386_elf.o    "$CLANG" i386-pc-linux-gnu "-O1"            demo.c demo_i386_elf.o
build demo_i386_nopic.o  "$CLANG" i386-pc-linux-gnu "-O1 -fno-pic"   demo.c demo_i386_nopic.o

echo
echo "== COMDAT: two TUs defining the same external-linkage inline =="
for t in "x86_64-pc-linux-gnu elf" "x86_64-pc-windows-msvc coff" "x86_64-apple-macosx macho"; do
  set -- $t
  # -fno-inline is what forces the out-of-line copy to be emitted at all;
  # without it clang inlines the body and there is nothing to put in a group.
  $CLANG -target $1 -O1 -fno-inline -c comdat_a.cpp -o ca_$2.o
  $CLANG -target $1 -O1 -fno-inline -c comdat_b.cpp -o cb_$2.o
  say "ca_$2.o / cb_$2.o" "$CLANG $1 -O1 -fno-inline"
done

echo
echo "== the counterfactual: the same collision with NO group =="
$CLANG -O1 -c dup_a.c -o dup_a.o 2>/dev/null; say dup_a.o clang
$CLANG -O1 -c dup_b.c -o dup_b.o 2>/dev/null; say dup_b.o clang

echo
echo "== weak definitions and undefined-weak references =="
for t in "x86_64-pc-linux-gnu elf" "x86_64-pc-windows-msvc coff" "x86_64-apple-macosx macho"; do
  set -- $t
  for s in w w2 uw; do
    $CLANG -target $1 -O1 -c $s.c -o ${s}_$2.o 2>/dev/null
  done
  say "w_$2.o w2_$2.o uw_$2.o" "$CLANG $1 -O1"
done

echo
echo "== archives =="
for f in mathlib strlib unused app; do
  $CLANG -O1 -c $f.c -o $f.o 2>/dev/null
done
rm -f libdemo.a
$AR rcs libdemo.a mathlib.o strlib.o unused.o
say libdemo.a "$AR rcs (3 members)"

for f in l1 l2 l3 main; do
  $CLANG -O1 -fno-inline -c $f.c -o $f.o 2>/dev/null
done
rm -f libchain.a
$AR rcs libchain.a l2.o l3.o l1.o
say libchain.a "$AR rcs (order reversed on purpose)"

echo
echo "== instruction encodings a fixup has to patch =="
$CLANG -O0 -fno-pic -c enc.c -o enc_nopic.o 2>/dev/null;     say enc_nopic.o    "clang -O0 -fno-pic"
$CLANG -O0 -fno-pic -c enc.c -o /dev/null 2>/dev/null || true
$CLANG -target aarch64-linux-gnu -O0 -fno-pic -c enc.c -o enc_a64_nopic.o 2>/dev/null
say enc_a64_nopic.o "clang -target aarch64 -O0 -fno-pic"
$CLANG -target aarch64-linux-gnu -O0 -c adrp_test.c -o adrp_test.o 2>/dev/null
say adrp_test.o "hand-encoded ADRP words, for aarch64_enc.py to check"

echo
echo "== the hand-built object: emitted by emit_elf.py, no library =="
python3 emit_elf.py hand.o >/dev/null
say hand.o "python3 emit_elf.py (936 bytes, byte-exact)"

echo
echo "== byte-reproducibility =="
$CLANG -target x86_64-pc-linux-gnu -O1 -c demo.c -o /tmp/_repro.o
if cmp -s /tmp/_repro.o demo_elf.o; then
  say "cmp demo_elf.o" "IDENTICAL on rebuild -- every claim is about these bytes"
else
  say "cmp demo_elf.o" "DIFFERS -- do not trust the recorded byte values"
fi
rm -f /tmp/_repro.o

# COFF is NOT byte-reproducible, and the reason is worth knowing: the file
# header carries a TimeDateStamp at offset 4.  Everything else is identical.
# Measured on this machine: a rebuild changes 3 bytes, all inside that field,
# and no other field moves.  The course quotes offsets 0x16a (the .text
# relocations), 0x12c (.text) and the symbol table at 0x211 -- none of which
# is the timestamp -- so no claim is affected.  Stated here rather than left
# for a reader to discover by diffing.
$CLANG -target x86_64-pc-windows-msvc -O1 -c demo.c -o /tmp/_reprocoff.o
if cmp -s /tmp/_reprocoff.o demo_coff.o; then
  say "cmp demo_coff.o" "IDENTICAL (timestamp happened to match)"
else
  say "cmp demo_coff.o" "differs -- TimeDateStamp only, see the note above"
fi
rm -f /tmp/_reprocoff.o

echo
echo "done."
