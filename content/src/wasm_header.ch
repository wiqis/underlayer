// WebAssembly Course — Module 1: The Container
// Concept: the eight-byte header — the only fixed-width integers in the framing,
// and what a file that fails them tells you.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Eight-Byte Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>The Eight-Byte Header</h1>
            <div class="lesson-meta">17 min &middot; Module 1: The Container &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Eight bytes is not much, and that is the point. Before a WebAssembly runtime will do anything at all &mdash; before it reads a type, allocates a memory, or looks for a single instruction &mdash; it checks eight bytes, and those eight bytes have one job: to establish that the rest of the file is worth parsing.</p>
                <p>That sounds trivial, and it would be in most formats. But consider what a runtime is being asked to do. It is being handed bytes from somewhere untrusted and asked to allocate memory, compile code, and run it. The header is the cheapest possible gate, and it is deliberately designed to fail on the wrong input with the least possible work.</p>
                <p>There is also something specific about these eight bytes that is easy to miss on a first reading, and it is the reason this concept exists at all. <strong>They are the only fixed-width integers in the entire container framing.</strong> The next concept covers the variable-width encoding that governs everything after them, and the contrast between the two is not a curiosity &mdash; it tells you which fields a runtime checks before it trusts anything, and it is the reason a WebAssembly file can be rejected without a single allocation.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The whole header, from a module that does nothing:</p>
                <div class="hex-dump">
                    <pre>00 61 73 6d 01 00 00 00
|  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  +-- 0x00
|  |  |  |  |  |  |  +----- 0x00
|  |  |  |  |  |  +-------- 0x00
|  |  |  |  |  +----------- 0x01
|  |  |  |  +-------------- 'm'  = 0x6d
|  |  |  +-----------------'s'  = 0x73
|  |  +--------------------'a'  = 0x61
|  +----------------------0x00
+------------------------- byte 0
</pre>
                </div>
                <p>Two fields, four bytes each, both fixed-width:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Field</th><th scope="col">Value</th><th scope="col">Encoding</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td><code>magic</code></td><td><code>00 61 73 6d</code></td><td>four raw bytes, compared one at a time</td></tr>
                        <tr><td>4</td><td><code>version</code></td><td><code>01 00 00 00</code></td><td><strong>four bytes, little-endian, interpreted as a number</strong></td></tr>
                    </tbody>
                </table>
                <p>And there is the detail. The magic is four bytes compared individually. <strong>The version is four bytes interpreted as a little-endian 32-bit integer</strong>, which is why <code>01</code> comes first and the three zeroes follow. A reader that compares the version as four separate bytes would be checking for the literal byte sequence <code>01 00 00 00</code> rather than for the number 1, and would reject a hypothetical future version 256, whose encoding is <code>00 01 00 00</code>.</p>
                <p>That is not a hypothetical distinction being made for its own sake. It is the difference between a format that can be extended with new versions and one that cannot, and it was decided in eight bytes. <strong>The version field is a number, not a pattern, precisely so that a later version is a later number</strong> rather than a different byte arrangement.</p>
                <h3>Why the magic starts with a zero byte</h3>
                <p><code>00 61 73 6d</code> is a NUL followed by the three ASCII letters <code>asm</code>. The format is named by its own first four bytes, and the fourth byte is there to stop that reading from working.</p>
                <p>Without the leading NUL, a file starting <code>asm</code> would be plausible as text, and the tools that sniff files by content &mdash; <code>file</code>, an editor, a browser deciding how to display a download &mdash; would have no reliable signal. With it, the first byte is <code>0x00</code>, which is not a legal start for any of them. The three letters are for humans and for hex dumps; the NUL is for the machines. Both halves of the field are doing work, and they are doing different work.</p>
                <div class="hex-dump">
                    <pre>$ xxd minimal.wasm
00000000: 0061 736d 0100 0000                      .asm....

$ file minimal.wasm
minimal.wasm: WebAssembly (wasm) binary module version 0x1 (MVP)
</pre>
                </div>
                <p>That ASCII gutter is worth a second look. <code>xxd</code> prints every unprintable byte as a dot, so the four magic bytes come out as <code>.asm</code> and the four version bytes as <code>....</code>. The format's own name is visible in a standard hex dump with no tooling, which is a small courtesy with a real payoff: a person looking at an unknown file in a hex editor sees <code>.asm</code> at offset zero and knows immediately what they are looking at.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>What each tool does when the header is wrong</h3>
                <p>Take a valid module and corrupt one byte at a time, then see how the three readers respond. This is the cheapest possible test of a runtime's gate, and it is worth doing by hand before writing one.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Corruption</th><th scope="col"><code>wasm-validate</code></th><th scope="col"><code>llvm-objdump</code></th><th scope="col"><code>wasm-objdump</code></th></tr>
                    </thead>
                    <tbody>
                        <tr><td>byte 1 of the magic changed</td><td>rejects</td><td>rejects, no sections printed</td><td>rejects</td></tr>
                        <tr><td>the version set to 2</td><td>rejects</td><td>rejects</td><td>rejects</td></tr>
                        <tr><td>version bytes reordered to <code>00 00 00 01</code></td><td colspan="3">the same rejection &mdash; it is the number 16777216, not 1</td></tr>
                        <tr><td>a section's length byte changed</td><td>rejects with an offset</td><td>rejects, no sections printed</td><td>prints a wrong table</td></tr>
                    </tbody>
                </table>
                <p>The last row is the one to notice, because it is a difference of <em>kind</em> rather than degree. On a file with a bad length, the validator names the offset and the rule; LLVM prints nothing, because it declines to print a structure it cannot trust; and <code>wasm-objdump</code> prints a section table anyway, which is wrong and which it presents without complaint.</p>
                <p>None of that is a bug. Each tool is answering a different question. The validator answers "is this file usable", LLVM answers "can I make sense of this file", and the disassembler answers "what is in this file". Only the first of those has a use for a header check at all, and the header exists because of it.</p>
                <h3>The gate, and why eight bytes is enough</h3>
                <p>Put the header in the context of what a runtime does with an untrusted module, because the order of operations is the design:</p>
                <div class="formula">
1. read 8 bytes
       if fewer than 8 are available:   reject
       if the magic is wrong:            reject
       if the version is not one this
          runtime understands:           reject
   -- nothing has been allocated. No memory, no table,
      no code, no parsing of any kind.

2. walk the section table using only the length fields
       every section declares its own size
       a section that cannot be skipped cleanly is a reject
   -- still nothing has been allocated. Only lengths read.

3. validate the whole module
       types, arities, indices in range, memory sizes legal,
       every branch target lands on an instruction boundary
   -- this is the expensive step, and it is where the
      format's value is actually spent

4. only now: allocate and compile or interpret
</div>
                <p>Two properties of that sequence are the point of the format's design. <strong>The header and the section walk both happen before any allocation</strong>, because both need only the length fields, and a length field cannot cause an allocation. And <strong>step 3 is a whole pass over the module that proves properties without executing anything</strong> &mdash; that every index is in range, that every function body has the arity its type claims, that no memory limit exceeds what the runtime permits, that no branch lands mid-instruction.</p>
                <p>That is what makes WebAssembly safe to compile ahead of time and ship to a machine you do not control. A JIT does not need to be careful about what it is handed, because the module was validated before it arrived &mdash; and the validator is a piece of code whose only job is to say no. <strong>The eight-byte header is the first line of that, and it is the cheapest.</strong></p>
                <h3>The two places the format does not use LEB128</h3>
                <p>And here is the observation the concept is built around, stated as a count. In the container framing of a WebAssembly module, exactly two integers are fixed-width:</p>
                <ul>
                    <li><strong>The four magic bytes.</strong> Not an integer at all &mdash; four bytes compared individually. Fixed by construction.</li>
                    <li><strong>The four version bytes.</strong> A 32-bit little-endian number. Fixed by construction.</li>
                </ul>
                <p>Everything else in the framing is a LEB128: every section length, every name length, every entry count, every index, every limit. The next concept covers that encoding, and the useful thing to carry into it is <strong>why these two are exceptions.</strong></p>
                <p>The answer is that they are the fields a reader must trust before it can trust anything else, and a fixed-width field can be checked with a single memory comparison. A LEB128 of unknown length would require a loop, and a loop on untrusted input before validation is exactly what you do not want to write. <strong>The two places the format is most conservative about width are the two places it is least able to afford to guess.</strong></p>
                <p>There is a pleasant symmetry in that, and it is the reason the concept ends where it does. The header is the part of the format that has to be readable by a reader who knows nothing, so it is the part that uses the simplest possible encoding. The body is the part that a reader may have read the header first, so it can afford the compact variable-width form and use the saved bytes for something. <strong>Every binary format makes this trade somewhere, and knowing where a format is most conservative tells you where its designers were most worried.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Writing the gate, which is the part of a runtime that must be right before anything else can be. Eight bytes, four checks, and the reasoning about what each one buys:</p>
                <div class="formula">
def looks_like_a_module(header):
    if len(header) &lt; 8:
        return False            # too short to be anything

    if header[0:4] != b'\x00asm':
        return False            # not ours; do not try to parse further

    version = int.from_bytes(header[4:8], 'little')
    if version not in SUPPORTED_VERSIONS:
        return False            # a module we cannot correctly interpret

    return True
</div>
                <p>Each check is a different kind of rejection, and the third is the one that is easy to get wrong. <strong>Rejecting an unknown version is not the same as rejecting a bad magic</strong>, and conflating them produces a runtime that either refuses future modules forever or attempts modules it cannot read. The version check is a statement about this runtime's capabilities: "I understand these versions and no others", which is a legitimate and conservative position.</p>
                <p>What the gate must not do is <strong>interpret anything</strong>. Note that nothing above looks at a section, a type, or an instruction. That is deliberate and it is the performance argument as much as the safety one: a file that begins with the right eight bytes but is otherwise nonsense has still cost a runtime eight bytes of work to begin with, whereas a file that begins wrongly is dismissed in a single comparison. And since the overwhelmingly common case for a wrong file is "not a WebAssembly module at all" &mdash; a mislabelled download, a text file, another binary format &mdash; the magic check is the one that fires nearly every time.</p>
                <p>Now the harder question, which is what to do about the third check. There are three reasonable positions, and the choice is a product decision rather than a technical one:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Policy</th><th scope="col">Behaviour on an unknown version</th><th scope="col">Cost</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Strict</td><td>reject</td><td>A module valid everywhere else will not load here, including modules produced by a newer toolchain for a newer feature you do not need</td></tr>
                        <tr><td>Permissive</td><td>attempt to parse, trusting the length fields</td><td>You may misinterpret a construct whose meaning changed, which is worse than failing</td></tr>
                        <tr><td>Capability-based</td><td>parse the section table, and reject only if a section kind is present that you do not understand</td><td>More work up front, and a design that has to be right about what "understand" means</td></tr>
                    </tbody>
                </table>
                <p>The third is the interesting one, and it is where the custom section earns its keep. A custom section can be skipped by a reader that has no idea what is in it, so <strong>a file containing only custom sections this runtime has never heard of is still perfectly loadable</strong> &mdash; which is what makes it safe for a toolchain to attach provenance and target-feature metadata without coordinating with runtimes. The strict policy rejects such a file at the version check only if the version changed; the capability-based policy accepts it, because it never looks inside a section it does not recognise.</p>
                <p>Which is the real answer to a question this course keeps returning to. The format's extensibility is not achieved by making the version number optional. It is achieved by having a section kind that means "here are some bytes, ignore them", and a framing that lets a reader skip it. The eight-byte header is what tells a reader which interpretation to use; the custom section is what lets the interpretation stay the same while the content changes.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ printf '\x00asm\x01\x00\x00\x00' &gt; raw.wasm
$ xxd raw.wasm
$ wasm-validate raw.wasm
$ printf '\x00asm\x02\x00\x00\x00' &gt; v2.wasm &amp;&amp; wasm-validate v2.wasm
$ printf '\x00asm\x00\x00\x00\x01' &gt; end.wasm &amp;&amp; wasm-validate end.wasm</code></pre>
                <ul>
                    <li><strong>Write the eight bytes with <code>printf</code>.</strong> The escape sequences make the two fields visible in the command itself, which is the fastest way to internalise that the magic is bytes and the version is a number. Then build the same file with <code>wat2wasm</code> from an empty module and confirm they are byte-identical &mdash; the hand-written version and the tool's version, agreeing with no shared code.</li>
                    <li><strong>Test the version as a number, not a pattern.</strong> The decisive experiment is the reordered version: <code>00 00 00 01</code>. A reader comparing four bytes against <code>01 00 00 00</code> rejects it; a reader computing a 32-bit little-endian integer gets 16777216 and also rejects it &mdash; but for the right reason, and it would behave correctly on a future version 256 whose encoding is also <code>00 01 00 00</code>. <strong>Build both and check which implementation gives which message.</strong></li>
                    <li><strong>Corrupt the NUL and see what changes.</strong> The first byte is the only thing distinguishing this format from a text file beginning with the letters <code>asm</code>. Remove it and run <code>file</code> and <code>xxd</code> on the result. Then try the file through a text-oriented tool and notice how much more willing everything is to try to interpret it. <strong>One byte is the entire difference between "binary" and "maybe text",</strong> and that is a design decision someone made on purpose.</li>
                    <li><strong>Implement the gate and test it against the tools.</strong> Write the function above in your language, then run it over a dozen files: valid modules, the empty module, a truncated file, a file with a bad magic, versions 1 and 2, and an ELF binary. Compare your verdicts with <code>wasm-validate</code>'s. Where they differ, find out which is right &mdash; and the version policies will differ legitimately, which is itself worth seeing.</li>
                    <li><strong>Count the fixed-width fields in a real module.</strong> Take <code>externs.o</code> and identify every integer in it that is not a LEB128. This course's claim is that there are exactly two, both in the header. Verify it, because a counterexample would mean the claim needs qualifying and it is much better to find that out here than in someone else's reader.</li>
                    <li><strong>Test what the gate does not catch.</strong> Append a valid custom section full of nonsense to a valid module. The gate passes, the section walk skips it, and the module runs. Confirm all three steps, and then confirm that a <em>standard</em> section full of nonsense is caught by validation and not by the header. <strong>Separating "is this the right format" from "is this a legal module" is the distinction this whole format is built on, and the header is the first half of it.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a runtime is given the eight bytes <code>00 61 73 6d 00 00 00 01</code>. The magic is correct. As a four-byte comparison against the known version it does not match. As a 32-bit little-endian integer the version field is 16777216. Has this file got a valid header, and what does the answer depend on?</p>
                <div class="quiz" id="quiz-wasm-header-1">
                    <button class="quiz-option" data-correct="true" data-explain="Both readings agree on the verdict and disagree on the reasoning, and that is what makes the question worth asking. As bytes, 00 00 00 01 is not the sequence 01 00 00 00, so a pattern-matching reader rejects it as an unrecognised version. As a number, the field is 16777216, so a numeric reader rejects it as an unsupported version. The file is rejected either way, but the two rejections mean different things: one says I have never seen this encoding, the other says I have seen this number and cannot handle it. That distinction is what lets a format add versions, because a future version 256 encodes as 00 01 00 00, a pattern that no version-1 reader has ever seen and a number a numeric reader can compare against its supported set. The general habit is to ask whether a field is a value or a shape, because the answer determines whether it can be extended." onclick="checkQuiz('quiz-wasm-header-1', this)">No. The magic is correct, so the file is a WebAssembly file; the version is 16777216, which no runtime supports, so it is rejected as an unsupported version. The byte-comparison reader rejects it too, but for a different reason &mdash; an unrecognised encoding rather than an unrecognised number</button>
                    <button class="quiz-option" data-correct="false" data-explain="This inverts which reading is the correct one. The version field is specified as a four-byte little-endian number, which is why the value 1 is encoded 01 00 00 00 with the significant byte first. A reader that compares the byte sequence would be checking for a pattern rather than a value, and would be unable to distinguish version 1 from any future version whose encoding happened to be 00 00 00 01. The file is still rejected, so the verdict is right, but the reasoning is the thing the question is about." onclick="checkQuiz('quiz-wasm-header-1', this)">No, because the version bytes do not match the known pattern 01 00 00 00, and a reader is required to compare the version as four fixed bytes rather than as a number</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are building a service that accepts uploaded <code>.wasm</code> modules, validates them, and stores them. Users are on a mix of toolchains, and about one in twenty uploads is rejected by your validator with a version error. The file is a valid module produced by a real toolchain &mdash; you can confirm that by opening it in a browser, where it runs. What are the plausible explanations, and what is the cheapest way to tell which one you are looking at?</p>
                <div class="quiz" id="quiz-wasm-header-2">
                    <button class="quiz-option" data-correct="true" data-explain="The observation that narrows it: the file runs in a browser but your validator rejects it, so the bytes are legal and the disagreement is about what your validator is willing to accept. That points at your version policy rather than at the file, and the cheapest check is a hex dump of the first eight bytes, which distinguishes the cases immediately. A newer major version shows 02 in the first version byte; a byte-reversed encoding shows the significant byte last; a truncated or non-module upload fails the magic instead. Each has a different remedy and none of them can be diagnosed from the validator's message, which is the general point: a gate that reports only accept or reject has thrown away the one piece of information that would tell you which check failed. The habit to build is to log the parsed version and the reason for rejection separately, because the second is what lets you tell a user what to do about the first. And the deeper design point is that a version policy is a product decision, not a technical fact &mdash; rejecting a module that runs everywhere else is a choice, and it should be made deliberately rather than inherited from whichever comparison you happened to write." onclick="checkQuiz('quiz-wasm-header-2', this)">Read the first eight bytes with <code>xxd</code> and check the version encoding. If the significant byte is last, a reader is comparing a pattern instead of a number; if the version is 2, your validator's supported set is stale; if the magic is wrong, the upload is not a module at all. One command separates all three</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth knowing and worth logging, but it does not explain a version error. Custom sections are skippable by a reader that does not understand them, and the module runs in a browser, which proves the standard sections are legal. If a custom section were the problem the failure would be a structural one, not a version rejection, and the eight-byte dump would show a correct magic and a supported version. This is the explanation to reach for after the cheap check has ruled the obvious ones out." onclick="checkQuiz('quiz-wasm-header-2', this)">The modules contain a custom section from a toolchain newer than yours, and your validator rejects unknown section kinds</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a gate rejects something that works elsewhere, dump the bytes the gate looked at. The gate's verdict is one bit and the reason is the information; a gate that logs only the bit has thrown away the useful part.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The header is the smallest possible version of a problem every format in this collection solves at a larger scale, and comparing the four is the fastest way to place WebAssembly in the space. <a href="/courses/elf/lessons/elf-header-fields">ELF</a> opens with <code>7f 45 4c 46</code> &mdash; four bytes, also a magic, also unmissable in a hex dump &mdash; but is followed by a <em>class</em> byte, a data encoding byte, a version, and then a header size that varies. <a href="/courses/pe/lessons/pe-dos-header">PE</a> opens with <code>4d 5a</code> and then a 64-byte DOS header of largely historical interest before the real header. <a href="/courses/coff/lessons/coff-file-header">COFF</a> has no magic at all, which is a real problem it solves by checking the machine field's plausibility instead.</p>
                <p>WebAssembly's eight bytes are the compressed answer to all of that, and the compression is only possible because there is almost nothing to describe. A module has no machine type, because it is not for a machine. It has no data encoding, because the format defines its own. It has no class, because there is only one kind of thing. <strong>Remove everything that can be inferred and the header collapses to a magic and a version</strong> &mdash; and a file format that can be identified in one comparison is a file format that a runtime can reject before it allocates anything.</p>
                <p>The next concept is the one that explains why those eight bytes are unusual in a second way, and it is worth holding the contrast in mind while you read it: <a href="/courses/wasm/lessons/wasm-leb128">LEB128</a> governs every number in the format except these eight bytes' worth. The header's conservatism and the body's compactness are the same design decision seen from two ends.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-sections">Sections</a> &mdash; what comes after the header, and a place where two reference tools report different numbers for the same bytes.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-intro">Previous: Why a Binary Format</a></span>
                <span><a href="/courses/wasm/lessons/wasm-sections">Next: Sections</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
