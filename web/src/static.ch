// underlayer_web — Static file serving.
using std::string
using std::string_view

public namespace underlayer_web {

    public func content_type_for_ext(ext : *string) : string {
        if(ext.equals(string("html"))) { return string("text/html; charset=utf-8") }
        if(ext.equals(string("css"))) { return string("text/css; charset=utf-8") }
        if(ext.equals(string("js"))) { return string("application/javascript; charset=utf-8") }
        if(ext.equals(string("json"))) { return string("application/json") }
        if(ext.equals(string("png"))) { return string("image/png") }
        if(ext.equals(string("jpg"))) { return string("image/jpeg") }
        if(ext.equals(string("jpeg"))) { return string("image/jpeg") }
        if(ext.equals(string("gif"))) { return string("image/gif") }
        if(ext.equals(string("svg"))) { return string("image/svg+xml") }
        if(ext.equals(string("ico"))) { return string("image/x-icon") }
        if(ext.equals(string("woff"))) { return string("font/woff") }
        if(ext.equals(string("woff2"))) { return string("font/woff2") }
        if(ext.equals(string("ttf"))) { return string("font/ttf") }
        return string("application/octet-stream")
    }

    public func file_extension(path : *string_view) : string {
        var last_dot : size_t = 0
        var i : size_t = 0
        while(i < path.size()) {
            if(path.get(i) == '.') { last_dot = i }
            i = i + 1
        }
        if(last_dot == 0 || last_dot >= path.size() - 1) { return string() }
        var ext = string()
        var j : size_t = last_dot + 1
        while(j < path.size()) {
            ext.append(path.get(j))
            j = j + 1
        }
        return ext
    }

    public func handle_static_file(courses_dir : &string, req_path : *string_view, res : *mut http::ResponseWriter) {
        var fs_path = courses_dir.copy()
        var req_str = req_path.to_string()
        fs_path.append_string(&req_str)

        var content_res = fs::read_entire_file(fs_path.data())
        if(content_res is std::Result.Err) {
            var err_msg = std::string("file not found")
            send_error(res, 404u, &err_msg)
            return
        }
        var Ok(bytes) = content_res else unreachable

        var ext = file_extension(req_path)
        var ct = content_type_for_ext(&raw ext)
        var ct_view = ct.to_view()
        res.set_header_view(std::string_view("Content-Type"), &ct_view)

        var body_view = std::string_view(bytes.data() as *char, bytes.size())
        res.write_view(&body_view)
    }

}
