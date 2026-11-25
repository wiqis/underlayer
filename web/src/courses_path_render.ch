// underlayer_web — #html components for the ordered /learning-path view.
//
// The steps of a route are a chain, and a chain reads wrong as a wall of
// prose: the whole point of the order is that step N needs step N-1.  Each row
// therefore shows ONLY what a learner needs to move on -- position, title, one
// sentence of "why here", time -- and puts the full argument and the declared
// prerequisites behind one labelled "Why is this here?" disclosure.
//
// Values reach #html RAW: the macro escapes once.  Pre-escaping here produced
// the literal text &#39; on both /courses and /learning-path.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    private func pathIsSpace(ch : char) : bool {
        return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    }

    // The first sentence of the authored reason: one line a learner can read
    // while deciding what to do next.  The full paragraph stays in the
    // disclosure below it, so no technical content is lost.
    private func pathFirstSentence(s : &string) : string {
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c == '.' || c == '?' || c == '!') {
                if(i + 1 >= s.size() || pathIsSpace(s.at(i + 1))) { return s.substring(0, i + 1) }
            }
            i = i + 1
        }
        return s.copy()
    }

    // One step: position, course, one-sentence why, time, then the disclosure.
    public func render_route_step(rc : &RouteCourse, page : &mut HtmlPage) {
        var brief = pathFirstSentence(&rc.card.place.reason)
        #html {
            <li class="route-step">
                <div class="step-head">
                    <span class="step-num">{rc.step}</span>
                    @if(rc.found) {
                        <a class="step-course" href={rc.card.href}>{rc.card.title}</a>
                    } @else {
                        <span class="step-course step-missing">{rc.card.title}</span>
                    }
                </div>
                <p class="step-why">{brief}</p>
                <p class="step-time">{rc.card.minutes} min &middot; {rc.card.concepts} lessons</p>
                <details class="step-why-detail">
                    <summary>Why is this here?</summary>
                    <p class="step-why-full">{rc.card.place.reason}</p>
                    {render_step_prereqs(&rc.deps, page)}
                </details>
            </li>
        }
    }

    // The prerequisites this step's manifest declares, as labelled chips.
    public func render_step_prereqs(deps : &vector<string>, page : &mut HtmlPage) {
        #html {
            <div class="step-prereqs">
                <span class="prereq-label">Prerequisites already covered</span>
                {render_prereq_items(deps, page)}
            </div>
        }
    }

    public func render_prereq_items(deps : &vector<string>, page : &mut HtmlPage) {
        var n : size_t = deps.size()
        if(n == 0) {
            #html {
                <span class="prereq-none">none &mdash; nothing in the collection declares this one as a dependency</span>
            }
            return
        }
        var i : size_t = 0
        while(i < n) {
            var dep = deps.at_ref(i).copy()
            var href = string("/courses/")
            href.append_string(&dep)
            #html {
                <a class="prereq" href={href}>{dep}</a>
            }
            i = i + 1
        }
    }

    // The verifier's numbers, printed.  Kept on /learning-path only, where the
    // claim "this order is walkable" is actually being made.
    public func render_route_check(chk : &RouteCheck, page : &mut HtmlPage) {
        #html {
            <div class="route-check">
                <p class="check-line"><strong>{chk.satisfied} of {chk.total}</strong> declared prerequisites are satisfied by this order.</p>
                @if(chk.missing_courses.size() > 0) {
                    <p class="check-bad">{chk.missing_courses.size()} route step(s) name a course that is not on disk.</p>
                } @else {
                    <p class="check-ok">All {chk.covered} courses named by the three routes exist on disk.</p>
                }
                @if(chk.duplicates.size() > 0) {
                    <p class="check-bad">{chk.duplicates.size()} course(s) are listed in more than one route.</p>
                }
                @if(chk.unmet.size() > 0) {
                    <p class="check-bad">{chk.unmet.size()} declared prerequisite(s) are unmet by this order:</p>
                    <ul class="check-list">
                        {render_unmet(&chk.unmet, page)}
                    </ul>
                }
            </div>
        }
    }

    public func render_unmet(unmet : &vector<string>, page : &mut HtmlPage) {
        var i : size_t = 0
        while(i < unmet.size()) {
            var u = unmet.at_ref(i).copy()
            #html {
                <li>{u}</li>
            }
            i = i + 1
        }
    }

    // Every step of one route, as one <ol>'s worth of <li>.
    public func render_all_steps(route : &PathRoute, courses : &vector<Course>, routes : &vector<PathRoute>, page : &mut HtmlPage) {
        var si : size_t = 0
        while(si < route.steps.size()) {
            var step = route.steps.at_ref(si)
            var rc = resolve_route_course(courses, routes, &step.course_id, si as int + 1)
            render_route_step(&mut rc, page)
            si = si + 1
        }
    }

    // ONE ordered view: three collapsible routes.  The first is opened by the
    // page script, so a reader who arrives with JavaScript off still has all
    // three summaries and can open whichever they need.
    public func render_all_routes(routes : &vector<PathRoute>, courses : &vector<Course>, page : &mut HtmlPage) {
        var ri : size_t = 0
        while(ri < routes.size()) {
            var route = routes.at_ref(ri)
            #html {
                <details class="route-card" id={`route-${route.id}`}>
                    <summary class="route-summary">
                        <span class="route-title">{route.name}</span>
                        <span class="route-tagline">{route.tagline}</span>
                    </summary>
                    <ol class="route-steps">
                        {render_all_steps(route, courses, routes, page)}
                    </ol>
                </details>
            }
            ri = ri + 1
        }
    }

}
