// underlayer_web — Named routes through the course collection.
//
// WHY THIS FILE EXISTS.  `/courses` had no index at all, and 42 links across
// 32 files pointed at it.  Fixing the 404 is the easy half; the other half is
// that with 34 courses and 398 concepts, an index is a directory nobody can
// use unless it answers "where do I start?".  So the index carries three
// named routes, and a route is an ORDERED list of courses with a reason per
// step -- not a difficulty sort.
//
// The order is not invented.  Two things decide it:
//
//   1. `docs/course-mission.md`.  The mission states the chain the whole
//      collection exists to serve (object files -> linking -> executable ->
//      loading, with the ISA and memory hierarchy on the other branch) and
//      names the seven linking courses in that order.  Route 2 IS that chain.
//   2. `courses/*/manifest.json`'s `dependencies` field.  Every step in every
//      route is checked against it at render time by `verify_route_order()` in
//      routes_verify.ch, and the page prints the number it counted.  The claim
//      "this order respects the declared prerequisites" is therefore a count,
//      not a claim.
//
// `hat` is deliberately in none of the three routes and is rendered as its own
// section: it is the only beginner course in the collection, it has no
// dependencies and nothing depends on it, and folding a 69-concept exam
// preparation course into "the linking chain" would be a lie about both.
using std::string
using std::vector

public namespace underlayer_web {

    // One step of a route: which course, and why it sits HERE rather than
    // somewhere else in the same route.
    public struct RouteStep {
        var course_id : string
        var reason : string

        @make
        func make() : RouteStep {
            return RouteStep {
                course_id = string(),
                reason = string()
            }
        }
    }

    public struct PathRoute {
        var id : string
        var name : string
        var tagline : string
        var blurb : string
        var steps : vector<RouteStep>

        @make
        func make() : PathRoute {
            return PathRoute {
                id = string(),
                name = string(),
                tagline = string(),
                blurb = string(),
                steps = vector<RouteStep>()
            }
        }
    }

    public func mk_step(course_id : string, reason : string) : RouteStep {
        var s = RouteStep::make()
        s.course_id = course_id
        s.reason = reason
        return s
    }

    // The three routes, in the order a learner is meant to walk them.
    // Route 2's steps assume Route 1; Route 3's assume Routes 1 and 2.  The
    // verifier treats the three routes as one concatenated sequence, which is
    // what makes a single satisfiable order possible.
    public func build_routes() : vector<PathRoute> {
        var routes = vector<PathRoute>()
        routes.push(route_formats())
        routes.push(route_link())
        routes.push(route_architectures())
        return routes
    }

    // The courses no route claims.  Rendered separately on /courses and
    // /learning-path so a learner is told where they are rather than left to
    // wonder whether they were missed.
    public func route_orphans(routes : &vector<PathRoute>) : vector<string> {
        var seen = vector<string>()
        var ri : size_t = 0
        while(ri < routes.size()) {
            var r = routes.get_ptr(ri)
            var si : size_t = 0
            while(si < r.steps.size()) {
                var st = r.steps.get_ptr(si)
                seen.push(st.course_id.copy())
                si = si + 1
            }
            ri = ri + 1
        }
        return seen
    }

}