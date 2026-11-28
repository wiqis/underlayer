// underlayer_web — Server-rendered public proof-of-work page.
//
// Every number on this page is in the served HTML: a crawler, a learner with
// JS off and a checker all see the same record. No fetch, no "Loading...".
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    public func render_public_proof_page(data : &ProofData) : string {
        var page = HtmlPage()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Public learning record — Underlayer")
        page.appendTitle(&title)
        var display_esc = underlayer_core::html_escape(&data.display_name)
        var user_esc = underlayer_core::html_escape(&data.username)
        var completed = underlayer_core::int_to_string(data.completed_courses as i64)
        var mastered = underlayer_core::int_to_string(data.mastered_concepts as i64)
        var minutes = underlayer_core::int_to_string(data.total_minutes)

        #html {
            {render_nav_bar(&mut page)}
            <main class="container proof-main" id="main-content">
                <header class="page-head">
                    <h1>{display_esc}</h1>
                    <p class="lede">A public record of work completed on Underlayer — <code>/u/{user_esc}</code>. Counts come from this learner's own progress rows, not a demo account.</p>
                </header>
                <section class="proof-stats" aria-label="Learning totals">
                    <div class="proof-stat"><span class="proof-value">{completed}</span><span class="proof-label">Courses completed</span></div>
                    <div class="proof-stat"><span class="proof-value">{mastered}</span><span class="proof-label">Concepts mastered</span></div>
                    <div class="proof-stat"><span class="proof-value">{minutes}</span><span class="proof-label">Minutes studied</span></div>
                </section>
                <section class="proof-section" aria-labelledby="proof-courses">
                    <h2 id="proof-courses">Courses</h2>
                    {render_proof_courses(&data.courses, &mut page)}
                </section>
                <section class="proof-section" aria-labelledby="proof-certs">
                    <h2 id="proof-certs">Certificates</h2>
                    {render_proof_certificates(&data.certificates, &mut page)}
                </section>
                <p class="proof-note">This record is read-only. Sharing a snapshot still uses the existing <code>/api/progress/shared/:token</code> endpoint; nothing here follows, messages or feeds another learner.</p>
            </main>
        }
        #css {
            .proof-main { max-width: 70ch; margin: 0 auto; padding: 2rem 1rem 3rem; }
            .proof-main .page-head h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .proof-main .lede { color: hsl(var(--muted-foreground)); line-height: 1.6; }
            .proof-stats { display: flex; flex-wrap: wrap; gap: 1rem; margin: 1.5rem 0; }
            .proof-stat { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1rem 1.25rem; min-width: 9rem; }
            .proof-value { display: block; font-size: 1.6rem; font-weight: 700; color: hsl(var(--primary)); line-height: 1.2; }
            .proof-label { display: block; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .proof-section { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 10px; padding: 1.25rem 1.5rem; margin-bottom: 1.25rem; }
            .proof-section h2 { font-size: 1.15rem; margin: 0 0 1rem; }
            .proof-course, .proof-cert { padding: 0.75rem 0; border-bottom: 1px solid hsl(var(--border)); }
            .proof-course:last-child, .proof-cert:last-child { border-bottom: none; }
            .proof-course a, .proof-cert a { color: hsl(var(--primary)); }
            .proof-empty { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .proof-note { color: hsl(var(--muted-foreground)); font-size: 0.85rem; line-height: 1.6; }
            :focus-visible { outline: 2px solid hsl(var(--primary)); outline-offset: 2px; }
            @media (max-width: 640px) { .proof-main { padding: 1rem 0.75rem 2rem; } .proof-stat { min-width: 0; flex: 1 1 8rem; } }
        }
        return page.toString()
    }

    // Each loop lives OUTSIDE the #html block: html_cbi's @{} statement
    // interpolation is broken (docs/implementation-gaps.md).
    public func render_proof_courses(courses : &vector<ProofCourse>, page : &mut HtmlPage) {
        if(courses.size() == 0) {
            #html {
                <p class="proof-empty">No completed or mastered courses have been recorded yet.</p>
            }
            return
        }
        var i : size_t = 0
        while(i < courses.size()) {
            var course = courses.at_ref(i)
            var title_esc = underlayer_core::html_escape(&course.course_title)
            var course_href = string("/courses/")
            course_href.append_string(&course.course_id)
            var cid_esc = underlayer_core::html_escape(&course_href)
            var mastered = underlayer_core::int_to_string(course.mastered as i64)
            #html {
                <div class="proof-course">
                    <a href={cid_esc}>{title_esc}</a>
                    <span class="proof-course-count">{mastered} concepts mastered</span>
                    {render_proof_cert_link(&course.certificate_id, page)}
                </div>
            }
            i = i + 1
        }
    }

    func render_proof_cert_link(cert_id : &string, page : &mut HtmlPage) {
        if(cert_id.size() == 0) { return }
        var href = string("/certificates/")
        href.append_string(cert_id)
        var href_esc = underlayer_core::html_escape(&href)
        #html {
            <a class="proof-cert-link" href={href_esc}>View certificate</a>
        }
    }

    public func render_proof_certificates(certs : &vector<underlayer_repository::Certificate>, page : &mut HtmlPage) {
        if(certs.size() == 0) {
            #html {
                <p class="proof-empty">No certificates have been issued yet.</p>
            }
            return
        }
        var i : size_t = 0
        while(i < certs.size()) {
            var cert = certs.at_ref(i)
            var href = string("/certificates/")
            href.append_string(&cert.id)
            var href_esc = underlayer_core::html_escape(&href)
            var title_esc = underlayer_core::html_escape(&cert.course_title)
            var date_esc = underlayer_core::html_escape(&cert.completion_date)
            #html {
                <div class="proof-cert">
                    <a href={href_esc}>{title_esc}</a>
                    <span class="proof-cert-date">Completed {date_esc}</span>
                </div>
            }
            i = i + 1
        }
    }

}
