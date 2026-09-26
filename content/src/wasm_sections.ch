// WebAssembly Course — Module 1: The Container
// Concept: the section framing, the fourteen ids, the ordering rule, and a place
// where two reference tools disagree about what a section's size means.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sections — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Sections</h1>
            <div class="lesson-meta">23 min &middot; Module 1: The Container &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>After the eight-byte header, everything in a WebAssembly module is a section, and the framing is identical for all of them. One byte of identifier, one LEB128 length, then that many bytes of content. There is no section header structure, no alignment padding, no per-section flags, and no name for the standard sections beyond the identifier.</p>
                <p>That uniformity is the format's main structural decision, and it is what makes a reader short enough to be trustworthy. A complete section walker is a dozen lines. But the uniformity is also where a subtle ambiguity hides, because the framing says "these <em>n</em> bytes are this section's content" and the two reference tools do not agree on what <em>n</em> means for one kind of section.</p>
                <p>This concept decodes the framing, enumerates the fourteen identifiers, works out the ordering rule, and then looks at that disagreement &mdash; which is not a bug in either tool but a genuine difference in what each one is reporting, and which produces a trap that is invisible unless you go looking for it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three fields per section, and one of them is not what you would guess:</p>
                <div class="formula">
+--------+--------+---------------------------+
| id     | size   | content                   |
| 1 byte | LEB128 | `size` bytes              |
+--------+--------+---------------------------+

id   which of the fourteen standard sections this is, or 0 for "custom"
size how many bytes of content follow, as an UNSIGNED LEB128
content the section's own payload, in a layout the id determines
</div>
                <p>Read a real section, from the hand-written sample in this course, byte by byte. Its header is <code>00 61 73 6d 01 00 00 00</code>, then the Type section begins at offset 8:</p>
                <div class="hex-dump">
                    <pre>0008: 01 0a 01 05 60 01 7f 01 7f 01 60 00 00
      |  |     |  |  |  |  |  |  |  |  |  |  |  |  |
      |  |     |  |  |  |  |  |  |  |  |  |  |  |  +-- 0x00: no children
      |  |     |  |  |  |  |  |  |  |  |  |  |  +----- 0x00: no results
      |  |     |  |  |  |  |  |  |  |  |  |  +-------- 0x60: a function type
      |  |     |  |  |  |  |  |  |  |  |  +---------- 0x01: one result
      |  |     |  |  |  |  |  |  |  |  +------------- 0x7f: i32
      |  |     |  |  |  |  |  |  |  +---------------- 0x01: one parameter
      |  |     |  |  |  |  |  |  +------------------- 0x7f: i32
      |  |     |  |  |  |  |  +---------------------- 0x60: a function type
      |  |     |  |  |  |  +------------------------- 0x01: two types
      |  |     |  |  |  +---------------------------- 0x60: a function type
      |  |     |  |  +------------------------------- 0x05: five entries
      |  |     |  +---------------------------------- 0x0a: TEN bytes of content
      |  +-------------------------------------------- 0x01: section id 1 (Type)
      +----------------------------------------------- content starts at 0x0a
</pre>
                </div>
                <p>Count the content bytes: offsets <code>0x0a</code> through <code>0x13</code> inclusive is exactly ten, and the next section starts at <code>0x14</code>. <strong>The length field is the number of bytes after the length field</strong>, not the distance from the section's start and not the distance to the next section. It excludes the id byte and it excludes the length bytes themselves. Two bytes of framing, then <em>n</em> bytes of content.</p>
                <h3>The fourteen identifiers</h3>
                <p>All fourteen, in the order they must appear. The order is not arbitrary: <strong>it is the order in which a module is conceptually built</strong>, and it is why the format can require it.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Id</th><th scope="col">Name</th><th scope="col">Declares</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td><code>custom</code></td><td>anything at all; not interpreted by the format</td></tr>
                        <tr><td>1</td><td><code>type</code></td><td>function signatures</td></tr>
                        <tr><td>2</td><td><code>import</code></td><td>functions, tables, memories, globals this module needs from outside</td></tr>
                        <tr><td>3</td><td><code>function</code></td><td>which signature each locally-defined function has</td></tr>
                        <tr><td>4</td><td><code>table</code></td><td>indirection tables</td></tr>
                        <tr><td>5</td><td><code>memory</code></td><td>linear memories</td></tr>
                        <tr><td>6</td><td><code>global</code></td><td>module-level variables</td></tr>
                        <tr><td>7</td><td><code>export</code></td><td>what this module offers to the outside</td></tr>
                        <tr><td>8</td><td><code>start</code></td><td>the function to run at instantiation</td></tr>
                        <tr><td>9</td><td><code>element</code></td><td>initial table contents</td></tr>
                        <tr><td>10</td><td><code>code</code></td><td>function bodies</td></tr>
                        <tr><td>11</td><td><code>data</code></td><td>initial memory contents</td></tr>
                        <tr><td>12</td><td><code>datacount</code></td><td>how many data segments there will be</td></tr>
                        <tr><td>13</td><td><code>tag</code></td><td>exception-handling tags</td></tr>
                    </tbody>
                </table>
                <p>Read the order and the design becomes visible. Types come first because everything else refers to them. Imports come next because <em>imported</em> things occupy index space before locally-defined ones. The function section declares signatures without bodies, and the code section supplies bodies &mdash; split in two so that a function's type is known before its body is parsed. Tables, memories and globals are all <em>declarations of space</em>; the export and start sections are <em>how the host will interact</em>; and element and data are the <em>contents</em> of that space, which is why they come after the space exists.</p>
                <p>And <code>datacount</code> is at 12, after <code>data</code> at 11, which looks wrong until you know why it exists: it is a forward declaration so that <code>memory.init</code> and <code>data.drop</code> can refer to a data segment by index <em>inside a function body</em>, and a function body is in section 10, before the data it refers to is declared in section 11. The count has to be known early, so it gets its own section placed before the code. <strong>A section order is a dependency order, and reading the order tells you the dependency graph.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The ordering rule, and how it fails</h3>
                <p>The rule: <strong>non-custom sections must appear in increasing identifier order, and each may appear at most once.</strong> Custom sections, id 0, may appear anywhere, any number of times, including between any two standard sections.</p>
                <p>Here is the rule being broken, by duplicating the Type section of the hand-written sample and appending a copy at the end:</p>
                <pre><code>$ wasm-validate dup.wasm
  0000063: error: multiple Type sections

$ llvm-objdump -h dup.wasm
llvm-objdump: error: 'dup.wasm': out of order section type: 1

$ wasm-objdump -h dup.wasm
  ...prints a section table, no complaint...</code></pre>
                <p>Three tools, three messages, one rule. The first is a validator naming the rule it broke and the offset. The second is a reader expressing the same rule as a consequence &mdash; in LLVM's model, a repeated section <em>is</em> an out-of-order section, and the message is more general than the situation. The third is a printer doing its job.</p>
                <p>What makes this worth a table of its own is that the failure is otherwise silent. Nothing about a duplicated Type section is locally wrong: the section is well-framed, its length is right, its content parses. It is the <em>file</em> that is illegal, and the only way to know is to have checked the thing you did not think to check. That is the general risk with a file format that has few redundant fields, and it is why the ordering rule is worth knowing as a rule rather than as an assumption.</p>
                <h3>Where two reference tools disagree about a size</h3>
                <p>Now the finding. Take the same custom sections from two real object files and ask <code>wasm-objdump</code> and <code>llvm-objdump</code> what their sizes are.</p>
                <div class="hex-dump">
                    <pre>custom section   declared   wabt    llvm    name bytes   payload after name
  linking            32      0x20    0x18        8              24
  producers          56      0x38    0x2e       10              46
  target_features   148      0x94    0x84       16             132
  reloc.CODE         17      0x11      --       11               6
</pre>
                </div>
                <p>Neither tool is wrong, and neither is guessing. They are reporting different quantities, and the file settles it unambiguously. Compute the payload size yourself from the bytes:</p>
                <div class="formula">
custom section content, in order:
    name length, as a LEB128          1 byte for a short name
    the name, that many bytes         8 for "linking", 10 for "producers",
                                      16 for "target_features", 11 for "reloc.CODE"
    whatever else, unnamed            the rest

payload size after the name = declared size - (1 + name length)
</div>
                <p>Every row checks out. <code>linking</code>: 32 &minus; 8 = 24 = <code>0x18</code>, which is what LLVM printed. <code>producers</code>: 56 &minus; 10 = 46 = <code>0x2e</code>. <code>target_features</code>: 148 &minus; 16 = 132 = <code>0x84</code>. And wabt's numbers are the declared sizes: 32 = <code>0x20</code>, 56 = <code>0x38</code>, 148 = <code>0x94</code>, 17 = <code>0x11</code>.</p>
                <p>So the finding is exactly this:</p>
                <ul>
                    <li><strong>wabt reports the declared size</strong> &mdash; the number in the length field, which includes the name.</li>
                    <li><strong>LLVM reports the payload after the name</strong> &mdash; what a consumer of the contents actually wants.</li>
                    <li><strong>For standard sections both report the declared size and both are identical</strong>, because standard sections have no name and the two definitions coincide.</li>
                </ul>
                <div class="callout callout-warn">
                    <p><strong>Why this is a trap rather than trivia.</strong> The difference is <em>1 + the name length</em>, which varies per section. A tool that takes wabt's number and uses it as a length to skip will land correctly, because wabt's number is the declared size. A tool that takes LLVM's number and does the same will stop <em>1 + name length</em> bytes early, inside the section, and start parsing whatever follows as if it were a section header.</p>
                    <p>Nothing errors. The bytes just past the end of a custom section's payload are the next section's identifier and length, which are small valid numbers, so the reader produces a plausible section that does not exist &mdash; and every row after that point is wrong. The error is <strong>constant per section and different for each section</strong>, because the name lengths differ, which is the same signature the <a href="/courses/dwarf/lessons/dwarf-frame">DWARF <code>.debug_frame</code> concept</a> used to identify a coordinate-system error.</p>
                    <p>Which is why this course's own crosscheck compares standard sections with both tools but compares custom-section <em>names</em> rather than sizes, and says so in a comment. A harness that blindly compared sizes would have reported a disagreement on every file, and the tempting conclusion &mdash; "one of the tools is wrong about custom sections" &mdash; would have been false.</p>
                </div>
                <h3>A length field that is two bytes wide</h3>
                <p>Every size in the samples so far has been under 128, so every length LEB128 has been a single byte with the high bit clear. That stops being true quickly. The hand-written sample has a section appended with a 43-character name and 200 bytes of filler:</p>
                <pre><code>$ wasm-objdump -h long_custom.wasm | tail -1
 Custom start=0x00000064 end=0x00000158 (size=0x000000f4) "really_long_custom_section_name_for_testing"</code></pre>
                <div class="hex-dump">
                    <pre>0064: 00 f4 01 2b 72 65 61 6c 6c 79 5f 6c 6f 6e 67 5f
      |  |  |  |  |  |
      |  |  |  |  |  +-- 0x2b = 43 decimal: the name length
      |  |  |  |  +----- "really_long_custom_section_name_for_testing"
      |  |  |  +-------- name starts here, after the length byte
      |  |  +----------- 0x01: the length continues
      |  +-------------- 0xf4: low 7 bits set, high bit set, so it continues
      +----------------- 0x00: section id, custom
</pre>
                </div>
                <p>Work the LEB128: the first length byte is <code>0xf4</code>. Its high bit is set, so the value continues in the next byte. Its low seven bits are <code>0x74</code> = 116, and the next byte <code>0x01</code> contributes <code>1 &times; 128</code> = 128. Total <strong>244</strong>, which is <code>0xf4</code> &mdash; and wabt printed <code>size=0x000000f4</code>, with <code>0x158 - 0x64 = 0xf4</code> confirming the distance.</p>
                <p>And the name length is itself a LEB128, <code>0x2b</code> = 43, one byte. It is worth noticing how much <em>everything</em> here is a LEB128: the section size, the custom section's name length, the count of entries in every section, every index, every limit. <strong>There are exactly two fixed-width integers in a WebAssembly module's framing &mdash; the four magic bytes and the four version bytes &mdash; and everything else is variable-width.</strong> That is the next concept, and it is the single most important encoding detail in the format.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The section walker, in full. It is thirteen lines, and it is the whole reader for the container layer of the format:</p>
                <div class="formula">
p = 8                          # past the header
while p &lt; len(file):
    off    = p                  # for error messages
    id     = file[p]            # 1 byte, no LEB
    p    += 1
    size, p = read_uleb128(file, p)
    content = file[p : p + size]
    p    += size

    if id == 0:
        # custom: the content starts with a name, and
        # "content" above therefore INCLUDES the name
        name, q = read_name(file, p)
        # so the real payload starts at q, not p
    else:
        # standard: content is the payload itself
        pass
</div>
                <p>That last indentation difference is the whole finding, and it is a <em>convention</em> rather than a rule. The framing is identical either way: <code>size</code> bytes of content follow the length field. But a custom section's content <em>begins</em> with a length-prefixed name, so whether the reported "size" includes that name decides where a consumer starts reading. wabt includes it, LLVM excludes it, and the file is unambiguous about which is which.</p>
                <p>Three things the walker deliberately does not do, and each is a decision:</p>
                <ul>
                    <li><strong>It does not check ordering.</strong> Adding that is four lines, and the tool you want it in is a validator, not a reader. A reader that silently accepts a duplicated section is more useful for inspecting broken files; a validator that accepts one is a security problem. Same code, different purpose, and knowing which one you are writing is the whole distinction.</li>
                    <li><strong>It does not stop at the first section it does not recognise.</strong> An unknown identifier is a forward-compatibility question, and the format's answer is to skip it using the length field. That is the property that lets a file written by a newer producer still be walked by an older reader: the reader does not need to understand a section to find its end.</li>
                    <li><strong>It does not cache anything.</strong> The point of the length field is that <em>skipping</em> a section is O(1) &mdash; one LEB128 read and an addition. A reader that decoded every section in order to "understand" the file would be O(n) in content, and the length field would buy nothing. Understanding is optional; skipping is the contract.</li>
                </ul>
                <p>That last point generalises past this format, and it is the reason length-prefixed framing is so common. A file where every region declares its own size can be walked by a reader that understands nothing about the contents, using only the sizes. It is why an <code>ar</code> archive can be listed without parsing a single object inside it, why a DWARF <code>.debug_cu_index</code> can be located without decoding a unit, and why <code>wasm-objdump</code> can print a section table for a file that will not validate. <strong>The length field is the interface between a reader that understands the format and a reader that only needs to find things in it.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -h simple.o
$ llvm-objdump -h simple.o
$ python3 courses/wasm/assets/samples/wasm_decode.py --hex simple.o</code></pre>
                <ul>
                    <li><strong>Reproduce the size disagreement by hand.</strong> Pick the <code>producers</code> section in <code>simple.o</code>, find its length byte in the hex, read the name length that follows, subtract, and check you get LLVM's number and not wabt's. Then write a one-line script that prints both numbers for every custom section in every sample, and you have built the check that would have caught this.</li>
                    <li><strong>Insert a custom section between two standard ones.</strong> Append one after the Data section of the hand-written sample, or splice one in the middle, and confirm it validates. Custom sections may appear anywhere; establishing that from a test is worth more than reading it.</li>
                    <li><strong>Break the ordering rule cleanly.</strong> My first attempt at this swapped two section ids, which also corrupted their sizes and so tested the wrong thing. Do it properly: move a whole section to the end, or duplicate one, so the framing stays valid and only the order is wrong. Then compare what the three tools say &mdash; the messages are the lesson.</li>
                    <li><strong>Make a section large enough to need a three-byte LEB.</strong> A payload over 16,384 bytes needs three bytes. Paste a large custom section into a module and confirm the length field widens and that both tools follow it. Two bytes is a coincidence of small files; three proves the encoding is general.</li>
                    <li><strong>Use the length field to skip.</strong> Write a ten-line program that reads a module, finds the Code section, and prints nothing else &mdash; no decoding of any content. That is the "reader that only needs to find things" and it is the property the framing exists to provide. Then add one section kind and confirm the finder needs no change.</li>
                    <li><strong>Add a section kind the tools reject.</strong> Change a standard section's id to 14, which is not defined, and see what each tool does. A reader that skips by length will sail past it; a validator will refuse the file. <strong>Those are different contracts, and which one you want depends on whether you are inspecting or loading.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a custom section is 56 bytes long by its length field, and its name is <code>producers</code>, which is 9 characters. A tool reports the section's size as <code>0x2e</code>. Which tool is it, and what would go wrong if the other tool's number were used to skip to the next section?</p>
                <div class="quiz" id="quiz-wasm-sections-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x2e is 46, and 56 minus the 1-byte name length and the 9 name bytes is exactly 46, so this is llvm-objdump reporting the payload after the name. wabt would report 56 as 0x38, the declared size. The consequence of using the wrong number is specific and nasty: skipping 46 bytes instead of 56 lands ten bytes early, inside the section, and the next ten bytes are the identifier and length of the following section, which are small valid numbers. The parser therefore reads a plausible section header that does not exist, and every subsequent section is off as well. The error is ten bytes for this section, eleven for a ten-character name, seventeen for a sixteen-character one, so it is constant within a section and different between them, which is the signature of an offset error rather than a content error." onclick="checkQuiz('quiz-wasm-sections-1', this)">It is <code>llvm-objdump</code>, reporting the payload after the name. Using wabt's number instead would over-skip by 10 bytes and land inside the following section</button>
                    <button class="quiz-option" data-correct="false" data-explain="The arithmetic is inverted, and it is worth being careful about which way round because the two numbers are easy to confuse. The declared size of 56 is wabt's, and it equals 0x38, not 0x2e. The payload after the name is 56 minus 1 minus 9, which is 46, and that is 0x2e. Getting the subtraction the wrong way round is the exact error this concept warns about, so it is worth checking the hex rather than reasoning about which tool is which." onclick="checkQuiz('quiz-wasm-sections-1', this)">It is <code>wasm-objdump</code>, reporting the declared size. Using the other tool's number would over-skip by 10 bytes and land past the section</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a different failure with a different fix. Both tools read the same length field, so there is no disagreement about where the next section starts; the only disagreement is about what to call the size once you know it. That is a reporting-convention difference, not a navigation difference, and a tool that skips by the declared size navigates correctly regardless of what it calls the number. What breaks is a reader that assumes one convention while reading the other's output." onclick="checkQuiz('quiz-wasm-sections-1', this)">It is <code>wasm-objdump</code>, and using the other number would make it skip to the wrong place, so the two tools cannot both be right about the same file</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your tool reads a WebAssembly module by walking sections and skipping unknown ones. It works on every module you have tested. A customer's module produces a section table with about four too many rows, and the extra rows are all small ids with plausible small sizes. Nothing errors. The customer says it was produced by a toolchain newer than yours, and asks whether their file is malformed. What do you conclude, how do you confirm it, and what is the one thing you should check about your own code first?</p>
                <div class="quiz" id="quiz-wasm-sections-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern identifies the failure. Too many rows, all with small plausible ids, is the signature of a walker that has lost sync and is now reading payload bytes as headers, which is what a size error produces. A newer toolchain is a red herring in the sense that it is not the cause: a format that can be extended is exactly the format designed so an old reader can skip a new section by its length. The confirmation is to compare against an independent reader on the same file, and if the two disagree on the count while agreeing on the file's total size, the file is fine and your walker is wrong. And the first thing to check in your own code is whether you handle the custom-section convention consistently, because that is where the two reference tools differ and it is the one place a reader can be internally consistent and still off by a variable amount. The general habit is to suspect your own parser before blaming the file when the symptom is a count being wrong rather than a value being wrong." onclick="checkQuiz('quiz-wasm-sections-2', this)">Your walker lost sync. Confirm it by reading the same file with the two reference tools and comparing section counts; check your own code first for whether you treat a custom section's size as including the name, since that is the one place the reference tools disagree and a variable per-section error</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the wrong conclusion to reach from that symptom, and it is worth seeing why. A well-formed section cannot be skipped wrongly by a reader that trusts the length field, because the length field is the definition of where the next section starts. If a new section kind broke the framing, every tool including the producer's own would be lost, and the customer's file would not have loaded at all. The symptom is a plausible-looking table with extra rows, which is what a desynchronised parser produces, not what an unfamiliar-but-legal file produces." onclick="checkQuiz('quiz-wasm-sections-2', this)">The customer's file is likely malformed, because a newer toolchain may emit section kinds your reader does not know and the extra rows are those</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a walk-based parser finds the wrong <em>number</em> of things, suspect it lost sync. A file cannot be both well-framed and mis-framed; it is one or the other, and the count is a better signal than any single value.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The length field is the oldest idea in binary formats and this course has now met it four times. <a href="/courses/coff/lessons/coff-archives">The <code>ar</code> archive</a> gives each member a 60-byte header with a decimal size, so a reader can step member to member without understanding any of them. <a href="/courses/dwarf/lessons/dwarf-loclists">The DWARF location list table</a> is framed by a section-level length field for the same reason. <a href="/courses/elf/lessons/relocation-entries">ELF</a> frames its sections the same way and then adds a section table so a reader can seek rather than scan.</p>
                <p>WebAssembly takes the idea and makes it the <em>only</em> framing mechanism, and adds two things the others do not have. The first is the ordering rule, which lets a reader be a straight-line loop with no state. The second is the custom section, which is a promise that the format will not interpret bytes it did not define &mdash; and that promise is why a module can carry compiler provenance, target feature requirements, and linker metadata without the specification having to mention any of them.</p>
                <p>That second one is the more interesting, and it connects straight to the <a href="/courses/coff/lessons/coff-drectve">COFF <code>.drectve</code> concept</a>, which is about a section whose contents are not the program's contents. Both formats discovered the same escape hatch, for the same reason: the specification is frozen and the world is not. The difference is that COFF marks the escape with a section characteristic, while WebAssembly marks it with the identifier zero &mdash; and LLVM's own object format leans on the WebAssembly one, so a <code>.wasm</code> file from clang is full of sections the core specification says nothing about.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-leb128">LEB128</a>, the encoding that almost every other number in the format uses.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-header">Previous: The Eight-Byte Header</a></span>
                <span><a href="/courses/wasm/lessons/wasm-leb128">Next: LEB128</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
