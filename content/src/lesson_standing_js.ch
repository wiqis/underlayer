// underlayer_content — how the learner is standing, on the page they are reading.
//
// WHY THE STREAK AND THE ACHIEVEMENT COUNT ARE HERE AND NOT IN THE DASHBOARD
// ONLY.  Measured 2026-10-02: /api/streaks and /api/achievements were called
// from zero of the 438 page builders, so the two numbers the platform works
// hardest to compute were visible on exactly two pages out of four hundred.  A
// streak that is only visible on the streak page is a streak with nothing to
// attach to; a learner needs to see "Day 4" while reading, because that is the
// moment it can still be extended.  One chip each, and both link nowhere --
// they are the number, not a button.
//
// THE SHAPES, VERIFIED WITH CURL BEFORE THIS WAS WRITTEN.
//   GET /api/streaks              -> {"learner_id":"...","current_streak":1,
//                                     "longest_streak":1,"total_active_days":1,
//                                     "last_active_date":"2026-10-02"}
//   GET /api/achievements/count   -> {"count":0}
//
// WHY THIS FILE RE-DECLARES __ulToken / __ulHeaders INSTEAD OF CALLING THE ONES
// IN lesson_engagement_js.ch.  The nav is also rendered by web/src/nav_bar.ch on
// collection pages, which do NOT call render_lesson_engagement -- so on /courses
// those two helpers do not exist, and calling them unguarded throws a
// TypeError in the middle of the nav script.  Declaring them again under the
// same names is idempotent (`window.x = window.x || ...`) and makes each file
// safe on its own.  The alternative -- moving them into the nav -- would have
// meant the nav owned a helper that only lesson pages use, which is the same
// layering mistake in the other direction.
//
// WHY NO TOKEN MEANS NO CALL AT ALL, HERE ESPECIALLY.  GET /api/streaks does not
// 401 a signed-out caller.  web/src/handlers_streaks.ch falls back to the literal
// learner id "demo", so an unauthenticated GET answers 200 with the SHARED
// demo learner's streak -- verified -- and POST /api/streaks/activity is equally
// unauthenticated and writes to that same shared bucket.  A lesson page that
// fetched it without a token would show one stranger's streak to every signed-
// out reader.  So the gate is in the caller, and the gate is the token.
//
// ZERO IS NOT SHOWN.  A chip reading "0-day streak" or "0 achievements" is a
// thing to apologise for, and this collection's design rules forbid a UI that
// makes a learner feel behind for not having started.  The chips appear when
// there is something to say.
public namespace underlayer_content {

    public func render_lesson_standing_js(page : &mut HtmlPage) {
        #js {
            // Declared here (and in lesson_identity.ch) so the nav can ask who is
            // signed in on COLLECTION pages, which never call
            // render_lesson_engagement and so never get its copies.
            window.__ulToken = window.__ulToken || function() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            };
            window.__ulHeaders = window.__ulHeaders || function() {
                var h = { 'Content-Type': 'application/json' };
                var t = window.__ulToken();
                if (t) { h['Authorization'] = 'Bearer ' + t; }
                return h;
            };

            window.__ulPaintStreak = function(d) {
                var el = document.getElementById('ul-streak');
                if (!el) { return; }
                var days = d.current_streak || 0;
                if (days < 1) { el.hidden = true; return; }
                el.textContent = days + '-day streak';
                el.className = 'ul-chip streak';
                el.hidden = false;
            };
            window.__ulPaintAchievements = function(count) {
                var el = document.getElementById('ul-achievements');
                if (!el) { return; }
                if (count < 1) { el.hidden = true; return; }
                var word = 'achievements';
                if (count === 1) { word = 'achievement'; }
                el.textContent = count + ' ' + word;
                el.className = 'ul-chip achieved';
                el.hidden = false;
            };
            window.__ulLoadStanding = function() {
                fetch('/api/streaks', { headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(d) { window.__ulPaintStreak(d); })
                    .catch(function() { });
                fetch('/api/achievements/count', { headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(d) { window.__ulPaintAchievements(d.count || 0); })
                    .catch(function() { });
            };
        }
    }

}