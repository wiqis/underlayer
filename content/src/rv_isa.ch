// RISC-V: The Encoding Spectrum -- Concept 1: the ISA as a set of documents.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_isa() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Set of Documents, Not a List — Underlayer")
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
            <h1>A Set of Documents, Not a List</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/rvasm">RISC-V: The Encoding Spectrum</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every architecture in this collection has an instruction set, and you have learned two of them as <em>lists</em>: x86-64 has a list, and AArch64 has a list. RISC-V is the odd one out, and the oddness is a design decision with a measurable consequence. <strong>The base is 40 instructions and everything else is a letter.</strong></p>
                <p>That sentence is usually delivered as a slogan about &ldquo;modularity&rdquo; and it is worth exactly nothing until you ask what it does to a compiled object. So this concept asks: compile the same eleven functions of ordinary C at eight different <code>-march</code> settings, and <strong>diff what appears and disappears</strong>. The answer is not &ldquo;M adds multiply&rdquo; and it is not monotonic in &ldquo;more features&rdquo;, and two of the rows are the sharpest things in the course.</p>
                <p>Why it has to come first, before any of the encoding: because a decoder is written against a <em>set</em> of documents, not against an architecture. Every guard in the artifact&rsquo;s dispatch table belongs to one letter. When you write a decoder you are answering &ldquo;does this word belong to the M extension or to the base?&rdquo; and the answer is a value in a funct7 field, which is <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a>&rsquo;s subject. The letters are not a packaging story; they are a dispatch story.</p>
            </div>

            <div class="unit unit-model">
                <h2>Forty, and the string in the object file</h2>
                <p>The base count is <strong>QUOTED</strong>, from the unprivileged manual, section 2.1, and the manual is unusually honest about it:</p>
                <div class="hex-dump">
                <pre>&ldquo;RV32I contains 40 unique instructions, though a simple implementation might
 cover the ecall/ebreak instructions with a single SYSTEM hardware
 instruction that always traps and might be able to implement the fence
 instruction as a nop, reducing base instruction count to 38 total.&rdquo;
                </pre>
                </div>
                <p>Forty. Compare that with the corpus&rsquo;s own opcode space, which <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> counts: ordinary C touches <strong>19 of the 128</strong> possible seven-bit opcodes. The base is small on purpose and the rest of the space is the letters.</p>
                <p>But the interesting string is not the <code>-march</code> you typed. It is the one the <strong>object file</strong> carries, and the object is what a linker reads. <code>Tag_RISCV_arch</code> is read out of <code>.riscv.attributes</code> by this file&rsquo;s own ELF reader, and the rows below are <strong>MEASURED-ON-BYTES</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/-march=rv64imafdc$/,/^$/p'
    rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zmmul1p0_zaamo1p0_
      |  zalrsc1p0_zca1p0_zcd1p0
      names: rv64i m a f d c zicsr zmmul zaamo zalrsc zca zcd
                </pre>
                </div>
                <p><strong>Six letters in, twelve names out.</strong> And the four the user did not type are not toolchain decoration:</p>
                <ul>
                    <li><strong><code>c2p0</code> appears <em>and</em> <code>zca1p0</code> and <code>zcd1p0</code> appear.</strong> The C extension has been split into named sub-extensions, and an object records the ones it actually uses. The reason is not tidiness: <strong>a linker has to know whether the compressed instructions in this object are decodable by the machine it is producing</strong>, and <code>c</code> is not an assumption a linker can make. This is QUOTED from the manual&rsquo;s own history and the string is MEASURED from the file.</li>
                    <li><strong><code>zmmul1p0</code> is the multiply-only subset of M.</strong> A machine with Zmmul satisfies an object that claims it <em>without</em> implementing divide. So <code>m</code> in a <code>-march</code> string is a shorthand the object has to expand, and the expansion is what a linker checks.</li>
                    <li><strong><code>zaamo1p0</code> and <code>zalrsc1p0</code> are the two halves of A</strong>, splittable independently for the same reason: one is the atomic memory operations and the other is load-reserved/store-conditional, and a machine may have either. That is <a href="/courses/rvasm/lessons/rv-encoding">a subject for a later course in this section</a>, but the <em>encoding</em> of the split is a fact about this one and it is in the string above.</li>
                    <li><strong><code>zicsr2p0</code> is the CSR set, and <code>rv64i</code> alone does not name it.</strong> <code>rv64if</code> does. The tool adds <code>zicsr</code> as soon as any floating point is present, which is a <em>toolchain</em> decision and not an architectural requirement &mdash; and it is exactly the kind of thing this string exists to record. The manual&rsquo;s own words, section 2.1: a machine including the privileged architecture &ldquo;will also require the 6 CSR instructions in the Zicsr extension&rdquo;. The base no longer contains them.</li>
                    <li><strong>The vector row names <code>zvl32b</code>, <code>zvl64b</code> and <code>zvl128b</code> &mdash; the vector <em>length</em> bounds, in bytes.</strong> An object built for a 128-bit vector is not runnable on a 64-bit-vector machine without recompiling, and this string is how a linker learns that. There is no equivalent on the integer side, because every RISC-V integer machine is RV32 or RV64 and says so in the base.</li>
                </ul>
                <p>So &ldquo;the ISA is a set of independent documents&rdquo; is not a slogan here. <strong>It is a string in the object file, and the string is longer than the <code>-march</code> that produced it.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>The sweep, and what each letter actually bought</h2>
                <p>The same <code>corpus.c</code> &mdash; arithmetic, masks, conditionals, a loop, a struct walk, a multiply, a divide, a float accumulator, a call &mdash; compiled eight ways. <strong>MEASURED</strong>, and a compiler version is in the numbers, so read the columns and not the third digit:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/-march       insns/,/^$/p'
  -march       insns   bytes    2-byte   B/insn    distinct mnem
  rv64i        146     584      0        4.000     28
  rv64im       114     456      0        4.000     27
  rv64if       146     584      0        4.000     28
  rv64imf      114     456      0        4.000     27
  rv64imafd    95      380      0        4.000     29
  rv64imafdc   95      246      67       2.589     29
  rv64gc       95      246      67       2.589     29
  rv64gcv      178     524      94       2.944     49
                </pre>
                </div>
                <p>The mnemonic <em>count</em> barely moves &mdash; 27 or 28 for every non-vector setting &mdash; and the instruction count falls and rises with the letters in a way that is not monotone in &ldquo;more features&rdquo;. Read the rows as pairs: what did this letter <strong>add</strong>, and what did it make <strong>unnecessary</strong>?</p>
                <h3>One: M is not only additive</h3>
                <div class="hex-dump">
                <pre>    rv64i      -&gt; rv64im      insns  146 -&gt;  114   bytes   584 -&gt;   456
        GAINED  3:  divuw(1)  mul(2)  rem(1)
        LOST    4:  j(1)  jr(1)  sext.w(2)  srli(2)
                </pre>
                </div>
                <p>An extension that adds three instructions and <strong>removes four</strong>. The base has no multiply, so the compiler synthesises one out of shifts and adds, and a shift-based multiply is a <em>sequence</em>, and sequences branch. Adding M removed branches: <code>j</code>, <code>jr</code>, <code>sext.w</code> and <code>srli</code> all disappear, and the instruction count falls by 32.</p>
                <p><strong>&ldquo;An extension adds instructions&rdquo; is true of the ISA and false of the object, and the object is what a linker sees.</strong> This is the first of the three retractions on this page, and it is worth a moment: the same claim in the AArch64 section would have been <em>true</em>, because AArch64&rsquo;s base has <code>mul</code> and its extensions add capabilities the base genuinely lacks. The claim is not architecture-neutral, and a course that states it as if it were would be teaching a fact about one ISA and calling it a principle.</p>
                <h3>Two: F buys this corpus nothing at all</h3>
                <div class="hex-dump">
                <pre>  rv64if       146     584      0        4.000     28
  rv64i        146     584      0        4.000     28
                </pre>
                </div>
                <p>Identical instruction count, identical byte count. The reason is in the corpus: its only floating-point function accumulates a <code>double</code>, and a <code>double</code> needs D. So the F extension buys this corpus <strong>absolutely nothing</strong>.</p>
                <p>This is a correct measurement and it is a <em>warning about the method</em>, which is why the artifact keeps it rather than dropping the row. <strong>An <code>-march</code> sweep over a corpus that does not use a feature reports the feature as worthless.</strong> A sweep is a measurement of <em>a corpus&rsquo;s use of</em> the extensions, and the corpus has to be in hand when you read it. The next row is the one that shows F is not worthless:</p>
                <h3>Three: D replaces calls with stores</h3>
                <div class="hex-dump">
                <pre>    rv64imf    -&gt; rv64imafd   insns  114 -&gt;   95   bytes   456 -&gt;   380
        GAINED  4:  fcvt.l.d(1)  fld(1)  fmadd.d(1)  fmv.d.x(1)
        LOST    2:  jalr(3)  sd(4)
                </pre>
                </div>
                <p>What the compiler was doing before was calling out to a software floating-point library &mdash; each call is a <code>jalr</code> &mdash; and storing double-width intermediates on the stack, which is four <code>sd</code>. With hardware double-precision floating point those become registers. <strong>The instruction count fell by 19 and the byte count by 76, and the letter that did it is one character long.</strong></p>
                <p>And the retraction inside the retraction: the first draft of this paragraph said &ldquo;three <code>auipc</code> disappear&rdquo;. <strong>They do not.</strong> The calls are within the &plusmn;2&nbsp;GiB an <code>auipc</code> can reach, so the address-forming pair survives and only the <code>jalr</code> goes. <a href="/courses/rvasm/lessons/rv-immediate">Concept 4</a> measures that reach.</p>
                <h3>And: the vector extension is not a subset of anything</h3>
                <div class="hex-dump">
                <pre>    rv64gc     -&gt; rv64gcv     insns   95 -&gt;  178   bytes   246 -&gt;   524
        GAINED 20:  and(3)  beq(3)  bgeu(3)  csrr(3)  divu(2)  j(3)  neg(3)
                    srli(6)  vadd.vv(1)  vfmul.vv(1)  vfmv.f.s(1)
                    vfredosum.vs(1)  vl2re64.v(2)  vlseg2e64.v(1)  vmacc.vv(1)
                    vmv.s.x(3)  vmv.v.i(2)  vmv.x.s(2)  vredsum.vs(2)  vsetvli(4)
                </pre>
                </div>
                <p>Twenty mnemonics gained, none of which is an integer instruction, and the instruction count nearly <strong>doubles</strong>. That is not a regression and it is not a measurement of the vector unit&rsquo;s speed &mdash; it is what happens when a compiler auto-vectorises a loop it was previously leaving scalar, and the vector code is longer than the scalar code was. MEASURED while scoping: a plain double loop under <code>-march=rv64gcv</code> came out as seven <code>vadd</code> and one <code>vsetvli</code>, and the scalar form was longer in bytes.</p>
                <p>Which is also the architecture&rsquo;s sharpest idea, and the reason the count goes <em>up</em>: <code>vsetvli</code> programmes the element width, the register-group count and the tail and mask policies at <em>runtime</em>, so one fixed 32-bit encoding describes a vector of a length the instruction does not contain. <a href="/courses/rvasm/lessons/rv-verify">Concept 5</a> is where that encoding is measured.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this measurement cannot show</h2>
                <p>This is a large fraction of what this page is for, so it gets its own section rather than a caveat at the end.</p>
                <ul>
                    <li><strong>None of these numbers is a property of the architecture.</strong> They are properties of <em>one compiler, at one version, on one source file</em>. A different <code>clang</code>, or a different <code>corpus.c</code>, will move every one of them, and the artifact says so in the paragraph under the table. What <em>is</em> a property of the architecture is the last column of the first table: the set of documents each object claims to need.</li>
                    <li><strong>No timings.</strong> There is no RISC-V machine on this host, no emulator, no RISC-V binutils. Not one instruction in this course has been run. The column headed <code>B/insn</code> is <strong>bytes per instruction</strong> and it is a property of the emitted file, not a density in any performance sense. The x86-64 section has speedup ratios; they have <strong>no counterpart here</strong> and are not invented to fill the gap.</li>
                    <li><strong>The empty rows teach nothing.</strong> A setting that produces no <code>mul</code> does not mean the machine cannot multiply; it means this compiler did not need to. A <code>-march</code> sweep measures a corpus&rsquo;s use of an ISA, and an empty column is a fact about the corpus.</li>
                    <li><strong>&ldquo;Distinct mnemonics&rdquo; is a count of names in <em>this</em> disassembly</strong>, and names are a printer&rsquo;s choice. <code>li</code> and <code>addi</code> are the same bits; <a href="/courses/rvasm/lessons/rv-verify">concept 5</a> reconciles the two printers&rsquo; conventions, and the count of mnemonics moves if the printer changes its mind about which alias to print.</li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Reproduce the M-is-not-additive row.</strong> <em>(Build the corpus yourself: <code>cd courses/rvasm/assets/samples &amp;&amp; ./build_samples.sh --only</code>, then <code>clang --target=riscv64-linux-gnu -march=rv64i -S -O2 corpus.c</code> and again with <code>-march=rv64im</code>. Expect the second to be SHORTER, and expect the <code>j</code>/<code>jr</code> to be gone. Then find the shift-and-add sequence the base used &mdash; it is four or five instructions where <code>mul</code> is one.)</em></li>
                    <li><strong>Read the attribute string and account for all twelve names.</strong> <em>(Expect six typed and six inferred, and expect the inferred ones to be the ones that matter to a linker: <code>zca</code>/<code>zcd</code>, <code>zmmul</code>, <code>zaamo</code>/<code>zalrsc</code>, <code>zicsr</code>. Then change one letter and watch which names move &mdash; <code>rv64gc</code> adds <code>zifencei</code> over <code>rv64imafdc</code> and changes nothing else.)</em></li>
                    <li><strong>Find a feature F <em>does</em> buy and give the corpus one.</strong> <em>(Add a <code>float</code> function &mdash; not a <code>double</code> one &mdash; and rebuild at <code>rv64if</code> against <code>rv64i</code>. Expect <code>flw</code>, <code>fsw</code>, <code>fadd.s</code> and a software-conversion call to appear, and expect the D-row&rsquo;s story to repeat at a smaller scale. Then revert, because the corpus is a shared input and the committed numbers were taken with the committed <code>corpus.c</code>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, the <a href="/courses/elf">ELF course</a> taught you to find <code>.text</code>; the <code>Tag_RISCV_arch</code> string on this page is in <code>.riscv.attributes</code>, which is the same container holding a different kind of fact, and finding it is the same exercise with a different name. <a href="/courses/reloc">The reloc course</a> is where the <em>consequences</em> of this page&rsquo;s last section live: an attribute string exists because a linker has to refuse to produce something it cannot run.</p>
                <p>Forwards, <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> takes the letters apart at the bit level &mdash; and finds that M, the extension this page measured as &ldquo;fills a funct7 value the base left empty&rdquo;, is not even <em>in</em> the same opcode space as the instruction that shares its format. <a href="/courses/rvasm/lessons/rv-compressed">Concept 3</a> is about the one extension whose cost is a permanent reservation of encoding space rather than a set of instructions.</p>
            </div>

            <div class="lesson-footer">
                <span>Next: <a href="/courses/rvasm/lessons/rv-encoding">Six Formats and Four Field Positions</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
