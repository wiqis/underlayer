// PE Course — Landing Page (static build).
// Shows the course structure and links to each concept.
// Uses #html, #css, #js macros for all markup.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("Portable Executable Format — Underlayer")
    page.appendTitle(&title)

        // I5: file:// pages keep the bundle link RELATIVE to the generated
        // course directory. The served pages cannot link to it yet: app/main.ch
        // routes every nested /courses/* asset URL to the web::App 404 (see
        // docs/verification-coverage.md). Adding that link broke 24 verifier
        // harnesses' internal-link check, so it is deliberately not shipped.
        #html {
            <aside class="specimen-link" data-specimen-link="pe">
                <a href="assets/samples/pe-specimen.zip">Download verified specimen pack</a>
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
                <h1>Portable Executable Format</h1>
                <p class="course-description">A deep dive into the Windows PE binary format — DOS and COFF headers, optional header, data directories, sections, imports, exports, relocations, resources, and how the Windows loader maps and runs an image.</p>
                <div class="course-meta">
                    <span class="meta-item">8 modules</span>
                    <span class="meta-item">24 concepts</span>
                    <span class="meta-item">Intermediate</span>
                </div>
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Fundamentals</h2>
                    <p>What PE is, how the file is layered, and its COFF heritage.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-intro">Why PE Exists</a></li>
                        <li><a href="/courses/pe/lessons/pe-file-layout">PE File Layout</a></li>
                        <li><a href="/courses/pe/lessons/pe-coff-basics">The COFF Heritage</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: Headers</h2>
                    <p>The DOS header, the PE signature with its COFF header, and the optional header.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-dos-header">The MS-DOS Header</a></li>
                        <li><a href="/courses/pe/lessons/pe-signature-coff">PE Signature and COFF Header</a></li>
                        <li><a href="/courses/pe/lessons/pe-optional-header">The Optional Header</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Addressing &amp; Data Directories</h2>
                    <p>The 16 data directories, the VA/RVA/file-offset model, and converting between them.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-data-directories">The Data Directories</a></li>
                        <li><a href="/courses/pe/lessons/pe-addresses">VA, RVA, and File Offset</a></li>
                        <li><a href="/courses/pe/lessons/pe-rva-conversion">Converting RVAs to File Offsets</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Sections</h2>
                    <p>The section table, the sections every PE has, and alignment rules.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-section-table">The Section Table</a></li>
                        <li><a href="/courses/pe/lessons/pe-common-sections">Common Sections</a></li>
                        <li><a href="/courses/pe/lessons/pe-alignment">Alignment: FileAlignment vs SectionAlignment</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 5: Imports &amp; Exports</h2>
                    <p>How an image consumes DLL functions, publishes its own, and defers loading.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-imports">The Import Tables</a></li>
                        <li><a href="/courses/pe/lessons/pe-exports">The Export Tables</a></li>
                        <li><a href="/courses/pe/lessons/pe-delay-loads">Delay-Load Imports</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 6: Relocations &amp; Hardening</h2>
                    <p>Moving an image off its preferred base, and the flags and structures that harden it.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-base-relocations">Base Relocations</a></li>
                        <li><a href="/courses/pe/lessons/pe-security-flags">Security &amp; Subsystem Flags</a></li>
                        <li><a href="/courses/pe/lessons/pe-load-config">The Load Configuration</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 7: Resources &amp; Runtime Tables</h2>
                    <p>Icons and strings in .rsrc, thread-local storage, and x64 exception tables.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-resources">The Resource Directory</a></li>
                        <li><a href="/courses/pe/lessons/pe-tls">Thread-Local Storage</a></li>
                        <li><a href="/courses/pe/lessons/pe-exceptions">Exception Tables (.pdata)</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 8: Loading &amp; Execution</h2>
                    <p>How Windows maps the image, what memory looks like, and how execution starts.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/pe/lessons/pe-loader">How the Windows Loader Maps a PE</a></li>
                        <li><a href="/courses/pe/lessons/pe-memory-layout">Process Memory Layout</a></li>
                        <li><a href="/courses/pe/lessons/pe-execution">The Startup Sequence</a></li>
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
