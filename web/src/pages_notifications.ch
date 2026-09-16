// underlayer_web - Notifications page.
// Client-side rendered list; data from GET /api/notifications and friends.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_notifications_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Notifications - Underlayer"))

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
                        <a href="/notifications" class="nav-link nav-link-active">Notifications</a>
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
                    <h1>Notifications</h1>
                    <p class="subtitle" id="notif-subtitle">Loading notifications...</p>
                </div>

                <div class="toolbar">
                    <button type="button" class="btn btn-outline" id="mark-all-btn">Mark all as read</button>
                    <button type="button" class="btn btn-outline" id="refresh-btn">Refresh</button>
                </div>

                <div class="notif-list" id="notif-body">
                    <p class="muted">Loading notifications...</p>
                </div>
            </div>

            <div class="toast" id="toast" role="status" aria-live="polite"></div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">&uarr; Top</button>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; } :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; } .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; gap: 1.5rem; } .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.75rem; border-radius: 6px; transition: all 0.15s; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; } .nav-link-active { color: hsl(var(--foreground)); background: hsl(var(--accent)); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; } .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); } .theme-icon-dark { display: none; } .dark .theme-icon-light { display: none; } .dark .theme-icon-dark { display: inline; }
            .container { max-width: 800px; margin: 0 auto; padding: 2rem; }
            .page-header { margin-bottom: 1rem; } .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; } .subtitle { color: hsl(var(--muted-foreground)); }
            .subtitle .count-pill { display: inline-block; background: hsl(217 91% 60%); color: white; border-radius: 999px; padding: 0.05rem 0.55rem; font-size: 0.8rem; font-weight: 700; margin-right: 0.35rem; }
            .toolbar { display: flex; gap: 0.75rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
            .btn { display: inline-block; padding: 0.6rem 1.1rem; border: 1px solid transparent; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.9rem; text-decoration: none; } .btn:disabled { opacity: 0.5; cursor: not-allowed; }
            .btn-primary { background: hsl(217 91% 60%); color: white; } .btn-outline { background: transparent; color: hsl(var(--foreground)); border-color: hsl(var(--border)); }
            .btn-outline:hover:not(:disabled) { background: hsl(var(--accent)); } .btn-danger { background: transparent; color: hsl(0 72% 51%); border-color: hsl(0 72% 51% / 40%); }
            .btn-danger:hover { background: hsl(0 72% 51% / 10%); } .btn-small { padding: 0.35rem 0.75rem; font-size: 0.8rem; }
            .notif-list { display: flex; flex-direction: column; gap: 0.75rem; }
            .notif-item { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--muted)); border-radius: 10px; padding: 1rem 1.25rem; }
            .notif-item.unread { border-left-color: hsl(217 91% 60%); background: hsl(217 91% 60% / 5%); }
            .notif-top { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
            .notif-title { font-size: 1rem; font-weight: 600; color: hsl(var(--foreground)); } .notif-item.unread .notif-title { font-weight: 700; }
            .badge { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; border-radius: 999px; padding: 0.15rem 0.6rem; flex-shrink: 0; }
            .badge-unread { background: hsl(217 91% 60%); color: white; } .badge-read { background: hsl(var(--muted)); color: hsl(var(--muted-foreground)); }
            .notif-message { margin: 0.5rem 0 0 0; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .notif-meta { display: flex; gap: 1rem; margin-top: 0.6rem; font-size: 0.78rem; color: hsl(var(--muted-foreground)); flex-wrap: wrap; } .notif-type { text-transform: capitalize; }
            .notif-actions { display: flex; gap: 0.5rem; margin-top: 0.85rem; flex-wrap: wrap; } .muted { color: hsl(var(--muted-foreground)); }
            .empty-state { text-align: center; padding: 3rem 1.5rem; background: hsl(var(--card)); border: 1px dashed hsl(var(--border)); border-radius: 12px; }
            .empty-title { font-size: 1.25rem; margin: 0 0 0.5rem 0; } .empty-text { color: hsl(var(--muted-foreground)); margin: 0; font-size: 0.9rem; }
            .error-state { padding: 1.5rem; background: hsl(0 72% 51% / 8%); border: 1px solid hsl(0 72% 51% / 30%); border-radius: 10px; color: hsl(0 72% 51%); }
            .toast { position: fixed; bottom: 2rem; left: 50%; transform: translateX(-50%) translateY(2rem); background: #1f2937; color: white; padding: 0.6rem 1.1rem; border-radius: 8px; font-size: 0.85rem; opacity: 0; pointer-events: none; transition: all 0.25s; z-index: 300; } .toast.visible { opacity: 1; transform: translateX(-50%) translateY(0); }
            .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; } .back-to-top.visible { opacity: 1; pointer-events: auto; } .back-to-top:hover { background: #111827; }
            @media (max-width: 768px) { .nav-links { display: none; } .container { padding: 1rem; } .notif-top { flex-direction: column; align-items: flex-start; } }
        }

        #js {
            function getTheme() { var saved = localStorage.getItem('theme'); if (saved) return saved; return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'; }
            function setTheme(theme) { document.documentElement.classList.toggle('dark', theme === 'dark'); localStorage.setItem('theme', theme); }
            function toggleTheme() { var cur = document.documentElement.classList.contains('dark') ? 'dark' : 'light'; setTheme(cur === 'dark' ? 'light' : 'dark'); }
            setTheme(getTheme());
            function authHeaders() { return { 'Authorization': 'Bearer ' + (localStorage.getItem('session_token') || '') }; }
            function apiFetch(url, method) {
                return fetch(url, { method: method || 'GET', headers: authHeaders() }).then(function(r) {
                    if (!r.ok) { throw new Error('request failed'); }
                    return r.json().catch(function() { return {}; });
                });
            }
            function clearNode(node) { while (node.firstChild) { node.removeChild(node.firstChild); } }
            function makeEl(tag, cls, text) {
                var e = document.createElement(tag);
                if (cls) { e.className = cls; }
                if (text !== null && text !== undefined) { e.textContent = text; }
                return e;
            }
            function formatTime(ts) {
                if (!ts) { return ''; }
                var ms = Number(ts); if (isNaN(ms)) { return String(ts); }
                if (ms < 1000000000000) { ms = ms * 1000; }
                var d = new Date(ms); return isNaN(d.getTime()) ? String(ts) : d.toLocaleString();
            }
            function showToast(text) {
                var toast = document.getElementById('toast'); if (!toast) { return; }
                toast.textContent = text; toast.classList.add('visible');
                window.setTimeout(function() { toast.classList.remove('visible'); }, 2400);
            }
            function renderError() {
                var body = document.getElementById('notif-body'); clearNode(body);
                var box = makeEl('div', 'error-state');
                box.appendChild(makeEl('p', 'error-text', 'Could not load notifications. You may need to sign in, or the server may be unavailable.'));
                body.appendChild(box);
            }
            function renderEmpty() {
                var body = document.getElementById('notif-body'); clearNode(body);
                var wrap = makeEl('div', 'empty-state');
                wrap.appendChild(makeEl('h2', 'empty-title', 'You are all caught up'));
                wrap.appendChild(makeEl('p', 'empty-text', 'No notifications right now. When reviews are due, new lessons are added, or something needs your attention, it will show up here.'));
                body.appendChild(wrap);
            }
            function renderItem(n) {
                var item = makeEl('div', 'notif-item');
                if (!n.is_read) { item.classList.add('unread'); }
                var top = makeEl('div', 'notif-top');
                top.appendChild(makeEl('div', 'notif-title', n.title ? String(n.title) : 'Notification'));
                top.appendChild(makeEl('span', n.is_read ? 'badge badge-read' : 'badge badge-unread', n.is_read ? 'Read' : 'Unread'));
                item.appendChild(top);
                if (n.message) { item.appendChild(makeEl('p', 'notif-message', String(n.message))); }
                var meta = makeEl('div', 'notif-meta');
                if (n.type) { meta.appendChild(makeEl('span', 'notif-type', String(n.type))); }
                var timeText = formatTime(n.created_at);
                if (timeText) { meta.appendChild(makeEl('span', 'notif-time', timeText)); }
                if (meta.childNodes.length > 0) { item.appendChild(meta); }
                var actions = makeEl('div', 'notif-actions');
                if (n.action_url) { var open = makeEl('a', 'btn btn-small btn-primary', 'Open'); open.setAttribute('href', String(n.action_url)); actions.appendChild(open); }
                if (!n.is_read) {
                    var markBtn = makeEl('button', 'btn btn-small btn-outline', 'Mark as read'); markBtn.setAttribute('type', 'button');
                    markBtn.addEventListener('click', function() { markRead(n.id); }); actions.appendChild(markBtn);
                }
                var delBtn = makeEl('button', 'btn btn-small btn-danger', 'Delete'); delBtn.setAttribute('type', 'button');
                delBtn.addEventListener('click', function() { deleteNotification(n.id); }); actions.appendChild(delBtn);
                item.appendChild(actions);
                return item;
            }
            function updateSubtitle(unread, total) {
                var sub = document.getElementById('notif-subtitle'); clearNode(sub);
                if (unread > 0) {
                    sub.appendChild(makeEl('span', 'count-pill', String(unread)));
                    sub.appendChild(makeEl('span', '', unread + ' unread of ' + total + ' notifications'));
                } else if (total > 0) {
                    sub.appendChild(makeEl('span', '', total + ' notifications, none unread'));
                } else {
                    sub.appendChild(makeEl('span', '', 'Nothing to review'));
                }
                var markAll = document.getElementById('mark-all-btn'); if (markAll) { markAll.disabled = unread === 0; }
            }
            function renderList(list, unread) {
                var body = document.getElementById('notif-body'); clearNode(body);
                if (!list || list.length === 0) { renderEmpty(); }
                else { var i = 0; while (i < list.length) { body.appendChild(renderItem(list[i])); i = i + 1; } }
                updateSubtitle(unread, list ? list.length : 0);
            }
            function loadNotifications() {
                return Promise.all([ apiFetch('/api/notifications', 'GET'), apiFetch('/api/notifications/unread-count', 'GET') ]).then(function(results) {
                    var list = results[0]; var countData = results[1];
                    if (!Array.isArray(list)) { list = []; }
                    var unread = 0;
                    if (countData && typeof countData.count === 'number') { unread = countData.count; }
                    else { var j = 0; while (j < list.length) { if (!list[j].is_read) { unread = unread + 1; } j = j + 1; } }
                    renderList(list, unread);
                }).catch(function() { renderError(); });
            }
            function markRead(id) {
                apiFetch('/api/notifications/' + encodeURIComponent(id) + '/read', 'POST').then(function() { return loadNotifications(); }).then(function() { showToast('Marked as read'); }).catch(function() { showToast('Could not mark as read'); });
            }
            function markAllRead() {
                apiFetch('/api/notifications/read-all', 'POST').then(function() { return loadNotifications(); }).then(function() { showToast('All notifications marked as read'); }).catch(function() { showToast('Could not mark all as read'); });
            }
            function deleteNotification(id) {
                apiFetch('/api/notifications/' + encodeURIComponent(id), 'DELETE').then(function() { return loadNotifications(); }).then(function() { showToast('Notification deleted'); }).catch(function() { showToast('Could not delete notification'); });
            }
            var markAllBtn = document.getElementById('mark-all-btn');
            if (markAllBtn) { markAllBtn.addEventListener('click', markAllRead); }
            var refreshBtn = document.getElementById('refresh-btn');
            if (refreshBtn) { refreshBtn.addEventListener('click', function() { loadNotifications(); }); }
            window.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('back-to-top');
                if (btn) { window.addEventListener('scroll', function() { if (window.scrollY > 300) { btn.classList.add('visible'); } else { btn.classList.remove('visible'); } }); }
            });
            loadNotifications();
        }

        return page.toString()
    }

}
