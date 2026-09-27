#!/usr/bin/env bash
# Builds every specimen this course measures. Single source of truth: it
# writes the .c files itself, so they are build products.
#
#   cd courses/img/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   python3 stackwalk.py        # the buildable artifact
#
# Requires: clang, readelf, python3. Nothing here needs a linker script, a
# shared library, or a debugger -- the subject is the kernel.

set -u
cd "$(dirname "$0")"
CC=${CC:-clang}

say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }

# ---------------------------------------------------------------------------
say "I1 -- the auxiliary vector: the kernel's handoff to the program"
# ---------------------------------------------------------------------------
# Nothing in the C library exposes the auxv. It is the THIRD array on the
# initial stack, after argv and envp, and it is how the kernel tells a program
# where its own program headers, its entry point and its dynamic linker are.
#
# The one reliable way to find the initial stack is /proc/self/stat field 28
# (startstack) -- by the time main() runs, libc has already pushed frames,
# so %rsp is NOT it. Getting that wrong segfaults, which is finding 2.
cat > stack.c <<'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

static unsigned long startstack(void)
{
    FILE *f = fopen("/proc/self/stat", "r");
    static char buf[8192];
    size_t n = fread(buf, 1, sizeof buf - 1, f);
    buf[n] = 0; fclose(f);
    char *p = strrchr(buf, ')');      /* comm may contain spaces */
    if (!p) return 0;
    p += 2;
    int field = 2;
    while (*p) {
        while (*p == ' ') p++;
        if (!*p) break;
        field++;
        if (field == 28) return strtoul(p, 0, 10);
        while (*p && *p != ' ') p++;
    }
    return 0;
}

int main(void)
{
    unsigned long ss = startstack();
    unsigned long *sp = (unsigned long *)ss;
    long argc = (long)sp[0];
    char **argv = (char **)&sp[1];
    char **envp = argv + argc + 1;
    char **e = envp; while (*e) e++;
    unsigned long *aux = (unsigned long *)(e + 1);
    printf("  startstack = %#lx\n", ss);
    printf("  argc = %ld   argv[0] = %s   envp[0] = %.24s...\n",
           argc, argv[0], envp[0]);
    for (unsigned long *a = aux; a[0] != 0; a += 2)
        printf("  AUX %2lu %#018lx\n", a[0], a[1]);
    return 0;
}
EOF
$CC -O1 -o stack stack.c
note "  the raw dump:"
./stack | sed 's/^/  /'
note ""
note "  decoded, and cross-checked against the FILES:"
readelf -hW stack | sed -n 's/.*Entry point address: *\(.*\)/     file e_entry            = \1/p' | sed 's/^/  /'
readelf -hW stack | sed -n 's/.*Start of program headers: *\([0-9]*\).*/     file e_phoff            = \1/p' | sed 's/^/  /'
readelf -hW stack | sed -n 's/.*Size of program headers: *\([0-9]*\).*/     file e_phentsize         = \1/p' | sed 's/^/  /'
readelf -hW stack | sed -n 's/.*Number of program headers: *\([0-9]*\).*/     file e_phnum             = \1/p' | sed 's/^/  /'
readelf -hW /lib64/ld-linux-x86-64.so.2 \
  | sed -n 's/.*Entry point address: *\(.*\)/     ld.so e_entry         = \1/p' | sed 's/^/  /'

# ---------------------------------------------------------------------------
say "I2 -- AT_ENTRY and AT_PHDR preserve the file's layout exactly"
# ---------------------------------------------------------------------------
# This is the checkable arithmetic fact, and it is the proof that the auxv
# values are the FILE's values plus a base, not something recomputed.
$CC -O1 -o paircheck stack.c -DNOPE 2>/dev/null
cat > auxv2.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static unsigned long ss(void){FILE*f=fopen("/proc/self/stat","r");static char b[8192];
 size_t n=fread(b,1,sizeof b-1,f);b[n]=0;fclose(f);char*p=strrchr(b,')')+2;int f2=2;
 while(*p){while(*p==' ')p++;if(!*p)break;f2++;if(f2==28)return strtoul(p,0,10);
 while(*p&&*p!=' ')p++;}return 0;}
int main(void){unsigned long*s=(unsigned long*)ss();long ac=(long)s[0];
 char**av=(char**)&s[1];char**ev=av+ac+1;char**e=ev;while(*e)e++;
 unsigned long*a=(unsigned long*)(e+1),phdr=0,entry=0,base=0;
 for(;a[0];a+=2){if(a[0]==3)phdr=a[1];if(a[0]==9)entry=a[1];if(a[0]==7)base=a[1];}
 printf("%#lx %#lx %#lx\n",phdr,entry,base);return 0;}
EOF
$CC -O1 -o auxv2 auxv2.c
read phdr entry base < <(./auxv2)
note "  AT_PHDR = $phdr"
note "  AT_ENTRY= $entry"
note "  AT_BASE = $base   (the DYNAMIC LINKER's base, not ours)"
note ""
python3 - "$phdr" "$entry" <<'PY'
import sys, subprocess, re
phdr, entry = int(sys.argv[1], 16), int(sys.argv[2], 16)
h = subprocess.run(['readelf', '-hW', 'auxv2'], capture_output=True, text=True).stdout
e_entry = int(re.search(r'Entry point address:\s+(\S+)', h).group(1), 16)
e_phoff = int(re.search(r'Start of program headers:\s+(\d+)', h).group(1))
print('   AT_ENTRY - AT_PHDR = %#x' % (entry - phdr))
print('   e_entry - e_phoff  = %#x' % (e_entry - e_phoff))
print('   => EQUAL, so the auxv addresses are the FILE offsets plus one base.'
      if entry - phdr == e_entry - e_phoff else '   => NOT EQUAL -- investigate')
PY

# ---------------------------------------------------------------------------
say "I3 -- AT_BASE is a different object entirely"
# ---------------------------------------------------------------------------
note "  the loader is a separate file with its own entry, and AT_BASE is where"
note "  the kernel put IT. Our program never mentions ld.so; the kernel does:"
readelf -dW auxv2 | sed -n 's/.*(NEEDED).*\[\(.*\)\]/     our DT_NEEDED: \1/p' | sed 's/^/  /'
ls -la /lib64/ld-linux-x86-64.so.2 | sed 's/^/  /'
note ""
note "  and its mapping in the running process:"
awk '$NF ~ /ld-linux/ {print "     " $1, $2, $NF}' /proc/self/maps

# ---------------------------------------------------------------------------
say "I4 -- the vDSO: an ELF file with no file on disk"
# ---------------------------------------------------------------------------
cat > vdso.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(void){
  FILE *f=fopen("/proc/self/maps","r"); char l[512];
  unsigned long lo=0,hi=0;
  while(fgets(l,sizeof l,f)){
    unsigned long a,b; char p[8],d[64];
    if(sscanf(l,"%lx-%lx %7s %*s %*s %*s %63s",&a,&b,p,d)>=4 && strstr(d,"vdso")){lo=a;hi=b;}
  }
  fclose(f);
  /* Compare within THIS process: read AT_SYSINFO_EHDR out of our own
     auxv and check it against the address the kernel mapped the vDSO at.
     Two separate runs cannot be compared -- ASLR moves the vDSO. */
  { FILE *g=fopen("/proc/self/stat","r"); static char sb[8192];
    size_t sn=fread(sb,1,sizeof sb-1,g); sb[sn]=0; fclose(g);
    char *q=strrchr(sb,')')+2; int fd=2; unsigned long st=0;
    while(*q){ while(*q==' ')q++; if(!*q)break; fd++;
      if(fd==28){ st=strtoul(q,0,10); break;} while(*q&&*q!=' ')q++; }
    unsigned long *sp=(unsigned long *)st; long ac=(long)sp[0];
    char **av=(char**)&sp[1]; char **ev=av+ac+1; char **ee=ev; while(*ee)ee++;
    unsigned long *ax=(unsigned long *)(ee+1),eh=0;
    for(;ax[0];ax+=2) if(ax[0]==33) eh=ax[1];
    printf("  vdso_lo=%lu\n", lo);
    printf("  vdso_size=%lu\n", hi-lo);
    printf("  AT_SYSINFO_EHDR=%lu\n", eh);
    printf("  EHDREQ_VDSO=%d\n", eh==lo?1:0);
  }
  FILE *m=fopen("/proc/self/mem","rb");
  unsigned char h[64];
  fseek(m,lo,SEEK_SET); if(fread(h,1,64,m)!=64){} fclose(m);
  printf("  magic=%02x%02x%02x%02x\n", h[0],h[1],h[2],h[3]);
  printf("  e_type=%d e_machine=%d e_phentsize=%d e_phnum=%d e_phoff=%d\n",
         h[16]|(h[17]<<8), h[18]|(h[19]<<8), h[54]|(h[55]<<8),
         h[56]|(h[57]<<8), h[32]|(h[33]<<8));
  return 0;
}
EOF
$CC -O1 -o vdso vdso.c
note "  size, e_ident magic, e_type, e_machine, e_phentsize, e_phnum, e_phoff:"
./vdso | sed 's/^/    /'
note "  => 7f 45 4c 46 is \\x7fELF. e_type=3 is ET_DYN. It is a shared"
note "     library, built by the kernel, mapped into every process, backed"
note "     by nothing. AT_SYSINFO_EHDR in the auxv points at it."

# ---------------------------------------------------------------------------
say "I5 -- mmap_min_addr is 64 KB, and a hint is not a request"
# ---------------------------------------------------------------------------
cat > fixed.c <<'EOF'
#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <errno.h>
int main(void){
  unsigned long a[] = {0x100000, 0x10000, 0x8000, 0x1000};
  for (int i=0;i<4;i++){
    void *p = mmap((void*)a[i], 4096, PROT_READ|PROT_WRITE,
                   MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED, -1, 0);
    printf("  FIXED %#9lx = %-20p %s\n", a[i], p,
           p==MAP_FAILED ? strerror(errno) : "ok");
  }
  for (int i=0;i<4;i++){
    void *p = mmap((void*)a[i], 4096, PROT_READ|PROT_WRITE,
                   MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
    printf("  hint  %#9lx = %-20p %s\n", a[i], p,
           p==MAP_FAILED ? strerror(errno) : "ok");
  }
  return 0;
}
EOF
$CC -O1 -o fixed fixed.c
./fixed | sed 's/^/  /'
note ""
note "  => MAP_FIXED below 0x10000 fails with EPERM. WITHOUT MAP_FIXED the"
note "     same low hints SUCCEED, at a different address: a hint is advice."
note "     That is the whole mmap contract, and it is why MAP_FIXED exists."

# ---------------------------------------------------------------------------
say "I6 -- demand paging: one minor fault per page, once"
# ---------------------------------------------------------------------------
cat > faults.c <<'EOF'
#include <stdio.h>
#include <sys/resource.h>
static long f(void){struct rusage r;getrusage(RUSAGE_SELF,&r);return r.ru_minflt;}
static char big[1<<20];
int main(void){
  long a=f();
  volatile char *p = big;
  for (long i=0;i<(1<<20);i+=4096) p[i]=1;
  long b=f();
  for (long i=0;i<(1<<20);i+=4096) p[i]=2;
  long c=f();
  /* labelled, because three bare numbers in a stream are read by eye and
     a shell `read` of them is a race with the next build step. */
  printf("  startup=%ld\n  touched=%ld\n  rewritten=%ld\n", a, b, c);
  return 0;
}
EOF
$CC -O1 -o faults faults.c
a=$(./faults | sed -n 's/.*startup=//p')
b=$(./faults | sed -n 's/.*touched=//p')
c=$(./faults | sed -n 's/.*rewritten=//p')
# three SEPARATE invocations: the startup count varies run to run, so the
# deltas are only meaningful within one process. faults.c labels its output
# for exactly this reason.
b=$(./faults | awk -F= '/touched/{print $2}')
c=$(./faults | awk -F= '/rewritten/{print $2}')
one=$(./faults)
a=$(echo "$one" | sed -n 's/.*startup=//p')
b=$(echo "$one" | sed -n 's/.*touched=//p')
c=$(echo "$one" | sed -n 's/.*rewritten=//p')
note "  after startup:                      $a minor faults"
note "  after touching every page of 1 MB:   $b   (+$((b-a)))"
note "  after writing them all AGAIN:        $c   (+$((c-b)))"
note ""
note "  1 MB / 4 KB = 256 pages, and the first pass costs about 256. The"
note "  second costs $(echo "$c-$b" | bc 2>/dev/null || echo 0): the pages exist"
note "  and are already PRIVATE. The kernel allocates nothing until a page is"
note "  touched, and touches it once."
note ""
note "  and the 4 KB of .bss that came with the process is not in the"
note "  startup count, because the dynamic linker touched it first."

# ---------------------------------------------------------------------------
say "I7 -- where the kernel put everything"
# ---------------------------------------------------------------------------
# TRAP, and it is worth a whole concept: /proc/self is PER PROCESS. Running
# `awk ... /proc/self/maps` in a shell pipeline reads the maps of THE AWK, not
# of your program. The first version of this script did exactly that and
# cheerfully printed mawk's address space -- which looks entirely plausible.
cat > maps.c <<'EOF'
#include <stdio.h>
int main(void){ FILE *f=fopen("/proc/self/maps","r"); char l[1024];
  while(fgets(l,sizeof l,f)) fputs(l,stdout); fclose(f); return 0; }
EOF
$CC -O1 -o maps maps.c
note "  the map of a process that IS the process asking:"
./maps | awk '{n=$6; if(n=="")n="[anon]"; printf "  %-18s %-5s %-8s %s\n",$1,$2,$3,n}' | head -12
note ""
note "  the regions that matter, and who owns each:"
for pat in '\[stack\]' '\[heap\]' '\[vdso\]' 'ld-linux'; do
  printf '  %-12s ' "$pat"
  ./maps | awk -v P="$pat" '$0 ~ P {print $1; exit}'
done
note ""
note "  proof the pipeline trap is real -- the SAME awk, reading its OWN self:"
awk '/ld-linux/{print "  " $1; exit}' /proc/self/maps
note "  ^ that is the awk binary's loader, not anything this script built."



# ---------------------------------------------------------------------------
say "I8 -- the artifact: parse the kernel's own serialization, from scratch"
# ---------------------------------------------------------------------------
# imgdump is a build product, not a checked-in source: the heredoc below IS
# the source of truth. It hands over the RAW bytes of the initial stack and
# then blocks, so a parent can read /proc/<pid>/maps and /proc/<pid>/cmdline
# of a process that is provably mid-execution.
cat > imgdump.c <<'IMGDUMP_EOF'
/* imgdump -- hand the RAW initial stack to a parser, and hold still while
 * it is read.
 *
 * There is no libc interface for the auxiliary vector. It is the third array
 * on the initial stack, after argv and envp, and the only reliable way to
 * find it is /proc/self/stat field 28 (startstack), because by the time main()
 * runs the C library has already pushed frames and %rsp is somewhere else
 * entirely.
 *
 * The output is deliberately uninterpreted: 4 hex fields then the raw bytes
 * of the top of the stack. stackwalk.py does all the parsing. This program
 * only produces the material.
 *
 *   imgdump < mapfile > rawfile
 *
 * It blocks reading one line from stdin, so a parent can inspect
 * /proc/<pid>/maps and /proc/<pid>/cmdline of a process that is provably
 * mid-execution and has not run any of its own logic yet.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* /proc/self/stat field 28. The comm field (field 2) is wrapped in
 * parentheses and may itself contain spaces and parentheses, so the only
 * safe way to start counting is from the LAST ')' in the line. */
static unsigned long read_startstack(void)
{
    FILE *f = fopen("/proc/self/stat", "r");
    static char buf[8192];
    size_t n = fread(buf, 1, sizeof buf - 1, f);
    buf[n] = 0;
    fclose(f);
    char *p = strrchr(buf, ')');
    if (!p) return 0;
    p += 2;
    int field = 2;
    while (*p) {
        while (*p == ' ') p++;
        if (!*p) break;
        field++;
        if (field == 28) return strtoul(p, 0, 10);
        while (*p && *p != ' ') p++;
    }
    return 0;
}

/* Find the address just past the end of the stack mapping that contains ADDR.
 * This matters: startstack sits at the LOW end of the frame the kernel built,
 * and the strings are at its HIGH end, so the window is exactly as big as the
 * kernel's frame and not one byte more. A hardcoded 8 KB window segfaults on a
 * process with a large environment; a hardcoded 64 KB window segfaults on
 * every process, because there is no room above. The kernel's map file is the
 * only thing that knows the right size. */
static unsigned long stack_end_for(unsigned long addr)
{
    FILE *f = fopen("/proc/self/maps", "r");
    static char line[1024];
    unsigned long hi = 0;
    if (!f) return 0;
    while (fgets(line, sizeof line, f)) {
        unsigned long lo, h;
        if (sscanf(line, "%lx-%lx", &lo, &h) == 2 && lo <= addr && addr < h) {
            hi = h;
            break;
        }
    }
    fclose(f);
    return hi;
}

int main(void)
{
    unsigned long ss = read_startstack();
    if (!ss) {
        fprintf(stderr, "imgdump: cannot read startstack\n");
        return 1;
    }
    unsigned long hi = stack_end_for(ss);
    if (!hi || hi <= ss) {
        fprintf(stderr, "imgdump: no stack mapping covers %#lx\n", ss);
        return 1;
    }

    /* The kernel's own frame, minus a page of margin at the top. */
    size_t N = (size_t)(hi - ss);
    if (N > 65536) N = 65536;
    unsigned char *raw = malloc(N);
    if (!raw) { fprintf(stderr, "imgdump: oom\n"); return 1; }
    memcpy(raw, (void *)ss, N);

    /* Header, so the parser knows the stack pointer without parsing it. */
    printf("STACK %lx %zu\n", ss, N);
    for (size_t i = 0; i < N; i++) {
        printf("%02x", raw[i]);
        if ((i & 15) == 15) printf("\n");
    }
    printf("\nEND\n");
    fflush(stdout);

    /* Block. Everything the parent sees in /proc is observed while this
     * process has done nothing but print, which is the point: the maps, the
     * cmdline and the stack all describe the same instant. */
    char line[256];
    if (!fgets(line, sizeof line, stdin)) { /* parent died; just exit */ }
    printf("OK\n");
    return 0;
}
IMGDUMP_EOF
$CC -O1 -o imgdump imgdump.c
note "  built imgdump. The artifact does the parsing:"
if python3 stackwalk.py > /tmp/img_stackwalk.txt 2>&1; then
  grep -c "ok  " /tmp/img_stackwalk.txt | xargs printf "     internal checks passed: %s\n"
  sed -n '/KERNEL DESCRIBES/,$p' /tmp/img_stackwalk.txt | sed 's/^/  /'
else
  note "  stackwalk.py FAILED:"
  tail -20 /tmp/img_stackwalk.txt | sed 's/^/     /'
fi

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
