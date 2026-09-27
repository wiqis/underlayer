inline int shared_inline(int x) { return x + 1; }
int b(int v) { return shared_inline(v); }
