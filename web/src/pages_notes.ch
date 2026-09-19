// underlayer_web — Notes page.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_notes_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Notes — Underlayer"))

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
                        <a href="/notes" class="nav-link">Notes</a>
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
                    <h1>Notes</h1>
                    <p class="subtitle">Your saved notes across every course</p>
                </div>

                <div class="search-bar">
                    <input type="text" id="search-input" class="search-input" placeholder="Search notes..." aria-label="Search notes">
                    <button class="btn btn-primary" id="search-btn" onclick="runSearch()">Search</button>
                    <button class="btn btn-secondary" id="clear-btn" onclick="clearSearch()">Clear</button>
                </div>

                <p class="status" id="status" role="status"></p>

                <div id="notes-body">
                    <p class="muted">Loading notes...</p>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; } :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; } .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; } .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; } .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; } .dark .theme-icon-light { display: none; } .dark .theme-icon-dark { display: inline; }
            .container { max-width: 800px; margin: 0 auto; padding: 2rem; } .page-header { margin-bottom: 1.5rem; } .page-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .subtitle { color: hsl(var(--muted-foreground)); margin: 0; } .search-bar { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
            .search-input { flex: 1; padding: 0.75rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); } .search-input:focus { outline: 2px solid hsl(217 91% 60%); outline-offset: 1px; }
            .status { color: hsl(var(--muted-foreground)); font-size: 0.85rem; min-height: 1.2rem; margin: 0 0 1rem 0; } .status.error { color: hsl(0 72% 51%); } .muted { color: hsl(var(--muted-foreground)); }
            .empty-state { text-align: center; padding: 3rem 1rem; background: hsl(var(--card)); border: 1px dashed hsl(var(--border)); border-radius: 12px; }
            .empty-title { font-size: 1.1rem; font-weight: 600; margin: 0 0 0.5rem 0; } .empty-hint { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0; }
            .note-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1rem 1.25rem; margin-bottom: 1rem; } .note-content { white-space: pre-wrap; font-size: 0.95rem; margin: 0 0 0.75rem 0; }
            .note-meta { display: flex; flex-wrap: wrap; gap: 1rem; font-size: 0.78rem; color: hsl(var(--muted-foreground)); margin-bottom: 0.75rem; } .note-meta a { color: hsl(217 91% 60%); text-decoration: none; } .note-meta a:hover { text-decoration: underline; }
            .note-actions { display: flex; gap: 0.5rem; } .note-edit-area { width: 100%; box-sizing: border-box; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-family: inherit; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); resize: vertical; margin-bottom: 0.75rem; }
            .btn { display: inline-block; padding: 0.6rem 1.1rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.9rem; } .btn-primary { background: hsl(217 91% 60%); color: white; } .btn-secondary { background: hsl(var(--secondary)); color: hsl(var(--foreground)); border: 1px solid hsl(var(--border)); } .btn-danger { background: hsl(0 72% 51%); color: white; } .btn:disabled { opacity: 0.6; cursor: not-allowed; }
            @media (max-width: 768px) {
                .nav-links { display: none; } .container { padding: 1rem; } .search-bar { flex-wrap: wrap; }
            }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem("theme");
                if (saved) return saved;
                return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
            }
            function setTheme(t) {
                document.documentElement.classList.toggle("dark", t === "dark");
                localStorage.setItem("theme", t);
            }
            function toggleTheme() {
                var c = document.documentElement.classList.contains("dark") ? "dark" : "light";
                setTheme(c === "dark" ? "light" : "dark");
            }
            setTheme(getTheme());

            function el(tag, cls, text) {
                var n = document.createElement(tag);
                if (cls) n.className = cls;
                if (text) n.textContent = text;
                return n;
            }
            function authHeaders(json) {
                var h = { "Authorization": "Bearer " + (localStorage.getItem("session_token") || "") };
                if (json) h["Content-Type"] = "application/json";
                return h;
            }
            function setStatus(msg, isError) {
                var s = document.getElementById("status");
                s.textContent = msg || "";
                if (isError) s.classList.add("error");
                else s.classList.remove("error");
            }
            function formatDate(seconds) {
                if (!seconds) return "";
                var d = new Date(seconds * 1000);
                if (isNaN(d.getTime())) return "";
                return d.toLocaleDateString();
            }

            function buildNoteCard(note) {
                var card = el("div", "note-card", null);
                card.appendChild(el("p", "note-content", note.content || ""));
                var meta = el("div", "note-meta", null);
                var link = el("a", null, note.concept_id || "concept");
                link.setAttribute("href", "/courses/" + (note.course_id || "elf") + "/lessons/" + (note.concept_id || ""));
                meta.appendChild(link);
                if (note.section_ref) meta.appendChild(el("span", null, note.section_ref));
                meta.appendChild(el("span", null, "Updated " + formatDate(note.updated_at || note.created_at)));
                card.appendChild(meta);
                var actions = el("div", "note-actions", null);
                var editBtn = el("button", "btn btn-secondary", "Edit");
                editBtn.addEventListener("click", function() { startEdit(card, note); });
                actions.appendChild(editBtn);
                var delBtn = el("button", "btn btn-danger", "Delete");
                delBtn.addEventListener("click", function() { deleteNote(note.id, delBtn); });
                actions.appendChild(delBtn);
                card.appendChild(actions);
                return card;
            }

            var currentNotes = [];

            function renderNotes(notes) {
                currentNotes = notes || [];
                var body = document.getElementById("notes-body");
                body.textContent = "";
                if (currentNotes.length === 0) {
                    var empty = el("div", "empty-state", null);
                    empty.appendChild(el("p", "empty-title", "No notes yet"));
                    empty.appendChild(el("p", "empty-hint", "Open a lesson and save a note to see it here."));
                    body.appendChild(empty);
                    return;
                }
                var i = 0;
                while (i < currentNotes.length) {
                    body.appendChild(buildNoteCard(currentNotes[i]));
                    i = i + 1;
                }
            }

            function startEdit(card, note) {
                card.textContent = "";
                var area = el("textarea", "note-edit-area", null);
                area.rows = 4;
                area.value = note.content || "";
                card.appendChild(area);
                var actions = el("div", "note-actions", null);
                var saveBtn = el("button", "btn btn-primary", "Save");
                saveBtn.addEventListener("click", function() {
                    var text = area.value.trim();
                    if (text.length === 0) { setStatus("Note content cannot be empty.", true); return; }
                    saveBtn.disabled = true;
                    fetch("/api/notes/" + encodeURIComponent(note.id), {
                        method: "PUT", headers: authHeaders(true), body: JSON.stringify({ content: text })
                    }).then(function(r) {
                        if (!r.ok) throw new Error("update failed");
                        note.content = text;
                        setStatus("Note updated.", false);
                        loadNotes();
                    }).catch(function() {
                        saveBtn.disabled = false;
                        setStatus("Could not update note.", true);
                    });
                });
                actions.appendChild(saveBtn);
                var cancelBtn = el("button", "btn btn-secondary", "Cancel");
                cancelBtn.addEventListener("click", function() { renderNotes(currentNotes); });
                actions.appendChild(cancelBtn);
                card.appendChild(actions);
            }

            function deleteNote(id, btn) {
                if (!window.confirm("Delete this note?")) return;
                btn.disabled = true;
                fetch("/api/notes/" + encodeURIComponent(id), {
                    method: "DELETE", headers: authHeaders(false)
                }).then(function(r) {
                    if (!r.ok) throw new Error("delete failed");
                    setStatus("Note deleted.", false);
                    loadNotes();
                }).catch(function() {
                    btn.disabled = false;
                    setStatus("Could not delete note.", true);
                });
            }

            function loadNotes() {
                fetch("/api/notes", { headers: authHeaders(false) })
                    .then(function(r) { return r.json(); })
                    .then(function(data) { renderNotes(data); })
                    .catch(function() {
                        var body = document.getElementById("notes-body");
                        body.textContent = "";
                        body.appendChild(el("p", "muted", "Failed to load notes."));
                    });
            }

            function runSearch() {
                var q = document.getElementById("search-input").value.trim();
                if (q.length === 0) { setStatus("Type something to search.", false); loadNotes(); return; }
                setStatus("Searching...", false);
                fetch("/api/notes/search?q=" + encodeURIComponent(q), { headers: authHeaders(false) })
                    .then(function(r) { return r.json(); })
                    .then(function(data) { setStatus(data.length + " matching note(s).", false); renderNotes(data); })
                    .catch(function() { setStatus("Search failed.", true); });
            }

            function clearSearch() {
                document.getElementById("search-input").value = "";
                setStatus("", false);
                loadNotes();
            }

            window.addEventListener("DOMContentLoaded", function() {
                document.getElementById("search-input").addEventListener("keydown", function(e) {
                    if (e.key === "Enter") runSearch();
                });
                loadNotes();
            });
        }

        return page.toString()
    }

}
