// The Instruction Set Architecture — Module 1: What the Bytes Are
// Concept: 228 of 256 byte values are instructions, 27 are prefixes, and the
// escape has a deliberately undefined member.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_opcodes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Opcode Map and Its Holes — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>The Opcode Map and Its Holes</h1>
            <div class="lesson-meta">24 min &middot; Module 1: What the Bytes Are &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/isa/lessons/isa-modes">The last concept</a> ended with a byte that is a prefix in one mode and an instruction in another. That only works because <strong>the one-byte map was already full enough that its spare values had to be reused</strong>. So the interesting question is not &ldquo;what does 0x89 mean&rdquo; &mdash; it is <em>what shape is the map, and what does it do with the values it has no room for</em>.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I5/,/I6/p'
   the 256 one-byte values:
     an instruction     228
     legacy prefix       27
     nothing              1
</pre>
                </div>
                <p><strong>Over a tenth of the one-byte map is not an instruction at all.</strong> Sixteen of the 27 prefixes are the REX bytes from the last concept; the other eleven are the ones that predate 64-bit mode. That is not a design flaw, it is the arithmetic of a design that wanted room to grow in a space that could not grow.</p>
                <p>And the escape has <strong>a hole in it on purpose</strong>, which is the single most useful fact in this concept and the reason the hardening course can end a bad indirect branch immediately rather than somewhere random:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/escape and the holes/,/^$/p'
   the escape and the holes in it:
     0f 05          syscall                    -&gt; syscall
     0f 0b          ud2 -- deliberately UNDEFINED -&gt; ud2
     0f 0e          femms (3DNow!)             -&gt; femms
     0f 1e fa       bare: a multi-byte NOP     -&gt; nop    edx
     f3 0f 1e fa    with F3: endbr64           -&gt; endbr64
     cd 80          the older syscall path     -&gt; int    0x80
</pre>
                </div>
                <p><code>0F 0B</code> is <strong>UD2</strong> &mdash; <em>undefined instruction</em>. It does nothing except fault. And the reason it exists is exactly the reason <a href="/courses/isa/lessons/isa-modes">the last concept</a> needed a chain check: <strong>an invalid indirect call should stop at the first instruction it reaches, not wander through memory executing whatever bytes are there</strong>. A deliberately-undefined opcode is a way of saying &ldquo;if you are executing this, something has already gone wrong, and the polite thing is to die now.&rdquo;</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There are three maps, not one, and they are reached in a fixed order:</p>
                <div class="formula">
  ONE-BYTE MAP          0x00 - 0xFF

    228 values are instructions
     27 values are prefixes (16 REX + 11 legacy)
      1 value decodes to nothing at all

  TWO-BYTE MAP          0F xx

    reached by the ESCAPE byte 0F. used when
    the one-byte map had no room. 0F 05 is
    SYSCALL; 0F 0B is UD2; 0F 0E is FEMMS, a
    1990s AMD extension that outlived its
    processor generation.

  THREE-BYTE MAPS       0F 38 xx   and   0F 3A xx

    where the vector extensions live. 0F 38 is
    ModRM-and-stop; 0F 3A additionally takes an
    8-bit immediate after the operand.

  and the escape is OUTSIDE the 0x40-0x4F
  range, which is why 0F 05 means SYSCALL in
  BOTH 32-bit and 64-bit mode. the collision
  that broke INC did not touch the escape.
                </div>
                <p>That last line is a design decision with a measurable consequence, and it is worth dwelling on. <strong>The escape byte was placed at <code>0x0F</code>, and REX took <code>0x40</code>&ndash;<code>0x4F</code>. The two ranges do not overlap, so the escape is immune to the mode collision.</strong> System instructions are exactly the ones you least want to be mode-dependent: a program that makes a syscall should not have a different encoding depending on which mode it was compiled for. <code>0F 05</code> is <code>0F 05</code> everywhere.</p>
                <p>Now the part that is genuinely strange, and it is the reason the map has the shape it does. <strong>Some of the one-byte values are not instructions and not prefixes either &mdash; they are escapes for <em>other</em> escapes.</strong> <code>CD</code> is <code>INT imm8</code>, the 1990s system-call path, and it is still there. <code>C4</code> and <code>C5</code> were <code>LES</code> and <code>LDS</code> &mdash; instructions so thoroughly unusable in a flat address space that Intel repurposed them as the <strong>VEX</strong> prefixes for 128-bit vector code. So:</p>
                <div class="formula">
  CD 80        INT 0x80        the 1990s syscall path,
                               still emitted by some code

  C4 ..        VEX 2-byte      was LES (load far segment)
  C5 ..        VEX 3-byte      was LDS (load far segment)

  the far-segment load instructions died because
  segmentation did. their OPCODES did not, and
  a prefix is what an opcode becomes when the
  thing it named stops existing and the encoding
  slot is more valuable than the instruction.
                </div>
                <p>That is the general shape of the whole map, and it is the answer to &ldquo;why is the opcode table so weird&rdquo;. <strong>An opcode is a slot, and slots outlive their contents.</strong> The <a href="/courses/isa/lessons/isa-modes">REX collision</a> and the EVEX collision are the same phenomenon, and so is <code>C4</code>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measuring the Map Rather Than Reading the Table</h2>
                <p>The counts above came from asking the oracle about all 256 byte values individually, not from reading a manual. That distinction matters, because the manual is the authority and the oracle is what a tool actually does &mdash; and where they differ, you want to know.</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
    import subprocess, collections
    def one(bs):
        open('_p.bin','wb').write(bytes(bs))
        o=subprocess.run(['objdump','-D','-b','binary','-m','i386:x86-64',
                          '-M','intel','_p.bin'],capture_output=True,text=True).stdout
        r=[l.split('\t') for l in o.splitlines() if len(l.split('\t'))&gt;=3]
        return [x[2].strip() for x in r if x[0].strip().rstrip(':').strip()]
    pref=('data','rep','lock','cs','ds','es','fs','gs','ss','addr','rex')
    c=collections.Counter()
    for b in range(256):
        g=one(bytes([b]))
        if not g: c['nothing']+=1
        elif g[0].startswith(pref): c['legacy prefix']+=1
        else: c['an instruction']+=1
    for k,v in c.most_common(): print('     %-18s %3d' % (k,v))
    PY
     an instruction     228
     legacy prefix       27
     nothing              1
</pre>
                </div>
                <p>Two of those three numbers are worth pausing on. <strong>228 instructions in 256 byte values is a map that is nearly full</strong> &mdash; and the 16 that are missing are the prefixes, which is why REX had to collide rather than expand. And <strong>the &ldquo;legacy prefix&rdquo; bucket of 27 is 16 REX plus 11 older ones</strong>: <code>66</code>, <code>67</code>, <code>F0</code>, <code>F2</code>, <code>F3</code>, and the six segment overrides <code>2E 36 3E 26 64 65</code>. Six of the eleven exist to name a segment, which in a flat address space means the DS and ES and SS ones are now decorative.</p>
                <p>Now the hole, because it is the load-bearing one. <code>0F 0B</code> is UD2 and the <a href="/courses/sec/lessons/sec-cet">hardening course</a> already made the point from the other direction: CET makes an indirect branch to a bad target fault, and this is the classic belt-and-braces landing pad. But the older, simpler version of the same idea needs no hardware at all:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py 0f0b 0f05 cd80
0f 0b     ud2
0f 05     syscall
cd 80     int     0x80
</pre>
                </div>
                <p>Three two-byte instructions, and they tell the whole story of system calls on this platform. <strong><code>0F 05</code> is the modern path, <code>CD 80</code> is the 1990s path, and <code>0F 0B</code> is the answer to &ldquo;what if the CPU is not where you thought it was&rdquo;.</strong> A compiler emits <code>UD2</code> immediately after a noreturn call site, so that if control ever reaches there anyway &mdash; because a function that promised not to return did &mdash; the program stops at the very next instruction instead of executing the bytes that follow, which might be a jump table or a string constant.</p>
                <p>And <code>ENDBR64</code> belongs in this concept too, because its encoding explains its behaviour. <strong><code>F3 0F 1E FA</code> is a mandatory-prefix escape: the <code>F3</code> is not decoration, it is what selects this instruction from the <code>0F 1E</code> group.</strong></p>
                <div class="formula">
  0F 1E FA        a multi-byte NOP     (mod=3, reg=7, rm=2)
  F3 0F 1E FA     ENDBR64             the SAME encoding plus F3

  the F3 changes nothing about the length -- both
  are 4 bytes. it changes what the instruction
  MEANS, and that is the whole mechanism: a prefix
  that reinterprets an existing opcode rather than
  widening an operand.
                </div>
                <p>So an <code>endbr64</code> is harmless on a CPU with no CET, where it decodes as a four-byte <code>NOP</code> with an odd prefix, and meaningful on one that has it. <strong>That is why the hardening course measured the instructions being present while the property note claimed nothing: the instructions and the enforcement are separate, and this is the encoding side of that separation.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Auditing a Table Instead of Reading One</h2>
                <p>There is a method in this course that turned out to matter more than any single fact, and it belongs here because the opcode table is where it pays.</p>
                <p>The decoder needs a table saying, for each opcode, whether it takes a ModRM byte and whether an immediate follows. That table is ~360 entries. Writing it by reading a manual is slow; writing it by hand from memory is how you get <code>0F F4</code> labelled HLT when it is actually <code>PMULUDQ</code>. So the crosscheck builds a minimal instruction from every entry and compares the length against the oracle:</p>
                <div class="formula">
  for each of 364 table entries:
      build a minimal instruction in the form
      the table claims
      ask the oracle how many bytes it is
      compare

  result: 0 disagreements

  and it is not a formality. it found:
    0F F4   labelled HLT      -- it is PMULUDQ
    D3      given an imm8     -- it takes none
    BSWAP   given a ModRM     -- it takes none
    0F 09/0B/31  forced to take a ModRM they do
               not have, so three ordinary
               instructions were REFUSED
                </div>
                <p><strong>Every one of those four errors was invisible in isolation.</strong> Each produced a plausible-looking disassembly of a hand-picked example. They were only findable by exhausting the table, because a decoder has no other way to find out it is wrong &mdash; it has no internal contradiction to notice.</p>
                <p>That is the argument for the method, and it generalises past this course. <strong>A lookup table has no self-check. A table that is 95% right produces output that is 95% right and gives you no way to tell which 5%.</strong> A crosscheck that walks the whole table converts &ldquo;I think this is right&rdquo; into a number, and a number either holds or does not.</p>
                <p>One thing the table deliberately does <em>not</em> do, which is a decision rather than a gap:</p>
                <div class="formula">
  where the decoder has no NAME for an opcode it
  can still LENGTH correctly, it prints:

      (op 0f 6c)

  not a guess.

  a guessed mnemonic is a claim nothing checked.
  a correct length with no name is an honest
  partial answer, and it is still useful: the
  instruction BOUNDARY is what the chain check
  and the linker both need.
                </div>
                <p>So the decoder is deliberately asymmetric. <strong>Length and structure are the contract; naming is a convenience.</strong> That is the right way round for this course, because <a href="/courses/obj/lessons/obj-arch-table">the question a linker asks</a> is where the bytes are, never what they are called.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I5/,/I6/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/I5/,/I6/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/I9/,$p'
</pre>
                </div>
                <p>Then find the slots that changed hands, which is the better exercise:</p>
                <div class="hex-dump">
                    <pre>  1. List the opcodes in this build's table that
     are prefixes now and were instructions
     once. The decoder's table has the answer;
     the manual has the history.

       grep -n "'c4'\|'c5'\|'cd'\|'62'" x86dec.py

     (C4 and C5 are VEX -- they were LES and LDS.
     CD is INT imm8 and still is. 62 is EVEX and
     was BOUND. Ask what each replaced and why the
     replacement was worth more than the thing it
     replaced. VEX is the interesting case: a
     prefix is 2 or 3 bytes, and its whole job is
     to carry bits -- a 4th operand, a wider
     register -- that the legacy opcode had no
     room for. The encoding grew a prefix layer
     rather than growing the opcode.)

  2. Now the opposite direction: find a byte
     sequence that is a valid instruction in 32-bit
     and an INVALID one in 64-bit, using the mode
     collision from the last concept as a lever.

       40 89 e8      valid in both, 1 insn vs 2
       62 ...        EVEX, invalid to a reader
                     without AVX-512

     (There are others. 0F 01 with certain ModRM
     values, and the whole far-jump family. The
     general question is: which 32-bit instructions
     became impossible, and what replaced them?)

  3. Take the UD2 argument seriously and find the
     compiler's own use of it:

       clang -O2 -S -o - t.c | grep -A2 -B2 'ud2'

     Count how many UD2 instructions appear in a
     modest C file, and check that each one follows
     something marked noreturn. Then write the
     three-instruction program that has no UD2 and
     see what happens when it falls through:

       int f(void) { return 1; }
       int g(void) { int x = f(); if (x) return x; x = 0; }

     (The point is that UD2 is not a security
     feature bolted on. It is the compiler saying
     "control cannot arrive here", and making that
     claim ENFORCEABLE in one byte. Compare the
     cost: 2 bytes against what an equivalent
     runtime check would cost.)

  4. Decode a real binary and count the distinct
     opcodes it uses, then check how many your table
     can name:

       objdump -d /bin/ls | awk -F'\t' '{print $3}' \
         | awk '{print $1}' | sort | uniq -c | sort -rn | head -30

     (Expect the top of that list to be entirely
     table entries, and the tail to include SSE
     opcodes the decoder lengths but does not name.
     That asymmetry is the design, not an oversight:
     a real binary is mostly the operations the
     compiler emits most often, and those are the
     ones worth naming.)

  5. Finally: write your own opcode table for a
     DIFFERENT architecture -- AArch64 -- and
     compare the two shapes. (AArch64 is fixed-width
     32-bit, so the table is a flat 4-byte field with
     no prefixes and no length calculation at all.
     The interesting part is not that it is simpler.
     It is that a fixed-width encoding makes the
     question this course is about -- how many bytes
     is this instruction -- trivially answered, and
     x86's difficulty is the direct price of
     compactness. Neither is wrong. They are
     different answers to "what do you want the
     encoding for?".)
</pre>
                </div>
                <p>Exercise 5 is the one that gives the course its shape, and it is worth doing because it inverts the usual reading. <strong>AArch64&rsquo;s encoding is four bytes, always, and that is a feature</strong> &mdash; a decoder is a table lookup, instruction boundaries need no chaining, and nothing can desynchronise. x86&rsquo;s is 1 to 15 bytes and that is also a feature &mdash; code density, which mattered when a 64K memory was the constraint. <strong>The two designs are the same trade in opposite directions, and this course only exists because x86 chose the end that makes decoding hard.</strong></p>
                <p>Exercise 3 is the one that changes how you read a compiler. <strong>UD2 after a noreturn call is the compiler making a claim enforceable in two bytes</strong>, and the claim is &ldquo;control flow cannot arrive here&rdquo;. Once you know to look for it you will see it in every non-trivial binary, and it reframes a stray <code>0F 0B</code> from noise into a proof obligation the compiler discharged. That is the same move as <a href="/courses/sec/lessons/sec-cet">CET&rsquo;s <code>endbr64</code></a> and the same move as a <a href="/courses/reloc/lessons/reloc-why-so-many">relocation&rsquo;s zero addend</a>: a value in the file that asserts something about control.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct technical debt this pays is to <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">the DWARF standard-opcodes concept</a>, which taught that DWARF numbers instructions using <em>per-architecture</em> tables because the encodings differ. That course could state the fact and had to stop there; <strong>this is the concept that shows what one of those tables contains, and why the DWARF spec needs 20 pages of them.</strong> A fixed-width architecture has a one-column table. x86 has a table with a length column, a ModRM column and a prefix column, and the crosscheck in module 4 exists because a table that shape is exactly the kind that can be 95% right.</p>
                <p>The connection to <a href="/courses/link/lessons/link-phdrs">the linker-script concept</a> is about the map&rsquo;s exhaustiveness. That course found the default script&rsquo;s rule for <code>.plt</code> and could not say why the section was sometimes empty; <strong><a href="/courses/isa/lessons/isa-rex">the REX concept</a> and <a href="/courses/isa/lessons/isa-modrm">the ModRM concept</a> supply the answer for the other half of that puzzle</strong> &mdash; a <code>.plt</code> entry is one instruction, and whether the entry needs a <code>disp32</code> or a <code>rip+disp32</code> depends on which ModRM class the encoding used. Three courses, one mechanism.</p>
                <p>Two connections outward, both about the same idea in a different register. <a href="/courses/sec/lessons/sec-cet">The CET concept</a> measured that <code>endbr64</code> is present in binaries with protection disabled, and this concept supplies the encoding: <code>F3 0F 1E FA</code>, a reinterpretation of an existing opcode by prefix. <strong>The reason the instructions can be present while enforcement is not is that the instruction and the request are two different files</strong> &mdash; the opcode map and the property note &mdash; and this concept is the half that lives in the opcode map. And <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">the DWARF standard-opcodes concept</a> is the other reader of the same table, for a different purpose: <a href="/courses/sec/lessons/sec-defaults">the hardening course</a> taught that a hardening feature is a compiler decision, a linker decision, or a driver decision, and this course is the reference for the first of those three layers at the level of individual bytes.</p>
                <p>One limit that is also the course&rsquo;s method, stated plainly. <strong>The opcode table in the artifact covers 364 audited entries for length and structure, and names a subset.</strong> It is not a complete disassembler and does not claim to be: where it has no name it prints the opcode in hex rather than guessing, because a guessed mnemonic is a claim nothing checked. And no number here was read from Intel&rsquo;s documentation &mdash; everything was measured against a reader and, where the two disagreed, the disagreement is recorded in <code>research.md</code> under &ldquo;Oracle limitations&rdquo; rather than resolved in Intel&rsquo;s favour by assertion. <strong>That is the collection&rsquo;s standing rule applied to the oldest format in it, and it is the rule the next five concepts are built on.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-modes">Previous: One Byte Stream, Two Meanings</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-rex">REX: Four Bits That Add Eight</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
