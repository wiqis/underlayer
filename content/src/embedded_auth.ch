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

                dialog.appendChild(close);
                dialog.appendChild(frame);
                document.body.appendChild(dialog);

                // A native <dialog> reports a backdrop click as a click on itself.
                dialog.addEventListener('click', function (event) {
                    if (event.target === dialog) { dialog.close(); }
                });

                var loaded = false;
                var open = function () {
                    if (!loaded) {
                        frame.setAttribute('src', account + '/login?next=close');
                        loaded = true;
                    }
                    if (dialog.showModal) { dialog.showModal(); }
                    else { dialog.setAttribute('open', 'open'); }
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
                // is the only thing that moves.
                window.addEventListener('message', function (event) {
                    if (event.data && event.data.type === 'login_success') {
                        if (dialog.open) { dialog.close(); }
                        window.location.reload();
                    }
                });
            };
            window.__ulInstallAuthDialog();
        }
        #css {
            .ul-auth-dialog { width: 28rem; max-width: calc(100vw - 2rem); max-height: 90vh; padding: 1.25rem; border: 1px solid hsl(var(--border)); border-radius: var(--radius); background: hsl(var(--card)); color: hsl(var(--card-foreground)); box-shadow: var(--shadow); }
            .ul-auth-dialog-close { position: absolute; top: 0.5rem; right: 0.75rem; border: 0; background: transparent; color: hsl(var(--muted-foreground)); font-size: 1.5rem; line-height: 1; cursor: pointer; }
            .ul-auth-dialog .wq-embed { height: 620px; max-height: 76vh; }
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
                    <div class="wq-foot">One Wiqis account signs you in to every app. <a href="/">Back to Underlayer</a></div>
                </div>
            </div>
        }
    }

    // Direct visit to /sign-in or /sign-up: the frame signs the reader in, but
    // nobody here closes a dialog, so send the TOP-LEVEL document home.
    public func render_auth_redirect_js(page : &mut HtmlPage) {
        #js {
            window.addEventListener('message', function (event) {
                if (event.data && event.data.type === 'login_success') {
                    window.location.href = '/';
                }
            });
        }
    }

}
