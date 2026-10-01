// underlayer_web — Machine check that the authored route order is honest.
//
// WHY A RUNTIME CHECK AND NOT A COMMENT.  A page that says "this order
// respects the prerequisites" is a claim, and this repo's rule is that a
// claim has to be a machine check.  docs/implementation-gaps.md records a
// course where a cross-check "has silently stopped comparing" and still
// printed the same number as one that was working; tools/verify_rvasm.py
// exists because of it.  So the three routes in routes_*.ch are walked
// against the real manifests on every render, and /courses prints the counts
// it got:
//
//   38 of 38 declared prerequisites satisfied   <- when the order is right
//   0 routes naming a course that is not on disk
//   0 courses listed twice across the three routes
//
// If someone adds a course, renames one, or reorders a step, one of those
// three numbers moves and the page says so.  A route that quietly stopped
// being walkable prints 36 of 38 instead of failing silently.
//
// The three routes are treated as ONE concatenated sequence, which is what
// makes a satisfiable order possible at all: Route 2's first course declares
// prerequisites that Route 1 supplies, and Route 3's declare prerequisites
// Route 2 supplies.
using std::string
using std::string_view
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    public struct RouteCheck {
        var satisfied : int
        var total : int
        var unmet : vector<string>
        var missing_courses : vector<string>
        var duplicates : vector<string>
        var covered : int

        @make
        func make() : RouteCheck {
            return RouteCheck {
                satisfied = 0,
                total = 0,
                unmet = vector<string>(),
                missing_courses = vector<string>(),
                duplicates = vector<string>(),
                covered = 0
            }
        }
    }

    // Index of a course in the loaded list, or -1.  Index-returning rather
    // than pointer-returning because a null Course* would have to be tested at
    // every call site, and an index cannot be forgotten.
    public func course_index(courses : &vector<Course>, course_id : &string) : int {
        var i : size_t = 0
        while(i < courses.size()) {
            var c = courses.get_ptr(i)
            if(c.id.equals(course_id)) { return i as int }
            i = i + 1
        }
        return -1
    }

    public func list_has(list : &vector<string>, value : &string) : bool {
        var i : size_t = 0
        while(i < list.size()) {
            var v = list.get_ptr(i)
            if(v.equals(value)) { return true }
            i = i + 1
        }
        return false
    }

    public func verify_route_order(courses : &vector<Course>, routes : &vector<PathRoute>) : RouteCheck {
        var chk = RouteCheck::make()
        var seen = vector<string>()
        var ri : size_t = 0
        while(ri < routes.size()) {
            var route = routes.get_ptr(ri)
            var si : size_t = 0
            while(si < route.steps.size()) {
                var step = route.steps.get_ptr(si)
                var cid = step.course_id.copy()
                var idx = course_index(courses, &cid)
                if(idx < 0) {
                    var m = route.name.copy()
                    m.append_view(string_view(" names a course that is not on disk: "))
                    m.append_string(&cid)
                    chk.missing_courses.push(m)
                } else {
                    if(list_has(&seen, &cid)) {
                        var d = string("listed twice across the three routes: ")
                        d.append_string(&cid)
                        chk.duplicates.push(d)
                    }
                    var c = courses.get_ptr(idx as size_t)
                    var di : size_t = 0
                    while(di < c.dependencies.size()) {
                        var dep = c.dependencies.get_ptr(di).copy()
                        chk.total = chk.total + 1
                        if(list_has(&seen, &dep)) {
                            chk.satisfied = chk.satisfied + 1
                        } else {
                            var u = route.name.copy()
                            u.append_view(string_view(", step "))
                            var pos = si + 2
                            var pos_s = underlayer_core::int_to_string(pos as i64)
                            u.append_string(&pos_s)
                            u.append_view(string_view(" ("))
                            u.append_string(&cid)
                            u.append_view(string_view("), declares "))
                            u.append_string(&dep)
                            u.append_view(string_view(" unread"))
                            chk.unmet.push(u)
                        }
                        di = di + 1
                    }
                }
                seen.push(cid)
                si = si + 1
            }
            ri = ri + 1
        }
        chk.covered = seen.size() as int
        return chk
    }

}