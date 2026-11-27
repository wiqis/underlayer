// underlayer_web — Terms of Service and Privacy Policy pages.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_terms_page(page : &mut HtmlPage) {
        page.defaultPrepare()
        WiqisTheme(page, true)
        // THE PRE-PAINT THEME, on a page that draws no navbar.
        //
        // These pages are the ones the nav audit listed as having no navbar at
        // all (/login, /register, /settings, /help, /faq, /about, ...).  Adding a
        // navbar to an auth page or a legal page is a design decision that was
        // deliberately deferred -- but the THEME is not the same decision.  They
        // already inject the components theme, whose .dark rules key on the <html>
        // class, so with the class set they respect the reader's OS preference
        // and their toggle.  Without it they render light unconditionally, which
        // is a reader with a dark OS reading a bright page.
        underlayer_content::render_theme_boot_js(page, false)
        underlayer_content::render_color_scheme_meta(page)
        var title = std::string("Terms of Service — Underlayer")
        var seo_desc = seo_desc_terms()
        var seo_path = string("/terms")
        var seo_ld = string()
        append_seo_head(page, &title, &seo_desc, &seo_path, &seo_ld)

        #html {
            <div class="legal-page">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help">Help</a>
                        <a href="/terms" class="active">Terms</a>
                        <a href="/privacy">Privacy</a>
                        <a href="/about">About</a>
                    </div>
                </div>

                <div class="legal-container">
                    <h1>Terms of Service</h1>
                    <p class="legal-updated">Last updated: 27 November 2026</p>

                    <h2>1. Acceptance of Terms</h2>
                    <p>By creating an account or using Underlayer, you agree to these Terms of Service. If you do not agree, do not use the platform.</p>

                    <h2>2. Accounts and sign-in</h2>
                    <p>Sign-in is provided by the Wiqis Account service at account.wiqis.com, embedded in this site. It supports an email address and password, a passkey, and Google sign-in. Credentials are handled by that account service; Underlayer keeps your learning data in its own database and links it to your account identity. You are responsible for keeping your credentials secure and for all activity under your account. You must provide accurate information and be old enough to form a binding contract in your jurisdiction.</p>

                    <h2>3. Acceptable Use</h2>
                    <p>You agree not to misuse the service, including by attempting to disrupt it, accessing other users' data, scraping content at scale, or using the platform for unlawful purposes.</p>

                    <h2>4. Learning Content</h2>
                    <p>Course content is provided for educational purposes. We work to keep it accurate, but we make no warranty that it is free of errors. Technical content may change as specifications and tools evolve.</p>

                    <h2>5. Your Content</h2>
                    <p>You retain ownership of notes and other content you create. You grant us the limited rights needed to store, process, and display that content back to you as part of the service.</p>

                    <h2>6. Purchases, payment and refunds</h2>
                    <p>Some courses, or a course pass, may be offered for a fee. The price and any applicable tax are shown at checkout before you pay. Paddle acts as merchant of record for paid purchases: it processes the payment and handles tax, receipts and refund requests. Underlayer does not receive or store your full card number; we keep only entitlement status and a receipt reference so access can be granted and supported. A purchase grants access to the paid content for the account that bought it; it does not transfer ownership of the course material.</p>
                    <p>Refund requests are handled by Paddle under its refund terms. If a purchase is refunded or charged back, the related entitlement is revoked and access closes on the next request. Learning progress is retained and is not erased by a refund. No course is paid today: if a paid course is introduced, this page and the checkout will name it before any payment is taken.</p>

                    <h2>7. Availability</h2>
                    <p>The service is provided "as is" and "as available". We may modify, suspend, or discontinue features at any time. We are not liable for interruptions or data loss, though we take reasonable care to avoid them.</p>

                    <h2>8. Termination</h2>
                    <p>You may delete your account at any time. We may suspend accounts that violate these terms. On termination, your access ends and your data may be deleted in line with our Privacy Policy.</p>

                    <h2>9. Changes to These Terms</h2>
                    <p>We may update these terms. Material changes will be reflected by updating the date above. Continued use after a change constitutes acceptance.</p>

                    <h2>10. Contact</h2>
                    <p>Questions about these terms can be raised through the <a href="/help">Help</a> page.</p>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { display: flex; align-items: center; justify-content: space-between; padding: 0.75rem 2rem; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.25rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); }
            .help-nav-links a.active { color: hsl(217 91% 60%); }
            .legal-container { max-width: 760px; margin: 0 auto; padding: 2.5rem 2rem 4rem 2rem; }
            .legal-container h1 { font-size: 2rem; margin-bottom: 0.25rem; }
            .legal-updated { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-bottom: 2rem; }
            .legal-container h2 { font-size: 1.15rem; margin-top: 2rem; margin-bottom: 0.5rem; }
            .legal-container p { color: hsl(var(--muted-foreground)); margin: 0 0 0.75rem 0; }
            .legal-container a { color: hsl(217 91% 60%); }
            @media (max-width: 640px) { .help-nav { padding: 0.75rem 1rem; } .legal-container { padding: 1.5rem 1rem 3rem 1rem; } }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem('theme');
                if (saved) { return saved; }
                return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }
            document.documentElement.classList.toggle('dark', getTheme() === 'dark');
        }
    }

    public func render_privacy_page(page : &mut HtmlPage) {
        page.defaultPrepare()
        WiqisTheme(page, true)
        // The CSS block below must differ from /terms' block: the static site
        // drops a page-local stylesheet that is byte-identical to one already
        // emitted, which is why /privacy shipped with NO <style> at all and
        // rendered in Times New Roman. The data attribute makes the two blocks
        // distinct and gives the extra rule a hook.
        // THE PRE-PAINT THEME, on a page that draws no navbar.
        //
        // These pages are the ones the nav audit listed as having no navbar at
        // all (/login, /register, /settings, /help, /faq, /about, ...).  Adding a
        // navbar to an auth page or a legal page is a design decision that was
        // deliberately deferred -- but the THEME is not the same decision.  They
        // already inject the components theme, whose .dark rules key on the <html>
        // class, so with the class set they respect the reader's OS preference
        // and their toggle.  Without it they render light unconditionally, which
        // is a reader with a dark OS reading a bright page.
        underlayer_content::render_theme_boot_js(page, false)
        underlayer_content::render_color_scheme_meta(page)
        var title = std::string("Privacy Policy — Underlayer")
        var seo_desc = seo_desc_privacy()
        var seo_path = string("/privacy")
        var seo_ld = string()
        append_seo_head(page, &title, &seo_desc, &seo_path, &seo_ld)

        #html {
            <div class="legal-page" data-page="privacy">
                <div class="help-nav">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="help-nav-links">
                        <a href="/help">Help</a>
                        <a href="/terms">Terms</a>
                        <a href="/privacy" class="active">Privacy</a>
                        <a href="/about">About</a>
                    </div>
                </div>

                <div class="legal-container">
                    <h1>Privacy Policy</h1>
                    <p class="legal-updated">Last updated: 27 November 2026</p>

                    <h2>1. What We Collect</h2>
                    <p>When you register we receive an account identifier and the profile details the account service provides (such as your name and email address). We also store the learning data generated as you use the platform: lesson views, exercise attempts, review ratings, notes, bookmarks, study plans and streaks.</p>

                    <h2>2. Embedded sign-in and Google</h2>
                    <p>The sign-in dialog on this site is served by the Wiqis Account service at account.wiqis.com. It can sign you in with an email address and password, a passkey, or through Google; the Google consent prompt is shown by Google. Those credentials are handled by the account service and by Google, not by Underlayer. Underlayer receives a session credential, keeps learning data in its own database, and does not copy it into the account service.</p>

                    <h2>3. How We Use It</h2>
                    <p>Your data is used to run the service: to schedule spaced-repetition reviews, show your progress, and personalize what you see next. We do not sell your personal data.</p>

                    <h2>4. Cookies and local storage</h2>
                    <p>Sign-in sets an HttpOnly session cookie on underlayer.wiqis.com. The browser sends it to the server with each request so the server can recognise your session; page scripts cannot read it, and it is not used for advertising or cross-site tracking. Browser local storage keeps a legacy copy of the session token for API callers and offline pages, and remembers display preferences such as the theme; it is no longer the credential used by the server-side page gate. We do not use third-party advertising trackers.</p>

                    <h2>5. Payments</h2>
                    <p>Paddle acts as merchant of record if a paid course or course pass is offered. It handles the payment, tax and receipt, so Underlayer does not receive or store full card details. We retain only entitlement status and a receipt reference to grant access and handle a refund. Refund requests go through Paddle; a refunded or charged-back purchase loses its entitlement on the next request, while learning progress is retained.</p>

                    <h2>6. Sharing</h2>
                    <p>We do not sell your personal data. We share only what is needed to operate the service: identity with the Wiqis Account service, and payment and entitlement data with Paddle when a paid purchase exists. The site loads fonts from Google Fonts, which receives the ordinary request metadata needed to serve that resource. We may also disclose data where required by law. Aggregate, non-identifying statistics may be used to improve the courses.</p>

                    <h2>7. Your choices</h2>
                    <p>The <a href="/settings">Settings</a> page lets you export your data, deactivate your account, or permanently delete it, and remove individual data categories. Export covers your progress, review history and profile. Deleting your account removes your personal data from our live systems, subject to routine backups; deactivation stops use of the account without deleting it.</p>

                    <h2>8. Security</h2>
                    <p>We use standard measures to protect your data, including the HttpOnly session cookie and HTTPS. No system is perfectly secure, so please use a strong, unique password.</p>

                    <h2>9. Children</h2>
                    <p>The service is not directed at children below the age required to consent to data processing in their jurisdiction.</p>

                    <h2>10. Changes</h2>
                    <p>We may update this policy. Material changes will be reflected by updating the date above.</p>

                    <h2>11. Contact</h2>
                    <p>Privacy questions can be raised through the <a href="/help">Help</a> page.</p>
                </div>
            </div>
        }

        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            .help-nav { display: flex; align-items: center; justify-content: space-between; padding: 0.75rem 2rem; background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .help-nav-links { display: flex; gap: 1.25rem; }
            .help-nav-links a { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; }
            .help-nav-links a:hover { color: hsl(var(--foreground)); }
            .help-nav-links a.active { color: hsl(217 91% 60%); }
            .legal-container { max-width: 760px; margin: 0 auto; padding: 2.5rem 2rem 4rem 2rem; }
            .legal-container h1 { font-size: 2rem; margin-bottom: 0.25rem; }
            .legal-updated { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-bottom: 2rem; }
            .legal-container h2 { font-size: 1.15rem; margin-top: 2rem; margin-bottom: 0.5rem; }
            .legal-container p { color: hsl(var(--muted-foreground)); margin: 0 0 0.75rem 0; }
            .legal-container a { color: hsl(217 91% 60%); }
            .legal-page[data-page="privacy"] { color: hsl(var(--foreground)); }
            @media (max-width: 640px) { .help-nav { padding: 0.75rem 1rem; } .legal-container { padding: 1.5rem 1rem 3rem 1rem; } }
        }

        #js {
            function getTheme() {
                var saved = localStorage.getItem('theme');
                if (saved) { return saved; }
                return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }
            document.documentElement.classList.toggle('dark', getTheme() === 'dark');
        }
    }

    // Pre-rendered routes (see pages_help.ch): the framework renders once at
    // build time and serves the frozen artifact.
    public func page_terms(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_terms_page(page)
    }

    public func page_privacy(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_privacy_page(page)
    }

}