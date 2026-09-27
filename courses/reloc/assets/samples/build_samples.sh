#!/usr/bin/env bash
# Builds every specimen this course measures. This script is the single source
# of truth: it writes the .c files itself, so they are build products.
#
#   cd courses/reloc/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#
# Requires: clang, ld (GNU bfd 2.46+), readelf, objdump, llvm-objdump-21,
# llvm-nm-21, python3.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}
OD=llvm-objdump-21

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
say "F1 -- the SAME source on two architectures: one relocation or two?"
# ---------------------------------------------------------------------------
cat > v.c <<'EOF'
/* One extern datum per access width, plus a call. */
extern int   g_i;        /* 4 bytes */
extern int  *g_p;        /* 8 bytes */
extern int   g_arr[8];   /* element is 4 bytes */
extern char  g_c;        /* 1 byte */
void sink(int);
int use(void) {
    sink(g_i); sink(*g_p); sink(g_arr[3]); sink(g_c);
    return 0;
}
EOF
$CC -O1 -fno-pic -fno-pie -c v.c -o v_x86.o
$CC -O1 -fno-pic --target=aarch64-linux-gnu -c v.c -o v_arm.o
echo "   x86-64, -fno-pic:"
$OD -r v_x86.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /'
echo "   aarch64, -fno-pic:"
$OD -r v_arm.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /'
echo "   ^ x86-64: ONE relocation per datum.  aarch64: TWO, 4 bytes apart."
echo "   ^ and the aarch64 TYPE encodes the access width: 64 / 32 / 8."

# ---------------------------------------------------------------------------
say "F2 -- the x86-64 vocabulary, grouped by what it computes"
# ---------------------------------------------------------------------------
cat > g.c <<'EOF'
extern int g;
int abs_val(void)   { return g; }              /* value, absolute     */
int *abs_addr(void)  { int *p = &g; return p; }/* address, absolute  */
int rel_val(void)   { return g + 1; }
int call_ext(void);
int do_call(void)   { return call_ext(); }
EOF
for m in "-fno-pic -fno-pie:nopie" "-fPIE:pie" "-fPIC:pic"; do
  fl="${m%%:*}"; n="${m#*:}"
  $CC -O1 $fl -c g.c -o g_$n.o 2>/dev/null
  printf '   %-6s (%s):\n' "$n" "$fl"
  $OD -r g_$n.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' \
    | grep -oE 'R_X86_64_[A-Z0-9_]+' | sort -u | sed 's/^/     /'
done

# ---------------------------------------------------------------------------
say "F3 -- PIE: what the flags actually are"
# ---------------------------------------------------------------------------
printf 'int main(void){return 0;}\n' > tiny.c
for spec in "-fno-pic -fno-pie -no-pie:nopie" \
            "-fno-pic -fno-pie -pie:halfpie" \
            "-fPIE -pie:pie" \
            "-fPIE -no-pie:halfpie2" \
            "-fPIC -shared:picso"; do
  fl="${spec%%:*}"; n="${spec#*:}"
  case "$n" in
    picso) $CC -O1 $fl -o p_$n tiny.c 2>/dev/null ;;
    *)     $CC -O1 $fl -o p_$n tiny.c 2>/dev/null ;;
  esac
  printf '   %-9s %-26s %s\n' "$n" "$fl" "$(readelf -hW p_$n | awk '/Type:/{print $2}')"
done
echo "   ^ a codegen flag and a link flag disagreeing gives a binary that is"
echo "     neither: ET_EXEC, but the compiler emitted PIE-style code."

# ---------------------------------------------------------------------------
say "F4 -- does a PIE actually move? (ASLR, measured)"
# ---------------------------------------------------------------------------
cat > where.c <<'EOF'
#include <stdio.h>
int main(void){ printf("%p\n", (void*)main); return 0; }
EOF
$CC -O1 -o w_pie where.c
$CC -O1 -fno-pie -no-pie -o w_nopie where.c
for f in w_pie w_nopie; do
  printf '   %-8s ' "$f"
  for i in 1 2 3 4 5; do printf '%s ' "$(./$f)"; done
  echo
done
echo "   ^ the PIE base moves every run; the non-PIE address never does."
echo "   Note the low 12 bits are CONSTANT in the PIE case too: ASLR moves"
echo "   the base, and the offset within a page stays a link-time constant."

# ---------------------------------------------------------------------------
say "F5 -- the cost of PIC, in instructions and bytes"
# ---------------------------------------------------------------------------
cat > sum8.c <<'EOF'
extern int a,b,c,d,e,f,g,h;
int f1(void){ return a+b+c+d+e+f+g+h; }
EOF
$CC -O1 -fno-pic -fno-pie -c sum8.c -o s_nopie.o
$CC -O1 -fPIC          -c sum8.c -o s_pic.o
echo "   non-PIC f1:"
$OD -d --no-show-raw-insn s_nopie.o | sed -n '/<f1>:/,/ret/p' | sed 's/^/     /'
echo "   PIC f1 (first 8 lines):"
$OD -d --no-show-raw-insn s_pic.o | sed -n '/<f1>:/,/ret/p' | head -8 | sed 's/^/     /'
# count INSTRUCTIONS only: the "<f1>:" header line is not one
printf '   instruction counts: non-pic=%s  pic=%s\n' \
  "$($OD -d s_nopie.o | sed -n '/<f1>:/,/ret/p' | grep -cE '^ +[0-9a-f]+:')" \
  "$($OD -d s_pic.o    | sed -n '/<f1>:/,/ret/p' | grep -cE '^ +[0-9a-f]+:')"
$CC -O1 -fPIC -shared -o s_pic.so sum8.c 2>/dev/null
printf '   .got in the PIC .so: %s bytes\n' \
  "$(readelf -SW s_pic.so | awk '/ \.got /{print $6}')"

# ---------------------------------------------------------------------------
say "F6 -- the relocation that must CALL the loader: TLS"
# ---------------------------------------------------------------------------
# TWO specimens, and the difference between them is the whole concept.
#
#   tls.c   both thread-locals are `extern`  -> they live in ANOTHER module
#   tls2.c  one is `extern`, one is `static` -> the static one lives HERE
#
# Only the second file can distinguish local-dynamic from initial-exec, because
# local-dynamic requires the symbol to be in the same module.
#
# -O0 is deliberate. At -O1 a `static __thread int my_tls = 7;` read folds to
# the constant 7, the memory access vanishes, and the TLSLD relocation vanishes
# with it. (Measured: that was the first version of this test, and it produced
# a wrong conclusion about local-dynamic. This note is why.)
cat > tls.c <<'EOF'
extern __thread int tls_i;
__thread int tls_def = 5;
int rd_explicit(void){ return tls_i; }
int rd_default(void){ return tls_def; }
EOF
echo "  (a) both symbols extern -- the only case that needs a loader call:"
for m in "-fPIC:-fPIC" \
         "-fPIE:-fPIE" \
         "-ftls-model=local-dynamic:local-dynamic" \
         "-ftls-model=initial-exec:initial-exec"; do
  fl="${m%%:*}"; n="${m#*:}"
  rm -f t.o; $CC -O0 $fl -c tls.c -o t.o 2>/dev/null
  printf '      %-18s ' "$n"
  $OD -r t.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' \
    | grep -oE 'R_X86_64_[A-Z0-9_]+' | sort -u | tr '\n' ' '
  echo
done

cat > tls2.c <<'EOF'
extern __thread int ext_tls;      /* another module */
static __thread int my_tls;       /* THIS module -- LD is possible here */
int rd_ext(void){ return ext_tls; }
int rd_mine(void){ return my_tls; }
EOF
echo "  (b) one extern, one module-local -- now the four models separate:"
for m in "-fPIC:-fPIC" \
         "-fPIE:-fPIE" \
         "-ftls-model=local-dynamic:local-dynamic" \
         "-ftls-model=initial-exec:initial-exec" \
         "-ftls-model=local-exec:local-exec"; do
  fl="${m%%:*}"; n="${m#*:}"
  rm -f y.o; $CC -O0 $fl -c tls2.c -o y.o 2>/dev/null
  printf '      %-18s ' "$n"
  $OD -r y.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' \
    | grep -oE 'R_X86_64_[A-Z0-9_]+' | sort -u | tr '\n' ' '
  echo
done
echo
echo "  the -fPIC build in full -- note the two DIFFERENT loader calls:"
$CC -O0 -fPIC -c tls2.c -o tls2_pic.o 2>/dev/null
$OD -r tls2_pic.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /'
echo
echo "  ^ TLSGD + PLT32 = general dynamic: ask about the SYMBOL, which is in"
echo "    another module. One call per symbol."
echo "    TLSLD + PLT32 + DTPOFF32 = local dynamic: ask about the MODULE once,"
echo "    then add a module-relative offset. One call for N symbols."
echo "    local-exec needs NO call and NO GOT: TPOFF32 on its own."
echo
echo "  and local-dynamic WITHOUT -fPIC, which is the surprise:"
rm -f y.o; $CC -O0 -ftls-model=local-dynamic -c tls2.c -o y.o 2>/dev/null
$OD -r y.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /'
echo "  ^ the request was OVERRIDDEN: no TLSLD, no call. Without PIC-ness the"
echo "    compiler knows the output is an executable and chooses for it."
echo "    THE FLAG IS A REQUEST; PIC-NESS IS A CONSTRAINT."

# ---------------------------------------------------------------------------
say "F7 -- the PIC violation, and the error that names it"
# ---------------------------------------------------------------------------
cat > vio.c <<'EOF'
extern int ext_data;
static int local_fn(int x){ return x*3; }
int *leak(void){ return &ext_data; }
int call_local(void){ return local_fn(2); }
EOF
$CC -O1 -fno-pic -c vio.c -o vio_nopic.o
$CC -O1 -fPIC    -c vio.c -o vio_pic.o
echo "   the -fno-pic object's relocations:"
$OD -r vio_nopic.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /' | head -4
echo "   the -fPIC object's relocations:"
$OD -r vio_pic.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /' | head -4
echo "   linking the -fno-pic one into a shared library:"
$CC -shared -o libvio.so vio_nopic.o 2>&1 | grep -v '^clang:' | sed 's/^/     /'
echo "   linking the -fPIC one:"
$CC -shared -o libvio_pic.so vio_pic.o 2>&1 | grep -v '^clang:' | sed 's/^/     /'
echo "     (silently succeeds)"

# ---------------------------------------------------------------------------
say "F8 -- instruction encoding limits: why 32-bit forms exist on a 64-bit chip"
# ---------------------------------------------------------------------------
cat > far.c <<'EOF'
extern int target;
int reach(void){ return target; }
EOF
$CC -O1 -fno-pic -fno-pie -c far.c -o far.o
$OD -d far.o | sed -n '/<reach>:/,/ret/p' | sed 's/^/   /'
echo "   ^ no absolute 64-bit addressing exists on x86-64, and the PC-relative"
echo "     displacement is 32 bits signed -- so a single reference has a"
echo "     +/-2GB reach, and anything further needs a stub."

# ---------------------------------------------------------------------------
say "F9 -- a CLOSED object: the specimen for the applier exercise"
# ---------------------------------------------------------------------------
# Every symbol this file references is defined in it, so "apply the
# relocations" has a CHECKABLE answer. Every other specimen in this directory
# references externs, which means the answer depends on a layout the applier
# is not told -- that is what makes them good for measuring and useless for
# building.
#
# volatile: without it, -O1 folds the whole file into a single 16-byte
#   constant load from .rodata.cst16 and there is nothing to apply.
# noinline: without it, `pick` is inlined and the call disappears, taking the
#   only PC-relative relocation with it.
cat > closed.c <<'EOF'
volatile int table[4] = {10, 20, 30, 40};
__attribute__((noinline)) int pick(int i){ return table[i & 3]; }
int sum4(int i){ return pick(i) + table[(i + 1) & 3]; }
EOF
$CC -O1 -fno-pic -fno-pie -c closed.c -o closed.o
echo "   relocations:"
$OD -r closed.o | sed -n '/RELOCATION RECORDS FOR \[.text\]/,/^$/p' | sed 's/^/     /'
echo "   undefined symbols (empty == closed):"
$OD -t closed.o | sed -n '/\*UND\*/p' | sed 's/^/     /'
echo "     (none)"
echo "   the PLT32 field is at 0x14 and the callq opcode is at 0x13:"
$OD -d --no-show-raw-insn closed.o | sed -n '/<sum4>:/,/ret/p' | sed 's/^/     /'
echo "   ^ P is the address of the FIELD (0x14), not of the instruction (0x13)."
echo "     Getting that wrong by one produces a call into the middle of"
echo "     'incl %ebx', which still assembles and still runs."

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
