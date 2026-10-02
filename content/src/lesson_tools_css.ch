// underlayer_content — the tools row's styles.
//
// Its own tokens, for the same compiler-bug reason lesson_nav.ch and
// lesson_engagement_css.ch carry their own: css_cbi silently drops the second
// argument of var(), so `hsl(var(--card, 0 0% 100%))` emits as
// `hsl(var(--card))` and every colour on it is invalid on a page with no
// components theme -- which is every lesson page.  See the header comment in
// lesson_nav.ch, which measured it.
public namespace underlayer_content {

    public func render_lesson_tools_css(page : &mut HtmlPage) {
        #css {
            .ul-tools { max-width: 820px; margin: 0.5rem auto 0; padding: 0.5rem 1rem; border: 1px solid hsl(220 11% 89%); border-radius: 8px; background: hsl(0 0% 100%); font-family: system-ui, -apple-system, sans-serif; font-size: 0.85rem; color: hsl(220 9% 46%); }
            .ul-tools[hidden] { display: none; }
            .ul-tools-standing { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
            .ul-tools-standing:empty { display: none; }
            .ul-tools-actions { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; margin-top: 0.5rem; }
            .ul-tools-actions[hidden] { display: none; }
            .ul-chip { padding: 0.15rem 0.55rem; border-radius: 9999px; border: 1px solid hsl(220 11% 89%); background: hsl(220 14% 96%); color: hsl(221 39% 11%); font-size: 0.78rem; font-weight: 600; }
            .ul-chip[hidden] { display: none; }
            .ul-chip.streak { border-color: hsl(25 95% 60%); background: hsl(24 95% 93%); color: hsl(21 90% 32%); }
            .ul-chip.achieved { border-color: hsl(142 71% 45%); background: hsl(142 76% 96%); color: hsl(142 72% 29%); }
            .ul-chip-link { text-decoration: none; }
            .ul-chip-link:hover { text-decoration: underline; }
            .ul-tool { font: inherit; padding: 0.3rem 0.7rem; border: 1px solid hsl(220 11% 89%); border-radius: 6px; background: hsl(0 0% 100%); color: hsl(221 39% 11%); cursor: pointer; font-weight: 600; }
            .ul-tool:hover { background: hsl(220 14% 96%); }
            .ul-tool-on { border-color: hsl(217 91% 60%); background: hsl(214 95% 93%); color: hsl(221 83% 33%); }
            .ul-tool-primary { border-color: hsl(217 91% 60%); background: hsl(217 91% 60%); color: hsl(0 0% 100%); }
            .ul-tool-primary:hover { background: hsl(217 91% 55%); }
            .ul-tools-offline { margin: 0.4rem 0 0; font-size: 0.8rem; color: hsl(220 9% 46%); }
            .ul-tools-offline[hidden] { display: none; }
            .ul-panel { margin-top: 0.6rem; padding-top: 0.6rem; border-top: 1px solid hsl(220 11% 89%); }
            .ul-panel[hidden] { display: none; }
            .ul-panel-label { display: block; font-size: 0.78rem; font-weight: 600; color: hsl(221 39% 11%); margin-bottom: 0.25rem; }
            .ul-field { width: 100%; box-sizing: border-box; padding: 0.5rem; border: 1px solid hsl(220 11% 89%); border-radius: 6px; font: inherit; background: hsl(0 0% 100%); color: hsl(221 39% 11%); resize: vertical; }
            .ul-panel-row { display: flex; align-items: center; gap: 0.6rem; flex-wrap: wrap; margin-top: 0.5rem; }
            .ul-panel-state { font-size: 0.8rem; }
            .ul-panel-state.saved { color: hsl(142 72% 29%); }
            .ul-panel-state.failed { color: hsl(0 72% 45%); }
            .ul-note-list { list-style: none; margin: 0.6rem 0 0; padding: 0; display: flex; flex-direction: column; gap: 0.4rem; }
            .ul-note-item { display: flex; align-items: flex-start; gap: 0.5rem; padding: 0.4rem 0.5rem; border: 1px solid hsl(220 11% 89%); border-radius: 6px; background: hsl(220 14% 96%); }
            .ul-note-text-body { flex: 1 1 auto; white-space: pre-wrap; word-break: break-word; color: hsl(221 39% 11%); }
            .ul-note-edit, .ul-note-delete { font: inherit; font-size: 0.75rem; padding: 0.1rem 0.4rem; border: 1px solid hsl(220 11% 89%); border-radius: 4px; background: hsl(0 0% 100%); color: hsl(221 39% 11%); cursor: pointer; }
            .ul-note-delete { color: hsl(0 72% 45%); }
            @media (max-width: 640px) { .ul-tools { margin: 0.4rem 1rem 0 auto; } }
        }
    }

}