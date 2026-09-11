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
        var v = getenv(name)
        if(v == null) { return std::string() }
        var view = std::string_view(v)
        if(view.empty()) { return std::string() }
        return view.to_string()
    }

    public func get_env_uint(name : *char, default_val : uint) : uint {
        var v = getenv(name)
        if(v == null) { return default_val }
        var view = std::string_view(v)
        if(view.empty()) { return default_val }
        var result : uint = 0u
        var i : size_t = 0
        while(i < view.size()) {
            var c = view.get(i)
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
            var c = s.get(i)
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
            result.append(digits.get(i))
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
            result.append(digits.get(i))
        }
        return result
    }

    // ---- Logging ----
    public func log_info(msg : &std::string_view) {
        printf("[INFO] %.*s\n", msg.size() as int, msg.data())
    }

    public func log_error(msg : &std::string_view) {
        printf("[ERROR] %.*s\n", msg.size() as int, msg.data())
    }

    // ---- Current timestamp (seconds since epoch) ----
    public func current_timestamp() : i64 {
        return time(null) as i64
    }

    // ---- Path helpers ----
    public func path_segments(path : &std::string_view) : std::vector<std::string_view> {
        var segments = std::vector<std::string_view>()
        var start : size_t = 0
        var i : size_t = 0
        while(i < path.size()) {
            var c = path.get(i)
            if(c == '/') {
                if(i > start) {
                    // Build a string_view from start to i
                    var j : size_t = start
                    var seg = std::string()
                    while(j < i) {
                        seg.append(path.get(j))
                        j = j + 1
                    }
                    segments.push(seg.to_view())
                }
                start = i + 1
            }
            i = i + 1
        }
        if(start < path.size()) {
            var j : size_t = start
            var seg = std::string()
            while(j < path.size()) {
                seg.append(path.get(j))
                j = j + 1
            }
            segments.push(seg.to_view())
        }
        return segments
    }

    // ---- JSON helpers ----
    public func json_escape(s : &std::string_view) : std::string {
        var out = std::string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.get(i)
            if(c == '"') { out.append_view(std::string_view("\\\"")) }
            else if(c == '\\') { out.append_view(std::string_view("\\\\")) }
            else if(c == '\n') { out.append_view(std::string_view("\\n")) }
            else if(c == '\r') { out.append_view(std::string_view("\\r")) }
            else if(c == '\t') { out.append_view(std::string_view("\\t")) }
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
}
