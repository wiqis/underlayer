// underlayer_content — the strip's styles.
//
// Its own tokens, for the same reason lesson_nav.ch has its own: the css_cbi
// pipeline silently drops the second argument of var(), so
// `hsl(var(--card, 0 0% 100%))` emits as `hsl(var(--card))` and the colours
// are invalid on a page that has no theme -- which is every lesson page.  See
// the header comment in lesson_nav.ch, which measured it.
public namespace underlayer_content {

    public func render_lesson_engagement_css(page : &mut HtmlPage) {
        #css {
            .ul-progress { max-width: 820px; margin: 1rem auto 0; padding: 0.75rem 1rem; border: 1px solid hsl(220 11% 89%); border-radius: 8px; background: hsl(0 0% 100%); font-family: system-ui, -apple-system, sans-serif; }
            .ul-progress[hidden] { display: none; }
            .ul-progress-bar { height: 4px; background: hsl(220 11% 92%); border-radius: 9999px; overflow: hidden; margin-bottom: 0.6rem; }
            .ul-progress-fill { height: 100%; width: 0%; background: hsl(217 91% 60%); border-radius: 9999px; transition: width 0.3s; }
            .ul-progress-row { display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap; font-size: 0.85rem; color: hsl(220 9% 46%); }
            .ul-progress-where { font-weight: 600; color: hsl(221 39% 11%); }
            .ul-progress-state { padding: 0.1rem 0.5rem; border-radius: 9999px; border: 1px solid hsl(220 11% 89%); background: hsl(220 14% 96%); }
            .ul-progress-state.logged { border-color: hsl(142 71% 45%); background: hsl(142 76% 96%); color: hsl(142 72% 29%); }
            .ul-progress-state.due { border-color: hsl(38 92% 50%); background: hsl(48 96% 89%); color: hsl(25 95% 35%); }
            .ul-progress-state.mastered { border-color: hsl(217 91% 60%); background: hsl(214 95% 93%); color: hsl(221 83% 33%); }
            .ul-progress-nav { margin-left: auto; display: flex; gap: 0.5rem; }
            .ul-step { padding: 0.25rem 0.7rem; border: 1px solid hsl(220 11% 89%); border-radius: 6px; color: hsl(221 39% 11%); text-decoration: none; font-size: 0.8rem; font-weight: 600; background: hsl(0 0% 100%); }
            .ul-step[hidden] { display: none; }
            .ul-step:hover { background: hsl(220 14% 96%); text-decoration: none; }
            @media (max-width: 640px) { .ul-progress { margin: 0.5rem 1rem 0 auto; } .ul-progress-nav { margin-left: 0; } }
        }
    }

}