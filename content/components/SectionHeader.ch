// Underlayer SectionHeader component

func ul_section_styles(page : &mut HtmlPage) : *char {
    return #css {
        margin-bottom: 2rem;
        padding: 1.5rem;
        border-radius: 8px;
        border-left: 4px solid;
        &[data-color="blue"] { border-color: hsl(215, 95%, 50%); background: hsl(214, 95%, 97%); }
        &[data-color="green"] { border-color: hsl(142, 76%, 36%); background: hsl(142, 76%, 94%); }
        &[data-color="amber"] { border-color: hsl(38, 92%, 50%); background: hsl(38, 92%, 95%); }
        &[data-color="purple"] { border-color: hsl(262, 83%, 58%); background: hsl(262, 83%, 97%); }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
    }
}

public #universal UlSection(props) {
    var color = props.color || "blue"
    var out = "ul-section " + ${ul_section_styles(page)}
    return <div class={out} data-color={color}>{props.children}</div>
}
