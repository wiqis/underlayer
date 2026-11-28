// underlayer_web — G8: server-rendered public proof of work.
//
// The /u/:username route used to render a "Loading..." shell filled by three
// client fetches. A shell with no data in the served HTML is not a public
// record: it cannot be indexed, cannot be read with JS off and cannot be
// checked against the served artifact. This handler reads the learner's OWN
// rows from this DB and hands a plain value struct to the renderer.
//
// No social graph is built here. The only sharing surface remains the
// existing progress-share token at /api/progress/shared/:token; this page is
// the human-readable counterpart of the same visibility setting and nothing
// more (founder ruling §6.11, narrow §8 items 8.1.10–8.1.17).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    public struct ProofCourse {
        var course_id : string
        var course_title : string
        var mastered : int
        var certificate_id : string

        @make
        func make() : ProofCourse {
            return ProofCourse {
                course_id = string(),
                course_title = string(),
                mastered = 0,
                certificate_id = string()
            }
        }
    }

    public struct ProofData {
        var display_name : string
        var username : string
        var visibility : string
        var courses : vector<ProofCourse>
        var completed_courses : int
        var mastered_concepts : int
        var total_minutes : i64
        var certificates : vector<underlayer_repository::Certificate>

        @make
        func make() : ProofData {
            return ProofData {
                display_name = string(),
                username = string(),
                visibility = string(),
                courses = vector<ProofCourse>(),
                completed_courses = 0,
                mastered_concepts = 0,
                total_minutes = 0,
                certificates = vector<underlayer_repository::Certificate>()
            }
        }
    }

    // Returns an empty username when the address does not name a profile or
    // the profile has opted out. The caller turns that into a plain 404.
    public func load_public_proof(db : *DbClient, req : &http::Request) : ProofData {
        var out = ProofData::make()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 2) { return out }
        var username = segments.at_ref(1).to_string()
        var profile = underlayer_repository::get_profile_by_username(db, &username)
        if(profile.learner_id.size() == 0) { return out }
        var private_vis = string("private")
        if(profile.visibility.equals(&private_vis)) { return out }

        out.username = profile.username.copy()
        out.visibility = profile.visibility.copy()
        out.display_name = profile.display_name.copy()
        var anonymous = string("anonymous")
        if(out.display_name.size() == 0 || out.visibility.equals(&anonymous)) {
            out.display_name = string("Anonymous learner")
        }

        var courses_dir = request_courses_dir()
        var catalog = underlayer_repository::list_courses(&courses_dir)
        var enrollments = underlayer_repository::get_learner_enrollments(db, &profile.learner_id)
        var certs = underlayer_repository::get_learner_certificates(db, &profile.learner_id)
        var ei : size_t = 0
        while(ei < enrollments.size()) {
            var enrollment = enrollments.at_ref(ei)
            var pc = ProofCourse::make()
            pc.course_id = enrollment.course_id.copy()
            pc.course_title = pc.course_id.copy()
            var ci : size_t = 0
            while(ci < catalog.size()) {
                var c = catalog.at_ref(ci)
                var cid = c.id.copy()
                if(cid.equals(&pc.course_id)) { pc.course_title = c.title.copy() }
                ci = ci + 1
            }
            var states = underlayer_repository::get_all_concept_states(db, &profile.learner_id, &pc.course_id)
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.at_ref(si)
                var mastered = string("mastered")
                if(state.status.equals(&mastered)) {
                    pc.mastered = pc.mastered + 1
                    out.mastered_concepts = out.mastered_concepts + 1
                }
                si = si + 1
            }
            var done = string("completed")
            if(enrollment.status.equals(&done)) {
                out.completed_courses = out.completed_courses + 1
            }
            var cert_i : size_t = 0
            while(cert_i < certs.size()) {
                var cert = certs.at_ref(cert_i)
                var ccid = cert.course_id.copy()
                if(ccid.equals(&pc.course_id) && pc.certificate_id.size() == 0) {
                    pc.certificate_id = cert.id.copy()
                }
                cert_i = cert_i + 1
            }
            if(pc.mastered > 0 || pc.certificate_id.size() > 0 || enrollment.status.equals(&done)) {
                out.courses.push(pc)
            }
            ei = ei + 1
        }
        var ci2 : size_t = 0
        while(ci2 < certs.size()) {
            out.certificates.push(copy_cert(certs.at_ref(ci2)))
            ci2 = ci2 + 1
        }
        var sessions = underlayer_repository::get_learner_sessions(db, &profile.learner_id, 1000)
        var s2 : size_t = 0
        while(s2 < sessions.size()) {
            var session = sessions.at_ref(s2)
            var sid = session.id.copy()
            var items = underlayer_repository::get_session_items(db, &sid)
            var k : size_t = 0
            while(k < items.size()) {
                out.total_minutes = out.total_minutes + items.at_ref(k).time_spent_ms / 60000
                k = k + 1
            }
            s2 = s2 + 1
        }
        return out
    }

    func copy_cert(src : &underlayer_repository::Certificate) : underlayer_repository::Certificate {
        var out = underlayer_repository::Certificate::make()
        out.id = src.id.copy()
        out.learner_id = src.learner_id.copy()
        out.course_id = src.course_id.copy()
        out.learner_name = src.learner_name.copy()
        out.course_title = src.course_title.copy()
        out.completion_date = src.completion_date.copy()
        out.certificate_url = src.certificate_url.copy()
        out.created_at = src.created_at
        return out
    }

    // Coordinator registration line (app/main.ch) — replaces the shell route:
    //   srv.router.add("GET", "/u/:username", ||(req) => {
    //       var db = request_db()
    //       return underlayer_web::deliver_with_learner(db, &req,
    //           underlayer_web::handle_public_proof_page(db, &req))
    //   })
    public func handle_public_proof_page(db : *DbClient, req : &http::Request) : http::Response {
        var data = load_public_proof(db, req)
        if(data.username.size() == 0) {
            var body = std::string("Not found")
            return send_status_text(404u, &body)
        }
        return send_html(&render_public_proof_page(&data))
    }

}
