// RISC-V atomics -- concept 2: the four fields of fence, the fifteen
// spellings, and the compiler's translation of the six C11 fence strengths.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_fence() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("fence, and an Ordering Model Defined in Terms of It — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvat-concept">
            <a href="/courses/rvat" class="back-link">RISC-V Atomics and the Vector Extension</a>
            <h1>fence, and an Ordering Model Defined in Terms of It</h1>
            <div class="lesson-meta">26 min &middot; Concept 2 of 4 &middot; module: atomic &middot; <a href="/courses/rvat">RISC-V Atomics and the Vector Extension</a></div>

            <div class="unit unit-why">
                <h2>Three models, and only one of them makes the fence the primitive</h2>
                <p>The finding on this page is not a number. It is a <strong>shape</strong>. Three architectures in this collection have a memory-ordering model, and they are not three degrees of one idea:</p>
                <ul>
                    <li><strong>x86-64</strong> gives you total store order as the baseline and lets a barrier do more. The common case is the rule and the exceptions are opt-in.</li>
                    <li><strong>AArch64</strong> gives every access a <em>mode</em> &mdash; <code>ldr</code>, <code>ldar</code>, <code>stlr</code> &mdash; so the ordering is a property of each instruction and <code>dmb</code> is the coarse barrier.</li>
                    <li><strong>RISC-V</strong> gives you a relaxed baseline, two bits per atomic, and <strong>one instruction whose entire content is &ldquo;these operations, relative to those&rdquo;</strong>.</li>
                </ul>
                <p>A baseline-and-escape model is a claim about what happens when you do nothing. An access-mode model is a claim about what each instruction means. A predecessor/successor model is a claim about a <strong>relation between two sets</strong>. <strong>IT IS A DIFFERENCE OF FORM</strong>, and the test is a reduction: a reader who knows what one fence does on RISC-V can predict what every other ordering operation does, because every other one of them is a fence with a part removed. There is no such reduction available in the other two directions, and that asymmetry is the whole point.</p>
                <p>Which is why concept 1 ends where this one begins. The two bits on an AMO are not a fourth thing to learn; they are the <em>difference between one fence and another</em>, recorded in the instruction instead of written out.</p>
            </div>

            <div class="unit unit-model">
                <h2>Four fields, fifteen spellings, and one hole</h2>
                <p>MEASURED-ON-BYTES. <code>fence</code> carries <code>fm</code> at <code>inst[31:28]</code>, a four-bit <code>pred</code> at <code>[27:24]</code>, a four-bit <code>succ</code> at <code>[23:20]</code>, and then <code>rs1</code> and <code>rd</code> &mdash; which are reserved and zero. Here is the whole table, with the spelling <strong>rebuilt from the decoded bits</strong> rather than copied from the reader:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE FOUR FIELDS, read/,+8p'
  word        the spelling   fm      pred       succ       rs1  rd  funct3
  0x0ff0000f  fence          0b0000  iorw = 15  iorw = 15  0    0   0
  0x0ff0000f  fence          0b0000  iorw = 15  iorw = 15  0    0   0
  0x0220000f  fence r, r     0b0000  r = 2      r = 2      0    0   0
  0x0110000f  fence w, w     0b0000  w = 1      w = 1      0    0   0
  0x0330000f  fence rw, rw   0b0000  rw = 3     rw = 3     0    0   0
  0x0230000f  fence r, rw    0b0000  r = 2      rw = 3     0    0   0
  0x0320000f  fence rw, r    0b0000  rw = 3     r = 2      0    0   0
  0x0f20000f  fence iorw, r  0b0000  iorw = 15  r = 2      0    0   0
                </pre>
                </div>
                <p>And that rebuild is not a style choice. If the spelling column were copied from the same reader the encoding came from, a row would be <strong>right twice or wrong once</strong>, and the table could not carry a measurement at all. Printing both columns independently is what lets the table be checked.</p>
                <h3>Two reserved fields, and the manual is why they are zero</h3>
                <p>Every one of those words has <code>rs1 = 0</code> and <code>rd = 0</code>. It is tempting to read that as a property of the assembler &mdash; and the artifact retracted exactly that reading. The manual reserves both fields for finer-grain fences in future extensions, says base implementations shall ignore them, and says standard software <strong>shall zero them</strong>:</p>
                <div class="callout callout-note">
                    <p><strong>Two reserved fields in an instruction whose other two fields carry the whole model is the tell that the encoding was designed for a future nobody has built yet.</strong> It is a small observation and it generalises: when you read an encoding and find fields that are always zero, ask whether a document <em>requires</em> the zero or whether the toolchain merely <em>emits</em> it. The first is an architecture; the second is a habit, and habits are not portable.</p>
                </div>
                <h3>Three instructions, one opcode</h3>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 1 'ordering fences at fm'
  35 ordering fences at fm = 0000, 2 fence.tso at fm = 1000, and
  2 fence.i at funct3 = 1.  THREE INSTRUCTIONS, ONE OPCODE,
                </pre>
                </div>
                <p>Three instructions share opcode <code>0x0f</code>, and the ordering is by <code>funct3</code> and by <code>fm</code> rather than by the opcode alone. So <strong>a decoder that dispatches on the opcode gets the wrong one of the three</strong> &mdash; and this course had to prepend its own model to the borrowed decoder for exactly that reason, because the inherited one reads <code>fm</code> and then calls every word <code>fence</code>. That is a defect in a <em>sibling course&rsquo;s</em> code, published rather than quietly patched, and it is retraction R3.</p>
                <h3>Fifteen spellings, and the sixteenth is a hole</h3>

            <p>&ldquo;The sets are <em>named</em> and not arbitrary&rdquo; sounds like a claim about a document. It is a claim about the <strong>assembler</strong>, so the artifact sweeps it: every non-empty subset of <code>&#123;i, o, r, w&#125;</code>, one assembler call each, and the four-bit code each one gets.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE FIFTEEN SPELLINGS/,+19p'
  bits    value  the name  an instruction the assembler emitted
  0b0001  1      w         fence
  0b0010  2      r         fence
  0b0011  3      rw        fence
  0b0100  4      o         fence
  0b0101  5      ow        fence
  ... through ...
  0b1111  15     iorw      fence

  15 distinct predecessor codes reached, of the 16 the field can hold.
                </pre>
                </div>
                <p>Fifteen of sixteen. And the sixteenth is <strong>the empty set, which the assembler will not spell at all</strong> &mdash; <code>fence</code> with an empty operand list is refused with &ldquo;too few operands for instruction&rdquo;. So the field has sixteen values, fifteen of them have names, and one of them is not reachable by name. That is why the table prints the sixteenth as a <strong>hole rather than a gap</strong>: a reader who has not seen the empty value cannot know whether it is reserved or merely unused, and those are different things to a decoder.</p>
                <p>And the four letters are not interchangeable, which is the part that makes the field a <em>set</em> rather than a mask. <code>i</code> is device input, <code>o</code> is device output, <code>r</code> is a memory read, <code>w</code> is a memory write &mdash; and the manual separates the two domains deliberately: &ldquo;the address space is divided by the execution environment into memory and I/O domains, and the FENCE instruction provides options to order accesses to one or both of these two address domains.&rdquo; So <code>fence r, w</code> and <code>fence io, io</code> are not two spellings of one thing in different amounts. <strong>They order different domains.</strong> A four-bit field whose four bits are two pairs from two independent axes is not a four-state enumeration; it is two two-state enumerations, and a decoder that treats it as one will eventually have to say &ldquo;iorw&rdquo; when it means &ldquo;both domains, everything&rdquo;.</p>
            </div>

            <div class="unit unit-example">
                <h2>What the compiler chose, and where it stopped</h2>
                <p>The model being <em>definitional</em> is a fact about the ISA. The model being <em>used</em> is a fact about clang 21.1.8. A course that conflates them is making a claim about one from evidence for the other, so the table is here in full:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/AND WHAT THE COMPILER CHOSE/,+8p'
  function         instr  fences  what it emitted
  .Lpcrel_hi0      3      0       NONE
  fence_acqrel     2      1       fence.tso (bare)
  fence_acquire    2      1       fence (r, rw)
  fence_consume    2      1       fence (r, rw)
  fence_relaxed    1      0       NONE
  fence_release    2      1       fence (rw, w)
  fence_seqcst     2      1       fence (rw, rw)
  load_acquire     3      1       fence (r, rw)
  load_seqcst      4      2       fence (rw, rw); fence (r, rw)
                </pre>
                </div>
                <p>Three rows in that table are worth reading twice, and all three are the compiler <em>translating</em> rather than choosing.</p>
                <div class="callout callout-key">
                    <p><strong>CONSUME and ACQUIRE are the same four bits.</strong> The C11 distinction between them is not representable in this encoding and the compiler does not pretend otherwise &mdash; it emits one word for both. <strong>A language feature the hardware cannot express shows up here as a diagnostic-free silent merge, and finding it costs one table.</strong></p>
                </div>
                <div class="callout callout-key">
                    <p><strong>ACQ_REL emits <code>fence.tso</code> and SEQ_CST emits <code>fence rw, rw</code>.</strong> That first one is the surprise: an acquire-release fence, whose spelling <em>names a barrier</em>, compiles to an instruction that is not <code>fence</code> at all. It is <code>fm = 1000</code> &mdash; a different instruction that shares an opcode. <strong>The mnemonic you grep for is not always the mnemonic that gets emitted, and a build that greps assembly for &ldquo;fence&rdquo; will miss half the fences.</strong></p>
                </div>
                <div class="callout callout-key">
                    <p><strong>An acquire load and a sequentially consistent load are the same <code>lw</code></strong> &mdash; four bytes, one opcode, byte for byte &mdash; and the difference is discharged by a fence <em>beside</em> it. On AArch64 the same two C11 operations are <code>ldar</code> and <code>ldar</code>, literally the same instruction; on x86-64 both are a plain <code>mov</code> and the difference is a <code>mfence</code> or nothing at all. RISC-V puts the ordering in a separate instruction because its model says ordering is a <em>relation between two sets</em> and not a property of an access. And measured: the something else is a <strong>second fence</strong>. <code>load_seqcst</code> emits <code>fence rw, rw</code> before the load and <code>fence r, rw</code> after it &mdash; two fences for one load, because the extra constraint a seq_cst load carries is on its relation to <em>other operations</em>, and that is discharged by ordering the neighbours rather than by changing the load.</p>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The row that is not a fence at all, and the one that is not <code>fence</code></h2>
                <p><code>fence_relaxed</code> is a bare <code>ret</code>. <strong>A relaxed fence is not a no-op instruction; it is the absence of one.</strong> A function that consists of a single return is a correct compilation of a function that asks for nothing, and the encoding for &ldquo;no ordering&rdquo; is no instruction. Eight of the twenty-one functions in that table emitted no fence at all.</p>
                <p>And then there is <code>fence.tso</code>, which is where the page has to stop, and the stopping is the content.</p>
                <p>This is where the page has to stop, and the stopping is the content. <code>fence.tso</code> is <code>fm = 1000</code> with <code>pred = RW</code> and <code>succ = RW</code> &mdash; the same sets as <code>fence rw, rw</code>, differing only in the <code>fm</code> field, which the manual calls reserved for future use. The natural guess is that it is a weaker barrier and that emitting it is a request. The manual says something <strong>stronger</strong>, and the direction is the interesting part:</p>
                <div class="hex-dump">
                <pre>    rv32-unpriv, chapter 2.7:
      "Because FENCE RW,RW IMPOSES A SUPERSET OF THE ORDERINGS THAT
       FENCE.TSO IMPOSES, IT IS CORRECT TO IGNORE THE fm FIELD AND
       IMPLEMENT FENCE.TSO AS FENCE RW,RW."
                </pre>
                </div>
                <p>So the instruction <strong>is</strong> a request for a weaker barrier than the one it is spelled like, <em>and</em> a base implementation is explicitly permitted to give the stronger one. Which means &ldquo;emit a <code>fence.tso</code>&rdquo; is not portable advice and also not a weaker barrier, and the only honest thing to say is both.</p>
                <div class="callout callout-warning">
                    <p><strong>And this course cannot tell you which one a machine does.</strong> It is measured that the compiler emits it for <code>__ATOMIC_ACQ_REL</code>, that it is <code>fm = 1000</code> with <code>pred = RW</code> and <code>succ = RW</code>, and that the manual permits the stronger implementation. Whether the machine gives the weaker barrier or the stronger one is a property of silicon, and there is no RISC-V silicon on this host. <strong>That is limit 6, and it is quoted beside the measurement rather than in a footnote.</strong></p>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Count the fence strength you did not ask for.</strong> <em>(Compile <code>__atomic_thread_fence(__ATOMIC_ACQUIRE)</code> and read the disassembly. Then compare with the <code>lr.aq</code> form of an acquire load. The first is a <em>relation between two sets</em>; the second is the same relation with a part deleted. Now ask which of the two is cheaper to reason about in your own code, and notice that the answer is not the answer to which is cheaper on hardware.)</em></li>
                    <li><strong>Find the hole.</strong> <em>(There are sixteen values of <code>pred</code> and fifteen names. Try to get the assembler to emit the sixteenth &mdash; <code>fence</code> with no sets at all. Read the diagnostic. Now write a decoder that has no case for it and consider what it will print for the zeroed <code>pred</code> of a <code>fence.i</code>, which is a different instruction entirely.)</em></li>
                    <li><strong>Grep your own build.</strong> <em>(Search a disassembly for <code>fence</code>. Count the instructions you find. Now search for <code>fence.tso</code> and count again. The difference is real: <code>fm = 1000</code> is a separate instruction that shares the opcode and will not appear in a mnemonic grep for &ldquo;fence&rdquo; in some tools and will in others. <strong>Which is exactly why the page prints the three-instruction-one-opcode count.</strong>)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>What ordering <em>means</em> &mdash; what a race is, what happens when two harts see stores in different orders &mdash; is in <a href="/courses/smp/lessons/smp-ordering">smp-ordering</a>, and it is not re-taught here. The same model on the two machines this collection can run is <a href="/courses/x86simd/lessons/x86-order">x86-order</a>, where the baseline is TSO and <code>mfence</code> is the escape, and <a href="/courses/a64simd/lessons/a64-order">a64-order</a>, where the ordering rides on the access as a mode and <code>dmb</code> is the coarse one. <a href="/courses/rvabi/lessons/rv-noflags">rv-noflags</a> is why the whole model has to be spelled out in instructions at all: an architecture with no condition codes has nowhere to put a result except a register, so every ordering operation is a real instruction with a name.</p>
                <p>Next: <a href="/courses/rvat/lessons/rv-vector">vsetvli and the Four Fields It Carries</a>, which is the same kind of idea in a different place &mdash; a fixed 32-bit word that describes a vector whose length is not in it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvat/lessons/rv-amo">The Reservation, and Why the Retry Is the Instruction</a></span>
                <span>Next: <a href="/courses/rvat/lessons/rv-vector">vsetvli and the Four Fields It Carries</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
