// underlayer_content â€” unit walking helpers for the guided journey.
//
// Reads the semantic .unit blocks already present in every lesson. No technical
// text is authored here: labels, key points and disclosure decisions all come
// from the lesson itself.
using std::string
using std::string_view

public namespace underlayer_content {

    public func render_journey_units_js(page : &mut HtmlPage) {
        #js {
            function jqText(el) {
                if(!el) { return ''; }
                return jqTrim(el.textContent);
            }
            function jqTrim(s) {
                var t = String(s || '');
                var a = 0;
                var b = t.length;
                while(a < b && (t.charAt(a) === ' ' || t.charAt(a) === '\t' || t.charAt(a) === '\n')) { a = a + 1; }
                while(b > a && (t.charAt(b - 1) === ' ' || t.charAt(b - 1) === '\t' || t.charAt(b - 1) === '\n')) { b = b - 1; }
                return t.substring(a, b);
            }

            function jqUnits() {
                var lesson = document.querySelector('.lesson');
                if(!lesson) { return []; }
                var all = lesson.querySelectorAll('.unit');
                var out = [];
                var i = 0;
                while(i < all.length) {
                    var u = all[i];
                    if(u.classList.contains('unit-exercises')) { i = i + 1; continue; }
                    if(u.style && u.style.display === 'none') { i = i + 1; continue; }
                    out.push(u);
                    i = i + 1;
                }
                return out;
            }

            function jqPurpose(u) {
                var c = u.className || '';
                if(c.indexOf('unit-why') >= 0) { return 'Why'; }
                if(c.indexOf('unit-model') >= 0) { return 'Model'; }
                if(c.indexOf('unit-reality') >= 0) { return 'Detail'; }
                if(c.indexOf('unit-example') >= 0) { return 'Example'; }
                if(c.indexOf('unit-connect') >= 0) { return 'Connect'; }
                if(c.indexOf('unit-interact') >= 0) { return 'Try it'; }
                if(c.indexOf('unit-apply') >= 0) { return 'Apply'; }
                if(c.indexOf('unit-retrieve') >= 0) { return 'Retrieve'; }
                return 'Detail';
            }

            function jqTitle(u) {
                var h = u.querySelector('h2');
                var t = jqTrim(jqText(h));
                if(t.length > 0) { return t; }
                return jqPurpose(u);
            }

            function jqKeyPoint(u) {
                var title = jqTitle(u);
                var ps = u.querySelectorAll('p');
                var first = '';
                var i = 0;
                while(i < ps.length) {
                    var t = jqTrim(jqText(ps[i]));
                    if(t.length > 0) { first = t; break; }
                    i = i + 1;
                }
                if(first.length === 0) { return title; }
                var dot = first.indexOf('.');
                if(dot > 24 && dot < 220) { first = first.substring(0, dot + 1); }
                if(first.length > 170) { first = first.substring(0, 167) + '...'; }
                var low = first.toLowerCase();
                if(title.length > 0 && low.indexOf(title.toLowerCase()) < 0) { return title + ': ' + first; }
                return first;
            }

            function jqNoFact(u) {
                if(u.classList.contains('unit-connect')) { return true; }
                if(u.classList.contains('unit-exercises')) { return true; }
                return false;
            }

            function jqIsLong(el) {
                var tag = el.tagName;
                if(tag === 'TABLE') {
                    var rows = el.querySelectorAll('tr');
                    return rows.length > 8;
                }
                if(tag === 'PRE') {
                    var body = jqText(el);
                    var lines = 1;
                    var i = 0;
                    while(i < body.length) {
                        if(body.charAt(i) === '\n') { lines = lines + 1; }
                        i = i + 1;
                    }
                    return lines > 8 || body.length > 360;
                }
                if(el.classList && (el.classList.contains('hex-dump') || el.classList.contains('hex-interactive'))) {
                    return jqText(el).length > 120;
                }
                return jqText(el).length > 600;
            }

            function jqShowDetail(ev) {
                var el = ev.target;
                while(el && el !== document) {
                    if(el.classList && el.classList.contains('journey-detail-btn')) { break; }
                    el = el.parentNode;
                }
                if(!el || el === document) { return; }
                var id = el.getAttribute('data-jq-show');
                var target = document.getElementById(id);
                if(!target) { return; }
                var revealing = target.getAttribute('hidden') !== null;
                if(revealing) { target.removeAttribute('hidden'); }
                else { target.setAttribute('hidden', ''); }
                el.textContent = revealing ? 'Hide the full detail' : 'Show the full detail';
                el.setAttribute('aria-label', el.textContent);
            }

            function jqDetailButton(target) {
                var id = target.getAttribute('id');
                if(!id) {
                    jqSeq = jqSeq + 1;
                    id = 'jq-detail-' + jqSeq;
                    target.setAttribute('id', id);
                }
                var b = document.createElement('button');
                b.type = 'button';
                b.className = 'journey-btn journey-detail-btn';
                b.setAttribute('data-jq-show', id);
                b.setAttribute('aria-label', 'Show the full detail');
                b.textContent = 'Show the full detail';
                return b;
            }

            function jqPrepareUnit(u) {
                if(u.getAttribute('data-jq-ready') === '1') { return; }
                var kids = [];
                var ch = u.children;
                var i = 0;
                while(i < ch.length) { kids.push(ch[i]); i = i + 1; }
                i = 0;
                while(i < kids.length) {
                    var el = kids[i];
                    if(jqIsLong(el)) {
                        var btn = jqDetailButton(el);
                        u.insertBefore(btn, el);
                        el.setAttribute('hidden', '');
                        el.setAttribute('data-jq-hidden', '1');
                    }
                    i = i + 1;
                }
                u.setAttribute('data-jq-ready', '1');
            }

            function jqRestoreUnit(u) {
                var hidden = u.querySelectorAll('[data-jq-hidden]');
                var i = 0;
                while(i < hidden.length) {
                    hidden[i].removeAttribute('hidden');
                    hidden[i].removeAttribute('data-jq-hidden');
                    i = i + 1;
                }
                var btns = u.querySelectorAll('.journey-detail-btn');
                i = 0;
                while(i < btns.length) {
                    var b = btns[i];
                    if(b.parentNode) { b.parentNode.removeChild(b); }
                    i = i + 1;
                }
                u.removeAttribute('data-jq-ready');
            }

            document.addEventListener('click', jqShowDetail, true);
        }
    }
}

