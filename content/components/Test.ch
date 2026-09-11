// Test component

func test_styles(page : &mut HtmlPage) : *char {
    return #css {
        color: red;
    }
}

public #universal TestComp(props) {
    var out = "test " + ${test_styles(page)}
    return <div class={out}>{props.children}</div>
}
