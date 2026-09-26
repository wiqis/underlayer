static const int table[4] = {1,2,3,4};
int g;
int sum(void) { int s = 0; for (int i=0;i<4;i++) s += table[i]; return s + g; }
