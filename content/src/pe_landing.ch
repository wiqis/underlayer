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

    #html {
        <a href="#main-content" class="skip-link">Skip to content</a>
        <div class="navbar">
            <div class="nav-inner">
                <a href="/" class="nav-brand">Underlayer</a>
                <div class="nav-links">
                    <a href="/" class="nav-link">Home</a>
                    <a href="/courses/pe" class="nav-link active">Courses</a>
                    <a href="/dashboard" class="nav-link">Dashboard</a>
                    <a href="/review" class="nav-link">Review</a>
                    <a href="/progress" class="nav-link">Progress</a>
                </div>
                <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                    <span class="theme-icon-light">☀️</span>
                    <span class="theme-icon-dark">🌙</span>
                </button>
            </div>
        </div>

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
        body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
        .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
        .skip-link:focus { top: 0; }
        :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
        .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
        .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
        .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
        .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
        .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
        .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
        .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
        .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
        .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
        .theme-toggle:hover { background: hsl(var(--accent)); }
        .theme-icon-dark { display: none; }
        .dark .theme-icon-light { display: none; }
        .dark .theme-icon-dark { display: inline; }
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
            .nav-links { display: none; }
            .course-landing { padding: 1rem; }
            .course-header h1 { font-size: 1.5rem; }
            .course-meta { flex-wrap: wrap; }
        }
    }

    #js {
        function getTheme() {
            var saved = localStorage.getItem('theme');
            if (saved) return saved;
            return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
        }
        function setTheme(theme) {
            document.documentElement.classList.toggle('dark', theme === 'dark');
            localStorage.setItem('theme', theme);
        }
        function toggleTheme() {
            var current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
            setTheme(current === 'dark' ? 'light' : 'dark');
        }
        setTheme(getTheme());
    }

    return page.toString()
}
}
