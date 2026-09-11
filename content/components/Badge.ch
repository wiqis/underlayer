// Underlayer Badge component

func ul_badge_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: inline-flex;
        align-items: center;
        border-radius: 9999px;
        border: 1px solid transparent;
        padding: 0.125rem 0.625rem;
        font-size: 0.75rem;
        line-height: 1.25rem;
        font-weight: 600;
        white-space: nowrap;
        background: hsl(220, 14%, 96%);
        color: hsl(215, 16%, 47%);
        &[data-variant="default"] { background: hsl(222, 47%, 11%); color: white; }
        &[data-variant="success"] { background: hsl(142, 76%, 94%); color: hsl(142, 76%, 26%); }
        &[data-variant="error"] { background: hsl(0, 86%, 97%); color: hsl(0, 86%, 32%); }
        &[data-variant="warning"] { background: hsl(38, 92%, 95%); color: hsl(38, 92%, 30%); }
        &[data-variant="info"] { background: hsl(214, 95%, 95%); color: hsl(214, 95%, 32%); }
        &[data-variant="outline"] { border-color: hsl(220, 13%, 91%); background: transparent; }
    }
}

public #universal UlBadge(props) {
    var classes = props.class || ""
    var variant = props.variant || "default"
    var out = classes + " " + ${ul_badge_styles(page)}
    return <span class={out} data-variant={variant}>{props.children}</span>
}
