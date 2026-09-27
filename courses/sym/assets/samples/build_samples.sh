#!/usr/bin/env bash
# Builds every specimen this course measures, and prints the observation each
# one exists to produce. Run it and read the output: the course text quotes
# these numbers, and this script is where they come from.
#
#   cd courses/sym/assets/samples && ./build_samples.sh
#
# This script is the single source of truth. It writes the .c files itself, so
# they are build products rather than sources and are not tracked in git --
# keeping copies would only create a chance for them to drift apart.
#
# Requires: clang, ld (GNU bfd 2.46+), readelf, objdump, llvm-nm-21, ar, python3.
# Everything lands in this directory; nothing is installed.

set -u
cd "$(dirname "$0")"

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
CC=${CC:-clang}

# ---------------------------------------------------------------------------
say "Finding 1/2 -- hidden and internal DEMOTE the binding; protected does not"
# ---------------------------------------------------------------------------
cat > vis.c <<'EOF'
/* One function and one datum at each of the four visibilities.
   The point is that three of the four are invisible in the finished object. */
int          def_fn(int x) { return x + 1; }
__attribute__((visibility("hidden")))    int hid_fn(int x)  { return x + 2; }
__attribute__((visibility("protected"))) int prot_fn(int x) { return x + 3; }
__attribute__((visibility("internal")))  int int_fn(int x)  { return x + 4; }

int          def_data = 1;
__attribute__((visibility("hidden")))    int hid_data = 2;
EOF
$CC -O1 -fPIC -shared -o libvis.so vis.c
printf '   $ llvm-nm-21 libvis.so   (uppercase = GLOBAL, lowercase = LOCAL)\n'
llvm-nm-21 libvis.so | grep -E ' (def_fn|hid_fn|prot_fn|int_fn|def_data|hid_data)$' | sed 's/^/   /'
printf '   -- and in .dynsym? --\n'
printf '   default + protected : %s of 3\n' \
  "$(readelf --dyn-syms -W libvis.so | grep -cE ' (def_fn|prot_fn|def_data)$')"
printf '   hidden + internal   : %s of 3   <- expect 0\n' \
  "$(readelf --dyn-syms -W libvis.so | grep -cE ' (hid_fn|int_fn|hid_data)$')"

# ---------------------------------------------------------------------------
say "Finding 3 -- two strong definitions: the message depends on link order"
# ---------------------------------------------------------------------------
printf 'int dup(void){return 1;}\n' > dup_a.c
printf 'int dup(void){return 2;}\n' > dup_b.c
printf 'int dup(void); int main(void){return dup();}\n' > dup_m.c
$CC -c dup_a.c -o dup_a.o; $CC -c dup_b.c -o dup_b.o; $CC -c dup_m.c -o dup_m.o
printf '   $ clang -o t dup_a.o dup_b.o dup_m.o\n'
$CC -o /dev/null dup_a.o dup_b.o dup_m.o 2>&1 | grep -E 'multiple|first defined' | sed 's/^/   /'
printf '   $ clang -o t dup_b.o dup_a.o dup_m.o\n'
$CC -o /dev/null dup_b.o dup_a.o dup_m.o 2>&1 | grep -E 'multiple|first defined' | sed 's/^/   /'
printf '   ^ same defect, different text: "first defined here" means first on\n'
printf '     the COMMAND LINE, so never read it as a priority.\n'

# ---------------------------------------------------------------------------
say "Finding 5 -- COMMON: the same three files link or fail on one flag"
# ---------------------------------------------------------------------------
printf 'int cvar;\n'                 > tent_x.c
printf 'int cvar;\n'                 > tent_y.c
printf 'int cvar = 5; int main(void){return cvar;}\n' > tent_z.c
for f in tent_x tent_y tent_z; do $CC -fcommon -c $f.c -o $f.o; done
printf '   -fcommon  ->  SHN_COMMON (an unallocated run in .bss):\n'
readelf -sW tent_x.o | grep ' cvar$' | sed 's/^/   /'
printf '   $ clang -o t tent_x.o tent_y.o tent_z.o && ./t\n'
$CC -o tent_com tent_x.o tent_y.o tent_z.o 2>&1 | sed 's/^/   /' && ./tent_com; echo "   exit=$? (expect 5)"
for f in tent_x tent_y tent_z; do $CC -fno-common -c $f.c -o ${f}n.o; done
printf '   -fno-common  ->  a real .bss definition, so it now COLLIDES:\n'
readelf -sW tent_xn.o | grep ' cvar$' | sed 's/^/   /'
printf '   $ clang -o t tent_xn.o tent_yn.o tent_zn.o\n'
$CC -o /dev/null tent_xn.o tent_yn.o tent_zn.o 2>&1 | grep -E 'multiple' | sed 's/^/   /'

# ---------------------------------------------------------------------------
say "Finding 6 -- archive extraction is demand-driven, one pass, left to right"
# ---------------------------------------------------------------------------
# Mutual reference WITHOUT recursion: a_fn reads b_data, b_fn reads a_data.
printf 'extern int b_data; int a_fn(void){ return 1 + b_data; }\n' > ma.c
printf 'int a_data = 10;\n'                                        > da.c
printf 'extern int a_data; int b_fn(void){ return 2 + a_data; }\n' > mb.c
printf 'int b_data = 20;\n'                                        > db.c
printf 'extern int a_fn(void); int main(void){ return a_fn(); }\n' > mu.c
for f in ma da mb db mu; do $CC -c $f.c -o $f.o; done
$CC -fPIC -c da.c -o da_pic.o; $CC -fPIC -c db.c -o db_pic.o
ar rcs libMA.a ma.o da_pic.o
ar rcs libMB.a mb.o db_pic.o
printf '   $ clang -o t mu.o libMA.a libMB.a          # right order\n'
$CC -o ord_ok mu.o libMA.a libMB.a 2>&1 | sed 's/^/   /' && ./ord_ok; echo "   exit=$? (expect 21)"
printf '   $ clang -o t mu.o libMB.a libMA.a          # wrong order\n'
$CC -o ord_bad mu.o libMB.a libMA.a 2>&1 | grep -E 'undefined' | sed 's/^/   /'
printf '   $ clang -o t mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group\n'
$CC -o ord_grp mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group 2>&1 | sed 's/^/   /' && ./ord_grp; echo "   exit=$?"
printf '   -- WHICH member answered WHICH reference, from the map file --\n'
$CC -o ord_map mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group -Wl,-Map=ord.map 2>/dev/null
grep -E '^libM[AB]\.a\(' ord.map | sed 's/^/   /'
printf '   libMB.a(mb.o) never appears. It satisfied nothing, so it was never\n'
printf '   read off the archive at all -- an unused member costs nothing.\n'

# ---------------------------------------------------------------------------
say "Finding 7/8 -- -z now changes NO code; it changes the dynamic section"
# ---------------------------------------------------------------------------
cat > lazytest.c <<'EOF'
/* The call to lib_fn EXISTS in the code and is NEVER EXECUTED. Both binaries
   have a PLT entry for it. The only question is whether the loader ever
   bothers to resolve it. */
#include <stdio.h>
extern int lib_fn(int);
int main(int argc, char **argv) {
    if(argc > 99) { lib_fn(1); }
    printf("%d\n", argc);
    return 0;
}
EOF
printf 'int lib_data = 7;\nint lib_fn(int x){ return x + lib_data; }\n' > lib.c
$CC -O1 -fPIC -shared -o libsym.so lib.c
$CC -O1 -fno-pie -no-pie -o lt_lazy lazytest.c -L. -lsym -Wl,-rpath,'$ORIGIN'
$CC -O1 -fno-pie -no-pie -o lt_now  lazytest.c -L. -lsym -Wl,-rpath,'$ORIGIN' -Wl,-z,now
printf '   .plt size   lazy=%s  eager=%s   <- identical\n' \
  "$(readelf -SW lt_lazy | awk '/ \.plt /{print $6}')" \
  "$(readelf -SW lt_now  | awk '/ \.plt /{print $6}')"
printf '   $ objdump -d -j .plt lt_lazy\n'
objdump -d --no-show-raw-insn -j .plt lt_lazy | tail -n +7 | sed 's/^/   /'
printf '   the ONLY file difference:\n'
printf '   lazy : %s BIND_NOW/FLAGS_1 entries\n' "$(readelf -dW lt_lazy | grep -cE 'BIND_NOW|FLAGS_1')"
printf '   eager: %s\n' "$(readelf -dW lt_now | grep -cE 'BIND_NOW|FLAGS_1')"
readelf -dW lt_now | grep -E 'BIND_NOW|FLAGS_1' | sed 's/^/     /'
printf '   -- who does the loader actually RESOLVE? (filter to this exe!) --\n'
for f in lt_lazy lt_now; do
  printf '   %-8s ' "$f"
  LD_DEBUG=bindings ./$f 2>&1 | grep "binding file ./$f" \
    | grep -oE "symbol \`[a-z_]+'" | sort -u | tr '\n' ' '
  echo
done
printf '   ^ lib_fn appears ONLY under -z now, and it is never called either\n'
printf '     way. That is the whole of lazy binding, measured.\n'

# ---------------------------------------------------------------------------
say "Finding 9/10 -- the CODE MODEL decides who owns a shared datum"
# ---------------------------------------------------------------------------
cat > owner.c <<'EOF'
#include <stdio.h>
extern int lib_data;
extern int lib_fn(int);
int main(void) {
    printf("before           lib_data=%d\n", lib_data);
    lib_data = 999;                  /* the EXECUTABLE writes */
    printf("after exe write  lib_data=%d\n", lib_data);
    printf("library lib_fn(0)=%d   <- reads the EXECUTABLE's copy\n", lib_fn(0));
    return 0;
}
EOF
$CC -O1 -fPIE   -pie    -o own_pie   owner.c -L. -lsym -Wl,-rpath,'$ORIGIN'
$CC -O1 -fno-pie -no-pie -o own_nopie owner.c -L. -lsym -Wl,-rpath,'$ORIGIN'
for f in own_pie own_nopie; do
  printf '   %-10s %-5s  lib_data reloc: %s\n' "$f" \
    "$(readelf -hW $f | awk '/Type:/{print $2}')" \
    "$(readelf -rW $f | grep 'lib_data' | grep -oE 'R_X86_64_[A-Z_]+' | head -1)"
  ./$f | sed 's/^/     /'
done
printf '   -- and the access sequence differs to match --\n'
printf '   GLOB_DAT: two instructions -- load the ADDRESS, then the value\n'
objdump -d --no-show-raw-insn own_pie | grep -A1 'lib_data>' | head -2 | sed 's/^/     /'
printf '   COPY    : one instruction -- the value is already at that address\n'
objdump -d --no-show-raw-insn own_nopie | grep -A1 'lib_data>' | head -2 | sed 's/^/     /'
printf '   NOTE: -no-pie at LINK time alone is NOT enough. main.o must also be\n'
printf '         compiled -fno-pie, or you still get GLOB_DAT.\n'
printf '   NOTE: both builds agree at 999, so COPY is ONE storage under two\n'
printf '         names, not two copies that can drift. See research.md F10.\n'

# ---------------------------------------------------------------------------
say "Finding 16/17 -- linker-defined symbols"
# ---------------------------------------------------------------------------
cat > lddef.c <<'EOF'
#include <stdio.h>
extern char _end[], __bss_start[], edata[], etext[];
int main(void) {
    printf("  ettext      %p\n", (void*)etext);
    printf("  edata       %p\n", (void*)edata);
    printf("  __bss_start %p\n", (void*)__bss_start);
    printf("  _end        %p\n", (void*)_end);
    return 0;
}
EOF
$CC -O0 -o lddef lddef.c
./lddef | sed 's/^/  /'
printf '   synthesised by the linker, NOTYPE, size 0, in no input file:\n'
readelf -sW lddef | grep -E ' (_end|__bss_start|etext|edata)$' | sed 's/^/   /'
printf '   ^ edata and __bss_start share an address: .bss starts where .data ends.\n'

cat > segmark.c <<'EOF'
#include <stdio.h>
extern char __start_mysecd[], __stop_mysecd[];
__attribute__((section("mysecd"))) const long tbl[4] = {10,20,30,40};
int main(void) {
    const long *first = (const long *)__start_mysecd;
    const long *last  = (const long *)__stop_mysecd;
    printf("  __start_mysecd=%p __stop_mysecd=%p count=%ld\n",
           (void*)__start_mysecd, (void*)__stop_mysecd, (long)(last - first));
    for (const long *p = first; p < last; p++) printf("   %ld\n", *p);
    return 0;
}
EOF
$CC -O0 -o segmark segmark.c
./segmark | sed 's/^/  /'
printf '   and they are PROTECTED -- the right visibility for a per-output-\n'
printf '   file boundary, since a second .so must not preempt the first one'"'"'s:\n'
readelf -sW segmark | grep -E '__start_mysecd|__stop_mysecd' | sed 's/^/   /'

# ---------------------------------------------------------------------------
say "Finding 18/19 -- hash style, and that the hash is of the BASE name"
# ---------------------------------------------------------------------------
printf 'int main(void){return 0;}\n' > tiny.c
for style in sysv gnu both; do
  $CC -O1 -Wl,--hash-style=$style -o hs_$style tiny.c
  printf '   --hash-style=%-5s -> %s\n' "$style" \
    "$(readelf -SW hs_$style | grep -oE '\.gnu\.hash|\.hash' | sort -u | tr '\n' ' ')"
done
printf '   default is gnu, so .hash is ABSENT unless you ask for it.\n'
printf '   $ python3 symtables.py hs_sysv   # decode + re-verify the chains\n'
python3 symtables.py hs_sysv 2>/dev/null | sed -n '/gnu.hash --/,$p' | sed 's/^/   /' | head -12

# ---------------------------------------------------------------------------
say "Findings 11-15 -- symbol versioning"
# ---------------------------------------------------------------------------
mkdir -p ver
cat > ver/vlib.c <<'EOF'
int compute(int x)       { return x * 2; }
int added_in_v2(int x)   { return x + 100; }
int removed_in_v3(int x) { return x - 1; }
const char *vtag(void)   { return "v3"; }
EOF
cat > ver/vmap <<'EOF'
V1 { global: compute; local: *; };
V2 { global: added_in_v2; } V1;
V3 { global: compute; added_in_v2; removed_in_v3; vtag; } V2;
EOF
printf 'V1 { global: compute; local: *; };\nV2 { global: added_in_v2; } V1;\nV3 { global: compute; removed_in_v3; vtag; } V2;\n' > ver/vmap_dup
printf 'V1 { global: compute@V1; local: *; };\n' > ver/vmap_at
$CC -O1 -fPIC -shared -Wl,--version-script=ver/vmap     -o ver/libv.so ver/vlib.c
$CC -O1 -fPIC -shared -fvisibility=hidden -Wl,--version-script=ver/vmap -o ver/libv_hidden.so ver/vlib.c
$CC -O1 -fPIC -shared -Wl,--version-script=ver/vmap_dup -o ver/libv_dup.so ver/vlib.c
printf '   .gnu.version_d -- the LAST verdaux of a node is its PARENT:\n'
python3 symtables.py ver/libv.so 2>/dev/null | sed -n '/gnu.version_d/,/gnu.version_r/p' | sed 's/^/   /'
printf '   Finding 13 -- compute is listed in V1 AND V3; ONE entry survives:\n'
llvm-nm-21 -D --defined-only ver/libv_dup.so | sed 's/^/   /'
printf '   Finding 14 -- -fvisibility=hidden beats the script'"'"'s global: clause:\n'
llvm-nm-21 -D --defined-only ver/libv_hidden.so | sed 's/^/   /'
printf '   Finding 15 -- name@version is .symver syntax, not version-script syntax:\n'
$CC -O1 -fPIC -shared -Wl,--version-script=ver/vmap_at -o /dev/null ver/vlib.c 2>&1 | grep -v '^clang:' | sed 's/^/   /'

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
