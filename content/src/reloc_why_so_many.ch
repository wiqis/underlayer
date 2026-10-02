// Relocations, PIC and PIE — Module 1: The Vocabulary
// Concept: the x86-64 relocation set, grouped by what it computes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_reloc_why_so_many() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why There Are So Many Kinds — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>Why There Are So Many Kinds</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Vocabulary &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The ELF x86-64 ABI defines about forty relocation types. A newcomer&rsquo;s reaction is usually that this is untidy, and the instinct to look for a tidier mental model is right &mdash; but the tidiness is not &ldquo;there are really only three&rdquo;, it is <em>&ldquo;a relocation is a verb applied to a symbol, and the verbs are few&rdquo;</em>.</p>
                <p>Here is one file exercising three of them, built three ways:</p>
                <div class="hex-dump">
                    <pre>/* g.c */
extern int g;
int  abs_val(void)   { return g; }               /* the VALUE   */
int *abs_addr(void)  { int *p = &amp;g; return p; } /* the ADDRESS */
int  rel_val(void)   { return g + 1; }
int  call_ext(void);
int  do_call(void)   { return call_ext(); }
</pre>
                </div>
                <div class="hex-dump">
                    <pre>$ for m in "-fno-pic -fno-pie" "-fPIE" "-fPIC"; do
    clang -O1 $m -c g.c -o g.o
    printf "%-16s " "$m"
    llvm-objdump-21 -r g.o | grep -oE 'R_X86_64_[A-Z0-9_]+' | sort -u | tr '\n' ' '
    echo
  done

-fno-pic -fno-pie   R_X86_64_32  R_X86_64_PC32  R_X86_64_PLT32
-fPIE               R_X86_64_PLT32  R_X86_64_REX_GOTPCRELX
-fPIC               R_X86_64_PLT32  R_X86_64_REX_GOTPCRELX
</pre>
                </div>
                <p>Three builds, three relocations, four distinct types across the lot. <strong>And note that PIE and PIC produce the same vocabulary for this source</strong> &mdash; the difference between them is not in the relocation set, it is in what the loader may do with it. That is <a href="/courses/reloc/lessons/pie-flags">the next module</a>, and it is worth holding in mind that <em>relocation type</em> and <em>code model</em> are different axes that the names happen to blur together.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Group the x86-64 types by <strong>what arithmetic they perform</strong>. Once grouped this way the apparent chaos is four ideas:</p>
                <div class="formula">
  1. ABSOLUTE -- write the symbol's ADDRESS into the field

     R_X86_64_64      8 bytes   the address
     R_X86_64_32      4 bytes   the address, TRUNCATED
     R_X86_64_32S     4 bytes   the address, must FIT in 32 signed

     32S exists so the linker can ERROR instead of
     silently truncating. A 64-bit address that does not
     fit in 32 bits is a bug, and 32S is how it gets
     caught.

  2. RELATIVE -- write a DISTANCE from this field to the symbol

     R_X86_64_PC64    8 bytes   S - P
     R_X86_64_PC32    4 bytes   S - P

     The only difference is width, and the 32-bit one is
     the ±2GB story (next concept).

  3. INDIRECTION -- write the address of a GOT SLOT

     R_X86_64_GOTPCREL / _GOTPCRELX    the slot's address
     R_X86_64_GOTPC32   the CONTENTS of the slot
     R_X86_64_GOTOFF64  the offset of the symbol from the GOT
     R_X86_64_GOTPC64   the address of a GOT slot, 64-bit

  4. DYNAMIC -- the LOADER fills these in, not the linker

     R_X86_64_RELATIVE   base + the addend
     R_X86_64_GLOB_DAT   the address of a global
     R_X86_64_JUMP_SLOT  ditto, for a function
     R_X86_64_COPY       make me a copy of this datum
     R_X86_64_TLSGD / GOTTPOFF / TPOFF32   thread-local

                </div>
                <p><strong>Group 4 is the one that surprises people, and it is a genuinely different category.</strong> Groups 1&ndash;3 are <em>the linker&rsquo;s</em> job: it knows every address because it chose every address. Group 4 is <em>the loader&rsquo;s</em> job, because the loader is the only party that knows where things will actually be in memory.</p>
                <p>That is the real dividing line in the whole table, and it is exactly the gap the <a href="/courses/sym/lessons/sym-hash">symbol-resolution course</a> found from the other side. <code>R_X86_64_PC32</code> is resolved by <code>ld</code>; <code>R_X86_64_GLOB_DAT</code> is resolved by <code>ld.so</code> at load time; and the same source file can contain both, which is why an object file&rsquo;s relocation list mixes two different resolution mechanisms with no marker distinguishing them other than the type value itself.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Groups 1&ndash;3 verified by watching the same source change:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -d --no-show-raw-insn g_nopie.o
0000000000000000 &lt;abs_val&gt;:
   0:  8b 05 00 00 00 00    movl  (%rip), %eax      # PC32
0000000000000000 &lt;abs_addr&gt;:
   0:  48 8d 05 00 00 00 00 lea   (%rip), %rax      # PC32, not 32
</pre>
                </div>
                <p>Both are <code>PC32</code>. Taking the address of a global and reading its value are the <em>same relocation</em>, and the difference between them is entirely in the instruction that consumes it. <strong>This is worth pausing on, because it is the reverse of the AArch64 finding</strong>: there, the type encoded the width; here, the type says nothing about the access and the opcode says everything. Same file format, opposite philosophy, because the two ISAs have different amounts of redundancy to exploit.</p>
                <p>Where the <code>32</code> form appears is the interesting part &mdash; it needs a genuine absolute address:</p>
                <div class="hex-dump">
                    <pre>$ cat vio.c
extern int ext_data;
int *leak(void){ return &amp;ext_data; }
$ clang -O1 -fno-pic -c vio.c -o vio_nopic.o
$ llvm-objdump-21 -r vio_nopic.o | sed -n '/.text/,/^$/p'
0000000000000001 R_X86_64_32   ext_data
$ llvm-objdump-21 -d vio_nopic.o | sed -n '/&lt;leak&gt;/,/ret/p'
   0:  b8 00 00 00 00    movl  $0x0, %eax
</pre>
                </div>
                <p><strong><code>R_X86_64_32</code> at offset 1, and the instruction is <code>movl $imm32, %eax</code>.</strong> The immediate field of that opcode is the only place a 32-bit absolute address fits, and the relocation sits inside it at offset 1 rather than at 0. Two details in one line: the offset tells you <em>which part of the instruction</em> the linker is patching, and the choice of <code>mov $imm32</code> rather than <code>lea</code> is what forced an absolute form at all.</p>
                <p>Now group 4, which is the loader&rsquo;s half, from a real linked binary:</p>
                <div class="hex-dump">
                    <pre>$ readelf -rW prog | grep -oE 'R_X86_64_[A-Z_]+' | sort | uniq -c
      4 R_X86_64_GLOB_DAT
      2 R_X86_64_JUMP_SLOT
$ readelf -rW prog | grep GLOB_DAT | head -2
 3fb0  ... R_X86_64_GLOB_DAT  __libc_start_main@GLIBC_2.34 + 0
 3fd8  ... R_X86_64_GLOB_DAT  lib_data + 0
</pre>
                </div>
                <p><code>JUMP_SLOT</code> for the two PLT functions, <code>GLOB_DAT</code> for the four data references, and <strong>not one <code>PC32</code> in the list</strong> &mdash; because at this point every intra-executable reference has already been resolved by <code>ld</code> and is no longer a relocation. The relocation section of a <em>linked</em> binary contains only what the loader still owes. That is the cleanest possible demonstration that groups 1&ndash;3 and group 4 are resolved at different times by different programs.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the vocabulary is this shape rather than some tidier shape: three encoding facts, each of which forces a group of types.</p>
                <div class="hex-dump">
                    <pre>  FACT                          FORCED RELOCATION FAMILY

  no absolute 64-bit             R_X86_64_64 / PC64
  addressing mode exists         (the only way to name an
                                  address is PC-relative or
                                  through the GOT)

  displacement is 32-bit         R_X86_64_PC32  and
  signed                         the whole jump-stub
                                  apparatus for anything
                                  beyond ±2GB

  the one mov that can take a    R_X86_64_REX_GOTPCRELX
  GOT operand was originally     (REX exists purely to
  a call opcode                  disambiguate this)
</pre>
                </div>
                <p>The third row is the one that makes the table look arbitrary until you know the history. <strong>On x86-64 the instruction that loads from a GOT slot was originally the <code>CALL</code> opcode.</strong> When the design gave it a second, entirely different meaning, every existing object file that contained the old meaning became undecodable &mdash; so the format added a <code>REX</code> prefix byte whose only job is to say &ldquo;this particular encoding means <code>mov</code> now&rdquo;.</p>
                <p>That single historical accident is why the most common relocation in modern position-independent code is called <code>R_X86_64_REX_GOTPCRELX</code>, and why the <code>X</code> is there. The <a href="/courses/obj/lessons/obj-pic">Object Files course</a> decomposed the name; this concept supplies the reason the decomposition was necessary at all. <strong>Three of the four tokens in that name are historical scar tissue.</strong></p>
                <p>And it has a measurable cost. A <code>REX</code> prefix is a byte, so the GOT-relative form is 7 bytes where the plain RIP-relative form is 6 &mdash; which is why <a href="/courses/obj/lessons/obj-pic">Position Independence</a> found that a data reference at offset 0x04 moved to 0x05 under <code>-fPIC</code>, and everything after it slid. The instruction grew by one byte because of a design decision made to preserve compatibility with binaries from 2003.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F2/,/F3/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[2\]/,/\[3\]/p'
</pre>
                </div>
                <p>Then classify rather than recall. Take these and put each in the right group, with the reason:</p>
                <div class="hex-dump">
                    <pre>  R_X86_64_PC32          R_X86_64_32S
  R_X86_64_PLT32         R_X86_64_GLOB_DAT
  R_X86_64_REX_GOTPCRELX R_X86_64_RELATIVE
  R_X86_64_GOTOFF64      R_X86_64_COPY

  1. Which are resolved by ld and which by ld.so?
  2. Which two exist only because a 64-bit value might not
     fit in 32 bits, and what is the difference in how they
     report that?
  3. R_X86_64_GOTPCREL writes the ADDRESS of a slot.
     R_X86_64_GOTPC32 writes the CONTENTS of a slot.
     Which is a LINK-time operation and which is a
     LOAD-time one? (Neither answer is "both".)
  4. Find a relocation in your own toolchain's output that
     is in group 4 and that you have never thought about.
</pre>
                </div>
                <p>Question 2 is the one that pays. <code>32</code> and <code>32S</code> compute the same value; the difference is entirely in what happens when the value does not fit. <code>32</code> <strong>truncates and continues</strong>, producing a binary that runs and is wrong. <code>32S</code> <strong>fails the link</strong>. The <code>S</code> is a suffix that buys you a diagnostic, and it is the only difference &mdash; which is a good example of a format encoding a policy decision in a type name.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept and <a href="/courses/reloc/lessons/reloc-arch-contrast">One Relocation, or Two</a> are one argument from two ends. That one asked why the <em>count</em> differs between architectures and answered with reach. This one asks why the <em>set</em> is large and answers with the same fact plus the historical accident of the <code>REX</code> prefix. Read together they say: <strong>the relocation vocabulary is a fingerprint of the instruction set, including the parts of the instruction set that were accidents.</strong></p>
                <p>Forward in the module, <a href="/courses/reloc/lessons/reloc-encoding-limits">The Limits That Shaped the Table</a> takes the &plusmn;2GB boundary that appears in group 2 and follows it to its consequence: what a linker does when a reference is further away than one instruction can reach. That is where jump stubs appear, and it is the one place in this course where a relocation record causes the linker to <em>invent an instruction</em> rather than patch a field.</p>
                <p>Into the symbol course, group 4 is the group that course already owned. <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> introduced <code>JUMP_SLOT</code> and <code>GLOB_DAT</code> as the two things the loader writes at startup, and <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is entirely about when a <code>GLOB_DAT</code> becomes a <code>COPY</code>. <strong>This concept is the format-level statement of what that course showed at the runtime level</strong>: group 4 is the set of relocations that survive the linker precisely so that something later can decide them.</p>
                <p>Back to the object files course, the connection is a correction of emphasis rather than of fact. <a href="/courses/obj/lessons/obj-relocations">The Fixup Record</a> presented the relocation record as a mechanism and asked what each field is for. <strong>This course asks the prior question &mdash; why there is a <em>type</em> field at all &mdash; and the answer is that the type is not bookkeeping, it is the entire instruction to the patcher.</strong> A relocation applier that reads the offset and the addend and ignores the type is not a simplification; on AArch64 it silently produces wrong addresses, as the previous concept showed.</p>
                <p>And the TLS concept later in this course is group 4&rsquo;s awkward member, because <code>R_X86_64_TLSGD</code> is a relocation that cannot be resolved by writing a number into a field. <a href="/courses/reloc/lessons/tls-model">The One Relocation That Calls the Loader</a> is where the four-group model has to be amended, and it is worth noticing that the amendment is forced by thread-local storage rather than by anything about the CPU.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/reloc-arch-contrast">Previous: One Relocation, or Two</a></span>
                <span>Next: <a href="/courses/reloc/lessons/reloc-encoding-limits">The Limits That Shaped the Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
