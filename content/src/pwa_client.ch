// underlayer_content — PWA client: registration, offline state, queued writes.
//
// Progress recorded while offline is a queued /api/progress/sync change. The
// server applies its own per-key last-write-wins rule and never writes FSRS
// from that endpoint, so replay cannot overwrite a schedule. Nothing here
// caches or replays a review rating.
using std::string

public namespace underlayer_content {

    public func render_pwa_client(page : &mut HtmlPage) {
        #css {
            .nav-offline { display: inline-block; margin-left: 0.75rem; padding: 0.2rem 0.55rem; border-radius: 999px; border: 1px solid hsl(var(--border)); background: hsl(var(--card)); color: hsl(var(--muted-foreground)); font-size: 0.75rem; }
            .nav-offline[hidden] { display: none !important; }
        }
        #js {
            (function() {
                var QKEY = 'ul_offline_queue';
                function qRead() {
                    try { return JSON.parse(localStorage.getItem(QKEY) || '[]') || []; } catch(e) { return []; }
                }
                function qWrite(list) {
                    try { localStorage.setItem(QKEY, JSON.stringify(list)); } catch(e) {}
                }
                function ulNow() { return Math.floor(Date.now() / 1000); }
                window.__ulQueueUnit = function(course, concept, unit, step, status) {
                    var list = qRead();
                    var change = { course_id: course, concept_id: concept, unit_id: unit || 'unit-why',
                        status: status || 'seen', step_index: step || 1, updated_at: ulNow() };
                    var i = 0;
                    while (i < list.length) {
                        if (list[i].course_id === change.course_id && list[i].concept_id === change.concept_id && list[i].unit_id === change.unit_id) {
                            if (change.updated_at >= list[i].updated_at) { list[i] = change; }
                            qWrite(list);
                            return;
                        }
                        i = i + 1;
                    }
                    list.push(change);
                    qWrite(list);
                };
                window.__ulReplayProgress = function() {
                    var list = qRead();
                    if (list.length === 0) { return Promise.resolve(true); }
                    var headers = { 'Content-Type': 'application/json' };
                    if (typeof window.__ulHeaders === 'function') {
                        var inherited = window.__ulHeaders();
                        for (var k in inherited) { if (Object.prototype.hasOwnProperty.call(inherited, k)) { headers[k] = inherited[k]; } }
                    }
                    return fetch('/api/progress/sync', {
                        method: 'POST', credentials: 'same-origin', headers: headers,
                        body: JSON.stringify({ client_now: ulNow(), changes: list })
                    }).then(function(r) {
                        if (!r.ok) { return false; }
                        qWrite([]);
                        return true;
                    }).catch(function() { return false; });
                };
                window.__ulCacheCourse = function(courseId) {
                    if (!navigator.serviceWorker || !courseId) { return; }
                    fetch('/api/courses/' + encodeURIComponent(courseId), { credentials: 'same-origin' })
                        .then(function(r) { return r.json(); })
                        .then(function(d) {
                            var paths = [];
                            var cs = d.concepts || [];
                            var i = 0;
                            while (i < cs.length) {
                                paths.push('/courses/' + courseId + '/lessons/' + cs[i].id);
                                i = i + 1;
                            }
                            navigator.serviceWorker.ready.then(function(reg) {
                                if (reg.active) { reg.active.postMessage({ type: 'cache-paths', paths: paths }); }
                            }).catch(function() {});
                        }).catch(function() {});
                };
                function ulIndicator(offline) {
                    var el = document.getElementById('ul-offline-indicator');
                    if (!el) { return; }
                    el.hidden = !offline;
                }
                document.addEventListener('DOMContentLoaded', function() {
                    ulIndicator(!navigator.onLine);
                    window.addEventListener('offline', function() { ulIndicator(true); });
                    window.addEventListener('online', function() {
                        ulIndicator(false);
                        window.__ulReplayProgress();
                    });
                    window.__ulReplayProgress();
                });
                if ('serviceWorker' in navigator && window.location.protocol !== 'file:') {
                    window.addEventListener('load', function() {
                        navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(function() {});
                    });
                }
            })();
        }
    }

}
