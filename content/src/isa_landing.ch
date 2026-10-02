// The Instruction Set Architecture — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_isa_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Instruction Set Architecture — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson isa-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The Instruction Set Architecture</h1>
            <div class="lesson-meta">7 concepts &middot; 4 modules &middot; 167 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Every course before this one used x86-64 machine code as an opaque byte string that relocations patch. <a href="/courses/obj/lessons/obj-arch-table">The architecture-table concept</a> asked a linker two questions and refused to answer either:</p>
                <div class="formula">
  Q1a. how many bytes is the instruction?
  Q1b. at what offset within it does the field start?

  "converting [a byte offset] to a field requires
   decoding the instruction"

  that was correct, and it was also a real gap.
  six concepts of the chain relied on that answer
  and none of them could give it. this course is
  the answer.
                </div>
                <p>And the first measurement is the reason the course exists, because it is not a subtlety. <strong>Three bytes, two correct readings:</strong></p>
                <div class="hex-dump">
                    <pre>$ cd courses/isa/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
     the same three bytes, decoded in each mode:
   40 89 e8  (64-bit)              40 89 e8               rex mov eax,ebp
   40 89 e8  (32-bit)              40                     inc    eax | 89 e8                  mov    eax,ebp
</pre>
                </div>
                <p><strong>One instruction of three bytes, or two instructions of one and two.</strong> <code>0x40</code>&ndash;<code>0x4F</code> is <code>INC</code>/<code>DEC</code> in 32-bit mode and a REX prefix in 64-bit. So the byte stream does not determine the instruction &mdash; the <em>mode</em> does &mdash; which is the same fact as an ELF <code>e_machine</code> field, one level down, demonstrated with three bytes rather than argued from a header. There is a second collision of the same shape at <code>0x62</code>, which is the AVX-512 EVEX prefix in 64-bit mode and <code>BOUND</code> in 32-bit.</p>
                <p>Seven concepts in four modules:</p>
                <div class="formula">
  MODULE 1  What the Bytes Are
            the mode collision, and why an opcode
            slot outlives the instruction in it
            the map: 228 instructions, 27 prefixes,
            and UD2, which exists to fail on purpose

  MODULE 2  The Prefix Layers
            REX: four bits that ADD 8, must be last,
            and only the last one counts
            ModRM: all 256 values, and the two
            fields that decide the length

  MODULE 3  Addressing
            SIB: scale, index, base, two special
            field values, and a byte order that is
            not the one you would guess
            the length formula, and the chain
            property that makes a check strong

  MODULE 4  Decode It Yourself
            a decoder that shows its work, and the
            table audit that finds what examples
            miss
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Three findings that carry the course</h2>
                <p>Toolchain and limits, up front: <strong>clang 21.1.8, GNU objdump 2.46, x86-64 Linux.</strong> One architecture, one reader, and that reader is the oracle rather than a specification &mdash; so where it and this course disagree, the disagreement is recorded in <code>research.md</code> rather than resolved by assertion. <strong>No AArch64 machine or linker was available, so nothing here is claimed about a second architecture.</strong></p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I3/,/I4/p'
   all 256 ModRM bytes for opcode 8b /r (MOV r32, r/m32):
   bytes that did NOT decode as exactly one instruction: 0 []
   mod=11 (register) forms:  64 of 256
   mod!=11 (memory) forms:   192 of 256
</pre>
                </div>
                <p><strong>All 256 ModRM values decode as exactly one instruction</strong>, and <code>mod=11</code> is exactly 64 of them &mdash; a clean quarter, the register forms. That exhaustiveness is not a formality: it is what makes the encoding a thirty-year success, and it is why <code>mod</code> and <code>rm</code> alone can answer Q1a.</p>
                <p>The second finding is the correction. <strong><code>mod=00</code> means no displacement except at <code>rm=101</code>, which is RIP-relative and always carries a 4-byte one</strong> &mdash; and that one form is why a position-independent binary has twice the relocations of a non-PIE. The relocations course measured that number two courses ago and could not say why. One bit in one ModRM byte is the reason.</p>
                <p>The third is the one that cost the most to get right. <strong>The SIB byte comes immediately after the ModRM and before the displacement</strong>, and both orders are valid instructions that mean different things:</p>
                <div class="hex-dump">
                    <pre>   8b 84 24 11 22 33 44  SIB then disp  -&gt; mov eax,[rsp+0x44332211]
   8b 84 11 22 33 44 24  disp then SIB  -&gt; mov eax,[rcx+rdx*1+0x24443322]
</pre>
                </div>
                <p>And there is a two-level dependency underneath it: when the base is <code>101</code> and <code>mod=00</code>, the displacement is four bytes and it is an absolute address &mdash; so <strong>you cannot size the instruction from the ModRM alone</strong>, and a decoder that tries desynchronises everything after the first such case.</p>
            </div>

            <div class="unit unit-example">
                <h2>The artifact</h2>
                <p>One decoder, no toolchain. It reads the ELF section table with <code>struct.unpack_from</code>, decodes each instruction from the rules above, and prints the derivation for every field:</p>
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
                <p>Three design decisions, each a position rather than a default. <strong>Length and structure are the contract</strong> &mdash; 364 audited opcodes resolve exactly, and where there is no name the decoder prints <code>(op 0f 6c)</code> rather than guessing, because a guessed mnemonic is a claim nothing checked. <strong>No toolchain anywhere</strong> &mdash; a crosscheck that used <code>objdump</code> to verify <code>objdump</code>&rsquo;s own fields would prove only self-consistency. And <strong>derivation over result</strong>, because a reader given &ldquo;mov eax,[rsp+32]&rdquo; has nowhere to look when they disagree.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/^I7/,/^I8/p'
   578/578 instruction boundaries agree (100.00%)

$ python3 crosscheck.py 2&gt;&amp;1 | tail -3
  118/118 checks passed
  ALL CLAIMS HOLD
</pre>
                </div>
                <p>Every code section of three specimens agrees with the oracle boundary for boundary, and <strong>every chain closes exactly</strong> &mdash; which is the property that matters, because one wrong length desynchronises everything after it and a per-instruction count could agree by coincidence.</p>
            </div>

            <div class="unit unit-example">
                <h2>What was retracted, and what broke</h2>
                <p>Five claims did not survive measurement, all in <code>research.md</code> and all asserted in the crosscheck so a future toolchain that changes the behaviour will fail rather than silently invalidate the text.</p>
                <p><strong>&ldquo;A known-size destination means <code>index=100</code> is rsp.&rdquo;</strong> No &mdash; <code>index=100</code> with <code>REX.X=0</code> is <em>no index</em>, and <code>index=101</code> is rbp. <strong>&ldquo;The SIB follows the displacement.&rdquo;</strong> No &mdash; it precedes it, and both orders are valid different instructions. <strong>&ldquo;<code>0F F4</code> is HLT.&rdquo;</strong> It is <code>PMULUDQ</code>; the one-byte <code>F4</code> had been copied into the two-byte table. <strong>&ldquo;<code>D3</code> takes an immediate.&rdquo;</strong> It does not. <strong>&ldquo;<code>48 C7 /0</code> has an 8-byte immediate.&rdquo;</strong> It is 8 bytes <em>total</em>, because REX.W widens the operand and not the immediate &mdash; which is also why you cannot load <code>0x00000000FFFFFFFF</code> in one instruction.</p>
                <p>Plus six errors in the tooling, kept because they are the lesson. <strong>Three separate reference parsers were wrong about <code>objdump</code>&rsquo;s output format</strong> &mdash; it wraps long encodings across lines, and it sometimes emits an entry with no mnemonic at all &mdash; and every one of those failures made a correct decoder look wrong. <strong>An over-broad exception list</strong> demanded a ModRM byte from three instructions that have none. <strong>Thirteen duplicate dict keys</strong> silently kept the last value, undoing fixes, and the line-based cleanup that removed them also deleted nine unrelated entries. <strong>The operand order was backwards for the entire ALU family</strong> &mdash; <code>0x89</code> is <code>MOV r/m, r</code> &mdash; and the author had it exactly reversed. <strong>An immediate was counted twice</strong> after an edit. And <strong>the file/hex argument ambiguity</strong> fed a filename to <code>bytes.fromhex</code>.</p>
                <p>The common thread, and the collection&rsquo;s standing rule: <strong>a check that fails for the wrong reason is worse than no check, because it teaches you to ignore it</strong> &mdash; so in every case the fix went into the harness, never into the decoder, and the disagreement with the oracle was written down rather than resolved in the oracle&rsquo;s favour by assertion.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start Here</h2>
                <p>If you want the surprise first, go to <a href="/courses/isa/lessons/isa-modes">One Byte Stream, Two Meanings</a>. If you want the artifact, go to <a href="/courses/isa/lessons/isa-decode">Decode It Yourself</a> and run it on a binary you did not build.</p>
                <p>Either way the thing to take away is not a list of opcodes. It is that <strong>the byte stream does not determine the instruction, and once you have accepted that, every remaining rule in this course is a consequence of one decision</strong> &mdash; prepend a widening byte rather than rewrite the fields, and accept a variable-length encoding rather than waste half the space. The chain began with a hex dump; this is the first course where those bytes became a language, and the next one is about what the hardware does with it.</p>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
