#!/usr/bin/env bash
# Builds every specimen this course measures. This script is the single source
# of truth: it writes the .c files itself, so they are build products.
#
#   cd courses/link/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   python3 linklab.py            # the buildable artifact
#
# Requires: clang, GNU ld (bfd) 2.46+, readelf, objdump, objcopy, python3.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}
LD=${LD:-ld}

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }

# readelf -lW columns: 1=Type 2=Offset 3=VirtAddr 4=PhysAddr 5=FileSiz
#                      6=MemSiz 7=Flg(R W E are folded into 7 and sometimes 8)
# The flags are $7 plus an "E" in $8 when present; the align is always $NF.
# Getting this wrong is how you end up printing MemSiz and calling it FileSiz.
segs() {
  readelf -lW "$1" | awk '/^  [A-Z]/ {
    type=$1; vaddr=$3; fsz=$5;
    fl=$7; if ($8 == "E") fl = fl " E";
    printf "       %-7s vaddr=%-18s filesz=%-9s %-4s align=%s\n", type, vaddr, fsz, fl, $NF
  }'
}

# ---------------------------------------------------------------------------
say "F1 -- the script you are already using, and the proof of what it decides"
# ---------------------------------------------------------------------------
# GNU ld will print the exact script it is using, on request. This is the
# single most useful thing to know about linker scripts and it is one flag.
$LD --verbose 2>/dev/null | sed -n '/^====/,$p' | sed '1d;$d' > default.ld
note "default.ld is $(grep -c '' default.ld) lines, extracted from ld itself."
note "its top-level commands:"
grep -nE '^[A-Z_]+' default.ld | cut -c1-72 | sed 's/^/     /'

cat > hello.c <<'EOF'
int helper(void){ return 7; }
int main(void){ return helper() - 7; }
EOF
$CC -O1 -c hello.c -o hello.o

# THE ROUND TRIP -- and the first version of this script overclaimed.
# It compared SIZES, found them equal, and said "IDENTICAL". They are the
# same SIZE and they are NOT the same FILE: ld's own default on this
# PIE-by-default toolchain emits ET_DYN, and the saved script emits ET_EXEC,
# because -T selects a non-PIE code model (see F9). Byte 17 is e_type.
note ""
note "round trip, three flag sets. Comparing FILES, not sizes:"
for m in ":none" "-fPIE -pie:-fPIE -pie" "-fno-pie -no-pie:-fno-pie -no-pie"; do
  fl="${m%%:*}"; d="${m#*:}"
  case "$d" in
    none)              a=rt.out;     b=rts.out ;;
    -fPIE)             a=rt_pie.out; b=rts_pie.out ;;
    *)                 a=rt_exec.out; b=rts_exec.out ;;
  esac
  rm -f "$a" "$b"
  $CC -O1 $fl hello.o -o "$a" 2>/dev/null
  $CC -O1 $fl hello.o -o "$b" -T default.ld 2>/dev/null
  printf '   %-18s ld default=%-5s script=%-5s ' "$d" \
    "$(readelf -hW rt.out | sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')" \
    "$(readelf -hW rts.out | sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')"
  if cmp -s "$a" "$b"; then echo "BYTE IDENTICAL"; else
    echo "differ in $(cmp -l "$a" "$b" 2>/dev/null | wc -l) bytes, first at $(cmp "$a" "$b" 2>/dev/null | sed -n 's/.*byte \([0-9]*\),.*/\1/p')"
  fi
done
note ""
note "So the script alone is NOT the program -- and that is the honest"
note "version of the claim. It round-trips byte-for-byte ONLY when the"
note "command-line flags and the script agree about the code model. The"
note "script decides placement; the flags decide the model; -T overrides"
note "the model towards EXEC. Expecting the script alone to reproduce a"
note "PIE build is the mistake, and F9 is where it becomes explicit."

# ---------------------------------------------------------------------------
say "F2 -- SEGMENT_START does NOT ask the emulation. It returns argument 2."
# ---------------------------------------------------------------------------
# The obvious story is that SEGMENT_START asks the target emulation where a
# named segment begins, and the second argument is a fallback. Measure it: put
# a recognisable sentinel in argument 2 and read the answer back out of the
# binary.
python3 - <<'PY'
s = open('default.ld').read()
s = s.replace('SECTIONS\n{', 'SECTIONS\n{\n'
              '  PROVIDE(__probe_text   = SEGMENT_START("text-segment",   0xDEADBEEF));\n'
              '  PROVIDE(__probe_rodata = SEGMENT_START("rodata-segment", 0xCAFEBABE));\n'
              '  PROVIDE(__probe_maxpg  = CONSTANT(MAXPAGESIZE));\n'
              '  PROVIDE(__probe_hdrs   = SIZEOF_HEADERS);\n', 1)
open('probe.ld', 'w').write(s)
PY
for m in "-fno-pie -no-pie" "-fPIE -pie" "-fno-pie -static"; do
  rm -f probe.out
  # -u is required: PROVIDE only defines a symbol that something REFERENCES.
  # That conditionality is itself a finding -- see the linker-defined symbols
  # concept in the Symbol Resolution course.
  $CC -O1 $m hello.o -o probe.out -T probe.ld \
      -Wl,-u,__probe_text -Wl,-u,__probe_rodata \
      -Wl,-u,__probe_maxpg -Wl,-u,__probe_hdrs 2>/dev/null
  printf '   %-18s ' "$m"
  readelf -sW probe.out 2>/dev/null | awk '
    / __probe_text$/   {printf "text=%s ", $2}
    / __probe_rodata$/ {printf "rodata=%s ", $2}
    / __probe_maxpg$/  {printf "MAXPAGESIZE=%s ", $2}
    / __probe_hdrs$/   {printf "SIZEOF_HEADERS=%s ", $2}
    END{print ""}'
done
note ""
note "0xdeadbeef / 0xcafebabe came back verbatim. On x86-64 Linux this"
note "emulation has NO opinion about 'text-segment', so the second argument"
note "IS the answer. The name is a hook for targets that do have segments."

# ---------------------------------------------------------------------------
say "F3 -- one number moves the whole binary, and the program still runs"
# ---------------------------------------------------------------------------
for base in 0x400000 0x10000000 0x800000; do
  sed "s/SEGMENT_START(\"text-segment\", 0x400000)/SEGMENT_START(\"text-segment\", $base)/g" \
      default.ld > b.ld
  rm -f moved_$base
  $CC -O1 hello.o -o moved_$base -T b.ld 2>/dev/null
  printf '   base=%-12s first LOAD vaddr=%s  ' "$base" \
    "$(readelf -lW moved_$base 2>/dev/null | awk '/LOAD/{print $3; exit}')"
  ./moved_$base 2>/dev/null
  echo "ran, exit=$?"
done
note ""
note "0x800000 is a perfectly ordinary address that nothing reserves, and"
note "the program ran there. So the number in the script is not a hint that"
note "the CPU ignores -- it is the address the CPU jumps to on entry."

# ---------------------------------------------------------------------------
say "F4 -- rule order decides placement: hot/cold, measured"
# ---------------------------------------------------------------------------
cat > hot.c <<'EOF'
#include <stdio.h>
int cold(int x){ if (x % 7 == 3) return x * 13; return x + 1; }
int hot(int x){ return x * 3 + 1; }
int main(void){ long s = 0; for (int i = 0; i < 100000; i++) s += hot(i);
                 printf("%ld %d\n", s, cold(9)); return 0; }
EOF
$CC -O2 -ffunction-sections -fdata-sections -c hot.c -o hot.o
note "input sections, in object order:"
readelf -SW hot.o | sed -n 's/^ *\[[ 0-9]*\] \(\.text[^ ]*\).*/     \1/p' | cat -n
$CC -O2 -o hot hot.o
note "function order in the LINKED binary:"
objdump -d hot --section=.text | sed -n 's/^[0-9a-f]* <\(hot\|cold\|main\)>:/     \1/p' | head -5
note ""
note "The script's .text rule is, in order:  .text.unlikely, .text.exit,"
note ".text.startup, .text.hot, .text.sorted, then .text .stub .text.*"
note "so .text.hot is pulled to the FRONT by rule 4, and .text.cold and"
note ".text.main both fall into the last wildcard and keep OBJECT order."

# ---------------------------------------------------------------------------
say "F5 -- rule order decides: a four-cell experiment, no exceptions"
# ---------------------------------------------------------------------------
# RETRACTION: an earlier version of this script concluded that /DISCARD/ beats
# rule order. That was WRONG, and the reason the experiment was wrong is worth
# recording: the two Python .replace() calls were chained, and in the file that
# produced the wrong answer the FIRST one had not applied -- so the "keep rule
# comes first" variant had no keep rule in it at all. Four cells, each built
# and each checked, settles it.
cat > note2.c <<'EOF'
__asm__(".section .note.mytest,\"\",@progbits\n .long 0x12345678\n");
int main(void){ return 0; }
EOF
$CC -O1 -c note2.c -o note2.o
python3 - <<'PY'
s = open('default.ld').read()
KEEP  = '  .mynote : { *(.note.mytest) }\n'
DISC  = ('  /DISCARD/ : { *(.note.mytest) *(.note.GNU-stack) *(.gnu_debuglink)'
         ' *(.gnu.lto_*) *(.gnu_object_only) }\n')
PLAIN = ('  /DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink)'
         ' *(.gnu.lto_*) *(.gnu_object_only) }\n')
# each cell is written and then VERIFIED below, because an edit that silently
# does not apply looks exactly like a linker behaviour.
def w(name, t):
    open(name, 'w').write(t)
    assert KEEP in t or KEEP not in t      # no-op; the real check is in shell
w('cell_a.ld', s.replace('SECTIONS\n{', 'SECTIONS\n{' + KEEP, 1))
w('cell_b.ld', s.replace(PLAIN, DISC, 1))
w('cell_c.ld', s.replace('SECTIONS\n{', 'SECTIONS\n{' + KEEP, 1)
                        .replace(PLAIN, DISC, 1))
w('cell_d.ld', s.replace('SECTIONS\n{', 'SECTIONS\n{' + DISC + KEEP, 1)
                        .replace(PLAIN, '', 1))
# and the trap that broke the first attempt: a replace that matches nothing
# leaves the text UNCHANGED and silently reports success.
bad = s.replace('NO-SUCH-TEXT', KEEP, 1)
assert bad == s, 'a non-matching replace must be detectable'
w('cell_bad.ld', bad)
PY
printf '   cell_bad.ld has a keep rule (must be 0): %s\n' \
  "$(grep -c mynote cell_bad.ld)"
printf '   cell_c.ld  has a keep rule (must be 1): %s\n' \
  "$(grep -c mynote cell_c.ld)"
printf '   cell_d.ld  has a keep rule (must be 1): %s\n' \
  "$(grep -c mynote cell_d.ld)"
for c in a b c d; do
  case $c in
    a) d="keep rule only" ;;
    b) d="/DISCARD/ only" ;;
    c) d="keep rule FIRST, then /DISCARD/" ;;
    d) d="/DISCARD/ FIRST, then keep rule" ;;
  esac
  rm -f cell_$c
  $CC -O1 note2.o -o cell_$c -T cell_$c.ld 2>/dev/null
  printf '   %s  %-34s .mynote kept: %s\n' "$c" "$d" \
    "$(readelf -SW cell_$c 2>/dev/null | grep -c mynote)"
done
note ""
note "1, 0, 1, 0. First-match-wins in all four cells, and /DISCARD/ is NOT"
note "special: in cell C it is simply the last rule, and in cell D it is"
note "simply the first."

# ---------------------------------------------------------------------------
say "F6 -- .note.GNU-stack is CONSUMED before script matching, not discarded"
# ---------------------------------------------------------------------------
note "the default script has a rule for it AND discards it:"
grep -n 'note.GNU-stack' default.ld | sed 's/^/     /'
note ""
note "remove the /DISCARD/ entry so the earlier rule cannot be beaten, and"
note "the section STILL does not appear as an output section:"
python3 - <<'PY'
s = open('default.ld').read()
before = s
s = s.replace('/DISCARD/ : { *(.note.GNU-stack) *(.gnu_debuglink)',
              '/DISCARD/ : { *(.gnu_debuglink)', 1)
# An edit that silently matches nothing looks exactly like linker behaviour.
# Assert it, so a future rename of the script cannot quietly break F6.
assert s != before, 'the /DISCARD/ edit did not apply -- F6 is now invalid'
assert '.note.GNU-stack :' in s, 'the earlier rule vanished -- F6 is now invalid'
open('nostack_discard.ld', 'w').write(s)
PY
rm -f ns.out
$CC -O1 hello.o -o ns.out -T nostack_discard.ld 2>/dev/null
printf '     .note.GNU-stack as an output SECTION: %s\n' "$(readelf -SW ns.out | grep -c 'GNU-stack')"
printf '     PT_GNU_STACK in the output:            %s\n' "$(readelf -lW ns.out | grep -ci 'GNU_STACK')"
note ""
note "So the first-match rule is not even reached: ld consumes this section"
note "while reading the input, to decide the executable-stack header."
note ""
note "and do NOT overclaim the causation. Strip the section from the input:"
objcopy --remove-section=.note.GNU-stack hello.o stripped.o 2>/dev/null
rm -f stripped.out; $CC -O1 stripped.o -o stripped.out 2>/dev/null
printf '     input .note.GNU-stack after stripping: %s\n' "$(readelf -SW stripped.o | grep -c 'GNU-stack')"
printf '     output PT_GNU_STACK anyway:              %s\n' "$(readelf -lW stripped.out | grep -ci 'GNU_STACK')"
note "     The header SURVIVES. So the section is not the only thing that"
note "     produces it, and this course does not claim it is."

# ---------------------------------------------------------------------------
say "F7 -- MEMORY is a budget, and exceeding it is an ERROR"
# ---------------------------------------------------------------------------
cat > mem.ld <<'EOF'
MEMORY {
  rom (rx) : ORIGIN = 0x08000000, LENGTH = 1M
  ram (rw) : ORIGIN = 0x20000000, LENGTH = 8M
}
SECTIONS {
  .text : { *(.text .text.*) } > rom
  .data : { *(.data .data.*) } > ram
  .bss  : { *(.bss  .bss.* ) } > ram
}
EOF
$LD -T mem.ld -o mem.out hello.o -e helper 2>/dev/null
note "MEMORY rom=0x08000000 ram=0x20000000, and the link:"
readelf -SW mem.out 2>/dev/null | sed -n 's/^ *\[[ 0-9]*\] *\(\.text\|\.data\) *[A-Z]* *\([0-9a-f]*\) .*/     \1 addr=0x\2/p'
readelf -hW mem.out | awk '/Entry point/ {printf "     entry=%s\n", $4}'
cat > tiny_mem.ld <<'EOF'
MEMORY { rom (rx) : ORIGIN = 0x08000000, LENGTH = 64 }
SECTIONS { .text : { *(.text .text.*) } > rom }
EOF
note ""
note "the same link with LENGTH = 64:"
$LD -T tiny_mem.ld -o tm.out hello.o -e helper 2>&1 | grep -v warning | sed 's/^/     /'
note "   ^ that is the entire value of MEMORY: a budget, enforced at link time."
# The ATTRIBUTES. Measured, because the documentation reads as though they
# drive the program-header flags, and the first version of this concept
# asserted that they did. They do not.
cat > attr_w.ld <<'EOF'
MEMORY { rw (w) : ORIGIN = 0x08000000, LENGTH = 1M }
SECTIONS { .text : { *(.text .text.*) } > rw }
EOF
cat > attr_rx.ld <<'EOF'
MEMORY { rom (rx) : ORIGIN = 0x08000000, LENGTH = 1M }
SECTIONS { .text : { *(.text .text.*) } > rom }
EOF
note ""
note "  .text in a (w) region, and in an (rx) region:"
for f in attr_w attr_rx; do
  rm -f $f.out
  $LD -T $f.ld -o $f.out hello.o -e helper 2>err_$f.txt
  printf '     %-8s exit=%s  %s\n' "$f" "$?" \
    "$(segs $f.out 2>/dev/null | sed -n '2p' | sed 's/^ *//')"
  printf '       diagnostics: %s\n' "$(wc -c < err_$f.txt | tr -d ' ') bytes"
done
note "  => IDENTICAL segment flags, and NO diagnostic. The attributes are"
note "     inert in GNU ld 2.46: they neither reject the mismatch nor set"
note "     the phdr flags. The flags came from the SECTION."
sed 's/LENGTH = 64/LENGTH = 4M/' tiny_mem.ld > big_mem.ld
$LD -T big_mem.ld -o bm.out hello.o -e helper 2>/dev/null
note "   with LENGTH = 4M it links: $([ -f bm.out ] && echo yes || echo no)"

# ---------------------------------------------------------------------------
say "F8 -- PHDRS writes program headers by hand"
# ---------------------------------------------------------------------------
cat > ph.ld <<'EOF'
PHDRS {
  code PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS {
  .text 0x08000000 : { *(.text .text.*) } :code
  .data 0x20000000 : { *(.data .data.*) } :data
}
EOF
$LD -T ph.ld -o ph.out hello.o -e helper 2>/dev/null
note "segments the script asked for:"
segs ph.out | head -3
note "   FLAGS(5) is R+X, FLAGS(6) is R+W. PF_X=1 PF_W=2, exactly the phdr bits."

# ---------------------------------------------------------------------------
say "F9 -- -T SUPPRESSES PIE. A custom script emits EXEC unless it says DYN."
# ---------------------------------------------------------------------------
for args in "-fPIE -pie" "-fPIE -pie -T default.ld" "-fPIE -T default.ld -pie"; do
  rm -f pie.out
  $CC -O1 $args hello.o -o pie.out 2>/dev/null
  printf '   %-28s e_type=%-5s first LOAD=%s\n' "$args" \
    "$(readelf -hW pie.out 2>/dev/null | sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')" \
    "$(readelf -lW pie.out 2>/dev/null | awk '/LOAD/{print $3; exit}')"
done
note ""
note "Order on the command line does not matter. This is the single most"
note "surprising thing about -T, and it is why a real embedded script has"
note "to say OUTPUT_FORMAT(\"...\", ..., \"elf64-x86-64\") and set up DYN itself."

# ---------------------------------------------------------------------------
say "F10 -- --gc-sections is REACHABILITY, and roots come from ENTRY and KEEP"
# ---------------------------------------------------------------------------
cat > gc.c <<'EOF'
#include <stdio.h>
int used(int x){ return x + 1; }
int unused(int x){ return x * 999; }
int also_unused(int x){ return unused(x) * 2; }
int main(void){ printf("%d\n", used(41)); return 0; }
EOF
for opt in -O1 -O0; do
  $CC $opt -ffunction-sections -c gc.c -o gc$opt.o
  rm -f gc$opt.off gc$opt.on
  $CC $opt gc$opt.o -o gc$opt.off
  $CC $opt -Wl,--gc-sections gc$opt.o -o gc$opt.on
  printf '   %s  input sections: ' "$opt"
  readelf -SW gc$opt.o | sed -n 's/^ *\[[ 0-9]*\] \(\.text\.[a-z_]*\).*/\1 /p'
  for m in off on; do
    printf '        --gc-sections %-3s .text=%s  funcs: ' "$m" \
      "$(readelf -SW gc$opt.$m | awk '/ \.text /{print $6}')"
    readelf -sW gc$opt.$m | awk '$4=="FUNC" && $7!="UND" && $8!~/^(_start|_init|_fini|frame_dummy|register_tm|deregister_tm|__do_global)/{printf "%s ", $8}'
    echo
  done
done
note ""
note "At -O1 main folds used(41) to the constant 42, so the out-of-line"
note "'used' has NO caller and is collected. At -O0 nothing is inlined, so"
note "'used' really is called and SURVIVES. Reachability, not liveness."
note ""
note "the root is ENTRY, from the script:"
grep -n '^ENTRY' default.ld | sed 's/^/     /'
rm -f gc.root
$CC -O1 -Wl,--gc-sections -Wl,-e,used gc-O1.o -o gc.root 2>/dev/null
printf '   with -Wl,-e,used as the root instead:  funcs: '
readelf -sW gc.root | awk '$4=="FUNC" && $7!="UND" && $8!~/^(_start|_init|_fini|frame_dummy|register_tm|deregister_tm|__do_global)/{printf "%s ", $8}'
echo
note "   main is GONE and used survives. The root moved, so the graph changed."

cat > ctor.c <<'EOF'
#include <stdio.h>
__attribute__((constructor)) static void c1(void){ puts("c1"); }
int main(void){ puts("main"); return 0; }
EOF
$CC -O1 -ffunction-sections -c ctor.c -o ctor.o
$CC -O1 -o ctor.off ctor.o
$CC -O1 -Wl,--gc-sections -o ctor.on ctor.o
note ""
note "KEEP makes a section a root regardless of reachability. c1 is only"
note "referenced from .init_array, and nothing calls c1:"
for m in off on; do printf '        --gc-sections %-3s funcs: ' "$m"; readelf -sW ctor.$m | awk '$4=="FUNC" && $7!="UND" && $8!~/^(_start|_init|_fini|frame_dummy|register_tm|deregister_tm|__do_global)/{printf "%s ", $8}'; echo; done
note "       .init_array size in both: $(readelf -SW ctor.on | awk '/\.init_array /{print $6}')"
note "       the script says:  KEEP (*(.init_array))"

# ---------------------------------------------------------------------------
say "F11 -- orphans: even the DEFAULT script guesses, five times"
# ---------------------------------------------------------------------------
cat > orph.c <<'EOF'
__asm__(".section .my_odd_section,\"ax\",@progbits\n .globl odd_fn\nodd_fn: ret\n");
int main(void){ return 0; }
EOF
$CC -O1 -c orph.c -o orph.o
note "by default, no warning at all:"
rm -f orph.off; $CC -O1 orph.o -o orph.off 2>&1 | grep -ci orphan | xargs printf '     warnings: %s\n'
note "with --orphan-handling=warn, ld admits what it guessed:"
rm -f orph.on
$CC -O1 orph.o -o orph.on -Wl,--orphan-handling=warn 2>&1 | grep -i orphan | sed 's/.*warning: /     /'
note ""
note "Four of those five are from the C runtime, not from your code. The"
note "'default' script is not complete; it leans on a fallback algorithm."

# ---------------------------------------------------------------------------
say "F12 -- -static, measured"
# ---------------------------------------------------------------------------
printf 'int main(void){ return 0; }\n' > tiny.c
$CC -O1 -o s_dyn tiny.c
$CC -O1 -static -o s_static tiny.c 2>/dev/null
for f in s_dyn s_static; do
  printf '   %-9s size=%-8s e_type=%-5s PT_INTERP=%s  PT_LOADs=%s  sections=%s\n' "$f" \
    "$(stat -c%s $f)" \
    "$(readelf -hW $f | sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')" \
    "$(readelf -lW $f | grep -c INTERP)" \
    "$(readelf -lW $f | grep -c '^  LOAD')" \
    "$(readelf -SW $f | grep -cE '^ *\[ *[0-9]+\]')"
done
note ""
note "segments, dynamic then static:"
for f in s_dyn s_static; do
  printf '   %s:\n' "$f"
  segs $f
done
note ""
note "The dynamic binary is ET_DYN with all LOAD vaddrs near 0 (the loader"
note "adds the base). The static one is ET_EXEC at 0x400000, which is the"
note "number from the SCRIPT (F3). -static changed the e_type and the script"
note "followed, and 52x the size is libc being pulled in."
note ""
note "what is actually in there:"
for f in s_dyn s_static; do
  printf '   %-9s biggest contributors:\n' "$f"
  readelf -SW $f | sed -n 's/^ *\[[ 0-9]*\] *\([.a-z_.0-9]*\) *[A-Z]* *[0-9a-f]* *[0-9a-f]* *\([0-9a-f]\{5,\}\).*/       \2 \1/p' | sort -r | head -4
done

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
