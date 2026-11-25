// underlayer_core — config, logging, string/time utilities
public namespace underlayer_core {

    // ---- AppConfig ----
    public struct AppConfig {
        var port : uint
        var db_url : std::string
        var db_token : std::string
        var courses_dir : std::string

        @make
        func make() : AppConfig {
            return AppConfig {
                port = 9000u,
                db_url = std::string("./underlayer.db"),
                db_token = std::string(),
                courses_dir = std::string("./courses")
            }
        }
    }

    // ---- Env helpers ----
    public func get_env_str(name : *char) : std::string {
        var v = unsafe(getenv(name))
        if(v == null) { return std::string() }
        var view = unsafe(std::string_view(v))
        if(view.empty()) { return std::string() }
        return view.to_string()
    }

    public func get_env_uint(name : *char, default_val : uint) : uint {
        var v = unsafe(getenv(name))
        if(v == null) { return default_val }
        var view = unsafe(std::string_view(v))
        if(view.empty()) { return default_val }
        var result : uint = 0u
        var i : size_t = 0
        while(i < view.size()) {
            var c = view.at(i)
            if(c >= '0' && c <= '9') {
                result = result * 10u + (c as uint - 48u)
            }
            i = i + 1
        }
        if(result == 0u) { return default_val }
        return result
    }

    // ---- Load config from env ----
    public func load_config() : AppConfig {
        var cfg = AppConfig::make()
        var port_str = get_env_str("PORT")
        if(!port_str.empty()) { cfg.port = parse_uint(port_str.to_view()) }
        var db_url = get_env_str("DATABASE_URL")
        if(!db_url.empty()) { cfg.db_url = db_url }
        var db_token = get_env_str("DATABASE_TOKEN")
        if(!db_token.empty()) { cfg.db_token = db_token }
        var courses_dir = get_env_str("COURSES_DIR")
        if(!courses_dir.empty()) { cfg.courses_dir = courses_dir }
        return cfg
    }

    // ---- String utilities ----
    public func parse_uint(s : &std::string_view) : uint {
        var result : uint = 0u
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c >= '0' && c <= '9') {
                result = result * 10u + (c as uint - 48u)
            }
            i = i + 1
        }
        return result
    }

    public func int_to_string(v : i64) : std::string {
        if(v == 0) { return std::string("0") }
        var negative = false
        var n = v
        if(n < 0) { negative = true; n = -n }
        var digits = std::string()
        while(n > 0) {
            var d = (n % 10) as i64
            if(d < 0) { d = -d }
            digits.append((d + 48) as char)
            n = n / 10
        }
        if(negative) { digits.append('-') }
        var result = std::string()
        var i : size_t = digits.size()
        while(i > 0) {
            i = i - 1
            result.append(digits.at(i))
        }
        return result
    }

    public func u32_to_string(v : uint) : std::string {
        if(v == 0u) { return std::string("0") }
        var digits = std::string()
        var n = v
        while(n > 0u) {
            var d = n % 10u
            digits.append((d + 48u) as char)
            n = n / 10u
        }
        var result = std::string()
        var i : size_t = digits.size()
        while(i > 0) {
            i = i - 1
            result.append(digits.at(i))
        }
        return result
    }

    // ---- Logging ----
    public func log_info(msg : &std::string_view) {
        var line = std::string()
        line.append_view(msg)
        println(`[INFO] ${line}`)
    }

    public func log_error(msg : &std::string_view) {
        var line = std::string()
        line.append_view(msg)
        println(`[ERROR] ${line}`)
    }

    // A diagnostic line already built as a string. `println` is a comptime
    // expansion whose argument has to be an expression, so it cannot be handed a
    // variable that holds the finished line; this is that expansion in one place.
    public func log_line(text : &std::string) {
        var line = std::string()
        line.append_view(text.to_view())
        println(`${line}`)
    }

    // ---- Random identifiers / hashes ----
    //
    // Every id the platform mints and every token hash it stores goes through
    // these two, so the randomness source and the digest are one decision each
    // rather than one copy per repository file.  Both use the safe library
    // entry points — `osrand::random_bytes` and `crypto::sha256` take slices and
    // return values, so nothing here holds a raw buffer.

    // `bytes` random bytes as lowercase hex.
    public func random_hex(byte_count : size_t) : std::string {
        var raw = osrand::random_bytes(byte_count)
        if(raw is std::Result.Err) { return std::string() }
        var Ok(bytes) = raw else unsafe { unreachable }
        var span : &[u8] = bytes.as_span()
        var encoded = encoding::hex_encode(span)
        if(encoded is std::Result.Err) { return std::string() }
        var Ok(hex) = encoded else unsafe { unreachable }
        return hex
    }

    // A 32-hex-character id: 16 random bytes.  What every table's primary key
    // uses.
    public func random_hex_id() : std::string {
        return random_hex(16)
    }

    // Lowercase hex SHA-256 of `text`.
    public func sha256_hex(text : &std::string_view) : std::string {
        var bytes : &[u8] = text.as_bytes()
        var digest = crypto::sha256(bytes)
        // The digest is a fixed array; `encoding::hex_encode` takes a byte
        // slice, and a local array does not convert to one implicitly, so it
        // goes through a vector. One 32-byte allocation per hash, on the
        // token/password paths only.
        var owned = std::vector<u8>()
        owned.reserve(32)
        var i : size_t = 0
        while(i < 32) {
            owned.push(digest[i])
            i = i + 1
        }
        var span : &[u8] = owned.as_span()
        var encoded = encoding::hex_encode(span)
        if(encoded is std::Result.Err) { return std::string() }
        var Ok(hex) = encoded else unsafe { unreachable }
        return hex
    }

    // ---- Current timestamp (seconds since epoch) ----
    public func current_timestamp() : i64 {
        return unsafe(time(null)) as i64
    }

    // ---- Path helpers ----
    // Returns views that point into the caller's `path` buffer. The caller must
    // keep the underlying path string alive for as long as the views are used.
    public func path_segments(path : &std::string_view) : std::vector<std::string_view> {
        var segments = std::vector<std::string_view>()
        var start : size_t = 0
        var i : size_t = 0
        while(i < path.size()) {
            var c = path.at(i)
            if(c == '/') {
                if(i > start) {
                    segments.push(path.subview(start, i))
                }
                start = i + 1
            }
            i = i + 1
        }
        if(start < path.size()) {
            segments.push(path.subview(start, path.size()))
        }
        return segments
    }

    // ---- JSON helpers ----
    public func json_escape(s : &std::string_view) : std::string {
        var out = std::string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            // `char` is signed: a UTF-8 byte such as 0xE2 is negative and must
            // NOT be treated as a control character.  Compare numerically.
            var code = c as i64
            if(c == '"') { out.append_view(std::string_view("\\\"")) }
            else if(c == '\\') { out.append_view(std::string_view("\\\\")) }
            else if(c == '\n') { out.append_view(std::string_view("\\n")) }
            else if(c == '\r') { out.append_view(std::string_view("\\r")) }
            else if(c == '\t') { out.append_view(std::string_view("\\t")) }
            else if(code >= 0 && code < 32) {
                // JSON forbids every raw C0 control, not just the four above.
                // A byte from a hex dump can be 0x01 and used to make the whole
                // emitted lesson invalid JSON.  Escape the rest as \u00XX.
                out.append('\\')
                out.append('u')
                out.append('0')
                out.append('0')
                var digits = std::string("0123456789abcdef")
                out.append(digits.at((code / 16) as size_t))
                out.append(digits.at((code % 16) as size_t))
            }
            else { out.append(c) }
            i = i + 1
        }
        return out
    }

    public func make_json_string(s : &std::string_view) : std::string {
        var out = std::string("\"")
        out.append_view(s)
        out.append('"')
        return out
    }

    // ---- Date formatting (epoch seconds -> "YYYY-MM-DD") ----
    public func date_string(timestamp : i64) : std::string {
        var secs_per_day : i64 = 86400
        var days = timestamp / secs_per_day
        // Days since 1970-01-01 (civil_from_days algorithm)
        var z = days + 719468
        var era = z
        if(era >= 0) { era = z / 146097 } else { era = (z - 146096) / 146097 }
        var doe = z - era * 146097
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        var y = yoe + era * 400
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        var mp = (5 * doy + 2) / 153
        var d = doy - (153 * mp + 2) / 5 + 1
        var m = mp
        if(m < 10) { m = m + 3 } else { m = m - 9 }
        if(m <= 2) { y = y + 1 }
        // Format as YYYY-MM-DD
        var out = std::string()
        var year_str = int_to_string(y)
        // Pad year to 4 digits
        var ypad = 4 - year_str.size()
        while(ypad > 0) { out.append('0'); ypad = ypad - 1 }
        out.append_view(year_str.to_view())
        out.append('-')
        if(m < 10) { out.append('0') }
        var m_str = int_to_string(m)
        out.append_view(m_str.to_view())
        out.append('-')
        if(d < 10) { out.append('0') }
        var d_str = int_to_string(d)
        out.append_view(d_str.to_view())
        return out
    }

    // ---- Subtract days from a date string ("YYYY-MM-DD") ----
    public func date_string_subtract_days(date : &std::string_view, days : int) : std::string {
        // Parse YYYY-MM-DD back to epoch days, subtract, reformat
        var secs_per_day : i64 = 86400
        // Parse year
        var year : i64 = 0
        var i : size_t = 0
        while(i < date.size() && date.at(i) != '-') {
            var c = date.at(i)
            if(c >= '0' && c <= '9') { year = year * 10 + (c as i64 - 48) }
            i = i + 1
        }
        i = i + 1 // skip '-'
        var month : i64 = 0
        while(i < date.size() && date.at(i) != '-') {
            var c = date.at(i)
            if(c >= '0' && c <= '9') { month = month * 10 + (c as i64 - 48) }
            i = i + 1
        }
        i = i + 1 // skip '-'
        var day : i64 = 0
        while(i < date.size()) {
            var c = date.at(i)
            if(c >= '0' && c <= '9') { day = day * 10 + (c as i64 - 48) }
            i = i + 1
        }
        // Convert to days since epoch (reverse of civil_from_days)
        var m_adj = month
        var y_adj = year
        if(m_adj <= 2) { m_adj = m_adj + 12; y_adj = y_adj - 1 }
        var epoch_days = (365 * y_adj + y_adj / 4 - y_adj / 100 + y_adj / 400 + (153 * (m_adj - 3) + 2) / 5 + day - 719468)
        epoch_days = epoch_days - (days as i64)
        return date_string(epoch_days * secs_per_day)
    }
}
