extern int other_fn(void) __attribute__((weak));
int call(void){ return other_fn ? other_fn() : 0; }
