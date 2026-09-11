// Underlayer HexViewer component

func hex_viewer_component_styles(page : &mut HtmlPage) : *char {
    return #css {
        font-family: monospace;
        background: hsl(222, 47%, 11%);
        color: hsl(210, 40%, 96%);
        padding: 1rem;
        border-radius: 6px;
        .chx-hex-bytes { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.5rem; }
        .chx-hex-byte {
            display: inline-block;
            width: 2ch;
            padding: 0.25rem;
            border-radius: 2px;
            cursor: pointer;
            transition: background 0.1s;
            &:hover { background: rgba(59, 130, 246, 0.3); }
            &[data-selected="true"] { background: rgba(59, 130, 246, 0.5); }
        }
        .chx-hex-info { font-size: 0.85rem; color: hsl(215, 16%, 65%); min-height: 1.25rem; }
        .chx-hex-label { font-size: 0.75rem; color: hsl(215, 16%, 55%); margin-bottom: 0.375rem; }
    }
}

public #universal UlHexViewer(props) {
    var [selectedIdx, setSelectedIdx] = useState(-1)
    var [selectedVal, setSelectedVal] = useState(0)
    var [selectedHex, setSelectedHex] = useState(std::string_view(""))
    var [selectedAscii, setSelectedAscii] = useState(std::string_view(""))

    var handleSelect = (||(idx : int, val : int, hex : std::string_view, ascii : std::string_view) => {
        setSelectedIdx(idx)
        setSelectedVal(val)
        setSelectedHex(hex)
        setSelectedAscii(ascii)
    })

    var hexInfo = selectedIdx >= 0 ? ("Decimal: " + underlayer_core::int_to_string(selectedVal) + " | Hex: 0x" + selectedHex + " | ASCII: " + selectedAscii) : "Click a byte above"
    var sel0 = selectedIdx == 0 ? "true" : ""
    var sel1 = selectedIdx == 1 ? "true" : ""
    var sel2 = selectedIdx == 2 ? "true" : ""
    var sel3 = selectedIdx == 3 ? "true" : ""
    var out = "ul-hex " + ${hex_viewer_component_styles(page)}

    return <div class={out}>
        <div class="chx-hex-label">{props.label}</div>
        <div class="chx-hex-bytes">
            <span class="chx-hex-byte" data-selected={sel0} onClick={() => handleSelect(0, props.val0, props.hex0, props.ascii0)}>{props.hex0}</span>
            <span class="chx-hex-byte" data-selected={sel1} onClick={() => handleSelect(1, props.val1, props.hex1, props.ascii1)}>{props.hex1}</span>
            <span class="chx-hex-byte" data-selected={sel2} onClick={() => handleSelect(2, props.val2, props.hex2, props.ascii2)}>{props.hex2}</span>
            <span class="chx-hex-byte" data-selected={sel3} onClick={() => handleSelect(3, props.val3, props.hex3, props.ascii3)}>{props.hex3}</span>
        </div>
        <div class="chx-hex-info">{hexInfo}</div>
    </div>
}
