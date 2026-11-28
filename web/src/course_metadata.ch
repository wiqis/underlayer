// underlayer_web — I7: the single course metadata contract, read from disk.
//
// The repository model carries author, license and an integer version because
// that is what it always carried. I7 adds toolchain, spec_source,
// last_verified and limitations, which the frozen model does NOT have. Rather
// than widen a shared model owned by another work package, the API and the
// landing read the manifest directly and expose these as ADDITIVE fields.
// No existing field is edited or removed.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public struct CourseMetadata {
        var course_id : string
        var author : string
        var license : string
        var version : string
        var toolchain : string
        var spec_source : string
        var last_verified : string
        var limitations : vector<string>

        @make
        func make() : CourseMetadata {
            return CourseMetadata {
                course_id = string(),
                author = string(),
                license = string(),
                version = string(),
                toolchain = string(),
                spec_source = string(),
                last_verified = string(),
                limitations = vector<string>()
            }
        }
    }

    public func load_course_metadata(courses_dir : &string, course_id : &string) : CourseMetadata {
        var out = CourseMetadata::make()
        out.course_id = course_id.copy()
        var manifest_path_str = courses_dir.copy()
        manifest_path_str.append_view(string_view("/"))
        manifest_path_str.append_string(course_id)
        manifest_path_str.append_view(string_view("/manifest.json"))
        var path_view = std::str.make_view(manifest_path_str.to_view())
        var manifest_path = path::Path.new(path_view)
        var content_res = fs::read_to_string(&manifest_path)
        if(content_res is std::Result.Err) { return out }
        var Ok(text) = content_res else unsafe { unreachable }
        var json_res = json::parse(text.to_view())
        if(json_res is std::Result.Err) { return out }
        var Ok(root) = json_res else unsafe { unreachable }
        out.author = json_get_str(&root, "author")
        out.license = json_get_str(&root, "license")
        // Tolerant during migration: a numeric legacy version still reads as
        // its literal digits until the coordinator applies the semver patch.
        out.version = json_get_str_or_num(&root, "version")
        out.toolchain = json_get_str(&root, "toolchain")
        out.spec_source = json_get_str(&root, "spec_source")
        out.last_verified = json_get_str(&root, "last_verified")
        var lim = json_get(&root, "limitations")
        if(lim is std::Option.Some) {
            var Some(node) = lim else unsafe { unreachable }
            if(node is JsonValue.Array) {
                var i : size_t = 0
                while(i < underlayer_repository::json_len(node)) {
                    var item = underlayer_repository::json_at(node, i)
                    if(item is std::Option.Some) {
                        var Some(v) = item else unsafe { unreachable }
                        var s = underlayer_repository::json_str(v)
                        if(s.size() > 0) { out.limitations.push(s) }
                    }
                    i = i + 1
                }
            } else if(node is JsonValue.String) {
                var s = json_get_str(&root, "limitations")
                if(s.size() > 0) { out.limitations.push(s) }
            }
        }
        return out
    }

    // Append the additive fields to a JSON object that is already open. Every
    // value is escaped; a manifest is data, never markup or raw JSON.
    public func append_metadata_json(body : &mut string, meta : &CourseMetadata) {
        body.append_view(",\"author\":\"")
        var a = underlayer_core::json_escape(&meta.author.to_view())
        body.append_view(a.to_view())
        body.append_view("\",\"license\":\"")
        var l = underlayer_core::json_escape(&meta.license.to_view())
        body.append_view(l.to_view())
        body.append_view("\",\"metadata_version\":\"")
        var v = underlayer_core::json_escape(&meta.version.to_view())
        body.append_view(v.to_view())
        body.append_view("\",\"toolchain\":\"")
        var t = underlayer_core::json_escape(&meta.toolchain.to_view())
        body.append_view(t.to_view())
        body.append_view("\",\"spec_source\":\"")
        var s = underlayer_core::json_escape(&meta.spec_source.to_view())
        body.append_view(s.to_view())
        body.append_view("\",\"last_verified\":\"")
        var d = underlayer_core::json_escape(&meta.last_verified.to_view())
        body.append_view(d.to_view())
        body.append_view("\",\"limitations\":[")
        var i : size_t = 0
        while(i < meta.limitations.size()) {
            if(i > 0) { body.append(',') }
            var item = meta.limitations.at_ref(i)
            var e = underlayer_core::json_escape(&item.to_view())
            body.append('"')
            body.append_view(e.to_view())
            body.append('"')
            i = i + 1
        }
        body.append(']')
    }

}
