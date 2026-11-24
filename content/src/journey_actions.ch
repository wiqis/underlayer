// underlayer_content â€” journey actions: takeaway, gate, recall, pacing, finish.
//
// Every decision here is reversible and local.  There is no score, no streak and
// no verdict: "I'm stuck - show me" always reveals an answer and always lets the
// learner continue.  The only persisted data is a short written takeaway and the
// exact step, both in localStorage under (course, concept, step).
using std::string
using std::string_view

public namespace underlayer_content {

    public func render_journey_actions_js(page : &mut HtmlPage) {
        #js {
            function jqWordCount(s) {
                var t = jqTrim(s);
                if(t.length === 0) { return 0; }
                var n = 1;
                var prev = false;
                var i = 0;
                while(i < t.length) {
                    var space = t.charAt(i) === ' ';
                    if(space && !prev) { n = n + 1; }
                    prev = space;
                    i = i + 1;
                }
                return n;
            }

            function jqClampWords(s) {
                var t = jqTrim(s);
                var words = [];
                var cur = '';
                var i = 0;
                while(i < t.length) {
                    var ch = t.charAt(i);
                    if(ch === ' ') {
                        if(cur.length > 0) { words.push(cur); cur = ''; }
                    } else { cur = cur + ch; }
                    i = i + 1;
                }
                if(cur.length > 0) { words.push(cur); }
                var out = '';
                var k = 0;
                while(k < words.length && k < 25) {
                    if(k > 0) { out = out + ' '; }
                    out = out + words[k];
                    k = k + 1;
                }
                return out;
            }

            function jqNote() {
                var el = jqEl('ul-journey-note');
                return el ? el.value : '';
            }

            function jqPrepareNote(i) {
                var el = jqEl('ul-journey-note');
                if(!el) { return; }
                el.value = jqGet(jqKey('note:' + i));
                var w = jqEl('ul-journey-words');
                if(w) { w.textContent = jqWordCount(el.value) + ' / 25 words'; }
            }

            function jqOnNote() {
                var el = jqEl('ul-journey-note');
                if(!el) { return; }
                var clamped = jqClampWords(el.value);
                if(el.value !== clamped) { el.value = clamped; }
                jqSet(jqKey('note:' + jqState.idx), el.value);
                var w = jqEl('ul-journey-words');
                if(w) { w.textContent = jqWordCount(el.value) + ' / 25 words'; }
                jqUpdateContinue();
            }

            function jqHasAction(u) {
                if(u.querySelector('.quiz-option')) { return true; }
                if(u.querySelector('.fill-blank')) { return true; }
                if(u.querySelector('.hex-byte')) { return true; }
                if(u.querySelector('.exercise-option')) { return true; }
                if(u.querySelector('.tf-option')) { return true; }
                if(u.querySelector('.recognize-option')) { return true; }
                return false;
            }

            function jqPrepareGate(i) {
                var u = jqState.units[i];
                var done = jqGet(jqKey('done:' + i)) === '1';
                jqState.gate[i] = done;
                var reveal = jqEl('ul-journey-reveal');
                if(reveal) { reveal.textContent = "I'm stuck - show me"; }
            }

            function jqMarkAction() {
                var i = jqState.idx;
                jqState.gate[i] = true;
                jqSet(jqKey('done:' + i), '1');
                jqUpdateContinue();
            }

            function jqUpdateContinue() {
                var btn = jqEl('ul-journey-continue');
                if(!btn) { return; }
                var i = jqState.idx;
                var u = jqState.units[i];
                var ok = jqState.gate[i] === true;
                if(!u || !jqHasAction(u)) { ok = jqWordCount(jqNote()) > 0 || ok; }
                else { ok = ok || jqWordCount(jqNote()) > 0; }
                btn.disabled = !ok;
            }

            function jqRetrieveUnit(i) {
                var s = jqState;
                var j = i - 1;
                while(j >= 0) {
                    if(s.units[j].classList.contains('unit-retrieve')) { return s.units[j]; }
                    j = j - 1;
                }
                return null;
            }

            function jqRetrieveQA(i) {
                var u = jqRetrieveUnit(i);
                if(!u) {
                    var earlier = jqState.units[i - 1];
                    var point = earlier ? jqKeyPoint(earlier) : '';
                    if(point.length > 0 && point.charAt(point.length - 1) === '.') { point = point.substring(0, point.length - 1); }
                    return { q: 'Earlier you saw: ' + point + '. In your own words, what did it mean?', a: point };
                }
                var ps = u.querySelectorAll('p');
                var q = '';
                var k = 0;
                while(k < ps.length) {
                    q = jqTrim(jqText(ps[k]));
                    if(q.length > 0) { break; }
                    k = k + 1;
                }
                var answer = '';
                var opts = u.querySelectorAll('.quiz-option');
                k = 0;
                while(k < opts.length) {
                    if(opts[k].getAttribute('data-correct') === 'true') { answer = jqTrim(jqText(opts[k])); break; }
                    k = k + 1;
                }
                if(answer.length === 0) {
                    var blanks = u.querySelectorAll('.fill-blank');
                    k = 0;
                    while(k < blanks.length) {
                        var a = blanks[k].getAttribute('data-answer') || '';
                        if(answer.length > 0) { answer = answer + ', '; }
                        answer = answer + a;
                        k = k + 1;
                    }
                }
                if(answer.length === 0) { answer = jqKeyPoint(u); }
                if(q.length === 0) { q = 'Recall the idea from ' + jqTitle(u) + '.'; }
                return { q: q, a: answer };
            }

            function jqPrepareRetrieval(i) {
                var box = jqEl('ul-journey-retrieve');
                if(!box) { return; }
                if(i === 0) { jqHide(box, true); return; }
                var qa = jqRetrieveQA(i);
                var ask = jqEl('ul-journey-ask');
                var answer = jqEl('ul-journey-answer');
                if(ask) { ask.textContent = qa.q; }
                if(answer) { answer.textContent = qa.a; jqHide(answer, true); }
                jqHide(box, false);
            }

            function jqReveal() {
                var answer = jqEl('ul-journey-answer');
                if(answer) { jqHide(answer, false); }
                var reveal = jqEl('ul-journey-reveal');
                if(reveal) { reveal.textContent = 'Answer shown - continue when ready'; }
                jqMarkAction();
            }

        }
    }
}

