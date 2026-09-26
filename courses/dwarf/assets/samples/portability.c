struct S { int a; char b[4]; };
int f(struct S *p, int i) { return p->a + p->b[i]; }
int g(void) { struct S s = {1,{2,3,4,5}}; return f(&s, 1); }
int main(void){ return g(); }
