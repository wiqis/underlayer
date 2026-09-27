/* a weak DEFINITION in this TU */
__attribute__((weak)) int maybe(int x) { return x - 1; }
int uses_weak(int a) { return maybe(a); }
