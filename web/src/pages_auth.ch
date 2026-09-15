// underlayer_web — Auth page handlers (login, register, forgot/reset password).
using std::string
using std::string_view

public namespace underlayer_web {

    public func handle_login_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Login — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="auth-page">
                <div class="auth-card">
                    <div class="auth-header">
                        <a href="/" class="auth-brand">Underlayer</a>
                        <h1>Welcome Back</h1>
                        <p class="auth-subtitle">Sign in to continue your learning journey</p>
                    </div>
                    <form id="loginForm" class="auth-form">
                        <div class="form-group">
                            <label for="email">Email</label>
                            <input type="email" id="email" name="email" required autocomplete="email" placeholder="you@example.com" />
                        </div>
                        <div class="form-group">
                            <label for="password">Password</label>
                            <div class="password-field">
                                <input type="password" id="password" name="password" required autocomplete="current-password" placeholder="Enter your password" />
                                <button type="button" class="password-toggle" onclick="togglePassword('password', this)" aria-label="Show password">Show</button>
                            </div>
                        </div>
                        <div class="form-row">
                            <label class="checkbox-label">
                                <input type="checkbox" id="remember" name="remember" />
                                <span>Remember me</span>
                            </label>
                        </div>
                        <button type="submit" class="btn btn-primary btn-full">Sign In</button>
                    </form>
                    <div class="auth-footer">
                        <a href="/forgot-password">Forgot your password?</a>
                        <p>Don't have an account? <a href="/register">Create one</a></p>
                    </div>
                </div>
            </div>
        }

        #css {
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="email"],
            .form-group input[type="password"],
            .form-group input[type="text"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .password-field { position: relative; }
            .password-toggle { position: absolute; right: 0.75rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: hsl(217 91% 60%); cursor: pointer; font-size: 0.85rem; font-weight: 500; padding: 0.25rem; }
            .password-toggle:hover { text-decoration: underline; }
            .form-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
            .checkbox-label { display: flex; align-items: center; gap: 0.5rem; cursor: pointer; font-size: 0.9rem; color: hsl(var(--muted-foreground)); }
            .checkbox-label input { width: 1rem; height: 1rem; accent-color: hsl(217 91% 60%); }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.9rem; }
            .auth-footer a:hover { text-decoration: underline; }
            .auth-footer p { margin-top: 0.75rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-error { background: hsl(0 84% 95%); border: 1px solid hsl(0 84% 80%); color: hsl(0 84% 40%); padding: 0.75rem 1rem; border-radius: 8px; margin-bottom: 1rem; font-size: 0.9rem; display: none; }
            .auth-success { background: hsl(142 76% 95%); border: 1px solid hsl(142 76% 80%); color: hsl(142 76% 30%); padding: 0.75rem 1rem; border-radius: 8px; margin-bottom: 1rem; font-size: 0.9rem; display: none; }
            @media (max-width: 480px) { .auth-card { padding: 1.5rem; margin: 0.75rem; } }
        }

        #js {
            function togglePassword(fieldId, btn) {
                var input = document.getElementById(fieldId);
                if(input.type === 'password') { input.type = 'text'; btn.textContent = 'Hide'; }
                else { input.type = 'password'; btn.textContent = 'Show'; }
            }

            document.getElementById('loginForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var email = document.getElementById('email').value;
                var password = document.getElementById('password').value;
                var remember = document.getElementById('remember').checked;
                fetch('/api/auth/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: email, password: password, remember: remember })
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    if(data.error) { alert(data.error); }
                    else {
                        localStorage.setItem('session_token', data.session_token);
                        if(data.refresh_token) { localStorage.setItem('refresh_token', data.refresh_token); }
                        window.location.href = '/';
                    }
                  }).catch(function() { alert('Network error. Please try again.'); });
            });
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    public func handle_register_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Register — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="auth-page">
                <div class="auth-card">
                    <div class="auth-header">
                        <a href="/" class="auth-brand">Underlayer</a>
                        <h1>Create Account</h1>
                        <p class="auth-subtitle">Start learning deeply today</p>
                    </div>
                    <form id="registerForm" class="auth-form">
                        <div class="form-group">
                            <label for="name">Full Name</label>
                            <input type="text" id="name" name="name" required autocomplete="name" placeholder="Your name" />
                        </div>
                        <div class="form-group">
                            <label for="email">Email</label>
                            <input type="email" id="email" name="email" required autocomplete="email" placeholder="you@example.com" />
                        </div>
                        <div class="form-group">
                            <label for="password">Password</label>
                            <div class="password-field">
                                <input type="password" id="password" name="password" required autocomplete="new-password" placeholder="At least 8 characters" minlength="8" oninput="checkStrength()" />
                                <button type="button" class="password-toggle" onclick="togglePassword('password', this)" aria-label="Show password">Show</button>
                            </div>
                            <div class="strength-bar" id="strength-bar">
                                <div class="strength-fill" id="strength-fill"></div>
                            </div>
                            <span class="strength-text" id="strength-text"></span>
                        </div>
                        <div class="form-group">
                            <label for="confirmPassword">Confirm Password</label>
                            <div class="password-field">
                                <input type="password" id="confirmPassword" name="confirmPassword" required autocomplete="new-password" placeholder="Re-enter password" />
                                <button type="button" class="password-toggle" onclick="togglePassword('confirmPassword', this)" aria-label="Show password">Show</button>
                            </div>
                        </div>
                        <div class="form-row">
                            <label class="checkbox-label">
                                <input type="checkbox" id="terms" name="terms" required />
                                <span>I agree to the <a href="/terms">Terms of Service</a> and <a href="/privacy">Privacy Policy</a></span>
                            </label>
                        </div>
                        <button type="submit" class="btn btn-primary btn-full">Create Account</button>
                    </form>
                    <div class="auth-footer">
                        <p>Already have an account? <a href="/login">Sign in</a></p>
                    </div>
                </div>
            </div>
        }

        #css {
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="email"],
            .form-group input[type="password"],
            .form-group input[type="text"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .password-field { position: relative; }
            .password-toggle { position: absolute; right: 0.75rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: hsl(217 91% 60%); cursor: pointer; font-size: 0.85rem; font-weight: 500; padding: 0.25rem; }
            .password-toggle:hover { text-decoration: underline; }
            .strength-bar { height: 4px; background: hsl(var(--border)); border-radius: 2px; margin-top: 0.5rem; overflow: hidden; }
            .strength-fill { height: 100%; width: 0; border-radius: 2px; transition: width 0.3s, background 0.3s; }
            .strength-text { font-size: 0.8rem; margin-top: 0.25rem; display: block; color: hsl(var(--muted-foreground)); }
            .form-row { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1.5rem; }
            .checkbox-label { display: flex; align-items: flex-start; gap: 0.5rem; cursor: pointer; font-size: 0.85rem; color: hsl(var(--muted-foreground)); line-height: 1.4; }
            .checkbox-label input { width: 1rem; height: 1rem; accent-color: hsl(217 91% 60%); margin-top: 0.1rem; flex-shrink: 0; }
            .checkbox-label a { color: hsl(217 91% 60%); text-decoration: none; }
            .checkbox-label a:hover { text-decoration: underline; }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.9rem; }
            .auth-footer a:hover { text-decoration: underline; }
            .auth-footer p { margin-top: 0.75rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            @media (max-width: 480px) { .auth-card { padding: 1.5rem; margin: 0.75rem; } }
        }

        #js {
            function togglePassword(fieldId, btn) {
                var input = document.getElementById(fieldId);
                if(input.type === 'password') { input.type = 'text'; btn.textContent = 'Hide'; }
                else { input.type = 'password'; btn.textContent = 'Show'; }
            }

            function checkStrength() {
                var pw = document.getElementById('password').value;
                var fill = document.getElementById('strength-fill');
                var text = document.getElementById('strength-text');
                var score = 0;
                if(pw.length >= 8) { score++; }
                if(pw.length >= 12) { score++; }
                var hasLower = false;
                var hasUpper = false;
                var hasDigit = false;
                var hasSpecial = false;
                for(var ci = 0; ci < pw.length; ci++) {
                    var ch = pw.charCodeAt(ci);
                    if(ch >= 97 && ch <= 122) { hasLower = true; }
                    if(ch >= 65 && ch <= 90) { hasUpper = true; }
                    if(ch >= 48 && ch <= 57) { hasDigit = true; }
                    if((ch < 48 || ch > 57) && (ch < 65 || ch > 90) && (ch < 97 || ch > 122)) { hasSpecial = true; }
                }
                if(hasLower && hasUpper) { score++; }
                if(hasDigit) { score++; }
                if(hasSpecial) { score++; }
                var pct = (score / 5) * 100;
                fill.style.width = pct + '%';
                if(score <= 1) { fill.style.background = '#ef4444'; text.textContent = 'Weak'; text.style.color = '#ef4444'; }
                else if(score <= 2) { fill.style.background = '#f59e0b'; text.textContent = 'Fair'; text.style.color = '#f59e0b'; }
                else if(score <= 3) { fill.style.background = '#3b82f6'; text.textContent = 'Good'; text.style.color = '#3b82f6'; }
                else { fill.style.background = '#22c55e'; text.textContent = 'Strong'; text.style.color = '#22c55e'; }
                if(pw.length === 0) { fill.style.width = '0'; text.textContent = ''; }
            }

            document.getElementById('registerForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var name = document.getElementById('name').value;
                var email = document.getElementById('email').value;
                var password = document.getElementById('password').value;
                var confirmPassword = document.getElementById('confirmPassword').value;
                var terms = document.getElementById('terms').checked;
                if(password !== confirmPassword) { alert('Passwords do not match.'); return; }
                if(!terms) { alert('You must accept the Terms of Service.'); return; }
                fetch('/api/auth/register', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name: name, email: email, password: password })
                }).then(function(r) { return r.json(); })
                  .then(function(data) {
                    if(data.error) { alert(data.error); }
                    else {
                        localStorage.setItem('session_token', data.session_token);
                        if(data.refresh_token) { localStorage.setItem('refresh_token', data.refresh_token); }
                        window.location.href = '/';
                    }
                  }).catch(function() { alert('Network error. Please try again.'); });
            });
        }

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    public func handle_forgot_password_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
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
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="email"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.9rem; }
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
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    public func handle_reset_password_page(req : &http::Request, res : *mut http::ResponseWriter) {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
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
            .auth-page { display: flex; justify-content: center; align-items: center; min-height: 100vh; background: hsl(var(--background)); font-family: system-ui, sans-serif; }
            .auth-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2.5rem; width: 100%; max-width: 420px; margin: 1rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .auth-header { text-align: center; margin-bottom: 2rem; }
            .auth-brand { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); text-decoration: none; display: inline-block; margin-bottom: 1rem; }
            .auth-brand:hover { text-decoration: none; }
            .auth-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; color: hsl(var(--foreground)); }
            .auth-subtitle { color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .auth-form { margin-bottom: 1.5rem; }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input[type="password"] { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .password-field { position: relative; }
            .password-toggle { position: absolute; right: 0.75rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: hsl(217 91% 60%); cursor: pointer; font-size: 0.85rem; font-weight: 500; padding: 0.25rem; }
            .password-toggle:hover { text-decoration: underline; }
            .btn { display: inline-block; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; transition: all 0.15s; text-align: center; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            .btn-full { width: 100%; }
            .auth-footer { text-align: center; }
            .auth-footer a { color: hsl(217 91% 60%); text-decoration: none; font-size: 0.9rem; }
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
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}
