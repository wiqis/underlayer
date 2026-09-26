// DWARF Course — Module 5: The Format on Other Inputs
// Concept: .debug_frame — the unwind section that is not .eh_frame, decoded from
// a real object, and the one field where the two disagree.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_frame() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Other Unwind Section — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The Other Unwind Section</h1>
            <div class="lesson-meta">21 min &middot; Module 5: The Format on Other Inputs &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/dwarf/lessons/dwarf-frames">The frames concept</a> decoded unwind information out of <code>.eh_frame</code>, and every claim in it was checked against that section. So a reader built from that concept has a working CFI decoder that silently assumes a <code>.eh_frame</code> layout &mdash; and <code>.debug_frame</code> is not that layout.</p>
                <p>Both sections describe the same thing. Both hold CIEs and FDEs, both use the same <code>DW_CFA_*</code> opcodes, and both answer the question the frames concept set up: at this program counter, where is the canonical frame address and where did each register get saved. Almost everything you learned transfers. And that is precisely the problem, because the differences are in the fields that come <em>first</em> &mdash; the ones a decoder reads before it has read anything it could sanity-check against.</p>
                <p>So this concept decodes <code>.debug_frame</code> from a real object, field by field, and puts the two headers side by side. The payoff is not that the section is complicated. It is that one field differs in a way that produces a number, and a plausible number, and the wrong number.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Ask gcc for one section or the other, and you get exactly one of the pair:</p>
                <pre><code>$ gcc -g -O0 -c t.c -o plain.o
$ readelf -S -W plain.o | grep -oE '\.eh_frame|\.debug_frame'
.eh_frame

$ gcc -g -O0 -fno-asynchronous-unwind-tables -c t.c -o frame.o
$ readelf -S -W frame.o | grep -oE '\.eh_frame|\.debug_frame'
.debug_frame</code></pre>
                <p>One flag, and the section is replaced rather than supplemented. That is the design: they are alternative homes for the same records, chosen by the producer, and a consumer must handle both because a binary may have been produced either way.</p>
                <p>Why a producer would choose one over the other is not a compiler preference so much as a historical accident that hardened. <code>.eh_frame</code> is designed to be <strong>loadable at runtime without any debug information present</strong> &mdash; it is how an exception propagator walks a stack on a machine that has never heard of DWARF, and it is why its records are position-relative so the section can be mapped anywhere. <code>.debug_frame</code> is the older, simpler arrangement kept for the debug-info case, where absolute addressing is fine because the section is read by a tool that also has the symbol table. Both are specified; they are not interchangeable.</p>
                <div class="callout">
                    <strong>One more difference worth knowing before you read the bytes.</strong> An FDE's <code>pc_begin</code> and <code>address_range</code> are relative to the start of the text section in <em>both</em> sections. So neither of them contains a real address in a relocatable object, and both are zero-patched by relocations. That is a fact about how the FDE is anchored, not about the CIE pointer, and it is worth separating the two so you do not attribute the wrong cause to the right symptom.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The whole section, 144 bytes</h3>
                <div class="hex-dump">
                    <pre>0000: 14 00 00 00 ff ff ff ff 01 00 01 78 10 0c 07 08
0010: 90 01 00 00 00 00 00 00 24 00 00 00 00 00 00 00
0020: 00 00 00 00 00 00 00 00 2a 00 00 00 00 00 00 00
0030: 45 0e 10 86 02 43 0d 06 61 0c 07 08 00 00 00 00
0040: 24 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
0050: 50 00 00 00 00 00 00 00 45 0e 10 86 02 43 0d 06
</pre>
                </div>
                <p>Two records. Read the first one completely, because it is a CIE and every field in it is either identical to <code>.eh_frame</code> or worth pausing on.</p>
                <h3>The CIE at offset 0</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>14 00 00 00</code></td><td><code>length</code></td><td>20, so the record occupies 24 bytes</td></tr>
                        <tr><td><code>ff ff ff ff</code></td><td><code>CIE_id</code></td><td><code>-1</code> &mdash; <strong>this is what marks a CIE</strong></td></tr>
                        <tr><td><code>01</code></td><td><code>version</code></td><td>1</td></tr>
                        <tr><td><code>00</code></td><td><code>augmentation</code></td><td>empty, a NUL-terminated string</td></tr>
                        <tr><td><code>01</code></td><td><code>code_alignment_factor</code></td><td>ULEB 1</td></tr>
                        <tr><td><code>78</code></td><td><code>data_alignment_factor</code></td><td>SLEB &minus;8</td></tr>
                        <tr><td><code>10</code></td><td><code>return_address_register</code></td><td>16, which is <code>rip</code></td></tr>
                        <tr><td><code>0c</code></td><td>initial instruction length</td><td>ULEB 12</td></tr>
                        <tr><td><code>07 08 90 01 ...</code></td><td>12 bytes of instructions</td><td>two rules and six <code>nop</code>s</td></tr>
                    </tbody>
                </table>
                <p>Check the arithmetic: 4 for the length field, plus 20 counted by it &mdash; 4 of <code>CIE_id</code>, 1 version, 1 augmentation, 1 code alignment, 1 data alignment, 1 return-address register, 1 instruction length, 12 instructions &mdash; gives 24 bytes, so the next record starts at <code>0x18</code>. It does.</p>
                <p>The twelve instruction bytes decode exactly as the frames concept taught, and it is worth confirming rather than assuming:</p>
                <div class="hex-dump">
                    <pre>07        DW_CFA_def_cfa
08        ULEB 8
          "the CFA is register 7 (rsp) plus 8"

90        DW_CFA_offset
01        ULEB 1
          "the return address register 16 was saved at
           CFA + (1 * -8), i.e. CFA - 8"

00 00 00 00 00 00
          six DW_CFA_nops -- padding to a 4-byte boundary
</pre>
                </div>
                <p>Those six <code>nop</code>s are not decoration. They are how the record is aligned to four bytes without the reader needing to know the record's length in advance, and they are why a naive "keep consuming opcodes until something looks wrong" parser is wrong: a <code>0x00</code> in an instruction stream is <code>DW_CFA_nop</code>, not an end marker. The <em>length</em> field is the end marker.</p>
                <h3>The CIE marker, which is the difference that matters</h3>
                <p>Compare the first eight bytes of a CIE in each section:</p>
                <div class="hex-dump">
                    <pre>.debug_frame CIE:  14 00 00 00  ff ff ff ff   CIE_id = -1
.eh_frame  CIE:  10 00 00 00  00 00 00 00   CIE_id =  0
</pre>
                </div>
                <p>Both are four bytes that mean "this record is a CIE", and they are different numbers because the two sections came from different specifications with different conventions. A reader that checks <code>CIE_id == 0</code> will classify every <code>.debug_frame</code> CIE as an FDE, and then try to read a CIE's instruction bytes as an FDE's initial location and address range. Those are the same bytes read with a different structure in mind, and the result is a plausible address range of eight bytes of instructions.</p>
                <h3>The FDE at offset 0x18, and the field the whole concept is about</h3>
                <div class="hex-dump">
                    <pre>0018: 24 00 00 00   length = 36
001c: 00 00 00 00   CIE_pointer = 0        &lt;-- ABSOLUTE
0020: 00 00 00 00 00 00 00 00   pc_begin   = 0
0028: 2a 00 00 00 00 00 00 00   range      = 0x2a = 42
0030: 45 0e 10 86 02 43 0d 06 61   10 bytes of instructions
003a: 0c 07 08 ...
</pre>
                </div>
                <p>Three fields, and the third is the one to notice. <code>pc_begin</code> is 0 and <code>range</code> is 42 &mdash; both relative to the text section's start, and both zero-patched by relocations in this object file, which is why the range is a plausible-looking 42 rather than a real address. <code>readelf</code> agrees on all of it:</p>
                <pre><code>00000018 0000000000000024 00000000 FDE cie=00000000 pc=0..2a</code></pre>
                <p>But look at that middle field again: <strong><code>CIE_pointer = 0</code>, and the CIE is at offset 0, so it is correct &mdash; and it is correct <em>by accident of this example</em>, because the CIE happens to be the first record.</strong> In <code>.eh_frame</code> that same field is a <strong>pc-relative</strong> displacement: you add the field's own address to its value to find the CIE. In <code>.debug_frame</code> it is an <strong>absolute section offset</strong>, used as-is.</p>
                <p>So here is the trap, and it is a good one because this file is the one case where the two readings agree. Take an FDE at offset <code>0x30</code> instead. Its <code>CIE_pointer</code> field would read <code>0</code> again, meaning CIE at section offset 0. A <code>.eh_frame</code> reader computes <code>0x30 + 4 + 0 = 0x34</code> and walks off into the middle of the FDE's own instructions, then interprets whatever it finds there as a CIE. It will not report an error, because the bytes it lands on are valid instruction bytes.</p>
                <div class="callout callout-warn">
                    <strong>The general rule, and it is worth more than this example.</strong> <code>.eh_frame</code> is designed to be mapped at an unknown address, so every internal reference in it is relative to something. <code>.debug_frame</code> is read by a tool that also has the symbol table, so its references are plain offsets into the section. <strong>Both fields occupy the same four bytes and mean different things.</strong> A reader that does not branch on which section it is reading will be right on one of them and silently wrong on the other, and the "wrong" is a number that passes every range check you are likely to write.
                </div>
                <p>One consequence worth stating, because it changes how you validate: in <code>.eh_frame</code>, a correct reader has a self-check available. The <code>CIE_pointer</code> must resolve to a record whose <code>CIE_id</code> is the CIE marker, and a pcrel computation that has gone wrong will almost never land on a record that passes. In <code>.debug_frame</code> the same check exists but is weaker, because the value is used unmodified and a stale or wrong offset is just as likely to land on a plausible record. If you write a reader for <code>.debug_frame</code>, check that the target record is a CIE <em>and</em> that its <code>version</code> byte is sane, and do not treat "it pointed somewhere" as success.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Unwinding one frame, in both sections, to show exactly where the two paths diverge. The state is the same: program counter inside the function, and a caller frame to reconstruct.</p>
                <div class="formula">
locate the FDE covering the program counter
    (pc_begin and address_range are section-relative in BOTH
     sections, so this step is identical)

read its CIE reference
    .eh_frame   :  cie = address_of_this_field + *this_field
                   then check the target's CIE_id is the CIE marker
    .debug_frame:  cie = *this_field
                   used as a section offset, unmodified

read the CIE
    augmentation string, code_alignment_factor, data_alignment_factor,
    return_address_register, and the initial instructions
    -- all identical in both sections

apply the initial instructions, then the FDE's instructions,
    as a program counter advances:
    DW_CFA_def_cfa  reg, off     -> CFA = regs[reg] + off
    DW_CFA_offset   reg, factored-> saved at CFA + factored * data_align
    ...

fetch the return address from where the CIE said it was saved
fetch the caller's CFA
    identical from here on
</div>
                <p>So the divergence is one line, and it is the third from the top. Everything after it is shared code, which is why a single decoder handles both sections so easily and why getting that one line wrong is so easy to miss &mdash; the rest of the pipeline works, and produces a number.</p>
                <p>It is also worth being concrete about what goes wrong when that line is wrong, because "a wrong address" is too vague to recognise. Suppose the reader takes a <code>.debug_frame</code> FDE and applies the pcrel rule. The computed CIE address is <code>field_address + 0</code>, which is the FDE's own length field &mdash; the first four bytes of the FDE. It then reads a CIE there:</p>
                <ul>
                    <li>The length it gets is the FDE's length. The record looks a plausible size.</li>
                    <li>The <code>CIE_id</code> it gets is the FDE's <code>CIE_pointer</code>, which is <code>0</code> for a first-record-adjacent CIE &mdash; and the pcrel reader's CIE check is "does this equal the CIE marker", which <code>0</code> passes in the <code>.eh_frame</code> convention. <strong>So the check that should have caught it actively ratifies it.</strong></li>
                    <li>The version byte it gets is the low byte of the CIE pointer. For <code>0x00000000</code> that is version 0, which does not exist; a reader that validates the version catches it here, and a reader that does not sails on.</li>
                    <li>The alignment factors it gets are the FDE's <code>pc_begin</code> bytes. So <code>code_alignment_factor</code> becomes a text-section-relative address, and every subsequent <code>advance_loc</code> delta is multiplied by a number in the billions.</li>
</ul>
                <p>The result of all that is a CFA computed from garbage, a return address read from a location derived from garbage, and a backtrace whose frames are plausible addresses in the executable. <strong>Every one of them will be a valid address, which is what makes this failure expensive to diagnose</strong> &mdash; the frame addresses look like real code until you check them against the disassembly and find they are all off by a constant that depends on how far the FDE was from the section start.</p>
                <p>And that last detail is the diagnostic. A wrong CIE reference produces an error that is <em>constant within a function</em> and <em>varies between functions</em>, because the pcrel error depends on the FDE's offset. A tool that reports the same wrong return address for every call site in one function, and a different wrong one in the next, is looking at a reference-resolution bug and not at a data problem. Recognising that pattern is faster than re-reading the opcode table.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -g -O0 -fno-asynchronous-unwind-tables -c t.c -o frame.o
$ readelf --debug-dump=frames frame.o
$ readelf -S -W frame.o | grep -oE '\.eh_frame|\.debug_frame'</code></pre>
                <ul>
                    <li><strong>Count the records yourself.</strong> Walk the 144 bytes using only the length fields, as the concept does, and confirm there are exactly two records. Then confirm your walk lands on the same offsets <code>readelf</code> reports. A record walker that uses the length field is the only kind that works on both sections, and building one is the exercise.</li>
                    <li><strong>Build the case the concept describes.</strong> Find or construct a <code>.debug_frame</code> where the CIE is <em>not</em> at offset 0 &mdash; a second CIE, or an FDE whose CIE is the second one. Then apply the pcrel rule to it and watch the computed address miss. This file is the one case where the bug hides, and building the case that exposes it is worth more than the observation.</li>
                    <li><strong>Force the <code>0x00</code> padding to matter.</strong> Add a function whose initial instructions come to an odd length, so the padding count is not six. Confirm the <code>DW_CFA_nop</code> run still pads to a four-byte boundary and that your parser consumes exactly the declared number of bytes. A parser that stops at the first <code>0x00</code> looks correct on this file and wrong on the next one.</li>
                    <li><strong>Write the section branch.</strong> Extend the decoder shipped with this course to read both sections, keyed on the section name. Then deliberately apply the wrong rule to each and confirm both produce a wrong-but-plausible answer. Having produced the failure yourself is what makes you check for it later.</li>
                    <li><strong>Check whether your platform ever needs this.</strong> Look at what your own system's binaries contain, and look at what a Windows PE contains. If <code>.debug_frame</code> is something you have never encountered, that is worth knowing <em>before</em> you meet it in a customer's core dump rather than after.</li>
                    <li><strong>Compare the augmentation strings.</strong> This CIE has an empty augmentation. <code>.eh_frame</code> CIEs in practice usually carry <code>zR</code> or <code>zPLR</code>, which adds a pointer-encoding byte and personality-routine fields. Decode one of those from a <code>.eh_frame</code> section and note that the <code>.debug_frame</code> CIE above has no room for any of it &mdash; which is a real constraint, not a simplification.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: your decoder reads an FDE from a <code>.debug_frame</code> section. The four bytes after the length field are <code>00 00 00 00</code>, and the section's only CIE is at offset 0. The <code>.eh_frame</code> version of your decoder is being reused, which computes the CIE address as the field's own address plus its value. What does it compute, and what happens next?</p>
                <div class="quiz" id="quiz-dwarf-frame-1">
                    <button class="quiz-option" data-correct="true" data-explain="Both halves of this are the point. The correct reading is the value used directly: 0, which is the CIE at offset 0, and the decode succeeds. The pcrel reading gives field_address plus zero, which is the FDE's own length field. From there the reader takes the FDE's CIE_pointer as a CIE_id, and because that pointer is 0 it satisfies the .eh_frame CIE check, so the check that exists to catch this actively ratifies the mistake. The version byte then reads 0, which does not exist, so a reader that validates the version catches it and one that does not continues into the alignment factors, which come from the FDE's pc_begin and are therefore text-relative addresses. The resulting CFA is computed from garbage while every address it produces is a valid one." onclick="checkQuiz('quiz-dwarf-frame-1', this)">It computes the FDE's own length field as the CIE. The CIE-id check then passes &mdash; because the value there is 0, which is the <code>.eh_frame</code> CIE marker &mdash; so the check ratifies the mistake instead of catching it, and the alignment factors end up being read out of <code>pc_begin</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="The file is the one case where the two readings coincide, and saying otherwise misreads the example. The CIE really is at offset 0, and the pcrel field value is 0, so the computed address is the field's own address rather than the section start. The section is 144 bytes and the FDE starts at 0x18, so the computed address is 0x1c, which is not the CIE. The two readings agree in what they point at, not in how they are computed." onclick="checkQuiz('quiz-dwarf-frame-1', this)">It computes 0, which is the CIE, so the decode succeeds and there is no problem in this particular file</button>
                    <button class="quiz-option" data-correct="false" data-explain="Applying the pcrel rule to a .debug_frame record is exactly the mistake the question describes, and it does not land on the CIE. The correct .debug_frame rule uses the value unmodified. This option describes the correct behaviour while attributing it to the wrong rule, which would teach a reader to use the right answer for the wrong reason &mdash; and the reason is the part that breaks on the next file." onclick="checkQuiz('quiz-dwarf-frame-1', this)">It computes 0, which is the CIE, because <code>.debug_frame</code> also uses a pc-relative CIE reference and the value happens to be zero</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your production unwinder works on your Linux binaries. A customer sends you a core dump from a tool built on a platform that uses <code>.debug_frame</code>, and every frame in the backtrace is wrong &mdash; but the addresses are all valid code addresses, the source lines look plausible, and the innermost frames are consistently off by the same amount within each function while differing between functions. Given this concept, what have you learned, and what is the one-line change that fixes it?</p>
                <div class="quiz" id="quiz-dwarf-frame-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern is the diagnosis. Wrong by a constant within a function and different between functions is the signature of a bad reference resolution rather than bad data, because the pcrel error is a function of each FDE's own offset from the section start. Valid code addresses everywhere means nothing downstream is validating, since a garbage CFA still produces addresses that point into the executable. The fix is one branch on the section name, and it is small precisely because this concept established that everything after the CIE reference is shared code: the record walk, the alignment factors, the opcode loop and the register reconstruction are identical in both sections. The cost of the bug was high and the fix is small, which is the usual shape when a single field carries a convention that is not self-describing." onclick="checkQuiz('quiz-dwarf-frame-2', this)">The CIE reference is being resolved with the <code>.eh_frame</code> pcrel rule, and the error is the FDE's offset, which is constant within a function and different between them. Fix it by keying the reference on the section name: absolute in <code>.debug_frame</code>, pc-relative in <code>.eh_frame</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real possibility and it is the first thing to check, but the specific signature argues against it. If the opcode decoding were wrong, the error would depend on which rules a function's CIE and FDE contain rather than on where the FDE sits, so functions with similar prologues would fail similarly. Being constant within a function and varying between functions points at an address computation, and the only address computation in the header is the CIE reference. There is also no shared section between the two platforms here, so a version difference is not available as an explanation." onclick="checkQuiz('quiz-dwarf-frame-2', this)">The two platforms use different DWARF versions, so your decoder is misreading the header layout and every subsequent offset is wrong</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a wrong answer that is constant within one function and different in the next is a coordinate-system error, not a data error. Whenever a value you computed is derived from another address, ask what would have to be true for the error to have that shape.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the other half of <a href="/courses/dwarf/lessons/dwarf-frames">the frames concept</a>, and the two together are the complete answer to "how does a debugger walk a stack". The connection is not thematic but mechanical: the same twelve CIE bytes in this file and in that one encode the same two rules, and the same <code>DW_CFA_*</code> opcodes drive the same state machine. The lesson to carry away is that a format with two encodings of one idea is a format where <em>the section name is part of the data</em>, and a reader that keys on the section name rather than on the content's shape will handle both.</p>
                <p>That is the third instance of the same structure in this module. <a href="/courses/dwarf/lessons/dwarf-v4">DWARF 4 and 5</a> differ by a header byte; <a href="/courses/dwarf/lessons/dwarf-type-units">type units</a> differ by a section name in one version and a field in the other; and here two sections differ by a reference convention. In every case the discriminating information is a single small value &mdash; a version, a <code>unit_type</code>, a section name &mdash; and in every case skipping it produces a number rather than an error.</p>
                <p>That is the shape of the last concept in this module too. <a href="/courses/dwarf/lessons/dwarf-portability">Portability</a> found a whole section that exists only in newer versions, and <a href="/courses/dwarf/lessons/dwarf-packages">the packages concept</a> found an index whose purpose is to skip work rather than to describe code. Both are cases where the format stores a pointer to knowledge that lives somewhere else, and both fail the same way: not loudly, but by resolving to something plausible.</p>
                <p>That closes the DWARF course's format coverage. What remains in this format is not unwritten for want of effort &mdash; it is enumerated, with reasons, in <code>courses/dwarf/research.md</code>: the indexed list opcodes no configuration on this machine emits, DWARF64, which needs four gigabytes of debug information, and the trailing bytes of <code>.debug_cu_index</code>, which I could not account for and declined to guess at.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-call-sites">Previous: Call Sites</a></span>
                <span><a href="/courses/dwarf">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
