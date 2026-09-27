// The Instruction Set Architecture — Module 1: What the Bytes Are
// Concept: 0x40 is INC in one mode and REX in another, so three bytes have
// two correct readings.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_modes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Byte Stream, Two Meanings — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>One Byte Stream, Two Meanings</h1>
            <div class="lesson-meta">23 min &middot; Module 1: What the Bytes Are &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every course before this one used x86-64 machine code as an opaque byte string. The <a href="/courses/obj/lessons/obj-arch-table">architecture table concept</a> said an x86-64 relocation patches a 4-byte field and asked where in the instruction that field sits &mdash; then declined to answer, because answering is a disassembler&rsquo;s job. The <a href="/courses/reloc/lessons/reloc-why-so-many">relocations course</a> could say &ldquo;a <code>disp32</code> is at offset 1&rdquo; and never say why.</p>
                <p>So the bytes were everywhere and the meaning nowhere. This course opens the black box, and it opens it with the sharpest fact I could measure &mdash; which is that <strong>the byte stream does not determine the instruction. The mode does.</strong></p>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
     the same three bytes, decoded in each mode:
   40 89 e8  (64-bit)              40 89 e8               rex mov eax,ebp
   40 89 e8  (32-bit)              40                     inc    eax | 89 e8                  mov    eax,ebp
</pre>
                </div>
                <p><strong>One instruction of three bytes, or two instructions of one and two.</strong> Same file, same three bytes, same disassembler, same moment. The only thing that changed is a declaration &mdash; the machine the reader was told it is looking at.</p>
                <p>That is worth a moment, because it is the answer to a question the whole chain has been circling. An ELF file carries <code>e_machine</code>, and a relocatable object carries the machine in its own header. <strong>Those fields exist precisely because raw bytes are not self-describing.</strong> The <a href="/courses/elf/lessons/elf-header-fields">ELF header-fields concept</a> said every field has a job; here is the job, demonstrated with three bytes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why the collision exists, and what it costs. The 64-bit extension needed a way to reach registers 8 through 15 from an instruction that only has three bits per register field. It could not spend a new opcode, because the one-byte map was full and every remaining value was taken. So it took <strong>sixteen values that already had a meaning and gave them a second one</strong>:</p>
                <div class="formula">
  0x40  0x41  0x42  0x43  0x44  0x45  0x46  0x47
  0x48  0x49  0x4A  0x4B  0x4C  0x4D  0x4E  0x4F

  in 32-bit mode:   INC EAX  ...  INC EDI
                    (or DEC, with a REX.W-like byte 0x41-0x4F)
  in 64-bit mode:   REX.  the byte that says
                    W=0 R=0 X=0 B=0

  one encoding, two readings, and the MODE
  is the only thing that picks between them.
                </div>
                <p>There is a second collision of exactly the same shape, and it is newer. <strong><code>0x62</code> is the AVX-512 EVEX prefix in 64-bit mode and the <code>BOUND</code> instruction in 32-bit.</strong> Same trade, a different generation: a full opcode map, no new space, take a value that already meant something.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/A SECOND MODE/,/escape and the holes/p'
   A SECOND MODE COLLISION, and the same shape as 0x40:
     40  REX in 64-bit, INC in 32-bit     -&gt; rex
     62  EVEX in 64-bit, BOUND in 32-bit  -&gt; .byte 0x62
   0x62 is the AVX-512 EVEX prefix in 64-bit mode, so it collides with
   the 32-bit BOUND instruction exactly the way 0x40 collides with INC.
   and a disassembler WITHOUT AVX-512 support refuses it and loses the
   instruction stream from that point on -- which is why the corpus
   below is built -march=x86-64: a reader that gives up is not a reader
   that disagrees, and the two must not be confused.
</pre>
                </div>
                <p>So the pattern is worth naming as a pattern, because it recurs: <strong>an instruction set that outgrows its encoding space takes a collision rather than growing.</strong> The 64-bit register extension collided with <code>INC</code>. AVX-512 collided with <code>BOUND</code>. Neither was a mistake; both were the only available move, and both leave a reader with a genuine ambiguity to resolve.</p>
                <p>And there is a third thing the collision is <em>not</em>, which is worth saying because it is the usual misreading:</p>
                <div class="formula">
  it is NOT that 0x40 is "sometimes a prefix".

  it is that 0x40 is a PREFIX IN 64-BIT MODE and
  an INSTRUCTION in 32-bit mode, with no overlap
  and no ambiguity WITHIN either mode.

  within one mode, the reading is determined.
  the ambiguity is entirely between modes.
                </div>
                <p>So a 64-bit decoder is not guessing. It is reading a well-defined encoding, and it would be <em>wrong</em> to read <code>40</code> as <code>inc eax</code> in this mode. The mode is not a hint; it is the rule.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What It Costs in Practice</h2>
                <p>The collision is a curiosity. Its <em>consequence</em> is not, and the consequence is the thing a tool has to get right.</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py --why 40 89 e8
    offset 0, 3 bytes: 40 89 e8
      mov      ebp,eax
      . byte 40 at 0 is a REX prefix: W=0 R=0 X=0 B=0
      . the three extension bits each ADD 8 to a 3-bit field,
      . so R=1 with reg=000 is r8 -- not r9
      . byte 89 at 1 is a one-byte opcode
      . byte e8 at 2 is the ModRM byte: mod=3 reg=5 rm=0
      .   mod=11: the r/m field names a REGISTER, so no address
      .   bytes follow
</pre>
                </div>
                <p>Read the three lines of derivation. <strong>The decoder had to consume a byte that is not an instruction before it could find the instruction at all</strong>, and then it had to know that the byte it found next was the last one. That is the whole difficulty in miniature, and it is why disassembly is a sequential process rather than a lookup: you cannot ask &ldquo;what is the instruction at offset 2&rdquo; without first knowing where instruction 0 ends.</p>
                <p>Now the consequence that actually bites. Suppose a decoder gets one instruction's length wrong. It does not produce one bad answer &mdash; <strong>it produces a bad answer for every instruction after it, because it is now reading from the wrong offset.</strong> There is no resynchronisation, because x86-64 has no sync marker. The corruption is silent and unbounded.</p>
                <div class="formula">
  correct:  |---- 3 bytes ----|--- 3 ---|--- 2 ---|
            ^0                  ^3        ^6

  one byte
  too long: |---- 4 bytes -----|-- 2 --|--- 2 ---|
            ^0                  ^4       ^6
                              ^  ^     ^  ^
                              |  |     |  +-- now inside an
                              |  |     |      operand, not an opcode
                              |  +-----+-- garbage from here on
                              +-- this is a DISPLACEMENT byte
                </div>
                <p>That is why <a href="/courses/isa/lessons/isa-length">the length concept</a> treats instruction boundaries as a <em>chain</em> and checks that it consumes a section exactly, rather than checking instructions one at a time. <strong>One wrong length does not produce one wrong answer; it invalidates the rest of the reading, and a per-instruction check cannot see that.</strong></p>
                <p>And it is why the mode matters operationally and not just theoretically. The <a href="/courses/elf/lessons/dynamic-section">dynamic section concept</a> and the <a href="/courses/img/lessons/img-entries">image-loading course</a> both insisted on reading the file rather than trusting a tool. This is the same discipline one level down: <strong>a disassembler given the wrong mode does not warn you. It returns confident nonsense.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Showing the Reasoning, Not the Answer</h2>
                <p>The artifact for this course is a decoder, and the design decision that matters is what it prints. A disassembler prints an answer; this one prints the <em>derivation</em>, because the derivation is the lesson:</p>
                <div class="formula">
  $ python3 x86dec.py 4889e8

  48 89 e8  movq     rax,rbp

  $ python3 x86dec.py --why 4889e8

    offset 0, 3 bytes: 48 89 e8
      mov      rax,rbp
      . byte 48 at 0 is a REX prefix: W=1 R=0 X=0 B=0
      . the three extension bits each ADD 8 to a 3-bit field,
      . so R=1 with reg=000 is r8 -- not r9
      . byte 89 at 1 is a one-byte opcode
      . byte e8 at 2 is the ModRM byte: mod=3 reg=5 rm=0
      .   mod=11: the r/m field names a REGISTER, so no address
      .   bytes follow
                </div>
                <p>Every field says which byte it came from and what it decided. That is not decoration &mdash; it is the difference between a tool you can check and a tool you have to believe. <strong>The mnemonic is a lookup; the four lines that produced it are the content.</strong></p>
                <p>Compare the two readers on the interesting case, because they genuinely differ and the difference is a decision rather than a bug:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/A REX byte must be/,/inherited/p'
   A REX byte must be the LAST prefix before the opcode. A legacy
   prefix that follows REX is not a prefix at all -- it is the opcode.

   and the two readers DISAGREE on that second case, which is worth
   stating rather than smoothing over. 0x66 as an OPCODE in 64-bit mode
   is PUSH ES, which does not exist, so the instruction faults. objdump
   prints a bare 'rex.W' and then re-reads the 0x66 as a prefix anyway --
   a diagnostic convenience, not the architectural reading. x86dec.py
   refuses. A decoder that recovers and a decoder that refuses are both
   defensible; what matters is that the difference is a decision you made
   rather than a bug you inherited.
</pre>
                </div>
                <p>On <code>48 66 8b c0</code> the oracle prints two entries and the artifact refuses. <strong>Both are defensible and the course asserts the architectural reading</strong> &mdash; the <code>0x66</code> is the opcode, and as an opcode in 64-bit mode it is invalid. A reader that recovers is being helpful; a reader that refuses is being honest. What is not acceptable is a reader that recovers without saying so, because then a faulting instruction and a working one look identical in the output.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
$ python3 x86dec.py --why 4089e8
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
</pre>
                </div>
                <p>Then find the other collisions, which is the better exercise because there are more than two:</p>
                <div class="hex-dump">
                    <pre>  1. Write a script that takes every byte value
     0x00-0xFF, decodes it in BOTH modes, and
     reports the ones whose INSTRUCTION COUNT differs:

       for b in $(seq 0 255); do
         n64=$(objdump -D -b binary -m i386:x86-64 \
                 -M intel one.bin 2>/dev/null | grep -c '^ ')
         ...
       done

     (Expect a small set, not just 0x40 and 0x62. Several
     of the 0x50-0x5F PUSH/POP group also change: in
     32-bit they are one byte, and in 64-bit PUSH r64
     needs no REX while PUSH r8..r15 does. The count
     changes for a different reason -- a 64-bit PUSH of a
     high register is TWO bytes -- and that is a second
     kind of mode difference worth listing separately.)

  2. Now the reverse question: which byte strings are
     UNAMBIGUOUS? Take the ten most common instruction
     encodings from a real binary and check each in both
     modes. (Most are ambiguous, because most 32-bit
     encodings are a prefix plus an instruction. The
     interesting ones are the escapes: CD 80 is INT 0x80
     in both, and 0F 05 is SYSCALL in both -- an escape
     is immune to the 0x40 class of collision because
     0x0F is not in the 0x40-0x4F range.)

  3. Break the chain on purpose and watch the damage
     propagate. Take a real .text, and shift its start
     by ONE byte. Then decode with x86dec.py and with
     objdump.

       python3 x86dec.py --section .text binary

     (Both will produce output. Neither will warn you.
     That is the point of the exercise: identical
     confidence, completely different content, and the
     only thing that distinguishes them is a fact
     supplied outside the bytes.)

  4. Now do it properly: decode the same section from
     its TRUE start and from a shifted one, and count
     how many of the instructions agree before the
     first divergence.

       python3 - <<'EOF'
       import sys; sys.path.insert(0,'.')
       import x86dec
       d, secs = x86dec.code_sections('corpus')
       for n, a, o, sz in secs:
         if n != '.text': continue
         good = x86dec.decode_stream(d[o:o+sz], 0, sz)[0]
         bad  = x86dec.decode_stream(d[o:o+sz], 1, sz)[0]
         same = 0
         for g, b in zip(good, bad):
           if g.offset == b.offset and g.length == b.length: same += 1
           else: break
         print('agreed for', same, 'of', len(good))
       EOF

     (Expect the answer to be small -- often one or two
     instructions -- because the first coincidence is
     what you get. This is the self-synchronising-code
     problem in its purest form, and it is why a
     disassembler cannot verify its own start address.)

  5. Finally, the historical question, and it is worth
     an afternoon: why was INC/DEC not given a new
     opcode instead of being reused? Read what you can
     find about the register-extension design. (The
     course does not answer this -- it states the
     mechanism and stops -- but the constraint is
     visible in the collision itself: the one-byte map
     had no room, so the extension had to come from
     somewhere. A collision is a fossil of a
     resource shortage.)
</pre>
                </div>
                <p>Exercise 4 is the one that makes the concept bite, and its result is the most useful thing in this unit. <strong>Decoding from a wrong start agrees with the correct reading for a handful of instructions and then diverges permanently</strong> &mdash; and both readings produce confident, well-formatted output. There is no way to tell from inside the byte stream that you are wrong, which is the deepest reason the mode has to be supplied from outside.</p>
                <p>Exercise 2 has the answer that connects to a concept two courses back. <strong>An escape byte is immune to the <code>0x40</code> class of collision</strong>, because <code>0x0F</code> is not in the <code>0x40</code>&ndash;<code>0x4F</code> range that REX took. That is not a coincidence: the two-byte map was designed after the collision was already a problem, and placing the escape outside the REX range is what kept <code>0F 05</code> meaning SYSCALL in both modes. <a href="/courses/isa/lessons/isa-opcodes">The next concept</a> measures the escape and the holes in it.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent of this concept is <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a>, and this is the concept that answers its question. That concept posed &ldquo;Q1a. how many bytes is the instruction?&rdquo; and said answering is a disassembler&rsquo;s job; <strong>every one of the seven concepts here is an answer to that question, and the decoder is the job being done.</strong> The chain had a genuine hole in it &mdash; a linker that must locate a field inside an instruction, and no course that could tell it how &mdash; and this is the course that fills it.</p>
                <p>The connection to <a href="/courses/elf/lessons/elf-header-fields">the ELF header fields</a> is the same fact at a different level, and it is worth making the parallel explicit because it is the collection&rsquo;s whole method. <strong><code>e_machine</code> declares the architecture; the mode declares the encoding; both exist because the bytes do not say.</strong> A file that carried no <code>e_machine</code> would be as undecodable as a byte string with no mode &mdash; not because the data is ambiguous, but because the reader would have no way to choose. The <a href="/courses/pe/lessons/pe-optional-header">PE optional header</a> and the <a href="/courses/macho/lessons/macho-cputypes">Mach-O architecture fields</a> exist for the same reason, which is why this course&rsquo;s method transfers to them even though none of its numbers do.</p>
                <p>Two connections outward, both about consequences rather than mechanism. <a href="/courses/sec/lessons/sec-cet">The CET concept in the hardening course</a> measured that <code>endbr64</code> appears in binaries built with CET explicitly disabled, and that enforcement comes from a property note rather than the instructions. <strong>The encoding of <code>endbr64</code> is the subject of <a href="/courses/isa/lessons/isa-opcodes">the next concept</a> &mdash; it is <code>F3 0F 1E FA</code>, an escape with a mandatory prefix &mdash; so the two courses meet at exactly the point where &ldquo;which bytes&rdquo; becomes &ldquo;what protection&rdquo;.</strong> And <a href="/courses/reloc/lessons/reloc-encoding-limits">The encoding-limits concept</a> measured why position independence costs an extra relocation per datum: because RIP-relative addressing needs a <code>disp32</code> that the linker can patch. <a href="/courses/isa/lessons/isa-modrm">The ModRM concept</a> measures that <code>disp32</code> and explains why the form exists, so this is a debt the chain has been carrying since the relocations course.</p>
                <p>One honest limit, which is also the reason this course is x86-64 only. <strong>The collision is a property of this ISA, not of instruction sets in general.</strong> AArch64 has fixed-width 32-bit instructions, so every instruction is four bytes and the question never arises; RISC-V has a 16- and 32-bit compressed form and no prefix bytes at all. The <a href="/courses/dwarf/lessons/dwarf-frames">DWARF frame-record course</a> covers the AArch64 encoding of registers, and this course deliberately does not duplicate it &mdash; but no AArch64 machine or linker was available here, so nothing in these seven concepts is claimed about a second architecture. What transfers is the <em>method</em>: feed the bytes to a reader, compare against an oracle, and distrust any number you did not reproduce.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-entries">Previous: Where the Entry Points Come From</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-opcodes">The Opcode Map and Its Holes</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
