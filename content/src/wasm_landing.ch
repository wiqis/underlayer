// WebAssembly Course — landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("WebAssembly — The Binary Format — Underlayer")
    page.appendTitle(&title)

    #css {
        .course-landing { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem 4rem; }
        .course-header { margin-bottom: 2rem; }
        .course-header h1 { font-size: 2.2rem; margin: 0 0 0.5rem; letter-spacing: -0.02em; }
        .course-description { color: #4b5563; line-height: 1.65; margin: 0 0 1.25rem; }
        .course-meta { display: flex; flex-wrap: wrap; gap: 0.5rem; }
        .meta-item { background: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 999px;
                     padding: 0.25rem 0.75rem; font-size: 0.85rem; color: #374151; }
        .module { margin: 2.5rem 0; }
        .module h2 { font-size: 1.35rem; margin: 0 0 0.5rem; }
        .module > p { color: #4b5563; line-height: 1.65; margin: 0 0 0.9rem; }
        .concept-list { list-style: none; padding: 0; margin: 0; }
        .concept-list li { border: 1px solid #e5e7eb; border-radius: 8px; padding: 0.7rem 0.9rem;
                           margin-bottom: 0.5rem; display: flex; justify-content: space-between;
                           align-items: baseline; gap: 1rem; background: #fff; }
        .concept-list a { color: #1d4ed8; text-decoration: none; font-weight: 500; }
        .concept-list a:hover { text-decoration: underline; }
        .concept-time { color: #6b7280; font-size: 0.85rem; white-space: nowrap; }
        .module-note { font-size: 0.9rem; color: #6b7280; margin-top: 0.75rem; line-height: 1.6; }
        .callout { border-left: 4px solid #3b82f6; background: #eff6ff; padding: 1rem 1.1rem;
                   border-radius: 0 8px 8px 0; margin: 1.5rem 0; line-height: 1.65; }
        .callout-warn { border-left-color: #f59e0b; background: #fffbeb; }
        .callout strong { display: block; margin-bottom: 0.35rem; }
        .course-footer-note { margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid #e5e7eb;
                              color: #6b7280; line-height: 1.65; font-size: 0.95rem; }
        code { background: #f3f4f6; padding: 0.1rem 0.3rem; border-radius: 4px; font-size: 0.9em; }
    }

    #html {
        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>WebAssembly &mdash; The Binary Format</h1>
                <p class="course-description">The container a compiler and a runtime agree on. A
                browser and a C++ compiler have nothing in common except this file, and the whole
                design is aimed at making that agreement checkable before anybody trusts it.</p>
                <div class="course-meta">
                    <span class="meta-item">5 modules</span>
                    <span class="meta-item">13 concepts</span>
                    <span class="meta-item">Intermediate</span>
                    <span class="meta-item">~274 min</span>
                </div>
            </div>

            <div class="callout callout-warn">
                <strong>What you need first.</strong> This course assumes you can read a binary header
                and a section table, so <a href="/courses/elf/lessons/elf-header-fields">ELF</a> or
                <a href="/courses/coff/lessons/coff-file-header">COFF</a> would both be useful
                preparation. You do not need to know anything about compilation, about runtimes, or
                about JavaScript.
            </div>

            <div class="callout">
                <strong>How this course was verified.</strong> Every offset, size and decoded value
                comes from real files on disk, and every claim is cross-checked against three
                independent implementations: a decoder written from the specification and shipped
                with this course, wabt's <code>wasm-objdump</code>, and LLVM's
                <code>llvm-objdump</code>. The harness that compares them is itself tested by
                injecting faults, and it is shipped too, so you can check its own claims. Where the
                tools disagree, the concept says so and shows the bytes that settle it.
            </div>

            <div class="module-list" id="module-list">
                <div class="module">
                    <h2>Module 1: The Container</h2>
                    <p>Everything in a WebAssembly module is one of three things: an eight-byte
                    header, a sequence of length-delimited sections, and a variable-width encoding
                    that almost every number in between uses. This module decodes all three, and the
                    through-line is how little redundancy the format has &mdash; which is exactly why
                    it needs three readers.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/wasm/lessons/wasm-intro">Why a Binary Format</a> <span class="concept-time">15 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-header">The Eight-Byte Header</a> <span class="concept-time">17 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-sections">Sections</a> <span class="concept-time">23 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-leb128">LEB128</a> <span class="concept-time">24 min</span></li>
                    </ul>
                    <p class="module-note">Two findings in this module are worth reading for even if you
                    skip the rest. One is a place where wabt and LLVM report different sizes for the
                    same custom section &mdash; not an error in either, but a trap for anything that
                    reads both. The other is that <code>wasm-objdump</code> prints <code>i32.const</code>
                    operands as unsigned, so a reader who takes its output as the constant is wrong on
                    exactly the values real code uses most.</p>
                </div>

                <div class="module">
                    <h2>Module 2: Declarations</h2>
                    <p>The four sections that say what a module <em>has</em> rather than what it
                    <em>does</em>. The through-line is that almost every fact in them is a number, and
                    that the numbers are positions in an index space whose rules are not obvious until
                    a module has an import in it.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/wasm/lessons/wasm-types">The Type Section</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-imports">Imports and Index Spaces</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-tables-memories">Tables, Memories and Limits</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-globals">Globals and Initialisers</a> <span class="concept-time">19 min</span></li>
                    </ul>
                    <p class="module-note">The idea to carry out of this module is the index space.
                    Imports are counted first, in five independent counters, so a module that imports
                    one function and defines two has functions 0, 1 and 2 with the two it defined at 1
                    and 2. Every reader that forgets the subtraction is wrong on exactly the modules
                    that have imports, and right on every module that does not.</p>
                </div>

                <div class="module">
                    <h2>Module 3: The Body</h2>
                    <p>The first part of the format that contains instructions rather than
                    declarations, and the two places where compactness made the encoding harder to
                    read than it needed to be.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/wasm/lessons/wasm-code">The Code Section</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-instructions">Instruction Encoding</a> <span class="concept-time">24 min</span></li>
                    </ul>
                    <p class="module-note">Both concepts turn on a field that says how long the next
                    thing is. A function body's local declarations are run-length encoded, so a
                    function with seven locals does not have seven local entries; and the
                    <code>align</code> immediate on a load is a base-2 logarithm, so
                    <code>i32.load</code> carries the number 2 and means four bytes. Both are correct
                    and both are read wrong by a decoder that assumes a simpler shape.</p>
                </div>

                <div class="module">
                    <h2>Module 4: Data Placement</h2>
                    <p>How tables and memories get filled. The element section has eight encodings for
                    one job, which is not redundancy but a record of four proposals arriving over
                    time, and it contains the single most dangerous byte in the format.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/wasm/lessons/wasm-elements">The Element Section</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/wasm/lessons/wasm-data">The Data Section and DataCount</a> <span class="concept-time">21 min</span></li>
                    </ul>
                    <p class="module-note">All eight element forms and all three data forms in this
                    course were verified, the last four element forms and all three data forms by
                    hand-assembling the bytes and confirming a second implementation accepts them,
                    because no available tool will emit them. The <code>0x00</code> elemkind byte is
                    worth reading about twice: it is not a value type, its only legal value is zero,
                    and a reader that expects <code>0x70</code> reports an empty segment for a
                    segment that has three elements in it.</p>
                </div>

                <div class="module">
                    <h2>Module 5: Objects and Tooling</h2>
                    <p>What a compiler emits before a linker has run, and the reason the core
                    specification can ignore the whole subject.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/wasm/lessons/wasm-objects">Objects, Linking and Relocations</a> <span class="concept-time">23 min</span></li>
                    </ul>
                    <p class="module-note">The finding that will bite you first is that every section
                    size in a real LLVM-produced object is a <strong>five-byte</strong> LEB128, where
                    one byte would do. A decoder written against the hand-built samples in this
                    course &mdash; which are the only files where the minimal encoding is correct
                    &mdash; fails on every section of every real object. Link <code>wasm-ld</code> is
                    not available in the environment this course was written in, so the output side of
                    linking is specified from the relocation records and stated as unobserved.</p>
                </div>
            </div>

            <div class="course-footer-note">
                <p>Every one of the thirteen concepts is written and every link resolves. The
                toolchain and the verification record, including the two things this course
                encountered and did not decode, are in <code>courses/wasm/research.md</code>.</p>
                <p>The WebAssembly binary format is also covered from the other side in the
                <a href="/courses/elf">ELF</a> and <a href="/courses/coff">COFF</a> courses, which
                decode the section-framing idea those formats share with it. And its text format, the
                one you write by hand, is a separate course that is not started.</p>
            </div>
        </div>
    }

    return page.toString()
}
}
