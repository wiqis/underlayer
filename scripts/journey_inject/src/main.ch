// Add the guided journey to pre-rendered pages that do not already carry it.
// The journey itself is authored in content/src/journey_*.ch via #html/#css/#js
// macros; this program only writes that macro output into generated HTML.
// A page with a journey shell is left byte-identical by the injector, but the
// shared metadata pass still fills its empty data-* attributes and derives the
// per-step takeaways from the lesson text and the course manifest.
using std::string
using std::string_view
using std::vector
using std::str

public func main() : int {
    var root_view = std::str.make_view(string_view("courses"))
    var root = path::Path.new(root_view)
    var list_res = fs::read_dir(&root)
    if(list_res is std::Result.Err) { return 1 }
    var Ok(entries) = list_res else unsafe { unreachable }

    var output_view = std::str.make_view(string_view("output"))
    var patched = 0
    var ci : size_t = 0
    while(ci < entries.size()) {
        var entry = entries.at_ref(ci)
        if(!entry.is_dir()) { ci = ci + 1; continue; }
        var out_dir = entry.path().join(&path::Path.new(output_view))
        if(!fs::is_dir(&out_dir.as_path())) { ci = ci + 1; continue; }

        var course_id = entry.file_name()
        var manifest = string("courses/")
        manifest.append_view(course_id.to_view())
        manifest.append_view(string_view("/manifest.json"))

        var html_res = fs::read_dir(&out_dir.as_path())
        if(html_res is std::Result.Err) { ci = ci + 1; continue; }
        var Ok(files) = html_res else unsafe { unreachable }
        var fi : size_t = 0
        while(fi < files.size()) {
            var f = files.at_ref(fi)
            var name = f.file_name()
            if(name.size() > 5) {
                var tail = name.to_view().subview(name.size() - 5, name.size())
                if(tail.equals(string_view(".html"))) {
                    var read_res = fs::read_to_string(&f.path().as_path())
                    if(read_res is std::Result.Err) { fi = fi + 1; continue; }
                    var Ok(text) = read_res else unsafe { unreachable }
                    var concept_id = name.substring(0, name.size() - 5)
                    var facts = underlayer_content::journey_facts_from_manifest(&manifest, &concept_id)
                    var with_shell = underlayer_content::apply_journey_to_document(&text)
                    var with_facts = underlayer_content::journey_apply_metadata(&with_shell, &facts, &course_id, &concept_id)
                    var final_html = underlayer_content::journey_apply_static_pager(&with_facts, &facts.prev_id, &facts.next_id)
                    if(final_html.size() != text.size()) {
                        fs::write(&f.path().as_path(), final_html.as_bytes())
                        patched = patched + 1
                    }
                    // The SAME composer the HTTP endpoint uses, fed the SAME
                    // journeyed HTML, so the bundled pack and the live API
                    // cannot drift.  No lesson source is edited.
                    var native = underlayer_content::native_lesson_json(&final_html, &facts, &course_id, &concept_id)
                    var native_name = concept_id.copy()
                    native_name.append_view(".native.json")
                    var native_path = out_dir.join(&path::Path.new(std::str.make_view(native_name.to_view())))
                    fs::write(&native_path.as_path(), native.as_bytes())
                }
            }
            fi = fi + 1
        }
        ci = ci + 1
    }
    unsafe { printf("journey_inject: %d page(s) received the guided journey\n", patched) }
    return 0
}
