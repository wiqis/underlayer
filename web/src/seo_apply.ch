// underlayer_web — apply SEO head metadata to rendered lessons and landings.
//
// These two document types are rendered in content/src and then patched by
// handle_lesson / handle_course_landing. Replacing the <title> with a complete
// HtmlPage head is the same sentinel pattern as the pager and the lesson
// header; it avoids threading metadata through 431 render functions whose
// byte output the verify_* checkers pin.
using std::string
using std::vector
using underlayer_models::Course

public namespace underlayer_web {

    private func find_concept_fields(course : &Course, concept_id : &string,
                                     title : &mut string, seed : &mut string) : bool {
        var i : size_t = 0
        while(i < course.concepts.size()) {
            var c = course.concepts.at_ref(i)
            if(c.id.equals(concept_id)) {
                var t = c.title.copy()
                var d = c.description.copy()
                title.append_view(t.to_view())
                seed.append_view(d.to_view())
                return true
            }
            i = i + 1
        }
        return false
    }

    private func crumbs(course_title : &string, course_url : &string,
                        concept_title : &string, concept_url : &string) : string {
        var names = vector<string>()
        var urls = vector<string>()
        var root = string("/")
        var all = string("/courses")
        names.push(string("Home"))
        urls.push(absolute_url(&root))
        names.push(string("Courses"))
        urls.push(absolute_url(&all))
        names.push(course_title.copy())
        urls.push(course_url.copy())
        if(concept_title.size() > 0) {
            names.push(concept_title.copy())
            urls.push(concept_url.copy())
        }
        return breadcrumb_json_ld(&names, &urls)
    }

    public func apply_lesson_seo(html : &string, course : &Course, concept_id : &string) : string {
        var ctitle = course.title.copy()
        var cdesc = course.description.copy()
        var cid = course.id.copy()
        var title = string()
        var seed = string()
        if(!find_concept_fields(course, concept_id, &mut title, &mut seed)) {
            return html.copy()
        }
        var full_title = title.copy()
        full_title.append_view(" — ")
        full_title.append_view(ctitle.to_view())
        full_title.append_view(" — Underlayer")
        var description = lesson_description(&title, &ctitle, &seed)
        var path = string("/courses/")
        path.append_view(cid.to_view())
        path.append_view("/lessons/")
        path.append_view(concept_id.to_view())
        var canonical = absolute_url(&path)
        var course_path = string("/courses/")
        course_path.append_view(cid.to_view())
        var course_url = absolute_url(&course_path)
        var objects = vector<string>()
        objects.push(course_json_ld(&ctitle, &cdesc, &course_url))
        objects.push(crumbs(&ctitle, &course_url, &title, &canonical))
        var ld = wrap_json_ld(&objects)
        var fragment = seo_head_fragment(&full_title, &description, &canonical, &ld)
        return inject_seo_head(html, &fragment)
    }

    public func apply_landing_seo(html : &string, course : &Course) : string {
        var ctitle = course.title.copy()
        var cdesc = course.description.copy()
        var cid = course.id.copy()
        var full_title = ctitle.copy()
        full_title.append_view(" — Underlayer")
        var description = course_description(&ctitle, &cdesc)
        var path = string("/courses/")
        path.append_view(cid.to_view())
        var canonical = absolute_url(&path)
        var empty_title = string()
        var objects = vector<string>()
        objects.push(course_json_ld(&ctitle, &cdesc, &canonical))
        objects.push(crumbs(&ctitle, &canonical, &empty_title, &empty_title))
        var ld = wrap_json_ld(&objects)
        var fragment = seo_head_fragment(&full_title, &description, &canonical, &ld)
        return inject_seo_head(html, &fragment)
    }

}
