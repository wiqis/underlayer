// Object Files — Module 5: Emitting One
// Concept: build a complete, valid, linkable ELF64 relocatable object byte by
// byte, with no library, and watch a real linker accept it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_emit() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Writing One From Scratch — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Writing One From Scratch</h1>
            <div class="lesson-meta">24 min &middot; Module 5: Emitting One &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything in the first four modules was reading. <strong>This one is writing, and that is not a change of exercise &mdash; it is a change of what you know.</strong></p>
                <p>A reader can hold a specification open. A writer cannot. <strong>To read an object file you need to know which fields exist; to write one you need to know which fields are <em>load-bearing</em>, which are conventions, and which are optional &mdash; and the only way to find out which is which is to emit a file and see whether a real linker accepts it.</strong></p>
                <p>So here is the mission's &ldquo;from scratch, not by delegation&rdquo; rule made concrete. <code>emit_elf.py</code> in this course's <code>assets/samples/</code> writes a relocatable ELF64 x86-64 object file with nothing but Python's <code>struct</code> module. <strong>No library formats a single byte.</strong> Every field is computed and packed by hand, and the acceptance test is not &ldquo;it parses&rdquo; but &ldquo;a production linker links it, the resulting program runs, and it prints the right answers.&rdquo;</p>
                <div class="hex-dump">
                    <pre>  $ python3 emit_elf.py hand.o
  wrote hand.o  (936 bytes)
    ELF header      0x0000 .. 0x0040
    .text          0x0040 .. 0x0057  (23 bytes)
    .data          0x0058 .. 0x0064  (12 bytes)
    .rela.text     0x0068 .. 0x0098  (48 bytes)
    .rela.data     0x0098 .. 0x00b0  (24 bytes)
    .symtab        0x00b0 .. 0x0140  (144 bytes)
    .strtab        0x0140 .. 0x0168  (40 bytes)
    .shstrtab      0x0168 .. 0x01a5  (61 bytes)
    section headers 0x01a8 .. 0x03a8  (8 x 64)
    e_phnum = 0   (no program headers: this is a relocatable file)
    relocation addends are in the RECORDS, not in the bytes
</pre>
                </div>
                <p>936 bytes, 8 section headers, 6 symbols, 3 relocations. <strong>That is the whole minimum.</strong> Not a demonstration &mdash; a working object file that GNU ld merges with compiler-produced objects and whose program computes the right answer.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Before the bytes, the plan, because the plan is the transferable part and the bytes are just the plan in a different notation. The object being built is the equivalent of this C:</p>
                <div class="formula">
  extern int helper(int);        /* defined elsewhere            */
  int   answer = 41;             /* .data, no relocation needed   */
  int  *answer_ptr = &answer;    /* .data, needs an 8-byte abs    */

  int compute(int x)  return helper(x) + 1;      /* calls out     */
  int start(int x)    return compute(x);          /* calls in      */
</div>
                <p class="code-note">Function bodies shown brace-free, to fit the page. <code>compute</code> is <code>helper(x) + 1</code>; <code>start</code> is <code>compute(x)</code>.</p>
                <p>And the requirements that shape the emitter. Notice that each one is a requirement the format imposes, not a choice:</p>
                <div class="formula">
  R1  one section per permission class
      .text  needs SHF_ALLOC | SHF_EXECINSTR
      .data  needs SHF_ALLOC | SHF_WRITE
      A linker is allowed to make .data writable and .text
      not, so putting both in one section would lose that.

  R2  every offset in a relocation is SECTION-RELATIVE
      because the relocation section header's sh_info says
      which section.  The record does not repeat it.

  R3  the addend lives in the RECORD
      x86-64 is RELA, so the section bytes stay zero and
      the bias of -4 goes in r_addend.

  R4  locals precede globals in .symtab
      sh_info of a symtab is the index of its first
      non-local symbol.  A file with a global before a
      local is malformed in a way most readers ignore.

  R5  section 0 is the reserved null entry
      and index 0 in .symtab is the reserved null symbol,
      so the first real section is 1 and the first real
      symbol is 1.
</div>
                <p>And the two requirements that are <em>conventions</em> rather than rules, which is worth separating because it is the hardest thing to learn from a specification: <strong>nothing requires the <code>.strtab</code> to begin with a NUL byte</strong>, yet every producer emits one and <code>st_name == 0</code> depends on it; and <strong>nothing requires sections to be 8-byte aligned</strong>, yet every producer does it. The emitter in this course does both, with a comment saying why, because <strong>a file that is merely legal and a file that behaves like every other file are different targets and only the second one is worth shipping.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The two calls, and why the addend is -4</h3>
                <p><code>start</code> is ten bytes and <code>compute</code> is thirteen, and the relocation offsets are <strong>5</strong> and <strong>15</strong>:</p>
                <div class="hex-dump">
                    <pre>  .text, 23 bytes, from the file at 0x40

  00000040: 8b44 2404 e800 0000 00c3 8b44 2404 e800  .D$........D$...
  00000050: 0000 0083 c001 c3                        .......

  offset 0x00  start:
      8b 44 24 04     movl 4(%rsp), %eax
      e8              call rel32          - opcode at 0x04
      00 00 00 00                      - the FIELD, at 0x05, zero
      c3              ret
  offset 0x0a  compute:
      8b 44 24 04     movl 4(%rsp), %eax
      e8              call rel32          - opcode at 0x0e
      00 00 00 00                      - the FIELD, at 0x0f, zero
      83 c0 01        addl $1, %eax
      c3              ret
</pre>
                </div>
                <p><strong>Note that the two calls are at different instruction offsets but the same offset <em>within</em> the instruction</strong> &mdash; byte 1 of a five-byte <code>e8 rel32</code>. That is the whole reason the field is at 5 and 15 and not at 4 and 14, and it is the concrete form of the claim <a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> made about three different instruction lengths sharing one 4-byte field. <a href="/courses/obj/lessons/obj-arch-table">The encodings concept</a> takes that further with AArch64, where the field is not even contiguous.</p>
                <p>And the addend. Both records carry <code>-4</code>:</p>
                <div class="hex-dump">
                    <pre>  .rela.text, 48 bytes, two 24-byte records, from 0x68

  00000068: 0500 0000 0000 0000 0200 0000 0500 0000  ................
  00000078: fcff ffff ffff ffff 0f00 0000 0000 0000  ................
  00000088: 0400 0000 0100 0000 fcff ffff ffff ffff  ................

  record 0                        record 1
    r_offset = 0x05                 r_offset = 0x0f
    r_info   = 0x0000000500000002   r_info   = 0x0000000100000004
             type 2 = PC32                   type 4 = PLT32
             sym  5 = compute                sym  1 = helper
    r_addend = -4                   r_addend = -4
</pre>
                </div>
                <p><strong>And <code>r_addend</code> is written with <code>struct.pack('&lt;QQq', ...)</code> &mdash; a <em>signed</em> 64-bit format.</strong> Using <code>Q</code> would produce <code>0xfffffffffffffffc</code> with no error at all, and the linker would compute a displacement of about 1.8&times;10<sup>19</sup> instead of -4. That is the <a href="/courses/obj/lessons/obj-addends">addend concept's</a> signed-field warning, and in an emitter it is not a reading exercise &mdash; it is a one-character bug.</p>

                <h3>The four bug classes, all of which were hit while writing this</h3>
                <p>Every one of these produced a file that <code>readelf</code> and <code>llvm-objdump</code> read <em>without a single warning</em>, and that linked and ran and printed wrong answers. They are the reason this concept exists.</p>
                <div class="hex-dump">
                    <pre>  BUG 1   e_shoff hardcoded to 64
          The header said the section table was at 0x40, where
          .text also was.  readelf printed garbage section
          headers and errored out.  FIX: pass the computed
          offset.  LESSON: layout is data, not a constant.

  BUG 2   sh_link and sh_info pointing at the wrong indices
          .rela.text had sh_link=8 and sh_info=2; the symtab
          is index 5 and .text is index 1.  The file PARSED.
          readelf warned that the link value was out of range,
          and every symbol name came out empty.  FIX: name
          the indices as constants and use them everywhere.
          LESSON: a relocation section's sh_link is the
          SYMTAB and its sh_info is the section being patched.
          Swapping them resolves every relocation against the
          wrong thing and looks fine.

  BUG 3   two objects in .data at the same offset
          `int answer` and `int *answer_ptr` both had
          st_value = 0, in an 8-byte .data.  They OVERLAPPED.
          The file was completely legal.  It linked, ran, and
          printed 389845008 -- an ADDRESS -- for `answer`,
          because the 8-byte pointer relocation wrote into the
          same four bytes the int lived in.  FIX: answer at 0,
          answer_ptr at 4, .data grown to 12 bytes.  LESSON:
          nothing checks symbol overlap.  Ever.

  BUG 4   addl $1 BEFORE the call instead of after
          compute(x) was emitted as (x+1) then call helper,
          so it computed helper(x+1), not helper(x)+1.
          The disassembly was plausible; the source comment
          said something else.  FIX: put the add after the
          call.  LESSON: when the bytes and the comment
          disagree, the bytes are the program.
</pre>
                </div>
                <p><strong>Bug 3 is the one worth dwelling on, because it is the only one that no tool reported.</strong> Overlapping symbols are not an error in ELF. The section has a size, the symbols have offsets and sizes, and nothing in the file says two symbols may not claim the same bytes. The result was a program that linked, ran, and printed a plausible large number. <strong>The only way it was caught was that the expected answer was 41 and the printed value was not 41.</strong> That is the honest state of affairs in object-file work, and it is the argument for the next concept.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The acceptance test, and then the proof that the holes were filled. This is the whole concept in one terminal session.</p>
                <div class="hex-dump">
                    <pre>  1. does readelf accept it, with no warnings?

  $ readelf -SW hand.o
    [ 1] .text             PROGBITS  000000 000040 000017 00  AX  0   0 16
    [ 2] .data             PROGBITS  000000 000058 00000c 00  WA  0   0  8
    [ 3] .rela.text        RELA      000000 000068 000030 18      5   1  8
    [ 4] .rela.data        RELA      000000 000098 000018 18      5   2  8
    [ 5] .symtab           SYMTAB    000000 0000b0 000090 18      6   1  8
    [ 6] .strtab           STRTAB    000000 000140 000028 00      0   0  1
    [ 7] .shstrtab         STRTAB    000000 000168 00003d 00      0   0  1

  $ readelf -sW hand.o
       1: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND helper
       2: 0000000000000000     4 OBJECT GLOBAL DEFAULT    2 answer
       3: 0000000000000004     8 OBJECT GLOBAL DEFAULT    2 answer_ptr
       4: 0000000000000000    10 FUNC   GLOBAL DEFAULT    1 start
       5: 000000000000000a    13 FUNC   GLOBAL DEFAULT    1 compute

  $ readelf -rW hand.o
  0000000000000005  0000000500000002 R_X86_64_PC32   0xa compute - 4
  000000000000000f  0000000100000004 R_X86_64_PLT32  0x0 helper  - 4
  0000000000000004  0000000200000001 R_X86_64_64     0x0 answer  + 0
</pre>
                </div>
                <p>Two independent readers agree, with no diagnostics. Now the real test &mdash; a production linker, compiler-produced companions, and execution:</p>
                <div class="hex-dump">
                    <pre>  $ gcc hand.o helper.o driver.o -o app
  $ ./app
  start(5)      = 11
  answer        = 41
  *answer_ptr   = 41   (answer_ptr == &amp;answer: yes)
</pre>
                </div>
                <p>And here is the payoff: <strong>the linker filled the holes, and you can see both the before and the after.</strong> From the hand-built object's own <code>.text</code>:</p>
                <div class="hex-dump">
                    <pre>  BEFORE, in hand.o                        AFTER, in the linked app
  .text+0x04  e8 00 00 00 00             start at 0x1140:
                                            1144: e8 01 00 00 00
  .text+0x0e  e8 00 00 00 00             1144 + 5 + 1 = 0x114a = compute
                                       compute at 0x114a:
  .data+0x04  00 00 00 00 00 00 00 00     114e: e8 0d 00 00 00
                                            114e + 5 + 0x0d = 0x1160 = helper

  .data+0x04  all eight bytes zero      .data in the executable, vaddr 0x4000:
                                          4000: 00 00 00 00 00 00 00 00
                                          4008: 08 40 00 00 00 00 00 00
                                          4010: 29 00 00 00            - 0x29 = 41
                                          4014: 10 40 00 00 00 00 00 00
                                                       ^^^^^^^^ 0x4010 = &amp;answer
</pre>
                </div>
                <p><strong>Every one of those numbers can be checked by hand, and every one of them is a consequence of a decision the emitter made.</strong> The <code>01</code> in <code>e8 01 00 00 00</code> is <code>compute - (start + 5)</code>. The <code>0d</code> is <code>helper - (compute + 5)</code>. The <code>10 40</code> is the address of <code>answer</code>. <strong>Three fields, three arithmetic operations, and the emitter contributed nothing to any of the final values &mdash; it contributed only the offsets and the addends that made the arithmetic possible.</strong></p>
                <p>Which is the last thing worth saying about writing object files, and it is the reason the mission puts this course before the linker course: <strong>the emitter's entire job is to describe where the holes are and what goes in them. Every value in the final binary is computed by someone else.</strong> A backend that gets the offsets and addends right and the instructions wrong produces a file that links; a backend that gets the offsets wrong produces one that does not. The failure modes are not symmetric, and knowing which is which is most of what this concept is for.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ python3 emit_elf.py /tmp/hand.o
$ readelf -a /tmp/hand.o | head -60
$ ld -r /tmp/hand.o -o /dev/null && echo "a real linker accepts it"</code></pre>
                <ul>
                    <li><strong>Emit it, then read it back with three tools and diff them against each other.</strong> <code>readelf -a</code>, <code>llvm-readobj-21 -a</code> and <code>llvm-objdump-21 -d -r</code> on the same file. <strong>Any field they disagree on is a place where one of them has an opinion, and working out which is the interesting part.</strong> Note the one deliberate difference: <code>readelf</code> prints a section symbol's name as the target section's name, while the symbol table stores <code>st_name = 0</code> for it. The file has no string; the tool is substituting one.</li>
                    <li><strong>Reproduce all four bugs deliberately, one at a time.</strong> Each is a one-line edit. <strong>For bug 2, watch <code>readelf</code>'s warnings and note that it still produced output</strong> &mdash; and then check whether <code>llvm-readobj-21</code> warns at all, because a reader that does not validate is the more dangerous one. For bug 3, the symptom is a plausible wrong number and no diagnostic from anyone. <strong>Reproducing a bug you have read about is worth far more than reading about it again.</strong></li>
                    <li><strong>Then fix them and re-verify, and notice how little changed.</strong> Each fix is one or two lines. <strong>The point of listing the bugs with their fixes is that the fix is never the hard part &mdash; identifying which of a dozen legal files is wrong is.</strong> That is the real skill, and it is why the next concept exists.</li>
                    <li><strong>Extend the emitter: add a third function and a <code>.bss</code> section.</strong> <code>.bss</code> is <code>SHT_NOBITS</code> with <code>sh_type = 8</code> and, crucially, <strong><code>sh_offset</code> pointing past the end of the file with no bytes in it</strong> &mdash; a detail worth getting wrong, because a reader that tries to read <code>sh_size</code> bytes from <code>sh_offset</code> will read whatever follows. <strong>Add the third function's <code>PLT32</code> against <code>helper</code> and confirm the linker resolves all three calls correctly.</strong></li>
                    <li><strong>Emit the same object for AArch64.</strong> Every field in the header and the tables is identical except <code>e_machine</code> and the four bytes of <code>.text</code>, which become the <code>ADRP</code>/<code>LDR</code> pair and the <code>RET</code> from <a href="/courses/obj/lessons/obj-arch-table">the encodings concept</a>. <strong>Make the same mistake twice &mdash; overlapping symbols &mdash; and observe that on this machine nothing will catch it, because there is no AArch64 linker here to fail.</strong> That is worth feeling directly: the verification you cannot do is the verification you will eventually miss.</li>
                    <li><strong>Try to make a file that a linker rejects, and understand each rejection.</strong> Try: a symtab with a global before a local; a relocation whose <code>sh_info</code> is out of range; an <code>r_info</code> with a symbol index past the end of the symtab; a <code>shstrndx</code> that does not point at a string table. <strong>Which of the four does GNU ld accept silently?</strong> The answer is the most useful single fact in this concept, and it is different for each.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: your emitter produces a file that <code>readelf</code> parses without a warning, <code>ld -r</code> accepts, and that links into a program which runs and prints one wrong number. Everything else about the program is correct. The <code>.data</code> section is 12 bytes, <code>answer</code> is declared <code>st_value = 0, st_size = 4</code>, and <code>answer_ptr</code> is <code>st_value = 8, st_size = 8</code>, both in section 2. What is wrong, why did no tool report it, and what general rule about object files does it illustrate?</p>
                <div class="quiz" id="quiz-obj-emit-1">
                    <button class="quiz-option" data-correct="true" data-explain="Nothing is wrong with the numbers given, which is exactly the difficulty. answer occupies bytes 0 through 3, answer_ptr occupies bytes 8 through 15, and .data is 12 bytes -- so answer_ptr claims four bytes past the end of the section. That is the actual defect, and it is invisible for two independent reasons. First, no tool validates it: overlapping or out-of-range symbol extents are not errors in ELF, because the section header already declares the section's size and a symbol's st_value is an offset into it, so a reader has no basis on which to object. The original overlap -- both symbols at offset 0 in an 8-byte section -- was the same class of bug and produced the same silence. Second, and more insidiously, the wrong number appears even when nothing is out of range, because the 8-byte R_X86_64_64 relocation at offset 4 writes eight bytes starting at 4, which covers 4 through 7, and the eight bytes at offset 8 belong to a different symbol. The linker's arithmetic was correct; the emitter's description of where the symbols were was not. The general rule is the strongest one in this concept: an object file has no internal consistency check on symbol placement. The section table bounds the section, the symbol table says where each symbol starts, and nothing cross-validates them. A validator has to compare sh_size against the maximum of st_value plus st_size, and compare st_value against sh_size, and clang's -fno-common variants of this bug have shipped in real toolchains. Which is the argument for the verification concept: correctness here comes from an oracle outside the file, not from the file itself." onclick="checkQuiz('obj-emit-1', this)">Nothing is wrong with the arithmetic you quoted &mdash; <code>answer_ptr</code> claims bytes 8 through 15 in a 12-byte section, so it runs four bytes past the end. <strong>ELF does not validate symbol extents against the section size, so no tool reports it</strong>, and the general rule is that an object file's two tables are cross-unchecked: the section header bounds the section, the symbol table claims offsets in it, and nothing validates one against the other. The linker's arithmetic was right; the emitter's <em>description</em> of where the symbols were was not</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the mechanism is misattributed in a way that points at the wrong part of the format. ELF does validate symbol placement against the section size, and it is this validation that would have caught the bug: a symbol whose st_value plus st_size exceeds the containing section's sh_size is a hard error, and readelf reports it. That is a real check and it does exist, so 'ELF does not validate' is false. What is true, and what the bug actually was, is subtler. The two symbols in the original failure were answer at st_value 0 with st_size 4, and answer_ptr at st_value 0 with st_size 8, in an 8-byte .data. Both fitted inside the section, so no size check could have fired -- they simply overlapped, each claiming bytes the other also claimed, and ELF has no rule against overlap because a section's size is a bound and not an allocation map. Two symbols may legally share a byte in this format. So the mechanism is not a missing bounds check but a missing exclusivity check, and the numbers in the question, with answer_ptr at 8 and st_size 8 in a 12-byte section, describe a different bug entirely: that one would be caught by a bounds check, if ELF had one, and the answer's claim that it does not is the part that has to be dropped. The general lesson survives in corrected form: nothing in an object file prevents two symbols from claiming the same bytes, so a backend must place symbols correctly on its own and cannot rely on the file to complain." onclick="checkQuiz('obj-emit-1', this)">The symbols overlap, and ELF does not validate symbol extents against the section size, so no tool reported it. The general rule is that a section header bounds the section and a symbol table claims offsets in it, with nothing cross-checking the two &mdash; which is why a validator must compute the maximum of st_value + st_size itself</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a backend for a new architecture. It must emit an object file your linker will accept. You have the specification, a reference producer, and a week. You write the header, the section table, the symbol table and the relocations, and you discover that the first file you emit is rejected with &ldquo;invalid section header&rdquo; while the second is accepted but produces a program that crashes on the first call. Given what this concept measured, what is the order in which you should build confidence, and what would you have to be able to check in order to tell a wrong <em>offset</em> from a wrong <em>instruction</em>?</p>
                <div class="quiz" id="quiz-obj-emit-2">
                    <button class="quiz-option" data-correct="true" data-explain="The order is: make the file legal first, then make it describable, then make it correct, and never try to do two of those at once. Make it legal means the header and the section table are self-consistent enough that a reader will walk them without complaining, because a file that will not parse tells you nothing about anything else. Make it describable means the symbol table, the string tables and the relocations are all present and internally consistent, so that readelf and an independent reader agree on what the file says -- at this point you can diff your output against a reference producer's field by field, and that diff is your real test. Only then does correctness become a question you can even ask. The last part is the substantive one. To tell a wrong offset from a wrong instruction you need three oracles, and they answer different questions. A disassembler tells you whether the bytes are the instructions you meant, which catches a wrong instruction and says nothing about an offset. The relocation dump tells you the offsets and types the file claims, which catches a wrong offset and says nothing about the instructions. And the linked-and-run binary tells you whether the two are mutually consistent, which is the only oracle that catches the case where both are wrong in compensating ways. The specific technique that makes the third usable is to write out the expected value by hand from the symbol table before linking, then compare it with what the linker produced. A mismatch localises the error to the emitter; a match with wrong behaviour means the arithmetic was right and the instruction was wrong. That distinction is the whole answer, and it is only available if you did the hand calculation while you still knew what the answer should have been." onclick="checkQuiz('obj-emit-2', this)">Build the file in three passes and test each separately. <strong>Legal</strong> first: a header and section table a reader will walk, so the file parses. <strong>Describable</strong> next: symbol and string tables and relocations that <code>readelf</code> and an independent reader agree on, so you can diff your output field by field against a reference producer. <strong>Correct</strong> last. To separate a wrong offset from a wrong instruction you need three oracles: a disassembler (is the byte sequence the instruction you meant?), a relocation dump (is the offset you claimed the offset the field is at?), and the linked binary (do the two agree?). <strong>The decisive technique is to hand-compute the expected value from the symbol table <em>before</em> linking and compare</strong> &mdash; a mismatch means a bad offset, a match with wrong behaviour means a bad instruction</button>
                    <button class="quiz-option" data-correct="false" data-explain="The ordering advice is reasonable, but the diagnosis method described here cannot work, and the reason is that it collapses the two failure modes it is supposed to separate. It proposes locating the error by taking the bad byte offset, applying the relocation by hand from the symbol table, and seeing whether the result matches what the linker produced. Consider the two cases this is meant to distinguish. If the offset is wrong, the hand calculation applies the relocation to the wrong field, so the hand value and the linked value agree -- both are 'the value that belongs at the field the file pointed at'. If the instruction is wrong, the hand calculation is still performed on the same field with the same symbol, so again the hand value and the linked value agree. In both cases the test passes, because the test never looks at the instruction at all. The two oracles it reaches for are also conflated: readelf -r reports what the file claims, not what is true, so if the offset is wrong readelf reports the wrong offset just as confidently as the right one, and comparing against it confirms nothing. What actually distinguishes the cases is a comparison the test does not make. You need the disassembly of the linked binary, which shows where the linker actually wrote the value relative to the real instruction boundaries, and the relocation dump of your own file, which shows where you said to write it. If those two positions differ, the offset was wrong. If they agree and the program still misbehaves, the instruction was wrong. The error is treating the linker's output as an oracle for the offset when the linker is faithfully obeying an offset you supplied." onclick="checkQuiz('obj-emit-2', this)">Make the file parse first, then get the relocation and symbol tables right, then worry about instructions &mdash; because an instruction bug shows up as a crash and an offset bug shows up as a wrong number, so they are easy to tell apart. To locate an offset bug, take the bad byte offset, apply the relocation by hand from the symbol table, and check whether the result matches what the linker wrote</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: an object file is a set of claims, and almost none of the claims are checked by anything. Build the file so that each class of claim can be falsified by a different oracle, in the order that lets the cheaper oracles speak first.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the mission's destination, and everything in the first four modules is scaffolding for it. <strong>The stated goal of the course is to emit an object file a real linker accepts, without using LLVM or any other backend to do it, and <code>emit_elf.py</code> is that goal met in 936 bytes.</strong> It is worth being precise about how small a claim that is: two functions, two data objects, three relocations, one undefined symbol. It is not a compiler. But every mechanism a production backend needs is in those 936 bytes &mdash; a section table, a symbol table with a weak and an undefined entry, a string table, a relocation set with an internal and an external reference, and a bias that only the record knows about.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-relocations">The Fixup Record</a> is the most direct in the course, because the emitter writes the records by hand and gets the packing wrong in instructive ways if it does not. <strong><code>r_info = (sym &lt;&lt; 32) | type</code> is not a fact to memorise; it is a fact to type correctly, four times, with the halves the right way round.</strong> And the signed <code>r_addend</code> is a one-character difference between <code>'q'</code> and <code>'Q'</code> in a format string, with no diagnostic. <a href="/courses/obj/lessons/obj-verify">The next concept</a> is about the class of bug where the tool is silent, and this is the smallest worked example of it in the course.</p>
                <p>Bug 3 &mdash; the overlapping symbols &mdash; connects straight back to <a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a>. <strong>COMMON exists precisely because C allows a symbol's storage to be claimed without being placed, and ELF responds with <code>SHN_COMMON</code>, a section index that means &ldquo;no section, size and alignment instead.&rdquo;</strong> That is a format explicitly acknowledging that symbol placement is a separate problem from section placement. The hand-built object has no COMMON symbols, and that is a choice: it places everything itself, and so has to be right. <strong>A backend that emitted tentative definitions as COMMON would hand the placement problem to the linker and would be wrong in a way this file cannot be.</strong> The bug is the mirror image of the feature, and seeing both makes the design decision legible.</p>
                <p>The bug-4 lesson &mdash; that the bytes and the comment can disagree &mdash; is a general point about working from specifications, and it is why the <a href="/courses/coff">COFF course's</a> harness discipline and the JVM course's crosscheck are not bureaucracy. <strong>A specification tells you what the bytes mean. It does not tell you what you meant.</strong> The comment in <code>emit_elf.py</code> that reads <code>compute(x): ... call helper ; addl $1,%eax</code> is a claim about the code, and when the bytes said otherwise the bytes were right and the comment was a lie. The only defence found in practice is to write the expectation down independently &mdash; in a comment, in a test, in a disassembler's output &mdash; and then compare.</p>
                <p>And there is a connection forward to the linker course, which is where the whole chain leads. <strong>The emitter's job ended when it wrote the offsets and addends; every value in the final binary was computed by GNU ld.</strong> The next step in the chain is to be the thing that computes them &mdash; and the four sections of this object, taken in the order the linker processes them, are a specification for a minimal linker: walk the section table, merge the symbol tables, resolve names, then walk the relocations applying <code>S + A - P</code> with the overflow check that the <a href="/courses/obj/lessons/obj-reloc-tables">relocation table concept's</a> <code>TYPE</code> flag exists to make possible.</p>
                <p>Next: the encodings that decide how big a fixup can be, which is the last piece of information you need before you can write the pass that applies them.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-weak-undef">Previous: Weak and Undefined-Weak</a></span>
                <span>Next: The Encodings That Set Relocation Size</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
