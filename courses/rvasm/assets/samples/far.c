/* far.c -- a global far from any single function, so that addressing it
 * forces the compiler to emit an address-forming pair in both of the two
 * forms this section compares.  Deliberately tiny. */
extern const long table[1024];
extern const char label[];
const long row = 7;
long pick(long i) { return table[i] + row; }
int name(void) { return label[0]; }
