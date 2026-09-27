/* an UNDEFINED WEAK reference: may or may not be there */
extern int optional_hook(int) __attribute__((weak));
int probe(void) {
    if (optional_hook) { return optional_hook(5); }   /* the may-be-zero idiom */
    return -1;
}
