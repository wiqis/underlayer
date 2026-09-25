// COFF Course — Module 1: The Relocatable Object
// Concept: why objects exist, and what "relocatable" actually means.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why COFF Exists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Why COFF Exists</h1>
            <div class="lesson-meta">14 min &middot; Module 1: The Relocatable Object &middot; Orientation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You have written <code>int add(int a, int b)</code> and called it from another file, and it worked. Something had to work out what the address of <code>add</code> actually <em>is</em> &mdash; because the compiler that compiled the caller did not know where the function would end up, and neither did the compiler that compiled it.</p>
                <p>COFF is the container that lets a compiler hand the linker a half-finished answer. It is the format of the <code>.obj</code> file on Windows and of the object files the GNU toolchain produces for Windows targets. It is also, deliberately, <strong>not</strong> a format you can run.</p>
                <p>You already know its sibling. The <a href="/courses/pe/lessons/pe-coff-basics">PE course covers the COFF header</a> as it appears inside a PE executable. This course covers the other half: the file that exists <em>before</em> the link, where addresses are still unknown and a table of "fix these up" is the whole point.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Compiling and linking are two different jobs, and the boundary between them is what COFF is built around:</p>
                <ol>
                    <li><strong>The compiler</strong> turns one source file into one object. It can resolve everything <em>inside</em> that file, because it can see all of it. It cannot resolve anything across files, because the other file has not been compiled yet, and even if it had, the answer depends on the order things get placed in memory.</li>
                    <li><strong>So it writes down the question instead of the answer.</strong> Wherever the code contains something whose value depends on layout, the compiler leaves a zero and a note: "at this offset, put the address of that symbol here."</li>
                    <li><strong>The linker</strong> concatenates the objects, decides where everything goes, and then answers every note.</li>
                </ol>
                <p>Those notes are <strong>relocations</strong>. They are the entire reason this file format exists, and the entire reason the file has no addresses in it.</p>
                <div class="callout callout-warn">
                    <strong>The simplification is the point, not a flaw.</strong> "No addresses at all" is close to true and worth stating sharply: in every section of every object in this course, <code>VirtualAddress</code> is exactly zero. The one qualification is that a symbol's <em>offset within its own section</em> is known and stored &mdash; a function at offset 80 of <code>.text</code> is a fact the compiler can record, because the section is its own private space for now. It is only the section's own eventual address that is unknown.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The sample used throughout this course is one small C file, compiled to a real COFF object:</p>
                <pre><code>int add(int a, int b) &#123; return a + b; &#125;

int g_data = 42;
int g_bss;
static int s_data = 7;
const char g_str[] = "coff";
const char *g_ptr = "ptr";
int *g_addr = &amp;g_data;

int table[4] = &#123;1, 2, 3, 4&#125;;

int call_through(int (*fn)(int, int), int v) &#123; return fn(v, v); &#125;
int use(void) &#123; return call_through(add, g_data); &#125;</code></pre>
                <p>That is 21 lines, and it produces a 1455-byte object. Almost all of the interest is in the parts that are <em>not</em> code: the file header says there is no optional header at all, the section table says every address is zero, and three relocation records sit in a side table saying where the linker owes answers.</p>
                <p>Here is the whole file, laid out by region. Sizes and offsets are read out of the file itself:</p>
                <table>
                    <thead>
                        <tr><th scope="col">File offset</th><th scope="col">Size</th><th scope="col">What it is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>20</td><td>File header. 7 fields. No magic number.</td></tr>
                        <tr><td>0x14</td><td>9 &times; 40 = 360</td><td>Section table. One 40-byte record per section.</td></tr>
                        <tr><td>0x17C</td><td>108</td><td><code>.text</code> raw bytes &mdash; the actual machine code</td></tr>
                        <tr><td>0x1E8</td><td>30</td><td><code>.text</code> relocations: 3 records of 10 bytes</td></tr>
                        <tr><td>0x206</td><td>48</td><td><code>.data</code> raw bytes</td></tr>
                        <tr><td>0x236</td><td>20</td><td><code>.data</code> relocations: 2 records</td></tr>
                        <tr><td>0x348</td><td>31 &times; 18 = 558</td><td>Symbol table</td></tr>
                        <tr><td>0x576</td><td>57</td><td>String table, running to the last byte of the file</td></tr>
                    </tbody>
                </table>
                <p>Two things about that table are worth pausing on, because neither is how ELF is arranged.</p>
                <p><strong>Relocations do not sit next to their code.</strong> The three <code>.text</code> records are at 0x1E8, immediately after the 108 bytes of <code>.text</code> that they describe &mdash; but that is a coincidence of this file's layout, not a rule. Every section has its own <code>PointerToRelocations</code>, and the linker seeks to each independently. A section's relocations can be anywhere in the file, or immediately before the code, or at the very end.</p>
                <p><strong>There is no magic number.</strong> A COFF object begins straight into the header, and there is nothing to identify it. The <code>file</code> utility reports <code>x86-64 COFF object file</code> by inferring from the plausible field values, not by matching a signature. This is a real weakness: a file with garbage in its first twenty bytes is not rejected, it is misinterpreted. Contrast the ELF magic <code>7f 45 4c 46</code>, which you met in <a href="/courses/elf/lessons/elf-identification">ELF identification</a>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here is the payoff, in the first twenty bytes of the real object. There is no magic number, no version, no class byte &mdash; just seven fields:</p>
                <div class="hex-dump">
                    <pre>00000000: 6486 0900 2aa5 b66a 4803 0000 1f00 0000  d...*..jH.......
00000010: 0000 0000 2e74 6578 7400 0000 0000 0000  .....text.......
00000020: 0000 0000 6c00 0000 7c01 0000 e801 0000  ....l...|.......
00000030: 0000 0000 0300 0000 2000 5060 2e64 6174  ........ .P`.dat</pre>
                </div>
                <p>Two of those bytes do more work than all the others together. Offset 0x10 and 0x11 are <code>00 00</code>: <code>SizeOfOptionalHeader = 0</code>. In a PE executable that field holds 224 or 240, because an executable needs a place to record its entry point, its image base, and sixteen data directories. An object needs none of those things, so the field is zero and the optional header simply is not there.</p>
                <p>That single value is the cleanest possible definition of the difference between the two formats:</p>
                <ul>
                    <li><strong>PE image</strong> &mdash; <code>SizeOfOptionalHeader</code> non-zero. Has addresses, an entry point, data directories. The OS can run it.</li>
                    <li><strong>COFF object</strong> &mdash; <code>SizeOfOptionalHeader</code> zero. Has relocations instead. Only a linker can consume it.</li>
                </ul>
                <p>Both carry the identical 20-byte <code>IMAGE_FILE_HEADER</code> at offset 0. That is the whole relationship between them: <strong>PE is a COFF header plus an optional header plus more</strong>. The PE course starts where this one stops.</p>
                <p>Also note the third line: byte 0x14 is <code>2e</code>, a full stop. That is not part of the header &mdash; the header ended at 0x13. It is the first byte of the first section's name, <code>.text</code>, which is how we know the section table begins at 0x14 and not somewhere else.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <p>Build the reference object. This is the exact command behind every byte in this course:</p>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ file sample_msvc.obj
sample_msvc.obj: x86-64 COFF object file, not stripped, 9 sections,
                 symbol offset=0x348, 31 symbols, ..., 1st section name ".text"</code></pre>
                <p>Then produce two more dialects of the same source, and watch how little changes:</p>
                <pre><code>$ clang --target=x86_64-w64-windows-gnu -c sample.c -o sample_gnu.obj
$ clang --target=i686-pc-windows-msvc     -c sample.c -o sample_m32.obj
$ file sample_*.obj</code></pre>
                <p>What to look for: the GNU build has <strong>8</strong> sections, not 9, and the i386 build reports <code>symbol offset=0x254</code> with 27 symbols. Same source, three objects, three different answers. The container is identical in all three; the content is a dialect. Module 1 and Module 2 are about the container.</p>
                <p>For the tools used throughout: the full LLVM suite sits beside <code>clang</code>, so <code>llvm-readobj</code> and <code>llvm-objdump</code> are usually available once you add that directory to your <code>PATH</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are handed a file whose <code>SizeOfOptionalHeader</code> is zero. Can the operating system run it?</p>
                <div class="quiz" id="quiz-coff-intro-1">
                    <button class="quiz-option" data-correct="true" data-explain="A zero SizeOfOptionalHeader means there is no optional header at all, so the file carries no entry point, no image base and no data directories. The OS loader has nothing to work with, and the file instead carries relocations that only a linker can resolve. The OS will reject it as a bad executable format." onclick="checkQuiz('quiz-coff-intro-1', this)">No. There is no entry point and no data directories, because a zero optional header means they are not there. Only a linker can consume it</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero optional header is not a hint that the loader should fall back to defaults; it means the structure is absent. A PE image with no entry point cannot be started, and the loader does not guess one." onclick="checkQuiz('quiz-coff-intro-1', this)">Yes. The loader falls back to a default entry point when the optional header is absent</button>
                    <button class="quiz-option" data-correct="false" data-explain="The linker does not execute anything, so it is not the thing that runs the file either. This option confuses the consumer of the object (the linker) with the consumer of a linked image (the OS loader)." onclick="checkQuiz('quiz-coff-intro-1', this)">No, but the linker can run it by resolving the relocations at load time</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A colleague hands you a COFF object and says "it crashed". You spend ten minutes looking for the bug in the C code before you realise what is wrong with their diagnosis. What is the actual problem with debugging a relocatable object?</p>
                <div class="quiz" id="quiz-coff-intro-2">
                    <button class="quiz-option" data-correct="true" data-explain="An object is not a program. Its relocations are unresolved questions, its sections have no addresses, and its code contains zeros where the address of add or g_data should be. Executing it directly cannot work, so there is no crash to diagnose. The workflow has to be: link it with its dependencies, then debug the link result." onclick="checkQuiz('quiz-coff-intro-2', this)">An object cannot be executed at all, so there is no crash to debug. Its relocations are unresolved and its sections have no addresses, so you have to link it first and debug the linked result</button>
                    <button class="quiz-option" data-correct="false" data-explain="A relocatable object has no entry point to jump to, so the debugger has nowhere to start. That is part of why the object cannot be run, but the deeper issue is that the code itself is incomplete, not merely unentrypointed." onclick="checkQuiz('quiz-coff-intro-2', this)">The symbols are stripped, so the debugger cannot map the crash address to a function name</button>
                    <button class="quiz-option" data-correct="false" data-explain="Symbol names are present and readable in an object, which is exactly how the linker finds what to resolve. The unresolved thing is not the names but the addresses those names will be given, which live in the relocation table." onclick="checkQuiz('quiz-coff-intro-2', this)">The section table is incomplete, so the debugger cannot find the code section</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: before debugging a binary artifact, check which stage of the toolchain produced it. A file that is "supposed to run" but does not is very often a file that was never meant to.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The closest thing to this in the ELF course is the relationship between a relocatable object and a linked executable &mdash; but the containers are more different than ELF's are. An ELF object keeps relocations in a section; a COFF object keeps them in a side table that the section header points at, one table per section. The idea is identical, the layout is not.</p>
                <p>You now know what the file is for. The next three concepts take it apart: the 20-byte header, the 40-byte section header, and the characteristics bitfield that is more subtle than it looks.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-file-header">The File Header</a> &mdash; all seven fields, and the machine types that tell you how wide the pointers are.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff">Course home</a></span>
                <span><a href="/courses/coff/lessons/coff-file-header">Next: The File Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
