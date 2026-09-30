#!/bin/sh
# build_samples.sh -- assemble everything courses/a64sys/assets/samples needs.
#
# It is `#!/bin/sh` and it is POSIX on purpose.  The previous course in this
# section lost an afternoon to a python heredoc inside a `$( )` substitution:
# a POSIX shell reads a heredoc body starting on the line AFTER the `<<`, so
# the body swallowed the rest of the script, the line that should have printed
# a section size printed it four times with a zero exit status, and nothing
# errored.  A build script that cannot fail is worse than no build script,
# because it is a build script that lies.
#
# Every step here is a COMPILE step.  Nothing links and nothing runs, because
# there is no AArch64 linker and no AArch64 machine on this host.
set -e

D=$(dirname "$0")
cd "$D"

T=aarch64-linux-gnu

for L in O0 O1 O2 Os; do
	clang --target=$T -S -$L sys.c -o sys_$L.s
	clang --target=$T -c -$L sys.c -o sys_$L.o
done

clang --target=$T -c vec.s -o vec.o
clang --target=$T -c rel.s -o rel.o

# the same C with the 2 MiB page table removed, so section 8 can print the
# alignment of `.bss` with and without it.  A small python filter rather than
# a `sed` script, because a multi-line `sed` s/// containing `\[0\]` needs
# three levels of escaping and the third is where a build script stops being
# readable.
python3 - <<'PY'
import re
src = open('sys.c').read()
for pat in (r'^static unsigned long l2_big.*\n',
            r'^    l2_big\[0\].*\n',
            r'^unsigned long \*ref_l2_big.*\n',
            r'^unsigned long  big0.*\n'):
    src = re.sub(pat, '', src, flags=re.M)
open('_sys_no2m.c', 'w').write(src)
PY
clang --target=$T -c -O2 _sys_no2m.c -o _no2m.o
rm -f _sys_no2m.c

echo "samples built: $(ls sys_*.s sys_*.o vec.o rel.o _no2m.o | wc -l) files"
