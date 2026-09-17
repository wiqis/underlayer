// HTML escaping for server-side string interpolation into #html blocks.
// The html_cbi {string} interpolation is raw (no auto-escaping), so any
// course-derived string placed into markup must pass through this first.
public namespace underlayer_core {

    public func html_escape(s : &std::string) : std::string {
        var out = std::string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.get(i)
            if(c == '&') { out.append_view(std::string_view("&amp;")) }
            else if(c == '<') { out.append_view(std::string_view("&lt;")) }
            else if(c == '>') { out.append_view(std::string_view("&gt;")) }
            else if(c == '"') { out.append_view(std::string_view("&quot;")) }
            else if(c == '\'') { out.append_view(std::string_view("&#39;")) }
            else { out.append(c) }
            i = i + 1
        }
        return out
    }

}
