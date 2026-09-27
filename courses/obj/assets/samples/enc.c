extern int g32; extern long g64; extern int arr[8];
int f_pc32(void)  { return g32; }
int f_rip(void)   { return arr[0]; }
long f_movabs(void){ return g64; }
void f_call(void) { g32 = 1; }
int  f_jmp(void)  { return f_pc32(); }
