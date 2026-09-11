// Underlayer Progress component

func progress_bar_styles(page : &mut HtmlPage) : *char {
    return #css {
        width: 100%;
        .chx-progress-header { display: flex; justify-content: space-between; margin-bottom: 0.375rem; }
        .chx-progress-label { font-size: 0.8125rem; color: hsl(215, 16%, 47%); }
        .chx-progress-track { width: 100%; height: 8px; background: hsl(220, 14%, 96%); border-radius: 9999px; overflow: hidden; }
        .chx-progress-fill { height: 100%; background: hsl(222, 47%, 11%); border-radius: 9999px; transition: width 0.3s ease; }
        &[data-variant="success"] .chx-progress-fill { background: hsl(142, 76%, 36%); }
        &[data-variant="warning"] .chx-progress-fill { background: hsl(38, 92%, 50%); }
    }
}

public #universal UlProgress(props) {
    var value = props.value || 0
    var max = props.max || 100
    var variant = props.variant || "default"
    var label = props.label || ""
    var pct = (value * 100) / max
    var pctStr = underlayer_core::int_to_string(pct)
    var fillStyle = "width: " + pctStr + "%"
    var out = "ul-progress " + ${progress_bar_styles(page)}
    return <div class={out} data-variant={variant}>
        <div class="chx-progress-header">
            <span class="chx-progress-label">{label}</span>
            <span class="chx-progress-label">{pctStr}%</span>
        </div>
        <div class="chx-progress-track">
            <div class="chx-progress-fill" style={fillStyle}></div>
        </div>
    </div>
}
