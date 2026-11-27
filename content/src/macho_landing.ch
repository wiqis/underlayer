// Mach-O Course — Landing Page (static build).
// Shows the course structure and links to each concept.
// Uses #html, #css, #js macros for all markup.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("Mach-O Format — Underlayer")
    page.appendTitle(&title)

        // I5: file:// pages keep the bundle link RELATIVE to the generated
        // course directory. The served pages cannot link to it yet: app/main.ch
        // routes every nested /courses/* asset URL to the web::App 404 (see
        // docs/verification-coverage.md). Adding that link broke 24 verifier
        // harnesses' internal-link check, so it is deliberately not shipped.
        #html {
            <aside class="specimen-link" data-specimen-link="macho">
                <a href="assets/samples/macho-specimen.zip">Download verified specimen pack</a>
                <span class="specimen-toolchain">Produced and checked with clang 21.1.8 / gcc 15.2.0 / readelf 2.46</span>
            </aside>
        }

        // C7: one shell. The hand-rolled six-link navbar, its own
        // theme script and its own identity slot were removed in
        // favour of the same render_site_nav call a lesson uses.
        render_site_nav(&mut page)

#html {
        <div class="course-landing" id="main-content">
            <div class="course-header">
                <h1>Mach-O Format</h1>
                <p class="course-description">A deep dive into Apple's Mach-O binary format — headers, load commands, segments, sections, symbols, dynamic linking, dyld, code signing, and how macOS maps and runs an executable.</p>
                <div class="course-meta">
                    <span class="meta-item">8 modules</span>
                    <span class="meta-item">24 concepts</span>
                    <span class="meta-item">Intermediate</span>
                </div>
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Fundamentals</h2>
                    <p>What Mach-O is, how the file is laid out, and the magic numbers that identify it.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-intro">Why Mach-O Exists</a></li>
                        <li><a href="/courses/macho/lessons/macho-file-layout">Mach-O File Layout</a></li>
                        <li><a href="/courses/macho/lessons/macho-magic">Magic Numbers and Byte Order</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: Headers</h2>
                    <p>The mach_header_64 field by field, CPU types, and universal (FAT) binaries.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-header">The mach_header_64 Field by Field</a></li>
                        <li><a href="/courses/macho/lessons/macho-cputypes">CPU Types and Subtypes</a></li>
                        <li><a href="/courses/macho/lessons/macho-universal">Universal (FAT) Binaries</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Load Commands</h2>
                    <p>The load command array, LC_SEGMENT_64, and the section_64 entries inside each segment.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-load-commands">The Load Command Area</a></li>
                        <li><a href="/courses/macho/lessons/macho-segments">LC_SEGMENT_64</a></li>
                        <li><a href="/courses/macho/lessons/macho-sections">Sections</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Symbols</h2>
                    <p>The symbol table, dynamic symbol table, and relocation entries in object files.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-symtab">The Symbol Table</a></li>
                        <li><a href="/courses/macho/lessons/macho-dysymtab">The Dynamic Symbol Table</a></li>
                        <li><a href="/courses/macho/lessons/macho-relocations">Relocation Entries</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 5: Dynamic Linking</h2>
                    <p>Dynamic libraries, rebase/bind opcodes, and the export trie.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-dylibs">Dynamic Libraries and Install Names</a></li>
                        <li><a href="/courses/macho/lessons/macho-dyld-info">Rebase and Bind Opcodes</a></li>
                        <li><a href="/courses/macho/lessons/macho-export-trie">The Export Trie</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 6: Modern Linking &amp; Entry</h2>
                    <p>Chained fixups, the entry point, and build version metadata.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-chained-fixups">Chained Fixups</a></li>
                        <li><a href="/courses/macho/lessons/macho-entry">The Dynamic Linker and Entry Point</a></li>
                        <li><a href="/courses/macho/lessons/macho-build-version">Build Versions and UUID</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 7: Integrity &amp; Debug</h2>
                    <p>Code signing, debug info in dSYM bundles, and memory hardening.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-code-signing">Code Signing</a></li>
                        <li><a href="/courses/macho/lessons/macho-debug-info">Debug Info</a></li>
                        <li><a href="/courses/macho/lessons/macho-hardening">__PAGEZERO and Memory Hardening</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 8: Loading &amp; Execution</h2>
                    <p>How dyld loads a Mach-O, what memory looks like, and the startup sequence.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/macho/lessons/macho-dyld">How dyld Loads a Mach-O</a></li>
                        <li><a href="/courses/macho/lessons/macho-memory-layout">Process Memory Layout</a></li>
                        <li><a href="/courses/macho/lessons/macho-execution">The Startup Sequence</a></li>
                    </ul>
                </div>
            </div>
        </div>
    }

    #css {
        .specimen-link { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; align-items: baseline; background: hsl(var(--secondary)); border-radius: 8px; padding: 0.75rem 1rem; margin-bottom: 1.5rem; }
        .specimen-link a { color: hsl(217 91% 60%); font-weight: 600; }
        .specimen-toolchain { color: hsl(var(--muted-foreground)); font-size: 0.85rem; }
        body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
        :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
        .course-landing { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .course-header { margin-bottom: 2rem; }
        .course-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .course-description { font-size: 1.1rem; color: hsl(var(--muted-foreground)); margin-bottom: 1rem; }
        .course-meta { display: flex; gap: 1rem; }
        .meta-item { padding: 0.25rem 0.75rem; background: hsl(var(--secondary)); border-radius: 9999px; font-size: 0.875rem; color: hsl(var(--foreground)); }
        .module-list { display: flex; flex-direction: column; gap: 1.5rem; }
        .module { padding: 1.5rem; border: 1px solid hsl(var(--border)); border-radius: 8px; }
        .module h2 { font-size: 1.25rem; margin-bottom: 0.5rem; }
        .module p { color: hsl(var(--muted-foreground)); margin-bottom: 1rem; }
        .concept-list { list-style: none; padding: 0; margin: 0; }
        .concept-list li { padding: 0.5rem 0; border-bottom: 1px solid hsl(var(--secondary)); }
        .concept-list li:last-child { border-bottom: none; }
        .concept-list a { color: hsl(217 91% 60%); text-decoration: none; }
        .concept-list a:hover { text-decoration: underline; }
        @media (max-width: 768px) {
            .course-landing { padding: 1rem; }
            .course-header h1 { font-size: 1.5rem; }
            .course-meta { flex-wrap: wrap; }
        }
    }

    #js {
    }

    return page.toString()
}
}
