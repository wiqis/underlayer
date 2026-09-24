// Type-specific exercise card builders for all 8 lesson types (4.1.29).
// Paired with exercise_ui_js.ch (loader/submit) — both call into the same
// global __ul_ex_* functions on the page.
public namespace underlayer_content {

    public func render_exercise_build_js(page : &mut HtmlPage) {
        #js {
            function __ul_ex_build(ex) {
                var card = document.createElement('div');
                card.className = 'exercise-card';
                var h = document.createElement('h4');
                h.textContent = ex.question;
                card.appendChild(h);
                var fb = document.createElement('div');
                fb.className = 'exercise-feedback';
                var t = ex.type;
                var hasOpts = ex.options && ex.options.length > 0;

                if (t === 'multi_recognize' && hasOpts) {
                    var checks = [];
                    var labels = [];
                    var j = 0;
                    while (j < ex.options.length) {
                        var lab = document.createElement('label');
                        lab.className = 'exercise-multi';
                        var cb = document.createElement('input');
                        cb.type = 'checkbox';
                        cb.value = String(j);
                        lab.appendChild(cb);
                        lab.appendChild(document.createTextNode(ex.options[j]));
                        card.appendChild(lab);
                        checks.push(cb);
                        labels.push(lab);
                        j = j + 1;
                    }
                    var mbtn = document.createElement('button');
                    mbtn.className = 'exercise-check';
                    mbtn.textContent = 'Check';
                    mbtn.onclick = function() {
                        var picked = [];
                        var k = 0;
                        while (k < checks.length) {
                            if (checks[k].checked) { picked.push(String(k)); }
                            k = k + 1;
                        }
                        __ul_ex_submit(ex, picked.join(','), checks.concat([mbtn]), fb);
                    };
                    card.appendChild(mbtn);
                } else if (t === 'ordering' && hasOpts) {
                    var order = [];
                    var oi = 0;
                    while (oi < ex.options.length) { order.push(ex.options[oi]); oi = oi + 1; }
                    var ul = document.createElement('ul');
                    ul.className = 'exercise-order';
                    var moveButtons = [];
                    var redraw = function() {
                        ul.innerHTML = '';
                        moveButtons = [];
                        var ri = 0;
                        while (ri < order.length) {
                            var li = document.createElement('li');
                            var span = document.createElement('span');
                            span.className = 'ord-label';
                            span.textContent = order[ri];
                            li.appendChild(span);
                            var up = document.createElement('button');
                            up.type = 'button';
                            up.textContent = '↑';
                            up.disabled = ri === 0;
                            (function(idx) {
                                up.onclick = function() {
                                    var tmp = order[idx - 1];
                                    order[idx - 1] = order[idx];
                                    order[idx] = tmp;
                                    redraw();
                                };
                            })(ri);
                            var down = document.createElement('button');
                            down.type = 'button';
                            down.textContent = '↓';
                            down.disabled = ri === order.length - 1;
                            (function(idx) {
                                down.onclick = function() {
                                    var tmp = order[idx + 1];
                                    order[idx + 1] = order[idx];
                                    order[idx] = tmp;
                                    redraw();
                                };
                            })(ri);
                            li.appendChild(up);
                            li.appendChild(down);
                            ul.appendChild(li);
                            moveButtons.push(up);
                            moveButtons.push(down);
                            ri = ri + 1;
                        }
                    };
                    redraw();
                    card.appendChild(ul);
                    var obtn = document.createElement('button');
                    obtn.className = 'exercise-check';
                    obtn.textContent = 'Check order';
                    obtn.onclick = function() {
                        var all = moveButtons.concat([obtn]);
                        __ul_ex_submit(ex, order.join('|'), all, fb);
                    };
                    card.appendChild(obtn);
                } else if (t === 'matching' && hasOpts && ex.right_options) {
                    var selects = [];
                    var mi = 0;
                    while (mi < ex.options.length) {
                        var row = document.createElement('div');
                        row.className = 'exercise-match-row';
                        var left = document.createElement('span');
                        left.textContent = ex.options[mi];
                        var sel = document.createElement('select');
                        var ph = document.createElement('option');
                        ph.value = '';
                        ph.textContent = 'Choose…';
                        sel.appendChild(ph);
                        var ri2 = 0;
                        while (ri2 < ex.right_options.length) {
                            var opt = document.createElement('option');
                            opt.value = ex.right_options[ri2];
                            opt.textContent = ex.right_options[ri2];
                            sel.appendChild(opt);
                            ri2 = ri2 + 1;
                        }
                        row.appendChild(left);
                        row.appendChild(sel);
                        card.appendChild(row);
                        selects.push(sel);
                        mi = mi + 1;
                    }
                    var mtbtn = document.createElement('button');
                    mtbtn.className = 'exercise-check';
                    mtbtn.textContent = 'Check matches';
                    mtbtn.onclick = function() {
                        var parts = [];
                        var si = 0;
                        while (si < selects.length) { parts.push(selects[si].value); si = si + 1; }
                        __ul_ex_submit(ex, parts.join('|'), selects.concat([mtbtn]), fb);
                    };
                    card.appendChild(mtbtn);
                } else if (t === 'labeling') {
                    var blanks = ex.blank_count || 1;
                    var wrap = document.createElement('div');
                    wrap.className = 'exercise-blank-row';
                    var inputs = [];
                    var bi = 0;
                    while (bi < blanks) {
                        var inp = document.createElement('input');
                        inp.type = 'text';
                        inp.className = 'exercise-input';
                        inp.placeholder = 'Blank ' + (bi + 1);
                        wrap.appendChild(inp);
                        inputs.push(inp);
                        bi = bi + 1;
                    }
                    card.appendChild(wrap);
                    var lbtn = document.createElement('button');
                    lbtn.className = 'exercise-check';
                    lbtn.textContent = 'Check labels';
                    lbtn.onclick = function() {
                        var parts = [];
                        var ii = 0;
                        while (ii < inputs.length) { parts.push(inputs[ii].value); ii = ii + 1; }
                        __ul_ex_submit(ex, parts.join('|'), inputs.concat([lbtn]), fb);
                    };
                    card.appendChild(lbtn);
                } else if (hasOpts && t !== 'fill_blank' && t !== 'recall' && t !== 'apply' && t !== 'explain') {
                    var oi2 = 0;
                    while (oi2 < ex.options.length) {
                        (function(opt) {
                            var b = document.createElement('button');
                            b.className = 'exercise-option';
                            b.textContent = opt;
                            b.onclick = function() {
                                var opts = card.querySelectorAll('.exercise-option');
                                __ul_ex_submit(ex, opt, Array.prototype.slice.call(opts), fb);
                            };
                            card.appendChild(b);
                        })(ex.options[oi2]);
                        oi2 = oi2 + 1;
                    }
                } else {
                    var row2 = document.createElement('div');
                    row2.className = 'exercise-row';
                    var inp2 = document.createElement('input');
                    inp2.type = 'text';
                    inp2.className = 'exercise-input';
                    inp2.placeholder = t === 'hex_inspect' ? 'e.g. 0x40' : 'Type your answer';
                    var tbtn = document.createElement('button');
                    tbtn.className = 'exercise-check';
                    tbtn.textContent = 'Check';
                    tbtn.onclick = function() { __ul_ex_submit(ex, inp2.value, [inp2, tbtn], fb); };
                    row2.appendChild(inp2);
                    row2.appendChild(tbtn);
                    card.appendChild(row2);
                }
                card.appendChild(fb);
                return card;
            }
        }
    }

}
