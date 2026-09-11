// Underlayer Navigation component

func ul_nav_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1.5rem 0;
        margin-top: 2rem;
        border-top: 1px solid hsl(220, 13%, 91%);
        .chx-nav-link {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.5rem 1rem;
            border: 1px solid hsl(220, 13%, 91%);
            border-radius: 6px;
            color: hsl(222, 47%, 11%);
            text-decoration: none;
            font-size: 0.875rem;
            font-weight: 500;
            transition: border-color 0.15s, background 0.15s;
            &:hover { border-color: hsl(215, 95%, 50%); background: hsl(214, 95%, 97%); }
        }
        .chx-nav-spacer { flex: 1; }
    }
}

public #universal UlNavigation(props) {
    var prevHref = props.prevHref || ""
    var prevLabel = props.prevLabel || ""
    var nextHref = props.nextHref || ""
    var nextLabel = props.nextLabel || ""
    var hasPrev = prevHref.size() > 0
    var hasNext = nextHref.size() > 0
    var prevText = "← " + prevLabel
    var nextText = nextLabel + " →"
    var out = "ul-nav " + ${ul_nav_styles(page)}

    return <nav class={out}>
        {hasPrev ? <a class="chx-nav-link" href={prevHref}>{prevText}</a> : <span class="chx-nav-spacer"></span>}
        {hasNext ? <a class="chx-nav-link" href={nextHref}>{nextText}</a> : <span class="chx-nav-spacer"></span>}
    </nav>
}
