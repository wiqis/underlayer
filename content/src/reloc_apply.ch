// Relocations, PIC and PIE — Module 4: Applying One
// Concept: read a real object file, apply its relocations at an address you
// choose, and check the result. The course's buildable artifact.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_reloc_apply() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Applying Them Yourself — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>Applying Them Yourself</h1>
            <div class="lesson-meta">26 min &middot; Module 4: Applying One &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything in the previous three modules was reading. This one writes, and the whole point is that <strong>a relocation applier is not a large program.</strong> Three numbers and an arithmetic rule, plus enough ELF to find the fields:</p>
                <div class="formula">
  the entire spec

    S = the symbol's value
    A = the addend
    P = the ADDRESS OF THE FIELD BEING PATCHED

    PC-RELATIVE:   field := S + A - P
    ABSOLUTE:      field := S + A
    WIDTH:         how many bytes to store it in

  three numbers, one conditional, one store.
  everything else is finding the bytes.

                </div>
                <p>And the specimen is chosen so the answer is checkable. This is the constraint that makes the exercise possible, and it is worth stating before the code, because getting it wrong is the reason most attempts at this fail silently:</p>
                <div class="hex-dump">
                    <pre>$ cat closed.c
volatile int table[4] = {10, 20, 30, 40};
__attribute__((noinline)) int pick(int i){ return table[i &amp; 3]; }
int sum4(int i){ return pick(i) + table[(i + 1) &amp; 3]; }

$ clang -O1 -fno-pic -fno-pie -c closed.c -o closed.o
$ llvm-nm-21 -u closed.o
$                                        &lt;-- EMPTY. The object is closed.
</pre>
                </div>
                <p><strong>Every symbol it references is defined in it.</strong> That is what makes &ldquo;apply the relocations&rdquo; a question with a right answer instead of a question about a layout the applier was never told. Every other specimen in this course&rsquo;s sample directory references <code>extern</code>s, which makes them good for measuring and useless for building.</p>
                <p>Two annotations in that file are load-bearing, and both were found by measuring:</p>
                <div class="hex-dump">
                    <pre>  volatile:  at -O1 without it, the whole file
              collapses to a single 16-byte constant
              load from .rodata.cst16. nothing left
              to relocate.

  noinline:   without it `pick` is inlined, the call
              disappears, and with it the only
              PC-RELATIVE relocation in the file.
</pre>
                </div>
                <p><strong>The exercise needs one relocation of each rule, and without both annotations there is only one.</strong> That is not a C detail; it is a measurement lesson in disguise, and it is the same trap the <a href="/courses/reloc/lessons/tls-model">TLS concept</a> fell into with <code>-O1</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the applier has to hold in its head, and it is shorter than you expect.</p>
                <div class="formula">
  FOUR TABLES, and why each is unavoidable

  section headers   to find .text, .symtab, .strtab,
                    .rela.text  -- and to know where
                    the bytes of .text actually are

  symbols           S. st_value is an OFFSET WITHIN
                    ITS OWN SECTION, not an address,
                    because nothing is placed yet

  relocations       r_offset (which field), r_info
                    (which symbol, which type -- the
                    type is in the LOW 32 BITS, which
                    is why the 64-bit r_info exists),
                    r_addend (A)

  the layout        where each section will GO. not in
                    the object file. the applier's
                    choice, or a linker's.

  THE TRAP: S is
  section-relative and P is absolute. you must add the
  section's address to S before you can subtract P.
  doing the whole thing in section offsets gives a
  displacement that is right for offset 0 and wrong
  everywhere else -- which is why the base argument
  exists and why you should try two different bases.

                </div>
                <p><strong>That trap is the one to spend time on.</strong> For an <code>ET_REL</code> object, <code>st_value</code> is an offset within its section, because the section has no address until layout. So <code>S</code> must become <code>section_address + st_value</code> before it can be compared with <code>P</code>. Every tutorial on relocations gets this right and nobody ever says why it matters, because the example always has the symbol in the first section and the base at zero.</p>
                <p>Choose a base that is not zero, and the difference becomes impossible to miss &mdash; which is what the exercise does.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The three relocations, and the arithmetic for each, with every number shown:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -r closed.o | sed -n '/.text/,/^$/p'
0000000000000006 R_X86_64_32S    table
0000000000000014 R_X86_64_PLT32  pick-0x4
0000000000000020 R_X86_64_32S    table

$ python3 apply_relocs.py
closed.o  e_type=1  3 relocations in .rela.text
base = 0x400000

  0x0006  R_X86_64_32S    table  S=0x00000000 A=+0  -&gt;  value=0x4000f0
  0x0014  R_X86_64_PLT32  pick   S=0x00000000 A=-4  -&gt;  value=-0x18
  0x0020  R_X86_64_32S    table  S=0x00000000 A=+0  -&gt;  value=0x4000f0

all 3 relocations applied; 38 bytes of .text
</pre>
                </div>
                <p>Work the middle one by hand, because it is the only one with non-obvious arithmetic:</p>
                <div class="formula">
  R_X86_64_PLT32 at offset 0x14, symbol `pick`, A = -4

    S = 0            pick is at offset 0 in .text
    P = 0x400000 + 0x14 = 0x400014     <- the FIELD, not
                                        the instruction
    A = -4

    value = S + A - P
          = 0x400000 + (-4) - 0x400014
          = -0x18

  and the four bytes it becomes:
      e8 e8 ff ff ff
         ^^^^^^^^ little-endian 0xffffffe8 = -0x18
      e8 = the callq opcode

  VERIFY IT, from the instruction rather than the
  arithmetic: the call is at 0x13, so the CPU reads
  the displacement at 0x18.
      0x18 + (-0x18) = 0x00
  and 0x00 is where `pick` is. correct.

                </div>
                <p><strong>That last check is the whole exercise in one line.</strong> You do not need to trust the applier; you can read the bytes and see where they point. A tool you can verify by hand is a tool you can extend, and the ability to do that check is the difference between having written a linker and having called one.</p>
                <p>Now the off-by-one that makes this a real trap rather than a formality. <strong>The <code>callq</code> opcode is at <code>0x13</code>. The relocation field is at <code>0x14</code>.</strong> They are different addresses, one byte apart, because the opcode byte comes first:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -d --no-show-raw-insn closed.o | sed -n '/&lt;sum4&gt;/,/ret/p'
0000000000000010 &lt;sum4&gt;:
  10:  pushq %rbx
  11:  movl  %edi, %ebx
  13:  callq 0x18 &lt;sum4+0x8&gt;        &lt;-- the INSTRUCTION is at 0x13
  18:  incl  %ebx
  1a:  andl  $0x3, %ebx
  1d:  addl  (,%rdi,4), %eax
  24:  popq  %rbx
  25:  retq

$ python3 crosscheck.py -v | grep 'the callq opcode'
  ok    the callq opcode is at 0x13, one byte before its field  'e8'
</pre>
                </div>
                <p><strong>Use the instruction&rsquo;s address for <code>P</code> and every PC-relative relocation in the file is off by one.</strong> The result is a call into the middle of the <code>incl %ebx</code> at <code>0x18</code>, which is a perfectly valid instruction, in a perfectly valid program, that computes something else. It assembles. It links. It runs. It is wrong &mdash; and nothing anywhere reports it.</p>
                <p>And the absolute ones, for contrast, are the easy case and the reason this is a fair exercise:</p>
                <div class="hex-dump">
                    <pre>  R_X86_64_32S at 0x06, symbol `table`, A = 0

    S = 0x4000f0      .data was placed here by the layout
    P = 0x400006
    A = 0

    value = S + A     (no subtraction: ABSOLUTE)
          = 0x4000f0

  the bytes become f0 00 40 00, and the instruction
  reads them as the base of a scaled index:
      movl 0x4000f0(,%rax,4), %eax
  which is table[rax]. correct.
</pre>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The second thing the applier does, and it is the behaviour that separates a patcher from a truncator. <strong>It refuses.</strong> Push the load address high enough and a 4-byte field cannot hold the answer:</p>
                <div class="hex-dump">
                    <pre>$ python3 apply_relocs.py --all-bases
sweeping the load base until a 4-byte field stops fitting
(64MB steps, 0..4GB)...

  base=0x0040000000  ok
  base=0x0080000000  OVERFLOW: offset 0x6: R_X86_64_32S overflow:
    2147483888 does not fit in 32 signed bits
    (P=0x80000086, S=0x800000f0, A=0, ADDRESS)

  first failure at base=0x80000000  (== 2^31 exactly)
  the last base that worked was 0x7c000000
</pre>
                </div>
                <p><strong>Exactly 2<sup>31</sup>, and the breaker is the <em>absolute</em> relocation.</strong> That is the finding, and it is the direct payoff of the <a href="/courses/reloc/lessons/pie-randomize">randomisation concept</a>: translate the image and a <em>distance</em> is unchanged, so the <code>PLT32</code> kept working at every base in the sweep. The absolute form stores an <em>address</em>, and an address stops fitting in 32 bits once the base passes 2<sup>31</sup>. <strong>This is why the vocabulary has a PC-relative form at all, demonstrated by watching the other one break.</strong></p>
                <p>And that maps exactly onto the two relocation types the <a href="/courses/reloc/lessons/reloc-encoding-limits">third concept</a> paired off:</p>
                <div class="formula">
  R_X86_64_32   truncate and carry on
                -&gt; a binary that runs and is wrong
                -&gt; and NO diagnostic

  R_X86_64_32S  fail the link
                -&gt; no binary
                -&gt; and a message that names the symbol

  the applier implements the 32S policy, which is why
  it raises instead of truncating. that choice is the
  whole difference between a tool and a bug factory,
  and it costs one comparison.

                </div>
                <p>What the applier deliberately does <em>not</em> do, and the list is the interesting part:</p>
                <div class="hex-dump">
                    <pre>  IT DOES NOT                          WHY

  apply TLSGD / TLSLD         there is no arithmetic. the value
                              is a function result. see the
                              TLS concept.

  handle GOT-relative forms   they need a GOT, and deciding
                              what goes in the GOT is layout,
                              not patching.

  invent a jump stub          an out-of-range call needs MORE
                              INSTRUCTIONS, not a wider field.

  lay out sections           it accepts a layout. deciding the
                              layout is a different program with
                              a much harder problem.

  THAT DIVISION IS THE POINT. "apply the relocations that are
  arithmetic" is a complete, shippable, testable program. "be
  a linker" is not. Most of the difficulty of real linkers is
  on the other side of this line.
</pre>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh
$ python3 apply_relocs.py
$ python3 apply_relocs.py --show
$ python3 apply_relocs.py --all-bases
$ python3 crosscheck.py
  ALL 87 CHECKS PASS
</pre>
                </div>
                <p>Then extend it, in the order that builds understanding fastest:</p>
                <div class="hex-dump">
                    <pre>  1. BREAK IT ON PURPOSE. Change P from
     base + r_offset to base + r_offset - 1 and
     re-run. Then disassemble --show. Where does the call
     actually land now? (It lands in the middle of an
     instruction, and nothing tells you.)

  2. Change the base to 0. Which relocations change their
     value and which do not? (Only the absolute ones.
     Prove it with two runs and diff.)

  3. Add the GOT-relative case. Compile closed.c with
     -fPIC instead of -fno-pic. Now you need a .got.
     Decide: does it belong in this program or not?
     (Defending either answer is the exercise.)

  4. Add R_X86_64_PC64 and R_X86_64_64 to the table. They
     are one line each. Then find a construct that emits
     them -- -mcmodel=large is the obvious candidate.

  5. Make the applier REFUSE to run on a reloc type it
     does not know, rather than guessing. Then run it on
     a TLS object and watch it decline cleanly.
</pre>
                </div>
                <p>Exercise 1 is the one that teaches the most, and it takes thirty seconds. <strong>You have just broken the tool in the exact way everyone breaks it, and the only symptom is that the disassembly shows a call to a different address.</strong> There is no error, no warning, no non-zero exit. That is what an off-by-one in a relocation applier looks like from the outside, and having produced one deliberately makes the lesson stick in a way that reading about it does not.</p>
                <p>Exercise 5 is the professional version of the same instinct. <strong>Declining correctly is part of applying correctly</strong> &mdash; a tool that guesses at a relocation it does not understand will produce output, and that output will be wrong, and the wrongness will surface somewhere else entirely. The <code>apply_relocs.py</code> in this course&rsquo;s sample directory recognises the TLS relocations by name only so that it can refuse them with a message pointing at the concept; everything else it does not recognise it refuses as &ldquo;unknown type number&rdquo;, which is the behaviour you want.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the course, and it is the concept that makes the other eight into a single thing. <a href="/courses/reloc/lessons/reloc-arch-contrast">One Relocation, or Two</a> said the vocabulary follows from reach. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> organised the set into four groups and found the dividing line between the linker&rsquo;s arithmetic and the loader&rsquo;s. <a href="/courses/reloc/lessons/reloc-encoding-limits">The Limits That Shaped the Table</a> gave the &plusmn;2GB boundary. <a href="/courses/reloc/lessons/pie-flags">The Flags</a>, <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> and <a href="/courses/reloc/lessons/pie-cost">What Position Independence Costs</a> gave PIE as a measured, quantified decision. <a href="/courses/reloc/lessons/pic-violation">The Relocation That Cannot Be Fixed</a> and <a href="/courses/reloc/lessons/tls-model">The One Relocation That Calls the Loader</a> gave the two ways it fails. <strong>This concept takes three of them and writes arithmetic on them, and the arithmetic is short enough to hold in your head.</strong> That is the shape the whole chain is aiming at: nine concepts of reading, ending in one page of writing.</p>
                <p>Three specific debts are paid off here. <strong>The <code>P</code> trap</strong> from <a href="/courses/reloc/lessons/reloc-encoding-limits">the third concept</a> &mdash; that <code>S - P</code> cannot be computed at compile time because <code>P</code> does not exist yet &mdash; is now a line of code, and the zero displacement that the <a href="/courses/obj/lessons/obj-the-hole">Object Files course</a> called &ldquo;the hole&rdquo; gets filled in front of you. <strong>The 32 against 32S policy</strong> from <a href="/courses/reloc/lessons/reloc-encoding-limits">the same concept</a> becomes a <code>raise</code> instead of a truncation. <strong>The loader&rsquo;s group</strong> from <a href="/courses/reloc/lessons/reloc-why-so-many">the second concept</a> becomes the list of things this program declines to do, which is a more useful form of the same knowledge than a table would have been.</p>
                <p>The chain out of this course is the static-linker course, and this concept is what makes it approachable. <a href="/courses/reloc/lessons/pic-violation">The PIC violation</a> said a linker&rsquo;s error message can point back at a compile flag, and this program is the other half of that loop: it is a minimal consumer of object files that has no idea a linker exists. <strong>The next step is to add a second object, which is where &ldquo;where does this symbol come from&rdquo; becomes a question with an answer that depends on search order, archives, and which definition wins.</strong> That is the <a href="/courses/sym/lessons/sym-algorithm">symbol-resolution course</a>, and this exercise is deliberately the last thing that can be built before it &mdash; one object, one layout, no names to resolve.</p>
                <p>And the connection that closes the course&rsquo;s argument is to the <a href="/courses/obj">Object Files</a> course it follows. That course established that an object file is a to-do list with zeros in it, and could not say who did the list. <a href="/courses/obj/lessons/obj-pic">Position Independence</a> showed the list changing shape under <code>-fPIC</code> without explaining why the shapes were necessary. <strong>This course answered the why, and then wrote the thing that consumes the list.</strong> The object file is the interface; a relocation applier is the smallest honest program that honours it, and having written one, the phrase &ldquo;linker magic&rdquo; has a specific meaning: it is the part of <code>apply_relocs.py</code> that this concept deliberately did not write.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/tls-model">Previous: The One Relocation That Calls the Loader</a></span>
                <span>End of course &middot; <a href="/courses/reloc">back to the course page</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
