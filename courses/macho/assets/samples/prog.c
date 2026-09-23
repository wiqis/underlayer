int global_counter = 42;
int bss_counter;
static int helper(int x) { return x * 2; }
int add(int a, int b) { return helper(a) + b + global_counter; }
int main(void) { bss_counter = add(1, 2); return bss_counter & 0xff; }
