#pragma comment(linker, "/alternatename:foo=bar")
int foo(void) { return 1; }
int bar(void) { return foo(); }
