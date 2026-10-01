// The fences, so that the ORDERING MODEL can be measured as something the
// compiler CHOOSES rather than something this course asserts.
//
// THE SIX C11 fence strengths, and what clang 21.1.8 emits for each at
// -march=rv64gc.  The interesting rows are not the ones you expect: a
// RELAXED fence emits NOTHING AT ALL (the function is a bare `ret`, which is
// the correct and most surprising measurement in the file), CONSUME and
// ACQUIRE are the SAME four bits, and ACQ_REL is the one that becomes
// `fence.tso` -- an instruction the architecture says is NOT a full barrier.

void fence_relaxed(void) { __atomic_thread_fence(__ATOMIC_RELAXED); }
void fence_consume(void) { __atomic_thread_fence(__ATOMIC_CONSUME); }
void fence_acquire(void) { __atomic_thread_fence(__ATOMIC_ACQUIRE); }
void fence_release(void) { __atomic_thread_fence(__ATOMIC_RELEASE); }
void fence_acqrel(void)  { __atomic_thread_fence(__ATOMIC_ACQ_REL); }
void fence_seqcst(void)  { __atomic_thread_fence(__ATOMIC_SEQ_CST); }

// THE ACCESSES, because the interesting finding is that an acquire LOAD and a
// sequentially-consistent LOAD are the SAME plain `lw` and the difference is
// discharged by a fence -- which is the opposite of AArch64, where the access
// itself carries the mode.  This is the course's sharpest cross-architecture
// contrast and it is a compiler's choice, so it is MEASURED.
int load_relaxed(int *p) { return __atomic_load_n(p, __ATOMIC_RELAXED); }
int load_consume(int *p) { return __atomic_load_n(p, __ATOMIC_CONSUME); }
int load_acquire(int *p) { return __atomic_load_n(p, __ATOMIC_ACQUIRE); }
int load_seqcst(int *p)  { return __atomic_load_n(p, __ATOMIC_SEQ_CST); }

void store_relaxed(int *p, int v) { __atomic_store_n(p, v, __ATOMIC_RELAXED); }
void store_release(int *p, int v) { __atomic_store_n(p, v, __ATOMIC_RELEASE); }
void store_seqcst(int *p, int v)  { __atomic_store_n(p, v, __ATOMIC_SEQ_CST); }

// A __sync full fence, which is the spelling a reader is most likely to meet
// in older code, and which must NOT be confused with a seq_cst fence.
void sync_full_fence(void) { __sync_synchronize(); }

// A pointer-published / pointer-observed pattern, which is the case a fence
// actually exists for, and which shows where the compiler puts the two.
static int published;
int publish(int v) { __atomic_store_n(&published, v, __ATOMIC_RELEASE); return v; }
int observe(void) { return __atomic_load_n(&published, __ATOMIC_ACQUIRE); }

// A seq_cst RMW, which is where the two aq/rl bits both get set and where the
// whole "the compiler sets BOTH bits and calls it sequentially consistent"
// claim can be read off a word.
int rmw_seqcst(int *p, int v) { return __atomic_fetch_add(p, v, __ATOMIC_SEQ_CST); }
int rmw_acqrel(int *p, int v)  { return __atomic_fetch_add(p, v, __ATOMIC_ACQ_REL); }
int rmw_acquire(int *p, int v)  { return __atomic_fetch_add(p, v, __ATOMIC_ACQUIRE); }
int rmw_release(int *p, int v)  { return __atomic_fetch_add(p, v, __ATOMIC_RELEASE); }