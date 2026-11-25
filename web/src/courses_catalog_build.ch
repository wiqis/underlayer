// underlayer_web — Build the /courses catalog and the /learning-path steps
// from the manifests on disk.
//
// Nothing here is written down twice.  The card counts come from the loaded
// Course, the minutes come from summing the concepts' `estimated_minutes`, and
// the route placement comes from the authored routes in routes_*.ch -- so the
// index cannot drift away from what /api/courses already reports.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public func concept_links_for(course : &Course) : vector<ConceptLink> {
        var out = vector<ConceptLink>()
        var cid_raw = course.id.copy()
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.at_ref(ci)
            var link = ConceptLink::make()
            var href = string("/courses/")
            href.append_string(&cid_raw)
            href.append_view(string_view("/lessons/"))
            var concept_id = cref.id.copy()
            href.append_string(&concept_id)
            // Raw here: #html escapes once when these reach the page.
            link.href = href
            var title = cref.title.copy()
            if(title.size() == 0) { title = concept_id.copy() }
            link.title = title
            link.module_title = module_title_for(course, &concept_id)
            out.push(link)
            ci = ci + 1
        }
        return out
    }

    public func minutes_of(course : &Course) : int {
        var total = 0
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.at_ref(ci)
            total = total + cref.estimated_minutes
            ci = ci + 1
        }
        return total
    }

    public func build_card(course : &Course, routes : &vector<PathRoute>) : CatalogCard {
        var card = CatalogCard::make()
        var href = string("/courses/")
        var cid = course.id.copy()
        href.append_string(&cid)
        // Values are stored RAW.  The #html macro escapes every {value} once,
        // so escaping here as well produced literal "&#39;" on /courses and
        // /learning-path.  One escape, at the point of use, and nowhere else.
        card.href = href
        card.title = course.title.copy()
        card.description = course.description.copy()
        card.difficulty = course.difficulty.copy()
        card.importance = course.importance.copy()
        card.modules = course.modules.size() as int
        card.concepts = course.concepts.size() as int
        card.minutes = minutes_of(course)
        card.place = placement_of(routes, &cid)
        card.concept_links = concept_links_for(course)
        // The search box on /courses matches this one field; it carries no
        // markup and is lowercased by the browser, not by the page.
        var hay = course.title.copy()
        hay.append_view(string_view(" "))
        hay.append_string(&course.description)
        hay.append_view(string_view(" "))
        hay.append_string(&course.difficulty)
        card.search_text = ascii_lower(&hay.to_view())
        return card
    }

    public func build_catalog(courses : &vector<Course>, routes : &vector<PathRoute>) : vector<CatalogCard> {
        var out = vector<CatalogCard>()
        var i : size_t = 0
        while(i < courses.size()) {
            var c = courses.at_ref(i)
            var card = build_card(c, routes)
            out.push(card)
            i = i + 1
        }
        return out
    }

    // One course named by a route, resolved against the manifests.  A route
    // step pointing at a course that is not on disk renders as the id alone,
    // with the position and the reason still shown, rather than as a 404 link
    // the learner would have to click in order to discover.
    public struct RouteCourse {
        var found : bool
        var step : int
        var card : CatalogCard
        var viz_href : string
        var deps : vector<string>

        @make
        func make() : RouteCourse {
            return RouteCourse {
                found = false,
                step = 0,
                card = CatalogCard::make(),
                viz_href = string(),
                deps = vector<string>()
            }
        }
    }

    public func resolve_route_course(courses : &vector<Course>, routes : &vector<PathRoute>, course_id : &string, step_no : int) : RouteCourse {
        var rc = RouteCourse::make()
        var cid = course_id.copy()
        rc.step = step_no
        rc.card.place.step = step_no
        var href = string("/courses/")
        href.append_string(&cid)
        rc.card.href = href
        var viz = href.copy()
        viz.append_view(string_view("/path"))
        rc.viz_href = viz
        rc.card.title = cid.copy()
        var idx = course_index(courses, &cid)
        if(idx < 0) { return rc }
        var c = courses.at_ref(idx as size_t)
        var real = build_card(c, routes)
        rc.card = real
        rc.card.place.step = step_no
        var di : size_t = 0
        while(di < c.dependencies.size()) {
            var dep = c.dependencies.at_ref(di).copy()
            rc.deps.push(dep)
            di = di + 1
        }
        rc.found = true
        return rc
    }

}