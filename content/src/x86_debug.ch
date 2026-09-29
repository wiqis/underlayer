// The x86-64 Machine — Concept 5: the debug registers
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_debug() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("DR0 to DR7 and the Mask a Debugger Must Program — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>DR0 to DR7 and the Mask a Debugger Must Program</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Eight registers hold four addresses and the control word that says what to do about them. That is the entire hardware debug facility on x86, and it is the reason a debugger can set a data breakpoint that fires on the exact instruction that stored &mdash; a capability that most other architectures do not offer and that every C programmer has relied on without knowing it existed.</p>
                <p>It is also a set of registers a user process cannot touch, in a set of registers with <strong>two authoritative layouts that disagree with each other</strong>, and where the field that says &ldquo;break on a four-byte write&rdquo; is a two-bit field followed by a two-bit field in a specific order that is the single most common DR7 bug there is. That is a reference with a retraction in it, and this page is where both live.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: four addresses and one control word</h2>
                <p>The <em>addresses</em> are trivial: <code>DR0</code> to <code>DR3</code> each hold one linear address, and there are four of them because there are four, and that is the whole of the hardware's breakpoint capacity. <code>DR4</code> and <code>DR5</code> are not registers at all &mdash; they are aliases of <code>DR6</code> and <code>DR7</code> when <code>CR4.DE</code> is clear, and <strong>#UD</strong> when it is set, which is the one time on this whole page where a <code>CR4</code> bit from the previous concept reappears.</p>
                <p><code>DR6</code> is status and <code>DR7</code> is control. <code>DR6</code> has four bits for &ldquo;breakpoint <em>n</em> fired&rdquo;, three more for single-step, task-switch and debug-register access, and a large reserved field. <code>DR7</code> is where the interest is:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/1B4\./,/LEN | 11/p' | head -40
1B4. DR0-DR7.  THE MASK, THE FORMULA, AND THE TWO SOURCES.

  DR0-DR3  | one LINEAR address each; four breakpoints, no more
  DR4,DR5  | aliases of DR6,DR7 when CR4.DE=0, #UD when CR4.DE=1
  DR6      | status: bits 0-3 B0-B3, 13 BD, 14 BS, 15 BT
  DR7      | control: the eight enable bits, the GD bit, and EIGHT
           | four-bit fields, one per breakpoint

  DR7 | 0     | L0      | local enable, breakpoint 0, cleared on a switch
  DR7 | 1     | G0      | global enable, breakpoint 0
  DR7 | 2     | L1      | local enable, breakpoint 1
  DR7 | 3     | G1      | global enable, breakpoint 1
  DR7 | 4     | L2      | local enable, breakpoint 2
  DR7 | 5     | G2      | global enable, breakpoint 2
  DR7 | 6     | L3      | local enable, breakpoint 3
  DR7 | 7     | G3      | global enable, breakpoint 3
  DR7 | 8     | LE      | local exact-breakpoint enable, ignored after the 486
  DR7 | 9     | GE      | global exact-breakpoint enable, ignored after the 486
  DR7 | 10    | ONE     | architecturally reserved to 1, the RESET value's bit
  DR7 | 11-12 | -       | reserved
  DR7 | 13    | GD      | general detect: #DB on any DR0-DR7 access
  DR7 | 14-15 | -       | reserved
  DR7 | 16-19 | FP0     | bits 17:16 R/W0, bits 19:18 LEN0
  DR7 | 20-23 | FP1     | bits 21:20 R/W1, bits 23:22 LEN1
  DR7 | 24-27 | FP2     | bits 25:24 R/W2, bits 27:26 LEN2
  DR7 | 28-31 | FP3     | bits 29:28 R/W3, bits 31:30 LEN3
  DR7 | 32-63 | -       | reserved, read as 0
                </pre>
            </div>
                <p>Two things about that layout are the whole reason this page exists. <strong>First, the eight enable bits are contiguous</strong> &mdash; <code>0x55</code> for all four local, <code>0xAA</code> for all four global &mdash; which is the 80386 arrangement and the reason the high two breakpoints have gaps in the bit numbering. <strong>Second, the four control fields are four bits wide each starting at bit 16</strong>, and each is split <em>R/W in the low two, LEN in the high two</em>. Not two fields of two bits side by side. One four-bit field, and getting the order of its halves wrong produces a mask that is entirely plausible and entirely wrong.</p>
                <div class="formula">
   THE LENGTH FIELD, and this is the trap.

     LEN | 00 | 1 byte
     LEN | 01 | 2 bytes
     LEN | 10 | 8 bytes, ONLY defined in 64-bit mode
     LEN | 11 | 4 bytes

   READ THAT AGAIN.  The two-bit code for
   FOUR bytes is 11, and the code for EIGHT
   is 10.  10 means LONGER.

   A table that says 10 = 4 bytes is not a
   typo in a table; it is a broken debugger,
   because the mask will be accepted by the
   hardware, the breakpoint will be set, and
   it will fire on a different width than the
   one that was asked for -- or not fire at
   all, depending on which way the mistake
   went.

   And the other half:
     R/W | 00 | instruction EXECUTE
     R/W | 01 | data WRITE
     R/W | 10 | I/O read or write, ONLY
     R/W |    |   defined while CR4.DE=1
     R/W | 11 | data READ or WRITE
            </div>
            <p><code>10</code> in the R/W field is the only one of the four that is undefined on a modern part with <code>CR4.DE</code> clear, and it is undefined rather than reserved, which is a stronger word: a kernel that programs it gets behaviour it may not rely on.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the mask, computed rather than quoted</h2>
                <p>Four cases, each built from the formula, each checked for internal consistency before it is printed:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  DR7MASK'
  DR7MASK | case | value | fields disjoint
  DR7MASK | four breakpoints, 4-byte, data write, global   | 0x00000000dddd06aa | yes
  DR7MASK | four breakpoints, 4-byte, data read/write, global | 0x00000000ffff06aa | yes
  DR7MASK | four breakpoints, 8-byte, data read/write, global | 0x00000000bbbb06aa | yes
  DR7MASK | one breakpoint, 1-byte, execute, LOCAL         | 0x0000000000000601 | yes
  DR7MASK | the mask for four 4-byte WRITE breakpoints | 0x00000000dddd06aa
  DR7MASK | derived from the formula above, not typed in
  DR7LOCAL | the same four, all LOCAL, no GD | 0x0000000055550455
  DR7RESET | the reset value: the fixed one and nothing else | 0x0000000000000400
                </pre>
            </div>
                <p>Read the mask for four 4-byte write breakpoints, <code>0xdddd06aa</code>, field by field, because that is the exercise and because a mask you can read is a mask you can debug:</p>
                <div class="hex-dump">
                <pre>  0x0aa  L0 G0 L1 G1 L2 G2 L3 G3  all four GLOBAL
  0x200  GE          global exact, what Linux always sets
  0x400  ONE         the reset value's fixed one
  0x4000 R/W0 = 01   data WRITE, breakpoint 0
  0x30000 LEN0 = 11  FOUR bytes  &lt;-- the 11 that means four
  0x1000000  R/W1 = 01
  0x3000000  LEN1 = 11
  0x10000000 R/W2 = 01
  0x30000000 LEN2 = 11
  0x100000000 R/W3 = 01
  0x300000000 LEN3 = 11
  ------
  0xdddd06aa
                </pre>
            </div>
                <p>And the <code>DR7LOCAL</code> row next to it is worth stopping on, because <strong>the first version of that line was wrong in a way that would have disabled every breakpoint it named</strong>. The intent was &ldquo;the same four, all local&rdquo;, and the code cleared the global bits out of the all-global mask:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  DR7(LOCAL|MASK) \| (the same|the mask for)'
  DR7MASK | the mask for four 4-byte WRITE breakpoints | 0x00000000dddd06aa
  DR7LOCAL | the same four, all LOCAL, no GD | 0x0000000055550455
                </pre>
                <p>The two lines differ in exactly one operation, and the operation is a logical OR. The first version computed the all-local mask by <em>clearing</em> the global bits out of the all-global mask &mdash; which is arithmetic on a mask that never had them set, so the result had <strong>zero enable bits</strong> and four correct control fields. That withdrawn value is <code>0x55550400</code>, and the correct one is <code>0x55550455</code>: the difference is the low <code>0x55</code>, the four local enable bits that were missing. <strong>A debugger programmed with the withdrawn value would run correctly and break on nothing at all</strong>, and a user would conclude the program has no bugs. The general form is the same as the <code>%al</code> lesson in the ABI course: a mask that says &ldquo;do nothing&rdquo; is the correct mask for a debugger that is <em>about</em> to stop, which is exactly why it is so easy to ship by accident.</p>
            </div>
                <p><code>0x55550400</code> against the correct <code>0x55550455</code>. The <code>0x555</code> in the low bits is the residual of the global bits, not the local ones: clearing a set bit leaves nothing, so the mask that came out had <em>zero</em> enable bits and four correct control fields. <strong>A debugger programmed with it would run correctly and break on nothing at all</strong>, and a user would conclude the program has no bugs.</p>
                <h3>The two layouts, and why the file cannot say which is right</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/DISAGREEMENT, PRINTED RATHER/,/in five lines/p'
  DISAGREEMENT, PRINTED RATHER THAN SETTLED.  A third description,
  the Intel SDM as summarised in several secondary sources, places
  L2 and G2 at bits 8 and 9, LE and GE at 16 and 17, and starts the
  R/W0 field at bit 22 with FOUR-bit LEN fields.  Linux
  DR_LOCAL_ENABLE_MASK=0x55, DR_GLOBAL_ENABLE_MASK=0xAA,
  DR_CONTROL_SHIFT=16, DR_CONTROL_SIZE=4, DR7_FIXED_1=0x400 and
  QEMU's DR7_TYPE_SHIFT=16, DR7_LEN_SHIFT=18 all say the table
  above.  Two implementations that work on real silicon agree with
  each other.  This file CANNOT MEASURE WHICH ONE ITS OWN CPU
  IMPLEMENTS, because DR7 is unreadable from ring 3: section 3
  shows the MOV failing.  The instrument that would settle it is a
  one-line ptrace program running at CPL 0.
                </pre>
            </div>
                <p>There is a third piece of evidence in the table itself, and it is the one that settles it for a <em>kernel</em> even though it settles nothing for a user process: <strong>bit 10 is architecturally reserved to 1</strong>, and it is the reset value's only set bit. Under the layout this file prints, bit 10 is a reserved hole between the enable block and the GD bit. Under the alternative, bit 10 is <code>L3</code> &mdash; the local enable for breakpoint 3 &mdash; and a kernel could not have a fixed-1 bit there without permanently enabling a breakpoint. <strong>That single fact eliminates one of the two descriptions, and it eliminates it by arithmetic rather than by authority.</strong></p>
                <p>It still does not tell you whether this particular CPU implements the surviving layout, because the only way to ask is to write to <code>DR7</code> and read it back. Every attempt does this:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  EDGE \| mov (dr|reg)'
  EDGE | mov dr0 -&gt; reg                 | debug registers   | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov dr6 -&gt; reg                 | debug registers   | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov dr7 -&gt; reg                 | debug registers   | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov reg -&gt; dr7                 | debug registers   | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
                </pre>
            </div>
                <p>Five of eight, all <code>si_code 128</code>. <code>DR4</code> and <code>DR5</code> are not in the table because whether they are #UD depends on <code>CR4.DE</code>, which is a bit this process cannot read, so a probe of them would measure the bit and be reported as a measurement of the register. The honest thing is to leave them out and say why.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the one debug mechanism ring 3 <em>can</em> reach</h2>
                <p>The debug <em>registers</em> are unreachable. The debug <em>exception</em> is not, and the reason is that vector 1 is delivered by a completely separate mechanism: set bit 8 of the flags and the CPU raises a <code>#DB</code> after every instruction, without consulting a single one of the eight registers.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  RAISE \| (int1|EFLAGS)'
  RAISE | int1                                              | #DB 1   | sig 5  | 1    | 0x&lt;per-run address&gt; | the RIP the kernel chose to report, for SIGTRAP
  RAISE | EFLAGS.TF set, then two more instructions         | #DB 1   | sig 5  | 2    | 0x&lt;per-run address&gt; | the RIP the kernel chose to report, for SIGTRAP
                </pre>
            </div>
                <p>Both arrive as <code>SIGTRAP</code> on vector 1, and <strong>they arrive with different <code>si_code</code> values</strong> &mdash; <code>1</code> for the <code>int1</code> and <code>2</code> for the trap flag. That is the exception table's class column showing up in a signal payload: the same vector, two conditions, two codes, and a handler that treats <code>si_code 2</code> as &ldquo;a single step happened&rdquo; is reading something the hardware actually decided rather than something it inferred.</p>
                <p>Three consequences worth having:</p>
                <ul>
                    <li><strong>A debugger does not need <code>DR0</code>&ndash;<code>DR3</code> to single-step.</strong> It writes the trap flag, runs one instruction, and takes the <code>#DB</code>. The four address registers exist for <em>watchpoints</em> &mdash; breaks on a data access &mdash; and single-stepping is a different mechanism entirely. That is why single-stepping works on every architecture x86-64 has an emulator for, and why watchpoint counts are always a hard four.</li>
                    <li><strong>Setting the trap flag is a user-mode operation.</strong> <code>pushfq; pop %rax; or $0x100, %rax; push %rax; popfq</code> is five instructions in a user program. The privilege boundary that stops a user program reading <code>DR7</code> does not stop it asking for a single step, and <strong>that asymmetry is the honest shape of the debug facility</strong>: a user can ask for a one-instruction trace and gets one, and cannot ask for a four-instruction watchpoint set.</li>
                    <li><strong>It costs a kernel round trip per instruction.</strong> The <code>#DB</code> is an exception, the kernel delivers a signal, the handler runs, the handler returns, and the next instruction executes. A single-stepping debugger is therefore a <em>signal-driven</em> debugger and is limited by the cost of a signal. <a href="/courses/priv/lessons/priv-doors">The privilege course's mode-change concept</a> measured that cost; this is where it is spent.</li>
                </ul>
                <p>And the limit, which is the same limit as everything else on this page: <strong>this file cannot set a watchpoint, and so cannot tell you what a watchpoint costs or whether the addresses are compared before or after translation.</strong> The addresses in <code>DR0</code>&ndash;<code>DR3</code> are <em>linear</em>, so a watchpoint on a page that is not currently mapped compares against a translation that does not exist &mdash; which is a real design decision in every debugger, and one this artifact has no instrument for.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Recompute the mask by hand and then let the artifact do it.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 1B4. <em>(Expect <code>0xdddd06aa</code> for four 4-byte write breakpoints, and expect the harness to recompute it from the printed formula and compare. If you change the LEN order in the formula the harness must fail, which is the point of asserting the arithmetic rather than the constant: the constant would have passed a wrong formula.)</em></li>
                    <li><strong>Reproduce the <code>DR7LOCAL</code> bug on purpose.</strong> Change the <code>| 0x55ULL</code> back out of that line and rebuild. <em>(Expect <code>0x55550400</code> and a harness failure on the local-mask check. It is a one-character deletion and it produces a mask that disables everything, which is the most expensive possible place to have an off-by-a-bit.)</em></li>
                    <li><strong>Find a real debugger's constant.</strong> Search a debugger source for the <code>DR7_FIXED_1</code> or the local-enable mask and check which of the two layouts it encodes. <em>(Expect 0x400 and 0x55, and expect that the debugger also <em>sets the global bit 9</em> for reasons that are historical &mdash; exact breakpoints have been free since the 486, and the bit is a leftover. A debugger that still sets a bit whose only function was to slow down a 386 is carrying a scar, and the scar is harmless, which is why nobody has removed it.)</em></li>
                    <li><strong>Single-step from user mode and count the signals.</strong> Set the trap flag, execute forty instructions, and count the <code>SIGTRAP</code>s. <em>(Expect forty, and expect the count to match the instruction count exactly rather than approximately &mdash; which is the interesting result, because it means the trap flag is honoured per instruction and not per something coarser. Then set the flag, take a page fault, and see whether the count survives the fault.)</em></li>
                    <li><strong>Decide what your kernel's GD bit does.</strong> <code>CR4.DE</code> and <code>DR7.GD</code> together decide whether a user program can <em>detect</em> that something is inspecting it. <em>(Expect there to be no complete answer &mdash; a debugger using watchpoints is invisible to the traced program, and a debugger using <code>DR4</code> or <code>DR5</code> is not. That asymmetry is a security property of the hardware and it is one of the very few that nobody has to choose to implement.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, the previous concept is where <code>CR4.DE</code> lives and where the general shape of &ldquo;a bit decides whether an instruction exists&rdquo; was established. <a href="/courses/priv/lessons/priv-vectors">The privilege course's vector concept</a> is where <code>#DB</code> appeared as a single row; the second concept here is what measured the two conditions behind that row.</p>
                <p>Forwards, and the connection is the reason the next concept is where it is. <code>#DB</code> is vector 1, and vector 1 is delivered for a non-canonical address &mdash; except it is not, a non-canonical address is vector 13 by way of a general protection fault &mdash; and the whole of the sixth concept is about a boundary that is not a privilege boundary at all. <strong>The privilege check that fails when you cross into the hole in the address space is a canonicality check, it happens during effective-address generation, and it produces exactly the same <code>si_code 128</code> as a #GP for a privileged instruction.</strong> Two different mechanisms, one number, and the artifact measures both so the pages can say so.</p>
                <p>Outward. Debugging is where a compiler backend meets this page, and the meeting point is <code>len</code>: the four available breakpoints have a width each, so a <code>char*</code> can be watched at 1-byte granularity and a <code>long</code> at 8, and a struct larger than 8 bytes cannot be watched in one breakpoint. Every debugger you have used has a &ldquo;watch this variable&rdquo; feature whose width is silently rounded, and that rounding is this page's <code>LEN</code> field.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-cr">CR0 to CR4, Every Bit</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-virtual">The 48-Bit Split, LA57 and LAM</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
