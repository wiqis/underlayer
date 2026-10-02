// underlayer_web — CSS for /search.
//
// Reuses the container, button and heading rules from courses_index_assets.ch
// by including them from the same selectors rather than repeating them:
// `#search` is a sibling of `/courses` in the nav, and two nearly identical
// sheets are how the home page and the index ended up looking like different
// products.
//
// The nav rules -- `.skip-link`, `.navbar`, `.nav-inner`, `.nav-brand`,
// `.nav-links`, `.nav-link`, `.nav-right`, `.theme-toggle`, `.theme-icon-*` --
// are not here at all.  They were, and they came out of the nav component
// (content/src/lesson_nav.ch) instead, so that one stylesheet serves this page
// and the 398 lesson pages below it.
using std::string

public namespace underlayer_web {

    public func render_search_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(217 91% 60%); text-decoration: none; }
            a:hover { text-decoration: underline; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
            .page-head h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .lede { color: hsl(var(--muted-foreground)); font-size: 1.05rem; max-width: 70ch; }
            .visually-hidden { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
            .search-form { display: flex; gap: 0.75rem; margin: 1.5rem 0 2rem; }
            .search-form input[type="search"] { flex: 1; padding: 0.8rem 1rem; font-size: 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .search-form input[type="search"]:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            .empty-state { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .empty-state p { margin: 0.35rem 0; }
            .empty-hint { color: hsl(var(--muted-foreground)); font-size: 0.9rem; max-width: 80ch; }
            .no-hits { font-size: 1rem; }
            code { background: hsl(var(--accent)); padding: 0.1rem 0.3rem; border-radius: 4px; font-size: 0.9em; }
            .result-count { color: hsl(var(--muted-foreground)); font-size: 0.95rem; margin-bottom: 0.25rem; }
            .result-truncated { color: hsl(var(--muted-foreground)); font-size: 0.85rem; margin-bottom: 1rem; }
            .result-list { list-style: none; margin: 1rem 0 0; padding: 0; display: grid; gap: 1rem; }
            .result { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.1rem 1.25rem; }
            .result:hover { box-shadow: 0 2px 10px hsl(var(--shadow)); }
            .result-head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.6rem; margin-bottom: 0.35rem; }
            .result-title { font-size: 1.05rem; font-weight: 600; }
            .result-course { color: hsl(var(--muted-foreground)); font-size: 0.85rem; }
            .result-course::before { content: "in "; }
            .result-snippet { margin: 0 0 0.5rem; font-size: 0.92rem; color: hsl(var(--foreground)); max-width: 90ch; }
            .result-meta { display: flex; flex-wrap: wrap; gap: 0.5rem; font-size: 0.78rem; color: hsl(var(--muted-foreground)); }
            .matched { background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 9999px; padding: 0.1rem 0.55rem; }
            @media (max-width: 700px) { .search-form { flex-direction: column; } .container { padding: 1rem; } }
        }
    }

}