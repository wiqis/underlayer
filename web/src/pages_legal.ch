// underlayer_web — Terms of Service and Privacy Policy pages.
using std::string
using std::string_view

public namespace underlayer_web {

    public func render_terms_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Terms of Service — Underlayer")
        page.appendTitle(&title)

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
                    <p class="legal-updated">Last updated: September 2026</p>

                    <h2>1. Acceptance of Terms</h2>
                    <p>By creating an account or using Underlayer, you agree to these Terms of Service. If you do not agree, do not use the platform.</p>

                    <h2>2. Your Account</h2>
                    <p>You are responsible for keeping your account credentials secure and for all activity that occurs under your account. You must provide accurate information and be old enough to form a binding contract in your jurisdiction.</p>

                    <h2>3. Acceptable Use</h2>
                    <p>You agree not to misuse the service, including by attempting to disrupt it, accessing other users' data, scraping content at scale, or using the platform for unlawful purposes.</p>

                    <h2>4. Learning Content</h2>
                    <p>Course content is provided for educational purposes. We work to keep it accurate, but we make no warranty that it is free of errors. Technical content may change as specifications and tools evolve.</p>

                    <h2>5. Your Content</h2>
                    <p>You retain ownership of notes and other content you create. You grant us the limited rights needed to store, process, and display that content back to you as part of the service.</p>

                    <h2>6. Availability</h2>
                    <p>The service is provided "as is" and "as available". We may modify, suspend, or discontinue features at any time. We are not liable for interruptions or data loss, though we take reasonable care to avoid them.</p>

                    <h2>7. Termination</h2>
                    <p>You may delete your account at any time. We may suspend accounts that violate these terms. On termination, your access ends and your data may be deleted in line with our Privacy Policy.</p>

                    <h2>8. Changes to These Terms</h2>
                    <p>We may update these terms. Material changes will be reflected by updating the date above. Continued use after a change constitutes acceptance.</p>

                    <h2>9. Contact</h2>
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

        return page.toString()
    }

    public func render_privacy_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Privacy Policy — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="legal-page">
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
                    <p class="legal-updated">Last updated: September 2026</p>

                    <h2>1. What We Collect</h2>
                    <p>We collect the information you provide when you register (such as your name and email address), and the learning data generated as you use the platform: lesson views, exercise attempts, review ratings, notes, bookmarks, study plans, and streaks.</p>

                    <h2>2. How We Use It</h2>
                    <p>Your data is used to run the service: to schedule spaced-repetition reviews, show your progress, and personalize what you see next. We do not sell your personal data.</p>

                    <h2>3. Storage</h2>
                    <p>Learning data is stored in our database and associated with your account. Session tokens are stored in your browser's local storage so you stay signed in.</p>

                    <h2>4. Cookies and Local Storage</h2>
                    <p>We use browser local storage to keep you signed in and to remember your display preferences. We do not use third-party advertising trackers.</p>

                    <h2>5. Sharing</h2>
                    <p>We do not share your personal data with third parties except as required to operate the service or comply with the law. Aggregate, non-identifying statistics may be used to improve the courses.</p>

                    <h2>6. Your Choices</h2>
                    <p>You can export your data, deactivate your account, or permanently delete your account from the <a href="/settings">Settings</a> page. Deleting your account removes your personal data from our systems, subject to routine backups.</p>

                    <h2>7. Security</h2>
                    <p>We use standard measures to protect your data. No system is perfectly secure, so please use a strong, unique password.</p>

                    <h2>8. Children</h2>
                    <p>The service is not directed at children below the age required to consent to data processing in their jurisdiction.</p>

                    <h2>9. Changes</h2>
                    <p>We may update this policy. Material changes will be reflected by updating the date above.</p>

                    <h2>10. Contact</h2>
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

        return page.toString()
    }

    public func handle_terms_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_terms_page()
        send_html(res, &raw html)
    }

    public func handle_privacy_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var html = render_privacy_page()
        send_html(res, &raw html)
    }

}
