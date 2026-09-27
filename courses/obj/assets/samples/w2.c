/* a STRONG definition of the same name, in a different TU */
int maybe(int x) { return x + 100; }
int other(void) { return maybe(1); }
