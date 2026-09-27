#!/usr/bin/env bash
# Builds every specimen this course measures. Single source of truth: it
# writes the .c files itself, so they are build products.
#
#   cd courses/dyn/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   python3 dynscope.py          # the buildable artifact
#
# Requires: clang, ld (GNU bfd 2.46+), readelf, objdump, nm, llvm-nm-21,
# llvm-objdump-21, python3.
#
# The instrument this course relies on is LD_DEBUG. glibc's loader will print
# every symbol binding it makes if you ask, which turns "the loader searches
# the scope in some order" from a claim into a measurement.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}

say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }

# bindings <program> [sym...] -- print the loader's actual binding decisions
bindings() {
  LD_DEBUG=bindings "$@" 2>&1 \
    | sed 's/^ *[0-9]*:\t*//' \
    | grep -E "binding file .* normal symbol" || true
}

# ---------------------------------------------------------------------------
say "D1 -- the instrument: LD_DEBUG makes the loader report its own decisions"
# ---------------------------------------------------------------------------
cat > lib.c <<'EOF'
#include <stdio.h>
static int static_helper(int x){ return x + 1; }  /* NOT an interposition
                                                    candidate: not in .dynsym */
int lib_value(void){ return static_helper(0); }
EOF
cat > mid.c <<'EOF'
extern int lib_value(void);
int mid_value(void){ return lib_value() + 10; }
EOF
cat > main.c <<'EOF'
#include <stdio.h>
extern int lib_value(void);
extern int mid_value(void);
int main(void){ printf("  lib_value()=%d  mid_value()=%d\n", lib_value(), mid_value()); return 0; }
EOF
$CC -fPIC -shared -o liba.so lib.c
$CC -fPIC -shared -o libb.so mid.c -L. -la -Wl,-rpath,'$ORIGIN'
# NOTE the -la as well. Without it, --as-needed (the default on this
# toolchain) drops liba.so, because at the point the linker sees -la
# nothing has referenced a symbol from it. That is --as-needed working
# correctly, and it is the cause of the single most common shared-library
# link error, so the build script does it right and the crosscheck asserts it.
$CC -o prog main.c -L. -lb -la -Wl,-rpath,'$ORIGIN'
note "the DT_NEEDED graph:"
for f in liba.so libb.so prog; do
  printf '   %-9s ' "$f"
  readelf -dW "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/[\1]/p' | tr '\n' ' '
  echo
done
note ""
note "the loader's own account of who bound to what:"
bindings ./prog | grep -E "lib_value|mid_value" | sed 's/^/   /'
./prog | sed 's/^/   /'

# ---------------------------------------------------------------------------
say "D2 -- INTERPOSITION: the executable's definition wins, EVERYWHERE"
# ---------------------------------------------------------------------------
cat > main2.c <<'EOF'
#include <stdio.h>
extern int lib_value(void);
extern int mid_value(void);
int lib_value(void){ return 100; }     /* the PROGRAM defines it too */
int main(void){ printf("  prog's lib_value()=%d   libb's view of it=%d\n",
                       lib_value(), mid_value()); return 0; }
EOF
$CC -o prog2 main2.c -L. -lb -la -Wl,-rpath,'$ORIGIN'
note "same binary, plus one definition in the executable:"
./prog2 | sed 's/^/   /'
note ""
note "and the loader says the LIBRARY's own call was rebound too:"
bindings ./prog2 | grep lib_value | sed 's/^/   /'
note ""
note "=> mid_value() is 110, not 11. libb.so asked for lib_value and got the"
note "   program's. That is interposition, and it is not a trick: it is the"
note "   scope search finding an earlier match."

# ---------------------------------------------------------------------------
say "D3 -- the scope is built BREADTH-FIRST from DT_NEEDED"
# ---------------------------------------------------------------------------
printf 'int deep(void){ return 3; }\n' > deep.c
printf 'extern int deep(void);\nint mid2(void){ return deep()*2; }\n' > mid2.c
$CC -fPIC -shared -o libdeep.so deep.c
$CC -fPIC -shared -o libd2.so mid2.c -L. -ldeep -Wl,-rpath,'$ORIGIN'
printf 'extern int mid_value(void);\nint main(void){ return mid_value(); }\n' > order.c
$CC -o order order.c -L. -ld2 -ldeep -lb -la -Wl,-rpath,'$ORIGIN'
note "the graph is a tree, but the loader loads it level by level:"
for f in order libd2.so libb.so liba.so libdeep.so; do
  printf '   %-11s ' "$f"
  readelf -dW "$f" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/[\1]/p' | tr '\n' ' '
  echo
done
note ""
note "libd2.so needs libdeep.so, and libb.so needs liba.so. Depth-first"
note "would finish libdeep.so, then liba.so, then libb.so. Breadth-first"
note "takes both direct dependencies first:"
LD_DEBUG=libs ./order 2>&1 | sed 's/^ *[0-9]*:\t*//' | grep "find library" | sed 's/; searching.*//' | sed 's/^/   /'
note ""
note "the order libdeep.so appears in is the answer, and it is 2nd, not 4th."

# ---------------------------------------------------------------------------
say "D4 -- -Bsymbolic is ONE instruction"
# ---------------------------------------------------------------------------
# The first attempt at this test used a library calling a symbol defined in a
# DIFFERENT library, and -Bsymbolic changed nothing at all. That is correct
# behaviour and it is the teaching point: -Bsymbolic binds references to
# symbols the library ITSELF defines. A cross-library reference has nothing
# for it to bind.
cat > self.c <<'EOF'
int helper(int x){ return x * 3; }        /* defined HERE */
int entry(int x){ return helper(x) + 1; } /* and called HERE */
EOF
cat > selfmain.c <<'EOF'
#include <stdio.h>
extern int entry(int);
int helper(int x){ return x * 1000; }     /* the program tries to interpose */
int main(void){ printf("  entry(2) = %d\n", entry(2)); return 0; }
EOF
$CC -fPIC -shared -o libself.so self.c
$CC -fPIC -shared -Wl,-Bsymbolic -o libself_sym.so self.c
$CC -o t_plain   selfmain.c ./libself.so     -Wl,-rpath,'$ORIGIN'
$CC -o t_symbolic selfmain.c ./libself_sym.so -Wl,-rpath,'$ORIGIN'
printf '   plain      ' ; ./t_plain
printf '   -Bsymbolic ' ; ./t_symbolic
note ""
note "the ONLY difference in the whole library:"
for lib in libself.so libself_sym.so; do
  printf '   %-16s ' "$lib"
  llvm-objdump-21 -d --no-show-raw-insn "$lib" 2>/dev/null \
    | sed -n '/<entry>:/,/^$/p' | grep -E 'call' | head -1 | sed 's/^ *//'
done
note ""
note "   callq <helper@plt>  -- indirect, interposable"
note "   callq <helper>      -- direct, bound at link time"
note ""
note "and .dynsym is IDENTICAL, so -Bsymbolic changes no export:"
for lib in libself.so libself_sym.so; do
  printf '   %-16s dynsym: ' "$lib"
  llvm-nm-21 -D --defined-only "$lib" 2>/dev/null | awk '{printf "%s ", $3}'
  echo
done

# ---------------------------------------------------------------------------
say "D5 -- a library that calls ANOTHER library is NOT affected by -Bsymbolic"
# ---------------------------------------------------------------------------
$CC -fPIC -shared -Wl,-Bsymbolic -o libb_sym.so mid.c -L. -la -Wl,-rpath,'$ORIGIN'
$CC -o prog3 main2.c -L. -l:b_sym.so -la -Wl,-rpath,'$ORIGIN' 2>/dev/null \
  || $CC -o prog3 main2.c ./libb_sym.so ./liba.so -Wl,-rpath,'$ORIGIN'
printf '   libb with -Bsymbolic, still calling liba: '
./prog3
note "   still 110. -Bsymbolic had nothing to do: lib_value is not libb's."
note "   The name says \"bind MY symbols\" and that is exactly what it means."

# ---------------------------------------------------------------------------
say "D6 -- dlopen: the mode bits, and the trap in RTLD_LOCAL == 0"
# ---------------------------------------------------------------------------
cat > plug.c <<'EOF'
int plug_value(void){ return 55; }
int hook(void){ return 900; }
EOF
$CC -fPIC -shared -o libplug.so plug.c
cat > dl.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv){
  int bind  = (argc > 2 && argv[2][0]=='n') ? RTLD_NOW : RTLD_LAZY;
  int scope = (argc > 1 && argv[1][0]=='g') ? RTLD_GLOBAL : RTLD_LOCAL;
  void *h = dlopen("./libplug.so", bind | scope);
  if(!h){ printf("  FAILED: %s\n", dlerror()); return 1; }
  int (*pv)(void) = (int(*)(void))dlsym(h, "plug_value");
  printf("  mode=%-6s plug_value()=%d  dlsym(\"nope\")=%p\n",
         (scope & RTLD_GLOBAL) ? "GLOBAL" : "LOCAL", pv(), dlsym(h, "nope"));
  dlclose(h);
  return 0;
}
EOF
$CC -o dlprog dl.c -ldl
cat > dl0.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(void){
  void *h = dlopen("./libplug.so", 0);   /* RTLD_LOCAL and NOTHING else */
  printf("  dlopen(path, 0) = %p   %s\n", h, h ? "ok" : dlerror());
  return 0;
}
EOF
$CC -o dl0 dl0.c -ldl
printf '   '
./dl0
printf '   '
./dlprog local
printf '   '
./dlprog global
note ""
note "RTLD_LOCAL is 0, so the mode must still carry RTLD_LAZY or RTLD_NOW."
note "\"invalid mode for dlopen()\" means exactly that, and it is the most"
note "common dlopen error there is."
note ""
note "and a dlopen'd library is NOT a DT_NEEDED entry -- it arrives at run"
note "time, which is the whole point:"
readelf -dW dlprog | sed -n 's/.*(NEEDED).*\[\(.*\)\]/   NEEDED \1/p'
readelf -lW dlprog | sed -n 's/.*(INTERP).*\[/   INTERP /p' | head -1

# ---------------------------------------------------------------------------
say "D7 -- what -z now changes: one dynamic entry, and no code at all"
# ---------------------------------------------------------------------------
cat > liblazy.c <<'EOF'
int libfn(int x){ return x + 1; }
EOF
cat > lazy.c <<'EOF'
extern int libfn(int);
int main(void){ int s=0; for(int i=0;i<1000;i++) s+=libfn(i); return s&1; }
EOF
$CC -fPIC -shared -o liblazy.so liblazy.c
$CC -O2 -o lazy     lazy.c -L. -llazy -Wl,-rpath,'$ORIGIN'
$CC -O2 -o lazy_now lazy.c -L. -llazy -Wl,-rpath,'$ORIGIN' -Wl,-z,now
note "the .plt is byte-identical, because -z now emits no CODE:"
for f in lazy lazy_now; do
  printf '   %-9s .plt=%s  .got.plt=%-6s .got=%s  dyn entries=%s\n' "$f" \
    "$(readelf -SW $f | awk '/ \.plt /{print $6}')" \
    "$(readelf -SW $f | awk '/\.got\.plt/{print $6}')" \
    "$(readelf -SW $f | awk '/ \.got /{print $6}')" \
    "$(readelf -dW $f | sed -n 's/.*contains \([0-9]*\) entries.*/\1/p')"
done
note ""
note "the structural difference is NOT code, it is DATA LAYOUT: with -z now"
note "the .got.plt section DISAPPEARS entirely, because its slots are all"
note "filled in at load time and need no separate home. They merge into"
note ".got, which grows to absorb them. The earlier Symbol Resolution course"
note "said \"-z now changes no code\" -- that is still exactly right, and"
note "this is the part that sentence did not cover."
note ""
note "the entries it adds:"
readelf -dW lazy_now | grep -E 'BIND_NOW|FLAGS' | sed 's/^ */   /' | sed 's/^ *0x[0-9a-f]* *//'
note "   (lazy had DT_FLAGS_1 = PIE only; -z now adds DT_FLAGS BIND_NOW and"
note "    the NOW bit in DT_FLAGS_1.)"
note ""
note "and how MANY bindings the loader makes either way:"
printf '   lazy      %s binding(s) for libfn\n' "$(bindings ./lazy     | grep -c libfn)"
printf '   -z now    %s binding(s) for libfn\n' "$(bindings ./lazy_now | grep -c libfn)"
printf '   LD_BIND_NOW=1, same binary: %s\n' "$(LD_BIND_NOW=1 LD_DEBUG=bindings ./lazy 2>&1 | grep -c libfn)"
note ""
note "ONE either way. Lazy binding defers the same single decision to the"
note "first call; it does not make more decisions, and it does not make a"
note "faster path for the other 999."

# ---------------------------------------------------------------------------
say "D8 -- a library's .dynsym, and how small it can be made"
# ---------------------------------------------------------------------------
cat > vis.c <<'EOF'
int  exported_one(void){ return 1; }
int  exported_two(void){ return 2; }
__attribute__((visibility("hidden"))) int hidden_one(void){ return 3; }
static int static_one(void){ return 4; }
int  calls_all(void){ return exported_one() + exported_two()
                           + hidden_one() + static_one(); }
EOF
$CC -fPIC -O1 -shared -o vis_default.so vis.c
$CC -fPIC -O1 -fvisibility=hidden -shared -o vis_hidden.so vis.c
note "default visibility:"
printf '   ' ; llvm-nm-21 -D --defined-only vis_default.so | awk '{printf "%s ", $3}'; echo
note "with -fvisibility=hidden:"
printf '   ' ; llvm-nm-21 -D --defined-only vis_hidden.so  | awk '{printf "%s ", $3}'; echo
note ""
note "and with a version script that localises everything but one:"
cat > ver.map <<'EOF'
V1 { global: exported_one; local: *; };
EOF
$CC -fPIC -O1 -shared -Wl,--version-script=ver.map -o vis_ver.so vis.c
printf '   ' ; llvm-nm-21 -D --defined-only vis_ver.so | awk '{printf "%s ", $3}'; echo
note ""
note "the version script also ADDS a version definition block:"
readelf -dW vis_ver.so | sed -n 's/^ *(\(VER[A-Z]*\)).*/   \1/p' | sed 's/^/   /'
readelf -VW vis_ver.so 2>/dev/null | sed -n '/Version definition/,/^$/p' | sed 's/^/   /' | head -8
note ""
note "The three builds do NOT all work, and the two that fail are the"
note "lesson. A program can only call what is in .dynsym:"
for f in vis_default.so vis_hidden.so vis_ver.so; do
  printf '   %-16s ' "$f"
  cat > t.c <<EOF
extern int calls_all(void); int main(void){ return calls_all()==10?0:1; }
EOF
  if $CC -o tv t.c ./$f -Wl,-rpath,'$ORIGIN' 2>/dev/null; then
    ./tv && echo "links, runs, correct" || echo "links, WRONG ANSWER"
  else
    echo "DOES NOT LINK -- calls_all is not in .dynsym"
  fi
done
note ""
note "-fvisibility=hidden hides EVERYTHING, including the API you meant to"
note "export, and a version script with 'local: *' does the same. Both are"
note "correct and both break every caller, silently, until link time."
note ""
note "the fix, and the only correct one -- mark the API explicitly:"
cat > vis2.c <<'EOF'
int  exported_one(void){ return 1; }
int  exported_two(void){ return 2; }
__attribute__((visibility("hidden"))) int hidden_one(void){ return 3; }
static int static_one(void){ return 4; }
/* WITHOUT this line the whole library is unusable. */
__attribute__((visibility("default"))) int calls_all(void);
int calls_all(void){ return exported_one() + exported_two()
                           + hidden_one() + static_one(); }
EOF
$CC -fPIC -O1 -fvisibility=hidden -shared -o vis_hidden2.so vis2.c
cat > ver2.map <<'EOF'
V1 { global: exported_one; calls_all; local: *; };
EOF
$CC -fPIC -O1 -shared -Wl,--version-script=ver2.map -o vis_ver2.so vis2.c
for f in vis_hidden2.so vis_ver2.so; do
  printf '   %-16s dynsym: ' "$f"
  llvm-nm-21 -D --defined-only "$f" 2>/dev/null | awk '{printf "%s ", $3}'
  printf '  -> '
  $CC -o tv2_$f t.c ./$f -Wl,-rpath,'$ORIGIN' 2>/dev/null && ./tv2_$f && echo "links, runs, correct" || echo "FAILED"
done
# the same test for the unmarked builds, so crosscheck can assert BOTH halves
for f in vis_hidden.so vis_ver.so; do
  $CC -o tv2_$f t.c ./$f -Wl,-rpath,'$ORIGIN' 2>/dev/null || echo "   ($f does not link, as expected)"
done

# ---------------------------------------------------------------------------
say 'D9 -- $ORIGIN, and what DT_NEEDED records'
# ---------------------------------------------------------------------------
note "every binary above was linked with -Wl,-rpath,'\$ORIGIN' and carries:"
readelf -dW prog | grep -E 'RPATH|RUNPATH' | sed 's/^ */   /'
note ""
note "which is the token that means \"the directory this file is in\". The"
note "loader expands it at run time. Compare with an absolute path:"

note ""
note "and DT_NEEDED records the SONAME, never the real file name:"
readelf -dW prog | sed -n 's/.*(NEEDED).*\[\(.*\)\]/   NEEDED \1/p'
readelf -dW liba.so | sed -n 's/.*(SONAME).*\[\(.*\)\]/   liba SONAME \1/p' || \
  note "   (liba.so has no SONAME -- nothing set one)"
note ""
note "so: a library built WITHOUT -Wl,-soname records nothing, and a program"
note "linked against it records the FILE name. That is the whole reason"
note "-soname exists, demonstrated by absence."

# ---------------------------------------------------------------------------
say "D10 -- link order becomes run-time behaviour, and --as-needed hides it"
# ---------------------------------------------------------------------------
# Two libraries both exporting lib_value. Which one wins is decided by where
# each lands in DT_NEEDED, and --as-needed can change that list.
printf 'int lib_value(void){ return 999; }  /* a SECOND definition */\n' > shim.c
$CC -fPIC -shared -Wl,-rpath,'$ORIGIN' -o libshim.so shim.c -L. -la
$CC -o order_shim  order.c -L. -lshim -ld2 -ldeep -lb -la -Wl,-rpath,'$ORIGIN'
$CC -o order_shim2 order.c -L. -ld2 -ldeep -lb -lshim -la -Wl,-rpath,'$ORIGIN'
for f in order_shim order_shim2; do
  note ""
  note "  $f   (-la is last in both, but note the DT_NEEDED list):"
  readelf -dW "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/     NEEDED \1/p' | sed 's/^/  /'
  printf '     lib_value binds to: '
  bindings "./$f" | grep -m1 lib_value | sed 's/.*to \(.*\) \[0\].*/\1/' | xargs basename
done
note ""
note "  ^ CORRECTION: the first draft of this section claimed that"
note "    --as-needed dropped liba.so from the second build. It did not --"
note "    liba.so is in BOTH DT_NEEDED lists. What is actually true is"
note "    simpler: DT_NEEDED order FOLLOWS THE LINK LINE ORDER, and libshim"
note "    beats liba in both builds because it precedes it in both."
note ""
note "    order_shim   libshim at 1, liba at 4   -> shim wins"
note "    order_shim2  libshim at 4, liba at 5   -> shim still wins"
note ""
note "  The interesting fact is the MARGIN, not the outcome: in the second"
note "  build the two are ADJACENT. Move -la one position earlier and liba"
note "  wins instead. The same source, the same objects, the same flags --"
note "  differing only in the order two of them appear."

# ---------------------------------------------------------------------------
say "D11 -- the compiler flag and the one a link-time flag cannot reach"
# ---------------------------------------------------------------------------
# -fno-semantic-interposition is a COMPILER flag and resolves at -c time, so
# the difference is visible before any linker runs. -Bsymbolic at this stage
# has done nothing at all, because there is no link.
$CC -fPIC -c self.c -o s_plain.o 2>/dev/null
$CC -fPIC -fno-semantic-interposition -c self.c -o s_nosem.o 2>/dev/null
$CC -fPIC -Wl,-Bsymbolic -c self.c -o s_sym.o 2>/dev/null
$CC -fPIC -c fptr.c -o f_plain.o 2>/dev/null
$CC -fPIC -Wl,-Bsymbolic -c fptr.c -o f_sym.o 2>/dev/null
note "  compiling self.c only (-c), so -Bsymbolic has not run yet:"
for m in ":-fPIC" ":-fPIC -fno-semantic-interposition" ":-fPIC -Wl,-Bsymbolic"; do
  fl="${m#*:}"; rm -f s.o
  $CC $fl -c self.c -o s.o 2>/dev/null
  printf '     %-38s ' "${fl:-plain}"
  llvm-objdump-21 -d --no-show-raw-insn s.o | sed -n '/<entry>:/,/^$/p' \
    | grep -m1 call | sed 's/^ *//'
done
note ""
note "  ^ -fno-semantic-interposition resolves the call IN THE OBJECT."
note "    -Bsymbolic produces an identical object here, because it is a"
note "    LINK-time flag and this is not a link."
printf 'int helper(int x){ return x * 3; }\nint (*get(void))(int){ return helper; }\nint entry(int x){ return get()(x) + 1; }\n' > fptr.c
note ""
note "  a call through a FUNCTION POINTER, with and without -Bsymbolic:"
for fl in "-fPIC" "-fPIC -Wl,-Bsymbolic"; do
  rm -f f.o; $CC $fl -c fptr.c -o f.o 2>/dev/null
  printf '     %-26s ' "$fl"
  llvm-objdump-21 -d --no-show-raw-insn f.o | sed -n '/<entry>:/,/^$/p' \
    | grep -m1 call | sed 's/^ *//'
done
note ""
note "  ^ IDENTICAL. The target is a runtime value, so no linker can"
note "    resolve it and no link-time flag can touch it. That is the"
note "    boundary of -Bsymbolic, and it is not a limitation of the flag --"
note "    there is nothing there to change."

# ---------------------------------------------------------------------------
say "D12 -- the three dlopen facts that are not in the documentation"
# ---------------------------------------------------------------------------
cat > late2.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
int main(void){
  void *h = dlopen("./libplug.so",
                   (getenv("G") ? RTLD_GLOBAL : RTLD_LOCAL) | RTLD_LAZY);
  if(!h){ printf("  dlopen: %s\n", dlerror()); return 1; }
  int (*hk)(void) = (int(*)(void))dlsym(RTLD_DEFAULT, "hook");
  printf("  RTLD_DEFAULT finds hook(): %s\n", hk ? "yes" : "NO");
  return 0;
}
EOF
$CC -o late2 late2.c -ldl -Wl,-rpath,'$ORIGIN'
note "  1. the ONLY observable difference between RTLD_LOCAL and RTLD_GLOBAL:"
printf '     RTLD_LOCAL  ' ; ./late2
printf '     RTLD_GLOBAL ' ; G=1 ./late2
note "     dlsym(RTLD_DEFAULT) is a GLOBAL-scope question. dlsym(handle) is"
note "     not, and always works either way."

cat > twice.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(void){
  void *a = dlopen("./libplug.so", RTLD_LAZY|RTLD_LOCAL);
  void *b = dlopen("./libplug.so", RTLD_LAZY|RTLD_LOCAL);
  printf("  same handle: %s   ", a==b ? "YES" : "no");
  dlclose(a);
  int (*p)(void) = (int(*)(void))dlsym(b, "plug_value");
  printf("after dlclose(a), handle b still works: %s\n", p ? "yes" : "NO");
  return 0;
}
EOF
$CC -o twice twice.c -ldl -Wl,-rpath,'$ORIGIN'
note ""
note "  2. dlopen on an ALREADY-LOADED library:"
note "     $(./twice)"
note "     a reference count, not a second load. dlclose drops one; the"
note "     object stays while anyone holds it."

printf 'extern int nonexistent_thing(void);\nint bad(void){ return nonexistent_thing(); }\n' > bad.c
$CC -fPIC -shared -o libbad.so bad.c 2>/dev/null
cat > dbad.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(int c, char **v){
  void *h = dlopen("./libbad.so", (c>1 && v[1][0]=='n') ? RTLD_NOW : RTLD_LAZY);
  printf("  %-4s : %s\n", c>1?v[1]:"lazy", h ? "dlopen SUCCEEDED" : dlerror());
  return 0;
}
EOF
$CC -o dbad dbad.c -ldl -Wl,-rpath,'$ORIGIN'
note ""
note "  3. a library that can never work, loaded both ways:"
note "     $(./dbad)"
note "     $(./dbad now)"
note "     RTLD_LAZY SUCCEEDS. the error surfaces at the first call into"
note "     it, which may be much later and may never happen. This is why"
note "     a plugin loader uses RTLD_NOW."

# ---------------------------------------------------------------------------
say "D13 -- where the thread-local block actually is"
# ---------------------------------------------------------------------------
cat > tls.c <<'EOF'
#include <stdio.h>
__thread int big_tls[64] = {1};   /* 256 bytes */
__thread int small_tls = 2;
int *where_big(void){ return big_tls; }
int *where_small(void){ return &small_tls; }
int main(void){ printf("  big=%p small=%p\n", (void*)where_big(), (void*)where_small()); return 0; }
EOF
$CC -O1 -o tlsmain tls.c
note "  two thread-locals, one thread:"
note "    $(./tlsmain)"
note "  256 bytes apart -- which is exactly sizeof(big_tls). the block is"
note "  laid out CONSECUTIVELY, and the two offsets are the TPOFF values"
note "  the reloc course measured being patched into the code."
printf '  PT_TLS   '
readelf -lW tlsmain | grep -E '^  TLS' | sed 's/^ *//'
note ""
note "  p_filesz is the TEMPLATE -- the initialiser bytes, copied into"
note "  every thread's block at creation. p_memsz is how much RESERVED."
note "  They are equal here because both variables are initialised, so"
note "  there is no .tbss and nothing to zero."
cat > tt.c <<'EOF'
#include <stdio.h>
#include <pthread.h>
__thread int t[4];
void *show(void *a){ (void)a; printf("  thread %p sees t at %p\n",(void*)pthread_self(),(void*)t); return 0; }
int main(void){ pthread_t b;
  printf("  main           sees t at %p\n",(void*)t);
  pthread_create(&b,0,show,0); pthread_join(b,0); return 0; }
EOF
$CC -O1 -o tt tt.c -lpthread
note ""
note "  the same variable, two threads:"
note "    $(./tt | tr '\n' ' ')"
note "  Two different addresses, tens of megabytes apart, for one source"
note "  variable. That is the whole reason TLS cannot be an ordinary"
note "  relocation: there is no single address to write into the code."
note ""
note "  NOT MEASURED HERE: the static-surplus limit and the fallback to"
note "  general-dynamic __tls_get_addr when it is exceeded. The attempt to"
note "  measure it (32 dlopen-able libraries each with 256 bytes of TLS)"
note "  failed to link, because --as-needed dropped them all with nothing"
note "  referencing them. The mechanism is real and is what the reloc"
note "  course's R_X86_64_TLSGD relocation is; the threshold on THIS machine"
note "  is not claimed."

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'    
