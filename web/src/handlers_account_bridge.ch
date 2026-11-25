// underlayer_web — THE SHARED-ACCOUNT BRIDGE.
//
// POST /api/auth/from-account exchanges a credential from `account.wiqis.com`
// for an Underlayer session, WITHOUT ever collecting a Wiqis password here and
// WITHOUT storing any learning data on the account service.
//
// TWO CALLERS, ONE SHAPE:
//   * the BROWSER sends the shared `refresh_token` cookie it received from the
//     account iframe.  We validate it with GET /api/me.
//   * the ANDROID client sends `Authorization: Bearer <account access_token>`.
//     We validate it with POST /v1/token/check, then read the stable id with
//     POST /v1/account/info.  The token is the same opaque value as the refresh
//     token; this is the /v1 compat contract from Web/account.
//
// The account service is asked for IDENTITY ONLY.  Progress, FSRS state and
// notes are written to Underlayer's own database by the existing session code.
// The local session is minted by `create_session` and the cookie set by
// `set_session_cookie` — the same helpers /api/auth/login uses, so a browser
// that arrives through this route is signed in exactly like one that logged in
// locally.  The legacy /api/auth/login|register handlers remain for Android.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // An Authorization header is authoritative: a malformed one must NOT fall
    // back to a cookie, or a stale browser cookie could silently override the
    // credential the caller actually sent.
    private func account_bearer(req : &http::Request) : string {
        var got = req.headers.get("Authorization")
        if(got is std::Option.None) { return string() }
        var Some(value) = got else return string()
        if(value.size() < 8) { return string() }
        var ok = value.at(0) == 'B' && value.at(1) == 'e' && value.at(2) == 'a' && value.at(3) == 'r' && value.at(4) == 'e' && value.at(5) == 'r' && value.at(6) == ' '
        if(!ok) { return string() }
        var out = string()
        var i : size_t = 7
        while(i < value.size()) { out.append(value.at(i)); i = i + 1 }
        return out
    }

    private func account_refresh_cookie(req : &http::Request) : string {
        var jar = http::CookieJar.of(req)
        var got = jar.get(string_view("refresh_token"))
        if(got is std::Option.None) { return string() }
        var Some(value) = got else return string()
        var out = string()
        out.append_view(&value)
        return out
    }

    // One outbound call.  `bearer` and `cookie` are mutually exclusive: the
    // mobile path sends a bearer, the browser path forwards the account cookie.
    // A POST gets an explicit empty body so Content-Length is always present.
    private func account_call(method : *char, path : string_view, bearer : &string, cookie : &string) : string {
        var account = underlayer_core::account_url()
        var url = string()
        url.append_view(account.to_view())
        url.append_view(&path)
        var parsed = http::URL::parse(url.to_view())
        if(parsed is std::Option.None) { return string() }
        var Some(u) = parsed else unsafe { unreachable }
        var rb = http::RequestBuilder(method, std::replace(&mut u, http::URL()))
        if(bearer.size() > 0) {
            var auth = string("Bearer ")
            auth.append_string(bearer)
            var av = auth.to_view()
            rb.header_view(string_view("Authorization"), &av)
        }
        if(cookie.size() > 0) {
            var ck = string("refresh_token=")
            ck.append_string(cookie)
            var cv = ck.to_view()
            rb.header_view(string_view("Cookie"), &cv)
        }
        var empty = string_view("")
        rb.set_body(&empty, "application/json")
        var client = http::Client()
        var result = client.request(&rb)
        if(result is std::Result.Err) { return string() }
        var Ok(resp) = result else unsafe { unreachable }
        var body_opt = resp.body.text()
        if(body_opt is std::Option.None) { return string() }
        var Some(body) = body_opt else unsafe { unreachable }
        return body.to_string()
    }

    // The response id is the KEY.  `id` (the /v1 UserInfo shape) and `user_id`
    // are both accepted; email is never used, because it can be changed on the
    // account service and would then create a second learner here.
    private func identity_id(obj : &JsonValue) : string {
        var id = json_get_str_or_num(obj, "id")
        if(id.size() > 0) { return id }
        return json_get_str_or_num(obj, "user_id")
    }

    public func handle_from_account(db : *DbClient, req : &http::Request) : http::Response {
        var bearer_token = account_bearer(req)
        var cookie_token = account_refresh_cookie(req)
        if(bearer_token.empty() && cookie_token.empty()) {
            var err = string("account credentials required")
            return send_error(401u, &err)
        }

        var stable_id = string()
        var display_name = string()
        if(bearer_token.size() > 0) {
            // MOBILE: token/check first — an unparseable or expired token must
            // never reach the identity lookup and become a shadow learner.
            var check_body = account_call("POST", string_view("/v1/token/check"), &bearer_token, &cookie_token)
            if(check_body.empty()) {
                var err = string("account token check failed")
                return send_error(502u, &err)
            }
            var check_parsed = json::parse(check_body.to_view())
            if(check_parsed is std::Result.Err) {
                var err = string("invalid account token check response")
                return send_error(502u, &err)
            }
            var Ok(check) = check_parsed else unsafe { unreachable }
            if(!json_get_bool(&check, "success")) {
                var err = string("account token rejected")
                return send_error(401u, &err)
            }
            var info_body = account_call("POST", string_view("/v1/account/info"), &bearer_token, &cookie_token)
            var info_parsed = json::parse(info_body.to_view())
            if(info_parsed is std::Result.Err) {
                var err = string("invalid account info response")
                return send_error(502u, &err)
            }
            var Ok(info) = info_parsed else unsafe { unreachable }
            stable_id = identity_id(&info)
            display_name = json_get_str(&info, "name")
        } else {
            // BROWSER: the cookie is HttpOnly on the account origin; the iframe
            // made it available to that service, and we forward it for /api/me.
            var me_body = account_call("GET", string_view("/api/me"), &bearer_token, &cookie_token)
            var me_parsed = json::parse(me_body.to_view())
            if(me_parsed is std::Result.Err) {
                var err = string("invalid account session response")
                return send_error(502u, &err)
            }
            var Ok(me) = me_parsed else unsafe { unreachable }
            if(!json_get_bool(&me, "logged_in")) {
                var err = string("account session not signed in")
                return send_error(401u, &err)
            }
            var user_opt = json_get(&me, "user")
            if(user_opt is std::Option.Some) {
                var Some(user) = user_opt else unsafe { unreachable }
                stable_id = identity_id(user)
                display_name = json_get_str(user, "name")
            }
            // /api/me's web shape carries no id.  The same opaque value is a
            // valid bearer for /v1/account/info, which does return `id`; ask
            // there rather than keying a learner on a changeable email.
            if(stable_id.empty()) {
                var info_body = account_call("POST", string_view("/v1/account/info"), &cookie_token, &cookie_token)
                var info_parsed = json::parse(info_body.to_view())
                if(info_parsed is std::Result.Err) {
                    var err = string("invalid account info response")
                    return send_error(502u, &err)
                }
                var Ok(info) = info_parsed else unsafe { unreachable }
                stable_id = identity_id(&info)
                if(display_name.empty()) { display_name = json_get_str(&info, "name") }
            }
        }

        if(stable_id.empty()) {
            var err = string("account response has no stable user id")
            return send_error(502u, &err)
        }

        var learner_id = underlayer_repository::find_or_create_shadow_learner(db, &stable_id, &display_name)
        if(learner_id.empty()) {
            var err = string("could not create the local learner")
            return send_error(500u, &err)
        }
        var token = create_session(db, &learner_id)
        if(token.empty()) {
            var err = string("could not create the local session")
            return send_error(500u, &err)
        }
        var body = string("{\"learner_id\":\"")
        var lid_s = underlayer_repository::sql_escape(&learner_id)
        var tok_s = underlayer_repository::sql_escape(&token)
        body.append_string(&lid_s)
        body.append_view("\",\"session_token\":\"")
        body.append_string(&tok_s)
        body.append_view("\"}")
        var res = send_json_str(&body)
        set_session_cookie(&mut res, req, &token)
        return res
    }

}
