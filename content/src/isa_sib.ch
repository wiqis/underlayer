// The Instruction Set Architecture — Module 3: Addressing
// Concept: scale, index and base; the two field values with special meanings;
// and a byte order nobody guesses.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_sib() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("SIB: The Byte That Exists Because rsp Is Special — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-lesson">
            <a href="/courses/isa" class="back-link">Back to course</a>
            <h1>SIB: The Byte That Exists Because rsp Is Special</h1>
            <div class="lesson-meta">23 min &middot; Module 3: Addressing &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The addressing forms <a href="/courses/isa/lessons/isa-modrm">ModRM gives you</a> are <code>[reg]</code>, <code>[reg+disp]</code> and <code>[rip+disp]</code>. Three forms. But the language you are compiling has arrays, and an array element is <code>base + index*scale</code>. <strong>Three forms is not enough to express <code>arr[i]</code>.</strong></p>
                <p>So x86 spends a second byte on the problem, and that byte is the SIB &mdash; Scale, Index, Base. Eight bits:</p>
                <div class="formula">
  SIB  =  s s i i i b b b
         | | | | | +-----+  base   (3 bits)
         | | | +-------+  index  (3 bits)
         +---------+  scale   (2 bits)

  scale   00=1  01=2  10=4  11=8     a SHIFT, not a value
  index   a register, or "none"      see below
  base    a register, or "none"      see below

  the address is  base + index*scale + displacement
                </div>
                <p>And it earns its existence in one instruction, which is the most-used addressing form in compiled code on this platform:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I4/,/I5/p'
     8 bits: ss(2) index(3) base(3). Two field values are special:
   8b 04 24    index=100 base=rsp  8b 04 24 mov eax,DWORD PTR [rsp]
   8b 04 2c    index=101 = rbp     8b 04 2c mov eax,DWORD PTR [rsp+rbp*1]
   8b 04 25 11223344  base=101 mod=00  8b 04 25 11 22 33 44 mov eax,DWORD PTR ds:0x44332211
   8b 44 25 11 base=101 mod=01     8b 44 25 11 mov eax,DWORD PTR [rbp+riz*1+0x11]
</pre>
                </div>
                <p><code>8B 04 24</code> is <code>mov eax, [rsp]</code>. Read it: opcode <code>8B</code>, ModRM <code>04</code> &mdash; <code>rm=100</code>, so a SIB follows &mdash; and SIB <code>24</code> = <code>00 100 100</code>, which is <strong>scale 1, index &ldquo;none&rdquo;, base rsp</strong>. Three bytes to say &ldquo;the stack pointer, with nothing added&rdquo;.</p>
                <p>And that last part is the whole reason the byte exists in that form. <strong>Base = <code>rsp</code> is the single most important addressing mode in x86-64</strong>, because <code>rsp</code> is where every local variable, every spilled register and every return address lives. A form that could say &ldquo;rsp plus a scaled index&rdquo; in one byte is worth a byte of encoding.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model, and Two Retractions</h2>
                <p>Two of the field values are special, and <strong>both of my recollections about them were wrong until they were measured</strong>. The corrections are the most useful part of this concept.</p>
                <div class="formula">
  index = 100   (0b100)   NO INDEX, when REX.X = 0
  index = 101   (0b101)   rbp        -- an ordinary register

  base  = 101   (0b101)   NO BASE, but ONLY at mod = 00,
                          where the disp32 becomes an
                          ABSOLUTE address. at mod = 01
                          or 10 it is simply rbp.

  the asymmetry is not a typo. it is what makes
  an absolute address expressible at all: an
  address with no base register can only be
  written as a displacement from nothing, and
  the only "nothing" available is zero -- which
  is what the compiler uses for a genuine
  absolute address, and what a linker refuses to
  produce in a PIE.
                </div>
                <p>So here is the first correction, and it is the one people get wrong most often: <strong><code>index=100</code> means &ldquo;no index&rdquo;, and <code>index=101</code> is rbp</strong> &mdash; the other way round from what most people remember. The consequence is a famous encoding gap:</p>
                <div class="formula">
  you cannot encode  [rbp + rsi*1]  without
  also adding a displacement.

      [rsp + rsi*1]   index=110  base=100   fine
      [rbp + rsi*1]   index=110  base=101   fine
      [rbp + rsi*1] with NO disp    IMPOSSIBLE

  why: rbp is index=101, and index=101 is rbp,
  so to use rbp as a BASE with no displacement
  you would need base=101 at mod=00, and that
  means "no base, absolute address". the
  encoding has no way to say "rbp" there.

  the 32-bit encoding did not have this problem,
  because rm=101 at mod=00 was not taken -- it
  became RIP-relative, and 64-bit mode inherited
  the restriction.
                </div>
                <p>Which is a real cost, paid by every compiler that generates a frame pointer. <strong>Any function with a frame pointer must emit a zero displacement to use <code>rbp</code> as a base at <code>mod=00</code></strong> &mdash; one wasted byte, in exchange for the <code>rm=100</code> escape that buys scaled indexing everywhere else. <a href="/courses/reloc/lessons/pic-violation">The PIC-violation concept</a> measured a related squeeze in the same register file; this is the encoding-level reason <code>rbp</code> is awkward.</p>
                <p>The second correction is about something simpler and it cost a rebuild cycle to find, because it is not a special value at all &mdash; it is an <strong>ordering</strong>:</p>
                <div class="hex-dump">
                    <pre>   and the BYTE ORDER, which is not the order you would guess:
   8b 84 24 11 22 33 44  SIB then disp  8b 84 24 11 22 33 44 mov eax,DWORD PTR [rsp+0x44332211]
   8b 84 11 22 33 44 24  disp then SIB  8b 84 11 22 33 44 24 mov eax,DWORD PTR [rcx+rdx*1+0x24443322]
     both are valid instructions, and they are DIFFERENT. The SIB comes
     immediately after the ModRM, BEFORE the displacement.
</pre>
                </div>
                <p><strong>ModRM, then SIB, then displacement, then immediate.</strong> Both byte strings above are valid and they are different instructions: the first is <code>[rsp + 0x44332211]</code> and the second is <code>[rcx + rdx*1 + 0x24443322]</code>. The second looks like the obvious order &mdash; address first, then the extra byte &mdash; and it is wrong.</p>
                <p>The reason is structural rather than aesthetic. <strong>The ModRM must be able to say &ldquo;there is more to this address&rdquo; without knowing what the more is</strong>, so it signals the SIB with <code>rm=100</code> before either appears. The SIB in turn may reveal that the displacement is four bytes rather than one, and by then both bytes are already placed. The order is forced by the dependency, and the dependency is the reason the byte exists.</p>
            </div>

            <div class="unit unit-reality">
                <h2>All 256 Bytes, and What They Say</h2>
                <p>Every SIB byte, decomposed, with the scale field measured separately:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/scale field/,/I5/p'
   ss=0                            8b 44 05 11 mov eax,DWORD PTR [rbp+rax*1+0x11]
   ss=1                            8b 44 45 11 mov eax,DWORD PTR [rbp+rax*2+0x11]
   ss=2                            8b 44 85 11 mov eax,DWORD PTR [rbp+rax*4+0x11]
   ss=3                            8b 44 c5 11 mov eax,DWORD PTR [rbp+rax*8+0x11]
</pre>
                </div>
                <p>Scale is a two-bit <strong>shift</strong>, not a two-bit number &mdash; <code>00</code> maps to 1, not 0, because an address scaled by zero is not a thing anyone wants to write. <code>ss=0,1,2,3</code> gives <code>&times;1, &times;2, &times;4, &times;8</code>, all four measured.</p>
                <p>And the &ldquo;no index&rdquo; case shows up in the oracle&rsquo;s output as a register literally named <code>riz</code> &mdash; the &ldquo;zero index register&rdquo;, a pseudo-register with the value zero. It is not a real register; it is how a disassembler prints an absent field:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/index=100/p'
   8b 04 24    index=100 base=rsp  8b 04 24 mov eax,DWORD PTR [rsp]
   8b 44 25 11 base=101 mod=01     8b 44 25 11 mov eax,DWORD PTR [rbp+riz*1+0x11]
</pre>
                </div>
                <p>Read those two together. <code>8B 04 24</code> prints a bare <code>[rsp]</code> with no index at all, while <code>8B 44 25 11</code> prints <code>[rbp+riz*1+0x11]</code> with a visible zero index. Same field value, different presentation &mdash; because in the first the index field is <code>100</code> and in the second the ModRM is <code>44</code>, so <code>rm=100</code> and the SIB is <code>25</code> = <code>00 100 101</code>, index none, base 101 which at <code>mod=01</code> is rbp with a <code>disp8</code>. <strong>The <code>riz</code> appears because the SIB byte exists at all, and the printer does not special-case the &ldquo;none&rdquo; value when it is already committed to printing a SIB-shaped operand.</strong></p>
                <p>Now the part with a real consequence for a linker. <strong>When the base is <code>101</code> and <code>mod=00</code>, the displacement is four bytes and it is an absolute address</strong>:</p>
                <div class="hex-dump">
                    <pre>$ python3 x86dec.py --why 8b 04 25 11 22 33 44
    offset 0, 7 bytes: 8b 04 25 11 22 33 44
      mov      eax,DWORD PTR [0x44332211]
      . byte 8b at 0 is a one-byte opcode
      . byte 04 at 1 is the ModRM byte: mod=0 reg=0 rm=4
      .   mod=00: no displacement, except rm=101 which is
      .   RIP-relative and carries a 4-byte displacement
      .   rm=100 means a SIB byte follows: 25 at 2
      .     ss=0 -&gt; scale 1,  index=4,  base=5
      .     index=100 with REX.X=0 means NO INDEX
      .     base=101 with mod=00 means NO BASE: the
      .     displacement is a 4-byte absolute address
      .   4 bytes displacement at 3, value 0x44332211 (1144219153)
      .   read little-endian, so the LOW byte is at the LOW
      .   address -- 11 22 33 44 means 0x44332211
</pre>
                </div>
                <p>That is a <strong>two-level dependency</strong>, and it is the subtlest thing in the addressing encoding. The ModRM said &ldquo;mod 00, rm 100, so there is more.&rdquo; The SIB said &ldquo;base 101.&rdquo; And <em>only then</em> could the decoder conclude that a four-byte displacement follows, when the ModRM&rsquo;s <code>mod=00</code> had implied none. <strong>A decoder that computed the length from the ModRM alone gets this case wrong by four bytes</strong> &mdash; and a decoder that gets it wrong does not report an error, it reports everything after this instruction as nonsense.</p>
                <p>Which is why the crosscheck audits every entry of the opcode table rather than testing examples. The table audit found this class of bug in a different place &mdash; <a href="/courses/isa/lessons/isa-length">the length concept</a> has the full accounting &mdash; and it is the argument for checking a rule across its whole input space instead of at the cases you thought of.</p>
            </div>

            <div class="unit unit-example">
                <h2>Why One Byte Was Worth It</h2>
                <p>Step back and ask whether the SIB is a good design, because the answer explains why x86 looks the way it does everywhere else.</p>
                <p><strong>Compare the two encodings of the same operation.</strong> Without a SIB, an array access <code>arr[i]</code> with a scaled index needs a scratch register or a self-modifying sequence. With it, one byte:</p>
                <div class="formula">
  arr[i]  where arr is in rbx and i in rax:

    8B 04 98      mov eax, [rax*4 + rbx]

  one opcode, one ModRM, one SIB. no scratch
  register, no second instruction.

  the same access WITHOUT a SIB, which is what
  a 32-bit-mode-only design gives you:

    89 C1         mov ecx, eax      ; copy the index
    C1 E1 02      shl ecx, 2        ; scale it
    01 D9         add ecx, ebx      ; add the base
    8B 01         mov eax, [ecx]    ; load

  four instructions and a destroyed register.
  the SIB costs 1 byte and saves about 12.
                </div>
                <p>That is the trade, and it is the trade the whole ISA is built on: <strong>one byte of encoding to avoid a sequence of instructions.</strong> It is also why the register-save cost of the feature is zero &mdash; the scratch-register version has to preserve <code>ecx</code>, the SIB version preserves everything because it reads no register it writes.</p>
                <p>Now the interesting counter-argument, because a good course should give the design its weakness as well as its strength. <strong>Scale is limited to 1, 2, 4 and 8, and the index is limited to eight registers before REX.</strong> So:</p>
                <div class="formula">
  arr[i*3]        needs a scratch register.
                  no SIB byte can say *3.

  arr[i*16]       scale 8, then a shift.
                  or two scratch registers.
                  or a different loop shape.

  a[i][j][k]      three levels of scaling.
                  a SIB byte holds ONE index and
                  ONE scale, so a 3-D array walk
                  still needs arithmetic -- the
                  hardware helps with the innermost
                  index and no further.
                </div>
                <p>So the SIB solves one problem completely and adjacent problems partially, and the partial solutions are exactly where compilers still emit arithmetic. <strong>&ldquo;base + index*scale&rdquo; is not a general array-addressing unit; it is the innermost loop of one.</strong> Knowing the boundary is more useful than having the feature, and it is the same shape as the limits <a href="/courses/reloc/lessons/reloc-encoding-limits">the encoding-limits course</a> found for position independence: enough expressiveness to compile most code directly, and a long tail that needs instructions around it.</p>
                <p>One more measured detail, because it is a trap in reading a disassembly. <strong>The decoder prints <code>[rsp+32]</code> where the oracle prints <code>[rsp+0x20]</code></strong> &mdash; same address, different notation &mdash; because the decoder prints displacements in decimal and the oracle in hex with a <code>0x</code> prefix. <a href="/courses/img/lessons/img-auxv">The image course</a> hit the same class of problem with <code>%018lx</code> printing a zero with no prefix, and the answer was the same: <strong>a number that is missing its prefix is a number you will misread in a log</strong>. Notation is not cosmetic when you are comparing two tools&rsquo; output by eye.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I4/,/I5/p'
$ python3 x86dec.py --why 8b 04 25 11 22 33 44
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I4/,/^I5/p'
</pre>
                </div>
                <p>Then write the field decoder and check it across the whole space:</p>
                <div class="hex-dump">
                    <pre>  1. Write a SIB decomposer and run it over all
     256 values, printing scale, index and base:

       for sib in range(256):
           ss, ix, bs = sib &gt;&gt; 6, (sib &gt;&gt; 3) &amp; 7, sib &amp; 7
           print(sib, 1 &lt;&lt; ss, ix, bs)

     Now annotate each of the 256 with what it
     actually means, treating index=100 and
     base=101 as special. How many distinct
     address FORMS are there in total?

     (Fewer than 256, because ss is a scale not an
     address component: 4 scales x 8 indices x
     8 bases, minus the two special values, plus
     the two "no base" cases. Count them -- the
     answer is around 240, which is the point:
     the byte is nearly injective and was designed
     to be.)

  2. Find the rbp gap empirically. Try to encode
     [rbp+rsi*1] with no displacement and show
     that you cannot:

       # mod=00 rm=101 is RIP-relative, not rbp
       # mod=00 rm=100 + SIB base=101 is absolute
       # so rbp at mod=00 with no disp is unreachable

     Then write the smallest thing that IS
     reachable and check it:

       8b 44 25 00   mov eax,[rbp+riz*1+0x0]

     (One wasted byte. Then compile a function
     with a frame pointer and count the zero
     displacements clang emits -- that is the
     price, measured on real code rather than
     argued from the spec.)

  3. Now the dependency. Write a length function
     that uses ONLY the ModRM, and run it over
     every SIB byte at mod=00. Count the failures:

       for sib in range(256):
         bs = bytes([0x8b, 0x04, sib]) + disp4
         ...

     (32 failures: every SIB with base=101. The
     ModRM said mod=00 so no displacement, and the
     SIB said otherwise. A decoder must read both
     before it can size the instruction, and there
     is no shortcut.)

  4. Test the scale field against reality. Compile
     the same loop four ways and find the SIB byte
     in each:

       for s in 1 2 4 8; do
         printf 'int f(char*a,long i){return a[i*%d];}\n' $s
       done

     (Expect *1, *2 and *4 to use the SIB scale
     field directly, and *8 to need a shift or an
     lea. The scale field tops out at 8, and finding
     where the hardware stops helping is more
     informative than confirming where it starts.)

  5. Finally, the experiment that makes the SIB
     legible: count SIB bytes in real code and
     correlate with what the source was doing.

       objdump -d /bin/ls | grep -c 'rsp\*'
       objdump -d /bin/ls | grep -oE '\((%r[a-z0-9]+),%r[a-z0-9]+(,[124])?\)' \
         | sort | uniq -c | sort -rn | head -20

     The top patterns will be dominated by [rsp]
     and [rsp+N] with scale 1 -- which is stack
     traffic, and stack traffic is [rsp] because
     rsp IS the stack. Then look for the rare
     scaled forms and read the surrounding code:
     they are array indexing, and they are rarer
     than you would expect from reading C, which
     is itself the finding from step 4 -- most
     array access in compiled code is a pointer
     that was already advanced, not an index that
     is being scaled.
</pre>
                </div>
                <p>Exercise 5 is the one with the most surprising answer, and it is worth doing slowly. <strong>Scaled-index addressing is rare in real compiled code</strong> &mdash; the dominant SIB patterns are <code>[rsp]</code> and <code>[rsp+N]</code>, which is stack traffic, and <code>riz</code>-free base-only forms. The reason is that C array decay means a compiler advances a <em>pointer</em> rather than scaling an <em>index</em>: <code>p++</code> is an add, and the SIB is reserved for the cases where a multiply genuinely happens. The hardware feature was designed for array indexing and is mostly used for stack frames, which is a good reminder that <strong>what an encoding supports and what a compiler uses it for are different questions.</strong></p>
                <p>Exercise 2 is the one that pays off in the hardening and relocations courses. <strong>The <code>rbp</code> gap is a measured encoding cost, visible in every frame-pointer function as a wasted displacement byte</strong> &mdash; and it exists because <code>rm=101</code> was taken by RIP-relative addressing before anyone needed <code>rbp</code> as a displacement-free base. That is a historical accident frozen into the encoding, and it is the same category of finding as the mode collisions: <em>a slot that got used, and could not be given back</em>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/reloc/lessons/reloc-why-so-many">the relocations course</a> is where this concept&rsquo;s arithmetic turns into a number, and it is the most direct technical debt in the course. That course measured that position independence costs <strong>twice the fixups</strong> and explained it as &ldquo;a PIC access needs a PC32 against a symbol, and a data access needs an absolute 32-bit, so two relocations where non-PIC needs one.&rdquo; <strong>That is the <code>mod=00 rm=101</code> form</strong> &mdash; the one this concept measured as &ldquo;RIP-relative, always a 4-byte displacement&rdquo; &mdash; and the reason a PIE has more relocations than a non-PIE is one bit in one ModRM byte. The chain had that number for two courses and no mechanism; this is the mechanism.</p>
                <p>The connection to <a href="/courses/img/lessons/img-stack">the stack concept in the image course</a> is that <a href="/courses/isa/lessons/isa-modrm">the ModRM concept</a> already flagged the dominant use. That course measured a real frame: the stack grows down, <code>rsp</code> is the low end, and every local is at <code>[rsp+N]</code> with a compile-time-constant <code>N</code>. <strong>So &ldquo;scale 1, index none, base rsp&rdquo; &mdash; a three-byte instruction &mdash; is the machine code for a local variable, and the <code>N</code> is the offset the frame concept measured.</strong> The image course showed you the frame; this course shows you its encoding, and the two are the same bytes.</p>
                <p>Two connections outward, both about the dependency chain rather than the field layout. <a href="/courses/obj/lessons/obj-pic">The PIC concept</a> in the object course needed the GOT and could not say how a compiler reaches it; <strong>RIP-relative addressing is how, and it is this concept&rsquo;s <code>mod=00 rm=101</code> case plus <a href="/courses/isa/lessons/isa-rex">a REX byte</a>.</strong> And <a href="/courses/sec/lessons/sec-relro">The RELRO concept</a> in the hardening course measured that <code>.got.plt</code> has a tail that crosses the end of the sealed range; <strong>the GOT slots are addressed with base-relative forms whose displacement width is exactly what the ModRM concept&rsquo;s table says</strong>, so a linker that needs to know whether a GOT reference is 3 or 6 bytes is asking the question this concept answers.</p>
                <p>One limit, and it is stated because it is the kind of thing that gets quietly assumed. <strong>The <code>index=100</code> rule is conditional on <code>REX.X</code>, and this course&rsquo;s own oracle gets that conditional wrong</strong> &mdash; it ignores <code>REX.X</code> on the SIB index entirely, printing <code>[rsp]</code> where the field layout says <code>[rsp+r12*1]</code>. The decoder applies it and the oracle does not, and the crosscheck compares only instruction boundaries so the two are never asked the question they disagree about. A reader who takes &ldquo;index 100 means no index&rdquo; as unconditional will get a confident wrong answer on exactly one input, which is the worst possible shape for a rule: almost always right, silently wrong once, and the once is the case that matters.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-modrm">Previous: ModRM: The Two Fields That Decide the Length</a></span>
                <span>Next: <a href="/courses/isa/lessons/isa-length">The Length Arithmetic</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
