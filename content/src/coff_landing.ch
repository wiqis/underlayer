// COFF Course — Landing Page (static build).
// Shows the course structure and links to each concept.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("COFF Common Object File Format — Underlayer")
    page.appendTitle(&title)

    #html {
        <a href="#main-content" class="skip-link">Skip to content</a>
        <div class="navbar">
            <div class="nav-inner">
                <a href="/" class="nav-brand">Underlayer</a>
                <div class="nav-links">
                    <a href="/" class="nav-link">Home</a>
                    <a href="/courses/coff" class="nav-link active">Courses</a>
                    <a href="/dashboard" class="nav-link">Dashboard</a>
                    <a href="/review" class="nav-link">Review</a>
                    <a href="/progress" class="nav-link">Progress</a>
                </div>
            </div>
        </div>

        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>COFF &mdash; Common Object File Format</h1>
                <p class="course-description">The container a compiler hands the linker. COFF is why a function compiled in one file can be called from another: the compiler writes down the question instead of the answer, and the relocation table holds the questions. It is also, deliberately, not a format you can run &mdash; which is the one field that tells you so.</p>
                <div class="course-meta">
                    <span class="meta-item">4 modules</span>
                    <span class="meta-item">14 concepts</span>
                    <span class="meta-item">Intermediate</span>
                    <span class="meta-item">~256 min</span>
                </div>
            </div>

            <div class="callout callout-tip">
                <strong>What you need first.</strong> This course assumes you can read an ELF section header table and you are comfortable with hexadecimal and little-endian integers. If either is shaky, start with <a href="/courses/elf/lessons/section-header-table">The ELF Section Header Table</a> &mdash; about twenty minutes, and the two formats share enough vocabulary that the second one is much cheaper.
            </div>

            <div class="callout callout-warn">
                <strong>How this course was verified.</strong> Every hex dump, offset and field size comes from real object files produced by <code>clang</code> for three targets, decoded by a parser written from the specification and then required to agree with <code>llvm-readobj</code> and <code>llvm-objdump</code> field by field. That process found three places where the documented layout and the actual bytes disagree &mdash; the section-definition aux record, the x64 relocation packing, and the alignment bitfield &mdash; and those are taught here rather than smoothed over. Where something could not be produced on this machine it is marked, not guessed.
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: The Relocatable Object</h2>
                    <p>What the file is for, the 20-byte header that identifies it, the 40-byte section header that describes its parts, and the characteristics field the linker obeys.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/coff/lessons/coff-intro">Why COFF Exists</a> <span class="concept-time">14 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-file-header">The File Header</a> <span class="concept-time">16 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-section-table">The Section Header</a> <span class="concept-time">18 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-characteristics">Section Characteristics</a> <span class="concept-time">17 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: Symbols and Relocations</h2>
                    <p>The tables that make an object relocatable: names, symbols, the questions a linker must answer, and the mechanism that lets duplicate sections be discarded safely.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/coff/lessons/coff-string-table">The String Table</a> <span class="concept-time">15 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-symbol-table">The Symbol Table</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-relocations">Relocations</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-comdat">COMDAT and Duplicate Sections</a> <span class="concept-time">19 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Containers and Variants</h2>
                    <p>What surrounds the object file: the archive that holds a hundred of them, the format variant for files too large to describe, and the one section-header field pair that no compiler here fills in.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/coff/lessons/coff-bigobj">bigobj</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-archives">The .lib Archive</a> <span class="concept-time">19 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-line-numbers">Line Numbers</a> <span class="concept-time">16 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: The Link</h2>
                    <p>What the linker does to an object, run for real. A <code>COFF</code> object has no addresses, and after a link
                    it has nothing but addresses &mdash; so the relocations, the COMDAT contract and the section flags from the first
                    three modules are all spent here, in that order. Three concepts, and one reproduced bug.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/coff/lessons/coff-linking">The Link</a> <span class="concept-time">23 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-map-files">Map Files</a> <span class="concept-time">18 min</span></li>
                        <li><a href="/courses/coff/lessons/coff-comdat-linking">COMDAT in the Linker</a> <span class="concept-time">21 min</span></li>
                    </ul>
                </div>
            </div>

            <div class="course-footer-note">
                <p>The PE course decodes the same <code>IMAGE_FILE_HEADER</code> and the same 40-byte section header, but inside a file that can be executed. Reading the two courses together is the fastest way to see what &ldquo;PE is COFF plus an optional header&rdquo; actually means in bytes. Sample objects used throughout are in <code>courses/coff/assets/samples/</code>, along with the independent parser and the cross-check script that produced every number here.</p>
            </div>
        </div>
    }

    #css {
        body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; margin: 0; color: #111827; background: #ffffff; }
        .skip-link { position: absolute; left: -9999px; }
        .skip-link:focus { left: 1rem; top: 1rem; background: #ffffff; padding: 0.5rem 0.75rem; border: 2px solid #3b82f6; z-index: 100; }
        .navbar { background: #111827; color: #ffffff; padding: 0.75rem 1rem; }
        .nav-inner { max-width: 900px; margin: 0 auto; display: flex; align-items: center; gap: 1.5rem; }
        .nav-brand { color: #ffffff; font-weight: 700; text-decoration: none; }
        .nav-links { display: flex; gap: 1rem; margin-left: auto; }
        .nav-link { color: #d1d5db; text-decoration: none; font-size: 0.9rem; }
        .nav-link:hover, .nav-link.active { color: #ffffff; text-decoration: underline; }
        .course-landing { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem 4rem; }
        .course-header h1 { font-size: 2rem; margin: 0 0 0.5rem; }
        .course-description { color: #4b5563; font-size: 1.05rem; }
        .course-meta { display: flex; flex-wrap: wrap; gap: 0.75rem; margin: 1rem 0 1.5rem; }
        .meta-item { background: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 999px; padding: 0.2rem 0.75rem; font-size: 0.8rem; color: #374151; }
        .callout { padding: 0.85rem 1rem; margin: 1.25rem 0; border-radius: 6px; font-size: 0.95rem; }
        .callout-tip { background: #eff6ff; border-left: 4px solid #3b82f6; }
        .callout-warn { background: #fffbeb; border-left: 4px solid #d97706; }
        .module-list { display: flex; flex-direction: column; gap: 1.75rem; margin-top: 2rem; }
        .module h2 { font-size: 1.2rem; margin: 0 0 0.35rem; }
        .module > p { color: #4b5563; margin: 0 0 0.5rem; }
        .concept-list { list-style: none; padding: 0; margin: 0.5rem 0 0; }
        .concept-list li { padding: 0.5rem 0; border-bottom: 1px solid #e5e7eb; display: flex; justify-content: space-between; gap: 1rem; align-items: baseline; }
        .concept-list li:last-child { border-bottom: none; }
        .concept-list a { color: #2563eb; text-decoration: none; }
        .concept-list a:hover { text-decoration: underline; }
        .concept-time { color: #6b7280; font-size: 0.85rem; white-space: nowrap; }
        .module-planned { opacity: 0.85; }
        .module-planned .concept-list li { color: #6b7280; }
        .module-note { font-size: 0.9rem; color: #6b7280; font-style: italic; }
        .course-footer-note { margin-top: 2.5rem; padding-top: 1.25rem; border-top: 1px solid #e5e7eb; color: #4b5563; font-size: 0.95rem; }
        code { background: #f3f4f6; padding: 0.15rem 0.4rem; border-radius: 4px; font-family: ui-monospace, monospace; font-size: 0.9em; }
        @media (max-width: 640px) { .course-landing { padding: 1.5rem 1rem 3rem; } .nav-links { display: none; } }
    }

    return page.toString()
}
}
