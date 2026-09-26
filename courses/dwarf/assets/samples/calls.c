int g(int);
int f(int n) { int s = 0; for (int i = 0; i < n; i++) s += g(i); return s; }
int main(void) { return f(3); }
