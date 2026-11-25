// underlayer_web — Password-recovery pages.
//
// /login and /register used to collect credentials here.  They now live in
// pages_auth_embedded.ch and embed the shared Wiqis account service instead;
// the local POST /api/auth/login|register handlers remain intact for the
// Android client.  The two pages below are recovery flows on Underlayer's own
// database and are deliberately unchanged.
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_forgot_password_page(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        WiqisTheme(&mut page, false)
        // THE PRE-PAINT THEME, on a page that draws no navbar.
        underlayer_content::render_theme_boot_js(&mut page, false)
        underlayer_content::render_color_scheme_meta(&mut page)
        var title = std::string_view("Forgot Password — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="auth-page">
                <div class="auth-card">
                    <div class="auth-header">
                        <a href="/" class="auth-brand">Underlayer</a>
                        <h1>Forgot Password</h1>
                        <p class="auth-subtitle">Enter your email and we'll send you a reset link</p>
                    </div>
                    <div id="success-msg" class="auth-success" style="display:none;">
                        <strong>Check your email.</strong> We sent a password reset link to the address you provided.
                    </div>
                    <form id="forgotForm" class="auth-form">
                        <div class="form-group">
                            <label for="email">Email</label>
                            <input type="email" id="email" name="email" required autocomplete="email" placeholder="you@example.com" />
                        </div>
                        <button type="submit" class="btn btn-primary btn-full">Send Reset Link</button>
                    </form>
                    <div class="auth-footer">
                        <p>Remember your password? <a href="/login">Sign in</a></p>
                    </div>
                </div>
            </div>
        }

        #css {
            body { margin: 0; }
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--primary)); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="email"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(var(--primary)); box-shadow: 0 0 0 3px hsl(var(--primary) / 15%); }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(var(--primary)); color: white; }
            .btn-primary:hover { background: hsl(var(--primary)); filter: brightness(0.9); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(var(--primary)); text-decoration: none; font-size: 0.9rem; }
            .auth-footer a:hover { text-decoration: underline; }
            .auth-footer p { margin-top: 0.75rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-success { background: hsl(142 76% 95%); border: 1px solid hsl(142 76% 80%); color: hsl(142 76% 30%); padding: 0.75rem 1rem; border-radius: 8px; margin-bottom: 1rem; font-size: 0.9rem; text-align: center; }
            @media (max-width: 480px) { .auth-card { padding: 1.5rem; margin: 0.75rem; } }
        }

        #js {
            document.getElementById('forgotForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var email = document.getElementById('email').value;
                fetch('/api/auth/forgot-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: email })
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    document.getElementById('forgotForm').style.display = 'none';
                    document.getElementById('success-msg').style.display = 'block';
                  }).catch(function() { alert('Network error. Please try again.'); });
            });
        }

        var html_out = page.toString()
        return send_html(&html_out)
    }

    public func handle_reset_password_page(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        WiqisTheme(&mut page, false)
        underlayer_content::render_theme_boot_js(&mut page, false)
        underlayer_content::render_color_scheme_meta(&mut page)
        var title = std::string_view("Reset Password — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="auth-page">
                <div class="auth-card">
                    <div class="auth-header">
                        <a href="/" class="auth-brand">Underlayer</a>
                        <h1>Reset Password</h1>
                        <p class="auth-subtitle">Enter your new password below</p>
                    </div>
                    <div id="success-msg" class="auth-success" style="display:none;">
                        <strong>Password reset!</strong> Redirecting to sign in...
                    </div>
                    <form id="resetForm" class="auth-form">
                        <div class="form-group">
                            <label for="password">New Password</label>
                            <div class="password-field">
                                <input type="password" id="password" name="password" required autocomplete="new-password" placeholder="At least 8 characters" minlength="8" />
                                <button type="button" class="password-toggle" onclick="togglePassword('password', this)" aria-label="Show password">Show</button>
                            </div>
                        </div>
                        <div class="form-group">
                            <label for="confirmPassword">Confirm Password</label>
                            <div class="password-field">
                                <input type="password" id="confirmPassword" name="confirmPassword" required autocomplete="new-password" placeholder="Re-enter password" />
                                <button type="button" class="password-toggle" onclick="togglePassword('confirmPassword', this)" aria-label="Show password">Show</button>
                            </div>
                        </div>
                        <button type="submit" class="btn btn-primary btn-full">Reset Password</button>
                    </form>
                    <div class="auth-footer">
                        <p><a href="/login">Back to Sign In</a></p>
                    </div>
                </div>
            </div>
        }

        #css {
            body { margin: 0; }
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--primary)); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="password"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(var(--primary)); box-shadow: 0 0 0 3px hsl(var(--primary) / 15%); }
            .password-field { position: relative; }
            .password-toggle { position: absolute; right: 0.75rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: hsl(var(--primary)); cursor: pointer; font-size: 0.85rem; font-weight: 500; padding: 0.25rem; }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(var(--primary)); color: white; }
            .btn-primary:hover { background: hsl(var(--primary)); filter: brightness(0.9); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(var(--primary)); text-decoration: none; font-size: 0.9rem; }
            .auth-footer a:hover { text-decoration: underline; }
            .auth-footer p { margin-top: 0.75rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-success { background: hsl(142 76% 95%); border: 1px solid hsl(142 76% 80%); color: hsl(142 76% 30%); padding: 0.75rem 1rem; border-radius: 8px; margin-bottom: 1rem; font-size: 0.9rem; text-align: center; }
            @media (max-width: 480px) { .auth-card { padding: 1.5rem; margin: 0.75rem; } }
        }

        #js {
            function togglePassword(fieldId, btn) {
                var input = document.getElementById(fieldId);
                if(input.type === 'password') { input.type = 'text'; btn.textContent = 'Hide'; }
                else { input.type = 'password'; btn.textContent = 'Show'; }
            }

            function getToken() {
                var params = new URLSearchParams(window.location.search);
                return params.get('token') || '';
            }

            document.getElementById('resetForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var password = document.getElementById('password').value;
                var confirmPassword = document.getElementById('confirmPassword').value;
                var token = getToken();
                if(password !== confirmPassword) { alert('Passwords do not match.'); return; }
                if(!token) { alert('Invalid or missing reset token.'); return; }
                fetch('/api/auth/reset-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ token: token, password: password })
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    if(data.error) { alert(data.error); }
                    else {
                        document.getElementById('resetForm').style.display = 'none';
                        document.getElementById('success-msg').style.display = 'block';
                        setTimeout(function() { window.location.href = '/login'; }, 2000);
                    }
                  }).catch(function() { alert('Network error. Please try again.'); });
            });
        }

        var html_out = page.toString()
        return send_html(&html_out)
    }

}
