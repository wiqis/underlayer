// underlayer_web — G6 installable-web asset routes.
//
// Three same-origin routes sit AHEAD of the web::App catch-all, so H3's header
// wrapper (deliver_with_learner) applies to them exactly as it does to pages:
// CSP, nosniff, Referrer-Policy, HSTS, ETag/304, request id. The CSP is not
// changed: the manifest and worker are same-origin and need no new source.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_manifest(req : &http::Request) : http::Response {
        var body = string("{\"name\":\"Underlayer — Learn things deeply\",\"short_name\":\"Underlayer\",\"description\":\"A guided journey through binary formats, from bytes to a working executable.\",\"lang\":\"en\",\"start_url\":\"/\",\"scope\":\"/\",\"display\":\"standalone\",\"orientation\":\"any\",\"background_color\":\"#112241\",\"theme_color\":\"#112241\",\"icons\":[{\"src\":\"/icons/icon-192.png\",\"sizes\":\"192x192\",\"type\":\"image/png\",\"purpose\":\"any\"},{\"src\":\"/icons/icon-512.png\",\"sizes\":\"512x512\",\"type\":\"image/png\",\"purpose\":\"any maskable\"}]}")
        var res = http::Response()
        var ct = string_view("application/manifest+json; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        var bv = body.to_view()
        res.text(&bv)
        return res
    }

    public func handle_service_worker(req : &http::Request) : http::Response {
        var js = underlayer_content::service_worker_source()
        var res = http::Response()
        var ct = string_view("application/javascript; charset=utf-8")
        res.set_header_view(string_view("Content-Type"), &ct)
        // A service worker must not be cached by an intermediary: a stale worker
        // is the one thing versioned cache deletion cannot repair.
        var cc = string_view("no-cache")
        res.set_header_view(string_view("Cache-Control"), &cc)
        var jv = js.to_view()
        res.text(&jv)
        return res
    }

    // Only the two generated, fixed names are reachable. Nothing from the
    // request becomes a filesystem path.
    public func handle_pwa_icon(req : &http::Request) : http::Response {
        var req_path = req.path.to_view()
        var segs = underlayer_core::path_segments(&req_path)
        if(segs.size() < 2) {
            var err = string("not found")
            return send_error(404u, &err)
        }
        var name = segs.at_ref(segs.size() - 1).to_string()
        var allowed_192 = string("icon-192.png")
        var allowed_512 = string("icon-512.png")
        if(!name.equals(&allowed_192) && !name.equals(&allowed_512)) {
            var err = string("not found")
            return send_error(404u, &err)
        }
        var file_path = string("app/")
        file_path.append_string(&name)
        var pview = std::str.make_view(file_path.to_view())
        var fp = path::Path.new(pview)
        var loaded = fs::read(&fp)
        if(loaded is std::Result.Err) {
            var err = string("not found")
            return send_error(404u, &err)
        }
        var Ok(bytes) = loaded else unsafe { unreachable }
        var res = http::Response()
        var ct = string_view("image/png")
        res.set_header_view(string_view("Content-Type"), &ct)
        res.bytes(bytes.as_span())
        return res
    }

}
