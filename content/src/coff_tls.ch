// COFF Course — Module 5: Other Targets and Other Sections
// Concept: the .tls$ section — where a thread-local variable's address is decided,
// and why one of them cannot be linked on this machine.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_tls() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Thread Local Storage — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Thread Local Storage</h1>
            <div class="lesson-meta">19 min &middot; Module 5: Other Targets and Other Sections &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every variable you have met in this course has had exactly one address. A global has an address, a local has an address computed from the stack pointer, and both are the same for every thread. A thread-local variable does not have that, and the reason is worth stating precisely: <strong>its address depends on which thread is asking.</strong></p>
                <p>That breaks the assumption the whole relocation machinery rests on. A <code>DW_AT_low_pc</code> or a <code>DW_OP_addr</code> is an address, and an address is a single number. But a thread-local's address is <em>an expression involving a base that the thread itself supplies</em> &mdash; on Windows, a value called <code>_tls_index</code> that the loader assigns per module and the runtime turns into a per-thread slot on first use.</p>
                <p>So the section is interesting for a reason beyond TLS: it is the one place in a COFF object where a variable's address is not a constant, and the format has to encode that as a section rather than as a relocation. A section whose <em>name</em> means something is unusual, and this one is named <code>.tls$</code> &mdash; with a dollar sign, which is a hint rather than a convention.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Compile a thread-local variable and look at the sections:</p>
                <p>Two thread-local variables, and one function that reads both:</p>
<table>
    <thead>
        <tr><th scope="col">Declaration</th><th scope="col">What it is</th></tr>
    </thead>
    <tbody>
        <tr><td><code>__declspec(thread) int counter = 5</code></td><td>an initialised thread-local scalar</td></tr>
        <tr><td><code>__declspec(thread) int shared_buf[4]</code></td><td>an uninitialised thread-local array, so it goes to the bss-like part</td></tr>
    </tbody>
</table>
<pre><code>$ clang --target=i686-pc-windows-msvc -c tls.c -o tls.obj
$ llvm-readobj --sections tls.obj | grep Name</code></pre>
                <p>Four ordinary sections and one that is not:</p>
                <div class="hex-dump">
                    <pre>sec1  .text       char=0x60500020
sec2  .data       char=0xc0300040
sec3  .bss        char=0xc0300080
sec4  .tls$       char=0xc0300040     &lt;-- the one that matters
sec5  .debug$S    char=0x42300040
sec6  /4          char=0x00100800
</pre>
                </div>
                <p>Read the characteristics of section 4 with the parser shipped with this course:</p>
                <pre><code>IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE</code></pre>
                <p>That is <strong>identical to <code>.data</code></strong> &mdash; same value <code>0xc0300040</code>, same three flags. And that is the point. A thread-local initialised variable is genuinely initialised data, genuinely readable, genuinely writable, and the format says so with the ordinary flags. <strong>Nothing in the characteristics marks it as thread-local.</strong> The only thing that says so is the section <em>name</em>.</p>
                <div class="callout callout-warn">
                    <strong>Which is a genuine fragility, and worth naming as one.</strong> Everything else in a COFF section header is either a fact about the data or an instruction to the linker. The name, for most sections, is a label a human chose. Here it is load-bearing: <code>.tls$</code> is not <code>.data</code> with a different letter, it is a request for per-thread allocation semantics, and a tool that reports a section by its characteristics alone cannot tell the two apart. This is the same lesson as the long section name <code>/4</code> in section 6, arrived at from the other direction &mdash; sometimes the name is the payload.
                </div>
                <h3>Why the dollar sign</h3>
                <p>The <code>$</code> is not decoration. In the COFF convention, <code>.text$mn</code> and <code>.text$zz</code> are suffixes that let a linker <em>order</em> code fragments within <code>.text</code> &mdash; the <code>mn</code> and <code>zz</code> pairs are alphabetical orderings chosen by convention so that multi-threaded and single-threaded startup paths land in a known order. <code>.tls$</code> uses the same idea: the dollar sign marks a section whose position within its group is meaningful, and bare <code>.tls$</code> sorts before any <code>.tls$zz</code>-style variant.</p>
                <p>So the section name here is doing two jobs at once: it selects TLS semantics, and its suffix participates in an ordering. Neither job is visible in the section header's numeric fields, and both are visible in eight bytes of name.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>What is in the section</h3>
                <p>The two variables in the source, and the raw contents of section 4:</p>
                <div class="hex-dump">
                    <pre>raw bytes:  05 00 00 00  00 00 00 00  00 00 00 00
             |     |     |      |      |      |      |      |
             |     |     |      |      |      |      |      +-- shared_buf[0..3] = 0
             |     |     |      |      |      |      +--------- shared_buf[1..3] = 0
             |     |     |      |      |      +---------------- counter's address is
             |     |     |      |      |                       irrelevant here: it is
             |     |     |      |      |                       a *template*
             |     |     |      |      +-------------------------- stored at offset 4
             |     |     |      +--------------------------------- 4 bytes of data
             |     |     +---------------------------------------- initial value, 5
             |     +---------------------------------------------- 4 bytes of padding
             +---------------------------------------------------- 4 bytes for the
                                                                   initialised value
</pre>
                </div>
                <p>Read that carefully, because it is the concept. The bytes are the <em>template</em> &mdash; the initial values, laid out exactly as they would be in <code>.data</code>. And yet <strong>the addresses in this section are not the addresses of the variables</strong>. Every thread gets its own copy, allocated at a different address, and this section is the template those copies are made from.</p>
                <p>That is the whole design in one sentence: <strong>the section holds initial values; it does not hold the variables.</strong> The variables live in per-thread storage the loader creates, and the template is consumed at thread-creation time.</p>
                <h3>How the code refers to it</h3>
                <p>Disassemble the one function:</p>
                <pre><code>$ llvm-objdump -d --section=.text tls.obj
  0:  a1 04 24 24 24        mov   0x2424,%eax
  5:  03 05 24 28 24 24     add   0x2428,%eax
  b:  c3                   ret
</code></pre>
                <p>Two absolute-looking addresses, <code>0x2424</code> and <code>0x2428</code> &mdash; four bytes apart, which is exactly the gap between <code>counter</code> and <code>shared_buf</code> in the template. In a relocatable object those are <code>IMAGE_REL_I386_DIR32</code> fixups with zeros, and after an ordinary link they would become real addresses into <code>.data</code>.</p>
                <p>For TLS they must not. They have to become something like <em>the address of this thread's copy</em>, which is base + <code>_tls_index</code>-derived offset. So the fixups in a TLS object are <strong>not</strong> plain <code>DIR32</code> against <code>.tls$</code> &mdash; and that is where the module runs out of road on this machine, which is the honest place to stop.</p>
                <h3>What happens when you try to link it</h3>
                <p>Attempt the link with the linker this course has been using throughout:</p>
                <pre><code>$ ld --oformat pei-i386 -m i386pe tls.obj -o tls.exe --entry read_it
tls.obj:tls.c:(.text+0x5): undefined reference to `_tls_index'
tls.obj:tls.c:(.text+0xb): undefined reference to `_tls_array'</code></pre>
                <p>Two undefined symbols, and they are the two things a Windows TLS program needs from the runtime. <code>_tls_index</code> is the per-module index the loader assigns; <code>_tls_array</code> is the per-thread pointer array the runtime indexes with it. A program that uses thread-locals computes its variable's address as <em>something involving these two</em>, and nothing in the object file can supply them.</p>
                <div class="callout callout-warn">
                    <strong>What is established and what is not, precisely.</strong>
                    <br /><br />
                    <strong>Established from the object file:</strong> a <code>.tls$</code> section exists; its characteristics are byte-identical to <code>.data</code> and say nothing about TLS; its contents are an initial-value template, not addresses; and the section name is the only thing marking it.
                    <br /><br />
                    <strong>Established from the link attempt:</strong> the linker reads the section and plans to place it, and then fails on <code>_tls_index</code> and <code>_tls_array</code>. The map file it produced before failing contains a row for <code>.tls</code> &mdash; <strong>note the name change</strong>, the output section is <code>.tls</code> where the input was <code>.tls$</code> &mdash; which is direct evidence that the linker renames the section on the way out.
                    <br /><br />
                    <strong>Not established, and therefore not taught:</strong> the exact <code>IMAGE_REL_I386</code> type used for a TLS address on this target, the bytes of the linked <code>.tls</code> section, and what the loader writes into <code>_tls_array</code>. Those need a linker that implements PE TLS, and this one does not. A reader who wants them needs <code>lld-link</code>.
                </div>
                <p>So this concept ends where Module 4's archive discussion ended, and for the same reason: <strong>the container and the flags are fully verifiable here; the runtime behaviour is not.</strong> That is still worth a concept, because the container is the part a tool author has to get right and the part a reader will meet in every Windows binary that uses a library with thread-locals &mdash; which is most of them.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a tool has to do with a <code>.tls$</code> section, and where each of those jobs is done. The value of walking this is that it separates the things an offline tool can get right from the things only a running process can.</p>
                <div class="formula">
OFFLINE, from the object file:
    .tls$ contents are the initial-value template
    the layout is the layout: offset of each symbol within
        the section is its offset within every thread's copy
    so a symbol's offset is knowable, and the section size is
        the per-thread footprint of all of them together

AT LINK TIME, by the linker:
    collect every .tls$ input section into one .tls output
        section, applying each object's own alignment
    assign each contributing module a _tls_index
    -- this needs PE TLS support, which this linker lacks

AT LOAD TIME, by the loader and the runtime:
    allocate the per-thread blocks
    publish _tls_array[ _tls_index ]
    the first access in a thread initialises that thread's
        block from the template

AT RUN TIME, in the generated code:
    the variable's address is
        _tls_array[ _tls_index ] + the symbol's offset
    which is why the fixup cannot be a plain DIR32
                </div>
                <p>Four stages, and they are worth keeping apart because tools operate at different ones. The crucial observation for anyone writing a tool is in the first block: <strong>the offset of a thread-local within its section is a static fact, knowable offline, and it is the same offset in every thread's copy.</strong> That is the property that makes TLS tractable &mdash; the block is copied, so the internal layout is invariant, and only the base moves.</p>
                <p>It also explains why the <code>.tls$</code> section is named the way it is, and why the dollar sign matters even though the section is a single group here. A toolchain that needs several TLS groups &mdash; one per initialisation priority, which is how C++ thread-local objects with destructors are ordered &mdash; uses names like <code>.tls$zz</code> and <code>.tls$mn</code> to give the linker an explicit order. The name carries the ordering because there is nowhere else to put it: the characteristics say "initialised data", the data says "these are the values", and neither can express "initialise this group before that one".</p>
                <p>And the reason a plain <code>DIR32</code> cannot work is the last block. The generated code needs <em>the address of the current thread's copy</em>, which is a runtime value reached through two symbols neither of which exists until the program loads. So the relocation the compiler emits is not a reference to the <code>.tls$</code> section at all &mdash; it is a reference to <code>_tls_index</code> or <code>_tls_array</code>, with the symbol's offset added. The section never appears in the fixup; it appears only in the loader's copy step. <strong>Which means a COFF object with thread-locals carries two references to each variable, in two different worlds</strong>, and a tool that resolves only the one it can see offline will report a section-relative offset where the program means a per-thread one.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-readobj --sections --relocations tls.obj
$ llvm-objdump -d --section=.text tls.obj
$ python3 courses/coff/assets/samples/coff_parse.py tls.obj</code></pre>
                <ul>
                    <li><strong>Compare the flags, character by character.</strong> Section 2 <code>.data</code> and section 4 <code>.tls$</code> have the same characteristics value. Confirm it, then confirm that nothing else in either section header distinguishes them. That is the whole "the name is the payload" lesson, and it takes one command.</li>
                    <li><strong>Read the symbols' section numbers.</strong> <code>counter</code> and <code>shared_buf</code> are in section 4. Note what their <code>Value</code> fields mean: an offset within the template, which is an offset within every thread's copy. Then write down what a debugger would have to do to report their addresses for a <em>particular</em> thread, and where it gets the base.</li>
                    <li><strong>Read the relocations and see that they do not name the section.</strong> The fixups in <code>.text</code> reference <code>_tls_index</code> and <code>_tls_array</code>, not a <code>.tls$</code> offset. Confirm it, and then explain to yourself why that is the only design that can work &mdash; the answer is in the four-stage breakdown above.</li>
                    <li><strong>Prove the template interpretation.</strong> Change <code>counter = 5</code> to <code>counter = 999</code>, recompile, and check that the bytes in <code>.tls$</code> change. Then add a second thread-local and confirm the section grows and the new symbol's offset matches its position. A section that grows in step with the declarations is a template, not a fixed allocation.</li>
                    <li><strong>Find a real-world <code>.tls$</code>.</strong> Take any Windows binary you have access to, or a MinGW-built one, and look for the section. Reading its size tells you the per-thread footprint of the program's thread-locals, which is a genuinely useful number that no other section gives you and that a memory report will never show you.</li>
                    <li><strong>Work out what a linker would have to do.</strong> You now know it fails on <code>_tls_index</code> and <code>_tls_array</code>. Write the three things it must do that an ordinary section does not require: assign a per-module index, rename the input section, and make the fixups refer to a runtime base rather than a section offset. Implementing any one of them is a small, well-defined piece of work.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an object's section 4 is named <code>.tls$</code> and has characteristics <code>0xc0300040</code>. Section 2 is named <code>.data</code> and has characteristics <code>0xc0300040</code>. A tool lists a symbol's address as <code>image_base + section.VirtualAddress + symbol.Value</code>, which is correct for every other symbol in the object. What does it report for a thread-local, and where does the information it needs actually live?</p>
                <div class="quiz" id="quiz-coff-tls-1">
                    <button class="quiz-option" data-correct="true" data-explain="This is the concept in one question. The section header says nothing about TLS, so nothing in the numeric fields tells the tool that section 4 is not ordinary data, and the formula it is applying is exactly the formula that is right everywhere else in the object. So it reports an address inside the section that holds the initial-value template, which is a real address and means nothing at run time. The offset half of the answer is right and is genuinely useful: the symbol's offset within the section is the same in every thread's copy, because the block is copied. The base half is not knowable offline at all, because it comes from _tls_array indexed by a loader-assigned _tls_index, neither of which exists until the program is running. So a tool can report the offset and must not report an address." onclick="checkQuiz('quiz-coff-tls-1', this)">It reports <code>image_base + .tls$.VirtualAddress + symbol.Value</code>, which is an address inside the initial-value template. The <em>offset</em> is correct and is the same in every thread's copy, but the <em>base</em> is a per-thread value the loader supplies through <code>_tls_array</code> and <code>_tls_index</code>, neither of which is knowable offline</button>
                    <button class="quiz-option" data-correct="false" data-explain="The section is not renamed before the tool looks at it. The rename from .tls$ to .tls happens at link time, and the object file on disk has .tls$, which is what the section table and the symbol table both name. A tool reading the object sees .tls$ and can only be confused if it ignores the name, which is the actual failure mode here." onclick="checkQuiz('quiz-coff-tls-1', this)">It reports nothing, because the section is renamed to <code>.tls</code> at load time so the symbol's section number no longer resolves</button>
                    <button class="quiz-option" data-correct="false" data-explain="That would be correct behaviour, and it is what the tool should do, but the question asks what it does report with the formula given. Since the characteristics are byte-identical to .data and the name is the only distinguishing feature, a tool that applies this formula without special-casing the name reports a plausible address in the template. That plausible wrong address is precisely the failure worth being able to recognise." onclick="checkQuiz('quiz-coff-tls-1', this)">It correctly reports that the symbol has no static address, because the characteristics show the section is not ordinary data</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You write a static analysis tool that reports every global's address in a Windows binary, by reading symbols and section headers. It works on most binaries. On one &mdash; a large C++ program that links a threading library &mdash; it reports a handful of symbols at addresses that fall inside a section called <code>.tls$</code>, and those symbols are the ones you would expect to be per-thread caches and counters. The tool reports no error. What is it doing, and what is the smallest change that makes its output correct rather than merely non-crashing?</p>
                <div class="quiz" id="quiz-coff-tls-2">
                    <button class="quiz-option" data-correct="true" data-explain="The identification is already done for you by the section name, and the smallest change is to use it. A tool that special-cases .tls$ and reports the symbol's offset within the section, labelled as a per-thread offset rather than an address, is correct in the only sense available offline: the offset really is invariant across threads because the block is copied. The alternative of trying to produce a real address is not available at all, since the base comes from a loader-assigned index through a per-thread pointer array, and no static reading of the file can recover it. Worth noticing is what made this bug survive: the characteristics are byte-identical to .data, so nothing in the numeric fields distinguishes the case, and the reported address is a real address inside a real section. That is the signature of a name-only distinction being ignored, and the habit to build is to treat a section name as data whenever the format lets two sections be otherwise identical." onclick="checkQuiz('quiz-coff-tls-2', this)">It is applying the ordinary address formula to symbols in a <code>.tls$</code> section and reporting an address inside the initial-value template. Fix it by special-casing the section <em>name</em> and reporting the symbol's offset as a per-thread offset, explicitly not an address</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth checking and it is the first thing to try, but the evidence is against it. The tool is reporting real addresses inside a real section, so it read the section table successfully, and section 4 in the object exists with a normal header. A missing or renamed section would produce a failed lookup rather than a successful address, and the same applies to a symbol-section mismatch: a bad section number gives a wrong-looking section, but here the tool found a coherent one." onclick="checkQuiz('quiz-coff-tls-2', this)">The section table indices are off by one, so symbols in the last section resolve to the section before it and land in a section that happens to be named <code>.tls$</code></button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when two sections in a format are allowed to be identical in every numeric field, the name is the only discriminator &mdash; so treat names as data, and check the name before trusting any derived value.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Two threads of this course meet here. The first is the <a href="/courses/coff/lessons/coff-section-table">section characteristics</a>: those flags are not a description, they are instructions, and this concept found a case where the instructions say something ordinary and the name says something else. <a href="/courses/coff/lessons/coff-linking">The link concept</a> then showed what happens when the instructions are obeyed &mdash; and the <code>.tls$</code> to <code>.tls</code> rename is a third transformation it did not cover, visible only in a map file from a link that failed for an unrelated reason.</p>
                <p>The second thread is the one about <strong>addresses not being constants</strong>. <a href="/courses/coff/lessons/coff-relocations">Relocations</a> exist because a symbol's address is not known when the code is written. TLS pushes that one step further: the address is not even a constant once the program is running, because it differs per thread. Every relocation mechanism in this course has assumed a program has one set of addresses; this is the case where that assumption is false, and the format's response &mdash; a section that holds values rather than variables &mdash; is a genuine change of level rather than another relocation type.</p>
                <p>Which is a good note to end the module's format coverage on before the last two concepts, because both of them are the same idea seen from opposite ends. This one carries information that only the <em>loader</em> can use, at run time, per thread. The next one carries information that only the <em>linker</em> can use, at link time, and is thrown away immediately after.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-weak-externals">Weak Externals</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-arm64">Previous: ARM64 Relocations</a></span>
                <span><a href="/courses/coff/lessons/coff-weak-externals">Next: Weak Externals</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
