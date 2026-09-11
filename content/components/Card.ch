// Underlayer Card component

func ul_card_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: flex;
        flex-direction: column;
        gap: 0.375rem;
        border-radius: 8px;
        border: 1px solid hsl(220, 13%, 91%);
        background: white;
        color: hsl(222, 47%, 11%);
        box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        transition: box-shadow 0.15s ease, border-color 0.15s ease;
        &:hover { border-color: hsl(220, 13%, 85%); }
        &[data-interactive="true"] {
            cursor: pointer;
            &:hover { box-shadow: 0 4px 6px rgba(0,0,0,0.07); }
        }
    }
}

func ul_card_header_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
        padding: 1.25rem 1.25rem 0 1.25rem;
    }
}

func ul_card_title_styles(page : &mut HtmlPage) : *char {
    return #css {
        font-size: 1.125rem;
        line-height: 1.5rem;
        font-weight: 600;
        margin: 0;
        color: hsl(222, 47%, 11%);
    }
}

func ul_card_description_styles(page : &mut HtmlPage) : *char {
    return #css {
        font-size: 0.875rem;
        line-height: 1.375rem;
        color: hsl(215, 16%, 47%);
        margin: 0;
    }
}

func ul_card_body_styles(page : &mut HtmlPage) : *char {
    return #css { padding: 1.25rem; }
}

func ul_card_footer_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0 1.25rem 1.25rem 1.25rem;
    }
}

public #universal UlCard(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_styles(page)}
    return <div data-interactive={props.onClick ? "true" : "false"} class={out} onClick={props.onClick}>{props.children}</div>
}

public #universal UlCardHeader(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_header_styles(page)}
    return <div class={out}>{props.children}</div>
}

public #universal UlCardTitle(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_title_styles(page)}
    return <h3 class={out}>{props.children}</h3>
}

public #universal UlCardDescription(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_description_styles(page)}
    return <p class={out}>{props.children}</p>
}

public #universal UlCardBody(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_body_styles(page)}
    return <div class={out}>{props.children}</div>
}

public #universal UlCardFooter(props) {
    var classes = props.class || ""
    var out = classes + " " + ${ul_card_footer_styles(page)}
    return <div class={out}>{props.children}</div>
}
