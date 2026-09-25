// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: .eh_frame, CIE and FDE, and the CFA that location expressions depend on.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_frames() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Call Frame Information — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Call Frame Information</h1>
            <div class="lesson-meta">22 min &middot; Module 3: DIEs, Types, Scopes and Locations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two facts make stack unwinding possible at all: the stack grows <em>downward</em>, so a return address pushed by a <code>call</code> is at a known place relative to the frame; and every function that might be unwound through saves the registers it clobbered before it clobbered them. Call frame information records the second fact as a set of rules, and the CIE records the rules that are true everywhere.</p>
                <p>It is also the answer to a question the previous concept left open. A location expression said <code>DW_OP_fbreg -36</code> &mdash; relative to the frame base &mdash; and did not say where the frame base is. That is here, in <code>DW_CFA_def_cfa</code>. The two sections are one mechanism split across two files, and a location expression with no CFI beside it is unusable.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The section is a sequence of records, and they come in exactly two shapes which are <strong>not</strong> the same shape:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Record</th><th scope="col">Contains</th><th scope="col">Says</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>CIE</strong><br>(Common Information Entry)</td>
                            <td>length, CIE_id = 0, version, augmentation string, the alignment factors and return-address register, any augmentation data, then initial instructions</td>
                            <td>the rules that hold for every function that uses this CIE</td>
                        </tr>
                        <tr>
                            <td><strong>FDE</strong><br>(Frame Description Entry)</td>
                            <td>length, CIE_pointer, initial_location, address_range, then instructions</td>
                            <td>which CIE's rules apply, over which address range, and what changes inside it</td>
                        </tr>
                    </tbody>
                </table>
                <p>An FDE has <strong>no version and no augmentation string</strong>. After the CIE pointer come exactly two encoded values and then the instructions. Reading a version byte for an FDE eats the first byte of the address and turns everything after it into noise &mdash; silently, because the instruction decoder will happily chew through whatever bytes it is given.</p>
                <p>The instructions themselves are a second little stack machine, but a much simpler one. It has no stack: each opcode <em>modifies a rule table</em>, and the table is read at whatever program counter you are unwinding to.</p>
                <ul>
                    <li><code>DW_CFA_def_cfa reg, offset</code> &mdash; <strong>the important one.</strong> The Canonical Frame Address is <code>reg + offset</code>. This single rule is what a location expression&rsquo;s frame base resolves to.</li>
                    <li><code>DW_CFA_offset reg, factored</code> &mdash; register <code>reg</code> was saved at <code>CFA + factored &times; data_alignment_factor</code>.</li>
                    <li><code>DW_CFA_def_cfa_offset n</code> &mdash; change the CFA offset, keeping the register. This is what a <code>push</code> looks like: <code>rsp</code> moves, so the distance from <code>rsp</code> to the CFA shrinks by 8.</li>
                    <li><code>DW_CFA_advance_loc n</code> &mdash; the following rules apply from <code>n</code> code-alignment units later. This is how a table stays compact: a function of forty instructions needs two rules, not forty.</li>
                    <li><code>DW_CFA_def_cfa_expression</code> &mdash; the CFA is given by a DWARF expression instead of register-plus-offset, for frames the compiler cannot describe simply.</li>
                    <li><code>DW_CFA_restore reg</code> &mdash; revert that register to the CIE&rsquo;s initial rule. This is what makes the advance-and-restore pattern work without listing every register twice.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Why the alignment factors are negative.</strong> <code>data_alignment_factor</code> is <strong>-8</strong> in the reference binary, and that is not a quirk. Register-save locations are described as <em>negative</em> displacements from the CFA, because that is the direction the stack grows. A positive factor would mean offsets below the frame, which is where the CFA is measured from in the first place. A reader that takes the absolute value of the factor produces save locations in the caller&rsquo;s frame.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The reference binary has exactly <strong>one CIE</strong>, at offset 0, twenty bytes long. Here it is in full, decoded byte by byte and matched against <code>readelf</code>:</p>
                <div class="hex-dump">
                    <pre>0000: 14 00 00 00 00 00 00 00 01 7a 52 00 01 78 10 01
      |&mdash;&mdash;length 20&mdash;&mdash;| |&mdash;CIE_id 0-&mdash;| |v|&mdash;aug&mdash;| |  |  |  |  |
                                              "zR"    |  |  |  |  |
                                                   |  |  |  +&mdash; 1b: fde_encoding
                                                   |  |  +&mdash; 10: return_address_register = 16
                                                   |  +&mdash; 78: data_alignment_factor = -8 (SLEB)
                                                   +&mdash; 01: code_alignment_factor = 1
0010: 1b 0c 07 08
         |&mdash;| |&mdash;&mdash;&mdash;&mdash;&mdash;&mdash;&mdash;&mdash; initial instructions
         |  +&mdash; 0c = DW_CFA_def_cfa  reg=7 (rsp) offset=8
         +&mdash; 1b = augmentation data length 1, then the R encoding 0x1b
              07 = DW_CFA_undefined  reg=16
              08 = DW_CFA_same_value reg=0
              (then padding nops to fill length 20)</pre>
                </div>
                <p>In words, which is what the concept is actually about:</p>
                <pre><code>DW_CFA_def_cfa  reg=7, offset=8       -> the CFA is rsp + 8
DW_CFA_offset  reg=16, factored=-8 bytes -> the return address is at CFA - 8
DW_CFA_undefined reg=16
DW_CFA_same_value reg=0</code></pre>
                <p><code>rsp + 8</code> on entry is the whole point. The return address sits at CFA-8 because <code>call</code> pushed it and then the <code>push rbp</code> (or the ABI&rsquo;s equivalent) moved rsp down by another 8. So the CFA is a fixed landmark that does not move as the function pushes and pops, and every saved register and every local is described relative to it.</p>
                <p>Now an FDE that does more than the default. The FDE covering <code>0x1020..0x1040</code>:</p>
                <div class="hex-dump">
                    <pre>DW_CFA_def_cfa_offset 16        -&gt; CFA is now rsp + 16
DW_CFA_advance_loc    6            -&gt; from here on, 6 bytes later
DW_CFA_def_cfa_offset 24           -&gt; CFA is rsp + 24
DW_CFA_advance_loc    10
DW_CFA_def_cfa_expression ...     -&gt; CFA is computed by a DWARF expression
(then nops)</pre>
                </div>
                <p>That is a real function's unwind table: three pushes, each one <code>def_cfa_offset</code> rather than a full redefinition, and then a frame the compiler cannot describe as register-plus-offset so it hands over a twelve-byte expression. The compactness is the design &mdash; a forty-instruction function needs three rules, not forty.</p>
                <h3>Eight FDEs for five functions</h3>
                <p>The reference binary has eight FDEs:</p>
                <div class="formula">
0x1060..0x1086   0x1020..0x1040   0x1040..0x1050   0x1050..0x1060
0x1149..0x117e   0x117e..0x11a9   0x11a9..0x11c9   0x11c9..0x1232
                </div>
                <p>One function's information is split across <strong>three adjacent FDEs</strong> (<code>0x1149..0x117e</code>, <code>0x117e..0x11a9</code>, <code>0x11a9..0x11c9</code>). "One FDE per function" is a reasonable first guess and it is wrong often enough to matter: any tool that assumes it will mis-handle a function whose unwind rules change mid-body, and there is no marker saying so.</p>
                <h3>Three encoding traps, all verified here</h3>
                <ol>
                    <li><strong>The CIE pointer in <code>.eh_frame</code> is relative to its own field position.</strong> Both FDEs in this binary store a value equal to the offset of the pointer field itself: the FDE at 0x18 stores 0x1c, and the FDE at 0x30 stores 0x34. The CIE is at 0. Read the field as an absolute offset and you look for a CIE at 0x1c and 0x34 and find nothing. In <code>.debug_frame</code> the same field is absolute &mdash; the two sections disagree, and a reader written for one will silently fail on the other.</li>
                    <li><strong><code>0x0b</code> is <code>sdata4</code>, four bytes, not eight.</strong> The CIE sets <code>fde_encoding = 0x1b</code> = <code>DW_EH_PE_pcrel | DW_EH_PE_sdata4</code>. Reading the low nibble as an eight-byte value swallows the following four bytes, and the FDE&rsquo;s end address comes out as <code>0x10076478</code> instead of <code>0x1086</code>. Every instruction after that point is then decoded from the wrong position.</li>
                    <li><strong><code>pcrel</code> applies to the location, not to the range, and needs the section&rsquo;s <em>virtual</em> address.</strong> <code>initial_location</code> is a displacement from the address of its own field, where &ldquo;address&rdquo; means the runtime address &mdash; <code>.eh_frame</code> is loaded at 0x2050, not at its file offset. <code>address_range</code> is a <em>length</em>: applying pcrel to it as well gave <code>0x20ac</code> where the real end of the range is <code>0x1040</code>.</li>
                </ol>
                <p>All three were found because an independently written decoder disagreed with <code>readelf</code>. All eight FDE ranges now agree with it exactly.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Unwinding one frame, by hand, using only the tables above. Say the program counter is at 0x1180, inside the function whose FDEs are 0x117e..0x11a9 and 0x11a9..0x11c9.</p>
                <ol>
                    <li><strong>Find the FDE whose range contains 0x1180.</strong> It is <code>0x117e..0x11a9</code> &mdash; and note that it is <em>not</em> the first of the three, so a reader assuming one FDE per function has already gone wrong.</li>
                    <li><strong>Start from the CIE&rsquo;s initial rules.</strong> CFA = rsp + 8, and register 16 (the return address) is at CFA-8. These hold at the FDE&rsquo;s entry point and are inherited from the CIE, not restated.</li>
                    <li><strong>Apply the FDE&rsquo;s own instructions up to 0x1180.</strong> For this FDE they leave the CFA rule at rsp+8, so CFA = rsp + 8 at this program counter.</li>
                    <li><strong>Now evaluate any location expression.</strong> The parameter <code>y</code> in the equivalent <code>-O0</code> build has <code>DW_AT_location : 91 58</code> = <code>DW_OP_fbreg -40</code>. Its <code>DW_AT_frame_base</code> is <code>9c</code> = <code>DW_OP_call_frame_cfa</code>, so the address is <code>CFA - 40</code> = <code>rsp + 8 - 40</code> = <code>rsp - 32</code>.</li>
                    <li><strong>Read the saved return address, and repeat.</strong> It is at CFA-8 = <code>rsp</code>. Unwinding means loading that value, restoring the caller&rsquo;s register state from the caller&rsquo;s CFI, and doing it again &mdash; which is how a debugger walks a backtrace without executing anything.</li>
                </ol>
                <div class="callout callout-tip">
                    <strong>Why the CFA is better than the frame pointer.</strong> The classic frame pointer chain depends on every function saving the frame pointer, which leaf functions often do not. The CFA is derived from the stack pointer and the unwind rules instead, so it works for any function that can be unwound &mdash; including one that has pushed four registers and has no frame pointer at all. That is the entire reason the CFI is expressed as a small rule table rather than as "here is where the saved registers are".
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=frames shape
$ readelf -wf shape            # -w wide, -f frames
$ objdump --dwarf=frames shape</code></pre>
                <p>Experiments that turn the tables into understanding:</p>
                <ul>
                    <li><strong>Count FDEs against functions.</strong> <code>readelf -wf</code> lists the ranges; compare them with <code>readelf --debug-dump=info</code>&rsquo;s <code>low_pc</code>/<code>high_pc</code> pairs. In the reference build, five functions produce eight FDEs. Find which function owns three of them and read the extra rules &mdash; that is where the <code>def_cfa_expression</code> lives.</li>
                    <li><strong>Write the CFA arithmetic for a function you know.</strong> Pick <code>make_point</code>, note that its three parameters are at CFA-36, CFA-40 and CFA-44 and the return address at CFA-8, and confirm the frame is the shape a three-argument x86-64 call should produce. If your numbers do not line up, one of the two decoders is wrong.</li>
                    <li><strong>Read the <code>def_cfa_expression</code> bytes.</strong> The twelve bytes <code>0c 07 08 80 00 3f 1a 39 2a 33 24 22</code> are a DWARF expression using the <em>location</em> machine. <code>readelf</code> prints its reading; decode it yourself with the opcodes from the previous concept and check you agree.</li>
                    <li><strong>Break the CIE pointer deliberately.</strong> Add 4 to the stored value in one FDE and watch every rule from that FDE become unreachable. The failure is silent: the FDE still parses, it just points at bytes inside another record, and the result is a backtrace that is wrong in a way nobody can see.</li>
                </ul>
                <p>And the check worth building into any tool: after decoding, verify that the FDE ranges are contiguous and non-overlapping across the section. Two FDEs claiming the same address, or a gap between them, means a pointer or a length is wrong &mdash; and it is much easier to catch that than to debug a wrong backtrace.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the CIE says <code>DW_CFA_def_cfa reg=7 offset=8</code> and then an FDE says <code>DW_CFA_def_cfa_offset 16</code>. What has happened to the CFA, and what instruction in the machine code caused it?</p>
                <div class="quiz" id="quiz-dwarf-frames-1">
                    <button class="quiz-option" data-correct="true" data-explain="def_cfa_offset replaces only the offset, keeping register 7, so the CFA becomes rsp + 16. A push is what moves rsp down by 8, so the distance from rsp to the fixed landmark grows by 8. This is the whole reason the CFA exists: it is a landmark that does not move while the frame pointer that measures to it does." onclick="checkQuiz('quiz-dwarf-frames-1', this)">The CFA moved from <code>rsp + 8</code> to <code>rsp + 16</code> because <code>rsp</code> itself dropped by 8. A <code>push</code> did it &mdash; the CFA is a fixed landmark and the stack pointer moves away from it</button>
                    <button class="quiz-option" data-correct="false" data-explain="That would mean the CFA moved without the stack moving, which is not what a def_cfa_offset describes. The offset is measured from the current value of the named register, so if rsp is unchanged the CFA is unchanged - the opcode is how the table stays in step with pushes and pops." onclick="checkQuiz('quiz-dwarf-frames-1', this)">The CFA moved from <code>rsp + 8</code> to <code>rsp + 8</code> but the register changed to 16, so it is now the return address rather than the stack pointer</button>
                    <button class="quiz-option" data-correct="false" data-explain="The opposite direction: a push moves rsp down, away from the CFA, so the distance from rsp to the CFA grows. A pop would shrink the offset back. Reading the sign backwards makes every location expression resolve into the caller frame instead of the current one." onclick="checkQuiz('quiz-dwarf-frames-1', this)">The CFA moved closer to <code>rsp</code>, from 8 bytes above it to 16, because a <code>pop</code> raised the stack pointer by 8</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your unwinder produces a correct backtrace for every function in the binary except one, where it crashes or reports a frame pointer that looks random. The binary has one CIE and eight FDEs. You have read the CIE correctly. What is the most likely cause, and what is the cheapest way to confirm it?</p>
                <div class="quiz" id="quiz-dwarf-frames-2">
                    <button class="quiz-option" data-correct="true" data-explain="The reference build has five functions and eight FDEs, with one function's information split across three adjacent FDEs. An unwinder that takes the first FDE matching a function's low_pc and applies its rules across the whole function is applying the wrong rules past the first boundary - and where a def_cfa_expression takes over, that produces a CFA with no relation to the real stack. Confirm it by listing the FDE ranges and checking which one contains the failing pc." onclick="checkQuiz('quiz-dwarf-frames-2', this)">That function&rsquo;s unwind information is split across several FDEs, and the unwinder is applying the first one&rsquo;s rules over the whole function. Confirm it by listing the FDE ranges and checking which one actually contains the failing program counter</button>
                    <button class="quiz-option" data-correct="false" data-explain="A single wrong CIE would corrupt every frame in the process, not one function, and the CIE here is known good. The failure being local to one function points at the FDE for that function, not at the shared rules every other frame already uses successfully." onclick="checkQuiz('quiz-dwarf-frames-2', this)">The CIE is being misparsed, so the alignment factors are wrong. Confirm it by checking that <code>data_alignment_factor</code> is -8 and that saved-register offsets come out negative</button>
                    <button class="quiz-option" data-correct="false" data-explain="A def_cfa_expression replaces only the CFA rule for the ranges where it applies; the initial def_cfa rules still hold everywhere else in the FDE, and the other seven FDEs in this binary use nothing but the simple form. It is worth decoding, but it cannot by itself explain a failure confined to one function." onclick="checkQuiz('quiz-dwarf-frames-2', this)">The failing function uses a <code>DW_CFA_def_cfa_expression</code> and the unwinder only handles register-plus-offset. Confirm it by checking whether that function&rsquo;s FDE contains the twelve-byte expression</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a failure that is local to one input is almost never a bug in the shared table. When a format gives you one common record and many per-input records, suspect the per-input ones first &mdash; and check the assumption you made about how many there should be.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Frame information is the other half of the <a href="/courses/pe/lessons/pe-exceptions">PE exception handling</a> story: <code>.pdata</code> entries, the <code>IMAGE_SCN_CNT_CODE</code> sections, and the <code>.xdata</code> unwind table you decoded byte-exactly in the <a href="/courses/coff/lessons/coff-relocations">COFF relocations concept</a> are the Windows mechanism for the same job. The COFF course's <code>ADDR32NB</code> relocations pointed at <code>.pdata</code> and <code>.xdata</code> for exactly this reason: data that references code has to survive the image being placed.</p>
                <p>Register-save rules and the <a href="/courses/pe/lessons/pe-security-flags">NX and DEP story in the PE course</a> are two answers to the same question &mdash; what may execute and what may be written. The COFF course's <a href="/courses/coff/lessons/coff-characteristics">section characteristics</a> decide it at the section level; the CFI decides it per instruction range, which is finer and is why a function that builds its own stack frame needs more rules.</p>
                <p>The CFI table is also the cleanest example in either course of <strong>describe the delta, not the state</strong> &mdash; the same principle as a <a href="/courses/coff/lessons/coff-relocations">REL32 relocation</a> storing a displacement, or a <a href="/courses/dwarf/lessons/dwarf-address-to-line">line program</a> storing advances. One more mechanism, then: what happens when the tree gets too big to ship in one file.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-split">Split DWARF</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-locations">Previous: Location Expressions</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-split">Next: Split DWARF</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
