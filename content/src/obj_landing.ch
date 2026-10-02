// Object Files Course — Landing Page (static build).
// Shows the course structure and links to each concept.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("Object Files — Underlayer")
    page.appendTitle(&title)

            // THE PRE-PAINT THEME.  These landing pages hand-roll their navbar
        // instead of calling render_site_nav, so they are the only pages that
        // would miss the <head> theme script and therefore the only pages that
        // paint light first and repaint -- the flash reported on 2026-10-02.
        // Measured before this: 0 of 432 static pages carried it.
        //
        // The real fix is to call render_site_nav here like every other page.
        // That is a layout change to seven pages and belongs in its own commit;
        // until then these two lines are what stops them flashing, and this
        // comment is what stops the next reader from thinking the duplication
        // is accidental.
        render_theme_boot_js(&mut page, false)
        render_color_scheme_meta(&mut page)

#html {
        <a href="#main-content" class="skip-link">Skip to content</a>
        <div class="navbar">
            <div class="nav-inner">
                <a href="/" class="nav-brand">Underlayer</a>
                <div class="nav-links">
                    <a href="/" class="nav-link">Home</a>
                    <a href="/courses/obj" class="nav-link active">Courses</a>
                    <a href="/dashboard" class="nav-link">Dashboard</a>
                    <a href="/review" class="nav-link">Review</a>
                    <a href="/progress" class="nav-link">Progress</a>
                </div>
            </div>
        </div>

        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>Object Files</h1>
                <p class="course-description">The intermediate artefact every compiler emits and no programmer ever sees. One C file compiled three ways, and the holes left behind for a linker to fill. The fixup record, the three symbol table designs, COMMON and its ABI break, COMDAT, archives &mdash; and the whole business of emitting an object file that a linker will actually accept.</p>
                <div class="course-meta">
                    <span class="meta-item">5 modules</span>
                    <span class="meta-item">18 concepts</span>
                    <span class="meta-item">Intermediate</span>
                    <span class="meta-item">~362 min</span>
                </div>
            </div>

            <div class="callout callout-tip">
                <strong>What you need first.</strong> This course assumes the <a href="/courses/elf">ELF course</a>, and specifically its section header table, symbol table and relocation entries. Nothing here is ELF-specific &mdash; the whole point is to compare formats &mdash; but you need one format in your hands before the comparisons mean anything. <a href="/courses/coff">COFF</a> and <a href="/courses/macho">Mach-O</a> are useful but not required; this course teaches their object-file halves side by side anyway.
            </div>

            <div class="callout callout-warn">
                <strong>How this course was verified.</strong> Every hex dump, offset, field size and bit position in this course comes from real object files produced on this machine by <code>clang</code> 21.1.8 for three targets, decoded by a parser written from the specifications and then required to agree with <code>llvm-readobj</code> and <code>llvm-objdump</code> field by field. That process <strong>corrected three claims that had been written from documentation and were wrong</strong>: where an addend actually lives, whether Mach-O has a <code>linkonce</code> section type at all, and whether ELF needs two string tables. They are taught here as the corrections they are. Where something could not be produced on this machine &mdash; there is no Mach-O linker and no AArch64 linker here &mdash; the concept says so instead of guessing.
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Why Object Files Exist</h2>
                    <p>What a relocatable file is, what &ldquo;relocatable&rdquo; means in practice, and the one table an object file has that an executable has two of.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/obj/lessons/obj-intro">The Middle of Every Build</a> <span class="concept-time">18 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-triangulate">One Source, Three Formats</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-no-segments">No Segments, and Why</a> <span class="concept-time">16 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: Anatomy, Compared</h2>
                    <p>Where names, code and data actually live &mdash; and the three incompatible answers to each question. One object file has no addresses, two sections can share a name, and one symbol's value is not a value.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/obj/lessons/obj-sections">Sections, Compared</a> <span class="concept-time">21 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-strings">Where Names Live</a> <span class="concept-time">17 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a> <span class="concept-time">20 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: The Fixup</h2>
                    <p>The heart of the course, and the part a linker is actually made of. One record, three incompatible layouts; the arithmetic as a set of flags rather than a list; and position independence as a choice of which relocations to emit.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/obj/lessons/obj-relocations">The Fixup Record</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-addends">The Addend Lives in the Bytes</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-reloc-tables">The Object Relocation Sets</a> <span class="concept-time">22 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-pic">Position Independence</a> <span class="concept-time">24 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Merging and Selection</h2>
                    <p>How two objects that disagree become one. Which of two definitions survives, which of three hundred objects gets loaded at all, and what happens when nothing supplies a symbol at all &mdash; three questions, three mechanisms, three places in the file to put the answer.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/obj/lessons/obj-comdat-group">COMDAT, GROUP, linkonce</a> <span class="concept-time">19 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-archives">The Archive</a> <span class="concept-time">19 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-weak-undef">Weak and Undefined-Weak</a> <span class="concept-time">18 min</span></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 5: Emitting One</h2>
                    <p>The mission&rsquo;s destination. A complete, valid, linkable object file written byte by byte with no library, the encodings a fixup has to patch, and the oracle loop that tells you whether your emitter is wrong or the tool is.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/obj/lessons/obj-emit">Writing One From Scratch</a> <span class="concept-time">24 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-arch-table">The Encodings That Set Relocation Size</a> <span class="concept-time">20 min</span></li>
                        <li><a href="/courses/obj/lessons/obj-verify">Proving Your Object File Is Right</a> <span class="concept-time">18 min</span></li>
                    </ul>
                    <p class="module-note">The hand-built object is real and it is in the samples directory: <code>emit_elf.py</code> writes 936 bytes, GNU <code>ld</code> merges them with compiler-produced objects, and the resulting program prints the right answers. Four bugs were found while building it, and <strong>every one of them got past every available reader</strong> &mdash; which is what the last concept is about.</p>
                </div>
            </div>

            <div class="course-footer-note">
                <p>Samples for every claim are in <code>courses/obj/assets/samples/</code>, and every one of them is rebuilt by <code>sh build_samples.sh</code> &mdash; including a byte-reproducibility check, because the whole course rests on these being the same bytes next time. The directory also holds <code>crosscheck.py</code> (95 checks, three tiers of evidence), <code>ardec.py</code> (an archive parser written from the format description), and <code>aarch64_enc.py</code> (which encodes an AArch64 page delta and has an independent disassembler read it back).</p>
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
        .module-note { font-size: 0.9rem; color: #6b7280; font-style: italic; }
        .course-footer-note { margin-top: 2.5rem; padding-top: 1.25rem; border-top: 1px solid #e5e7eb; color: #4b5563; font-size: 0.95rem; }
        code { background: #f3f4f6; padding: 0.15rem 0.4rem; border-radius: 4px; font-family: ui-monospace, monospace; font-size: 0.9em; }
        @media (max-width: 640px) { .course-landing { padding: 1.5rem 1rem 3rem; } .nav-links { display: none; } }
    }

    return page.toString()
}
}
