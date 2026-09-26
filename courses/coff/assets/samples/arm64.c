extern int gvar;
int arr[4] = {1,2,3,4};
int rd(void) { return gvar; }
int wr(int v) { gvar = v; return 0; }
int idx(int i) { return arr[i]; }
int br(int v) { if (v) return rd(); return wr(v); }
