// x86-64 Assembly and Encoding — Concept 1: the assembly surface
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_asm() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Reading a Disassembly Without Being Fooled — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>&uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>Reading a Disassembly Without Being Fooled</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every claim in the next four concepts is quoted out of a disassembly, and the single most common way to be wrong about one is to read two of them written in two different syntaxes and assume they are the same instruction. They are not, and the difference is one line of code that no tool will warn you about.</p>
                <div class="hex-dump">
                <pre>$ as -o /dev/null &lt;&lt;'EOF' &amp;&amp; objdump -d -M intel /dev/null
.text
x:  addps %xmm1, %xmm0
EOF

  0:   0f 58 c1    addps xmm0,xmm1
  </pre>
                </div>
                <p>Those are the <strong>same three bytes</strong>. The first line is AT&amp;T syntax, the second is Intel syntax, and between them the operands are <em>reversed</em>. Read the AT&amp;T line as &ldquo;add xmm0 by xmm1, and put the result in xmm0&rdquo; and you have it right. Read the Intel line as &ldquo;add xmm0 by xmm1&rdquo; and you have computed the wrong thing, in a language where <code>addps xmm0, xmm1</code> really does mean <em>xmm0 = xmm0 + xmm1</em>.</p>
                <p>It is worse than a confusion, because the two syntaxes are <strong>both correct</strong> and a document that mixes them is a document that is wrong in a way that disassembles. The trap is not exotic either: a search for &ldquo;x86 lea example&rdquo; returns AT&amp;T lines, a search for &ldquo;x86 movaps example&rdquo; returns Intel lines, and they land in the same editor.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two syntaxes, one rule each, and the two prefixes that are not syntax</h2>
                <p>There is a single rule that generates both syntaxes, and once you have it the two are not two things to remember but one thing seen from two sides.</p>
                <div class="formula">
   AT&amp;T (the assembler's default, and what `as` accepts)
     source first, DESTINATION LAST.   sub %eax, %ebx
     means  ebx = ebx - eax.

   Intel (what objdump -M intel prints, and what most
   documentation uses)
     destination first.               sub ebx, eax
     means  ebx = ebx - eax.

   THE MEMORY OPERAND IS THE EXTRA BIT OF CONFUSION:
     mov 8(%rbx), %eax     AT&amp;T: load from rbx+8 into eax
     mov eax, [rbx+8]      Intel
     [rbx+8] is a MEMORY reference and 8(%rbx) is ALSO a
     memory reference -- neither of them is an immediate.  A
     number with no $ and no brackets, in AT&amp;T, is an
     immediate.  That is the whole of the immediate syntax.
                </div>
                <p>Which one is the default flipped for, and it is a <em>toolchain</em> decision rather than an architectural one, which is the point worth keeping. GNU <code>as</code> is AT&amp;T. GNU <code>objdump</code> is Intel. So the assembler and the disassembler that ship in the same binutils tarball speak <strong>different languages about the same bytes</strong>, and that is why a beginner's first disassembly looks like the assembler has been tampered with. It has not; you are looking at the same three bytes printed by a program that is trying to be helpful to a different audience.</p>
                <p>Two prefixes that get mistaken for syntax, and are not:</p>
                <ul>
                    <li><strong><code>66</code></strong> is an <em>operand-size override</em> and it is not decoration: it is the difference between <code>addps</code> and <code>addpd</code>, between <code>mov ax, al</code> and <code>mov eax, al</code>, and it is <strong>also</strong> a VEX byte's <code>pp</code> field wearing its old costume. The two are the same two bits. <a href="/courses/isa/lessons/isa-rex">The REX concept</a> has the other end of this.</li>
                    <li><strong><code>lock</code></strong> is a prefix that is <em>not</em> a mode, and the assembler refuses it in a way worth reading closely:</li>
                </ul>
                <div class="hex-dump">
                <pre>$ echo '.text
x: lock addq $1, %rax' &gt; /tmp/q.s &amp;&amp; as -o /tmp/q.o /tmp/q.s
/tmp/q.s: Error: expecting lockable instruction after `lock'

$ echo '.text
x: lock addq $1, (%rax)' &gt; /tmp/q.s &amp;&amp; as -o /tmp/q.o /tmp/q.s &amp;&amp; objdump -d /tmp/q.o
   0:	f0 48 83 00 01    lock add QWORD PTR [rax],0x1
  </pre>
                </div>
                <p>The error names the <em>prefix</em> rather than the reason, and the reason is one clause long: <code>LOCK</code> is defined only for a memory destination, because it makes the read-modify-write atomic <em>in memory</em> and a register has no memory to be atomic about. The message costs the reader a trip to the manual. The bytes are in the corpus for exactly this reason &mdash; <code>int_lock_add</code> and <code>int_lock_add_plain</code> are one <code>f0</code> apart and both are in <code>corpus.s</code>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the corpus, and the twenty-six instructions gcc chose for itself</h2>
                <p>The course ships two corpora. One is hand-written: <code>corpus.s</code>, 52 instructions, every one of them chosen because some claim in these pages depends on its encoding. The other is a compiler's: <code>corpus.c</code>, compiled at <code>-O2</code> and disassembled by the build script. <strong>A claim about what a compiler did is a claim about bytes</strong>, and the only way to check one is to read them.</p>
                <div class="hex-dump">
                <pre>$ sed -n '5,20p' corpus_c.txt
shift_left       | 48 89 fa 8b f0 89 d6  | mov    rdx,rdi
                 | c1 e2 08             | shl    edx,0x8
                 | 39 f7                | cmp    esi,edi
shift_by_one     | 48 d1 e2             | shl    rdx,1
pick             | 4c 0f 4c e1 0f      | cmovl  r12,r13
bump             | 0f b6 00 48 0f be 00 | movzx  rax,BYTE PTR [rax]
                 | 48 83 c0 01          | add    rax,0x1
                 | 88 00                | mov    BYTE PTR [rax],al
  </pre>
                </div>
                <p>Four things in eight lines that a reader of the C would not have predicted, and every one of them is a fact about the encoding rather than about the algorithm:</p>
                <ul>
                    <li><strong><code>a &lt;&lt; b</code> became <code>shl edx, 0x8</code> &mdash; a count in the instruction.</strong> The variable form <code>shl %cl, %rdx</code> is one byte longer and needs a register to be free, so the compiler used the immediate where the count was a constant. The next concept measures both and finds the immediate form is not the cheap one, which is a fact about <em>this</em> processor and about nothing in the manual.</li>
                    <li><strong><code>a &lt;&lt; 1</code> became <code>shl rdx, 1</code> and <code>48 d1 e2</code> became <code>shl rdx,1</code>.</strong> The <code>d1</code> form encodes &ldquo;shift by one&rdquo; in the opcode byte with no immediate at all &mdash; a third encoding of the same operation, and the reason the opcode space has a hole where <code>d0</code>&ndash;<code>d3</code> are.</li>
                    <li><strong><code>x &lt; y ? p : q</code> became <code>cmovl</code>.</strong> Not a branch. The next-next concept measures that choice and finds that on this machine, in a loop the predictor can learn, the branch was the <em>cheaper</em> of the two &mdash; and explains why that is not a contradiction.</li>
                    <li><strong><code>p[0] = p[0] + 1</code> on a <code>char *</code> became <code>movzx rax, BYTE PTR [rax]</code> &hellip; <code>mov BYTE PTR [rax], al</code>.</strong> A <strong>64-bit</strong> load of an 8-bit quantity, because the C promotion is to <code>int</code> and <code>int</code> is 32 bits and the compiler chose to carry it in a 64-bit register. Every extension in that sequence is a decision, and the next concept is the reference for what each of them costs and what each of them means when you get the width wrong.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Worked: reading one instruction all the way down</h2>
                <p>Take the row that appears in every disassembly of every compiled program ever written, and read it byte by byte. This is <code>sub %ebx, %eax</code>, which the artifact's corpus records as <code>int_sub</code> with the bytes <strong><code>29 d8</code></strong>.</p>
                <div class="hex-dump">
                <pre>  29        the opcode.  It is in the ONE-BYTE map, and
            0x28-0x2d are the SUB group: 28 = r/m8,r8
            29 = r/m32,r32   2a = r8,r/m8   2b = r8,r/m32
            2c = AL,imm8     2d = eAX,imm32
            The suffix IN THE MNEMONIC is the low three bits.
            A mnemonic that says `subl` is telling you the
            encoding, not the language.

  d8        the ModRM byte, and the course that has the whole
            layout of this byte is at isa-modrm, so this is
            one line of it:
              d8 = 11 011 000
                   |  |  `-- rm  = 000 = EAX
                   |  `----- reg = 011 = EBX
                   `-------- mod = 11 = REGISTER, so there is
                               no SIB byte and no displacement

  TWO BYTES TOTAL, and the length is not stored anywhere.
  A decoder knows it is two bytes because it has read the
  opcode and the ModRM and mod says register.  That is the
  whole of the length arithmetic, and the neutral course
  derives it; this is what it looks like applied.
                </pre>
                </div>
                <p>Now the same instruction with a memory operand, from the same corpus: <code>int_lea_mem</code> is <strong><code>48 8d 44 f7 08</code></strong>, and every byte is doing work.</p>
                <div class="hex-dump">
                <pre>  48        REX.W.  One byte that says four things at
            once: W (64-bit operands), R (extension for the
            reg field), X and B (for the SIB).  Without it
            the instruction is 32-bit and the address
            computation is 32-bit.  isa-rex has the rest.

  8d        LEA.  Note that the opcode for LEA is 0x8d,
            not 0x8b: MOV to a register and LEA into a
            register are DIFFERENT OPCODES, and the
            difference is the entire subject of the next
            concept.

  44        ModRM = 01 000 100
               mod = 01  -> a ONE-BYTE displacement follows
               reg = 000 -> rax is the destination
               rm  = 100 -> a SIB byte follows

  f7        SIB = 11 111 111
               scale = 11 -> x8
               index = 111 -> NONE.  An index of 111 means
                               no index register at all
               base  = 111 -> rdi

  08        the one-byte displacement, +8

  FIVE BYTES to compute rdi + rsi*8 + 8 and put it in rax,
  touching no memory.  Compare `mov 8(%rdi,%rsi,8), %rax`,
  which is six bytes and DOES touch memory.  The next concept
  measures the difference between those two and finds it is
  not the five-versus-six you would guess.
                </pre>
                </div>
                <p>One trap in that, and it is the one that costs a day. <strong>You cannot write a scale of 3.</strong> The scale field is two bits and it encodes 1, 2, 4 and 8, and <code>as</code> says so out loud rather than silently computing something else:</p>
                <div class="hex-dump">
                <pre>$ cat _probe.s
.text
probe:  lea 0(%rdi,%rsi,3), %rax
$ as -o _probe.o _probe.s
_probe.s:2: Error: expecting scale factor of 1, 2, 4, or 8: got `3'
  </pre>
                </div>
                <p>So <code>lea 0(rdi,rsi,3)</code> is the <em>same shape</em> as <code>lea 0(rdi,rsi,4)</code> &mdash; a base, an index, a scale, a displacement, a destination &mdash; and there is a value of the scale for which that shape has <strong>no encoding at all</strong>. A &times;3 address is a LEA, a shift and an add, and the assembler makes you write all three. That is the whole ModRM-and-SIB story in one diagnostic, and the neutral course has the byte layout if you want it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Disassemble one function twice, in both syntaxes, and diff the bytes.</strong> <code>objdump -d f.o</code> and <code>objdump -d -M intel f.o | sed 's/\t/ /g'</code> &mdash; or more simply, write the same six instructions in both syntaxes, assemble each, and compare the hex. <em>(Expect the bytes to be identical and the operand order to be reversed. If your assembler is LLVM rather than GNU, `.intel_syntax noprefix` switches it and the exercise becomes the same experiment with a different toolchain &mdash; which is the point: the choice of default is a toolchain decision, not an architectural one, and knowing which one you are looking at is the skill.)</em></li>
                    <li><strong>Find the SIB scale 3.</strong> Take a real loop and replace <code>a[i]</code> with <code>a[3*i]</code> and watch the compiler emit three instructions instead of one. <em>(Expect the array-index form to become a LEA with a scale, a multiply or a shift-and-add, and a register to be spilled if the loop was register-tight. The interesting number is not the speed; it is that the <em>source</em> looks identical in shape and differs in encoding, which is the property the whole architecture is built on.)</em></li>
                    <li><strong>Count the extensions in a compiled <code>char</code> loop.</strong> <code>unsigned char c = p[i]; use(c);</code> at <code>-O2</code>, then read the disassembly. <em>(Expect a <code>movzx</code> and then nothing, because the zero extension IS the value. Then write <code>char c = p[i]</code> and expect a <code>movsx</code> instead &mdash; and then ask what happens to the upper 32 bits when the compiler uses a 32-bit register, which is the trap the next concept opens with.)</em></li>
                    <li><strong>Break the assembler's error message on purpose.</strong> Try <code>lock</code> on a register destination, <code>mov %eax, (%rbx,%rsi,3)</code>, <code>mov</code> with four operands, and a <code>66</code> prefix on an instruction that has no 16-bit form. <em>(Expect four different messages and three of them to be about something other than what you got wrong. Record each one and what the real reason was: this course's whole argument is that a plausible message is worse than a crash, and a collection of eight real assembler messages is the cheapest possible way to believe it.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/isa/lessons/isa-length">The ISA course's length concept</a> is where the rule this page applied twice is derived rather than illustrated, and <a href="/courses/isa/lessons/isa-decode">its decoder</a> is the thing this course's last concept deliberately tries to break. <a href="/courses/isa/lessons/isa-rex">isa-rex</a> has the four bits in <code>48</code> and <a href="/courses/isa/lessons/isa-sib">isa-sib</a> has the three in <code>f7</code>; both are linked rather than repeated, because repeating them is exactly the duplication <code>docs/x86-64-section-plan.md</code> exists to prevent. <a href="/courses/isa/lessons/isa-modes">isa-modes</a> is where the 64-bit mode you have been assuming comes from.</p>
                <p>Forwards, this page read three instructions out of a compiled C file and said that each of them encodes a decision. <a href="/courses/x86asm/lessons/x86-integers">The integer set concept</a> is the reference for what those decisions are: what every one of the instructions in that disassembly writes, what it costs, and the three places where the register name in the source decides the <em>answer</em> rather than the speed. <a href="/courses/x86asm/lessons/x86-vex">The prefix encodings</a> takes the <code>66</code> in <code>addpd</code> and shows that its two bits are the VEX <code>pp</code> field wearing a different hat.</p>
                <p>Outward, the neighbouring courses that this one leans on rather than repeats. <a href="/courses/simd/lessons/simd-width">The vector course</a> measured what happens when the width in <code>movzx</code> is wrong, at a width of 128 bits, and found that an unaligned load is free on this machine &mdash; which is <em>not</em> re-measured here and <em>not</em> restated as this course's number. <a href="/courses/exe/lessons/exe-frontend">The execution course's frontend</a> is where the "one instruction is a decode slot" claim in the next concept comes from, and where the reason the three-operand encoding buys nothing measurable is properly explained.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></span>
                <span>Next: <a href="/courses/x86asm/lessons/x86-integers">The Integer Set, Which Nothing Teaches</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
