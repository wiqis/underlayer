/* Hand-encoded ADRP words, placed with .inst so no assembler arithmetic is
   involved. llvm-objdump must decode the page delta we encoded on purpose. */
extern int g32;
int t1(void) { __asm__(".inst 0xf0000008"); __asm__("ldr w0, [x8]"); return 0; }
int t2(void) { __asm__(".inst 0xf0ffffc8"); __asm__("ldr w0, [x8]"); return 0; }
int t3(void) { __asm__(".inst 0x90000008"); __asm__("ldr w0, [x8]"); return 0; }
