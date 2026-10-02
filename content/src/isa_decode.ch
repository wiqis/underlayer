// The Instruction Set Architecture — Module 4: Decode It Yourself
// Concept: a decoder that shows its work, and the table audit that finds what
// examples miss.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_decode() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Decode It Yourself — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>Decode It Yourself</h1>
            <div class="lesson-meta">25 min &middot; Module 4: Decode It Yourself &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Six concepts, one artifact, and a habit. The artifact is a decoder: give it bytes and it tells you what instructions they are, <strong>and it prints the derivation for every field it consumed</strong>. It does not shell out to <code>objdump</code> and it does not use a compiler. It parses the ELF section table to find code, then decodes each instruction from the rules in this course.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ python3 x86dec.py corpus | tail -12
  .plt.got          0x2000        8 B       2 instructions
  .fini            0x22a0        13 B       4 instructions
  ---
  1885 bytes of code, 472 instructions decoded, mean 3.99 bytes
</pre>
                </div>
                <p>And the default view, which is the one that matters:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py 4889e84883ec205bc3
48 89 e8  movq     rax,rbp
48 83 ec 20 subq     rsp,0x20
5b        pop      rbx
c3        ret
</pre>
                </div>
                <p>That is a function prologue, epilogue and return, decoded from nine bytes with no toolchain involved. <strong>It is the collection&rsquo;s mission stated as a program</strong> &mdash; a format, parsed by hand, into a working answer &mdash; and it is what <a href="/courses/obj/lessons/obj-emit">the object course&rsquo;s <code>emit</code> concept</a> did one level down, where the artifact <em>wrote</em> a valid object file rather than reading one.</p>
                <p>So why does it need a course? Because <strong>a disassembler that prints only answers is a tool you have to trust, and this collection&rsquo;s standing rule is that you never have to trust anything you can read.</strong> So:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py --why 8b 44 24 20
    offset 0, 4 bytes: 8b 44 24 20
      mov      eax,[rsp+32]
      . byte 8b at 0 is a one-byte opcode
      . byte 44 at 1 is the ModRM byte: mod=1 reg=0 rm=4
      .   mod=01: an 8-bit SIGNED displacement follows
      .   rm=100 means a SIB byte follows: 24 at 2
      .     ss=0 -&gt; scale 1,  index=4,  base=4
      .     index=100 with REX.X=0 means NO INDEX
      .   1 byte displacement at 3, value 32 (0x20)
      .   read little-endian, so the LOW byte is at the LOW
      .   address -- 11 22 33 44 means 0x44332211
</pre>
                </div>
                <p><strong>Every line names the byte it came from and the decision it forced.</strong> That is the difference between a mnemonic and an argument.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three design decisions, and each one is a position rather than a default.</p>
                <div class="formula">
  1. LENGTH AND STRUCTURE ARE THE CONTRACT.

     the decoder resolves the encoding exactly for
     364 audited opcodes. naming is a bonus, and
     where there is no name it prints

         (op 0f 6c)

     rather than guessing. a guessed mnemonic is a
     claim nothing checked. a correct length with
     no name is an honest PARTIAL answer, and the
     length is the part a linker needs.

  2. NO TOOLCHAIN, ANYWHERE.

     the ELF section table is read with
     struct.unpack_from. no readelf, no objdump,
     no compiler. a crosscheck that used objdump
     to verify objdump's own fields would prove
     only self-consistency.

  3. DERIVATION OVER RESULT.

     --why prints what each field DECIDED, not
     what it is. a reader who disagrees with the
     output can find the line where the
     disagreement happens. a reader given only
     "mov eax,[rsp+32]" has nowhere to look.
                </div>
                <p>And there is a fourth decision that is a limitation stated rather than a shortfall, and it is the one that makes the tool honest:</p>
                <div class="formula">
  THE TOOL NAMES A SUBSET, ON PURPOSE.

    364 opcodes: length resolved, audited, exact
    a smaller subset: also named

    so a real binary decodes with a realistic
    mixture of names and (op xx) markers. that is
    the design working, not failing -- and it is
    the honest boundary of what a 1000-line
    decoder can claim.

    the alternative -- a table with names for
    everything and no audit -- would look more
    complete and be less trustworthy, and this
    collection has measured that trade three times
    now.
                </div>
                <p>Which is worth stating as the general principle, because it applies to every artifact in this collection: <strong>an artifact that says &ldquo;I do not know&rdquo; in a specific place is more useful than one that is confidently wrong everywhere.</strong> The <a href="/courses/obj/lessons/obj-verify">object course&rsquo;s verifier</a>, the <a href="/courses/img/lessons/img-walk">image course&rsquo;s stack walker</a> and the <a href="/courses/sec/lessons/sec-posture">hardening course&rsquo;s posture reader</a> all have the same property, and all three were built after their authors got something wrong and found that a specific refusal was worth more than a plausible guess.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Two Decoders Agree</h2>
                <p>The claim that matters is not that the decoder works on examples the author chose. It is that it agrees with an independent implementation across real code:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/^I7/,/^I8/p'
   ok  corpus     .init            27 B       8 instructions  chain exact
   ok  corpus     .plt             96 B      18 instructions  chain exact
   ok  corpus     .plt.got          8 B       2 instructions  chain exact
   ok  corpus     .text          1741 B     440 instructions  chain exact
   ok  corpus     .fini            13 B       4 instructions  chain exact
   ok  mini       .init            27 B       8 instructions  chain exact
   ok  mini       .plt             16 B       3 instructions  chain exact
   ok  mini       .plt.got          8 B       2 instructions  chain exact
   ok  mini       .text           288 B      72 instructions  chain exact
   ok  mini       .fini            13 B       4 instructions  chain exact
   ok  probe.o    .text            56 B      17 instructions  chain exact
   ---
   578/578 instruction boundaries agree (100.00%)
</pre>
                </div>
                <p><strong>578 of 578, and every chain closes exactly</strong> across three specimens including an object file, where every displacement is a zero waiting for a linker. And the crosscheck is not a summary of that run &mdash; it re-derives all 118 claims from a fresh build:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py 2&gt;&amp;1 | tail -16
  A     6 passed   0 failed
  I1    5 passed   0 failed
  I2   10 passed   0 failed
  I3    4 passed   0 failed
  I4   10 passed   0 failed
  I5    6 passed   0 failed
  I6   19 passed   0 failed
  I7   33 passed   0 failed
  I8   23 passed   0 failed
  I9    2 passed   0 failed
  ------------------------------------------------------------------------------
  118/118 checks passed
  ALL CLAIMS HOLD
</pre>
                </div>
                <p>Six of those are in group I9 and they are the two most valuable checks in the file, because I9 is the one that found the bugs:</p>
                <div class="formula">
  I9  the WHOLE TABLE, audited

     for each of 364 entries:
         build a minimal instruction in the form
         the table claims
         ask objdump how many bytes it is
         compare

     364 entries, 38 skipped as invalid
     (the oracle itself calls them (bad)),
     0 disagreements.

     and the errors it caught before the audit
     existed:
       0F F4  labelled HLT     -- it is PMULUDQ
       D3     given an imm8    -- it takes none
       BSWAP  given a ModRM    -- it takes none
       0F 09/0B/31  forced to take a ModRM they
               do not have, so three ordinary
               instructions were REFUSED
                </div>
                <p><strong>Every one of those four was invisible in isolation.</strong> Each produced a plausible-looking disassembly of a hand-picked example, because the example was the case the author had in mind and the table was right about that case. A table has no internal contradiction to notice, so exhausting it against an independent source is the only way to find out.</p>
                <p>And here is the part worth reading twice, because it is the collection&rsquo;s method applied to its own tooling. <strong>Three separate parsers in this course were wrong about the oracle&rsquo;s output format, and every one of the failures looked like the decoder being wrong.</strong></p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/A SECOND MODE/,/confused/p'
   0x62 is the AVX-512 EVEX prefix in 64-bit mode, so it collides with
   the 32-bit BOUND instruction exactly the way 0x40 collides with INC.
   and a disassembler WITHOUT AVX-512 support refuses it and loses the
   instruction stream from that point on -- which is why the corpus
   below is built -march=x86-64: a reader that gives up is not a reader
   that disagrees, and the two must not be confused.
</pre>
                </div>
                <p>Three of them, and each taught the same lesson:</p>
                <div class="formula">
  1. objdump WRAPS long encodings across lines --
     7 bytes then a continuation with no mnemonic.
     an instruction is not a line. a line-per-
     instruction parser called a correct 10-byte
     NOP 7 bytes long.

  2. objdump sometimes emits an entry with NO
     MNEMONIC for a byte run it cannot name. a
     parser requiring three tab-separated fields
     dropped it silently, and reported 578/611
     agreement when the decoder was right.

  3. objdump IGNORES REX.X on the SIB index, so
     it prints [rsp] where the field layout says
     [rsp+r12*1]. the decoder applies the bit and
     the oracle does not.

  in all three cases the FIX was to the CHECK,
  never to the decoder. a check that fails for the
  wrong reason is worse than no check, because it
  teaches you to ignore it -- and the fix in each
  case was to narrow the question until both tools
  were reliable about it.
                </div>
                <p>That is why the crosscheck compares <strong>boundaries and lengths</strong> and never operand text. Not because operand text is uninteresting &mdash; it is printed, for a human &mdash; but because <em>asking a checker a question one of your tools is known to get wrong is how a correct tool gets &ldquo;fixed&rdquo; into a broken one.</em></p>
            </div>

            <div class="unit unit-example">
                <h2>Using It On Things You Did Not Build</h2>
                <p>The real use is not your own binaries. It is everything else, and it is the same use the other artifacts in this collection have:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py /usr/bin/objdump | tail -3
$ python3 x86dec.py --section .text /bin/ls | head -20
$ python3 x86dec.py --why 0f 1f 84 00 00 00 00 00
$ python3 crosscheck.py -v 2&gt;&amp; | head -40
</pre>
                </div>
                <p>Three uses in increasing order of value. <strong>Reading unfamiliar code</strong> &mdash; the <code>--why</code> output teaches the encoding while it answers the question, which is a better way to learn an ISA than a reference. <strong>Comparing two builds</strong> &mdash; decode both and diff the instruction streams, and a compiler-version difference shows up as a shift in the mean length. <strong>Failing a build</strong> &mdash; and this is the one that pays, because the chain property makes it a cheap assertion:</p>
                <div class="formula">
  for every binary you ship:
      decode every code section
      require the chain to consume it exactly

  a failure means the decoder met an opcode it
  does not know, which is the most useful thing a
  decoder can tell you about a binary it has never
  seen. "I do not understand these four bytes" is
  actionable. "The mean instruction is 4.1 bytes"
  is not.
                </div>
                <p>That is the honest division of labour, and it is the same one the <a href="/courses/sec/lessons/sec-posture">posture reader</a> makes. <strong>A decoder&rsquo;s most valuable output on an unknown binary is a refusal, not a summary</strong>, because a refusal localises and a summary does not. The decoder was built on x86-64 and would decline most of a modern AVX-512 binary &mdash; and declining, with a reason, is more useful than a mean-length statistic computed over the 40% it understood.</p>
                <p>One thing the tool deliberately does not do, which is worth naming because every decoder eventually gets asked to. <strong>It does not produce a coverage percentage, and it does not claim completeness.</strong> The 364-entry table is audited; the naming subset is not claimed to be anything in particular. A tool that printed &ldquo;97% coverage&rdquo; would be making a claim about the fraction of <em>instructions</em> in a real binary, which depends on which binary, and the number would be true and useless &mdash; it would go up and down with the code rather than with the tool.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
$ python3 x86dec.py --why 8b 44 24 20
$ python3 x86dec.py corpus
</pre>
                </div>
                <p>Then extend it, which is the exercise that turns a reader into a decoder:</p>
                <div class="hex-dump">
                    <pre>  1. Make the decoder handle the 0F 38 and 0F 3A
     maps, and watch it decode a binary built
     with AVX or AVX-512:

       clang -O2 -mavx2 -o avx corpus.c
       python3 x86dec.py avx | tail -3
       objdump -d avx | tail -3

     (The length arithmetic already handles the
     two maps -- they are 3-byte opcodes, and 0F 3A
     takes an imm8 after the operand. What is missing
     is the NAMES and, more importantly, the VEX
     and EVEX PREFIXES, which are 2 and 4 bytes of
     their own and sit where a legacy prefix would.
     Adding them is a good exercise precisely because
     it shows how many places a prefix can appear.)

  2. Write a length-only decoder from scratch --
     no operand text, no names, no tables beyond
     which opcodes take a ModRM. Then run it over
     every binary on the system and report the
     first offset it cannot size.

       ./length.py /usr/bin/* 2>&amp;1 | head

     (Expect it to be short, correct on the
     overwhelming majority, and to fail on AVX-512
     binaries. That failure is the right answer: a
     length decoder that never refuses is a length
     decoder that is guessing, and the refusals are
     the only interesting output.)

  3. Now break the decoder and let the crosscheck
     catch it. Change one table entry, rebuild
     nothing, and watch I9 fail:

       sed -i "s/'f4': ('pmuludq'/'f4': ('hlt'/" x86dec.py
       python3 crosscheck.py 2&gt;&amp;1 | tail -4

     Restore it. Then do the same to a LENGTH RULE
     rather than a table entry -- add 1 to the
     disp32 case -- and watch I7 fail instead,
     with a section name and a first-divergence
     offset. (The two checks catch different classes
     of error: I9 catches a wrong TABLE, I7 catches
     a wrong RULE. A checker suite needs both, and
     the only way to know which of yours covers
     which is to break something on purpose.)

  4. Compare against a third reader, and be careful
     about what a third reader proves. Install or
     locate one -- gdb's disassembler, or a Python
     library -- and run all three over one section.

     (Then ask the question that matters: do the
     three INDEPENDENTLY, or do two of them share an
     implementation? Two tools that both consult the
     same opcode table are one tool with two
     interfaces, and their agreement is worth
     nothing. Check the provenance before you count
     the agreement -- that lesson arrived in this
     course as a real bug, in a reference parser
     that silently dropped the oracle's
     no-mnemonic entries.)

  5. Finally, the exercise that is really the
     course: use the decoder to answer a question
     about a binary you did not build.

       python3 x86dec.py --section .text /bin/ls \
         | tail -20

     Then find the mean instruction length, the
     fraction under 4 bytes, and the most common
     opcode. Now go and read /bin/ls's source. Is
     the code you found the code you expected from
     the source you read?

     (It will not match, and the mismatch is the
     finding. A compiler rearranges, inlines,
     unrolls and vectorises; the source is a
     hypothesis about the bytes and the bytes are
     the evidence. This is the same relationship the
     <a href="/courses/obj/lessons/obj-verify">object
     course's oracle loop</a> established between a
     reader and its input, applied to a reader and a
     program -- and it is the most transferable
     habit in the collection: when a claim about
     code does not match the code, believe the
     code.)
</pre>
                </div>
                <p>Exercise 3 is the one that makes the harness a habit rather than a script you run. <strong>Break the decoder on purpose and confirm the right check fails</strong> &mdash; a table error caught by I9, a length-rule error caught by I7 with a section name and an offset. A checker that has never failed is not known to work, and the two checks catch different classes, so knowing which covers which is the difference between a suite and a decoration. This is the fifth time in this collection that a harness bug masqueraded as a finding, and the fifth time the fix belonged in the harness.</p>
                <p>Exercise 5 is the one that carries the method out of the course, and the mismatch it produces is the point. <strong>Read <code>/bin/ls</code>&rsquo;s source, predict the instruction stream, and then look.</strong> You will find a mean length around 4, you will find <code>call</code> and <code>ret</code> and a handful of arithmetic opcodes dominating, and you will find that the source contains loops the binary has unrolled and functions the binary has inlined. The code is the evidence and the source is a hypothesis, and this collection has argued in one direction only.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the payoff for the chain, and the connection runs the full length of it. <a href="/courses/elf/lessons/program-header-table">The program-header concept</a> taught the segment table. <a href="/courses/elf/lessons/section-header-table">The section-header concept</a> taught the section table and the string-table index. <a href="/courses/elf/lessons/dynamic-section">The dynamic-section concept</a> taught <code>DT_*</code> tags and the rule that the array is 16 bytes per entry. <strong>Every one of those is a source this artifact reads, and it reads them with <code>struct.unpack_from</code> rather than shelling out.</strong> That is the mission stated as a program: a format, parsed by hand, into a working answer, with no dependency on the tool that already understands it.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-emit">the <code>emit</code> concept</a> is the tightest in the collection. That artifact <em>wrote</em> a valid ELF object by hand &mdash; section headers, a symbol table, a string table, relocations &mdash; and this one <em>reads</em> a valid ELF executable by hand. <strong>One course apart, the two ends of the same format, and between them the whole chain: bytes, relocations, linking, loading, hardening, and now the instruction encoding the bytes actually spell.</strong> The chain began with a hex dump and has arrived at a decoder, and the arc is the point.</p>
                <p>Two connections about what a tool cannot see. <a href="/courses/reloc/lessons/reloc-encoding-limits">The encoding-limits course</a> measured that position independence costs twice the fixups and could not say why; <strong>the reason is one ModRM byte, and this decoder can now show you which one in a real binary</strong> &mdash; find a <code>PC32</code> relocation, decode the instruction it points into, and read the <code>disp32</code> at the offset the formula gives you. And <a href="/courses/sec/lessons/sec-cet">the CET concept</a> measured that <code>endbr64</code> is present in binaries that request no enforcement; <strong>this decoder can count them and read their encoding, and it cannot tell you whether the kernel honours them</strong> &mdash; which is exactly the limit the hardening course set, now visible from the other side.</p>
                <p>And the connection forward, which is the next course in the list. <strong>Everything this course decoded is a description, and a description has no timing.</strong> Now that the bytes are legible, the natural next question is what the hardware does with them: how many bytes it fetches at a time, what a branch predictor is predicting, why an instruction boundary is free and a taken branch is not. That is <em>How a CPU Executes Instructions</em>, and it can assume everything in these seven concepts &mdash; which is the only kind of prerequisite worth having, because it means the next course never has to re-derive an encoding.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-length">Previous: The Length Arithmetic</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pic-violation">Back to the chain: The PIC Violation</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
