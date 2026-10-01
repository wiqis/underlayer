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

    public func concept_links_for(course : *Course) : vector<ConceptLink> {
        var out = vector<ConceptLink>()
        var cid_raw = course.id.copy()
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci)
            var link = ConceptLink::make()
            var href = string("/courses/")
            href.append_string(&cid_raw)
            href.append_view(string_view("/lessons/"))
            var concept_id = cref.id.copy()
            href.append_string(&concept_id)
            var href_esc = underlayer_core::html_escape(&href)
            link.href = href_esc
            var title = cref.title.copy()
            if(title.size() == 0) { title = concept_id.copy() }
            var title_esc = underlayer_core::html_escape(&title)
            link.title = title_esc
            var module_title = module_title_for(course, &concept_id)
            var module_esc = underlayer_core::html_escape(&module_title)
            link.module_title = module_esc
            out.push(link)
            ci = ci + 1
        }
        return out
    }

    public func minutes_of(course : *Course) : int {
        var total = 0
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci)
            total = total + cref.estimated_minutes
            ci = ci + 1
        }
        return total
    }

    public func build_card(course : *Course, routes : &vector<PathRoute>) : CatalogCard {
        var card = CatalogCard::make()
        var href = string("/courses/")
        var cid = course.id.copy()
        href.append_string(&cid)
        var href_esc = underlayer_core::html_escape(&href)
        card.href = href_esc
        var title = course.title.copy()
        var title_esc = underlayer_core::html_escape(&title)
        card.title = title_esc
        var desc = course.description.copy()
        var desc_esc = underlayer_core::html_escape(&desc)
        card.description = desc_esc
        var diff = course.difficulty.copy()
        var diff_esc = underlayer_core::html_escape(&diff)
        card.difficulty = diff_esc
        var imp = course.importance.copy()
        var imp_esc = underlayer_core::html_escape(&imp)
        card.importance = imp_esc
        card.modules = course.modules.size() as int
        card.concepts = course.concepts.size() as int
        card.minutes = minutes_of(course)
        card.place = placement_of(routes, &cid)
        var reason = card.place.reason.copy()
        var reason_esc = underlayer_core::html_escape(&reason)
        card.place.reason = reason_esc
        card.concept_links = concept_links_for(course)
        return card
    }

    public func build_catalog(courses : &vector<Course>, routes : &vector<PathRoute>) : vector<CatalogCard> {
        var out = vector<CatalogCard>()
        var i : size_t = 0
        while(i < courses.size()) {
            var c = courses.get_ptr(i)
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
        var href_esc = underlayer_core::html_escape(&href)
        rc.card.href = href_esc
        var viz = href.copy()
        viz.append_view(string_view("/path"))
        var viz_esc = underlayer_core::html_escape(&viz)
        rc.viz_href = viz_esc
        var id_esc = underlayer_core::html_escape(&cid)
        rc.card.title = id_esc
        var idx = course_index(courses, &cid)
        if(idx < 0) { return rc }
        var c = courses.get_ptr(idx as size_t)
        var real = build_card(c, routes)
        rc.card = real
        rc.card.place.step = step_no
        var di : size_t = 0
        while(di < c.dependencies.size()) {
            var dep = c.dependencies.get_ptr(di).copy()
            rc.deps.push(dep)
            di = di + 1
        }
        rc.found = true
        return rc
    }

}