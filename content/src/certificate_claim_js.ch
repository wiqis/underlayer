// underlayer_content — the certificate claim's behaviour.
//
// SPLIT OUT OF certificate_claim.ch ONLY TO KEEP THAT FILE READABLE; same
// namespace, same block, one concern: that file is the markup and the styles,
// this one is what the button does.
//
// THREE REQUESTS AND NO MORE, IN THIS ORDER:
//   1. GET  /api/certificates     -- "have I already claimed one for this course?"
//   2. GET  /api/progress/<id>    -- only when the answer is no, "is it finished?"
//   3. POST /api/certificates     -- only when the answer to 2 is yes, and only
//                                   because a human pressed the button.
//
// The order is the whole design.  A page load makes at most two GETs and no
// write, so reloading this page cannot issue a certificate, and a learner who
// has finished a course sees the claim offered to them rather than having it
// done to them.
//
// NOTHING IS BUILT BY CONCATENATION.  Every value goes in with textContent, so
// a learner_name or a completion_date that happens to contain markup is shown
// as those characters.  Same reason as the note list in lesson_tools_js.ch.
//
// EVERY CATCH IS EMPTY ON PURPOSE.  No backend, no token, no course in the
// pathname -- all three leave the box hidden, which is the correct rendering of
// "this does not apply to you" and never a broken page.
public namespace underlayer_content {

    public func render_certificate_claim_js(page : &mut HtmlPage) {
        #js {
            (function() {
                var box = document.getElementById('cert-claim');
                if (!box) { return; }
                var label = document.getElementById('cert-claim-label');
                var link = document.getElementById('cert-claim-link');
                var btn = document.getElementById('cert-claim-btn');
                if (!label || !link || !btn) { return; }
                var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
                var courseId = (parts.length >= 2 && parts[0] === 'courses') ? parts[1] : null;
                if (!courseId) { return; }
                var token = '';
                try { token = localStorage.getItem('session_token') || ''; } catch (e) { token = ''; }
                if (token.length === 0) { return; }
                var headers = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token };

                function showClaimable() {
                    label.textContent = 'Every concept in this course read.';
                    btn.hidden = false;
                    box.hidden = false;
                }
                function paintIssued(row) {
                    var when = row.completion_date || '';
                    if (when) {
                        label.textContent = 'Certificate issued ' + when + '.';
                    } else {
                        label.textContent = 'Certificate issued.';
                    }
                    link.href = '/certificates/' + encodeURIComponent(row.id);
                    link.hidden = false;
                    box.hidden = false;
                }

                btn.addEventListener('click', function() {
                    btn.disabled = true;
                    fetch('/api/certificates', {
                        method: 'POST',
                        headers: headers,
                        body: JSON.stringify({ course_id: courseId })
                    }).then(function(r) { return r.json(); }).then(function(d) {
                        btn.disabled = false;
                        if (d && d.id) { paintIssued(d); btn.hidden = true; return; }
                        // A repeat POST answers {"error":"certificate already
                        // issued","certificate_id":"..."} with HTTP 200, so the
                        // error branch has to be handled rather than assumed
                        // away.
                        var existing = d && d.certificate_id ? d.certificate_id : '';
                        if (existing) { paintIssued({ id: existing, completion_date: '' }); btn.hidden = true; return; }
                        // The server refuses an unfinished course with 403 and
                        // {"error":"course not complete","concepts_started":N,
                        // "concepts_total":M,...}  (web/src/completion_gate.ch).
                        // Say the counts rather than "try again", because the
                        // one thing a learner who cannot claim needs to know is
                        // how much is left.  The same shape is what a POST made
                        // by hand without the button produces, and it is the
                        // honest answer in both cases.
                        if (d && d.error === 'course not complete') {
                            label.textContent = 'Not finished: ' + d.concepts_started + ' of ' + d.concepts_total + ' concepts read.';
                            return;
                        }
                        label.textContent = 'Could not issue it. Try again.';
                    }).catch(function() {
                        btn.disabled = false;
                        label.textContent = 'Could not issue it - offline.';
                    });
                });

                fetch('/api/certificates', { headers: headers })
                    .then(function(r) { return r.json(); })
                    .then(function(list) {
                        var rows = list || [];
                        for (var i = 0; i < rows.length; i++) {
                            if (rows[i].course_id === courseId) { paintIssued(rows[i]); return; }
                        }
                        fetch('/api/progress/' + encodeURIComponent(courseId), { headers: headers })
                            .then(function(r) { return r.json(); })
                            .then(function(p) {
                                var pct = p.progress_percentage || 0;
                                if (pct >= 100) { showClaimable(); }
                            })
                            .catch(function() { });
                    })
                    .catch(function() { });
            })();
        }
    }

}