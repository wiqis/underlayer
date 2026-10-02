// underlayer_web — CSS and JS for /courses and /learning-path.
//
// THE NAV IS NOT HERE ANY MORE.  `.skip-link`, `.navbar`, `.nav-inner`,
// `.nav-brand`, `.nav-links`, `.nav-link`, `.nav-right`, `.theme-toggle` and
// the three `.theme-icon-*` rules used to sit in this file, and in
// search_assets.ch beside it -- two copies of one nav in two sheets, with the
// 398 lesson pages having neither.  They belong to the nav component
// (content/src/lesson_nav.ch), which renders the markup, so it renders the
// styles too: a page that draws the nav can no longer draw it unstyled, and
// there is one stylesheet for it rather than three.
//
// The card treatment is copied from the home page's course grid in
// home_assets.ch (.course-card, .course-badge, .course-stats, .btn-primary)
// rather than reinvented: this page is the same collection rendered one level
// down, and two card styles would make the home page and the index look like
// two products.
using std::string

public namespace underlayer_web {

    public func render_index_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(217 91% 60%); text-decoration: none; }
            a:hover { text-decoration: underline; }
            :focus-visible { outline: 2px solid hsl(217 91% 60%); outline-offset: 2px; }
            .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
            .page-head h1 { font-size: 2rem; margin-bottom: 0.5rem; }
            .lede { color: hsl(var(--muted-foreground)); font-size: 1.05rem; max-width: 70ch; }
            .tally { color: hsl(var(--muted-foreground)); font-size: 0.9rem; border-left: 3px solid hsl(217 91% 60%); padding-left: 0.75rem; }
            h2 { font-size: 1.5rem; margin-bottom: 0.5rem; }
            .section-note { color: hsl(var(--muted-foreground)); font-size: 0.95rem; max-width: 75ch; margin-bottom: 1.5rem; }
            .route-grid { display: grid; gap: 1.5rem; margin-bottom: 1.5rem; }
            .route-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .route-card:target { border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .route-title { font-size: 1.2rem; margin: 0 0 0.25rem; }
            .route-tagline { color: hsl(217 91% 60%); font-size: 0.9rem; font-weight: 600; margin: 0 0 0.5rem; }
            .route-blurb { color: hsl(var(--muted-foreground)); font-size: 0.95rem; margin: 0 0 1.25rem; max-width: 80ch; }
            .route-steps { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.75rem; }
            .route-step { border-left: 3px solid hsl(var(--border)); padding: 0.25rem 0 0.25rem 1rem; }
            .step-head { display: flex; align-items: baseline; gap: 0.6rem; }
            .step-num { background: hsl(217 91% 60% / 12%); color: hsl(217 91% 60%); border-radius: 9999px; min-width: 1.8rem; height: 1.8rem; display: inline-flex; align-items: center; justify-content: center; font-size: 0.85rem; font-weight: 700; }
            .step-course { font-weight: 600; font-size: 1rem; }
            .step-course.step-missing { color: hsl(0 70% 55%); }
            .step-why { margin: 0.35rem 0 0.4rem; color: hsl(var(--foreground)); font-size: 0.92rem; max-width: 85ch; }
            .step-meta { display: flex; flex-wrap: wrap; gap: 0.75rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .stat-diff { text-transform: capitalize; }
            .stat-imp { text-transform: capitalize; }
            .stat-missing { color: hsl(0 70% 55%); }
            .step-prereqs { margin-top: 0.4rem; font-size: 0.78rem; display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem; }
            .prereq-label { color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.04em; font-size: 0.7rem; }
            .prereq { background: hsl(var(--accent)); color: hsl(var(--foreground)); border-radius: 6px; padding: 0.1rem 0.4rem; }
            .prereq-none { color: hsl(var(--muted-foreground)); }
            .route-check { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 3px solid hsl(217 91% 60%); border-radius: 8px; padding: 1rem 1.25rem; margin-bottom: 1.5rem; font-size: 0.9rem; }
            .route-check p { margin: 0.2rem 0; }
            .check-ok { color: hsl(152 60% 36%); }
            .check-bad { color: hsl(0 70% 55%); font-weight: 600; }
            .check-list { margin: 0.25rem 0 0 1.25rem; color: hsl(0 70% 55%); }
            .orphan-note { border: 1px dashed hsl(var(--border)); border-radius: 12px; padding: 1.5rem; }
            .orphan-note h3 { margin-top: 0; font-size: 1.05rem; }
            .orphan-note p { color: hsl(var(--muted-foreground)); font-size: 0.9rem; max-width: 80ch; }
            .orphan-row { display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.75rem; padding: 0.5rem 0; border-top: 1px solid hsl(var(--border)); font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .orphan-row a { font-weight: 600; font-size: 0.95rem; }
            .catalogue { margin-top: 3rem; }
            .catalogue-head { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
            .expand-all { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); color: hsl(var(--foreground)); border-radius: 8px; padding: 0.45rem 0.9rem; font-size: 0.85rem; cursor: pointer; }
            .expand-all:hover { border-color: hsl(217 91% 60%); color: hsl(217 91% 60%); }
            .course-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 1.25rem; }
            .course-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; display: flex; flex-direction: column; }
            .course-card:hover { box-shadow: 0 4px 12px hsl(var(--shadow)); }
            .course-badge { align-self: flex-start; padding: 0.2rem 0.7rem; background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); border-radius: 9999px; font-size: 0.78rem; font-weight: 500; margin-bottom: 0.75rem; }
            .course-card h3 { font-size: 1.1rem; margin: 0 0 0.4rem; }
            .course-desc { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 0.75rem; flex: 1; }
            .course-stats { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 0.75rem; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .route-line { font-size: 0.82rem; margin: 0 0 0.2rem; color: hsl(var(--muted-foreground)); }
            .route-line .route-name { color: hsl(217 91% 60%); font-weight: 600; }
            .route-none { font-style: italic; }
            .route-why { font-size: 0.85rem; margin: 0 0 0.75rem; max-width: 60ch; }
            .concepts { border-top: 1px solid hsl(var(--border)); padding-top: 0.6rem; }
            .concepts summary { cursor: pointer; font-size: 0.85rem; font-weight: 600; color: hsl(217 91% 60%); }
            .concept-list { list-style: none; margin: 0.6rem 0 0; padding: 0; display: grid; gap: 0.3rem; max-height: 22rem; overflow-y: auto; }
            .concept-item { font-size: 0.85rem; }
            .btn { display: inline-block; padding: 0.6rem 1.25rem; border-radius: 8px; font-weight: 500; font-size: 0.9rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); text-decoration: none; }
            @media (max-width: 900px) { .course-grid { grid-template-columns: 1fr; } .container { padding: 1rem; } }
        }
    }

    public func render_index_js(page : &mut HtmlPage) {
        // The theme script is NOT called here any more: render_nav_bar emits
        // it, because the theme toggle belongs to the nav rather than to this
        // page, and calling it in both places shipped it twice.
        #js {
            // Expand-all is a toggle over every <details>, so a learner who
            // wants the whole catalogue open gets it in one click and can put
            // it back.  The button label follows the state rather than
            // assuming it, which is the difference between a control and a
            // decoration.
            function toggleAllConcepts() {
                var boxes = document.querySelectorAll('.concepts');
                if (boxes.length === 0) return;
                var anyClosed = false;
                boxes.forEach(function(b) { if (!b.open) { anyClosed = true; } });
                boxes.forEach(function(b) { b.open = anyClosed; });
                var btn = document.querySelector('.expand-all');
                if (btn) { btn.textContent = anyClosed ? 'Collapse all concepts' : 'Expand all concepts'; }
            }
        }
    }

}