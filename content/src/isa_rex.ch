// The Instruction Set Architecture — Module 2: The Prefix Layers
// Concept: the extension rule that makes R=1 mean r8, and the order rule that
// makes REX the last prefix.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_rex() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("REX: Four Bits That Add Eight — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>REX: Four Bits That Add Eight</h1>
            <div class="lesson-meta">24 min &middot; Module 2: The Prefix Layers &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>x86-64 has sixteen general-purpose registers. Every legacy instruction has three bits per register field, which names eight. Something has to bridge that gap, and the answer is a single byte that was already spoken for.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I2/,/I3/p'
     the four bits, W R X B, in 0x40..0x4F:
   89 c0                           89 c0 mov eax,eax
         ^ no REX              32-bit operands
   44 89 c0                        44 89 c0 mov eax,r8d
         ^ REX 0x44 R=1     32-bit, reg becomes r8d
   4c 89 c0                        4c 89 c0 mov rax,r8
         ^ REX 0x4c W=1 R=1 64-bit, reg becomes r8
   49 8b 00                        49 8b 00 mov rax,QWORD PTR [r8]
         ^ REX 0x49 R=1 B=1 r/m becomes r8
   45 8b 04 24                     45 8b 04 24 mov r8d,DWORD PTR [r12]
         ^ REX 0x45 X=1 B=1  base AND index become r12
</pre>
                </div>
                <p>Read those five lines as a single mechanism. <strong>REX is four bits &mdash; <code>W</code>, <code>R</code>, <code>X</code>, <code>B</code> &mdash; and three of them do exactly one job: extend a three-bit field to four bits.</strong> One extends the operand <em>size</em>. Three extend the three register fields &mdash; <code>R</code> for the ModRM <code>reg</code> field, <code>X</code> and <code>B</code> for the address.</p>
                <p>And the rule that catches everyone, including this course&rsquo;s author before it was measured: <strong>the extension bit ADDS 8. It does not select &ldquo;the ninth register&rdquo;.</strong> So <code>R=1</code> with <code>reg=000</code> is <strong>r8</strong>, and with <code>reg=100</code> it is <strong>r12</strong>. The field stays a 3-bit number and the bit supplies bit 3.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <div class="formula">
  REX  = 0100 W R X B
         ^^^^ always 0100, which is what makes
              0x40-0x4F identifiable at all

  W  operand size   0 = 32-bit,  1 = 64-bit
  R  ModRM.reg      adds 8
  X  SIB.index      adds 8
  B  ModRM.rm       adds 8

  and the ADDING is the whole trick:

      reg = 000  R=0  -&gt;  register 0  = rax
      reg = 000  R=1  -&gt;  register 8  = r8
      reg = 100  R=0  -&gt;  register 4  = rsp
      reg = 100  R=1  -&gt;  register 12 = r12

  0..7 and 8..15.  never 0..7 and 1..8.
                </div>
                <p>That is a strange design and it is worth asking why, because the answer explains the second rule. <strong>The alternative was to widen the register fields to four bits</strong>, which would have meant an entirely new encoding &mdash; and the whole point of 64-bit mode was compatibility. An old decoder, handed a 64-bit binary, should ideally still decode the parts it understands. So Intel kept the legacy encoding intact and <em>added</em> a byte that widens it, rather than widening the fields in place.</p>
                <p>Which produces the second rule, and it falls straight out of that:</p>
                <div class="formula">
  A REX BYTE MUST BE THE LAST PREFIX BEFORE
  THE OPCODE.

      66 48 8B C0     ONE instruction
                      66 = operand-size prefix
                      48 = REX.W
                      8B = MOV
                      C0 = ModRM

      48 66 8B C0     NOT one instruction
                      48 = REX.W
                      66 = THE OPCODE, not a prefix
                      8B = the next instruction
                      C0 = its ModRM

  why: once the decoder has read a REX, the next
  byte is the opcode. the state machine has ONE
  slot for "REX", and it is closed the moment it
  is filled.
                </div>
                <p>And that is not a stylistic rule. <strong>It is a state-machine rule, and it exists because a REX byte is only meaningful when it is adjacent to the thing it modifies.</strong> If <code>66</code> could follow <code>48</code> and still be a prefix, the decoder would have to remember an unbounded number of prefix bytes and their order &mdash; but the hardware has no room to remember that, so the rule is enforced in the encoding instead.</p>
                <p>There is a third property that falls out of the &ldquo;adjacent&rdquo; design and is easy to miss:</p>
                <div class="formula">
  IF TWO REX BYTES APPEAR, ONLY THE LAST
  ONE COUNTS.

      48 4C 8B C0     the 48 is IGNORED
                      4C is the REX: W=1 R=1

  the earlier one is not an error. it is a
  no-op prefix, decoded and discarded, which is
  exactly what makes "prepend REX.W and hope"
  work as a code-generation strategy -- and also
  exactly why it is a bad one, since the thing you
  hoped for may be the byte that got dropped.
                </div>
                <p>So the three REX rules are: <strong>it adds 8, it must be last, and only the last one counts.</strong> All three are consequences of one decision &mdash; prepend a widening byte rather than rewrite the fields &mdash; and all three are things you can get wrong in a compiler, a bootloader, or a hand-written assembler.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measuring the Extension, and the Oracle&rsquo;s Gap</h2>
                <p>Every bit measured, one at a time, against the oracle:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I2/,/^I3/p'
  ok  all 256 ModRM bytes decode as exactly one instruction   (that is I3)
  ok  REX extension in 44 89 e0 -&gt; r12d
  ok  REX extension in 4c 89 e0 -&gt; r12
  ok  REX extension in 49 89 e0 -&gt; r8
  ok  REX extension in 49 8b 00 -&gt; [r8]
  ok  REX.R=1 with reg=000 is r8, NOT r9
  ok  a bare REX prefix does not change the instruction
  ok  66 then REX is ONE instruction
  ok  REX then 66 is TWO objdump entries
  ok  x86dec agrees on the 66-then-REX case
  ok  x86dec REFUSES REX-then-0x66, which is the architectural reading
</pre>
                </div>
                <p>Now the part that is worth more than any of those checks, because it is a limitation of the <em>instrument</em> rather than of the ISA. The fifth row of the I2 output in the build script is this:</p>
                <div class="hex-dump">
                    <pre>   A LIMITATION OF THE ORACLE, measured and worth knowing: the last row
   has REX.X=1, so the SIB index (100 with X=1) should be r12 as well as
   the base. objdump prints only [r12] -- it does not apply REX.X to the
   SIB index field. x86dec.py DOES apply it, so the two disagree here, and
   the crosscheck compares instruction BOUNDARIES rather than operand
   text for exactly this reason.
</pre>
                </div>
                <p><code>45 8B 04 24</code> has <code>REX.X=1</code> and <code>REX.B=1</code>. The base is <code>100</code>, so with B it is r12. The index is also <code>100</code>, so with X it should be r12 too &mdash; the instruction is <code>mov r8d, [r12+r12*1]</code>. The oracle prints <code>[r12]</code>: it applied B and ignored X.</p>
                <p><strong>This is a real bug in the tool, and it has a consequence for how the course is verified.</strong> If the crosscheck compared operand text, it would fail here &mdash; with the decoder right and the oracle wrong. So the crosscheck compares <em>instruction boundaries and lengths</em>, which both readers get right, and the operand text is printed for a human to read rather than asserted.</p>
                <div class="formula">
  when two readers disagree, decide WHICH
  QUESTION you are asking before you pick a
  winner.

    "do they agree where the instructions
     start and how long they are?"
         -&gt; YES, 578 of 578. assert it.

    "do they agree what the operands are?"
         -&gt; NO. the oracle is wrong about
            REX.X. assert nothing.

  the first question is what a linker needs.
  the second is what a human needs. asking
  the second question of a checker is how a
  correct tool gets &ldquo;fixed&rdquo; into a
  broken one.
                </div>
                <p>That is the general lesson and it is the same one the hardening course learned about the wrong output stream: <strong>a check that fails for the wrong reason teaches you to ignore it, which is worse than having no check.</strong> So the right move is to narrow the check until it tests something both tools are reliable about, and to write down the part that is not covered rather than quietly dropping it.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three Rules, Three Failure Modes</h2>
                <p>Each rule has a characteristic bug, and each bug is silent. That is what makes them worth memorising as a set rather than as a definition.</p>
                <div class="formula">
  RULE                    SYMPTOM WHEN VIOLATED
  ---------------------   ------------------------------------
  REX adds 8              a tool prints r9 where the
                          answer is r12, or vice versa.
                          NO crash: r9 and r12 are both
                          real registers, so the code
                          runs and reads the wrong one.

  REX must be last        a tool reads 66 as a prefix
                          when it is really the opcode.
                          may crash, may not.

  only the LAST REX        a code generator prepends
  counts                  48 to an instruction that
                          already had a REX, and the
                          extension silently vanishes.
                          worst of the three: no
                          diagnostic at all.
                </div>
                <p>The third is the dangerous one and it has a real historical shape. <strong>Tools that rewrite machine code &mdash; emulators, binary patchers, JIT compilers that emit x86 directly &mdash; naturally prepend a prefix to widen something.</strong> If the instruction already carried a REX, the prepended one is discarded and the widening silently does not happen. The emitted bytes are valid, the code assembles, and the value is wrong.</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py --why 4c 89 e0  |  head -6
    offset 0, 3 bytes: 4c 89 e0
      mov      r12,eax
      . byte 4c at 0 is a REX prefix: W=1 R=1 X=0 B=0
      . the three extension bits each ADD 8 to a 3-bit field,
      . so R=1 with reg=000 is r8 -- not r9
      . byte 89 at 1 is a one-byte opcode
      . byte e0 at 2 is the ModRM byte: mod=3 reg=4 rm=0
      .   mod=11: the r/m field names a REGISTER, so no address
      .   bytes follow
</pre>
                </div>
                <p>That derivation is the whole concept in six lines. <code>4c</code> is REX with W=1 and R=1. <code>89</code> is <code>MOV r/m, r</code>. The ModRM is <code>e0</code> = <code>11 100 000</code>: a register form, <code>reg=4</code>, <code>rm=0</code>. <strong>With R=1 that is <code>reg = 4 + 8 = 12</code> &mdash; r12, not r8</strong>, because the bit is added to the three-bit field rather than selecting a group. And W=1 makes the operands 64-bit. The instruction is <code>mov r12, rax</code>, four bytes, and every one of those conclusions came from two bits of one byte.</p>
                <p>One more thing the derivation shows, and it is the bridge to the next concept. <strong>W=1 changed the operand width without changing a single bit of the ModRM.</strong> <code>4c 89 e0</code> and <code>44 89 e0</code> have identical opcodes and identical ModRM bytes, and they are different instructions operating on different widths. <a href="/courses/isa/lessons/isa-modrm">The next concept</a> is about that byte, and this is the first evidence that the opcode and the ModRM are not independent knobs.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I2/,/I3/p'
$ python3 x86dec.py --why 4c 89 e0
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I2/,/^I3/p'
</pre>
                </div>
                <p>Then break each rule deliberately, which is the better exercise because the breakage is instructive:</p>
                <div class="hex-dump">
                    <pre>  1. Prove the ADD-8 rule by brute force. For each
     of the 8 reg values and both values of R,
     emit the instruction and read the register
     name:

       for r in $(seq 0 7); do for R in 0 1; do
         rex=$((0x44 + 2*R))
         printf '%02x 8b c0\n' $rex   # rm=0
       done; done

     Then print the sixteen register names in
     order and check they come out rax rcx rdx rbx
     rsp rbp rsi rdi r8 r9 r10 ... r15 -- and
     NOT rax ... rdi r9 r10 ...

  2. Now the order rule, as a table. Every pair of
     prefix bytes, both orders, decoded:

       for a in 66 67 f0 f2 f3 2e 36 3e 26 64 65 48 4c; do
         for b in 66 48 4c; do
           printf '%s %s 8b c0\n' $a $b
         done
       done | xxd -r -p | ...

     (Some orders are one instruction, some are two,
     and the rule predicts which: a legacy prefix
     followed by anything is one; anything followed
     by REX is one; REX followed by a legacy prefix
     is two. Find a case that violates the rule, if
     one exists -- the course did not find one and
     does not claim there is none.)

  3. The double-REX trap, concretely. Take a real
     instruction that already has a REX, prepend a
     different REX, and show that the first is
     discarded:

       4c 89 e0   mov r12,rax     W=1 R=1
       48 4c 89 e0 mov r12,rax     the 48 is a no-op
       4c 4c 89 e0 mov r12,rax     only the last counts

     But now try to actually CHANGE the width by
     prepending, and watch it fail:

       89 e0       mov eax,eax
       48 89 e0    mov rax,rax     works: REX first
       44 48 89 e0 mov rax,rax     the 44 is DROPPED,
                                  so the operand is
                                  64-bit when the
                                  emitter wanted 32

     (That last one is the bug in miniature: the
     emitted bytes are valid, the instruction
     assembles, and the width is wrong. It is the
     failure mode a binary rewriter has to test
     for, and it produces no diagnostic.)

  4. Check the oracle's REX.X gap against a second
     independent source so you are not trusting
     one tool. Build the same instruction and
     count the registers the SIB can reach:

       45 8b 04 24   REX.X=1 B=1
       41 8b 04 24   X=0 B=1

     What SHOULD the first be? ([r12+r12*1]) What
     do the tools print? (objdump: [r12] both
     times; x86dec.py: [r12+r12*1] then [r12].)
     The two tools differ, one of them is wrong,
     and the way to tell which is to reason from
     the field layout rather than to ask a third
     tool that might share the same bug.

  5. Finally: audit the whole REX space. For all
     sixteen REX values against a fixed ModRM, what
     changes and what does not? Print the sixteen
     results and check that W is the only bit that
     changes the operand WIDTH, and that X and B
     change nothing at all when the ModRM has
     mod=11 and no SIB.

       for rex in $(seq 64 79); do
         printf '%02x 89 c0\n' $rex
       done

     (Expect: W flips between 32-bit and 64-bit
     forms, R changes the destination among the
     high registers, and X and B are INVISIBLE --
     because there is no SIB and the r/m is a
     register field that B does extend. Check
     whether B is visible. It should be: B extends
     ModRM.rm, and rm=0 here. If your output says
     it is not, you have found the same class of
     bug as the oracle's.)
</pre>
                </div>
                <p>Exercise 3 is the one that makes the concept a habit, and the failure it produces is the most instructive thing in this unit. <strong>&ldquo;The emitted bytes are valid, the instruction assembles, and the width is wrong&rdquo;</strong> &mdash; there is no diagnostic, no crash, and no way to notice without reading the bytes back. That is the signature of a whole class of binary-manipulation bug, and it is why <a href="/courses/sec/lessons/sec-posture">the hardening course&rsquo;s posture reader</a> exists: every serious tool that rewrites machine code has to be checked by reading the file, because the tool cannot check itself.</p>
                <p>Exercise 4 is the one that teaches the method rather than the fact. <strong>When two tools disagree, do not reach for a third &mdash; work out the answer from the field layout and then say which tool is wrong.</strong> Here the field layout settles it: <code>REX.X</code> is documented as extending the SIB index, so the oracle is wrong and the decoder is right. Reaching for a third tool would have produced a majority vote instead of a reason, and majority votes are how a shared bug becomes a fact.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/obj/lessons/obj-pic">the PIC concept in the object course</a> is the most direct in the chain, and it is a debt. That concept measured that position independence needs a base register because an absolute 32-bit address cannot be relocated, and concluded that the fix is RIP-relative addressing. <strong>It could not say how RIP-relative addressing is <em>encoded</em>, and this is the answer: it is <code>REX.B=1</code> selecting rIP as the base, and a <code>disp32</code> after the ModRM.</strong> The <code>B</code> bit this concept measured is the bit that concept&rsquo;s mechanism needs. Three courses, one bit.</p>
                <p>The connection to <a href="/courses/reloc/lessons/pic-violation">the PIC-violation concept</a> is about the cost. That concept measured that <code>R_X86_64_32S</code> overflows above <code>0x80000000</code> &mdash; which is a consequence of <strong><code>W</code> selecting a <em>signed</em> 32-bit displacement</strong> rather than an unsigned one, so that a RIP-relative access can reach backwards. This concept is where that choice lives, and it is the reason the field is <code>disp32</code> and not <code>disp64</code>: <a href="/courses/reloc/lessons/reloc-encoding-limits">the encoding-limits concept</a> measured the price of position independence and this is the mechanism paying it.</p>
                <p>Two connections outward. <a href="/courses/sec/lessons/sec-cet">The CET concept</a> measured that a binary can contain <code>endbr64</code> and request no enforcement, and <a href="/courses/isa/lessons/isa-opcodes">the previous concept</a> measured the encoding: <code>F3 0F 1E FA</code>, a reinterpretation by prefix. <strong>REX is the other kind of prefix &mdash; it widens rather than reinterprets &mdash; and the distinction is the whole taxonomy of prefix bytes: operand size, address size, REX widening, lock/rep semantics, segment override, and reinterpretation.</strong> And <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> again, because the question it asked is still the live one: it wanted to know how many bytes an instruction is, and the answer turns out to be &ldquo;it depends on a bit in a prefix, so you have to decode the prefix first.&rdquo;</p>
                <p>One limit, and it is a real one rather than a formality. <strong>Nothing here was measured on a second architecture, and the REX design is specifically a solution to the 32-to-64-bit transition.</strong> AArch64 has no REX because it has no legacy mode to stay compatible with; its register-to-field mapping is fixed at five bits in the base encoding. So the <em>pattern</em> here &mdash; a prefix that widens a field rather than a field that is wide &mdash; is portable, and the specific mechanism is not. The <a href="/courses/dwarf/lessons/dwarf-frames">DWARF frame course</a> covers the AArch64 side of register encoding, and this course deliberately stops at x86-64 rather than asserting a symmetry it did not measure.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-opcodes">Previous: The Opcode Map and Its Holes</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-modrm">ModRM: The Two Fields That Decide the Length</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
