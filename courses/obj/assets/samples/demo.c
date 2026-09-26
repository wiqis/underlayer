/* One source, three object formats. Exercises every object-file mechanism
   a linker needs to see. */
int external_fn(int x);          /* defined elsewhere -> undefined symbol here */

int global_counter = 7;               /* .data, initialised, global  */
int uninitialised;                     /* .bss, zero-init, global     */
static int private_counter = 3;        /* .data, initialised, local   */
static int private_bss;                /* .bss,  local                */
const char *message = "hello";         /* pointer in .data, target in .rodata */
const char message_bytes[] = "hi";     /* .rodata, no relocation      */

static int helper(int x) { return x * 2; }   /* local .text, local symbol */
inline int inlined(int x) { return x + 1; }   /* emitted into a COMDAT/group */

int compute(int a, int b) {
    return helper(a) + private_counter + global_counter + uninitialised;
}

int call_out(int x) { return external_fn(x); }   /* call to an undefined symbol */

int use_data(void) { return message[0] + message_bytes[1]; }
