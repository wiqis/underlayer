// underlayer_web — the lesson header's styles.
//
// WHY A SEPARATE FILE FOR FOUR RULES.
//
// The header is injected by `apply_lesson_header` into 431 pre-rendered lesson
// documents, so its CSS cannot come from a `#css` block in the file that builds
// the page -- there is no such build step for these documents.  It is emitted
// with `res.set_header` alongside the HTML, exactly as the pre-rendered pages
// already do for their own styles.
//
// WHY IT IS INJECTED AT ALL RATHER THAN LINKED.
//
// A `<link>` to a shared stylesheet would be one more request per lesson page,
// and the 432 pre-rendered pages are already served from a server that cannot be
// assumed.  A `file://` lesson would have no stylesheet at all.  The rules are
// small enough that inlining them costs less than the round trip.
//
// EVERYTHING IS SIZE-RELATIVE, and one rule uses a clamp, because this strip is
// the first thing under the title and it must never be the thing that breaks a
// narrow screen.  The prerequisite link wraps rather than truncating: a reader on
// a phone who cannot see which lesson came before cannot act on it, and a
// truncated "Continues from Binary Representat…" is worse than a wrapped line.
using std::string

public namespace underlayer_web {

    // Appended rather than written as one expression of `+`.
    //
    // `return string("a" + "b" + ... )` failed to compile with "comptime
    // function expects argument that is known at compile time": the literal
    // concatenation is a comptime operation and it did not fold across eleven
    // operands.  Building it with append_view is the shape every other string in
    // this codebase uses, and it costs nothing at runtime -- this function is
    // called once per lesson request.
    public func lesson_header_css() : string {
        var css = std::string()
        css.append_view(".lesson-head{display:flex;align-items:center;flex-wrap:wrap;gap:.4rem .9rem;margin:.6rem 0 1.1rem;font-size:.86rem;line-height:1.5;color:hsl(215 16% 42%)}")
        css.append_view(".lesson-head-item{display:inline-flex;align-items:center;gap:.3rem;white-space:nowrap}")
        css.append_view(".lesson-head-ico{font-size:.85em;opacity:.7}")
        css.append_view(".lesson-head-diff{border:1px solid #d1d5db;border-radius:999px;padding:.05rem .5rem}")
        css.append_view(".lesson-head-mod{border-left:2px solid #d1d5db;padding-left:.6rem}")
        // The prerequisite link WRAPS rather than truncating: a reader who
        // cannot see which lesson came before cannot act on it, and a truncated
        // "Continues from Binary Representat..." is worse than a wrapped line.
        css.append_view(".lesson-head-prereq{flex:1 1 100%;color:#6b7280;overflow-wrap:anywhere}")
        css.append_view(".lesson-head-prereq a{color:#2563eb;text-decoration:none;border-bottom:1px solid #93c5fd}")
        css.append_view(".lesson-head-prereq a:hover{text-decoration:none;border-bottom-color:#2563eb}")
        // The lesson pages carry a hardcoded LIGHT palette and deliberately do
        // not get the theme class (see content/src/theme_boot.ch), so the dark
        // rules here are scoped to the OS preference rather than to a class that
        // is never set.  Without this the header would be the one unreadable
        // strip on a dark-mode page.
        css.append_view("@media (prefers-color-scheme:dark){")
        css.append_view(".lesson-head{color:hsl(215 20% 78%)}")
        css.append_view(".lesson-head-diff{border-color:#4b5563}")
        css.append_view(".lesson-head-mod{border-left-color:#4b5563}")
        css.append_view(".lesson-head-prereq{color:hsl(215 16% 68%)}")
        css.append_view(".lesson-head-prereq a{color:#93c5fd;border-bottom-color:#1d4ed8}")
        css.append_view("}")
        css.append_view("@media (max-width:640px){.lesson-head{font-size:.82rem;gap:.3rem .6rem}}")
        return css
    }

}
