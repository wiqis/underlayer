// underlayer_web — View model for the /courses index.
//
// Every string that reaches a #html block is escaped HERE, once, rather than
// at the point of use.  That is not tidiness: `html_cbi`'s `{value}`
// interpolation is raw, and a course description containing `<` produces a
// DOM nobody wrote.  docs/implementation-gaps.md says so, and
// content/src/course_landing.ch is the existing example of the pattern.
//
// Counts and minutes are computed from the loaded manifests rather than
// written down here, so adding a concept to a course cannot leave the index
// quoting a stale number.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    // One concept as a link the index can render.  `module_title` is the
    // module the concept sits in, which is the only context a bare concept
    // title has when you are looking at 398 of them.
    public struct ConceptLink {
        var href : string
        var title : string
        var module_title : string

        @make
        func make() : ConceptLink {
            return ConceptLink {
                href = string(),
                title = string(),
                module_title = string()
            }
        }
    }

    // Which route, if any, claims a course -- and at which step.  `step` is 0
    // when no route claims it, which is how "outside the three routes" is
    // decided rather than assumed.
    public struct Placement {
        var route_id : string
        var route_name : string
        var step : int
        var reason : string

        @make
        func make() : Placement {
            return Placement {
                route_id = string(),
                route_name = string(),
                step = 0,
                reason = string()
            }
        }
    }

    // One course as the index renders it: pre-escaped, pre-counted, and
    // already told which route claims it.
    public struct CatalogCard {
        var href : string
        var title : string
        var description : string
        var difficulty : string
        var importance : string
        var modules : int
        var concepts : int
        var minutes : int
        var place : Placement
        var concept_links : vector<ConceptLink>

        @make
        func make() : CatalogCard {
            return CatalogCard {
                href = string(),
                title = string(),
                description = string(),
                difficulty = string(),
                importance = string(),
                modules = 0,
                concepts = 0,
                minutes = 0,
                place = Placement::make(),
                concept_links = vector<ConceptLink>()
            }
        }
    }

    public func placement_of(routes : &vector<PathRoute>, course_id : &string) : Placement {
        var p = Placement::make()
        var cid = course_id.copy()
        var ri : size_t = 0
        while(ri < routes.size()) {
            var route = routes.get_ptr(ri)
            var si : size_t = 0
            while(si < route.steps.size()) {
                var step = route.steps.get_ptr(si)
                var scid = step.course_id.copy()
                if(scid.equals(&cid)) {
                    p.route_id = route.id.copy()
                    p.route_name = route.name.copy()
                    p.step = si as int + 1
                    p.reason = step.reason.copy()
                    return p
                }
                si = si + 1
            }
            ri = ri + 1
        }
        return p
    }

    func module_title_for(course : *Course, concept_id : &string) : string {
        var cid = concept_id.copy()
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var m = course.modules.get_ptr(mi)
            var ci : size_t = 0
            while(ci < m.concepts.size()) {
                var mid = m.concepts.get_ptr(ci)
                var mcid = mid.copy()
                if(mcid.equals(&cid)) { return m.title.copy() }
                ci = ci + 1
            }
            mi = mi + 1
        }
        return string()
    }

}