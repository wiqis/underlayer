int helper(int v);
int entry(int x) { return helper(x) + 1; }
int helper(int v) { return v * 3; }
int main(void) { return entry(5); }
