// underlayer_web — CSS for /search.
//
// Reuses the nav, container, button and heading rules from
// courses_index_assets.ch by including them from the same selectors rather
// than repeating them: `#search` is a sibling of `/courses` in the nav, and
// two nearly identical sheets are how the home page and the index ended up
// looking like different products.
using std::string

public namespace underlayer_web {

    public func render_search_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(217 91% 60%); text-decoration: none; }
            a:hover { text-decoration: underline; }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .navbar { background: hsl(var(--card)); border-bottom: 1px solid hsl(var(--border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--foreground)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--muted-foreground)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--foreground)); background: hsl(var(--accent)); text-decoration: none; }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
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