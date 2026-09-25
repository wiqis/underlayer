/* COFF research sample: exercises relocations, sections, symbols. */
int add(int a, int b) { return a + b; }

int g_data = 42;
int g_bss;
static int s_data = 7;
const char g_str[] = "coff";
const char *g_ptr = "ptr";
int *g_addr = &g_data;

int table[4] = {1, 2, 3, 4};

int call_through(int (*fn)(int, int), int v) { return fn(v, v); }
int use(void) { return call_through(add, g_data); }
