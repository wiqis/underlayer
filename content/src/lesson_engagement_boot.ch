// underlayer_content — WHEN the engagement runs.  Split out of
// lesson_engagement_js.ch purely to keep that file under 250 lines (AGENTS.md
// "no file over 250 lines"); the logic is unchanged and the split is a
// namespace boundary, not a new idea.
//
// This file is the part with the bug in it, so it is the part that earns its
// own file and its own explanation: the start function used to be registered on
// BOTH DOMContentLoaded and pageshow, and a normal page load fires both.  Every
// genuine page view therefore recorded TWO reads -- the first answering
// first_time:true and the second first_time:false, so a learner's very first
// visit to a concept was labelled "read before", and record_activity() and
// run_achievement_checks() each ran twice.
//
// Nothing in the source looks wrong.  Both registrations are individually
// defensible: one is "the page is ready", the other is "the page was restored".
// tools/progress_check.py found it, by running the emitted script in Node
// against a DOM shim that fires both handlers the way a browser does.
//
// THE FLAG IS PER DOCUMENT, and that is what makes it correct rather than
// merely quiet.  A back/forward-cache restore replays pageshow WITHOUT
// re-running DOMContentLoaded, so the flag is still set from the original load
// and the restore is correctly not counted as a new read -- which is the whole
// reason the pageshow listener exists.  A real navigation to a lesson builds a
// new document, the flag is false again, and the read is recorded once.
public namespace underlayer_content {

    public func render_lesson_engagement_boot(page : &mut HtmlPage) {
        #js {
            window.__ulStartEngagement = function() {
                if (window.__ulEngagementStarted) { return; }
                window.__ulEngagementStarted = true;
                var ctx = window.__ulPosition();
                // Not a lesson URL: the nav also renders on collection pages,
                // and there is nothing to record there.  The flag stays set,
                // which is harmless -- this document has no lesson.
                if (ctx === null) { return; }
                var strip = document.getElementById('ul-progress');
                if (strip) { strip.hidden = false; }
                window.__ulLoadPosition(ctx);
                window.__ulReportRead(ctx);
                window.__ulLoadProgress(ctx);
            };
            document.addEventListener('DOMContentLoaded', function() { window.__ulStartEngagement(); });
            // `persisted` is true only for a bfcache restore.  The guard on
            // __ulEngagementStarted above covers the ordinary case where this
            // and DOMContentLoaded are the same load seen twice.
            window.addEventListener('pageshow', function(ev) {
                if (ev.persisted) { return; }
                window.__ulStartEngagement();
            });
        }
    }

}