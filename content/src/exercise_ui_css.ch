// Shared exercise UI styles for all 8 lesson types (4.1.29).
// Included by render_lesson_css and by every ELF page's #css block.
public namespace underlayer_content {

    public func render_exercise_css(page : &mut HtmlPage) {
        #css {
            .unit-exercises { border-color: #8b5cf6; background: #f5f3ff; }
            .exercise-card { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem; margin: 0.75rem 0; }
            .exercise-card h4 { margin: 0 0 0.5rem 0; font-size: 0.95rem; }
            .exercise-option { display: block; width: 100%; padding: 0.6rem 0.9rem; margin: 0.4rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; cursor: pointer; text-align: left; font-size: 0.92rem; color: #111827; }
            .exercise-option:hover:not(:disabled) { border-color: #8b5cf6; background: #f5f3ff; }
            .exercise-option.correct { border-color: #059669; background: #ecfdf5; }
            .exercise-option.wrong { border-color: #dc2626; background: #fef2f2; }
            .exercise-option:disabled { cursor: default; }
            .exercise-option.selected { border-color: #3b82f6; background: #eff6ff; }
            .exercise-input { padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.95rem; min-width: 12rem; }
            .exercise-input:focus { outline: 2px solid #3b82f6; outline-offset: 1px; }
            .exercise-feedback { margin-top: 0.6rem; padding: 0.6rem 0.8rem; border-radius: 6px; font-size: 0.9rem; display: none; }
            .exercise-feedback.ok { display: block; background: #ecfdf5; border-left: 3px solid #059669; }
            .exercise-feedback.err { display: block; background: #fef2f2; border-left: 3px solid #dc2626; }
            .exercise-check { margin-top: 0.6rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; cursor: pointer; font-size: 0.9rem; color: #111827; }
            .exercise-check:hover:not(:disabled) { background: #f9fafb; border-color: #3b82f6; }
            .exercise-check:disabled { cursor: default; opacity: 0.7; }
            .exercise-row { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin: 0.4rem 0; }
            .exercise-multi { display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0.75rem; margin: 0.35rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; cursor: pointer; font-size: 0.92rem; }
            .exercise-multi:hover { border-color: #8b5cf6; }
            .exercise-order { list-style: none; padding: 0; margin: 0.5rem 0; }
            .exercise-order li { display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0.75rem; margin: 0.35rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; font-size: 0.92rem; }
            .exercise-order .ord-label { flex: 1; }
            .exercise-order button { padding: 0.2rem 0.55rem; border: 1px solid #d1d5db; border-radius: 4px; background: #f9fafb; cursor: pointer; font-size: 0.85rem; }
            .exercise-order button:hover:not(:disabled) { border-color: #3b82f6; background: #eff6ff; }
            .exercise-match-row { display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; margin: 0.4rem 0; font-size: 0.92rem; }
            .exercise-match-row select { padding: 0.4rem 0.5rem; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; font-size: 0.92rem; max-width: 16rem; }
            .exercise-blank-row { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin: 0.5rem 0; }
            .exercise-hint { color: #6b7280; font-size: 0.85rem; margin: 0.35rem 0; }
        }
    }

}
