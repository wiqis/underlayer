#!/usr/bin/env bash
# Builds and runs the instrument for "How a CPU Executes Instructions", and
# prints the findings. The artifact IS the measurement program, so this script
# compiles it and reads its output.
#
#   cd courses/exe/assets/samples && ./build_samples.sh
#   python3 crosscheck.py
#   ./cycbench --quick        # a faster, noisier version
#
# Requires: gcc, objdump, python3. No perf, and that is a finding rather than
# a gap -- see research.md.

set -u
cd "$(dirname "$0")"
CC=${CC:-gcc}
CFLAGS=${CFLAGS:--O2}

say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
note() { printf '   %s\n' "$1"; }

# ---------------------------------------------------------------------------
say "E0 -- the machine, and why the compiler matters for this course"
# ---------------------------------------------------------------------------
note "  this is the machine every number below came from:"
if [ -r /proc/cpuinfo ]; then
  grep -m1 'model name' /proc/cpuinfo | sed 's/^ */    /'
  printf '    logical CPUs: %s   cores per socket: %s\n' \
    "$(grep -c '^processor' /proc/cpuinfo)" \
    "$(grep -m1 'cpu cores' /proc/cpuinfo | sed 's/.*: *//')"
fi
printf '    cache line: %s bytes\n' "$(getconf LEVEL1_DCACHE_LINESIZE 2>/dev/null || echo '?')"
for d in /sys/devices/system/cpu/cpu0/cache/index*; do
  [ -d "$d" ] || continue
  printf '    L%s %-4s %-6s %-4s ways, %s B line\n' \
    "$(cat $d/level 2>/dev/null)" "$(cat $d/type 2>/dev/null)" \
    "$(cat $d/size 2>/dev/null)" \
    "$(cat $d/ways_of_associativity 2>/dev/null)" \
    "$(cat $d/coherency_line_size 2>/dev/null)"
done
printf '    constant_tsc: %s   nonstop_tsc: %s\n' \
  "$(grep -qw constant_tsc /proc/cpuinfo && echo yes || echo NO)" \
  "$(grep -qw nonstop_tsc /proc/cpuinfo && echo yes || echo NO)"

note ""
note "  and the thing that decides what this course may claim at all:"
printf '    perf_event_paranoid = %s\n' "$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo '?')"
printf '    event sources: %s\n' "$(ls /sys/bus/event_source/devices/ 2>/dev/null | tr '\n' ' ')"
# The `cpu` entry in event_source/devices is the SOFTWARE event source, not a
# PMU, so its presence proves nothing. The authoritative test is whether perf
# can actually read a hardware event, and that is what is asked here.
if perf stat -e branch-misses true >/dev/null 2>&1; then
  note "    perf CAN read branch-misses here, so mispredictions are countable"
else
  note "    perf CANNOT read branch-misses in this guest. There is no hardware"
  note "    PMU, so mispredictions cannot be COUNTED -- only inferred from"
  note "    timing, and the two explanations cannot be told apart."
fi

# ---------------------------------------------------------------------------
say "E1 -- build the instrument"
# ---------------------------------------------------------------------------
$CC $CFLAGS -o cycbench cycbench.c 2>&1 | grep -E 'error|warning: .*(unused|clobber)' | head -5
[ -x ./cycbench ] || { note "  BUILD FAILED"; exit 1; }
note "  built ./cycbench"

note ""
note "  every bench function is 64-byte aligned, and that is not tidiness."
note "  The first version had two BYTE-IDENTICAL loops in one binary"
note "  measuring 0.79 and 2.13 ticks/iter, because one of them landed"
note "  where its body crossed a 64-byte fetch boundary. Alignment is"
note "  the difference between a usable instrument and a random number"
note "  generator, so it is asserted here rather than assumed:"
objdump -t cycbench 2>/dev/null \
  | awk '$NF ~ /^(b_|aligned_|branchless$|table_walk$)/ {print $NF, $1}' \
  | while read -r sym addr; do
      a=$((16#$addr))
      printf '      %-16s 0x%-8s %s 64\n' "$sym" "$addr" \
        "$([ $((a % 64)) -eq 0 ] && echo 'aligned  ' || echo 'MISALIGNED')"
    done
note ""
note "  every address must be a multiple of 64. crosscheck.py asserts it,"

# ---------------------------------------------------------------------------
say "E2 -- run it"
# ---------------------------------------------------------------------------
./cycbench | sed 's/^/  /'

# ---------------------------------------------------------------------------
say "E3 -- the noise floor, on its own, with nothing else running"
# ---------------------------------------------------------------------------
note "  the same body, twelve times, consecutive. This is the number that"
note "  decides the shape of the whole course."
python3 - <<'PY'
import subprocess, re, sys
# cycbench --quick prints the floor's fastest/slowest; run it a few times so
# the reader sees a range rather than one sample.
for i in range(3):
    out = subprocess.run(['./cycbench', '--quick'], capture_output=True,
                         text=True).stdout
    m = re.search(r'fastest ([\d.]+)\s+slowest ([\d.]+)\s+spread ([\d.]+)%', out)
    if m:
        print('      run %d:  fastest %-8s slowest %-8s spread %s%%'
              % (i + 1, m.group(1), m.group(2), m.group(3)))
print()
print("      => absolute timings from this machine are not publishable.")
print("         Every figure cycbench reports is therefore a RATIO or a")
print("         MINIMUM of interleaved repetitions, and the crosscheck")
print("         asserts the shape rather than the absolute value.")
PY

printf '\n\033[1mdone. Next: python3 crosscheck.py\033[0m\n'
