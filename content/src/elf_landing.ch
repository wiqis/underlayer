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
        <a href="#main-content" class="skip-link">Skip to content</a>
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
                <div class="nav-progress" id="nav-progress" hidden>
                    <div class="nav-progress-track" id="nav-progress-bar" role="progressbar" aria-label="Course progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
                        <div class="nav-progress-fill" id="nav-progress-fill"></div>
                    </div>
                    <a href="/review" class="nav-due-badge" id="nav-due-badge" hidden></a>
                </div>
                <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                    <span class="theme-icon-light">☀️</span>
                    <span class="theme-icon-dark">🌙</span>
                </button>
            </div>
        </div>


        <div class="course-landing" id="main-content">
            <!-- P2 7.1.10: Command palette (opened via Ctrl+K or /) -->
            <div class="cmdk-overlay" id="cmdk" hidden role="dialog" aria-modal="true" aria-label="Quick jump">
                <div class="cmdk-panel">
                    <input type="text" class="cmdk-input" id="cmdk-input" placeholder="Jump to a concept… (Esc to close)" autocomplete="off" />
                    <div class="cmdk-results" id="cmdk-results" role="listbox"></div>
                </div>
            </div>

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
        .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
        .skip-link:focus { top: 0; }
        :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
        .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
        .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
        .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
        .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
        .nav-links { display: flex; gap: 1.5rem; }
        .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
        .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
        .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
        .nav-right { display: flex; align-items: center; gap: 0.75rem; }
        .hamburger { display: none; background: none; border: none; cursor: pointer; padding: 0.5rem; }
        .hamburger-line { display: block; width: 24px; height: 2px; background: hsl(var(--foreground)); margin: 4px 0; transition: all 0.3s; }
        .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
        .theme-toggle:hover { background: hsl(var(--accent)); }
        .nav-progress { display: flex; align-items: center; gap: 0.75rem; }
        .nav-progress[hidden] { display: none; }
        .nav-progress-track { width: 120px; height: 6px; background: hsl(var(--secondary)); border-radius: 9999px; overflow: hidden; }
        .nav-progress-fill { height: 100%; width: 0%; background: hsl(217 91% 60%); border-radius: 9999px; transition: width 0.3s; }
        .nav-due-badge { font-size: 0.75rem; font-weight: 600; color: hsl(0 0% 100%); background: hsl(0 84% 60%); border-radius: 9999px; padding: 0.15rem 0.6rem; text-decoration: none; white-space: nowrap; }
        .nav-due-badge[hidden] { display: none; }
        .nav-due-badge:hover { text-decoration: none; filter: brightness(1.1); }
        .cmdk-overlay { position: fixed; inset: 0; background: hsl(0 0% 0% / 50%); display: flex; align-items: flex-start; justify-content: center; padding-top: 12vh; z-index: 300; }
        .cmdk-overlay[hidden] { display: none; }
        .cmdk-panel { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; width: min(560px, 92vw); box-shadow: 0 16px 48px hsl(0 0% 0% / 25%); overflow: hidden; }
        .cmdk-input { width: 100%; box-sizing: border-box; padding: 0.9rem 1.1rem; border: none; outline: none; background: hsl(var(--card)); color: hsl(var(--foreground)); font-size: 1rem; border-bottom: 1px solid hsl(var(--border)); }
        .cmdk-results { max-height: 320px; overflow-y: auto; }
        .cmdk-item { display: flex; justify-content: space-between; align-items: center; padding: 0.6rem 1.1rem; cursor: pointer; color: hsl(var(--foreground)); }
        .cmdk-item.selected { background: hsl(217 91% 60% / 15%); }
        .cmdk-kind { font-size: 0.7rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.05em; }
        .cmdk-empty { padding: 1rem 1.1rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
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
            .nav-links { display: none; position: absolute; top: 100%; left: 0; right: 0; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); flex-direction: column; padding: 1rem; gap: 0.5rem; }
            .nav-links.open { display: flex; }
            .nav-link { padding: 0.75rem 1rem; }
            .hamburger { display: block; }
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
        // P2 7.1.13/7.1.15: Nav progress bar + due review badge.
        // Stays hidden in static mode (no backend) — fetch failure is a no-op.
        function loadNavStatus() {
            var wrap = document.getElementById('nav-progress');
            if (!wrap) return;
            fetch('/api/nav-status').then(function(r) {
                if (!r.ok) throw new Error('http ' + r.status);
                return r.json();
            }).then(function(data) {
                wrap.hidden = false;
                var pct = data.progress_pct || 0;
                var fill = document.getElementById('nav-progress-fill');
                if (fill) fill.style.width = pct + '%';
                var bar = document.getElementById('nav-progress-bar');
                if (bar) bar.setAttribute('aria-valuenow', String(pct));
                var badge = document.getElementById('nav-due-badge');
                if (badge && data.due_reviews > 0) {
                    badge.textContent = data.due_reviews + ' due';
                    badge.hidden = false;
                }
            }).catch(function() {
                // No backend available — leave indicators hidden.
            });
        }
        loadNavStatus();

        // P2 7.1.10: Command palette — Ctrl+K or '/' to open, Esc closes,
        // arrows + Enter navigate. Entries load lazily on first open.
        var cmdkEntries = null;
        var cmdkSelected = 0;
        var cmdkVisible = [];
        var cmdkLoaded = false;
        function cmdkOpen() {
            var overlay = document.getElementById('cmdk');
            if (!overlay) return;
            overlay.hidden = false;
            var input = document.getElementById('cmdk-input');
            if (input) { input.value = ''; input.focus(); }
            if (!cmdkLoaded) {
                cmdkLoaded = true;
                fetch('/api/nav-search').then(function(r) { return r.json(); }).then(function(data) {
                    cmdkEntries = data.entries || [];
                    cmdkRender('');
                }).catch(function() { cmdkEntries = []; });
            } else {
                cmdkRender('');
            }
        }
        function cmdkClose() {
            var overlay = document.getElementById('cmdk');
            if (overlay) overlay.hidden = true;
        }
        function cmdkRender(q) {
            var box = document.getElementById('cmdk-results');
            if (!box) return;
            var list = (cmdkEntries || []).filter(function(e) {
                return e.label.toLowerCase().indexOf(q.toLowerCase()) !== -1;
            });
            cmdkVisible = list;
            cmdkSelected = 0;
            var html = '';
            list.forEach(function(e, i) {
                html += '<div class="cmdk-item' + (i === 0 ? ' selected' : '') + '" data-i="' + i + '">' +
                    '<span>' + e.label + '</span><span class="cmdk-kind">' + e.kind + '</span></div>';
            });
            if (list.length === 0) html = '<div class="cmdk-empty">No matches</div>';
            box.innerHTML = html;
            box.querySelectorAll('.cmdk-item').forEach(function(el) {
                el.addEventListener('click', function() { window.location.href = cmdkVisible[el.getAttribute('data-i')].url; });
            });
        }
        function cmdkMove(delta) {
            if (cmdkVisible.length === 0) return;
            cmdkSelected = (cmdkSelected + delta + cmdkVisible.length) % cmdkVisible.length;
            var box = document.getElementById('cmdk-results');
            box.querySelectorAll('.cmdk-item').forEach(function(el, i) {
                el.classList.toggle('selected', i === cmdkSelected);
            });
        }
        document.addEventListener('keydown', function(ev) {
            var overlay = document.getElementById('cmdk');
            var open = overlay && !overlay.hidden;
            var tag = (ev.target && ev.target.tagName || '').toLowerCase();
            var typing = tag === 'input' || tag === 'textarea';
            if ((ev.ctrlKey || ev.metaKey) && (ev.key === 'k' || ev.key === 'K')) {
                ev.preventDefault();
                if (open) { cmdkClose(); } else { cmdkOpen(); }
                return;
            }
            if (ev.key === '/' && !open && !typing) { ev.preventDefault(); cmdkOpen(); return; }
            if (!open) return;
            if (ev.key === 'Escape') { cmdkClose(); return; }
            if (ev.key === 'ArrowDown') { ev.preventDefault(); cmdkMove(1); return; }
            if (ev.key === 'ArrowUp') { ev.preventDefault(); cmdkMove(-1); return; }
            if (ev.key === 'Enter') {
                ev.preventDefault();
                if (cmdkVisible[cmdkSelected]) window.location.href = cmdkVisible[cmdkSelected].url;
            }
        });
        document.addEventListener('click', function(ev) {
            var overlay = document.getElementById('cmdk');
            if (overlay && !overlay.hidden && ev.target === overlay) cmdkClose();
        });
    }

    return page.toString()
}
}
