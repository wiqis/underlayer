inline int shared_inline(int x) { return x + 1; }
int a(int v) { return shared_inline(v); }
