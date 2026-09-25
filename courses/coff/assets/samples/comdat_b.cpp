inline int shared(int v) { return v * 3; }
int use_b() { return shared(11); }
