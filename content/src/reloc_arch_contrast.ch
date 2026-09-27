// Relocations, PIC and PIE — Module 1: The Vocabulary
// Concept: the same source, one relocation on x86-64 and two on AArch64.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_reloc_arch_contrast() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Relocation, or Two — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>One Relocation, or Two</h1>
            <div class="lesson-meta">22 min &middot; Module 1: The Vocabulary &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a source file. Nothing about it is architecture-specific, and nothing about it is position-dependent &mdash; every symbol is <code>extern</code>, so there is nothing local to reason about:</p>
                <div class="hex-dump">
                    <pre>/* v.c -- one extern datum of each access width, and a call */
extern int   g_i;        /* 4 bytes */
extern int  *g_p;        /* 8 bytes */
extern int   g_arr[8];   /* element is 4 bytes */
extern char  g_c;        /* 1 byte */
void sink(int);

int use(void) {
    sink(g_i); sink(*g_p); sink(g_arr[3]); sink(g_c);
    return 0;
}
</pre>
                </div>
                <p>Compile it twice, once per architecture, both with <code>-fno-pic</code>, and count the relocations each datum reference needed:</p>
                <div class="hex-dump">
                    <pre>$ clang -O1 -fno-pic -fno-pie                -c v.c -o v_x86.o
$ clang -O1 -fno-pic --target=aarch64-linux-gnu -c v.c -o v_arm.o
</pre>
                </div>
                <p><strong>x86-64 emits one relocation per datum reference. AArch64 emits two.</strong> Not because AArch64 is worse engineered, and not because the language differs. Because the two architectures can address memory over different ranges, and a wider range costs an extra instruction, and an extra instruction needs its own relocation.</p>
                <p>That is the whole concept in one sentence, and it has a consequence you will meet for the rest of this course: <strong>the relocation table is a property of the target, not of the program.</strong> A linker author does not implement &ldquo;one relocation per reference&rdquo;. They implement a <em>vocabulary</em>, and the vocabulary is whatever the target&rsquo;s instruction set happens to need.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Before the numbers, the shape. A CPU can only put a limited distance into a single instruction. A reference to a symbol therefore has to be expressed as <em>some instruction that can reach that symbol</em>, and if the symbol is further away than one instruction can reach, you need more than one.</p>
                <div class="formula">
  REACH, and what happens past it

  x86-64     RIP-relative displacement is SIGNED 32-bit
             -> one instruction reaches +/-2 GB
             -> 99.99% of real programs: ONE relocation

  AArch64    ADRP reaches +/-4 GB (the 4KB-aligned page)
             ADR  reaches +/-1 MB (within a page)
             -> anything not within 1MB needs ADRP + ADD/LDR
             -> TWO relocations, always, for a datum

  the low field is 12 bits because a page is 4KB = 2^12.
  That is not a coincidence: 2^12 is literally what a
  4KB page is, and the instruction encodes "offset within
  the page" so the pair can express any 4GB-aligned base
  plus any offset inside it.

                </div>
                <p><strong>So the two-relocation pattern is a consequence of a wider per-instruction reach, not a worse design.</strong> AArch64 traded one extra instruction for the ability to address the whole address space from a single <code>ADRP</code>. If x86-64 had a ±4GB displacement field it would need one relocation too &mdash; the extra instruction is the price of the range.</p>
                <p>And the corollary, which is the more useful half: <strong>if the reach were the same, the relocation counts would be the same.</strong> This is why you cannot reason about a relocation table without knowing the ISA, and why every tool that presents &ldquo;the ELF relocations&rdquo; as one list is quietly assuming x86-64.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The two dumps, side by side, and the pattern is immediate:</p>
                <div class="hex-dump">
                    <pre>  x86-64                                  aarch64
  OFFSET      TYPE        VALUE            OFFSET      TYPE        VALUE
  0000..0003  R_X86_64_PC32      g_i-0x4     0000..0008  R_AARCH64_ADR_PREL_PG_HI21  g_i
  0000..0008  R_X86_64_PLT32     sink-0x4     0000..000c  R_AARCH64_LDST32_ABS_LO12_NC g_i
  0000..000f  R_X86_64_PC32      g_p-0x4     0000..0010  R_AARCH64_CALL26            sink
  0000..0016  R_X86_64_PLT32     sink-0x4     0000..0014  R_AARCH64_ADR_PREL_PG_HI21  g_p
  0000..001c  R_X86_64_PC32  g_arr+0x8      0000..0018  R_AARCH64_LDST64_ABS_LO12_NC g_p
  0000..0021  R_X86_64_PLT32     sink-0x4     0000..0020  R_AARCH64_CALL26            sink
  0000..0028  R_X86_64_PC32      g_c-0x4     0000..0024  R_AARCH64_ADR_PREL_PG_HI21  g_arr+0xc
                                        ...     0000..0028  R_AARCH64_LDST32_ABS_LO12_NC g_arr+0xc
                                        ...     0000..002c  R_AARCH64_CALL26            sink
                                        ...     0000..0030  R_AARCH64_ADR_PREL_PG_HI21  g_c
                                        ...     0000..0034  R_AARCH64_LDST8_ABS_LO12_NC  g_c
</pre>
                </div>
                <p>Read the AArch64 column in pairs. <code>ADR_PREL_PG_HI21</code> at <code>0x30</code>, then <code>LDST8_ABS_LO12_NC</code> at <code>0x34</code>. Four bytes apart, every time. That is one <code>ADRP</code> and one <code>LDRB</code>:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py -v | grep -A2 'every LO12'
    ok    the two counts agree (one HI21 per LO12)              (4, 4)
    ok    every LO12 sits exactly 4 bytes after its HI21        [4, 4, 4, 4]
</pre>
                </div>
                <p><strong>Every single one. Not approximately &mdash; all four, checked programmatically.</strong> The pair is not a convention; it is the encoding, and the 4-byte gap is the width of the <code>ADRP</code> instruction.</p>
                <p>Now the second finding, which is the more interesting one and the reason to read the AArch64 <em>type names</em> carefully:</p>
                <div class="hex-dump">
                    <pre>  g_p   is a pointer        ->  R_AARCH64_LDST64_ABS_LO12_NC
  g_arr is an int element    ->  R_AARCH64_LDST32_ABS_LO12_NC
  g_c   is a char           ->  R_AARCH64_LDST8_ABS_LO12_NC
</pre>
                </div>
                <p><strong>Three different relocation types for &ldquo;load a datum&rdquo;, differing only in width.</strong> The x86-64 column has exactly one form, <code>R_X86_64_PC32</code>, for all three &mdash; because in an x86 instruction the width is already implied by the opcode, and the relocation does not repeat it.</p>
                <p>That is the finding that generalises: <strong>the relocation vocabulary is a function of the instruction encoding.</strong> AArch64 has fewer addressing modes than x86-64 but records more per relocation, because each of its load/store instructions covers a size <em>class</em> and the low field has to say which. x86-64 has thousands of opcodes and a uniform displacement, so its relocations are correspondingly uniform.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What this costs in practice, because the two-relocation pattern is not free. A PIC AArch64 build of the same file:</p>
                <div class="hex-dump">
                    <pre>$ clang -O1 -fPIC --target=aarch64-linux-gnu -c v.c -o v_arm_pic.o
$ llvm-objdump-21 -r v_arm_pic.o | sed -n '/.text/,/^$/p'
  0000000000000010  R_AARCH64_ADRP_PREL_PG_HI21  :got:g_i
  0000000000000014  R_AARCH64_LDST64_ABS_LO12_NC  :got:g_i:g_i
  0000000000000018  R_AARCH64_RELR              ...
</pre>
                </div>
                <p>The symbol name in each slot is the giveaway. <code>:got:g_i</code> is <strong>the GOT entry for</strong> <code>g_i</code>, and <code>:got:g_i:g_i</code> is the same slot read at a 64-bit width. <strong>Even in PIC, AArch64 needs two relocations per datum, because the GOT access is still a two-instruction sequence.</strong> x86-64 needs one, because its GOT access is a single <code>mov</code>.</p>
                <p>So the count is a property of the architecture that survives the code model. That has a real consequence for tool authors: <strong>a relocation-processing loop written as &ldquo;for each symbol, patch the reference&rdquo; is wrong on AArch64</strong>, and wrong in a way that produces plausible-looking output rather than an error, because a half-patched <code>ADRP</code>/<code>ADD</code> pair is still a valid instruction encoding pointing at the wrong place. The relocations must be processed as a set with an ordering constraint, not individually.</p>
                <p>One more thing worth noticing, and it is the asymmetry that trips people up: <strong>the call is one relocation on both architectures.</strong> <code>R_X86_64_PLT32</code> and <code>R_AARCH64_CALL26</code> are each a single PC-relative branch, because a call instruction encodes a 26-bit or 32-bit displacement <em>in the instruction itself</em> on both. Neither architecture needs a page/base split for control transfer, so neither pays the double cost.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F1/,/F2/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[1\]/,/\[2\]/p'
</pre>
                </div>
                <p>Then establish the rule rather than memorising the table:</p>
                <div class="hex-dump">
                    <pre>  1. Add a double to v.c. Recompile for both. How
     many relocations does the new reference get on each?

  2. Add a `char*` (a pointer to a pointer). Which
     LDST*_ABS_LO12_NC does AArch64 pick, and why is the
     answer not "LDST128"?

  3. Add a function call to a function DEFINED in the same
     file (not extern). Does it get a relocation on
     AArch64? Why is the answer different from the datum?

  4. Find an x86-64 build where a datum needs TWO
     relocations. (Hint: it needs a displacement that does
     not fit in 32 bits. You will need -mcmodel=.)
</pre>
                </div>
                <p>Question 4 is the one that closes the loop, and it is the reason this concept is not merely an AArch64 curiosity. <strong>x86-64 <em>does</em> have a two-relocation case</strong> &mdash; the <code>-mcmodel=large</code> and <code>-mcmodel=medium</code> code models exist precisely because a 32-bit displacement is not always enough, and they use the same <code>movabs</code>-plus-<code>add</code> shape that AArch64 uses unconditionally. The pattern is universal; the threshold is what differs. x86-64 pays it rarely, AArch64 pays it always.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the opening concept of the course and it exists to reframe something the <a href="/courses/obj">Object Files</a> course had to state without being able to explain. <a href="/courses/obj/lessons/obj-relocations">The Fixup Record</a> recorded that a linker implements &ldquo;a vocabulary per target&rdquo;, and <a href="/courses/obj/lessons/obj-pic">Position Independence</a> showed one x86-64 vocabulary changing under <code>-fPIC</code>. <strong>This concept supplies the reason the phrase exists</strong>: the vocabulary is dictated by how far one instruction can reach, and that is the one fact about an ISA that determines how many relocations a reference needs.</p>
                <p>Into the rest of the module: <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> takes the x86-64 half of this comparison and organises it &mdash; absolute against relative, and the three or four things a relocation can be asked to compute. <a href="/courses/reloc/lessons/reloc-encoding-limits">The Limits That Shaped the Table</a> is the same reach argument turned on x86-64 specifically, and it is where the &plusmn;2GB boundary and the jump-stub response live.</p>
                <p>The connection into the symbol course is about ordering, and it is the practical consequence of the two-relocation case. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> showed that a linker is a demand-driven left-to-right pass, and it did not need to say in what order the relocations <em>within one object</em> are applied. <strong>This concept is where that order stops being arbitrary</strong>: an <code>ADRP</code> must be applied before the <code>ADD</code> that consumes it, so a linker that processes relocations in file order and assumes independence produces code that assembles cleanly and computes the wrong address. That is the same class of bug as the map-file reading in the symbol course: <em>a tool that is silently order-dependent and reports success</em>.</p>
                <p>Finally, out to the platform layer. <a href="/courses/obj/lessons/coff-relocations">COFF Relocations</a> measured that COFF packs the type into the top four bits of a 32-bit field and that the i386 target distinguishes <code>DIR32</code> from <code>REL32</code> where x86-64 does not. That is the same lesson from a third direction: <strong>the relocation table is a target-specific artifact, and three formats disagree about where the type even lives.</strong> Once you accept that the vocabulary follows the encoding, COFF&rsquo;s four-bit type field stops looking like a space-saving trick and starts looking like a consequence &mdash; a target with few relocation kinds can afford a narrow field.</p>
            </div>

            <div class="lesson-footer">
                <span>Start of course</span>
                <span>Next: <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
