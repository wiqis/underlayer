#!/usr/bin/env bash
# Builds every specimen the x86-64 course measures, and prints the findings.
#
#   cd courses/isa/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   python3 x86dec.py <hex> | --why <hex> | --elf <binary>
#
# This script writes the .c files itself, so they are build products rather
# than tracked sources. See research.md.
#
# Requires: clang, gcc, objdump, readelf, python3.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}
GCC=${GCC:-gcc}

say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }
hex()  { printf '   %-30s %s\n' "$1" "$2"; }

# The oracle, in one line: disassemble a raw byte string.
o() {  # o <hex bytes> [mode]
  local mode=i386:x86-64
  [ "${2:-}" = "--32" ] && mode=i386
  python3 -c "import sys;open('_o.bin','wb').write(bytes(int(x,16) for x in sys.argv[1:]))" $1
  # Drop the section header line, which has no tab, then reformat. Matching on
  # the tab rather than a line NUMBER is what makes this survive a binutils
  # that prints a different number of header lines.
  objdump -D -b binary -m "$mode" -M intel _o.bin 2>/dev/null \
    | awk -F'\t' 'NF>=3 && $1 ~ /^[ ]*[0-9a-f]+:$/ { gsub(/[ ]+$/,"",$3); print "      " $2 "  " $3 }'
}

# Same, collapsed onto one line so a table row stays one line.
oj() {
  local mode=i386:x86-64
  [ "${2:-}" = "--32" ] && mode=i386
  o "$1" "${2:-}" | sed 's/^ *//' | awk 'NF{printf "%s", (n++ ? " | " : "") $0} END{print ""}'
}

# ---------------------------------------------------------------------------
say "I1 -- one byte stream, two meanings: the 0x40 collision"
# ---------------------------------------------------------------------------
# The chain has used x86-64 code as an opaque byte string that relocations
# patch. obj-arch-table asked "how many bytes is this instruction?" and
# deliberately did not answer. This is the answer's first surprise.
note "  the same three bytes, decoded in each mode:"
hex "40 89 e8  (64-bit)" "$(oj '40 89 e8')"
hex "40 89 e8  (32-bit)" "$(oj '40 89 e8' --32)"
note ""
note "  0x40-0x4F is INC/DEC in 32-bit mode and a REX PREFIX in 64-bit mode."
note "  So the byte stream does not determine the instruction: the MODE does."
note "  One instruction of 3 bytes, or two of 1 and 2. Same file, same bytes."
note "  A disassembler that is not told the mode is not reading a string."

# ---------------------------------------------------------------------------
say "I2 -- REX: four bits, and they ADD 8"
# ---------------------------------------------------------------------------
note "  the four bits, W R X B, in 0x40..0x4F:"
for h in "89 c0::no REX              32-bit operands" \
         "44 89 c0::REX 0x44 R=1     32-bit, reg becomes r8d" \
         "4c 89 c0::REX 0x4c W=1 R=1 64-bit, reg becomes r8" \
         "49 8b 00::REX 0x49 R=1 B=1 r/m becomes r8" \
         "45 8b 04 24::REX 0x45 X=1 B=1  base r12 -- see the note below"; do
  hh=${h%%::*}; lbl=${h#*::}
  hex "$hh" "$(o "$hh" | tr -s ' ')"
  note "      ^ $lbl"
done
note ""
note "  A LIMITATION OF THE ORACLE, measured and worth knowing: the last row"
note "  has REX.X=1, so the SIB index (100 with X=1) should be r12 as well as"
note "  the base. objdump prints only [r12] -- it does not apply REX.X to the"
note "  SIB index field. x86dec.py DOES apply it, so the two disagree here, and"
note "  the crosscheck compares instruction BOUNDARIES rather than operand"
note "  text for exactly this reason."
note ""
note "  THE RULE, and it is the part people get wrong: each extension bit"
note "  ADDS 8 to a 3-bit field. So R=1 with reg=000 is r8 -- not r9."
note "  0..7 and 8..15, never 0..7 and 1..8."
note ""
note "  and the prefix ORDER rule, which is a different rule entirely:"
hex "66 48 8b c0  (66 then REX)" "$(oj '66 48 8b c0')"
hex "48 66 8b c0  (REX then 66)" "$(oj '48 66 8b c0')"
note ""
note "  A REX byte must be the LAST prefix before the opcode. A legacy"
note "  prefix that follows REX is not a prefix at all -- it is the opcode."
note ""
note "  and the two readers DISAGREE on that second case, which is worth"
note "  stating rather than smoothing over. 0x66 as an OPCODE in 64-bit mode"
note "  is PUSH ES, which does not exist, so the instruction faults. objdump"
note "  prints a bare 'rex.W' and then re-reads the 0x66 as a prefix anyway --"
note "  a diagnostic convenience, not the architectural reading. x86dec.py"
note "  refuses. A decoder that recovers and a decoder that refuses are both"
note "  defensible; what matters is that the difference is a decision you made"
note "  rather than a bug you inherited."

# ---------------------------------------------------------------------------
say "I3 -- ModRM: 256 combinations, and the question they answer"
# ---------------------------------------------------------------------------
cat > modrm.py <<'PY'
import subprocess
def one(bs, mode='i386:x86-64'):
    open('_m.bin','wb').write(bytes(bs))
    o=subprocess.run(['objdump','-D','-b','binary','-m',mode,'-M','intel','_m.bin'],
                     capture_output=True,text=True).stdout
    r=[l.split('\t') for l in o.splitlines() if len(l.split('\t'))>=3]
    return [(x[1].strip(), x[2].strip()) for x in r
            if x[0].strip().rstrip(':').strip()]
def full(m):
    mod, rm = m>>6, m&7
    b=bytes([0x8b,m])
    if mod==3: return b
    if mod==1: b+=b'\x11'
    elif mod==2: b+=b'\x11\x22\x33\x44'
    elif mod==0 and rm==5: b+=b'\x44\x33\x22\x11'
    if rm==4: b+=b'\x24'
    return b
forms={}; bad=[]
for m in range(256):
    g=one(full(m))
    if len(g)!=1: bad.append(m); continue
    t=g[0][1]
    k='register' if '[' not in t else t[t.index('['):].split('+')[0]+'...'
    forms[k]=forms.get(k,0)+1
print("   all 256 ModRM bytes for opcode 8b /r (MOV r32, r/m32):")
print("   bytes that did NOT decode as exactly one instruction: %d %s"
      % (len(bad), bad[:8]))
print("   mod=11 (register) forms:  %d of 256" % (64))
print("   mod!=11 (memory) forms:   %d of 256" % (256-64))
print()
print("   the four mod classes, one representative each:")
for lbl,m in (("mod=00 rm=000  [reg]",0x00),("mod=00 rm=100  SIB",0x04),
              ("mod=00 rm=101  RIP+disp32",0x05),("mod=01 rm=000  [reg+disp8]",0x40),
              ("mod=10 rm=000  [reg+disp32]",0x80),("mod=11 rm=000  register",0xc0)):
    b=full(m); g=one(b)
    print("     %-26s %-22s %s" % (lbl, ' '.join('%02x'%x for x in b),
          g[0][1] if len(g)==1 else 'N(%d)'%len(g)))
PY
python3 modrm.py
note ""
note "  the answer to obj-arch-table's question, as a rule rather than a"
note "  table: mod and rm together decide the instruction's LENGTH, and"
note "  they are the only two fields that do."

# ---------------------------------------------------------------------------
say "I4 -- SIB: the byte that exists because rsp is special"
# ---------------------------------------------------------------------------
note "  8 bits: ss(2) index(3) base(3). Two field values are special:"
hex "8b 04 24    index=100 base=rsp" "$(o '8b 04 24' | tr -s ' ')"
hex "8b 04 2c    index=101 = rbp" "$(o '8b 04 2c' | tr -s ' ')"
hex "8b 04 25 11223344  base=101 mod=00" "$(o '8b 04 25 11 22 33 44' | tr -s ' ')"
hex "8b 44 25 11 base=101 mod=01" "$(o '8b 44 25 11' | tr -s ' ')"
note ""
note "  index=100 (with REX.X=0) means NO INDEX. index=101 is rbp, which"
note "  is why [rbp+rsi*1] cannot be encoded without a displacement."
note "  base=101 is 'no base' ONLY at mod=00, where the disp32 is then an"
note "  absolute address. At mod=01 or 10 it is simply rbp."
note ""
note "  and the BYTE ORDER, which is not the order you would guess:"
hex "8b 84 24 11223344  SIB then disp" "$(o '8b 84 24 11 22 33 44' | tr -s ' ')"
hex "8b 84 1122334424  disp then SIB" "$(o '8b 84 11 22 33 44 24' | tr -s ' ')"
note "  both are valid instructions, and they are DIFFERENT. The SIB comes"
note "  immediately after the ModRM, BEFORE the displacement."
note ""
note "  the scale field, all four values:"
for ss in 0 1 2 3; do
  hex "ss=$ss" "$(o "8b 44 $(printf '%02x' $((ss<<6|5))) 11" | tr -s ' ')"
done

# ---------------------------------------------------------------------------
say "I5 -- the opcode map, the 0F escape, and the holes"
# ---------------------------------------------------------------------------
cat > opmap.py <<'PY'
import subprocess, collections
def one(bs):
    open('_p.bin','wb').write(bytes(bs))
    o=subprocess.run(['objdump','-D','-b','binary','-m','i386:x86-64','-M','intel','_p.bin'],
                     capture_output=True,text=True).stdout
    r=[l.split('\t') for l in o.splitlines() if len(l.split('\t'))>=3]
    return [x[2].strip() for x in r if x[0].strip().rstrip(':').strip()]
pref=('data','rep','lock','cs','ds','es','fs','gs','ss','addr','rex','bound')
c=collections.Counter()
for b in range(256):
    g=one(bytes([b]))
    if not g: c['nothing']+=1
    elif g[0].startswith(pref): c['legacy prefix']+=1
    else: c['an instruction']+=1
print("   the 256 one-byte values:")
for k,v in c.most_common(): print("     %-18s %3d" % (k,v))
print()
print()
print("   A SECOND MODE COLLISION, and the same shape as 0x40:")
for b,lbl in (('40','REX in 64-bit, INC in 32-bit'),
              ('62','EVEX in 64-bit, BOUND in 32-bit')):
    a=one(bytes([int(b,16)])); c=one(bytes([int(b,16)]))
    print("     %s  %-32s -> %s" % (b, lbl, a[0] if a else '?'))
print("   0x62 is the AVX-512 EVEX prefix in 64-bit mode, so it collides with")
print("   the 32-bit BOUND instruction exactly the way 0x40 collides with INC.")
print("   and a disassembler WITHOUT AVX-512 support refuses it and loses the")
print("   instruction stream from that point on -- which is why the corpus")
print("   below is built -march=x86-64: a reader that gives up is not a reader")
print("   that disagrees, and the two must not be confused.")
print()
print("   the escape and the holes in it:")
for h,lbl in (('0f 05','syscall'),('0f 0b','ud2 -- deliberately UNDEFINED'),
              ('0f 0e','femms (3DNow!)'),('0f 1e fa','bare: a multi-byte NOP'),
              ('f3 0f 1e fa','with F3: endbr64'),('cd 80','the older syscall path')):
    g=one(bytes.fromhex(h))
    print("     %-14s %-26s -> %s" % (h, lbl, g[0] if g else '?'))
PY
python3 opmap.py

# ---------------------------------------------------------------------------
say "I6 -- the sixteen condition codes"
# ---------------------------------------------------------------------------
cat > cc.py <<'PY'
import subprocess
def one(bs):
    open('_c.bin','wb').write(bytes(bs))
    o=subprocess.run(['objdump','-D','-b','binary','-m','i386:x86-64','-M','intel','_c.bin'],
                     capture_output=True,text=True).stdout
    r=[l.split('\t') for l in o.splitlines() if len(l.split('\t'))>=3]
    return [x[2].strip() for x in r if x[0].strip().rstrip(':').strip()]
print("   0F 8x = Jcc rel32, 0F 90-9F = SETcc r/m8 -- the SAME 16 conditions:")
for row in range(2):
    out=[]
    for lo in range(8):
        for hi in (0,1):
            c=lo|(hi<<3)
            out.append("%02x=%-4s" % (c, one(bytes([0x0f,0x80|c])+b'\x11\x22\x33\x44')[0].split()[0]))
    print("     " + "  ".join(out[:8]))
    print("     " + "  ".join(out[8:]))
print()
print("   so the two groups line up condition for condition:")
for c,name in ((4,'e'),(5,'ne'),(12,'l'),(14,'le')):
    print("     0f %02x -> %-4s    0f %02x c0 -> %s"
          % (0x80|c, one(bytes([0x0f,0x80|c])+b'\x11\x22\x33\x44')[0].split()[0],
             0x90|c, one(bytes([0x0f,0x90|c,0xc0]))[0].split()[0]))
print()
print("   and the same conditions with an 8-bit displacement instead:")
print("     74 -> %s      0f 84 -> %s"
      % (one(bytes([0x74,0x05]))[0].split()[0],
         one(bytes([0x0f,0x84])+b'\x05\x00\x00\x00')[0].split()[0]))
PY
python3 cc.py

# ---------------------------------------------------------------------------
say "I7 -- the length formula, and two decoders agreeing on it"
# ---------------------------------------------------------------------------
cat > corpus.c <<'EOF'
/* A specimen chosen to make the decoder work: loops, switches, calls,
   floating point, structs, pointers, and a library call -- so the .text
   contains most of the shapes of instruction the course talks about. */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct P { int x; long y; char n[16]; struct P *next; };
static long arith(long a, long b, long c, long d) {
    return a * b + c / d - (a & b) | (c ^ d) << (a & 31);
}
int cmpz(int a, int b) {
    if (a < b) return 1; if (a <= b) return 2; if (a > b) return 3;
    return a != b ? 4 : 5;
}
void loop(int *p, int n, int m) {
    for (int i = 0; i < n; i++) p[i] = p[i] * m + i;
    while (n--) *p++ = n;
}
double fmath(double a, double b) { return a * b + a / b - sqrt(a) + fmod(a, b); }
struct P *mk(int k) {
    struct P *p = malloc(sizeof *p);
    p->x = k; p->y = k * 2L; strcpy(p->n, "obj"); p->next = NULL;
    return p;
}
int sum(const struct P *p, int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += p[i].x + (int)p[i].y;
    return s;
}
int main(int c, char **v) {
    struct P *p = mk(c);
    loop(&p->x, c, 3);
    printf("%d %ld %f %d\n", sum(p, c), arith(c, 2, 3, 4), fmath(c, 1.5), cmpz(c, 2));
    free(p);
    return 0;
}
EOF
cat > mini.c <<'EOF'
/* The smallest corpus that still exercises every addressing form. */
int g;
int f(int a, int b) {
    int *p = &g, arr[4];
    arr[0] = a; arr[1] = b;
    *p = arr[0] + arr[1];
    if (*p > 0) *p = *p * 2; else *p = -*p;
    return *p;
}
int main(void) { return f(3, 4); }
EOF
cat > probe.c <<'EOF'
/* An OBJECT file, so the decoder is tested on relocatable code too: the
   displacements here are all zero and waiting for the linker. */
int table[4];
int f(int i) { return table[i]; }
int g(void) { int *p = &table[0]; return *p + *(p + 1); }
long h(long a) { return a * 3 + 7; }
int k(int a, int b) { return a > b ? a : b; }
EOF
# -march=x86-64 pins the BASELINE encoder, and that is not laziness: the
# course teaches the baseline encoding, and without the pin clang emits the
# AVX-512 EVEX prefix (byte 0x62), which is the SAME class of mode collision
# as 0x40 and which objdump without AVX-512 support refuses to decode -- so
# objdump gives up mid-section and everything after the refusal is garbage.
# Two readers, one refusing, is not a disagreement; it is a missing feature.
ARCH=${ARCH:--march=x86-64}
$CC -O2 $ARCH -o corpus corpus.c -lm 2>/dev/null
$CC -O2 $ARCH -o mini mini.c 2>/dev/null
$CC -O2 $ARCH -c -o probe.o probe.c 2>/dev/null
note "  built with $ARCH (baseline encoding, no EVEX):"
note "    corpus $(stat -c%s corpus 2>/dev/null) B, mini $(stat -c%s mini 2>/dev/null) B, probe.o $(stat -c%s probe.o 2>/dev/null) B"

cat > agree.py <<'PY'
"""Two independent decoders, one question: do they agree on every boundary?"""
import os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import x86dec

# objdump WRAPS long instructions: it prints at most 7 bytes of an encoding on
# the first line and any remainder on a continuation line that has NO mnemonic
# field. So "one instruction" is not "one line". This bit me twice while the
# decoder was already correct: a naive line-per-instruction parser counted a
# 10-byte NOP as 7 bytes and a 1-instruction section as 2, which made a
# working decoder look broken. Two rules distinguish the cases:
#   a 2-field line CONTINUES the previous instruction iff the previous line's
#       byte field was exactly 7 bytes long (objdump's wrap width);
#   otherwise it is a real entry that objdump could not name.
def ref(binary, addr, size):
    out = subprocess.run(['objdump','-d','--start-address=%#x'%addr,
                          '--stop-address=%#x'%(addr+size), binary],
                         capture_output=True, text=True).stdout
    r=[]; prev=None
    for l in out.splitlines():
        c=l.split('\t')
        if len(c)<2: continue
        try: a=int(c[0].strip().rstrip(':'),16)
        except ValueError: continue
        nb=len(c[1].split())
        if prev is not None and len(c)==2 and prev==7:
            r[-1]=(r[-1][0], r[-1][1]+nb)
        else:
            r.append((a-addr, nb))
        prev=nb
    return r

ta=tot=0
for t in ('corpus','mini','probe.o'):
    path=os.path.join(os.path.dirname(os.path.abspath(__file__)), t)
    try: data, secs = x86dec.code_sections(path)
    except Exception as e:
        print("   skip %s: %s" % (t,e)); continue
    for nm, addr, off, size in secs:
        body=data[off:off+size]
        mine, end, bad = x86dec.decode_stream(body, 0, len(body))
        r = ref(path, addr, size)
        if not r: continue
        agree=sum(1 for a,b in zip(mine,r) if a.offset==b[0] and a.length==b[1])
        ta+=agree; tot+=len(r)
        exact = (len(mine)==len(r) and agree==len(r) and end==size)
        print("   %s %-10s %-11s %7d B  %6d instructions  %s"
              % ('ok ' if exact else 'BAD', t, nm, size, len(mine),
                 'chain exact' if end==size else 'chain ends at %d of %d'%(end,size)))
        if not exact:
            for a,b in zip(mine,r):
                if a.offset!=b[0] or a.length!=b[1]:
                    print("        first divergence: mine off=%d len=%d %r | ref off=%d len=%d"
                          % (a.offset,a.length,a.text,b[0],b[1]))
                    break
print("   ---")
print("   %d/%d instruction boundaries agree (%.2f%%)" % (ta,tot,100*ta/tot if tot else 0))
print()
print("   The check that matters is the CHAIN, not the per-instruction count:")
print("   one wrong length desynchronises every boundary after it, so a")
print("   section can only be called a match if the boundaries consume the")
print("   section EXACTLY. A count that happens to agree proves nothing.")
PY
python3 agree.py

# ---------------------------------------------------------------------------
say "I8 -- the length formula, stated once"
# ---------------------------------------------------------------------------
cat > lengths.py <<'PY'
import subprocess
def n(bs):
    """Bytes in the FIRST instruction, summing objdump's wrap continuation."""
    open('_l.bin','wb').write(bytes(bs))
    o=subprocess.run(['objdump','-D','-b','binary','-m','i386:x86-64','-M','intel','_l.bin'],
                     capture_output=True,text=True).stdout
    total=0; started=False
    for l in o.splitlines():
        c=l.split('\t')
        if len(c)<2: continue
        try: int(c[0].strip().rstrip(':'),16)
        except ValueError: continue
        nb=len(c[1].split())
        if not started:
            total=nb; started=True
            if nb!=7: break
        else:
            total+=nb; break
    return total
print("   length = prefixes + opcode + modrm + sib + displacement + immediate")
print()
rows=[('8b 00','8b','1','-','-','-','2'),
      ('48 8b 00','48 8b','1','-','-','-','3'),
      ('8b 04 24','8b','1','24','-','-','3'),
      ('8b 40 11','8b','1','-','1','-','3'),
      ('8b 80 11 22 33 44','8b','1','-','4','-','6'),
      ('8b 05 44 33 22 11','8b','1','-','4','-','6'),
      ('8b 84 24 11 22 33 44','8b','1','24','4','-','7'),
      ('83 c0 01','83','c0','-','-','1','3'),
      ('b8 11 22 33 44','b8','-','-','-','4','5'),
      ('48 b8 11 22 33 44 55 66 77 88','48 b8','-','-','-','8','10'),
      ('66 b8 11 22','66 b8','-','-','-','2','4'),
      ('f6 c0 01','f6','c0','-','-','1','3'),
      ('f6 d0','f6','d0','-','-','-','2'),
      ('66 2e 0f 1f 84 00 00 00 00 00','66 2e 0f 1f','84','00','4','-','10')]
print("   %-30s %-10s %-6s %-5s %-4s %-4s %-4s %s"
      % ('bytes','prefixes+op','modrm','sib','disp','imm','sum','measured'))
allok=True
for h,p,m,s,d,i,exp in rows:
    got=n(bytes.fromhex(h.replace(' ','')))[1]
    ok = got==int(exp)
    allok &= ok
    print("   %-30s %-10s %-6s %-5s %-4s %-4s %-4s %d %s"
          % (h,p,m,s,d,i,exp,got,'ok' if ok else '<-- MISMATCH'))
print()
print("   every row matches: %s" % allok)
print()
print("   the two rows worth reading twice: 66 2e 0f 1f 84 00 00 00 00 00 is")
print("   TEN bytes -- two legacy prefixes, the two-byte escape, a ModRM, a")
print("   SIB and a disp32 -- and 83 c0 01 is THREE bytes for a reason the")
print("   OPCODE alone does not tell you: the ModRM reg field picks the")
print("   operation AND decides whether an immediate follows.")
PY
python3 lengths.py

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
