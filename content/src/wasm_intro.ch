// WebAssembly Course — Module 1: The Container
// Concept: what the binary format is, who reads it, and the three tools this
// course cross-checks every claim against.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why a Binary Format — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Why a Binary Format</h1>
            <div class="lesson-meta">15 min &middot; Module 1: The Container &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every binary format in this collection exists because somebody needed to put one thing in a file where two parties could not both be the source of truth. The ELF header exists so a kernel and a compiler agree on where the program starts. The DWARF sections exist so a compiler and a debugger agree on what a variable means. <strong>WebAssembly's binary format exists so that a compiler and a browser agree on what a program does, across language and vendor boundaries, with the agreement settled by a written specification rather than by a conversation.</strong></p>
                <p>That framing matters more for WebAssembly than for the others, because here the two parties are unusually far apart. A compiler written in one language emits code for a runtime written in another, on a machine neither author controls, and the only thing they share is this file format. There is no header to be added by a vendor, no field that means "vendor private", no room to negotiate. <strong>Eight bytes of fixed prefix, then a strictly ordered sequence of length-delimited sections, and that is the entire negotiation surface.</strong></p>
                <p>The rigidity is the feature. It is why a WebAssembly module can be validated by a fifty-line checker before it is allowed to run, and why the same file can be handed to a JIT, an interpreter, or a validator and all three agree on what it contains. Every design decision in this module is downstream of that goal: a format that can be checked without executing it, by code that does not trust it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What is actually in the file. The smallest legal module, in full:</p>
                <div class="hex-dump">
                    <pre>00 61 73 6d 01 00 00 00
|  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  +-- version 1, FOUR fixed bytes
|  |  |  |  |  |  |  +----- little-endian, so 01 comes first
|  |  |  |  |  |  +-------- the 0 byte here is the high half
|  |  |  |  |  +----------- an ASCII "m"
|  |  |  |  +-------------- an ASCII "s"
|  |  +------------------ an ASCII "a"
|  +--------------------- 0x00, the NUL that makes it not a text file
+------------------------ the magic: 0x00 followed by the letters "asm"
</pre>
                </div>
                <p>Eight bytes, and that is a complete, valid, empty WebAssembly module. Not a stub and not a placeholder &mdash; a module that does nothing, correctly encoded, that a runtime will load and instantiate without complaint.</p>
                <p>Build it yourself in two commands, which is the fastest way to make the format concrete:</p>
                <pre><code>$ printf '(module)' &gt; min.wat
$ wat2wasm min.wat -o min.wasm
$ xxd min.wasm
00000000: 0061 736d 0100 0000                      .asm....
$ wc -c &lt; min.wasm
8</code></pre>
                <p>Two interesting things in that output. The magic is <code>0x00</code> followed by the ASCII letters <code>asm</code> &mdash; the format is literally named by its own first four bytes, with a NUL in front so that the file is not mistaken for text. And <code>xxd</code>'s ASCII gutter prints the same eight bytes as <code>.asm....</code>, which is the format telling you what it is in a display you can read at a glance.</p>
                <h3>The three tools, and why there are three</h3>
                <p>This course checks every claim against three independent implementations, and the reason is not ceremony. A binary format has almost no redundancy in it: if a decoder misreads a size by one byte, it still produces a table that looks entirely reasonable. The only defence is disagreement.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Reader</th><th scope="col">Where it comes from</th><th scope="col">What it is good for</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>wasm_decode.py</code></td><td>written from the specification, shipped with this course</td><td>Being wrong in the way the <em>specification</em> is ambiguous, rather than in the way an implementation is sloppy</td></tr>
                        <tr><td><code>wasm-objdump</code></td><td>wabt, the reference toolchain</td><td>The most complete section-aware reader; the disassembler</td></tr>
                        <tr><td><code>llvm-objdump</code></td><td>LLVM, which also compiles to WebAssembly</td><td>A second implementation with entirely different internal assumptions</td></tr>
                    </tbody>
                </table>
                <p>And a fourth participant, which is a reader of a different kind: <code>clang --target=wasm32</code>. It is a producer rather than a reader, and it matters because it gives this course something the ELF and COFF courses do not have in the same form: <strong>a real compiler that emits real modules from real source</strong>, so every claim about the format can be checked against a file that something intended rather than something hand-assembled.</p>
                <div class="hex-dump">
                    <pre>$ clang --target=wasm32 -O2 -c w2.c -o w2.o
$ file w2.o
w2.o: WebAssembly (wasm) binary module version 0x1 (MVP)
</pre>
                </div>
                <p>Note what that object is: <em>a WebAssembly module</em>. Not a container wrapping one, not a distinct format. The compiled output of one C file is already a module, with the same header as the eight-byte one above, and it can be handed straight to a runtime. That is a genuinely unusual property &mdash; ELF objects and COFF objects both need a linker, and what the linker produces is a different file &mdash; and the module format doubles as the object format because there is no separate "unlinked" representation.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The crosscheck, and what it is protecting against</h3>
                <p>Run it on the samples shipped with this course:</p>
                <pre><code>$ cd courses/wasm/assets/samples
$ python3 crosscheck.py
ok    externs.o                10 sections, three readers agree
ok    handwritten.wasm          9 sections, three readers agree
ok    long_custom.wasm         10 sections, three readers agree
ok    minimal.wasm              0 sections, three readers agree
ok    simple.o                  7 sections, three readers agree

5 file(s) checked, 0 with disagreements
CROSS-CHECK PASSED -- all three readers agree on every section</code></pre>
                <p>A green result is worth nothing on its own, so the harness is itself tested by breaking files on purpose. Three corruptions, three detections:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Injected fault</th><th scope="col">Result</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>one byte of a section's size changed</td><td>FAIL &mdash; section count disagreement</td></tr>
                        <tr><td>two section ids swapped</td><td>FAIL &mdash; section count disagreement</td></tr>
                        <tr><td>one byte of the magic changed</td><td>FAIL &mdash; section count disagreement</td></tr>
                    </tbody>
                </table>
                <p>And notice <em>how</em> the tools disagree about broken files, because it is instructive. On a file with a duplicated Type section:</p>
                <pre><code>$ wasm-validate dup.wasm
  0000063: error: multiple Type sections

$ llvm-objdump -h dup.wasm
llvm-objdump: error: 'dup.wasm': out of order section type: 1

$ wasm-objdump -h dup.wasm
   ...prints a section table quite happily...</code></pre>
                <p>Three behaviours, and the difference is a design decision each tool made. <code>wasm-validate</code> is a validator, so it reports the specific rule it broke. LLVM expresses the same rule as an <em>ordering</em> violation &mdash; "out of order section type" &mdash; because in its model a repeated section is a special case of appearing out of sequence. <code>wasm-objdump</code> is a printer, so it prints; it will happily show you the structure of a file that could never run, and that is a reasonable thing for a disassembler to do.</p>
                <p>Which produces a habit worth having. <strong>A tool that prints something is not a tool that vouched for it.</strong> Throughout this course, "the disassembler shows" and "the validator accepts" are different claims and are never used interchangeably. The 1.0.36 wabt and LLVM versions quoted here are what produced every number in this module.</p>
                <h3>What is in a real module</h3>
                <p>The samples are not toys. <code>simple.o</code> is what clang emits for two C functions, and <code>externs.o</code> is what it emits when those functions touch a static array and an external global:</p>
                <pre><code>$ wasm-objdump -h simple.o
  Type start=0x0000000e end=0x0000001a (size=0x0000000c) count: 2
Import start=0x00000020 end=0x00000038 (size=0x00000018) count: 1
Function start=0x0000003e end=0x00000041 (size=0x00000003) count: 2
Code start=0x00000047 end=0x00000058 (size=0x00000011) count: 2
Custom start=0x0000005e end=0x0000007e (size=0x00000020) "linking"
Custom start=0x00000084 end=0x000000bc (size=0x00000038) "producers"
Custom start=0x000000c2 end=0x00000156 (size=0x00000094) "target_features"</code></pre>
                <p>Four standard sections and three custom ones, and the custom ones are where a compiler puts everything the module format does not have a place for: which toolchain produced it, which target features it needs, and &mdash; in <code>linking</code> &mdash; the information a linker needs. That last one is why there is a Module 5 in this course at all. For now the point is narrower: <strong>the standard sections are a closed, specified set, and everything a real compiler needs to say beyond them goes in custom sections that the format promises not to interpret.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why a format with this little redundancy has to be read by more than one tool. Take the section table of <code>simple.o</code> and remove any one of the three readers, and ask what class of bug it would now fail to catch.</p>
                <div class="formula">
a decoder is wrong about a size
    by one byte
        -> it starts the next section one byte early
        -> it reads a plausible section id from the middle of a payload
        -> the id is usually a small number, so it is usually VALID
        -> the following "size" is also a plausible small number
        -> the section table it prints has a plausible number of rows
        -> NOTHING looks wrong

the same bug, caught by disagreement
    my decoder says  the next section starts at 0x16
    wabt says         the next section starts at 0x16
    llvm says         the next section starts at 0x16
    two of them agree -> the byte is probably 0x16
    all three agree   -> the byte IS 0x16, because a single
                         shared misunderstanding of the
                         format is far less likely than a
                         single implementation's slip
</div>
                <p>That is the whole argument, and it is the reason this course's harness exists rather than a prose promise. Note the shape of the failure: <strong>a decoder that is off by one does not look broken, it looks like a decoder for a slightly different format.</strong> And there are many slightly different formats to be wrong about &mdash; the size convention for custom sections differs between tools, as the next concept shows, and a decoder that has silently picked the wrong one produces a table that is wrong in a way nobody can see.</p>
                <p>The same argument applies to <em>reading the specification</em>. Where a spec is ambiguous, two implementations will differ, and the difference is a fact about the format that a third reader can often settle. That happened twice in the previous course in this collection: a readelf and an llvm-dwarfdump disagreed about DWARF 5 location lists, and the byte offsets settled it. It will happen again here. The method is the same and it is the reason this course ships a decoder rather than only prose: <strong>an independent implementation written from the specification is the only way to find out whether the specification said what you thought it said.</strong></p>
                <p>What you should take from this concept is a working habit rather than a fact. When you next read a binary format, the first question worth asking is not "what does this field mean" but "what would it take to check that claim, and who else has already tried". A format that cannot be checked cannot be learned reliably, and a great many can.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ printf '(module)' &gt; min.wat &amp;&amp; wat2wasm min.wat -o min.wasm &amp;&amp; xxd min.wasm
$ clang --target=wasm32 -O2 -c mycode.c -o mycode.o &amp;&amp; wasm-objdump -h mycode.o
$ cd courses/wasm/assets/samples &amp;&amp; python3 crosscheck.py</code></pre>
                <ul>
                    <li><strong>Build the eight-byte module by hand.</strong> Write the eight bytes with <code>printf</code> or a hex editor, check them with <code>wasm-validate</code>, and then check that <code>wasm-objdump</code> and <code>llvm-objdump</code> both accept the same file. Then change the version to <code>02</code> and see which tools refuse it and what they say. The refusal messages are the most informative thing in the exercise.</li>
                    <li><strong>Prove the magic is what you think.</strong> Change byte 1 from <code>0x61</code> to something else and observe all three readers. Then try a file that starts with <code>asm</code> but no NUL &mdash; a plausible mistake, since the magic reads as three letters &mdash; and see whether anything notices. The NUL is the part that stops a text tool from trying to read it.</li>
                    <li><strong>Compile something of your own and crosscheck it.</strong> Take a C file with a function, an array, and a global, compile it with <code>clang --target=wasm32 -c</code>, and run the harness on the result. This is the fastest way to build intuition for which sections appear when, and it costs one command.</li>
                    <li><strong>Compare <code>-O0</code> and <code>-O2</code>.</strong> The same file at two optimisation levels produces the same section <em>kinds</em> and different code sections. Diff the two section tables and then disassemble both. Watching the code section shrink while the declaration sections stay put is the clearest demonstration of what the optimiser does in this format.</li>
                    <li><strong>Break the harness on purpose, properly.</strong> The three injections described above are in this course's history; reproduce at least one and confirm the harness reports it. Then try a subtler one &mdash; change a byte deep inside a code payload &mdash; and note that the <em>section table</em> check passes. That is a real limitation of a harness that checks structure, and knowing its boundary is part of using it.</li>
                    <li><strong>Look at the version number in a tool.</strong> <code>wasm-objdump</code> prints <code>file format wasm 0x1</code> and <code>file</code> prints <code>version 0x1 (MVP)</code>. The MVP label is historical, from when the format was a proposal and "1" meant the proposal. Find out what changed and in which direction the version field has moved since, because a field called "version" in a format that has only ever had one value is a design choice rather than a fact about the past.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you have a file that starts with the eight-byte header, then a Type section of size 10, then something that does not parse. You have three readers and they all report a section table. What is the strongest evidence that the Type section's size is really 10, and why is a single reader's agreement with itself not that evidence?</p>
                <div class="quiz" id="quiz-wasm-intro-1">
                    <button class="quiz-option" data-correct="true" data-explain="This is the concept's whole argument. Agreement between three implementations with different codebases and different assumptions is evidence in a way that one implementation's internal consistency is not, because a single off-by-one produces a table that is internally consistent and wrong: the next section id is read from the middle of a payload, and small numbers are common there, so the id is usually valid, and the size that follows it is usually also a valid small number. The result is a table with a plausible number of plausible rows and nothing visibly wrong. Three-way agreement does not prove the value either, since a shared misreading of the specification is possible, but it makes a single implementation's slip the less likely explanation, and when they do disagree the disagreement is a fact about the format worth chasing." onclick="checkQuiz('quiz-wasm-intro-1', this)">That all three readers independently report the same next-section offset. A single reader being self-consistent proves only that its error, if any, is self-consistent &mdash; and an off-by-one is, because the next byte is usually a small valid id</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real check and it is the right instinct, but it is a different claim from the one asked. A validator confirming the size is internally consistent is one implementation agreeing with itself, which is precisely the category of evidence that cannot distinguish a correct decode from a consistent misdecode. It tells you the file is well-formed enough to validate, not that your reader's offset arithmetic matches everyone else's." onclick="checkQuiz('quiz-wasm-intro-1', this)">That the validator accepts the file, since <code>wasm-validate</code> is the reference implementation for correctness</button>
                    <button class="quiz-option" data-correct="false" data-explain="Byte-position evidence is genuinely part of the argument, but it does not require hexdumping by hand. The whole point of three readers is to make that check mechanical rather than manual, and this answer picks the one approach that is slow, error-prone, and only available for the small files where a human would bother. The automated comparison of three independent reports is the same evidence with none of the manual cost." onclick="checkQuiz('quiz-wasm-intro-1', this)">That the size byte is followed by a plausible section id at exactly the offset the size predicts, which you can check by hand in a hex dump</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a WebAssembly module builder &mdash; a tool that emits <code>.wasm</code> files, rather than one that reads them. Your first output loads in a browser and runs correctly. Your second, which adds one data segment, loads and then silently produces an empty string where the data should be. No error, no warning, from any tool you try. Walk through what you would check, in order, and say what result would send you to which part of the file.</p>
                <div class="quiz" id="quiz-wasm-intro-2">
                    <button class="quiz-option" data-correct="true" data-explain="The reasoning is the useful part, not the answer. Run the validator first, because it costs nothing and it distinguishes a malformed file from a well-formed file that does the wrong thing; a validator error names the offset and the rule, and a silent wrong answer with a clean validator means the file is legal and something else is wrong. Then diff the section tables of the two files with two independent tools, because the data segment is a size and a payload and a wrong size corrupts every section after it, which is why a data-section bug shows up as a string being empty rather than as a crash. Then read the data segment's own bytes and confirm the payload is where the mode field and the offset expression say it is. The habit underneath all of it is to let the cheapest check that could distinguish two explanations run first, and to notice that a silent wrong answer in a format with no redundancy almost always means a length field is wrong rather than a value field." onclick="checkQuiz('quiz-wasm-intro-2', this)">Run <code>wasm-validate</code> first, then diff the two files' section tables with two tools, then read the data segment's bytes. A clean validator plus an empty string points at a size or offset field, not at the data itself</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a reasonable instinct and it is the wrong order. The validator runs first precisely because it is the cheapest check that can eliminate a whole class of explanations: if the file is malformed it says so, with an offset, and the data-segment theory is settled immediately. Going to a disassembly first means doing by hand the work the validator does for free, and a disassembly of a mis-sized file shows you the consequences rather than the cause." onclick="checkQuiz('quiz-wasm-intro-2', this)">Disassemble both files with <code>wasm-objdump -d</code> and diff the code sections, since the data is loaded by an instruction you will be able to see</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: on a silent wrong answer, check the length fields before the value fields. In a format with no redundancy, a wrong length does not look wrong &mdash; it looks like the next thing in the file.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>WebAssembly's binary format is the fourth container this collection has decoded, and the comparison is the fastest way to place it. <a href="/courses/elf/lessons/elf-header-fields">ELF</a> and <a href="/courses/coff/lessons/coff-file-header">COFF</a> both begin with a fixed header describing the whole file, and both have a section table that can appear in any order. <a href="/courses/dwarf/lessons/dwarf-sections">DWARF</a> has no header at all, just a bag of sections the consumer looks up by name.</p>
                <p>WebAssembly shares ELF's strict ordering requirement and rejects the rest: its section ids must appear in increasing order, with custom sections as the only exception. <strong>That is a stronger constraint than ELF's and it buys something specific</strong> &mdash; a reader can walk the file once, in one direction, and know when it is finished, without tracking which sections it has already seen. ELF cannot make that promise because a section may legitimately be absent, and its reader must therefore be written to tolerate holes. WebAssembly trades flexibility for a reader that is a loop.</p>
                <p>It is also the only one of the four whose container doubles as its object format, which the next two concepts make concrete: there is a header and then sections, and what a compiler emits and what a runtime consumes is the same kind of file. ELF needed a separate <code>.rel</code> section to say how to get from object to executable; WebAssembly will carry that information in custom sections instead, and Module 5 decodes them.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-header">The Eight-Byte Header</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm">Back to course</a></span>
                <span><a href="/courses/wasm/lessons/wasm-header">Next: The Eight-Byte Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
