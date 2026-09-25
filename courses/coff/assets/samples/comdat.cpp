struct S { int a, b; };
inline S make(int v) { S s; s.a = v; s.b = v * 2; return s; }
int f() { S s = make(3); return s.a + s.b; }
template<class T> T twice(T v) { return v + v; }
int g() { return twice(21); }
