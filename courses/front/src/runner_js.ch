// Interactive learner-authored runner for the `front` course.
//
// The learner authors a SOURCE EXPRESSION (not executable JavaScript).  The
// lexer/parser the lesson teaches tokenises and parses it; a second, independent
// Pratt parser in the same page is the oracle.  Both trees are compared BY VALUE
// with a canonical serialiser.  No eval, no fetch, no filesystem, no dynamic
// code execution: learner input is data, never program text for this runtime.
// Input is bounded to 4096 characters and the parser has a 100000-step budget,
// so a pathological input cannot hang the page.
public namespace front_pages {

using std::string

public func render_runner_js(page : &mut HtmlPage) {
    #css {
        .front-runner { margin: 1rem 0; padding: 1rem; border: 1px solid hsl(var(--border)); border-radius: 8px; background: hsl(var(--card)); }
        .front-runner label { display: block; font-weight: 600; margin-bottom: 0.4rem; }
        .front-runner input { width: 100%; box-sizing: border-box; padding: 0.6rem; font-family: ui-monospace, monospace; font-size: 1rem; border: 1px solid hsl(var(--border)); border-radius: 4px; background: hsl(var(--background)); color: hsl(var(--foreground)); }
        .front-runner input:focus-visible { outline: 2px solid hsl(var(--primary)); outline-offset: 1px; }
        .front-runner button { margin-top: 0.7rem; min-height: 2.75rem; padding: 0.5rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 6px; background: hsl(var(--card)); color: hsl(var(--foreground)); cursor: pointer; font-size: 1rem; }
        .front-runner button:hover { background: hsl(var(--accent)); }
        .front-runner pre { white-space: pre-wrap; word-break: break-word; background: #1e1e1e; color: #d4d4d4; padding: 0.8rem; border-radius: 6px; font-size: 0.9rem; }
        .front-verdict { font-size: 0.92rem; min-height: 1.4rem; margin-top: 0.5rem; }
        .front-error { color: hsl(var(--foreground)); font-size: 0.92rem; min-height: 1.4rem; margin-top: 0.25rem; }
    }

    #js {
        (function() {
            var OPS = { '+': 'Add', '-': 'Sub', '*': 'Mult', '/': 'Div' };

            function frontLex(src) {
                if (src.length > 4096) { throw new Error('source is longer than 4096 characters (bounded input)'); }
                var out = [];
                var i = 0;
                while (i < src.length) {
                    var c = src.charAt(i);
                    if (/\s/.test(c)) { i = i + 1; continue; }
                    if (c >= '0' && c <= '9') {
                        var j = i + 1;
                        while (j < src.length && src.charAt(j) >= '0' && src.charAt(j) <= '9') { j = j + 1; }
                        out.push(['NUMBER', src.slice(i, j)]);
                        i = j;
                        continue;
                    }
                    if (/[A-Za-z_]/.test(c)) {
                        var j = i + 1;
                        while (j < src.length && /[A-Za-z0-9_]/.test(src.charAt(j))) { j = j + 1; }
                        out.push(['NAME', src.slice(i, j)]);
                        i = j;
                        continue;
                    }
                    if ('+-*/()'.indexOf(c) >= 0) { out.push(['OP', c]); i = i + 1; continue; }
                    throw new Error('unexpected character ' + c + ' at offset ' + i);
                }
                return out;
            }

            // The course's recursive-descent parser: expr -> term -> unary -> primary.
            function frontParse(tokens) {
                var pos = 0;
                var steps = 0;
                function bump() {
                    steps = steps + 1;
                    if (steps > 100000) { throw new Error('parse step limit exceeded (bounded work)'); }
                }
                function peek() { return pos < tokens.length ? tokens[pos] : null; }
                function take() {
                    var t = peek();
                    if (t === null) { throw new Error('expected more input, reached end of source'); }
                    pos = pos + 1;
                    return t;
                }
                function primary() {
                    bump();
                    var t = take();
                    if (t[0] === 'NUMBER') { return { k: 'num', v: parseInt(t[1], 10) }; }
                    if (t[0] === 'NAME') { return { k: 'name', v: t[1] }; }
                    if (t[0] === 'OP' && t[1] === '(') {
                        var inner = expr();
                        var close = take();
                        if (close[1] !== ')') { throw new Error('expected ) after (, got ' + close[1]); }
                        return inner;
                    }
                    throw new Error('expected a number, a name, or (, got ' + t[1]);
                }
                function unary() {
                    bump();
                    var t = peek();
                    if (t !== null && t[0] === 'OP' && t[1] === '-') {
                        take();
                        return { k: 'un', op: 'USub', v: unary() };
                    }
                    return primary();
                }
                function term() {
                    bump();
                    var node = unary();
                    while (pos < tokens.length) {
                        var t = tokens[pos];
                        if (t[0] !== 'OP' || (t[1] !== '*' && t[1] !== '/')) { return node; }
                        var op = take()[1];
                        node = { k: 'bin', op: OPS[op], l: node, r: unary() };
                    }
                    return node;
                }
                function expr() {
                    bump();
                    var node = term();
                    while (pos < tokens.length) {
                        var t = tokens[pos];
                        if (t[0] !== 'OP' || (t[1] !== '+' && t[1] !== '-')) { return node; }
                        var op = take()[1];
                        node = { k: 'bin', op: OPS[op], l: node, r: term() };
                    }
                    return node;
                }
                if (tokens.length === 0) { throw new Error('empty source has no expression'); }
                var root = expr();
                if (pos !== tokens.length) { throw new Error('unexpected token ' + tokens[pos][1] + ' at offset ' + pos); }
                return root;
            }

            // Independent oracle: a Pratt parser, not the course's algorithm.
            function oracleParse(tokens) {
                var pos = 0;
                var BP = { '+': 10, '-': 10, '*': 20, '/': 20 };
                function nud() {
                    var t = tokens[pos];
                    if (typeof t === 'undefined') { throw new Error('oracle expected a token'); }
                    pos = pos + 1;
                    if (t[0] === 'NUMBER') { return { k: 'num', v: parseInt(t[1], 10) }; }
                    if (t[0] === 'NAME') { return { k: 'name', v: t[1] }; }
                    if (t[0] === 'OP' && t[1] === '-') { return { k: 'un', op: 'USub', v: parseBP(30) }; }
                    if (t[0] === 'OP' && t[1] === '(') {
                        var inner = parseBP(0);
                        var close = tokens[pos];
                        if (typeof close === 'undefined' || close[1] !== ')') { throw new Error('oracle expected )'); }
                        pos = pos + 1;
                        return inner;
                    }
                    throw new Error('oracle cannot read token ' + t[1]);
                }
                function parseBP(minBP) {
                    var left = nud();
                    while (pos < tokens.length) {
                        var t = tokens[pos];
                        if (t[0] !== 'OP') { break; }
                        var bp = BP[t[1]];
                        if (typeof bp !== 'number' || bp <= minBP) { break; }
                        pos = pos + 1;
                        var right = parseBP(bp);
                        left = { k: 'bin', op: OPS[t[1]], l: left, r: right };
                    }
                    return left;
                }
                if (tokens.length === 0) { throw new Error('empty source has no expression'); }
                var root = parseBP(0);
                if (pos !== tokens.length) { throw new Error('oracle saw leftover token ' + tokens[pos][1]); }
                return root;
            }

            function canon(v) {
                if (Array.isArray(v)) {
                    var a = [];
                    for (var i = 0; i < v.length; i = i + 1) { a.push(canon(v[i])); }
                    return '[' + a.join(',') + ']';
                }
                if (v !== null && typeof v === 'object') {
                    var keys = Object.keys(v).sort();
                    var b = [];
                    for (var i = 0; i < keys.length; i = i + 1) {
                        b.push(JSON.stringify(keys[i]) + ':' + canon(v[keys[i]]));
                    }
                    return '{' + b.join(',') + '}';
                }
                return JSON.stringify(v);
            }

            function run() {
                var box = document.getElementById('front-source');
                var out = document.getElementById('front-output');
                var verdict = document.getElementById('front-verdict');
                var error = document.getElementById('front-error');
                if (box === null || out === null || verdict === null || error === null) { return; }
                out.textContent = '';
                error.textContent = '';
                verdict.textContent = '';
                var src = box.value;
                try {
                    var tokens = frontLex(src);
                    var mine = frontParse(tokens);
                    var oracle = oracleParse(tokens);
                    var fixtureNode = document.getElementById('front-fixture');
                    if (fixtureNode !== null && src === fixtureNode.getAttribute('data-source')) {
                        var fixture = JSON.parse(fixtureNode.textContent);
                        if (canon(fixture) !== canon(oracle)) {
                            error.textContent = 'the shipped fixture and the oracle disagree: check courses/front/assets/samples/specimen.ast.json';
                            return;
                        }
                    }
                    var lines = [];
                    lines.push('TOKENS (' + tokens.length + ')');
                    for (var i = 0; i < tokens.length; i = i + 1) {
                        lines.push('  ' + tokens[i][0] + ' ' + tokens[i][1]);
                    }
                    lines.push('AST (my recursive descent)');
                    lines.push('  ' + canon(mine));
                    lines.push('AST (oracle Pratt)');
                    lines.push('  ' + canon(oracle));
                    out.textContent = lines.join('\n');
                    if (canon(mine) === canon(oracle)) {
                        verdict.textContent = 'AGREE by value: ' + tokens.length + ' tokens; both parsers built the same tree.';
                    } else {
                        verdict.textContent = 'DISAGREE: the two parsers built different trees; read the AST lines above.';
                    }
                } catch (e) {
                    error.textContent = e.message || String(e);
                }
            }

            document.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('front-run');
                if (btn !== null) { btn.addEventListener('click', run); }
            });
        })();
    }
}

}
