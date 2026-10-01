// The C11 atomics, so that the compiler's CHOICE is a measurement rather
// than an assumption.  Compiled TWICE: once with the A extension and once
// without it, and the difference is the course's central experiment.
//
// WHY __atomic AND NOT stdatomic.h.  `<stdatomic.h>` includes `<stdint.h>`,
// which includes glibc's `<bits/libc-header-start.h>`, and there is no RISC-V
// libc on this host, so the C11 header fails to compile at all.  The GCC
// builtins `__atomic_*` and `__sync_*` are compiler intrinsics and need no
// library at all -- which makes them the RIGHT choice here for a reason that
// is worth recording, because "we could not include the header" is a
// limitation and "the builtins are the only spelling that needs no libc" is a
// measurement about the toolchain.
//
// The functions are kept small and their arguments are USED, because the
// previous RISC-V course measured a -O1 dead-code elimination and reported it
// as a calling convention (its retraction R4).  Every function's return value
// depends on its pointer argument, so nothing here can be deleted.

int amo_fetch_add_seqcst(int *p, int v) {
    return __atomic_fetch_add(p, v, __ATOMIC_SEQ_CST);
}

int amo_fetch_add_relaxed(int *p, int v) {
    return __atomic_fetch_add(p, v, __ATOMIC_RELAXED);
}

int amo_exchange_seqcst(int *p, int v) {
    return __atomic_exchange_n(p, v, __ATOMIC_SEQ_CST);
}

int amo_exchange_relaxed(int *p, int v) {
    return __atomic_exchange_n(p, v, __ATOMIC_RELAXED);
}

void amo_store_release(int *p, int v) {
    __atomic_store_n(p, v, __ATOMIC_RELEASE);
}

int amo_load_acquire(int *p) {
    return __atomic_load_n(p, __ATOMIC_ACQUIRE);
}

int amo_or_relaxed(int *p, int v) {
    return __atomic_fetch_or(p, v, __ATOMIC_RELAXED);
}

// THE COMPARE-EXCHANGE LOOP.  The whole point of the concept is that
// compare-and-swap is a RETRY LOOP BY CONSTRUCTION on this architecture, so
// the source here is a loop on purpose and the measurement is what the
// compiler does with it.  Under rv64gc it becomes an `lr.w.aqrl` / `bne` /
// `sc.w.rl` / `bnez` sequence -- four instructions and two branches for one
// attempt, and the loop is IN THE OUTPUT rather than in a library call.
int amo_cas_loop(int *p, int expect, int want) {
    int e = expect;
    int r;
    do {
        r = __atomic_compare_exchange_n(p, &e, want, 1, __ATOMIC_SEQ_CST,
                                        __ATOMIC_SEQ_CST);
    } while (!r);
    return e;
}

// AND THE __sync SPELLING, which is the older builtin and which the compiler
// lowers DIFFERENTLY: __sync_bool_compare_and_swap takes no expected-out
// pointer, so the compiler has to carry the expected value in a register and
// reload the memory word to decide whether it changed.  Under rv64gc this
// produces TWO lr/sc pairs rather than one, which is a compiler decision with
// a real cost and nothing to do with the architecture.
int sync_cas_loop(int *p, int expect, int want) {
    int r;
    do {
        r = __sync_bool_compare_and_swap(p, expect, want);
    } while (!r);
    return r;
}