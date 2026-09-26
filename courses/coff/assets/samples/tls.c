__declspec(thread) int counter = 5;
__declspec(thread) int shared_buf[4];
int read_it(void) { return counter + shared_buf[0]; }
