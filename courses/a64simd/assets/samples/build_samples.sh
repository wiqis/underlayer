#!/bin/sh
# build_samples.sh -- assemble everything courses/a64simd/assets/samples needs.
#
# It is `#!/bin/sh` and it is POSIX on purpose, for the reason the machine
# course's script records: a python heredoc inside a `$( )` substitution reads
# its body from the line AFTER the `<<`, swallows the rest of the script, and
# exits 0 while doing nothing.  A build script that cannot fail is worse than
# no build script, because it is a build script that lies.
#
# Every step here is a COMPILE step.  Nothing links and nothing runs: there is
# no AArch64 linker and no AArch64 machine on this host.
set -e

D=$(dirname "$0")
cd "$D"

T=aarch64-linux-gnu

# ---------------------------------------------------------------- data.c
# Four optimisation levels, each to BOTH a .s (so a section can read the
# emitted text) and an .o (so a section can read the CODE SECTION BYTES
# through its own ELF reader).  Both are needed and they are not
# interchangeable: the two-reader cross-check reads the .o, and the
# instruction counts read the .s.
for L in O0 O1 O2 Os; do
	clang --target=$T -S -$L data.c -o data_$L.s
	clang --target=$T -c -$L data.c -o data_$L.o
done

# The same C with the vectoriser switched off, as a TEXT file only.  Section 5
# compares the two builds and the comparison is done on the .s, so there is no
# .o for it and this line is the only asymmetry in the loop above.
clang --target=$T -S -O2 -fno-vectorize data.c -o data_O2_novec.s

# ---------------------------------------------------------------- pair.c
# THE 16-BYTE CASE, AT BOTH FEATURE LEVELS, AND BOTH TO AN .o.
#
# The .o matters here and the omission of it was retraction R22's hiding place.
# For most of this file's life `pair_base.s` was built and `pair_base.o` was
# NOT, so the exclusive-PAIR path -- `ldaxp` and `stlxp`, the two instructions
# concept 3 is named for -- appeared in the disassembly that a reader sees and
# in NO object file that the two-reader pass reads.  `m_lse` was consequently
# free to read 0xc87fa009 as `caspal x31` for a whole draft, and the coverage
# number could not see it: the number was about a corpus, and the instruction
# was not in the corpus.
#
# A COVERAGE FIGURE IS A NUMBER ABOUT WHAT WAS FED TO IT, and "we covered
# everything" is a statement about the pipeline rather than about the
# decoder.  Every build in this script therefore produces BOTH artefacts
# unless it says why not, and the one that does not is the no-vectorise
# comparison above, which is read as text.
clang --target=$T -S -O2 pair.c -o pair_base.s
clang --target=$T -c -O2 pair.c -o pair_base.o

# With FEAT_LSE.  The four suffix-free forms (`casp`, `caspal`) are refused at
# the baseline with "instruction requires: lse" and that refusal IS the
# measurement, so the baseline build above is not a spare copy of this one.
clang --target=$T -S -O2 -march=armv8.1-a pair.c -o pair_lse.s
clang --target=$T -c -O2 -march=armv8.1-a pair.c -o pair_lse.o

echo "samples built: $(ls data_*.s data_*.o pair_*.s pair_*.o | wc -l) files"
