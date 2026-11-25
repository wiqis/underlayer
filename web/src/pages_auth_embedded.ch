// underlayer_web — THE BROWSER'S SIGN-IN SURFACES.
//
// Underlayer no longer collects credentials.  Identity belongs to the shared
// Wiqis account (`account.wiqis.com`); everything learned here stays in THIS
// service's database.  These pages implement the fleet's embedded-sign-in
// contract, copied from Web/timeline and Web/easytodo rather than invented:
//
//   * /login and /register  -> an in-place `<dialog>` with the account iframe,
//                              opened by a LOCAL `/sign-in` href carrying
//                              `data-auth-open`; the account frame posts
//                              `{type:"login_success"}` and we close + reload.
//   * /sign-in and /sign-up -> the statically rendered no-JS iframe, both with
//                              `allow="publickey-credentials-get"`.
//   * /sign-out             -> ends the local session (the account session is
//                              cleared on the account service's own page).
//
// The local `/api/auth/login|register` handlers are UNTOUCHED: the Android
// client still speaks them.  See web/src/handlers_auth.ch.
using std::string
using std::string_view

public namespace underlayer_web {

    // The dialog pages.  There is no form, no email field and no password
    // field — only the local opener and the shared runtime.
    func render_account_entry_page(req : &http::Request, title : string_view, heading : string_view, subtitle : string_view) : http::Response {
        var page = HtmlPage()
        page.defaultPrepare()
        // An embedded auth surface follows the surrounding page/OS theme.
        WiqisTheme(&mut page, false)
        var title_value = title
        page.appendTitle(&title_value)
        var heading_value = heading
        var subtitle_value = subtitle

        #html {
            <div class="wq-stage ul-auth-entry">
                <div class="wq-stage-col">
                    <div class="wq-stage-brand">
                        <svg class="wq-brand-mark" style="width:36px;height:36px;" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <rect width="32" height="32" rx="8" fill="#ff5733"></rect>
                            <text x="16" y="23" font-family="Inter,Arial,sans-serif" font-size="19" font-weight="800" fill="#ffffff" text-anchor="middle">W</text>
                        </svg>
                        <span class="wq-brand-name">Wiqis</span>
                    </div>
                    <div class="ul-auth-card">
                        <h1>{heading_value}</h1>
                        <p class="ul-auth-subtitle">{subtitle_value}</p>
                        <a href="/sign-in" class="ul-auth-open" data-auth-open>Sign in with your Wiqis account</a>
                    </div>
                    <div class="wq-foot">One Wiqis account signs you in to every app. Your Underlayer progress stays on this site.</div>
                </div>
            </div>
        }
        // Installs the dialog and delegates every [data-auth-open] click.
        underlayer_content::render_embedded_auth_runtime(&mut page)
        #css {
            .ul-auth-card { display: flex; flex-direction: column; gap: 1rem; padding: 1.5rem; border: 1px solid hsl(var(--border)); border-radius: var(--radius); background: hsl(var(--card)); color: hsl(var(--card-foreground)); box-shadow: var(--shadow); }
            .ul-auth-card h1 { margin: 0; font-size: 1.5rem; font-weight: 700; letter-spacing: -0.02em; }
            .ul-auth-subtitle { margin: 0; color: hsl(var(--muted-foreground)); font-size: 0.9rem; line-height: 1.5; }
            .ul-auth-open { display: inline-block; text-align: center; padding: 0.7rem 1rem; border-radius: var(--radius); background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); font-weight: 600; text-decoration: none; }
            .ul-auth-open:hover { filter: brightness(1.06); text-decoration: none; }
        }
        var html_out = page.toString()
        return send_html(&html_out)
    }

    public func handle_login_page(req : &http::Request) : http::Response {
        return render_account_entry_page(req, string_view("Sign in — Underlayer"), string_view("Welcome back"), string_view("Sign in with the Wiqis account you use across all our apps. Your lessons and review schedule remain here on Underlayer."))
    }

    public func handle_register_page(req : &http::Request) : http::Response {
        return render_account_entry_page(req, string_view("Create account — Underlayer"), string_view("Start learning deeply"), string_view("Create one Wiqis account to sign in everywhere. It also gives you a private place here for progress, notes and reviews."))
    }

    // The no-JavaScript path.  The iframe's src is absolute and carries
    // `?next=close`, exactly as Timeline's exported sign-in page does.
    func render_account_fallback_page(req : &http::Request, title : string_view, frame_path : string_view, frame_title : string_view) : http::Response {
        var page = HtmlPage()
        page.defaultPrepare()
        WiqisTheme(&mut page, false)
        var title_value = title
        page.appendTitle(&title_value)
        var account = underlayer_core::account_url()
        var src = string()
        src.append_view(account.to_view())
        src.append_view(&frame_path)
        var src_view = src.to_view()
        underlayer_content::render_auth_stage(&mut page, frame_title, src_view)
        underlayer_content::render_auth_redirect_js(&mut page)
        var html_out = page.toString()
        return send_html(&html_out)
    }

    public func handle_signin_page(req : &http::Request) : http::Response {
        return render_account_fallback_page(req, string_view("Sign in — Underlayer"), string_view("/login?next=close"), string_view("Wiqis account sign in"))
    }

    public func handle_signup_page(req : &http::Request) : http::Response {
        return render_account_fallback_page(req, string_view("Create account — Underlayer"), string_view("/signup?next=close"), string_view("Wiqis account sign up"))
    }

    // End the LOCAL Underlayer session.  The account session is a cookie on
    // account.wiqis.com and is cleared by that service's own sign-out page.
    public func handle_signout_page(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultPrepare()
        WiqisTheme(&mut page, false)
        var title = string_view("Sign out — Underlayer")
        page.appendTitle(&title)
        #html {
            <main class="ul-signout">
                <h1>Signing out</h1>
                <p>Clearing your Underlayer session&hellip;</p>
                <a href="/">Return home</a>
            </main>
        }
        #js {
            fetch('/api/auth/logout', { method: 'POST', credentials: 'same-origin' })
                .catch(function () { })
                .then(function () { window.location.href = '/'; });
        }
        #css {
            .ul-signout { max-width: 34rem; margin: 0 auto; padding: 4rem 1.5rem; font-family: var(--font-sans); }
            .ul-signout h1 { font-size: 1.5rem; margin: 0 0 1rem; }
            .ul-signout a { color: hsl(var(--primary)); }
        }
        var html_out = page.toString()
        return send_html(&html_out)
    }

}
