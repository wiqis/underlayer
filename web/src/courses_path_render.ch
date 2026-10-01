// underlayer_web — #html components for the route sections of /courses and
// /learning-path.
//
// The steps of a route are a chain, and a chain reads wrong as a numbered
// list with no visible connection between rows: the whole point of the order
// is that step N needs step N-1.  Each row therefore carries the prerequisites
// its manifest declares, so a learner can see WHY it is at this position and
// not merely be told the position.
using std::string
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    // One step: position, course, why it is HERE, its size, and the
    // prerequisites that justify the position.  Both facts come from data --
    // the reason from the authored route, the prerequisite list from the
    // manifest.
    public func render_route_step(rc : *RouteCourse, page : &mut HtmlPage) {
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
                <p class="step-why">{rc.card.place.reason}</p>
                <div class="step-meta">
                    @if(rc.found) {
                        <span>{rc.card.modules} modules</span>
                        <span>{rc.card.concepts} concepts</span>
                        <span>{rc.card.minutes} min</span>
                        <span class="stat-diff">{rc.card.difficulty}</span>
                        <a class="step-viz" href={rc.viz_href}>dependency graph</a>
                    } @else {
                        <span class="stat-missing">Named by this route but not present in courses/ &mdash; the link will 404.</span>
                    }
                </div>
                {render_step_prereqs(&rc.deps, page)}
            </li>
        }
    }

    // The prerequisites this step's manifest declares.  Every one of them is
    // already behind the learner in a verified order -- render_route_check()
    // prints the count that says so, and names any that is not.
    public func render_step_prereqs(deps : &vector<string>, page : &mut HtmlPage) {
        #html {
            <div class="step-prereqs">
                <span class="prereq-label">declared prerequisites</span>
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
            var dep_ptr = deps.get_ptr(i)
            var dep = dep_ptr.copy()
            var dep_esc = underlayer_core::html_escape(&dep)
            #html {
                <a class="prereq" href={`/courses/${dep_esc}`}>{dep_esc}</a>
            }
            i = i + 1
        }
    }

    // The verifier's numbers, printed.  A route page that claims an ordering
    // is sound without printing what it counted is a claim, and a claim is
    // what this repo does not accept.
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
            var u_ptr = unmet.get_ptr(i)
            var u = u_ptr.copy()
            var u_esc = underlayer_core::html_escape(&u)
            #html {
                <li>{u_esc}</li>
            }
            i = i + 1
        }
    }

    // Every step of one route, as one <ol>'s worth of <li>.
    public func render_all_steps(route : *PathRoute, courses : &vector<Course>, routes : &vector<PathRoute>, page : &mut HtmlPage) {
        var si : size_t = 0
        while(si < route.steps.size()) {
            var step = route.steps.get_ptr(si)
            var rc = resolve_route_course(courses, routes, &step.course_id, si as int + 1)
            render_route_step(&raw mut rc, page)
            si = si + 1
        }
    }

    // Every route, as one block's worth of <section>s.  The route name,
    // tagline and blurb are escaped here for the same reason the cards are:
    // `{value}` interpolation is raw.
    public func render_all_routes(routes : &vector<PathRoute>, courses : &vector<Course>, page : &mut HtmlPage) {
        var ri : size_t = 0
        while(ri < routes.size()) {
            var route = routes.get_ptr(ri)
            var name = route.name.copy()
            var name_esc = underlayer_core::html_escape(&name)
            var tagline = route.tagline.copy()
            var tagline_esc = underlayer_core::html_escape(&tagline)
            var blurb = route.blurb.copy()
            var blurb_esc = underlayer_core::html_escape(&blurb)
            #html {
                <section class="route-card" id={`route-${route.id}`}>
                    <h3 class="route-title">{name_esc}</h3>
                    <p class="route-tagline">{tagline_esc}</p>
                    <p class="route-blurb">{blurb_esc}</p>
                    <ol class="route-steps">
                        {render_all_steps(route, courses, routes, page)}
                    </ol>
                </section>
            }
            ri = ri + 1
        }
    }

}