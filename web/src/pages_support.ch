// underlayer_web — public support page and the shared support footer (I11).
//
// All markup is macro output. The page is server-rendered: a reader with
// JavaScript disabled still sees the channel, the owner and the response-time
// target. F0's /privacy names the same channel; this file does not edit it.
using std::string
using std::string_view

public namespace underlayer_web {

    // One support link in the footer of every web page that draws the shared
    // nav. Called from nav_bar.ch's render_nav_bar, so there is exactly one
    // owner for the insertion point and no page carries a second copy.
    public func render_support_footer(page : &mut HtmlPage) {
        #html {
            <footer class="ul-support-footer" role="contentinfo">
                <p>Need help? <a href="/support">Contact support</a> or email <a href="mailto:support@wiqis.com">support@wiqis.com</a>.</p>
            </footer>
        }
        #css {
            .ul-support-footer { max-width: 68ch; margin: 2rem auto 0; padding: 1rem 1rem 2rem; border-top: 1px solid hsl(var(--border, 0 0% 85%)); font-size: 0.85rem; line-height: 1.6; color: hsl(var(--muted-foreground, 0 0% 40%)); text-align: center; }
            .ul-support-footer a { color: hsl(217 91% 60%); }
        }
    }

    // GET /support — server-rendered support and contact channel.
    public func render_support_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Support — Underlayer")
        page.appendTitle(&title)
        render_nav_bar(&mut page)

        #html {
            <main class="container support-main" id="main-content">
            <article class="support-page">
                <h1>Support</h1>
                <p class="support-lead">Underlayer is built by a small team. Here is how to reach us and what to expect.</p>
                <section class="support-card">
                    <h2>Supported channels</h2>
                    <ul>
                        <li>Email: <a href="mailto:support@wiqis.com">support@wiqis.com</a> — for account, purchase and general help.</li>
                        <li>The <a href="/help">Help</a> and <a href="/faq">FAQ</a> pages — for using the courses and the review system.</li>
                        <li>The report control on each lesson — for a correction to lesson text, a byte claim or an exercise.</li>
                    </ul>
                    <p>There is no phone line or live chat. Messages sent through any other channel may not be seen.</p>
                </section>
                <section class="support-card">
                    <h2>Owner</h2>
                    <p>Support owner: Waqas Tahir (founder). The duty operator is assigned from the operator allow-list and published here when the rota is live; until then the founder reads this inbox.</p>
                </section>
                <section class="support-card">
                    <h2>Response-time target</h2>
                    <p>We aim to reply within <strong>two business days</strong>. If your message needs a lesson correction, we will tell you when the verified text has been updated rather than closing the thread with a guess.</p>
                </section>
                <section class="support-card">
                    <h2>Write to us</h2>
                    <p><a class="btn btn-primary" href="mailto:support@wiqis.com">Email support@wiqis.com</a></p>
                    <p>Please include the course and concept id, the page address and what you expected. That lets us reproduce the problem without asking you to repeat it.</p>
                </section>
            </article>
            </main>
        }
        #css {
            body { font-family: var(--font-sans); font-size: 1rem; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            :focus-visible { outline: 2px solid hsl(var(--primary)); outline-offset: 2px; }
            .support-main { max-width: 68ch; margin: 0 auto; padding: 2rem 1rem 3rem; }
            .support-page h1 { font-size: 1.75rem; line-height: 1.6; margin: 0 0 0.5rem; }
            .support-lead { color: hsl(var(--muted-foreground)); margin: 0 0 1.5rem; line-height: 1.6; }
            .support-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 0.75rem; padding: 1.5rem; margin-bottom: 1rem; }
            .support-card h2 { font-size: 1.1rem; line-height: 1.6; margin: 0 0 0.75rem; }
            .support-card p, .support-card li { line-height: 1.6; }
            .support-card a { color: hsl(217 91% 60%); }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 0.5rem; background: hsl(217 91% 60%); color: hsl(0 0% 100%); text-decoration: none; font-weight: 600; }
            @media (max-width: 600px) { .support-main { padding: 1rem 0.75rem 2rem; } .support-card { padding: 1.25rem; } }
        }
        return page.toString()
    }

}
