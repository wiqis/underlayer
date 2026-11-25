// underlayer_content — THE EMBEDDED WIQIS SIGN-IN, one flow for every surface.
//
// Underlayer never collects a credential.  It opens the account service in a
// native <dialog> in place, waits for `postMessage({type:"login_success"})`,
// closes and reloads.  The shape is copied from Web/timeline's
// `features/app/client.ch` and `features/auth/pages.ch` (and easyToDo's twin),
// because it is the fleet contract — not an Underlayer invention.
//
// TWO IFRAMES, NEITHER COVERING THE OTHER.  `render_embedded_auth_runtime`
// installs the dialog iframe used by anyone with JavaScript; `render_auth_stage`
// emits the statically rendered iframe at /sign-in and /sign-up for a visitor
// with scripting off.  BOTH carry `allow="publickey-credentials-get"`: WebAuthn
// is a powerful feature and Permissions Policy disables it in a cross-origin
// frame unless the embedding page delegates it.  The failure is silent — no
// prompt, no log, no console line — and the same page works at the top level.
//
// IT LIVES IN content/ SO THERE IS ONLY ONE COPY.  The 438 lesson pages are
// built in this layer, which cannot import web/.  Putting the installer here
// means render_site_nav gives a lesson page the identical dialog a collection
// page gets, without a second hand-maintained copy drifting apart (the way the
// session helpers in web/src/session_js.ch and content/src/lesson_identity.ch
// had to be duplicated and guarded).  web/ imported content/ already.
//
// The account URL is carried in a data attribute rather than interpolated into
// the JavaScript: #js is a macro with no string escape token, and the account
// host is configuration.  Markup goes through #html, script through #js.
using std::string
using std::string_view

public namespace underlayer_content {

    public func render_embedded_auth_runtime(page : &mut HtmlPage) {
        var account = underlayer_core::account_url()
        var account_view = account.to_view()
        #html {
            <div id="ul-auth-config" data-account-url={account_view} hidden></div>
            <div id="ul-auth-fallback-template" hidden>
                <p class="ul-auth-fallback-text">Sign-in is temporarily unavailable — you can keep learning; progress is saved on this device.</p>
                <button type="button" class="ul-auth-retry">Retry</button>
            </div>
        }
        #js {
            window.__ulInstallAuthDialog = function () {
                if (window.__ulAuthDialogReady) { return; }
                // Already signed in? There is nothing to embed.
                if (window.__ulAuthenticated) { return; }
                var cfg = document.getElementById('ul-auth-config');
                var account = cfg ? cfg.getAttribute('data-account-url') : '';
                if (!account) { return; }
                window.__ulAuthDialogReady = true;

                var dialog = document.createElement('dialog');
                dialog.className = 'ul-auth-dialog';
                dialog.setAttribute('aria-label', 'Sign in with your Wiqis account');

                var close = document.createElement('button');
                close.type = 'button';
                close.className = 'ul-auth-dialog-close';
                close.setAttribute('aria-label', 'Close');
                close.innerHTML = '&times;';
                close.addEventListener('click', function () { dialog.close(); });

                var frame = document.createElement('iframe');
                frame.className = 'wq-embed';
                frame.setAttribute('title', 'Wiqis account');
                frame.setAttribute('allow', 'publickey-credentials-get');

                // The frame gets a src ONLY after the account origin answers.
                // A refused connection then shows this calm panel instead of
                // the browser's raw "refused to connect" document in a frame.
                var frameHost = document.createElement('div');
                frameHost.className = 'ul-auth-frame-host';
                frameHost.appendChild(frame);
                var status = document.createElement('p');
                status.className = 'ul-auth-status';
                status.hidden = true;
                var template = document.getElementById('ul-auth-fallback-template');
                var fallback = template ? template.cloneNode(true) : null;
                if (fallback) {
                    fallback.id = 'ul-auth-fallback';
                    fallback.className = 'ul-auth-fallback';
                    fallback.removeAttribute('hidden');
                    var retry = fallback.querySelector('.ul-auth-retry');
                    if (retry) { retry.addEventListener('click', function () { loadFrame(); }); }
                }

                dialog.appendChild(close);
                dialog.appendChild(status);
                dialog.appendChild(frameHost);
                if (fallback) { dialog.appendChild(fallback); }
                document.body.appendChild(dialog);

                // A native <dialog> reports a backdrop click as a click on itself.
                dialog.addEventListener('click', function (event) {
                    if (event.target === dialog) { dialog.close(); }
                });

                // Shared by the dialog and the static /sign-in surface.  A
                // no-cors fetch cannot read the response, but it DOES reject
                // when nothing is listening, which is the failure we need to
                // catch.  Six seconds is the ceiling, not the normal wait.
                window.__ulAuthProbe = window.__ulAuthProbe || function (origin, done) {
                    var opts = { mode: 'no-cors', cache: 'no-store' };
                    var timer = null;
                    if (typeof AbortController === 'function') {
                        var ctrl = new AbortController();
                        opts.signal = ctrl.signal;
                        timer = setTimeout(function () { ctrl.abort(); }, 6000);
                    }
                    fetch(origin + '/login?next=close', opts).then(function () {
                        if (timer) { clearTimeout(timer); }
                        done(true);
                    }).catch(function () {
                        if (timer) { clearTimeout(timer); }
                        done(false);
                    });
                };

                var loaded = false;
                function loadFrame() {
                    if (fallback) { fallback.hidden = true; }
                    frameHost.hidden = true;
                    status.hidden = false;
                    status.textContent = 'Checking sign-in availability...';
                    window.__ulAuthProbe(account, function (ok) {
                        status.hidden = true;
                        if (ok) {
                            if (!loaded) { frame.setAttribute('src', account + '/login?next=close'); loaded = true; }
                            frameHost.hidden = false;
                        } else {
                            frameHost.hidden = true;
                            if (fallback) { fallback.hidden = false; }
                        }
                    });
                }
                var open = function () {
                    if (dialog.showModal) { dialog.showModal(); }
                    else { dialog.setAttribute('open', 'open'); }
                    loadFrame();
                };
                window.__ulOpenAuth = open;

                // Delegated: the opener may be a nested element inside the anchor.
                document.addEventListener('click', function (event) {
                    var el = event.target;
                    while (el && el !== document) {
                        if (el.getAttribute && el.getAttribute('data-auth-open') !== null) {
                            event.preventDefault();
                            open();
                            return;
                        }
                        el = el.parentNode;
                    }
                });

                // The account frame posts this once the credential is accepted.
                // ?next=close stopped the frame navigating itself; this listener
                // is the only thing that moves.  It MUST exchange the shared
                // account cookie for a local session before reloading: the
                // cookie is identity on account.wiqis.com, but the page gate on
                // /dashboard, /review, /progress and /health reads ul_session.
                // Without this call the visitor looks signed in in the dialog
                // and is bounced straight back to /sign-in on the next page.
                window.__ulCompleteSignIn = window.__ulCompleteSignIn || function (done) {
                    fetch('/api/auth/from-account', {
                        method: 'POST',
                        credentials: 'same-origin',
                        headers: { 'Content-Type': 'application/json' },
                        body: '{}'
                    }).then(function (response) {
                        if (!response.ok) { throw new Error('account exchange failed'); }
                        done();
                    }).catch(function () {
                        var box = document.getElementById('ul-auth-error');
                        if (!box) {
                            box = document.createElement('div');
                            box.id = 'ul-auth-error';
                            box.setAttribute('role', 'alert');
                            box.style.cssText = 'position:fixed;left:50%;bottom:1rem;transform:translateX(-50%);z-index:9999;max-width:90vw;padding:0.75rem 1rem;border-radius:0.75rem;background:hsl(var(--destructive));color:white;font-size:0.9rem;';
                            document.body.appendChild(box);
                        }
                        box.textContent = 'We could not finish signing you in. Please try again.';
                    });
                };
                window.addEventListener('message', function (event) {
                    // Only the account service may claim a successful sign-in.
                    if (event.origin !== account) { return; }
                    if (event.data && event.data.type === 'login_success') {
                        if (dialog.open) { dialog.close(); }
                        window.__ulCompleteSignIn(function () { window.location.reload(); });
                    }
                });
            };
            window.__ulInstallAuthDialog();
        }
        #css {
            .ul-auth-dialog { width: 28rem; max-width: calc(100vw - 2rem); max-height: 90vh; padding: 1.25rem; border: 1px solid hsl(var(--border)); border-radius: var(--radius); background: hsl(var(--card)); color: hsl(var(--card-foreground)); box-shadow: var(--shadow); }
            .ul-auth-dialog-close { position: absolute; top: 0.5rem; right: 0.75rem; border: 0; background: transparent; color: hsl(var(--muted-foreground)); font-size: 1.5rem; line-height: 1; cursor: pointer; }
            .ul-auth-dialog .wq-embed { height: 620px; max-height: 76vh; }
            .ul-auth-status { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0.5rem 0; }
            .ul-auth-fallback { padding: 1.5rem 1rem; border: 1px solid hsl(var(--border)); border-radius: var(--radius); background: hsl(var(--card)); text-align: center; }
            .ul-auth-fallback-text { margin: 0 0 1rem; color: hsl(var(--foreground)); font-size: 0.95rem; line-height: 1.6; }
            .ul-auth-retry { min-height: 2.75rem; padding: 0.6rem 1.1rem; border: 1px solid hsl(var(--primary)); border-radius: var(--radius); background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); font: inherit; font-weight: 600; cursor: pointer; }
            .ul-auth-retry:hover { filter: brightness(1.06); }
            .ul-auth-frame-host[hidden], .ul-auth-fallback[hidden], .ul-auth-status[hidden] { display: none; }
        }
    }

    // The no-JavaScript surface.  `src` is the ABSOLUTE account URL including
    // `?next=close`; the caller builds it from underlayer_core::account_url().
    public func render_auth_stage(page : &mut HtmlPage, title : string_view, src : string_view) {
        var title_value = title
        var src_value = src
        #html {
            <div class="wq-stage ul-auth-stage">
                <div class="wq-stage-col">
                    <div class="wq-stage-brand">
                        <svg class="wq-brand-mark" style="width:36px;height:36px;" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                            <rect width="32" height="32" rx="8" fill="#ff5733"></rect>
                            <text x="16" y="23" font-family="Inter,Arial,sans-serif" font-size="19" font-weight="800" fill="#ffffff" text-anchor="middle">W</text>
                        </svg>
                        <span class="wq-brand-name">Wiqis</span>
                    </div>
                    <iframe
                        class="wq-embed"
                        style="height: 600px;"
                        title={title_value}
                        src={src_value}
                        allow="publickey-credentials-get"
                    ></iframe>
                    <div id="ul-auth-fallback-template" hidden>
                        <p class="ul-auth-fallback-text">Sign-in is temporarily unavailable — you can keep learning; progress is saved on this device.</p>
                        <button type="button" class="ul-auth-retry">Retry</button>
                    </div>
                    <div class="wq-foot">One Wiqis account signs you in to every app. <a href="/">Back to Underlayer</a></div>
                </div>
            </div>
        }
    }

    // Direct visit to /sign-in or /sign-up: the frame signs the reader in, but
    // nobody here closes a dialog, so send the TOP-LEVEL document home.  The
    // local exchange is still mandatory here — the fallback surface is the path
    // a visitor with no JavaScript takes, and it must leave the same ul_session
    // cookie behind as the dialog path.
    public func render_auth_redirect_js(page : &mut HtmlPage) {
        #js {
            // The static surface has no dialog runtime, so it carries its own
            // guarded copy of the reachability probe with the same signature.
            window.__ulAuthProbe = window.__ulAuthProbe || function (origin, done) {
                var opts = { mode: 'no-cors', cache: 'no-store' };
                var timer = null;
                if (typeof AbortController === 'function') {
                    var ctrl = new AbortController();
                    opts.signal = ctrl.signal;
                    timer = setTimeout(function () { ctrl.abort(); }, 6000);
                }
                fetch(origin + '/login?next=close', opts).then(function () {
                    if (timer) { clearTimeout(timer); }
                    done(true);
                }).catch(function () {
                    if (timer) { clearTimeout(timer); }
                    done(false);
                });
            };

            window.__ulCompleteSignIn = window.__ulCompleteSignIn || function (done) {
                fetch('/api/auth/from-account', {
                    method: 'POST',
                    credentials: 'same-origin',
                    headers: { 'Content-Type': 'application/json' },
                    body: '{}'
                }).then(function (response) {
                    if (!response.ok) { throw new Error('account exchange failed'); }
                    done();
                }).catch(function () {
                    var box = document.getElementById('ul-auth-error');
                    if (!box) {
                        box = document.createElement('div');
                        box.id = 'ul-auth-error';
                        box.setAttribute('role', 'alert');
                        box.style.cssText = 'position:fixed;left:50%;bottom:1rem;transform:translateX(-50%);z-index:9999;max-width:90vw;padding:0.75rem 1rem;border-radius:0.75rem;background:hsl(var(--destructive));color:white;font-size:0.9rem;';
                        document.body.appendChild(box);
                    }
                    box.textContent = 'We could not finish signing you in. Please try again.';
                });
            };
            // The static page has no dialog config; the account origin comes
            // from the iframe's own absolute src, captured before probing.
            var ulStageAccount = '';

            window.addEventListener('message', function (event) {
                if (!ulStageAccount || event.origin !== ulStageAccount) { return; }
                if (event.data && event.data.type === 'login_success') {
                    window.__ulCompleteSignIn(function () { window.location.href = '/'; });
                }
            });

            function ulInstallStageFallback() {
                var frame = document.querySelector('.ul-auth-stage iframe.wq-embed');
                var template = document.getElementById('ul-auth-fallback-template');
                if (!frame || !template) { return; }
                var original = frame.getAttribute('src') || '';
                try { ulStageAccount = new URL(original, window.location.href).origin; } catch (e) { ulStageAccount = ''; }
                if (!ulStageAccount) { return; }
                // Stop the frame before it can paint a connection-error page.
                frame.setAttribute('src', 'about:blank');
                var panel = null;
                function showFallback() {
                    frame.hidden = true;
                    if (panel) { panel.hidden = false; return; }
                    panel = template.cloneNode(true);
                    panel.id = 'ul-auth-fallback';
                    panel.className = 'ul-auth-fallback';
                    panel.removeAttribute('hidden');
                    var retry = panel.querySelector('.ul-auth-retry');
                    if (retry) {
                        retry.addEventListener('click', function () {
                            panel.hidden = true;
                            window.__ulAuthProbe(ulStageAccount, function (ok) {
                                if (ok) { frame.hidden = false; frame.setAttribute('src', original); }
                                else { panel.hidden = false; }
                            });
                        });
                    }
                    frame.parentNode.appendChild(panel);
                }
                window.__ulAuthProbe(ulStageAccount, function (ok) {
                    if (ok) { frame.setAttribute('src', original); }
                    else { showFallback(); }
                });
            }
            // On the embedded auth page this script can be emitted after
            // DOMContentLoaded has already fired. A bare listener then never
            // runs, leaving the iframe on about:blank with no fallback panel.
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', ulInstallStageFallback);
            } else {
                ulInstallStageFallback();
            }
        }
        #css {
            .ul-auth-fallback { padding: 1.5rem 1rem; border: 1px solid hsl(var(--border)); border-radius: var(--radius); background: hsl(var(--card)); text-align: center; }
            .ul-auth-fallback-text { margin: 0 0 1rem; color: hsl(var(--foreground)); font-size: 0.95rem; line-height: 1.6; }
            .ul-auth-retry { min-height: 2.75rem; padding: 0.6rem 1.1rem; border: 1px solid hsl(var(--primary)); border-radius: var(--radius); background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); font: inherit; font-weight: 600; cursor: pointer; }
            .ul-auth-frame-host[hidden], .ul-auth-fallback[hidden] { display: none; }
            .ul-auth-stage iframe[hidden] { display: none; }
        }
    }

}
