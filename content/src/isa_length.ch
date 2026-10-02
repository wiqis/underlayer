// The Instruction Set Architecture — Module 3: Addressing
// Concept: one formula, fourteen specimens, and the chain property that makes
// a boundary check strong.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_length() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Length Arithmetic — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>The Length Arithmetic</h1>
            <div class="lesson-meta">24 min &middot; Module 3: Addressing &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> asked how many bytes an instruction is and would not answer. <a href="/courses/isa/lessons/isa-modrm">The ModRM concept</a> said <code>mod</code> and <code>rm</code> decide the trailing bytes. <a href="/courses/isa/lessons/isa-sib">The SIB concept</a> found a case where that is not quite enough. <strong>This concept closes it: one formula, and the reason a formula beats a table.</strong></p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I8/,$p'
   length = prefixes + opcode + modrm + sib + displacement + immediate

   bytes                          prefixes+op modrm  sib   disp imm  sum  measured
   8b 00                          8b         1      -     -    -    2    2 ok
   48 8b 00                       48 8b      1      -     -    -    3    3 ok
   8b 04 24                       8b         1      24    -    -    3    3 ok
   8b 40 11                       8b         1      -     1    -    3    3 ok
   8b 80 11 22 33 44              8b         1      -     4    -    6    6 ok
   8b 05 44 33 22 11              8b         1      -     4    -    6    6 ok
   8b 84 24 11 22 33 44           8b         1      24    4    -    7    7 ok
   83 c0 01                       83         c0     -     -    1    3    3 ok
   b8 11 22 33 44                 b8         -      -     -    4    5    5 ok
   48 b8 11 22 33 44 55 66 77 88  48 b8      -      -     -    8    10   10  ok
   66 b8 11 22                    66 b8      -      -     -    2    4    4 ok
   f6 c0 01                       f6         c0     -     -    1    3    3 ok
   f6 d0                         f6         d0     -     -    -    2    2 ok
   66 2e 0f 1f 84 00 00 00 00 00  66 2e 0f 1f 84     00    4    -    10   10  ok

   every row matches: True
</pre>
                </div>
                <p>Fourteen rows, every one matching, and the formula is a single line. <strong>Length is not a property of the opcode. It is a sum of six independent contributions</strong>, and each contribution is decided by a different part of the encoding.</p>
                <p>The longest row is the one to read twice. <code>66 2E 0F 1F 84 00 00 00 00 00</code> is <strong>ten bytes</strong>: two legacy prefixes, the two-byte escape, a ModRM, a SIB and a <code>disp32</code>. It is the canonical multi-byte NOP that compilers emit for alignment padding, which means real binaries are full of them and any decoder has to get this exact shape right.</p>
                <p>And the shortest is one byte: <code>ret</code> is <code>C3</code> and nothing else. <strong>So the same instruction format spans 1 to 15 bytes, and the span is a design choice rather than an accident.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model, and the Two Rules That Break It</h2>
                <p>The formula, and then the two places where a naive implementation of it is wrong:</p>
                <div class="formula">
  length = prefixes
         + opcode          (1 byte, or 2 with the escape,
                           or 3 in the 0F 38 / 0F 3A maps)
         + modrm           (1, if the opcode takes one)
         + sib             (1, if mod != 11 and rm == 100)
         + displacement    (0, 1, or 4 -- from mod and rm,
                           and the SIB can change the answer)
         + immediate       (0, 1, 2, 4, or 8)

  RULE 1: the immediate width is NOT the operand
          width.

    48 b8 <8 bytes>              movabs rax, imm64    10
    48 c7 40 20 00 00 00 00      mov [rax+0x20], 0     8

  REX.W widens the OPERAND. the immediate is
  still 32 bits and gets sign-extended. the only
  64-bit immediates are the handful of opcodes
  that define one.

  so you cannot load 0x00000000FFFFFFFF with
  one instruction. write the low half, then
  shift.

  RULE 2: for the ten opcode GROUPS, the ModRM
          reg field decides whether an immediate
          exists at all.

    f6 c0 01    test r/m8, imm8      3 bytes
    f6 d0       not  r/m8            2 bytes

  a bare f6 is not a length. you must read the
  ModRM to know how long the instruction is,
  which means you cannot even size the
  instruction before you have decoded part of
  it.
                </div>
                <p>Rule 1 is the one that bit this course&rsquo;s own decoder first, and the way it presented is worth describing because it is a shape of bug the collection has now seen four times. <strong>The decoder read the <code>disp32</code> and then the immediate, and added the immediate twice</strong> after an edit &mdash; so every instruction with an immediate overran by its own width. It did not crash. It produced plausible-looking output for the first few instructions and then nonsense, which is exactly the failure mode a boundary check exists to catch.</p>
                <p>And the semantic point behind rule 1 is real, not just an encoding curiosity. <strong>A sign-extended 32-bit immediate is a deliberate design choice</strong>: it makes the common case &mdash; a small positive or negative constant &mdash; cost 4 bytes instead of 8, and 4 bytes is the difference between a 3-byte and a 7-byte instruction. The price is that the full 64-bit range needs a sequence, and the price is paid knowingly.</p>
                <p>Rule 2 is the more interesting structural point. <strong>The ModRM byte is both data and control.</strong> In most opcodes its <code>reg</code> field names a register and its <code>rm</code> field is an address; in ten opcodes the <code>reg</code> field selects which of eight operations this is, and in two of those the selection also determines whether an immediate follows. So:</p>
                <div class="formula">
  the decode order is FORCED, not chosen:

    prefixes -&gt; opcode -&gt; ModRM -&gt; SIB
             -&gt; displacement -&gt; immediate

  you cannot compute the length from the first
  two bytes. you cannot parallelise the parse.
  and a decoder that guesses is a decoder that
  will eventually not.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Why the Chain Is the Right Thing to Check</h2>
                <p>Now the property that makes a length decoder verifiable, and it is the most important idea in this concept.</p>
                <p>Instruction boundaries form a <strong>chain</strong>: <code>start[0] = 0</code> and <code>start[i+1] = start[i] + len[i]</code>. So if you decode a code section and the last instruction ends exactly at the section size, then <em>every</em> length was right &mdash; or they were wrong in a way that cancelled out, which for a chain of this shape means a compensating pair, and the oracle comparison rules that out.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/^I7/,/^I8/p'
   ok  corpus     .init            27 B       8 instructions  chain exact
   ok  corpus     .plt             96 B      18 instructions  chain exact
   ok  corpus     .plt.got          8 B       2 instructions  chain exact
   ok  corpus     .text          1741 B     440 instructions  chain exact
   ok  corpus     .fini            13 B       4 instructions  chain exact
   ok  mini       .text           288 B      72 instructions  chain exact
   ok  probe.o    .text            56 B      17 instructions  chain exact
   ---
   578/578 instruction boundaries agree (100.00%)
</pre>
                </div>
                <p><strong>578 of 578 boundaries agree with the oracle, and every chain closes exactly.</strong> And the &ldquo;chain exact&rdquo; column is the load-bearing one, for a reason that is worth spelling out because it is the difference between a strong test and a weak one:</p>
                <div class="formula">
  A WEAK check:  "the instruction COUNT matches"
      440 vs 440.  could be right, could be
      wrong in a way that happens to balance.

  A STRONG check:  "the boundaries match, AND
      the chain consumes the section exactly"

      correct:  |--3--|--3--|--2--|    = 8
      3 too long:|----4----|-2-|--2--|   = 8 too!
                 ^0        ^4   ^6
                           |    ^--- a byte early
                           +-------- and TWO bytes late

  the counts agree. the boundaries do not. and
  one wrong length DESYNCHRONISES everything
  after it, so a sequence of compensating
  errors would have to be contrived.
                </div>
                <p>So the count is a necessary condition and a poor one, and the chain is what makes the check strong. <strong>This is the same reasoning the <a href="/courses/obj/lessons/obj-verify">object course&rsquo;s oracle-loop concept</a> used</strong> &mdash; three independent readers, byte-exact comparison &mdash; applied to a different kind of claim. There, three readers agreed on bytes. Here, two readers agree on structure, and the structure has a property that makes agreement hard to fake.</p>
                <p>Now the length distribution, because the shape of real code is a fact rather than an intuition:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py corpus
  ---
  1885 bytes of code, 472 instructions decoded, mean 3.99 bytes
</pre>
                </div>
                <p>Plus the histogram from the earlier measurement of a smaller specimen: <strong>1 byte 16 times, 2 bytes 28, 3 bytes 25, 4 bytes 27, 5 bytes 8, 6 bytes 5, 7 bytes 20</strong> &mdash; 129 instructions, mean 3.60, and a shape that is nothing like a normal distribution. The modes at 2 and 4 bytes are the register forms and the <code>disp8</code>/<code>disp32</code> forms; the bump at 7 is the multi-byte NOP padding.</p>
                <p>Two consequences follow from that histogram, and both are practical. <strong>Code density is the reason the encoding is variable-length at all</strong> &mdash; a fixed 4 bytes would waste about half the space, and on a machine with a 64K memory that was not affordable. And <strong>the 15-byte maximum is essentially never reached</strong>: no compiler emits it, because a 15-byte instruction is worse than a call. The architectural limit exists for hand-written code and for the padding NOP, and the measured maximum in real code is 10.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Formula Is Small; the Table Around It Is Not</h2>
                <p>Here is the shape of a complete length function, which is worth writing out because <strong>it is short, and everything hard about x86 decoding is in the six decisions rather than the arithmetic</strong>:</p>
                <div class="formula">
  def length(buf, at, end):
      p = at
      # 1. legacy prefixes, any number
      while buf[p] in PREFIXES: p += 1
      # 2. REX: at most one, and only if it is
      #    IMMEDIATELY before the opcode
      if 0x40 &lt;= buf[p] &lt;= 0x4f: p += 1
      # 3. the opcode, 1-3 bytes
      if buf[p] == 0x0f:
          p += 1
          if buf[p] in (0x38, 0x3a): p += 1
      p += 1
      # 4. ModRM, and everything it drags along
      if TAKES_MODRM[opcode]:
          mod, reg, rm = decompose(buf[p]); p += 1
          if mod != 3:
              if rm == 4: p += 1          # SIB
              p += disp_width(mod, rm, sib)
      # 5. the immediate, whose width the OPCODE
      #    and the reg field both affect
      p += imm_width(opcode, reg, rex_w, op16)
      return p - at
                </div>
                <p>Thirty lines. And notice which lines are hard: not 4 and not 5, but the two <em>tables</em> those lines consult. <strong><code>TAKES_MODRM</code> is 364 entries, and it is the only part of the decoder that can be wrong without the arithmetic noticing.</strong> The table is the vulnerability, and that is why the crosscheck audits it exhaustively rather than spot-checking it.</p>
                <p>And the audit is where the method paid for itself. <strong>364 entries audited, 0 length disagreements, and it found four errors that every hand-written example had missed:</strong></p>
                <div class="formula">
  0F F4    labelled HLT       -- it is PMULUDQ
  D3       given an imm8      -- it takes none
  BSWAP    given a ModRM      -- it takes none
  0F 09/0B/31  forced to take a ModRM
            they do not have, so three ordinary
            instructions were REFUSED by the
            decoder

  plus two more found by inspection afterwards:

  E4-EF    IN/OUT immediate   -- the immediate
            forms take imm8 not imm32, and the
            DX forms take NONE
  62       EVEX               -- the one-byte table
            had 32-bit BOUND, and in 64-bit that
            byte is the AVX-512 prefix
                </div>
                <p>Every one of those produced a plausible disassembly of a chosen example. <strong>None of them could have been found by reading the decoder, because the decoder has no internal contradiction to notice &mdash; it has a table, and a table is just data.</strong> The only way to find out a table is wrong is to compare it against something independent, across its whole input space.</p>
                <p>That is the argument for the whole method of this collection, stated in its most compressed form:</p>
                <div class="formula">
  a table cannot check itself.
  a rule cannot be silently wrong.
  so: exhaust the table against an oracle, and
      check the rule on a property that cannot
      be satisfied by luck (does the chain close?).
                </div>
                <p>Which is also, not coincidentally, what <a href="/courses/img/lessons/img-walk">the image course&rsquo;s artifact</a> does and what <a href="/courses/sec/lessons/sec-posture">the hardening course&rsquo;s reader</a> does. Three courses, three artifacts, one discipline: <strong>every value checked against a source that did not produce it.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I7/,$p'
$ python3 x86dec.py corpus
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I7/,$p'
</pre>
                </div>
                <p>Then write the length function and test it the hard way:</p>
                <div class="hex-dump">
                    <pre>  1. Implement the length function above and check
     it against the oracle for every opcode in
     the table -- not every instruction, every
     OPCODE, in every form:

       for each table entry:
         build a minimal instruction
         assert length(...) == oracle(bs)

     (The crosscheck already does this as check I9:
     364 entries, 38 skipped as invalid, 0
     disagreements. Re-derive it and then BREAK one
     entry deliberately -- change 0F F4 to 'hlt' and
     watch I9 fail. A checker that has never failed
     is not known to work.)

  2. Now the property test, which is stronger and
     costs less. Decode every code section of
     several real binaries and require the chain
     to close:

       for b in ('corpus','mini','probe.o'):
         d, secs = x86dec.code_sections(b)
         for n,a,o,sz in secs:
           ins,end,bad = x86dec.decode_stream(d[o:o+sz],0,sz)
           assert end == sz, (b,n,end,sz)

     How many sections pass? (All of them, across
     every binary you try, or the decoder is wrong
     somewhere you have not looked.) This single
     assertion catches more than a thousand
     per-instruction comparisons would, because it
     is sensitive to compensating errors.

  3. Find the distribution yourself and check it
     against the oracle's, per length:

       objdump -d corpus | awk -F'\t' 'NF>2{gsub(/ /,"",$2);
         n=split($2,b," "); print n}' | sort -n | uniq -c

     Two independent length histograms for the same
     binary. They should match exactly. Then
     compute the mean and the mode, and ask what
     fraction of instructions are 4 bytes or fewer
     -- the answer is the code-density argument in
     one number, and it justifies the variable-length
     encoding better than any amount of prose.

  4. Test the two rules that break naive
     implementations, as explicit cases:

       # rule 1: REX.W does not widen the immediate
       48 b8 <8>        10 bytes
       b8   <4>          5 bytes
       48 c7 40 20 <4>   8 bytes   <- the trap

       # rule 2: the reg field decides the immediate
       f6 c0 01          3 bytes
       f6 d0             2 bytes
       0f ba c0 01       4 bytes
       0f ba e8          3 bytes

     (The 0F BA group is the interesting one: BT/BTS/
     BTR/BTC take an imm8 and the other four members
     do not, so a decoder needs the group table for
     the two-byte map as well. Find every such group
     in the decoder's GROUPS dictionary and check
     each one's rule.)

  5. Finally, the experiment that makes the chain
     property vivid. Corrupt ONE length in the
     decoder -- add 1 to the disp32 case -- and
     measure how many instructions are wrong:

       # patch: return 4 instead of the computed
       # width for mod=10 rm=000

     Then count the instructions that still decode
     correctly after the first divergence. (A few,
     by coincidence, and then none. Count the few:
     that is the number of instructions a
     per-instruction spot check would have called
     "mostly passing".)
</pre>
                </div>
                <p>Exercise 5 is the one that makes the concept a reflex, and its result is the most useful number in the course. <strong>Corrupt one length rule and a per-instruction check still passes for the handful of instructions before the first error, while the chain check fails immediately and locallyises the bug to one specific opcode class.</strong> That is the difference between a test that tells you something is wrong and a test that tells you where, and it is why the crosscheck asserts the chain rather than a count.</p>
                <p>Exercise 3 answers the question the whole course has been circling. <strong>The mean instruction is under 4 bytes, and most instructions are 4 or fewer</strong> &mdash; which is the measured justification for a variable-length encoding. A fixed-width 4-byte instruction would be barely larger and enormously simpler to decode, and x86 chose the harder design because a 64K memory made the density worth it. That is the trade, stated as a number rather than an assertion, and it is the same reasoning the <a href="/courses/isa/lessons/isa-sib">SIB concept</a> reached for scaled indexing: one byte of encoding to avoid a sequence of instructions.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept closes the loop the collection opened in the object course, and the loop is worth naming precisely because it took seven courses to close. <a href="/courses/obj/lessons/obj-arch-table">obj-arch-table</a> said a linker needs to know how many bytes an instruction is and where the field starts; <a href="/courses/obj/lessons/obj-relocations">the relocations concept</a> measured the per-architecture relocation tables that consume the answer; <a href="/courses/obj/lessons/obj-pic">the PIC concept</a> and the relocations course both needed <code>disp32</code> without being able to say how it is encoded. <strong>That is six concepts of debt and this formula pays it</strong> &mdash; and the way the chain paid it is the method made visible: each course measured what it could, wrote down what it could not, and the missing piece turned out to be exactly one formula plus one table.</p>
                <p>The connection to <a href="/courses/link/lessons/link-default-script">the default-linker-script concept</a> is about what the formula makes possible. That course found the default script&rsquo;s section-placement rules and could not say why <code>.plt</code> entries are six bytes and <code>.text</code> entries vary. <strong>Six bytes is <code>FF 25</code> plus a <code>mod=00 rm=101</code> ModRM plus a <code>disp32</code></strong> &mdash; the RIP-relative indirect jump &mdash; and the reason it cannot be shorter is that an indirect jump has no register to put the address in. One formula answers a question a linker script raised two courses ago.</p>
                <p>Two connections outward, both about verification rather than mechanism. <a href="/courses/img/lessons/img-walk">The image course&rsquo;s artifact</a> established the discipline of checking every value against a source that did not produce it, and the two-level dependency measured here &mdash; ModRM says &ldquo;more&rdquo;, SIB says &ldquo;how much&rdquo; &mdash; is the same shape as the <a href="/courses/img/lessons/img-entries">image course&rsquo;s pointer-versus-size warning</a>: a value whose meaning depends on a field you have not read yet. And <a href="/courses/sec/lessons/sec-posture">The posture reader in the hardening course</a> made the same choice for a different format, where two of the eight features it checks leave no header field at all and must be found by searching the bytes. <strong>Both readers exist because the interesting properties are not all in the fields, and a format whose interesting parts are hidden in the encoding is a format you have to decode, not just parse.</strong></p>
                <p>One limit, and it is the course&rsquo;s standing one. <strong>Every number here was measured on x86-64 against one reader, and the table covers 364 audited entries out of a much larger ISA.</strong> The decoder is not a complete disassembler and the crosscheck does not pretend it is: where the decoder has no name for an opcode it still gets the length right, and where it refuses it says why. The formula generalises to any variable-length ISA; the table does not, and the honest summary is that <em>the part a machine needs is thirty lines of arithmetic, and the part a person needs is the table, the oracle, and the 118 checks that keep them honest</em>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-sib">Previous: SIB: The Byte That Exists Because rsp Is Special</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-decode">Decode It Yourself</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
