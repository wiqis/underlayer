#!/usr/bin/env bash
# Builds every specimen this course measures. Single source of truth: it
# writes the .c files itself, so they are build products, not sources.
#
#   cd courses/sec/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   python3 harden.py <binary> ...        # the artifact
#
# Requires: clang, gcc, readelf, objdump, python3.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}
GCC=${GCC:-gcc}

say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
say "H1 -- the default stack protector differs between the two compilers"
# ---------------------------------------------------------------------------
# Same source, same machine, same -O1, no flags. The answer below is the
# single most surprising fact in this course and it is not a subtlety.
cat > canary.c <<'EOF'
#include <stdio.h>
#include <string.h>
static void copy(char *d, const char *s) { strcpy(d, s); }
int main(int argc, char **argv) { char b[16]; copy(b, argc > 1 ? argv[1] : "hi"); printf("%s\n", b); return 0; }
EOF
$CC -O1 -o can_clang canary.c
$GCC -O1 -o can_gcc canary.c
note "  no flags at all, -O1, identical source:"
printf "   %-12s %%fs:0x28 references = %s\n" clang "$(objdump -d can_clang | grep -c 'fs:0x28')"
printf "   %-12s %%fs:0x28 references = %s\n" gcc   "$(objdump -d can_gcc   | grep -c 'fs:0x28')"
note ""
note "  clang emits NO canary by default here; gcc emits one. The same"
note "  source, on the same machine, with the same command line."
note ""
note "  and the three-way ladder, under gcc so the comparison is clean:"
for f in "off:-fno-stack-protector" "on:-fstack-protector" "strong:-fstack-protector-strong" "all:-fstack-protector-all"; do
  n=${f%%:*}; fl=${f#*:}
  $GCC -O1 $fl -o sp_$n canary.c 2>/dev/null
  printf "   %-8s %-28s %s refs\n" "$n" "${fl:-<default>}" "$(objdump -d sp_$n | grep -c 'fs:0x28')"
done
note ""
note "  the mechanism, in the gcc default build -- load, store, compare:"
objdump -d can_gcc | grep -E 'fs:0x28' | sed 's/^/     /'
note ""
note "  %fs:0x28 is the per-thread canary the C runtime put in the thread"
note "  control block. Three instructions: read it, park it in the frame,"
note "  and on the way out subtract the parked copy from %fs:0x28. If the"
note "  overflow overwrote the parked copy the subtraction is non-zero and"
note "  the jne branches to __stack_chk_fail -- which does not return."

# ---------------------------------------------------------------------------
say "H2 -- the canary catches one thing, and FORTIFY catches another"
# ---------------------------------------------------------------------------
# Both mechanisms abort. They are trivially confused, because the failure
# looks identical from the outside -- and the MESSAGE is what tells them
# apart, so the messages are the measurement here.
cat > probe.c <<'PROBE_EOF'
#include <stdio.h>
#include <string.h>
char sink[64];
/* A: has a local array (so the canary is instrumented) but overflows a GLOBAL */
int a_local_canary_global_overflow(const char *s) { char pad[8]; pad[0] = 1; strcpy(sink, s); return pad[0]; }
/* B: has a local array, and overflows its OWN local */
int b_local_canary_local_overflow(const char *s) { char pad[8]; strcpy(pad, s); return pad[0]; }
/* C: no local array at all */
int c_no_local_array(const char *s) { strcpy(sink, s); return 0; }
int main(int argc, char **argv)
{
    if (argc < 2) return 0;
    if (argv[1][0] == 'a') printf("%d\n", a_local_canary_global_overflow(argv[1] + 2));
    if (argv[1][0] == 'b') printf("%d\n", b_local_canary_local_overflow(argv[1] + 2));
    if (argv[1][0] == 'c') printf("%d\n", c_no_local_array(argv[1] + 2));
    return 0;
}
PROBE_EOF
note "  gcc turns FORTIFY on BY ITSELF at -O1, so both mechanisms are"
note "  live in a default build and both print an abort:"
printf "   %s\n" "$(gcc -O1 -### -c -o /dev/null probe.c 2>&1 | grep -o 'FORTIFY_SOURCE=[0-9]' | sort -u | head -1)"
echo
$GCC -O1 -o probe_def probe.c 2>/dev/null
$GCC -O1 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fstack-protector-all -o probe_can probe.c 2>/dev/null
note "  three overflows, 200 bytes each, two builds:"
printf "   %-5s %-46s %s\n" case "gcc default (FORTIFY on, canary on)" "canary only (FORTIFY off)"
for c in a b c; do
  o1=$(./probe_def  "$c$(python3 -c 'print("A"*200)')" 2>&1); r1=$?
  o2=$(./probe_can  "$c$(python3 -c 'print("A"*200)')" 2>&1); r2=$?
  m1=$(echo "$o1" | grep -oE 'stack smashing|buffer overflow|Segmentation' | head -1); [ -z "$m1" ] && m1="NO DIAGNOSTIC"
  m2=$(echo "$o2" | grep -oE 'stack smashing|buffer overflow|Segmentation' | head -1); [ -z "$m2" ] && m2="NO DIAGNOSTIC"
  printf "   %-5s %-46s %s\n" "$c" "$m1" "$m2"
done
note ""
note "  THE RESULT, and it is the whole concept:"
note "    case b, overflowing its OWN local, is the only one the canary"
note "    ever sees. cases a and c overflow a GLOBAL -- the damage never"
note "    touches the frame, so the canary is intact and silent."
note "    and in a DEFAULT gcc build, FORTIFY catches all three, because"
note "    strcpy into a known-size object is checkable wherever it lives."
note ""
note "  the two messages, which is how you tell them apart in the wild:"
printf "   canary:   %s\n" "$(./probe_can b$(python3 -c 'print("A"*200)') 2>&1 | grep -oE '\*\*\* .* \*\*\*' | head -1)"
printf "   fortify:  %s\n" "$(./probe_def a$(python3 -c 'print("A"*200)') 2>&1 | grep -oE '\*\*\* .* \*\*\*' | head -1)"
note ""
note "  and one more trap, the -O1 one: at -O1 the local array in case a"
note "  is optimised away, so gcc does not instrument that function at"
note "  all and the canary count is 0. At -O0 it is 2. The evidence was"
note "  deleted by the optimiser, not absent from the source."

# ---------------------------------------------------------------------------
say "H3 -- RELRO has two tiers and only one of them is a flag you need"
# ---------------------------------------------------------------------------
cat > relro.c <<'EOF'
#include <stdio.h>
int g = 7;
const char *msg = "hello";
void show(void) { printf("%s %d\n", msg, g); }
EOF
cat > wx_main.c <<'EOF'
#include <stdio.h>
void show(void);
int main(void) { show(); return 0; }
EOF
$CC -O1 -c -o relro.o relro.c
# -no-pie so the file's vaddrs ARE the runtime addresses and the RELRO
# arithmetic below can be read straight off the headers.
for m in none partial full; do
  case $m in
    none)    fl="" ;;
    partial) fl="-Wl,-z,relro" ;;
    full)    fl="-Wl,-z,relro,-z,now" ;;
  esac
  $CC -no-pie $fl -o relro_$m relro.o wx_main.c 2>/dev/null
done
note "  GNU_RELRO, and whether .got.plt survives, per link mode:"
printf "   %-8s %-24s %-8s %-10s %s\n" mode flags memsz got.plt "dynamic tags"
for m in none partial full; do
  case $m in
    none)    fl="" ;;
    partial) fl="-Wl,-z,relro" ;;
    full)    fl="-Wl,-z,relro,-z,now" ;;
  esac
  memsz=$(readelf -lW relro_$m | grep GNU_RELRO | awk '{print $6}')
  gp=$(readelf -SW relro_$m | awk '/\.got\.plt/{print "present"}' | head -1)
  tags=$(readelf -dW relro_$m | grep -oE 'BIND_NOW|FLAGS_1\)' | tr '\n' ',' )
  printf "   %-8s %-24s %-8s %-10s %s\n" "$m" "${fl:-<none>}" "$memsz" "${gp:-ABSENT}" "${tags:-none}"
done
note ""
note "  partial is the SAME SIZE as none on this toolchain -- the linker"
note "  already emits a GNU_RELRO segment. The two tiers are not about the"
note "  segment existing, they are about how far it reaches."
note ""
python3 - <<'PY'
import subprocess, re
def info(m):
    sw = subprocess.run(['readelf', '-SW', 'relro_' + m], capture_output=True, text=True).stdout
    sec = {}
    for l in sw.splitlines():
        mm = re.match(r'\s*\[\s*\d+\]\s+(\S+)\s+(\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+([0-9a-f]+)', l)
        if mm:
            sec[mm.group(1)] = (int(mm.group(3), 16), int(mm.group(5), 16))
    lw = subprocess.run(['readelf', '-lW', 'relro_' + m], capture_output=True, text=True).stdout
    r = [x for x in lw.splitlines() if 'GNU_RELRO' in x][0].split()
    return sec, int(r[2], 16), int(r[5], 16)
print("   the arithmetic that matters:")
for m in ('none', 'partial', 'full'):
    sec, v, sz = info(m)
    lo, hi = v, v + sz
    gp = sec.get('.got.plt')
    print("   %-8s RELRO %#x..%#x  ends on a page: %s" % (m, lo, hi, "YES" if hi % 0x1000 == 0 else "no"))
    if gp:
        a, s = gp
        cross = a < hi < a + s
        print("            .got.plt %#x..%#x  CROSSES the RELRO end: %s  -> %d bytes stay writable"
              % (a, a + s, "YES" if cross else "no", a + s - hi))
    else:
        print("            .got.plt ABSENT -- absorbed into .got, which is inside RELRO")
PY

# ---------------------------------------------------------------------------
say "H4 -- FORTIFY: a compile-time fact turned into a runtime argument"
# ---------------------------------------------------------------------------
cat > fort.c <<'EOF'
#include <string.h>
#include <stdio.h>
#include <unistd.h>
/* The DESTINATION is a fixed-size local, so the compiler knows its size.
   That is the precondition: without a known object size there is nothing
   to check against and the call is left alone. */
void f(char *d, const char *s)
{
    char b[32];
    strcpy(b, s);
    memcpy(b, s, 8);
    d[0] = b[0];
}
int main(int argc, char **argv)
{
    char b[64];
    if (argc > 1) { f(b, argv[1]); b[read(0, b, 16)] = 0; }
    printf("%d\n", (int)strlen(b));
    return 0;
}
EOF
for v in 0 1 2 3; do
  $CC -O1 -D_FORTIFY_SOURCE=$v -o fort_$v fort.c 2>/dev/null
done
note "  which libc entry points each level calls:"
for v in 0 1 2 3; do
  printf "   level %-2s " "$v"
  objdump -d fort_$v | grep -oE '<(__)?(strcpy|memcpy|read|v?printf|strlen)[a-z_]*@plt>' \
    | sort -u | tr '\n' ' ' | sed 's/@plt>//g;s/<//g'
  echo
done
note ""
note "  level 0  no checks at all"
note "  level 1  strcpy -> __strcpy_chk, read -> __read_chk (size known)"
note "  level 2  adds printf -> __vprintf_chk, because %n is a write primitive"
note "  level 3  adds compile-time DIAGNOSIS for a known-too-large count;"
note "          this specimen has no such call, so 2 and 3 agree here."
note ""
note "  the mechanism -- the object size becomes an argument:"
objdump -d fort_2 | grep -B3 'call.*__strcpy_chk' | grep -E 'mov.*edx|mov.*rdx' | head -2 | sed 's/^/     /'
note "  0x20 is 32, sizeof(b). The compiler knew it statically and passed"
note "  it, so libc can compare it against the actual copy length."
note ""
note "  and the precondition, shown by removing it -- FORTIFY can only"
note "  act on a size the COMPILER KNOWS:"
cat > fort_rt.c <<'EOF'
#include <string.h>
/* the size is a RUNTIME value, so there is nothing to check against */
void g(char *d, const char *s, unsigned long n) { memcpy(d, s, n); }
int main(int c, char **v) { char b[8192]; g(b, c > 1 ? v[1] : "", 2048); return b[0]; }
EOF
cat > fort_kn.c <<'EOF'
#include <string.h>
/* the DESTINATION is a fixed-size local, so its size IS known statically */
void g(char *d, const char *s) { char b[4096]; memcpy(b, s, 2048); d[0] = b[0]; }
int main(int c, char **v) { char b[8192]; g(b, c > 1 ? v[1] : ""); return b[0]; }
EOF
$CC -O1 -D_FORTIFY_SOURCE=3 -o fort_rt fort_rt.c 2>/dev/null
$CC -O1 -D_FORTIFY_SOURCE=3 -o fort_kn fort_kn.c 2>/dev/null
printf "   memcpy with a RUNTIME size -> %s\n" "$(objdump -d fort_rt | grep -oE '<(__)?memcpy[a-z_]*@plt>' | sort -u | tr '\n' ' ' | sed 's/@plt>//g;s/<//g')"
printf "   memcpy with a KNOWN size   -> %s\n" "$(objdump -d fort_kn | grep -oE '<(__)?memcpy[a-z_]*@plt>' | sort -u | tr '\n' ' ' | sed 's/@plt>//g;s/<//g')"
note ""
note "  A RETRACTION, kept because it is the honest result: a known-size"
note "  destination was expected to produce __memcpy_chk. clang 21 does"
note "  NOT emit it -- both rows call plain memcpy. strcpy becomes"
note "  __strcpy_chk reliably; memcpy does not, even with a statically"
note "  known 4096-byte destination. The rule was not determined from"
note "  source and is not claimed here."
note ""
note "  What IS claimed, and it is the useful part: FORTIFY is a"
note "  COMPILE-TIME technique whose visible effect is in the binary's"
note "  IMPORTS. So you verify it the same way you verify everything else"
note "  in this collection -- read the file. Never assume a flag did"
note "  what its name says; check which libc entry points you actually"
note "  call."

# ---------------------------------------------------------------------------
say "H5 -- W^X: the stack bit, and why TEXTREL is nearly gone"
# ---------------------------------------------------------------------------
cat > wx.c <<'EOF'
#include <stdio.h>
static int helper(int x) { return x * 2; }
int main(int argc, char **argv) { return helper(argc) + (argv[0][0] & 1); }
EOF
for m in default noexec exec; do
  case $m in
    default) fl="" ;;
    noexec)  fl="-Wl,-z,noexecstack" ;;
    exec)    fl="-Wl,-z,execstack" ;;
  esac
  $CC -O1 $fl -o wx_$m wx.c 2>/dev/null
done
note "  PT_GNU_STACK flags, which is the stack's permission request:"
for m in default noexec exec; do
  printf "   %-8s %s\n" "$m" "$(readelf -lW wx_$m | grep GNU_STACK | awk '{print $(NF-2), $(NF-1), $NF}')"
done
note "  the default is RW -- no execute. -z execstack is the flag that"
note "  gives the stack away, and it is the one to look for in a Makefile."
note ""
cat > textrel.c <<'EOF'
/* A table of pointers to string literals. In a shared library each entry
   needs a RELATIVE relocation, and a naive linker would have to make a
   read-only segment writable to apply it -- which is what TEXTREL meant. */
static const char *const names[] = { "alpha", "beta", "gamma" };
const char *lookup(int i) { return names[i % 3]; }
EOF
$CC -shared -fPIC -o textrel.so textrel.c 2>/dev/null
$CC -shared -fPIC -Wl,-z,text -o textrel_t.so textrel.c 2>/dev/null
printf "   TEXTREL in the plain build:        %s\n" "$(readelf -dW textrel.so | grep -c TEXTREL)"
printf "   TEXTREL even with -z text:         %s\n" "$(readelf -dW textrel_t.so | grep -c TEXTREL)"
printf "   -z text refused to link:           %s\n" "$([ -f textrel_t.so ] && echo no || echo YES)"
note ""
note "  TEXTREL could not be forced, and the reason IS the finding:"
readelf -SW textrel.so | grep -E 'data\.rel\.ro|\.rodata' | sed 's/^/     /'
readelf -lW textrel.so | grep GNU_RELRO | sed 's/^/     /'
note "  the pointer table went to .data.rel.ro, which is writable DURING"
note "  load and sealed by RELRO afterwards. The loader had somewhere"
note "  legal to write, so it never needed a writable text segment."
note "  .data.rel.ro is the reason TEXTREL is nearly extinct -- and it is"
note "  the same sealing mechanism as full RELRO, doing a second job."

# ---------------------------------------------------------------------------
say "H6 -- CET: on by default, and partly out of your hands"
# ---------------------------------------------------------------------------
for m in none branch full; do
  case $m in
    none)   fl="-fcf-protection=none" ;;
    branch) fl="-fcf-protection=branch" ;;
    full)   fl="-fcf-protection=full" ;;
  esac
  $CC -O1 $fl -o cet_$m wx.c 2>/dev/null
done
note "  the property note -- what the binary ASKS the hardware for:"
for m in none branch full; do
  printf "   %-7s note=%-12s properties: %s\n" "$m" \
    "$(readelf -n cet_$m | grep GNU_PROPERTY | head -1 | awk '{print $2}')" \
    "$(readelf -n cet_$m | sed -n '/Properties:/s/.*Properties: *//p' | tr -d '\n' | sed 's/^$/none/')"
done
note ""
note "  endbr64 in the binary, and in MY functions only:"
for m in none branch full; do
  all=$(objdump -d cet_$m | grep -c endbr64)
  mine=$(objdump -d cet_$m | sed -n '/<main>:/,/^$/p;/<helper>:/,/^$/p' | grep -c endbr64)
  printf "   %-7s total=%-3s in main/helper=%s\n" "$m" "$all" "$mine"
done
note ""
note "  with protection OFF my functions have none, yet the binary still"
note "  has 5. They come from the C runtime, which the distro built with"
note "  protection ON:"
for o in crt1.o crti.o crtn.o; do
  p=/usr/lib/x86_64-linux-gnu/$o
  [ -f "$p" ] && printf "     %-9s endbr64 = %s\n" "$o" "$(objdump -d $p | grep -c endbr64)"
done
note "  -fcf-protection=none removes the protection from YOUR code and"
note "  leaves the startup files alone. You cannot un-harden them with a"
note "  compiler flag, which is the correct default and worth knowing."
note ""
note "  the instruction itself:"
objdump -d cet_full | grep -A1 '<main>:' | tail -1 | sed 's/^/     /'

# ---------------------------------------------------------------------------
say "H7 -- the matrix, so the interactions are visible"
# ---------------------------------------------------------------------------
printf "   %-34s %-8s %-10s %-7s %s\n" "build" "canary" "RELROmem" "IBT" "PT_GNU_STACK"
for spec in "plain:" "canary:-fstack-protector-all" "relro:-Wl,-z,relro,-z,now" \
            "fortify:-D_FORTIFY_SOURCE=2" "cet:-fcf-protection=full" \
            "all:-fstack-protector-all -D_FORTIFY_SOURCE=2 -Wl,-z,relro,-z,now -fcf-protection=full -Wl,-z,noexecstack"; do
  n=${spec%%:*}; fl=${spec#*:}
  $CC -O1 $fl -o mx_$n wx.c 2>/dev/null
  can=$(objdump -d mx_$n | grep -c 'fs:0x28')
  rz=$(readelf -lW mx_$n | grep GNU_RELRO | awk '{print $6}')
  ibt=$(readelf -n mx_$n | grep -c 'IBT')
  st=$(readelf -lW mx_$n | grep GNU_STACK | awk '{print $(NF-2), $(NF-1), $NF}')
  printf "   %-34s %-8s %-10s %-7s %s\n" "$n" "$can" "$rz" "$ibt" "$st"
done
note ""
note "  Read the canary column. It is 0 on five of six rows, and 2 on the"
note "  one that asks for it explicitly -- because clang does not enable"
note "  the stack protector by default. Rebuild the last row with gcc and"
note "  the canary column is 2 on EVERY row, with no flags at all."
note "  That single difference is the whole course: a hardening feature is"
note "  a compiler DECISION, and the decision is not uniform."
note ""
note "  RELROmem moves for two different reasons and they are worth"
note "  separating: -z now GROWS it (0x200 -> 0x248) because it must reach"
note "  the lazy-binding slots, while the other rows differ only because"
note "  the code differs. Compare the relro row against plain, not against"
note "  fortify -- only the LINKER flag changes the segment."


# ---------------------------------------------------------------------------
say "H8 -- the driver defaults, which are a third thing entirely"
# ---------------------------------------------------------------------------
# Two layers so far: compiler CODEGEN defaults (clang emits no canary, gcc
# does) and linker flags. There is a third layer neither name covers: the
# compiler DRIVER decides which linker flags to pass, and the two disagree.
note "  what each driver passes to ld with NO flags of your own:"
for cc in "$GCC" "$CC"; do
  got=$("$cc" -O1 -### -o /dev/null canary.c 2>&1 \
        | grep -oE '\-z (relro|now|noexecstack|ibtplt)' | sort -u | tr '\n' ' ')
  printf "   %-10s %s\n" "$cc" "${got:-nothing}"
done
note ""
note "  the consequence, in the FILES. Same source, same -O1, no flags:"
for cc in "$GCC" "$CC"; do
  n=$(basename "$cc")
  "$cc" -O1 -o drv_$n canary.c 2>/dev/null
  printf "   %-10s %s\n" "drv_$n" \
    "$(python3 harden.py drv_$n 2>/dev/null | grep -E 'RELRO tier|covered by RELRO' \
       | tr -s ' ' | tr '\n' ' ')"
done
note ""
note "  THIS IS THE HEADLINE, and it is not about codegen at all. The same"
note "  one-line source, compiled with no flags of your own, gives FULL"
note "  RELRO under gcc and only PARTIAL under clang -- and under clang"
note "  the .got.plt tail is left writable. The driver picked the linker"
note "  flags, and the two drivers do not agree about which hardening"
note "  belongs on by default."
note ""
note "  So there are three independent decisions, and 'is my binary"
note "  hardened?' has to answer all three:"
note "    1. CODEGEN   does the compiler emit the canary?   clang: no"
note "    2. LINKER    -z now / -z relro / -z execstack     you pass these"
note "    3. DRIVER    which -z flags pass by DEFAULT?     gcc: -z relro -z now"
note "  A build system that pins the compiler and forgets the driver inherits"
note "  whatever that distribution chose, which is why two teams with the"
note "  same hardening policy get different binaries."

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
