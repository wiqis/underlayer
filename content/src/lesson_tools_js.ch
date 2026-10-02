// underlayer_content — the tools row's behaviour: bookmark, note, report.
//
// THE THREE CALLS, WITH THE SHAPE EACH ONE ACTUALLY HAS.  Every one of these
// was verified with curl against the running server on 2026-10-02 before this
// client was written, because a client written against a guessed shape is worse
// than no client -- it fails in the browser where nobody is watching.
//
//   GET    /api/bookmarks/check/:conceptId  -> {"bookmarked":false}      200
//   POST   /api/bookmarks   {course_id, concept_id, note}  -> {"ok":true,"id":"..."}
//   DELETE /api/bookmarks/:conceptId        -> {"ok":true}
//   GET    /api/notes/concept/:conceptId    -> [ {id, concept_id, course_id,
//                                                content, section_ref,
//                                                created_at, updated_at} ]
//   POST   /api/notes {course_id, concept_id, content, section_ref} -> {"ok":true,"id":"..."}
//   PUT    /api/notes/:id  {content}       -> {"ok":true}
//   DELETE /api/notes/:id                  -> {"ok":true}
//   POST   /api/feedback {concept_id, course_id, feedback_type, message, page_url}
//                                        -> {"ok":true,"id":"..."}
//
// WHAT THIS CLIENT DELIBERATELY DOES NOT CALL, AND WHY.  GET
// /api/feedback/concept/:conceptId returns EVERY learner's feedback for a
// concept -- ids, learner_id, message, status -- and it does so with no
// Authorization header at all, which was verified: an unauthenticated curl gets
// a full list back with HTTP 200.  Rendering that list on a lesson page would
// publish every learner's corrections and every learner's id to anyone who opens
// the page.  So the report form POSTs and then says "Sent", and never reads the
// list back.  The endpoint wanting an auth check is a server-side fix and is
// reported separately; a lesson page is the worst possible place to start using
// it.
//
// TWO MORE SERVER FACTS THIS CLIENT RESPONDS TO RATHER THAN IGNORES.
//
//   * POST /api/bookmarks does not de-duplicate.  Two presses create two rows,
//     is_bookmarked() answers true to both, and DELETE removes both.  So the
//     toggle does not decide from "have I pressed this" -- it decides from the
//     aria-pressed value, which came from GET .../check.  One press, one row.
//   * PUT and DELETE /api/notes/:id take a note id and do NOT check that the
//     note belongs to the caller (web/src/handlers_notes.ch resolves
//     learner_id and then never uses it).  That is an IDOR on the server.  This
//     client is not the hole -- it only ever passes ids that came back from the
//     caller's own GET /api/notes/concept/:conceptId -- and it is reported
//     separately.  Wiring a page to an endpoint should not become the reason
//     that endpoint gets used.
//
// NOTHING IS BUILT BY CONCATENATION.  The note list is assembled with
// document.createElement and textContent, never with innerHTML, so a note
// containing "<script>" is shown as those characters instead of executed.  That
// is also the AGENTS.md rule about string-built markup, arrived at from the
// security side rather than the macro side.
//
// THE TWO #js RULES FROM lesson_engagement_js.ch ARE THE RULES HERE: no
// arithmetic inside a string concatenation (compute into a `var` first), and no
// parenthesised sub-expression in an operand position.
public namespace underlayer_content {

    public func render_lesson_tools_js(page : &mut HtmlPage) {
        #js {
            window.__ulPanelState = function(id, text, good) {
                var el = document.getElementById(id);
                if (!el) { return; }
                el.textContent = text;
                if (good) { el.className = 'ul-panel-state saved'; } else { el.className = 'ul-panel-state failed'; }
            };

            // ---- bookmark ----
            window.__ulPaintBookmark = function(on) {
                var b = document.getElementById('ul-bookmark');
                if (!b) { return; }
                if (on) { b.setAttribute('aria-pressed', 'true'); b.textContent = 'Bookmarked'; b.className = 'ul-tool ul-tool-on'; } else { b.setAttribute('aria-pressed', 'false'); b.textContent = 'Bookmark'; b.className = 'ul-tool'; }
            };
            window.__ulLoadBookmark = function(ctx) {
                var url = '/api/bookmarks/check/' + encodeURIComponent(ctx.concept);
                fetch(url, { headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(d) { window.__ulPaintBookmark(d.bookmarked === true); })
                    .catch(function() { });
            };
            window.__ulToggleBookmark = function(ctx) {
                var b = document.getElementById('ul-bookmark');
                if (!b) { return; }
                if (b.getAttribute('aria-pressed') === 'true') {
                    fetch('/api/bookmarks/' + encodeURIComponent(ctx.concept), { method: 'DELETE', headers: window.__ulHeaders() })
                        .then(function(r) { return r.json(); })
                        .then(function() { window.__ulPaintBookmark(false); })
                        .catch(function() { });
                    return;
                }
                fetch('/api/bookmarks', {
                    method: 'POST',
                    headers: window.__ulHeaders(),
                    body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept, note: '' })
                })
                    .then(function(r) { return r.json(); })
                    .then(function(d) { window.__ulPaintBookmark(d.ok === true); })
                    .catch(function() { });
            };

            // ---- notes ----
            // The id of the note the textarea is currently editing, or '' for a
            // new one.  A save with an id is a PUT and a save without is a POST,
            // which is the whole of "annotate": write it once, change it later.
            window.__ulNoteEditing = '';
            // The rows the last GET returned, kept so the click handlers can find
            // a note by id without round-tripping its text through an attribute.
            window.__ulNoteRows = [];
            window.__ulRenderNotes = function(rows) {
                var ul = document.getElementById('ul-note-list');
                if (!ul) { return; }
                ul.textContent = '';
                var list = rows || [];
                window.__ulNoteRows = list;
                for (var i = 0; i < list.length; i++) {
                    var n = list[i];
                    var li = document.createElement('li');
                    li.className = 'ul-note-item';
                    li.setAttribute('data-note-id', n.id);
                    var body = document.createElement('span');
                    body.className = 'ul-note-text-body';
                    body.textContent = n.content;
                    var edit = document.createElement('button');
                    edit.type = 'button';
                    edit.className = 'ul-note-edit';
                    edit.textContent = 'Edit';
                    edit.setAttribute('data-note-action', 'edit');
                    var del = document.createElement('button');
                    del.type = 'button';
                    del.className = 'ul-note-delete';
                    del.textContent = 'Delete';
                    del.setAttribute('data-note-action', 'delete');
                    li.appendChild(body);
                    li.appendChild(edit);
                    li.appendChild(del);
                    ul.appendChild(li);
                }
            };
            window.__ulLoadNotes = function(ctx) {
                var url = '/api/notes/concept/' + encodeURIComponent(ctx.concept);
                fetch(url, { headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(d) { window.__ulRenderNotes(d); })
                    .catch(function() { });
            };
            window.__ulEditNote = function(id, content) {
                window.__ulNoteEditing = id;
                var ta = document.getElementById('ul-note-text');
                if (ta) { ta.value = content; }
                var panel = document.getElementById('ul-notes-panel');
                if (panel) { panel.hidden = false; }
                var btn = document.getElementById('ul-notes-toggle');
                if (btn) { btn.setAttribute('aria-expanded', 'true'); }
                window.__ulPanelState('ul-note-state', 'Editing a saved note.', true);
            };
            window.__ulSaveNote = function(ctx) {
                var ta = document.getElementById('ul-note-text');
                if (!ta) { return; }
                var content = ta.value;
                if (content.length === 0) {
                    window.__ulPanelState('ul-note-state', 'Write something first.', false);
                    return;
                }
                var editing = window.__ulNoteEditing;
                var req;
                if (editing.length > 0) {
                    req = fetch('/api/notes/' + encodeURIComponent(editing), { method: 'PUT', headers: window.__ulHeaders(), body: JSON.stringify({ content: content }) });
                } else {
                    req = fetch('/api/notes', {
                        method: 'POST',
                        headers: window.__ulHeaders(),
                        body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept, content: content, section_ref: '' })
                    });
                }
                req.then(function(r) { return r.json(); })
                    .then(function() {
                        window.__ulNoteEditing = '';
                        ta.value = '';
                        window.__ulPanelState('ul-note-state', 'Saved.', true);
                        window.__ulLoadNotes(ctx);
                    })
                    .catch(function() { window.__ulPanelState('ul-note-state', 'Not saved - offline.', false); });
            };
            window.__ulDeleteNote = function(ctx, id) {
                fetch('/api/notes/' + encodeURIComponent(id), { method: 'DELETE', headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function() { window.__ulLoadNotes(ctx); })
                    .catch(function() { });
            };
        }
    }

}