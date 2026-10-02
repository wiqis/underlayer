// The Instruction Set Architecture — Module 2: The Prefix Layers
// Concept: all 256 combinations, the four mod classes, and the answer to the
// linker's standing question about instruction length.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_modrm() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ModRM: The Two Fields That Decide the Length — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>ModRM: The Two Fields That Decide the Length</h1>
            <div class="lesson-meta">24 min &middot; Module 2: The Prefix Layers &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/obj/lessons/obj-arch-table">The architecture-table concept</a> asked a linker two questions and refused to answer either:</p>
                <div class="formula">
  Q1a. how many bytes is the instruction?
  Q1b. at what offset within it does the field start?

  "converting [a byte offset] to a field requires
   decoding the instruction, because ... the field
   is at a position that depends on the encoding."

  that was correct and it was also the end of the
  road. this concept is the answer to Q1a.
                </div>
                <p>The answer is not a lookup table. It is <strong>two three-bit fields, and together they decide the length of the instruction</strong> &mdash; every other field in the encoding is a value, but these two are a <em>grammar</em>. That is a categorically different kind of thing, and it is why an x86 decoder has to read them before it can say anything.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I3/,/I4/p'
   all 256 ModRM bytes for opcode 8b /r (MOV r32, r/m32):
   bytes that did NOT decode as exactly one instruction: 0 []
   mod=11 (register) forms:  64 of 256
   mod!=11 (memory) forms:   192 of 256

   the four mod classes, one representative each:
     mod=00 rm=000  [reg]       8b 00                  mov    eax,DWORD PTR [rax]
     mod=00 rm=100  SIB         8b 04 24               mov    eax,DWORD PTR [rsp]
     mod=00 rm=101  RIP+disp32  8b 05 44 33 22 11      mov    eax,DWORD PTR [rip+0x11223344]
     mod=01 rm=000  [reg+disp8] 8b 40 11               mov    eax,DWORD PTR [rax+0x11]
     mod=10 rm=000  [reg+disp32] 8b 80 11 22 33 44      mov    eax,DWORD PTR [rax+0x44332211]
     mod=11 rm=000  register    8b c0                  mov    eax,eax
</pre>
                </div>
                <p><strong>All 256 values, each completed with the trailing bytes its own form requires, and every one decodes as exactly one instruction.</strong> That is not a triviality &mdash; it is the reason the encoding is a success. A 256-way space where all 256 values are usable, in an instruction set that has been extended for thirty years by collision, is a genuinely well-designed table.</p>
                <p>And the split is memorable: <strong><code>mod=11</code> is exactly 64 of the 256</strong> &mdash; a clean quarter &mdash; and those are the register forms. The other 192 are memory forms, and within those the <code>mod</code> field is choosing how to spend the next few bytes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Eight bits, three fields, and the two that do the structural work:</p>
                <div class="formula">
  ModRM  =  mm r r r r r
           |  | | | | +---- rm   : the r/m operand
           |  +---------+      reg  : the register operand
           +----------------    mod  : the MODE

  mm = 11   the r/m field names a REGISTER.
            no address bytes follow. DONE.
            this is 64 of the 256 values.

  mm != 11  the r/m field is an ADDRESS, and
            mod says how it is spelled:

     mod=00   no displacement ...
              ... except rm=101, which is
              RIP+disp32 and always has one

     mod=01   an 8-bit SIGNED displacement
     mod=10   a 32-bit SIGNED displacement

  and rm has one more special case, in every
  mode except 11: rm=100 means a SIB BYTE
  FOLLOWS, and the SIB supplies base and index.
                </div>
                <p>Read the <code>mod=00</code> exception carefully, because it is the one that breaks the tidy pattern. <strong>Normally <code>mod=00</code> means no displacement, so a two-byte instruction. But <code>rm=101</code> means no base register either &mdash; and an address with no base register must be relative to something, so the encoding switches to RIP-relative with a mandatory <code>disp32</code>.</strong></p>
                <div class="formula">
  mod=00  rm=000   [rax]              2 bytes:  8B 00
  mod=00  rm=101   [rip+disp32]       6 bytes:  8B 05 dd cc bb aa
                                 ~~~~~~~~~~~~~~~
  and rm=101 skips
  mod=01  rm=101   [rbp+disp8]        3 bytes:  8B 45 11
  mod=10  rm=101   [rbp+disp32]       6 bytes:  8B 85 dd cc bb aa

  note the gap: 2, 6, 3, 6. there is no 3-byte
  or 5-byte form of the no-base case, because
  the displacement is either absent or it is 4
  bytes wide. RIP-relative has no disp8 variant.
                </div>
                <p>And that gap is the answer to Q1a, stated as a rule a linker can implement:</p>
                <div class="formula">
  GIVEN a ModRM byte, the number of bytes that
  FOLLOW it is decided entirely by mod and rm:

    mod=11               0
    mod=00 rm=100        1 (SIB) + 0..4 (disp, see below)
    mod=00 rm=101        4
    mod=00 otherwise     0
    mod=01 rm=100        1 (SIB) + 1
    mod=01 otherwise     1
    mod=10 rm=100        1 (SIB) + 4
    mod=10 otherwise     4

  no other field in the instruction affects
  this count. not the opcode, not the prefix,
  not the immediate. ONLY mod and rm.
                </div>
                <p>That is the load-bearing result of the concept, and it is what makes the whole encoding tractable. <strong>The prefix bytes change what the instruction means; <code>mod</code> and <code>rm</code> change how long it is.</strong> A linker that needs the length has to decode exactly two fields and nothing else, which is a much smaller job than decoding the instruction.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Answer, and Where It Breaks</h2>
                <p>So: how many bytes is <code>8B 05 11 22 33 44</code>? The ModRM is <code>05</code> = <code>00 000 101</code>. <code>mod=00</code>, <code>rm=101</code> &mdash; the RIP-relative exception &mdash; so a <code>disp32</code> follows, and the instruction is six bytes. And the <code>disp32</code> starts at offset 2.</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py --why 8b 05 44 33 22 11
    offset 0, 6 bytes: 8b 05 44 33 22 11
      mov      eax,DWORD PTR [rip+0x11223344]
      . byte 8b at 0 is a one-byte opcode
      . byte 05 at 1 is the ModRM byte: mod=0 reg=0 rm=5
      .   mod=00: no displacement, except rm=101 which is
      .   RIP-relative and carries a 4-byte displacement
      .   4 bytes displacement at 2, value 0x11223344 (114421920)
      .   read little-endian, so the LOW byte is at the LOW
      .   address -- 11 22 33 44 means 0x44332211
</pre>
                </div>
                <p>So Q1b has an answer too: <strong>the field starts at offset 2</strong>, and it is read little-endian so the byte at the lowest address is the least significant. That is the last piece <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> needed, and it is a complete answer to a question that course correctly refused to guess at.</p>
                <p>Now where the tidy rule breaks, which is where the interesting part is. <strong>There is one family of opcodes where <code>rm</code> does not mean an address at all &mdash; it selects the operation.</strong> One byte covers eight different instructions:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py 83 c0 01 83 c8 01 83 f0 01 f6 c0 01 f6 d0
83 c0 01    add      eax,0x1
83 c8 01    or       eax,0x1
83 f0 01    xor      eax,0x1
f6 c0 01    test     eax,0x1
f6 d0       not      eax
</pre>
                </div>
                <p>Same opcode byte, same length for the first three, and the <strong>operation comes from the <code>reg</code> field &mdash; the field that elsewhere names a register.</strong> And the last two are the sharpest case in the encoding: <code>F6</code> is one byte, and whether an immediate follows depends on the <code>reg</code> field too.</p>
                <div class="formula">
  F6 /0  TEST r/m8, imm8     3 bytes:  F6 C0 01
  F6 /1  TEST r/m8, imm8     3 bytes
  F6 /2  NOT  r/m8           2 bytes:  F6 D0
  F6 /3  NEG  r/m8           2 bytes
  F6 /4  MUL  r/m8           2 bytes
  F6 /5  IMUL r/m8           2 bytes
  F6 /6  DIV  r/m8           2 bytes
  F6 /7  IDIV r/m8           2 bytes

  so a bare F6 is NOT a length. the ModRM reg
  field decides whether an immediate exists.
                </div>
                <p>Which breaks the rule I stated one paragraph ago, and the correction is instructive rather than embarrassing. <strong>The claim &ldquo;only <code>mod</code> and <code>rm</code> decide the length&rdquo; is true of the operand encoding and false of the opcode groups.</strong> For <code>80</code>, <code>81</code>, <code>83</code>, <code>C0</code>, <code>C1</code>, <code>D0</code>&ndash;<code>D3</code>, <code>F6</code>, <code>F7</code>, <code>FE</code> and <code>FF</code>, the <code>reg</code> field participates in the length. And that is a real design tension worth naming: <strong>the same field means &ldquo;a register&rdquo; in most opcodes and &ldquo;which operation&rdquo; in these ten, and a decoder has to know which before it can proceed.</strong></p>
                <p><a href="/courses/reloc/lessons/reloc-encoding-limits">The encoding-limits course</a> measured a related squeeze: position independence doubled the relocation count because the <code>disp32</code> needed a <code>R_X86_64_PC32</code> against a symbol that also needed one. <strong>This is the mechanism underneath that number</strong> &mdash; the <code>mod=00 rm=101</code> form is the one the compiler emits for every position-independent access, because it is the only encoding that needs no base register.</p>
            </div>

            <div class="unit unit-example">
                <h2>Computing the Length Instead of Storing It</h2>
                <p>Since <code>mod</code> and <code>rm</code> decide the trailing byte count, a decoder does not need a table of instruction lengths. It needs four lines of arithmetic, and that is the difference between a table that can be wrong and a rule that cannot:</p>
                <div class="formula">
  def trailing(modrm):
      mod, reg, rm = modrm &gt;&gt; 6, (modrm &gt;&gt; 3) &amp; 7, modrm &amp; 7
      if mod == 3:            return 0
      n = 0
      if rm == 4:             n += 1        # a SIB byte
      if mod == 1:            n += 1        # disp8
      elif mod == 2:          n += 4        # disp32
      elif mod == 0 and rm == 5:  n += 4    # RIP+disp32
      elif mod == 0 and rm == 4 and (sib &amp; 7) == 5:
                               n += 4        # no base -&gt; absolute disp32
      return n

  the last clause is the one that is easy to miss
  and the decoder got it wrong on its first run
  against a real binary. a SIB with base=101 at
  mod=00 has NO BASE, so the disp32 is an
  absolute address and it is always four bytes.
                </div>
                <p>That last clause is worth dwelling on, because it is a genuine two-level dependency. <strong>You cannot compute the length from the ModRM alone when <code>rm=100</code> &mdash; you have to read the SIB byte first, and the SIB byte&rsquo;s <code>base</code> field can then change the displacement width.</strong> So the decoder&rsquo;s read order is forced: ModRM, then SIB, then displacement. There is no way to parallelise it and no way to guess it.</p>
                <p>Which gives the correct shape for a length oracle a linker could use, and it is worth writing down because it is the artifact of a concept that otherwise stays theoretical:</p>
                <div class="formula">
  instruction_length(bytes, at) -&gt; int

    p = at
    while bytes[p] is a legacy prefix:  p += 1
    if bytes[p] is 0x40..0x4F:          p += 1   # REX, at most one,
                                               # and only if last
    if bytes[p] == 0x0F:                p += 1   # the escape
    p += 1                                        # the opcode

    if opcode takes a ModRM:
        p += 1 + trailing(bytes[p])

    if opcode takes an immediate:
        p += immediate_width(...)

    return p - at

  which is exactly what x86dec.py does, and why
  its --why output exists: a length function is
  four lines of arithmetic wrapped around six
  decisions, and every one of the decisions is a
  place to be wrong.
                </div>
                <p>And the honest caveat: that sketch is not the whole decoder, and the reason is instructive. <strong>Opcode groups, the <code>0F</code> escape, <code>0F 38</code> and <code>0F 3A</code>, mandatory prefixes like <code>F3 0F 1E FA</code>, and the <code>Rex.W</code>-does-not-widen-the-immediate rule all sit outside the four lines.</strong> The arithmetic gets the 192 memory forms right on its own; everything else needs a table. The <a href="/courses/isa/lessons/isa-decode">decoder concept</a> is about which parts need which.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I3/,/I4/p'
$ python3 x86dec.py --why 8b 05 44 33 22 11
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I3/,/^I4/p'
</pre>
                </div>
                <p>Then build the length function yourself, which is the exercise that turns the concept into code:</p>
                <div class="hex-dump">
                    <pre>  1. Write `trailing(modrm)` from the model above
     -- four lines -- then check it against the
     oracle for all 256 values:

       for m in range(256):
         bs = full_instruction_for(m)   # supply the bytes
         n, _ = ora(bs)
         assert trailing(m) == n - 2 - opcode_bytes(m)

     (Expect agreement on the 192 memory forms and
     confusion on the 64 register forms if you forget
     that mod=11 means ZERO trailing bytes and the
     base count already includes the ModRM itself.
     Off-by-one here is the single most common bug
     in a disassembler and it desynchronises
     everything after it.)

  2. Now the case that made the decoder wrong the
     first time: rm=100 with a SIB whose base is
     101 at mod=00. Enumerate it:

       for sib in range(256):
         bs = bytes([0x8b, 0x04, sib]) + \
              (b'\x11\x22\x33\x44' if (sib &amp; 7) == 5 else b'')
         ...

     How many of the 256 SIB bytes need a 4-byte
     displacement, and how many need none? (Expect:
     base=101 at mod=00 is the only one, so 32 of
     256 -- one for each ss/index combination.)

  3. Write a length-only decoder and run it over a
     real .text, requiring the chain to consume the
     section exactly. Do NOT resolve operands, do
     NOT name instructions. How few lines is it?

       def length(buf, i, end):
           ...

     (Around thirty, once the opcode table is
     included. The point is that a LENGTH decoder is
     small -- and it is enough to answer Q1a, which
     is all a linker ever needed. Everything else in
     this course is for the human.)

  4. Find the opcodes where the reg field affects
     the LENGTH rather than naming a register. The
     decoder's table has them:

       grep -n "GROUP_IMM_ONLY" -A6 x86dec.py

     For each, state the rule. Then check: is there
     any opcode where the reg field affects the
     length in a way that is NOT "reg 0 and 1 have
     an immediate"? (The 0F BA group is one:
     BT/BTS/BTR/BTC take an imm8, and the other four
     members do not. Same shape, different members.)

  5. Finally, the one that ties back to the course
     that asked the question. Take a real relocation
     against a real instruction and locate the field
     by hand, then check with the decoder:

       readelf -rW /bin/ls | head -5
       objdump -d /bin/ls | head -40

     Pick a PC32 relocation. Find the instruction
     the relocation entry points into. Compute where
     the disp32 is using mod and rm. Read the 4
     bytes and check they are the addend.

     (This is exactly the workflow obj-arch-table said
     a linker performs and declined to do. Doing it
     once by hand is worth more than the whole
     concept, and doing it twice is worth more than
     that -- because the second time you will not
     need the decoder and the first time you will
     get it wrong.)
</pre>
                </div>
                <p>Exercise 3 is the one with the best answer in the concept, and the answer is a deflation that is also the point. <strong>A length-only decoder is about thirty lines and it answers the linker&rsquo;s question completely.</strong> Everything else &mdash; the mnemonics, the operand text, the SIB arithmetic, the condition codes &mdash; exists for a human reading the result. The mission of this collection is to parse a format into a working executable, and the honest shape of that here is: <em>the part a machine needs is small, and the part a person needs is the course</em>.</p>
                <p>Exercise 5 is the one that closes the loop. <strong>Locating a <code>disp32</code> inside a real instruction by hand, using only <code>mod</code> and <code>rm</code>, is the workflow <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> described and would not perform.</strong> The chain built a linker course that needed this and an architecture table that named the need, and left a gap between them. This is the gap, and the first time through you will get it wrong &mdash; which is exactly the argument for the concept existing rather than a table of answers.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> is the whole concept and it deserves to be stated without hedging. That concept asked &ldquo;how many bytes is the instruction?&rdquo; and said a linker must decode it; <strong>this concept says the linker must decode exactly two three-bit fields, and here is the four-line function that does it.</strong> The chain had a real gap &mdash; a format whose consumers were told they needed a capability no course taught &mdash; and the collection&rsquo;s own method found it: measure, notice what is missing, build the thing.</p>
                <p>The connection to <a href="/courses/link/lessons/link-phdrs">the linker-script concept</a> is about where these instructions end up. That course found the default script&rsquo;s rule for <code>.plt</code> and noted the section is sometimes empty; <strong>a <code>.plt</code> entry is <code>jmp [rip+disp32]</code> for a lazily-bound function, which is <code>FF 25</code> followed by a ModRM of <code>mod=00 rm=101</code> and a <code>disp32</code> &mdash; six bytes</strong>, and under <a href="/courses/sec/lessons/sec-relro">full RELRO</a> the form changes to <code>jmp [rip+disp32]</code> through a different register so the table can be sealed. Two courses and a hardening flag, all visible in one ModRM byte.</p>
                <p>Two connections outward, both about fields doing double duty. <a href="/courses/obj/lessons/obj-addends">The addend concept</a> measured why a disassembler prints a symbol as &ldquo;minus four&rdquo;, and the answer is in this unit: <strong>the four is the <code>disp32</code> field, and the printed value is the target, so the field&rsquo;s contents are the target less four.</strong> That is a link-time convention living inside an instruction encoding, and it is the clearest example in the chain of a value meaning one thing in the file and another on screen. And <a href="/courses/isa/lessons/isa-sib">The SIB concept</a> is where <code>rm=100</code> stops the story: this concept establishes that a SIB byte may follow, and the next one is about what it contains and why one of its field values also changes the displacement width.</p>
                <p>One limit, and it is the same limit this course keeps hitting honestly. <strong>Everything here is x86-64, measured on one machine, against one reader.</strong> Where that reader is known to be wrong &mdash; it ignores <code>REX.X</code> on the SIB index &mdash; the crosscheck compares only what both tools are reliable about, and the disagreement is written down rather than resolved by assertion. The four-line length function is portable in its <em>shape</em> to any variable-length ISA and useless without the table, and the <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">DWARF standard-opcodes concept</a> covers the other side of that trade for a fixed-width architecture.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-rex">Previous: REX: Four Bits That Add Eight</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-sib">SIB: The Byte That Exists Because rsp Is Special</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
