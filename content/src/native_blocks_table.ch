// underlayer_content — table block derivation for the native lesson contract.
//
// Kept apart from the walker so native_blocks.ch stays under the 250-line
// ceiling.  Header cells come from <thead>, rows from <tbody>, exactly as the
// lesson rendered them.  A tag name only matches at an opening-tag boundary:
// `<thead` is not a `<th>` cell, and `<th scope="col">` is one cell, not a row.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    private func nt_element_end(s : &string, lt : size_t, gt : size_t, tag : &string) : size_t {
        var close = matching_close(s, lt, tag)
        if(close == std::NPOS) { return gt + 1 }
        var ce = tag_end(s, close)
        if(ce == std::NPOS) { return gt + 1 }
        return ce + 1
    }

    private func nt_inner_of(s : &string, gt : size_t, end : size_t, tag : &string) : string {
        if(end <= gt + 1) { return string() }
        var close_len = tag.size() + 3
        if(end < close_len) { return string() }
        var inner_end = end - close_len
        if(inner_end < gt + 1) { return string() }
        return s.substring(gt + 1, inner_end)
    }

    // A `<name` hit is an opening tag only when the next character is '>',
    // '/' or whitespace.  Without this, searching for `<th>` also finds
    // `<thead>`, which is why headers used to arrive as one joined string.
    private func nt_open_at(s : &string, name : &string, from : size_t) : size_t {
        var pat = string("<")
        pat.append_string(name)
        var cursor = from
        while(true) {
            var pv = pat.to_view()
            var at = nfind(s, &pv, cursor)
            if(at == std::NPOS) { return std::NPOS }
            var after = at + pat.size()
            if(after < s.size()) {
                var c = s.at(after)
                if(c == '>' || c == '/' || nis_space(c)) { return at }
            }
            cursor = after
        }
        return std::NPOS
    }

    public func nt_cells_of(section : &string, cell_tag : &string) : vector<string> {
        var cells = vector<string>()
        var cursor : size_t = 0
        while(true) {
            var at = nt_open_at(section, cell_tag, cursor)
            if(at == std::NPOS) { break }
            var gt = tag_end(section, at)
            if(gt == std::NPOS) { break }
            var end = nt_element_end(section, at, gt, cell_tag)
            if(end <= gt + 1) { break }
            var inner = nt_inner_of(section, gt, end, cell_tag)
            var text = inline_text(&inner)
            cells.push(ntrim(&text))
            cursor = end
        }
        return cells
    }

    private func nt_section_of(table : &string, name : &string) : string {
        var at = nt_open_at(table, name, 0)
        if(at == std::NPOS) { return string() }
        var gt = tag_end(table, at)
        if(gt == std::NPOS) { return string() }
        var end = nt_element_end(table, at, gt, name)
        if(end <= at) { return string() }
        return table.substring(at, end)
    }

    public func block_table(fragment : &string) : string {
        var thead = nt_section_of(fragment, string("thead"))
        var tbody = nt_section_of(fragment, string("tbody"))
        // Without a wrapper, scan the table itself.  This still finds real
        // `<th>` / `<tr>` cells; it never turns `<td>` data into a header.
        if(thead.size() == 0) { thead = fragment.copy() }
        if(tbody.size() == 0) { tbody = fragment.copy() }
        // One JSON string per `<th>` cell.  No `<th>` means no headers — never
        // a synthesized one.  inline_text decoded entities; jquote escapes
        // with the product's single json_escape, once.
        var headers = nt_cells_of(&thead, string("th"))
        var hs = jstring_array(&headers)
        var rows = vector<string>()
        var cursor : size_t = 0
        var tr = string("tr")
        while(true) {
            var at = nt_open_at(&tbody, &tr, cursor)
            if(at == std::NPOS) { break }
            var gt = tag_end(&tbody, at)
            if(gt == std::NPOS) { break }
            var end = nt_element_end(&tbody, at, gt, &tr)
            if(end <= gt + 1) { break }
            // One JSON array per `<tr>`, of its `<td>` cell strings.  The old
            // code wrapped each row a second time (rows of rows) — removed.
            // A row with no `<td>` cells is not a data row; skip it rather
            // than emitting padding.
            var row = tbody.substring(at, end)
            var cells = nt_cells_of(&row, string("td"))
            if(cells.size() == 0) { cursor = end; continue }
            rows.push(jstring_array(&cells))
            cursor = end
        }
        var rs = jarray(&rows)
        var out = string("{\"type\":\"table\",\"headers\":")
        out.append_string(&hs)
        out.append_view(",\"rows\":")
        out.append_string(&rs)
        out.append('}')
        return out
    }
}
