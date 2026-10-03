// underlayer_content — the nav's styles, in one place.
//
// WHY THE NAV OWNS ITS OWN `@media` RULES AND EVERY OTHER FILE OWNS NONE.
// Measured on the served HTML, 2026-10-03: seven files in web/src carried their
// own copy of the navbar stylesheet, and six of those copies ended in a rule
// that made the product unreachable on a laptop:
//
//     @media (max-width: 1300px) {
//         .nav-links { display: none; position: absolute; ... }
//         .nav-links.open { display: flex; }
//         .hamburger { display: block; }
//     }
//
// There is no `.hamburger` element in the markup and no script ever added
// `.open`, so between 769px and 1300px -- a 1280x800 laptop, the most common
// shape there is -- the entire fourteen-link nav rendered as nothing and left
// the brand and the theme toggle floating alone.  tests/src/page_html_test.ch
// called this covered: `test_home_page_has_hamburger_menu` asserts the string
// "hamburger" is in the body, and it was matching the dead CSS rule, not a
// button.  A test that passes on the absence of the thing it tests.
//
// So the responsive behaviour is HERE, next to the markup it belongs to, and
// it is written against a button that exists.  The page-level copies were
// removed; the nav is one component and it is styled once.
//
// THE `--nav-*` TOKENS, and why not the theme's.  See the header comment in
// lesson_nav.ch: css_cbi silently drops a `var(--x, fallback)` second
// argument, so a fallback would emit an undefined colour on exactly the 398
// lesson pages that have no components theme.  The tokens are therefore
// declared here on `:root` and on `.dark`, carrying the same values.
//
// THE FOCUS RING.  Every interactive element in this component gets an
// explicit `:focus-visible` ring.  The UA default ring is suppressed by
// `outline: none` in several of the page stylesheets this component is
// embedded in, and a nav whose links cannot be seen by a keyboard user is a
// nav that does not exist for them.  `outline-offset` keeps the ring off the
// text so the label stays readable while focused.
public namespace underlayer_content {

    public func render_site_nav_css(page : &mut HtmlPage) {
        #css {
            :root { --nav-card: 0 0% 100%; --nav-border: 220 11% 89%; --nav-fg: 221 39% 11%; --nav-muted: 220 9% 46%; --nav-accent: 220 14% 96%; --nav-accent-strong: 220 13% 91%; --nav-ring: 217 91% 60%; }
            .dark { --nav-card: 240 10% 3.9%; --nav-border: 240 3.7% 15.9%; --nav-fg: 0 0% 98%; --nav-muted: 240 5% 64.9%; --nav-accent: 240 3.7% 15.9%; --nav-accent-strong: 240 3.7% 20%; --nav-ring: 217 91% 70%; }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(var(--nav-ring)); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }

            .navbar { background: hsl(var(--nav-card)); border-bottom: 1px solid hsl(var(--nav-border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.5rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--nav-fg)); text-decoration: none; flex: 0 0 auto; }
            .nav-brand:hover { color: hsl(var(--nav-ring)); text-decoration: none; }

            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--nav-muted)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.7rem; border-radius: 6px; transition: color 0.15s, background-color 0.15s; white-space: nowrap; display: inline-block; cursor: pointer; }
            .nav-link:hover { color: hsl(var(--nav-fg)); background: hsl(var(--nav-accent)); text-decoration: none; }
            .nav-link.active, .nav-link[aria-current="page"] { color: hsl(var(--nav-ring)); background: hsl(var(--nav-ring) / 12%); font-weight: 600; }
            .nav-link:focus-visible, .nav-brand:focus-visible, .nav-toggle:focus-visible, .theme-toggle:focus-visible { outline: 2px solid hsl(var(--nav-ring)); outline-offset: 2px; }

            .nav-menu { position: relative; display: inline-block; }
            .nav-menu-summary { list-style: none; }
            .nav-menu-summary::-webkit-details-marker { display: none; }
            .nav-menu-summary::after { content: " \25BE"; font-size: 0.75em; opacity: 0.7; }
            .nav-menu[open] .nav-menu-summary::after { content: " \25B4"; }
            .nav-menu[data-active="true"] > .nav-menu-summary { color: hsl(var(--nav-ring)); background: hsl(var(--nav-ring) / 12%); font-weight: 600; }
            .nav-menu-panel { position: absolute; top: calc(100% + 0.35rem); right: 0; z-index: 120; min-width: 13rem; padding: 0.35rem; background: hsl(var(--nav-card)); border: 1px solid hsl(var(--nav-border)); border-radius: 10px; box-shadow: 0 10px 24px -6px rgb(0 0 0 / 0.18); display: flex; flex-direction: column; }
            .nav-menu-panel .nav-link { width: 100%; text-align: left; }
            .nav-menu-rule { height: 1px; background: hsl(var(--nav-border)); margin: 0.35rem 0.4rem; }

            .nav-right { display: flex; align-items: center; gap: 0.75rem; flex: 0 0 auto; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--nav-border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; color: inherit; }
            .theme-toggle:hover { background: hsl(var(--nav-accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }

            .nav-toggle { display: none; align-items: center; gap: 0.5rem; background: hsl(var(--nav-card)); border: 1px solid hsl(var(--nav-border)); border-radius: 8px; padding: 0.5rem 0.7rem; font-size: 0.9rem; font-weight: 600; color: hsl(var(--nav-fg)); cursor: pointer; }
            .nav-toggle-bars { display: inline-block; position: relative; width: 1rem; height: 2px; background: currentColor; box-shadow: 0 -5px 0 currentColor, 0 5px 0 currentColor; }

            @media (max-width: 860px) {
                .nav-inner { flex-wrap: nowrap; }
                .nav-toggle { display: inline-flex; order: 3; }
                .nav-links { display: none; order: 4; flex-basis: 100%; flex-direction: column; align-items: stretch; justify-content: flex-start; gap: 0.15rem; padding-top: 0.5rem; }
                .nav-links.nav-open { display: flex; }
                .nav-link { padding: 0.65rem 0.7rem; font-size: 0.95rem; }
                .nav-menu-panel { position: static; min-width: 0; border: none; box-shadow: none; padding: 0 0 0 0.75rem; margin-left: 0.5rem; border-left: 2px solid hsl(var(--nav-border)); border-radius: 0; }
                .nav-menu-summary::after { content: " \25BE"; }
                .nav-menu[open] .nav-menu-summary::after { content: " \25B4"; }
            }
            @media (max-width: 420px) {
                .nav-inner { padding: 0 1rem; }
                .nav-brand { font-size: 1.1rem; }
            }

            @media (prefers-reduced-motion: reduce) {
                .nav-link { transition: none; }
            }
        }
    }

}