/* uwprobe.c -- what a PROFILER does when the second description of the frame
 * is absent.
 *
 * Built TWICE by build_samples.sh: once normally and once with
 * -fno-asynchronous-unwind-tables.  abidump.c runs both and reads the frame
 * counts off their standard output, so the number in the course is produced
 * by the unwinder and not typed in by an author.
 *
 * The instrument is `backtrace()` from glibc's execinfo, which is a real
 * consumer of `.eh_frame`: it is what GDB, perf and every crash reporter on
 * this machine use.  It is not a simulation of a profiler; it is one.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <execinfo.h>

__attribute__((noinline)) static int level3(void) {
    void *bt[32];
    int n = backtrace(bt, 32);
    /* A backtrace that cannot step out of level3 is a backtrace with one
     * entry in it: the caller of backtrace itself.  Say which. */
    printf("UNWINDTABLES %s\n", UNW_TABLES);
    printf("FRAMES %d\n", n);
    return n;
}

__attribute__((noinline)) static int level2(void) { return level3() + 1; }
__attribute__((noinline)) static int level1(void) { return level2() + 1; }

int main(void) {
    int n = level1();
    printf("STACKDEPTH %d\n", n);
    return 0;
}
