// underlayer_content — the report-a-problem form, and the panel wiring.
//
// SPLIT FROM lesson_tools_js.ch ONLY TO KEEP THAT FILE UNDER 250 LINES (AGENTS.md
// "no file over 250 lines").  Same namespace, same script block, one concern:
// this one is the WRITE half (report) and the wiring, where its sibling is the
// read-and-toggle half (bookmark, note).
//
// THE FEEDBACK SHAPE, VERIFIED WITH CURL BEFORE THIS WAS WRITTEN.
//   POST /api/feedback
//     body: {concept_id, course_id, feedback_type, message, page_url}
//     200:  {"ok":true,"id":"..."}
//   All three of concept_id, feedback_type and message are required; the
//   handler answers 400 naming the one that is missing, so the form's own
//   client-side check (an empty textarea) is a courtesy and not the enforcement.
//
// feedback_type is a free string as far as the server is concerned -- there is
// no enum in web/src/handlers_feedback.ch and no CHECK in the schema -- so the
// four values in the select are the platform's vocabulary, chosen to be the four
// things a reader of a technical lesson actually wants to say: a wrong fact, an
// unclear passage, something broken, and a gap.
//
// WHY THERE IS NO "SEE WHAT OTHERS REPORTED" LINK HERE, when the endpoint that
// would power it exists and works.  GET /api/feedback/concept/:conceptId is
// unauthenticated and returns every learner's feedback for the concept,
// including learner_id and message.  Rendering it on a lesson page would publish
// that to every reader.  The endpoint needs an auth check on the server; until it
// has one, a page that links to it is the defect.  Reported separately.
public namespace underlayer_content {

    public func render_lesson_feedback_js(page : &mut HtmlPage) {
        #js {
            window.__ulSendFeedback = function(ctx) {
                var ta = document.getElementById('ul-feedback-message');
                if (!ta) { return; }
                var message = ta.value;
                if (message.length === 0) {
                    window.__ulPanelState('ul-feedback-state', 'Say what is wrong first.', false);
                    return;
                }
                // The default is 'correction' AND NOT the first option's value read back from
                // the select, because a select whose value comes back empty --
                // a browser with an odd option set, a form restored from cache,
                // a test shim -- would POST an empty feedback_type and the
                // handler would answer 400 "feedback_type is required" with a
                // learner staring at "Not sent." and no reason.  Finding that
                // shape out cost a run of tools/integration_check.py.
                var kind = 'correction';
                var sel = document.getElementById('ul-feedback-type');
                if (sel && sel.value) { kind = sel.value; }
                fetch('/api/feedback', {
                    method: 'POST',
                    headers: window.__ulHeaders(),
                    body: JSON.stringify({ concept_id: ctx.concept, course_id: ctx.course, feedback_type: kind, message: message, page_url: window.location.pathname })
                })
                    .then(function(r) { return r.json(); })
                    .then(function(d) {
                        if (d.ok !== true) {
                            window.__ulPanelState('ul-feedback-state', 'Not sent.', false);
                            return;
                        }
                        ta.value = '';
                        window.__ulPanelState('ul-feedback-state', 'Sent. Thank you.', true);
                    })
                    .catch(function() { window.__ulPanelState('ul-feedback-state', 'Not sent - offline.', false); });
            };

            window.__ulTogglePanel = function(btnId, panelId) {
                var panel = document.getElementById(panelId);
                var btn = document.getElementById(btnId);
                if (!panel || !btn) { return; }
                var open = panel.hidden;
                panel.hidden = !open;
                if (open) { btn.setAttribute('aria-expanded', 'true'); } else { btn.setAttribute('aria-expanded', 'false'); }
            };

            window.__ulWireTools = function(ctx) {
                var bm = document.getElementById('ul-bookmark');
                if (bm) { bm.addEventListener('click', function() { window.__ulToggleBookmark(ctx); }); }
                var nt = document.getElementById('ul-notes-toggle');
                if (nt) { nt.addEventListener('click', function() { window.__ulTogglePanel('ul-notes-toggle', 'ul-notes-panel'); }); }
                var ft = document.getElementById('ul-feedback-toggle');
                if (ft) { ft.addEventListener('click', function() { window.__ulTogglePanel('ul-feedback-toggle', 'ul-feedback-panel'); }); }
                var ns = document.getElementById('ul-note-save');
                if (ns) { ns.addEventListener('click', function() { window.__ulSaveNote(ctx); }); }
                var fs = document.getElementById('ul-feedback-save');
                if (fs) { fs.addEventListener('click', function() { window.__ulSendFeedback(ctx); }); }
                // ONE DELEGATED LISTENER for the per-note controls, because
                // those nodes are built from the server's own rows and there is
                // nowhere else to hang a handler on them.  The action comes from
                // data-note-action and the id from the row's own data-note-id, so
                // this does not have to know how many notes there are.
                var list = document.getElementById('ul-note-list');
                if (list) {
                    list.addEventListener('click', function(ev) {
                        var t = ev.target;
                        if (!t || !t.getAttribute) { return; }
                        var action = t.getAttribute('data-note-action');
                        if (!action) { return; }
                        var row = t.parentNode;
                        if (!row || !row.getAttribute) { return; }
                        var id = row.getAttribute('data-note-id');
                        if (!id) { return; }
                        if (action === 'delete') {
                            window.__ulDeleteNote(ctx, id);
                            return;
                        }
                        var rows = window.__ulNoteRows || [];
                        for (var i = 0; i < rows.length; i++) {
                            if (rows[i].id === id) {
                                window.__ulEditNote(id, rows[i].content);
                                return;
                            }
                        }
                    });
                }
            };
        }
    }

}