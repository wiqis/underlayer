// Underlayer Quiz component

func quiz_styles(page : &mut HtmlPage) : *char {
    return #css {
        margin-top: 1rem;
        .chx-quiz-options { display: flex; flex-direction: column; gap: 0.5rem; }
        .chx-quiz-option {
            display: block;
            width: 100%;
            padding: 0.75rem 1rem;
            border: 1px solid hsl(220, 13%, 91%);
            border-radius: 6px;
            background: white;
            cursor: pointer;
            text-align: left;
            font-size: 0.875rem;
            transition: border-color 0.15s, background 0.15s;
            &:hover { border-color: hsl(215, 95%, 50%); }
            &:disabled { cursor: default; }
        }
        .chx-quiz-option[data-state="correct"] { border-color: hsl(142, 76%, 36%); background: hsl(142, 76%, 94%); }
        .chx-quiz-option[data-state="wrong"] { border-color: hsl(0, 86%, 53%); background: hsl(0, 86%, 97%); }
        .chx-quiz-feedback { margin-top: 0.75rem; font-size: 0.875rem; font-weight: 500; }
    }
}

public #universal UlQuiz(props) {
    var out = "ul-quiz " + ${quiz_styles(page)}

    return <div class={out}>
        <div class="chx-quiz-options">
            <button class="chx-quiz-option">{props.opt0}</button>
            <button class="chx-quiz-option">{props.opt1}</button>
            <button class="chx-quiz-option">{props.opt2}</button>
        </div>
        <div class="chx-quiz-feedback"></div>
    </div>
}
