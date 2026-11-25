// underlayer_web — CSS and JS for the two collection pages.
//
// Calm, one-primary-action layout.  Brand colour comes from --primary (the
// Wiqis orange token), not from a blue literal in this file.  The nav is not
// here: it is owned by content/src/lesson_nav.ch and renders its own styles.
using std::string

public namespace underlayer_web {

    public func render_index_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, sans-serif; line-height: 1.6; margin: 0; background: hsl(var(--background)); color: hsl(var(--foreground)); }
            a { color: hsl(var(--primary)); text-decoration: none; }
            a:hover { text-decoration: underline; }
            :focus-visible { outline: 2px solid hsl(var(--primary)); outline-offset: 2px; }
            .container { max-width: 1100px; margin: 0 auto; padding: 2.5rem 1.5rem; }
            .page-head { max-width: 70ch; margin-bottom: 2.5rem; }
            .page-head h1 { font-size: 2.1rem; line-height: 1.2; margin: 0 0 0.75rem; letter-spacing: -0.02em; }
            .lede { color: hsl(var(--muted-foreground)); font-size: 1.05rem; margin: 0 0 1rem; }
            .tally { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 1.5rem; }
            .btn { display: inline-block; padding: 0.7rem 1.3rem; border-radius: 8px; font-weight: 600; font-size: 0.95rem; cursor: pointer; border: none; text-decoration: none; }
            .btn-primary { background: hsl(var(--primary)); color: hsl(var(--primary-foreground)); }
            .btn-primary:hover { filter: brightness(1.06); text-decoration: none; }
            .text-link { margin-left: 0.75rem; font-size: 0.95rem; }
            .visually-hidden { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }

            /* /courses: one search, one filter row, a compact grid. */
            .catalogue-tools { display: flex; flex-wrap: wrap; align-items: center; gap: 0.75rem; margin-bottom: 1.75rem; }
            .course-search-label { font-weight: 600; font-size: 0.9rem; }
            .course-search { flex: 1 1 16rem; min-height: 2.75rem; padding: 0.6rem 0.85rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--card)); color: hsl(var(--foreground)); font-size: 0.95rem; }
            .course-filters { display: flex; flex-wrap: wrap; gap: 0.4rem; }
            .filter-chip { min-height: 2.4rem; padding: 0.35rem 0.8rem; border: 1px solid hsl(var(--border)); border-radius: 9999px; background: hsl(var(--card)); color: hsl(var(--muted-foreground)); font-size: 0.85rem; cursor: pointer; }
            .filter-chip:hover { border-color: hsl(var(--primary)); color: hsl(var(--foreground)); }
            .filter-chip.is-active { border-color: hsl(var(--primary)); background: hsl(var(--accent)); color: hsl(var(--foreground)); font-weight: 600; }
            .course-count { flex-basis: 100%; margin: 0; color: hsl(var(--muted-foreground)); font-size: 0.85rem; }
            .course-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
            .course-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 1.25rem; }
            .course-card[hidden] { display: none; }
            .course-card:hover { border-color: hsl(var(--primary)); }
            .course-card h3 { font-size: 1.1rem; margin: 0 0 0.4rem; line-height: 1.35; }
            .course-desc { color: hsl(var(--muted-foreground)); font-size: 0.9rem; margin: 0 0 0.9rem; }
            .course-stats { display: flex; flex-wrap: wrap; gap: 0.9rem; margin: 0; font-size: 0.8rem; color: hsl(var(--muted-foreground)); }
            .stat-diff { text-transform: capitalize; }

            /* /learning-path: three collapsible routes, one ordered view. */
            .route-grid { display: grid; gap: 1rem; }
            .route-card { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 0.4rem 1.25rem; }
            .route-card[open] { border-left: 4px solid hsl(var(--primary)); }
            .route-card:target { border-color: hsl(var(--primary)); }
            .route-summary { cursor: pointer; list-style: none; padding: 0.9rem 0; }
            .route-summary::-webkit-details-marker { display: none; }
            .route-summary::before { content: "+"; display: inline-block; width: 1.4rem; color: hsl(var(--primary)); font-weight: 700; }
            .route-card[open] .route-summary::before { content: "-"; }
            .route-title { font-size: 1.1rem; font-weight: 700; }
            .route-tagline { display: block; margin-left: 1.4rem; color: hsl(var(--muted-foreground)); font-size: 0.9rem; }
            .route-steps { list-style: none; margin: 0 0 0.6rem; padding: 0; display: grid; gap: 0.55rem; }
            .route-step { border-top: 1px solid hsl(var(--border)); padding: 0.85rem 0 0.35rem; }
            .step-head { display: flex; align-items: baseline; gap: 0.7rem; }
            .step-num { background: hsl(var(--accent)); color: hsl(var(--primary)); border-radius: 9999px; min-width: 1.9rem; height: 1.9rem; display: inline-flex; align-items: center; justify-content: center; font-size: 0.85rem; font-weight: 700; }
            .step-course { font-weight: 600; font-size: 1rem; }
            .step-course.step-missing { color: hsl(var(--muted-foreground)); font-style: italic; }
            .step-why { margin: 0.35rem 0 0.2rem; color: hsl(var(--foreground)); font-size: 0.92rem; max-width: 80ch; }
            .step-time { margin: 0 0 0.4rem; color: hsl(var(--muted-foreground)); font-size: 0.82rem; }
            .step-why-detail { margin: 0.35rem 0 0; }
            .step-why-detail summary { cursor: pointer; color: hsl(var(--primary)); font-size: 0.85rem; font-weight: 600; }
            .step-why-full { color: hsl(var(--muted-foreground)); font-size: 0.9rem; max-width: 80ch; margin: 0.5rem 0; }
            .step-prereqs { display: flex; flex-wrap: wrap; align-items: center; gap: 0.4rem; margin-top: 0.5rem; }
            .prereq-label { color: hsl(var(--muted-foreground)); font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.04em; }
            .prereq { background: hsl(var(--accent)); color: hsl(var(--foreground)); border-radius: 6px; padding: 0.15rem 0.5rem; font-size: 0.8rem; }
            .prereq-none { color: hsl(var(--muted-foreground)); font-size: 0.82rem; }
            .route-check { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-left: 3px solid hsl(var(--primary)); border-radius: 8px; padding: 0.9rem 1.1rem; margin-top: 1.5rem; font-size: 0.85rem; color: hsl(var(--muted-foreground)); }
            .route-check p { margin: 0.2rem 0; }
            .check-ok { color: hsl(var(--primary)); }
            .check-bad { font-weight: 600; }
            .check-list { margin: 0.25rem 0 0 1.25rem; }

            @media (max-width: 700px) {
                .container { padding: 1.25rem 1rem; }
                .course-grid { grid-template-columns: 1fr; }
            }
        }
    }

    public func render_index_js(page : &mut HtmlPage) {
        // The theme boot script belongs to the nav, not to this page.
        #js {
            function ciCourseCards() {
                var grid = document.getElementById('course-grid');
                return grid ? grid.querySelectorAll('.course-card') : [];
            }

            function ciApplyFilters() {
                var input = document.getElementById('course-search');
                var chips = document.querySelectorAll('.filter-chip');
                var count = document.getElementById('course-count');
                var query = '';
                var level = 'all';
                var i = 0;
                while(i < chips.length) {
                    if(chips[i].getAttribute('aria-pressed') === 'true') { level = chips[i].getAttribute('data-filter') || 'all'; }
                    i = i + 1;
                }
                if(input) { query = (input.value || '').toLowerCase().trim(); }
                var cards = ciCourseCards();
                var shown = 0;
                i = 0;
                while(i < cards.length) {
                    var card = cards[i];
                    var hay = (card.getAttribute('data-search') || '').toLowerCase();
                    var diff = (card.getAttribute('data-difficulty') || '').toLowerCase();
                    var fits = (query.length === 0 || hay.indexOf(query) >= 0) && (level === 'all' || diff === level);
                    if(fits) { shown = shown + 1; }
                    card.hidden = !fits;
                    i = i + 1;
                }
                if(count) { count.textContent = shown + ' of ' + cards.length + ' courses'; }
            }

            function ciInitCollection() {
                if(document.getElementById('course-search')) { ciApplyFilters(); }
                var input = document.getElementById('course-search');
                if(input) { input.addEventListener('input', ciApplyFilters); }
                var chips = document.querySelectorAll('.filter-chip');
                var i = 0;
                while(i < chips.length) {
                    chips[i].addEventListener('click', function() {
                        var all = document.querySelectorAll('.filter-chip');
                        var j = 0;
                        while(j < all.length) { all[j].setAttribute('aria-pressed', 'false'); all[j].classList.remove('is-active'); j = j + 1; }
                        this.setAttribute('aria-pressed', 'true');
                        this.classList.add('is-active');
                        ciApplyFilters();
                    });
                    i = i + 1;
                }
                var firstRoute = document.querySelector('.route-card');
                if(firstRoute && !firstRoute.open) { firstRoute.open = true; }
            }

            if(document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', ciInitCollection); }
            else { ciInitCollection(); }
        }
    }

}
