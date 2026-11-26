// underlayer_web — one structured request line, one request id.
//
// B1. Every response leaves through `underlayer_web::deliver` (handler routes)
// or `underlayer_web::deliver_web_request` (the `web::App` catch-all: frozen
// pages, assets, 404). Both funnel into `apply_delivery` below, which is the
// ONE place that emits the access line. Guards that used to `return refusal`
// directly now go through delivery too, so a 429 is logged like any other
// answer instead of disappearing from the operator's view.
//
// FIELDS (space-separated, no free text in the path/remote fields):
//   method path status duration_ms learner_id request_id remote
// `duration_ms` is measured from `begin_request` to the response being
// wire-ready. It covers delivery (ETag, conditional handling, gzip) and, on
// the catch-all, the frozen-page read. The handler itself runs BEFORE
// `deliver` is entered -- the upstream router has no middleware hook -- so
// this is honestly a DELIVERY duration, not a whole-request duration. The
// server library's `http::AccessEntry` has the full exchange time but carries
// neither a request id nor a learner id, so it cannot produce this line.
//
// `request_id` is echoed in `X-Request-Id`. A caller-supplied value is used
// ONLY if it is a short, plain token (no whitespace, quotes, CR/LF or
// separators): an attacker-controlled id must not be able to forge a second
// log line through a header. Otherwise a fresh 16-hex id is minted with the
// safe `osrand` path in `underlayer_core::random_hex`.
//
// `learner_id` is resolved from the same bearer/cookie token the guards use.
// It is passed in from app/main.ch (`request_db()`) rather than read from a
// new process-wide global: there is no new mutable state here. Requests that
// have no session log `-`, never a token or an email.
//
// DB failures are logged at ERROR by database/src/main.ch through
// `log_db_failure`, and every 5xx response is logged at ERROR here.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public struct RequestInfo {
        var method : string
        var path : string
        var remote : string
        var request_id : string
        var learner_id : string
        var started : std::chrono::Instant
    }

    // A header value is echoed only when it cannot alter the log line's shape.
    // 64 characters is enough for a trace id and short enough to bound the line.
    private func safe_request_id(value : &std::string_view) : bool {
        if(value.size() == 0 || value.size() > 64) { return false }
        var i : size_t = 0
        while(i < value.size()) {
            var c = value.at(i)
            var ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                     (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == ':'
            if(!ok) { return false }
            i = i + 1
        }
        return true
    }

    public func begin_request(req : &http::Request) : RequestInfo {
        var info = RequestInfo {
            method = req.method.copy(),
            path = req.path.copy(),
            remote = req.remote.copy(),
            request_id = string(),
            learner_id = string(),
            started = std::chrono::Instant.now()
        }
        var got = req.headers.get(string_view("X-Request-Id"))
        if(got is std::Option.Some) {
            var Some(value) = got else unsafe { unreachable }
            if(safe_request_id(&value)) {
                info.request_id = value.to_string()
                return info
            }
        }
        info.request_id = underlayer_core::random_hex(8)
        return info
    }

    // Resolve the learner id once, with the same helper the auth gates use.
    // `db` is the existing per-process handle handed in by app/main.ch.
    public func set_learner(info : &mut RequestInfo, db : *DbClient, req : &http::Request) {
        if(db == null) { return }
        var id = auth_get_learner_id(db, req)
        if(id.size() > 0) { info.learner_id = id }
    }

    // One log field, escaped so a path like `/a\nb` cannot inject a second line.
    private func append_field(out : &mut string, value : &std::string_view) {
        var i : size_t = 0
        while(i < value.size()) {
            var c = value.at(i)
            var code = c as i64
            if(code < 32 || code == 127 || c == ' ') { out.append('_') }
            else { out.append(c) }
            i = i + 1
        }
    }

    public func finish_request(info : &RequestInfo, res : &mut http::Response) {
        var idv = info.request_id.to_view()
        res.set_header_view(string_view("X-Request-Id"), &idv)

        var micros = info.started.elapsed().as_micros()
        if(micros < 0) { micros = 0 }
        var duration_ms = micros / 1000

        var line = string("[request] method=")
        var method_view = info.method.to_view()
        append_field(&mut line, &method_view)
        line.append_view(" path=")
        var path_view = info.path.to_view()
        append_field(&mut line, &path_view)
        line.append_view(" status=")
        line.append_integer(res.status as i64)
        line.append_view(" duration_ms=")
        line.append_integer(duration_ms)
        line.append_view(" learner_id=")
        if(info.learner_id.size() > 0) {
            var learner_view = info.learner_id.to_view()
            append_field(&mut line, &learner_view)
        } else {
            line.append('-')
        }
        line.append_view(" request_id=")
        var rid_view = info.request_id.to_view()
        append_field(&mut line, &rid_view)
        line.append_view(" remote=")
        if(info.remote.size() > 0) {
            var remote_view = info.remote.to_view()
            append_field(&mut line, &remote_view)
        } else {
            line.append('-')
        }

        if(res.status >= 500u) {
            var line_view = line.to_view()
            underlayer_core::log_error(&line_view)
        } else {
            underlayer_core::log_line(&line)
        }
    }

    // ERROR-level DB failure line. Called from database/src/main.ch where there
    // is no request in scope, so the field is explicitly `-` rather than a
    // made-up correlation id.
    public func log_db_failure(operation : &string, detail : &string) {
        var line = string("[ERROR] [db-failure] op=")
        var op_view = operation.to_view()
        append_field(&mut line, &op_view)
        line.append_view(" request_id=- detail=")
        var detail_view = detail.to_view()
        append_field(&mut line, &detail_view)
        underlayer_core::log_line(&line)
    }

}
