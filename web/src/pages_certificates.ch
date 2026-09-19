// underlayer_web — Certificates page.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_certificates_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Certificates — Underlayer"))

        #html {
            <a href="#main-content" class="skip-link">Skip to content</a>
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses/elf" class="nav-link">Courses</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                        <a href="/certificates" class="nav-link">Certificates</a>
                    </div>
                    <div class="nav-right">
                        <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                            <span class="theme-icon-light">&#9728;</span>
                            <span class="theme-icon-dark">&#9790;</span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Certificates</h1>
                    <p class="subtitle">Your earned certificates of completion</p>
                </div>

                <div class="claim-box">
                    <p class="claim-text">Finished a course? Claim your certificate using its course ID.</p>
                    <div class="claim-form">
                        <div>
                            <label class="claim-label" for="course-id">Course ID</label>
                            <input class="claim-input" id="course-id" type="text" value="elf" placeholder="elf" />
                        </div>
                        <button class="btn btn-primary" id="claim-btn" onclick="claimCertificate()">Claim Certificate</button>
                    </div>
                    <p class="claim-msg" id="claim-msg"></p>
                </div>

                <div id="certs-body">
                    <p class="muted">Loading certificates...</p>
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
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
            .container { max-width: 800px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 1.5rem; }
            .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); }
            .claim-box { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem; margin-bottom: 2rem; }
            .claim-text { margin: 0 0 0.75rem 0; font-size: 0.9rem; color: hsl(var(--muted-foreground)); }
            .claim-form { display: flex; align-items: flex-end; gap: 0.75rem; flex-wrap: wrap; }
            .claim-label { display: block; font-size: 0.8rem; font-weight: 600; color: hsl(var(--foreground)); margin-bottom: 0.25rem; }
            .claim-input { padding: 0.6rem 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--background)); color: hsl(var(--foreground)); font-size: 0.95rem; min-width: 160px; }
            .claim-msg { margin: 0.75rem 0 0 0; font-size: 0.85rem; color: hsl(var(--muted-foreground)); min-height: 1.2em; }
            .claim-msg.success { color: hsl(142 76% 36%); }
            .claim-msg.error { color: hsl(0 72% 51%); }
            .btn { display: inline-block; padding: 0.65rem 1.25rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.9rem; }
            .btn-primary { background: hsl(217 91% 60%); color: white; text-decoration: none; }
            .btn-primary:hover { background: hsl(217 91% 52%); }
            .btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
            .muted { color: hsl(var(--muted-foreground)); }
            .cert-list { display: flex; flex-direction: column; gap: 1rem; }
            .cert-card { display: block; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(45 93% 47%); border-radius: 10px; padding: 1.25rem; text-decoration: none; transition: all 0.15s; }
            .cert-card:hover { border-color: hsl(217 91% 60%); border-left-color: hsl(45 93% 47%); text-decoration: none; transform: translateY(-2px); }
            .cert-title { font-size: 1.1rem; font-weight: 600; color: hsl(var(--foreground)); margin-bottom: 0.25rem; }
            .cert-meta { font-size: 0.82rem; color: hsl(var(--muted-foreground)); display: flex; gap: 1rem; flex-wrap: wrap; }
            .cert-id { font-family: monospace; }
            .empty-state { text-align: center; padding: 3rem 1rem; background: hsl(var(--card)); border: 1px dashed hsl(var(--border)); border-radius: 10px; }
            .empty-state h2 { font-size: 1.2rem; margin-bottom: 0.5rem; }
            .empty-state p { color: hsl(var(--muted-foreground)); margin-bottom: 1rem; }
            .empty-state a { color: hsl(217 91% 60%); text-decoration: none; font-weight: 600; }
            .empty-state a:hover { text-decoration: underline; }
            @media (max-width: 768px) {
                .nav-links { display: none; }
                .container { padding: 1rem; }
                .claim-form { flex-direction: column; align-items: stretch; }
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

            function authHeaders(json) {
                var headers = { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') };
                if (json) { headers['Content-Type'] = 'application/json'; }
                return headers;
            }

            function renderEmpty() {
                var body = document.getElementById('certs-body');
                body.textContent = '';
                var wrap = document.createElement('div');
                wrap.className = 'empty-state';
                var heading = document.createElement('h2');
                heading.textContent = 'Complete a course to earn a certificate';
                var text = document.createElement('p');
                text.textContent = 'Once you finish a course, claim your certificate above and it will appear here.';
                var link = document.createElement('a');
                link.setAttribute('href', '/courses/elf');
                link.textContent = 'Go to courses';
                wrap.appendChild(heading);
                wrap.appendChild(text);
                wrap.appendChild(link);
                body.appendChild(wrap);
            }

            function renderCertificates(certs) {
                if (!certs || certs.length === 0) { renderEmpty(); return; }
                var body = document.getElementById('certs-body');
                body.textContent = '';
                var list = document.createElement('div');
                list.className = 'cert-list';
                var i = 0;
                while (i < certs.length) {
                    var cert = certs[i];
                    var card = document.createElement('a');
                    card.className = 'cert-card';
                    card.setAttribute('href', '/certificates/' + cert.id);
                    var title = document.createElement('div');
                    title.className = 'cert-title';
                    title.textContent = cert.course_title || cert.course_id;
                    var meta = document.createElement('div');
                    meta.className = 'cert-meta';
                    var name = document.createElement('span');
                    name.textContent = cert.learner_name || 'Learner';
                    var date = document.createElement('span');
                    date.textContent = 'Completed ' + (cert.completion_date || 'unknown');
                    var id = document.createElement('span');
                    id.className = 'cert-id';
                    id.textContent = cert.id;
                    meta.appendChild(name);
                    meta.appendChild(date);
                    meta.appendChild(id);
                    card.appendChild(title);
                    card.appendChild(meta);
                    list.appendChild(card);
                    i = i + 1;
                }
                body.appendChild(list);
            }

            function loadCertificates() {
                fetch('/api/certificates', { headers: authHeaders(false) })
                  .then(function(r) {
                    if (!r.ok) { throw new Error('request failed'); }
                    return r.json();
                  }).then(function(data) {
                    if (!data || !data.length) { renderEmpty(); return; }
                    renderCertificates(data);
                  }).catch(function() {
                    var body = document.getElementById('certs-body');
                    body.textContent = 'Failed to load certificates.';
                    body.className = 'muted';
                  });
            }

            function setClaimMessage(text, kind) {
                var msg = document.getElementById('claim-msg');
                msg.textContent = text;
                msg.className = 'claim-msg';
                if (kind === 'success') { msg.className = 'claim-msg success'; }
                if (kind === 'error') { msg.className = 'claim-msg error'; }
            }

            function claimCertificate() {
                var input = document.getElementById('course-id');
                var courseId = (input.value || '').trim();
                if (!courseId) { setClaimMessage('Please enter a course ID.', 'error'); return; }
                var btn = document.getElementById('claim-btn');
                btn.disabled = true;
                setClaimMessage('Claiming certificate...', null);
                fetch('/api/certificates', {
                    method: 'POST',
                    headers: authHeaders(true),
                    body: JSON.stringify({ course_id: courseId })
                }).then(function(r) {
                    return r.json().then(function(data) {
                        return { ok: r.ok, data: data };
                    });
                }).then(function(result) {
                    btn.disabled = false;
                    if (result.ok) {
                        setClaimMessage('Certificate issued.', 'success');
                        loadCertificates();
                    } else {
                        var detail = 'Could not issue certificate.';
                        if (result.data && result.data.error) { detail = result.data.error; }
                        setClaimMessage(detail, 'error');
                    }
                }).catch(function() {
                    btn.disabled = false;
                    setClaimMessage('Failed to claim certificate.', 'error');
                });
            }

            loadCertificates();
        }

        return page.toString()
    }

}
