// underlayer_web — Certificate handlers (issue, get, list, HTML page).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // ---- POST /api/certificates — Issue a new certificate ----

    public func handle_issue_certificate(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var course_id = json_get_str(&raw parsed, "course_id")
        if(course_id.size() == 0) {
            var err = string("course_id is required")
            send_error(res, 400u, &err)
            return
        }
        if(underlayer_repository::has_certificate(db, &learner_id, &course_id)) {
            var existing = underlayer_repository::get_certificate(db, &learner_id)
            var resp = string("{\"error\":\"certificate already issued\",\"certificate_id\":\"")
            var existing_certs = underlayer_repository::get_learner_certificates(db, &learner_id)
            var fi : size_t = 0
            while(fi < existing_certs.size()) {
                var c = existing_certs.get_ptr(fi)
                if(c.course_id.equals(&course_id)) {
                    resp.append_string(&c.id)
                    break
                }
                fi = fi + 1
            }
            resp.append_view("\"}")
            send_json_str(res, &raw resp)
            return
        }
        var learner = underlayer_repository::get_learner(db, &learner_id)
        var learner_name = learner.name
        if(learner_name.size() == 0) { learner_name = string("Learner") }
        var course_title = course_id.copy()
        var cert_id = underlayer_repository::issue_certificate(db, &learner_id, &course_id, &learner_name, &course_title)
        var resp = string("{\"id\":\"")
        resp.append_string(&cert_id)
        resp.append_view("\",\"learner_id\":\"")
        resp.append_string(&learner_id)
        resp.append_view("\",\"course_id\":\"")
        resp.append_string(&course_id)
        resp.append_view("\",\"learner_name\":\"")
        var name_esc = underlayer_core::json_escape(&learner_name.to_view())
        resp.append_string(&name_esc)
        resp.append_view("\",\"course_title\":\"")
        var title_esc = underlayer_core::json_escape(&course_title.to_view())
        resp.append_string(&title_esc)
        resp.append_view("\",\"certificate_url\":\"/certificates/")
        resp.append_string(&cert_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // ---- GET /api/certificates/:id — Get a specific certificate ----

    public func handle_get_certificate(db : *DbClient, cert_id : *string, req : &http::Request, res : *mut http::ResponseWriter) {
        var cert = underlayer_repository::get_certificate(db, cert_id)
        if(cert.id.size() == 0) {
            var err = string("certificate not found")
            send_error(res, 404u, &err)
            return
        }
        var resp = string("{\"id\":\"")
        resp.append_string(&cert.id)
        resp.append_view("\",\"learner_id\":\"")
        resp.append_string(&cert.learner_id)
        resp.append_view("\",\"course_id\":\"")
        resp.append_string(&cert.course_id)
        resp.append_view("\",\"learner_name\":\"")
        var name_esc = underlayer_core::json_escape(&cert.learner_name.to_view())
        resp.append_string(&name_esc)
        resp.append_view("\",\"course_title\":\"")
        var title_esc = underlayer_core::json_escape(&cert.course_title.to_view())
        resp.append_string(&title_esc)
        resp.append_view("\",\"completion_date\":\"")
        resp.append_string(&cert.completion_date)
        resp.append_view("\",\"certificate_url\":\"")
        resp.append_string(&cert.certificate_url)
        resp.append_view("\",\"created_at\":")
        var cat_str = underlayer_core::int_to_string(cert.created_at)
        resp.append_string(&cat_str)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // ---- GET /api/certificates — List user's certificates ----

    public func handle_get_certificates(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var certs = underlayer_repository::get_learner_certificates(db, &learner_id)
        var resp = string("[")
        var ci : size_t = 0
        while(ci < certs.size()) {
            if(ci > 0) { resp.append_view(",") }
            var cert = certs.get_ptr(ci)
            resp.append_view("{\"id\":\"")
            resp.append_string(&cert.id)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&cert.course_id)
            resp.append_view("\",\"learner_name\":\"")
            var ne = underlayer_core::json_escape(&cert.learner_name.to_view())
            resp.append_string(&ne)
            resp.append_view("\",\"course_title\":\"")
            var te = underlayer_core::json_escape(&cert.course_title.to_view())
            resp.append_string(&te)
            resp.append_view("\",\"completion_date\":\"")
            resp.append_string(&cert.completion_date)
            resp.append_view("\",\"certificate_url\":\"")
            resp.append_string(&cert.certificate_url)
            resp.append_view("\",\"created_at\":")
            var cs = underlayer_core::int_to_string(cert.created_at)
            resp.append_string(&cs)
            resp.append_view("}")
            ci = ci + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // ---- GET /certificates/:id — HTML certificate page ----

    public func handle_certificate_page(db : *DbClient, cert_id : *string, req : &http::Request, res : *mut http::ResponseWriter) {
        var cert = underlayer_repository::get_certificate(db, cert_id)
        if(cert.id.size() == 0) {
            var err = string("certificate not found")
            send_error(res, 404u, &err)
            return
        }
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title_str = string("Certificate of Completion — Underlayer")
        var title_sv = title_str.to_view()
        page.appendTitle(&title_sv)

        var html = string()
        html.append_view("<div class=\"cert-page\"><div class=\"cert-card\"><div class=\"cert-border\"><div class=\"cert-inner\">")
        html.append_view("<div class=\"cert-header\"><div class=\"cert-brand\">Underlayer</div>")
        html.append_view("<div class=\"cert-badge\"><svg width=\"48\" height=\"48\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"hsl(45 93% 47%)\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"8\" r=\"7\"/><polyline points=\"8.21 13.89 7 23 12 20 17 23 15.79 13.88\"/></svg></div></div>")
        html.append_view("<h1 class=\"cert-title\">Certificate of Completion</h1>")
        html.append_view("<p class=\"cert-subtitle\">This is to certify that</p>")
        html.append_view("<p class=\"cert-learner\">")
        html.append_string(&cert.learner_name)
        html.append_view("</p>")
        html.append_view("<p class=\"cert-subtitle\">has successfully completed the course</p>")
        html.append_view("<p class=\"cert-course\">")
        html.append_string(&cert.course_title)
        html.append_view("</p>")
        html.append_view("<p class=\"cert-date\">Completed on ")
        html.append_string(&cert.completion_date)
        html.append_view("</p>")
        html.append_view("<div class=\"cert-footer\"><div class=\"cert-id\">Certificate ID: ")
        html.append_string(&cert.id)
        html.append_view("</div>")
        html.append_view("<div class=\"cert-verify\">Verify at: localhost:9000")
        html.append_string(&cert.certificate_url)
        html.append_view("</div></div>")
        html.append_view("</div></div></div></div>")

        page.append_html(html.data(), html.size())

        #css {
            .cert-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); padding: 2rem; font-family: Georgia, 'Times New Roman', serif; }
            .cert-card { width: 100%; max-width: 720px; }
            .cert-border { border: 3px solid hsl(45 93% 47%); border-radius: 4px; padding: 4px; background: hsl(var(--card)); }
            .cert-inner { border: 1px solid hsl(45 93% 70% / 0.3); padding: 3rem 2.5rem; text-align: center; position: relative; }
            .cert-header { margin-bottom: 1.5rem; }
            .cert-brand { font-size: 0.9rem; font-weight: 700; color: hsl(217 91% 60%); text-transform: uppercase; letter-spacing: 3px; margin-bottom: 1rem; }
            .cert-badge { margin: 0 auto; width: 64px; height: 64px; display: flex; align-items: center; justify-content: center; background: hsl(45 93% 47% / 0.1); border-radius: 50%; }
            .cert-title { font-size: 1.75rem; font-weight: 700; color: hsl(var(--foreground)); margin-bottom: 1rem; letter-spacing: 1px; }
            .cert-subtitle { font-size: 1rem; color: hsl(var(--muted-foreground)); margin-bottom: 0.5rem; font-style: italic; }
            .cert-learner { font-size: 2rem; font-weight: 700; color: hsl(217 91% 60%); margin-bottom: 1rem; border-bottom: 2px solid hsl(45 93% 47%); display: inline-block; padding-bottom: 0.25rem; }
            .cert-course { font-size: 1.25rem; font-weight: 600; color: hsl(var(--foreground)); margin-bottom: 1rem; }
            .cert-date { font-size: 0.95rem; color: hsl(var(--muted-foreground)); margin-bottom: 2rem; }
            .cert-footer { border-top: 1px solid hsl(var(--border)); padding-top: 1rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .cert-id { margin-bottom: 0.25rem; font-family: monospace; }
            .cert-verify { font-style: italic; }
        }

        #js {
            // No interactivity needed for static certificate
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
