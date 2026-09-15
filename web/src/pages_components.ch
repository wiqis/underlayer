// underlayer_web — UI components demo page (P2 7.2.19, 7.2.20, 7.3.6, 7.3.11).
// Scroll area, resizable panel, theme preview, custom font upload.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_components_demo_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Components — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="comp-page">
                <nav class="comp-nav">
                    <a href="/" class="comp-brand">Underlayer</a>
                    <a href="/dashboard" class="comp-link">Dashboard</a>
                    <a href="/settings" class="comp-link">Settings</a>
                </nav>
                <main class="comp-main" id="main-content">
                    <h1>UI Components</h1>
                    <p class="comp-sub">Scroll area, resizable panel, theme preview, and custom fonts.</p>

                    <section class="comp-section" aria-labelledby="h-scroll">
                        <h2 id="h-scroll">Scroll Area</h2>
                        <p>A fixed-height container with custom scrollbar styling and keyboard scrolling.</p>
                        <div class="scroll-area" id="scroll-area" tabindex="0" role="region" aria-label="Scrollable content" style="max-height: 160px; overflow-y: auto; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 1rem;">
                            <p>Item 1 — scroll me</p><p>Item 2 — with the keyboard too</p><p>Item 3 — focus and use arrows</p><p>Item 4</p><p>Item 5</p><p>Item 6</p><p>Item 7</p><p>Item 8</p><p>Item 9 — the end</p>
                        </div>
                    </section>

                    <section class="comp-section" aria-labelledby="h-resize">
                        <h2 id="h-resize">Resizable Panel</h2>
                        <p>Drag the handle to resize. Panel width persists to localStorage.</p>
                        <div class="resize-wrap">
                            <div class="resize-panel" id="resize-panel">
                                <strong>Panel</strong>
                                <p>Drag my right edge.</p>
                            </div>
                            <div class="resize-handle" id="resize-handle" role="separator" aria-orientation="vertical" aria-label="Resize panel" tabindex="0"></div>
                            <div class="resize-rest">
                                <p>Content beside the panel reflows as you drag.</p>
                            </div>
                        </div>
                    </section>

                    <section class="comp-section" aria-labelledby="h-theme">
                        <h2 id="h-theme">Theme Preview</h2>
                        <p>Hover (or focus) a theme to preview it before applying. Click to apply.</p>
                        <div class="theme-cards">
                            <button class="theme-card" data-theme="light" onfocus="previewTheme('light')" onmouseover="previewTheme('light')" onclick="applyTheme('light')">
                                <span class="theme-swatch swatch-light"></span> Light
                            </button>
                            <button class="theme-card" data-theme="dark" onfocus="previewTheme('dark')" onmouseover="previewTheme('dark')" onclick="applyTheme('dark')">
                                <span class="theme-swatch swatch-dark"></span> Dark
                            </button>
                            <button class="theme-card" data-theme="system" onfocus="previewTheme('system')" onmouseover="previewTheme('system')" onclick="applyTheme('system')">
                                <span class="theme-swatch swatch-system"></span> System
                            </button>
                        </div>
                        <button class="btn-revert" id="theme-revert" onclick="revertTheme()" hidden>Revert preview</button>
                    </section>

                    <section class="comp-section" aria-labelledby="h-font">
                        <h2 id="h-font">Custom Font</h2>
                        <p>Upload a .ttf/.otf/.woff2 file — it is applied locally (never uploaded to a server).</p>
                        <input type="file" id="font-file" accept=".ttf,.otf,.woff,.woff2" />
                        <div class="font-preview" id="font-preview">
                            <p class="font-sample-title" id="font-sample">The quick brown fox jumps over 0123456789</p>
                            <button class="btn-revert" id="font-reset" onclick="resetFont()" hidden>Reset font</button>
                        </div>
                    </section>
                </main>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .comp-nav { display: flex; gap: 1.5rem; align-items: center; padding: 0.75rem 2rem; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); }
            .comp-brand { font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .comp-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; }
            .comp-link:hover { color: hsl(var(--foreground)); }
            .comp-main { max-width: 760px; margin: 0 auto; padding: 2rem; }
            .comp-sub { color: hsl(var(--muted-foreground)); }
            .comp-section { margin-bottom: 2.5rem; }
            .comp-section h2 { font-size: 1.15rem; margin-bottom: 0.5rem; }
            .scroll-area::-webkit-scrollbar { width: 10px; }
            .scroll-area::-webkit-scrollbar-thumb { background: hsl(var(--border)); border-radius: 9999px; }
            .scroll-area::-webkit-scrollbar-thumb:hover { background: hsl(var(--muted-foreground)); }
            .scroll-area:focus-visible { outline: 2px solid hsl(217 91% 60%); }
            .resize-wrap { display: flex; min-height: 120px; }
            .resize-panel { width: 220px; min-width: 120px; background: hsl(var(--secondary)); border-radius: 8px; padding: 1rem; }
            .resize-handle { width: 10px; cursor: grab; background: hsl(var(--border)); border-radius: 9999px; margin: 0 0.5rem; touch-action: none; }
            .resize-handle:hover, .resize-handle:focus-visible { background: hsl(217 91% 60%); outline: none; }
            .resize-rest { flex: 1; padding: 0.5rem; }
            .theme-cards { display: flex; gap: 1rem; }
            .theme-card { display: flex; align-items: center; gap: 0.5rem; padding: 0.6rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--card)); color: hsl(var(--foreground)); cursor: pointer; font-size: 0.9rem; }
            .theme-card:hover, .theme-card:focus-visible { border-color: hsl(217 91% 60%); }
            .theme-swatch { width: 18px; height: 18px; border-radius: 9999px; border: 1px solid hsl(var(--border)); display: inline-block; }
            .swatch-light { background: #ffffff; }
            .swatch-dark { background: #0a0a0a; }
            .swatch-system { background: linear-gradient(90deg, #ffffff 50%, #0a0a0a 50%); }
            .btn-revert { margin-top: 0.75rem; padding: 0.4rem 0.9rem; border: 1px solid hsl(var(--border)); border-radius: 6px; background: hsl(var(--card)); color: hsl(var(--foreground)); cursor: pointer; }
            .btn-revert:hover { background: hsl(var(--accent)); }
            .font-preview { margin-top: 0.75rem; padding: 1rem; border: 1px dashed hsl(var(--border)); border-radius: 8px; }
            .font-sample-title { margin: 0; font-size: 1.1rem; }
        }

        #js {
            function previewTheme(name) {
                var root = document.documentElement;
                if (name === 'dark') { root.classList.add('dark'); }
                else if (name === 'light') { root.classList.remove('dark'); }
                else { // system
                    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                    root.classList.toggle('dark', prefersDark);
                }
                document.getElementById('theme-revert').hidden = false;
            }
            function applyTheme(name) {
                localStorage.setItem('theme', name);
                document.getElementById('theme-revert').hidden = true;
            }
            function revertTheme() {
                var saved = localStorage.getItem('theme') || 'system';
                previewTheme(saved);
                document.getElementById('theme-revert').hidden = true;
            }
            (function() {
                var handle = document.getElementById('resize-handle');
                var panel = document.getElementById('resize-panel');
                if (!handle || !panel) return;
                var saved = localStorage.getItem('panel-width');
                if (saved) panel.style.width = saved + 'px';
                var startX = 0;
                var startW = 0;
                var dragging = false;
                function onMove(ev) {
                    if (!dragging) return;
                    var w = startW + (ev.clientX - startX);
                    if (w < 120) w = 120;
                    if (w > 480) w = 480;
                    panel.style.width = w + 'px';
                }
                function onUp() {
                    if (!dragging) return;
                    dragging = false;
                    localStorage.setItem('panel-width', String(parseInt(panel.style.width)));
                    document.body.style.cursor = '';
                }
                handle.addEventListener('pointerdown', function(ev) {
                    dragging = true; startX = ev.clientX; startW = panel.getBoundingClientRect().width;
                    document.body.style.cursor = 'col-resize';
                    ev.preventDefault();
                });
                window.addEventListener('pointermove', onMove);
                window.addEventListener('pointerup', onUp);
                handle.addEventListener('keydown', function(ev) {
                    var cur = parseInt(panel.style.width) || 220;
                    if (ev.key === 'ArrowLeft') { panel.style.width = Math.max(120, cur - 16) + 'px'; ev.preventDefault(); }
                    if (ev.key === 'ArrowRight') { panel.style.width = Math.min(480, cur + 16) + 'px'; ev.preventDefault(); }
                });
            })();
            (function() {
                var input = document.getElementById('font-file');
                var sample = document.getElementById('font-sample');
                var reset = document.getElementById('font-reset');
                if (!input) return;
                var savedData = null;
                try { savedData = localStorage.getItem('custom-font'); } catch (e) { savedData = null; }
                if (savedData && sample) {
                    sample.style.fontFamily = 'CustomLearnerFont, system-ui, sans-serif';
                    if (reset) reset.hidden = false;
                }
                input.addEventListener('change', function() {
                    var file = input.files ? input.files[0] : null;
                    if (!file) return;
                    var reader = new FileReader();
                    reader.onload = function() {
                        var dataUrl = String(reader.result);
                        var face = new FontFace('CustomLearnerFont', 'url(' + dataUrl + ')');
                        face.load().then(function(loaded) {
                            document.fonts.add(loaded);
                            sample.style.fontFamily = 'CustomLearnerFont, system-ui, sans-serif';
                            if (reset) reset.hidden = false;
                            try { localStorage.setItem('custom-font', dataUrl); } catch (e) { /* quota — font still applies for this session */ }
                        }).catch(function() {
                            sample.textContent = 'Could not load that font file.';
                        });
                    };
                    reader.readAsDataURL(file);
                });
                if (typeof reset !== 'undefined' && reset) {
                    reset.addEventListener('click', function() {
                        localStorage.removeItem('custom-font');
                        sample.style.fontFamily = '';
                        sample.textContent = 'The quick brown fox jumps over 0123456789';
                        reset.hidden = true;
                    });
                }
            })();
        }

        return page.toString()
    }

    public func handle_components_demo_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html_out = render_components_demo_page()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
