// ELF Course — Landing Page
// Shows the course structure and links to each concept.
// Uses #html, #css, #js macros for all markup.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_elf_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.injectDefaultComponentsTheme()
    var title = std::string_view("Executable and Linkable Format — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="navbar">
            <div class="nav-inner">
                <a href="/" class="nav-brand">Underlayer</a>
                <div class="nav-links">
                    <a href="/" class="nav-link">Home</a>
                    <a href="/courses/elf" class="nav-link active">Courses</a>
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

        <div class="course-landing">
            <div class="course-header">
                <h1>Executable and Linkable Format</h1>
                <p class="course-description">A deep dive into the ELF binary format — headers, sections, segments, symbols, relocations, and dynamic linking.</p>
                <div class="course-meta">
                    <span class="meta-item">8 modules</span>
                    <span class="meta-item">24 concepts</span>
                    <span class="meta-item">Beginner-friendly</span>
                </div>
            </div>

            <div class="module-list">
                <div class="module">
                    <h2>Module 1: Fundamentals</h2>
                    <p>Bytes, binary representation, and file layout.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/bytes">Bytes and Binary</a></li>
                        <li><a href="/courses/elf/lessons/binary-representation">Binary Representation</a></li>
                        <li><a href="/courses/elf/lessons/file-layout">File Layout</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 2: ELF Header</h2>
                    <p>The ELF identification and header structure.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/elf-identification">ELF Identification</a></li>
                        <li><a href="/courses/elf/lessons/elf-header-fields">ELF Header Fields</a></li>
                        <li><a href="/courses/elf/lessons/entry-point">Entry Point</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 3: Program Headers</h2>
                    <p>How the loader maps segments into memory.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/program-header-table">Program Header Table</a></li>
                        <li><a href="/courses/elf/lessons/segment-types">Segment Types</a></li>
                        <li><a href="/courses/elf/lessons/memory-mapping">Memory Mapping</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 4: Sections</h2>
                    <p>The sections that make up an ELF file.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/section-header-table">Section Header Table</a></li>
                        <li><a href="/courses/elf/lessons/common-sections">Common Sections</a></li>
                        <li><a href="/courses/elf/lessons/section-vs-segment">Section vs Segment</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 5: Symbols</h2>
                    <p>How ELF names and exports functions and variables.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/symbol-table">Symbol Table</a></li>
                        <li><a href="/courses/elf/lessons/binding">Symbol Binding</a></li>
                        <li><a href="/courses/elf/lessons/visibility">Symbol Visibility</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 6: Relocations</h2>
                    <p>How the linker patches addresses when combining objects.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/relocation-entries">Relocation Entries</a></li>
                        <li><a href="/courses/elf/lessons/relocation-types">Relocation Types</a></li>
                        <li><a href="/courses/elf/lessons/dynamic-relocations">Dynamic Relocations</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 7: Dynamic Linking</h2>
                    <p>How shared libraries are found, loaded, and connected at runtime.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/dynamic-section">Dynamic Section</a></li>
                        <li><a href="/courses/elf/lessons/shared-libraries">Shared Libraries</a></li>
                        <li><a href="/courses/elf/lessons/ld-so">The Dynamic Linker</a></li>
                    </ul>
                </div>

                <div class="module">
                    <h2>Module 8: Loading & Execution</h2>
                    <p>How the OS loads and runs your program.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/elf/lessons/loader">The Kernel Loader</a></li>
                        <li><a href="/courses/elf/lessons/memory-layout">Process Memory Layout</a></li>
                        <li><a href="/courses/elf/lessons/execution">The Startup Sequence</a></li>
                    </ul>
                </div>
            </div>
        </div>
    }

    #css {
        body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
        .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
        .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
        .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
        .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
        .nav-links { display: flex; gap: 1.5rem; }
        .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
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
