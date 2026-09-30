#!/usr/bin/env python3
"""Repair and verify the div/pre nesting in a Chemical `#html { }` block.

The html_cbi macro is a real parser, so a mismatched closing tag does not
degrade gracefully -- it drops out of the macro and the rest of the file is
read as Chemical. This walks the block with a tag stack, rewrites any closer
that does not match the innermost open tag, and then reports.

    python3 tools/html_balance.py content/src/obj_*.ch
"""
import re
import sys

OPEN = re.compile(r'<(div|pre)\b[^>]*>')
CLOSE = re.compile(r'</(div|pre)>')
ANY_TAG = re.compile(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)')
VOID = {'br', 'hr', 'img', 'input', 'meta', 'link'}

# Tags the lesson markup actually uses. A '<' followed by one of these is a real
# tag; a '<' followed by any other word is a metavariable such as <heaptype>
# and must be written &lt;heaptype>.
REAL_TAGS = {
    'a', 'abbr', 'b', 'blockquote', 'br', 'button', 'caption', 'code', 'col',
    'dd', 'details', 'div', 'dl', 'dt', 'em', 'figcaption', 'figure', 'h1',
    'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'i', 'img', 'input', 'kbd', 'li',
    'link', 'meta', 'ol', 'p', 'pre', 's', 'small', 'span', 'strong',
    'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'tfoot', 'th', 'thead',
    'tr', 'u', 'ul',
}


def macro_hazards(path):
    """Characters that break the #html macro, given the current lexer rules.

    Rules as implemented in html_cbi/html_parser (verified by the compiler's
    own tests in lang/tests/compiler_plugins/html/src/pre_verbatim.ch):

      * inside <pre> a bare `{` and `}` are LITERAL CHARACTERS. A brace there
        is no longer a hazard, so this check no longer fires on <pre> content.
        A value inside <pre> is written `@(expr)`.
      * a `<` is a tag only before `!`, `/` or an ASCII letter (the html
        "tag open" state), so a `<` before anything else is text and is legal.
        Only a `<` before a letter needs checking.
      * OUTSIDE <pre> a bare `{` or `}` is still the interpolation sigil and
        still aborts the macro, so that case is still reported.
    """
    src = open(path).read()
    _s, _e, block = block_of(src)
    out = []
    for m in re.finditer(r'<pre>(.*?)</pre>', block, re.S):
        for line in m.group(1).split('\n'):
            for bad in re.findall(r'<([a-zA-Z][a-zA-Z0-9]*)', m.group(1)):
                if bad.lower() not in REAL_TAGS:
                    out.append('"<%s>" inside <pre> is not a real tag -- it '
                               'will be lexed as one; write &lt;%s>'
                               % (bad, bad))
                    break
    # Outside <pre> a brace is the interpolation sigil and aborts the macro.
    # The concept pages carry no Chemical logic, so every brace seen here is
    # spurious. Checked separately so a real @{...} or @(...) expression can be
    # allow-listed by editing this line rather than by accident.
    rest = re.sub(r'<pre>.*?</pre>', '', block, flags=re.S)
    rest = rest.replace('#html {', '', 1).rstrip()
    if rest.endswith('}'):
        rest = rest[:-1]
    for m in re.finditer(r'(?<![@(])[{}]', rest):
        line = rest[:m.start()].count('\n') + 1
        ctx = rest[max(0, m.start() - 40):m.start() + 40].replace('\n', ' ')
        out.append('brace outside <pre> (block line ~%d): ...%s...'
                   % (line, ctx.strip()))
    return out


def unclosed(path):
    """Report tags opened but never closed in the #html block.

    html_cbi is a real parser, so an unclosed <a> or <p> does not degrade
    gracefully -- it drops the rest of the file out of the macro. Cheap to
    check, and it catches the class of mistake a div/pre counter cannot.
    """
    src = open(path).read()
    _s, _e, block = block_of(src)
    stack = []
    problems = []
    for m in ANY_TAG.finditer(block):
        closing, name = m.group(1), m.group(2).lower()
        if name in VOID:
            continue
        if closing:
            if name in stack:
                while stack and stack[-1] != name:
                    problems.append('</%s> closed while <%s> was still open'
                                    % (name, stack[-1]))
                    stack.pop()
                if stack:
                    stack.pop()
            else:
                problems.append('</%s> with no matching opener' % name)
        else:
            stack.append(name)
    for name in stack:
        problems.append('<%s> never closed' % name)
    # A closing tag whose '>' is missing is silent: the lexer keeps scanning
    # and blames whatever tag it finds next. Cheap to catch by shape.
    for m in re.finditer(r'</([a-zA-Z][a-zA-Z0-9]*)\s', block):
        ctx = block[max(0, m.start() - 30):m.start() + 30].replace('\n', ' ')
        problems.append('closing tag </%s has no ">" ...%s...'
                        % (m.group(1), ctx.strip()))
    return problems


def block_of(src):
    if '#html {' not in src:
        raise ValueError('no #html macro in this file (landing pages have '
                         'one, concept pages have one)')
    start = src.index('#html {')
    tail = len(src)
    for marker in ('render_lesson_js', '#css {', 'return page.toString()'):
        k = src.find(marker, start)
        if k >= 0:
            tail = min(tail, k)
    return start, tail, src[start:tail]


def repair(path, write=True):
    src = open(path).read()
    start, end, block = block_of(src)
    out = []
    stack = []
    i = 0
    changed = 0
    # Only div and pre are tracked; they are the only containers used in the
    # lesson markup, and a stray <p> or <span> is never a nesting problem.
    while i < len(block):
        mo = OPEN.search(block, i)
        mc = CLOSE.search(block, i)
        if mc and (not mo or mc.start() < mo.start()):
            out.append(block[i:mc.start()])      # text before the tag
            name = mc.group(1)
            if stack and stack[-1] == name:
                out.append(mc.group(0))
                stack.pop()
            else:
                # Mismatched. The correct closer is whatever is innermost.
                want = stack[-1] if stack else None
                if want:
                    out.append('</%s>' % want)
                    stack.pop()
                    changed += 1
                else:
                    out.append(mc.group(0))   # stray; drop it
                    changed += 1
            i = mc.end()
            continue
        if mo:
            out.append(block[i:mo.start()])
            out.append(mo.group(0))
            stack.append(mo.group(1))
            i = mo.end()
            continue
        out.append(block[i:])
        i = len(block)

    # Anything still open at the end is a missing closer.
    tail = ''
    while stack:
        tail += '</%s>' % stack.pop()
    if tail:
        changed += 1

    new = ''.join(out) + tail
    if write and new != block:
        whole = src[:start] + new + src[end:]
        # Never write a file that has lost its macro delimiters. A truncated
        # .ch file is unrecoverable if it was not committed, so this check is
        # the whole safety rail.
        for marker in ('#html {', 'render_lesson_css', 'render_lesson_js',
                       'public namespace', 'return page.toString()'):
            if marker in src and marker not in whole:
                raise AssertionError(
                    'refusing to write %s: repair dropped %r' % (path, marker))
        if len(whole) < len(src) * 0.9:
            raise AssertionError(
                'refusing to write %s: %d -> %d bytes'
                % (path, len(src), len(whole)))
        open(path, 'w').write(whole)
    return changed, stack


def report(path):
    src = open(path).read()
    _s, _e, block = block_of(src)
    o = len(re.findall(r'<div\b', block))
    c = len(re.findall(r'</div>', block))
    op = len(re.findall(r'<pre\b', block))
    cp = len(re.findall(r'</pre>', block))
    probs = unclosed(path) + macro_hazards(path)
    ok = (o == c and op == cp and not probs)
    print('%-34s div %3d/%-3d  pre %3d/%-3d  %s'
          % (path.split('/')[-1], o, c, op, cp,
             'ok' if ok else 'PROBLEM'))
    for q in probs:
        print('           %s' % q)
    return ok


if __name__ == '__main__':
    args = sys.argv[1:]
    # A verifier must not mutate what it verifies.  This tool used to REWRITE
    # every file it was pointed at unless `--check` was passed, and that is how
    # a page with a genuinely unbalanced div shipped and still read as balanced:
    # the repair appended the missing close at the end of the block with no
    # newline, after which the counts matched.  The check that was supposed to
    # catch the bug was the thing lying about it.
    #
    # So writing now requires `--repair`, and `--check` is accepted and ignored
    # so that existing callers -- and the four subagents' notes that say
    # "html_balance.py --check" -- keep working unchanged.
    write = '--repair' in args
    args = [a for a in args if a not in ('--check', '--repair')]
    allok = True
    for p in args:
        if write:
            n, leftover = repair(p)
            if n:
                print('repaired %d nesting error(s) in %s' % (n, leftover and p))
        allok &= report(p)
    sys.exit(0 if allok else 1)
