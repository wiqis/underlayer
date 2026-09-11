// Underlayer Button component

func ul_button_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        white-space: nowrap;
        border-radius: 6px;
        height: 2.5rem;
        padding: 0 1rem;
        font-size: 0.875rem;
        font-weight: 500;
        line-height: 1;
        background-color: hsl(222, 47%, 11%);
        color: white;
        border: 1px solid transparent;
        box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        cursor: pointer;
        user-select: none;
        transition: background-color 0.15s ease, color 0.15s ease, opacity 0.15s ease;
        &:hover { background-color: hsl(222, 47%, 15%); }
        &:focus-visible { outline: 2px solid hsl(215, 95%, 50%); outline-offset: 2px; }
        &:active { transform: translateY(0.5px); }
        &:disabled { opacity: 0.5; pointer-events: none; }
        &[data-variant="outline"] {
            background-color: transparent;
            border-color: hsl(220, 13%, 91%);
            color: hsl(222, 47%, 11%);
            &:hover { background-color: hsl(220, 14%, 96%); }
        }
        &[data-variant="ghost"] {
            background-color: transparent;
            color: hsl(222, 47%, 11%);
            &:hover { background-color: hsl(220, 14%, 96%); }
        }
        &[data-variant="success"] {
            background-color: hsl(142, 76%, 36%);
            color: white;
            &:hover { background-color: hsl(142, 76%, 32%); }
        }
        &[data-size="sm"] { height: 2rem; padding: 0 0.75rem; font-size: 0.8125rem; }
        &[data-size="lg"] { height: 2.75rem; padding: 0 1.25rem; font-size: 1rem; }
    }
}

public #universal UlButton(props) {
    var classes = props.class || ""
    var variant = props.variant || "default"
    var size = props.size || "default"
    var out = classes + " " + ${ul_button_styles(page)}
    return <button class={out} data-variant={variant} data-size={size != "default" ? size : null} onClick={props.onClick} disabled={props.disabled}>{props.children}</button>
}
