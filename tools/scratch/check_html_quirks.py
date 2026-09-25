#!/usr/bin/env python3
"""Check #html blocks in content/src/*.ch for constructs html_cbi rejects.

Deliberately narrow. It reports only the two failure modes that are cheap to
detect mechanically and expensive to find by reading a compiler error, because
both of them point at the wrong column:

  * a literal '{' or '}' as text or inside <pre><code>
  * a '<' immediately followed by a digit, which is read as a tag name

It does NOT try to check attribute quoting, tag balance, or entity placement.
Those either need a real parser or produce more noise than signal -- an earlier
version of this script did all three and was useless. When a #html block fails
to parse for another reason, isolate it: drop a file into content/src/ with one
`#html { ... }` function per suspect, and remember it needs
`public namespace ... { using std::string ... }` and must NOT repeat the
import lines, because the parent chemical.mod already supplies page, html_cbi,
css_cbi and js_cbi.

    python3 tools/check_html_quirks.py [content/src/*.ch]
"""
import re
import sys
from glob import glob

BRACE_OK = re.compile(r'&(?:#\d+|[a-zA-Z]+);')
# A brace pair around an identifier is Chemical's own interpolation syntax and
# is the reason braces appear in #html at all -- {esc_difficulty} is required,
# not a literal. Only a brace that is NOT an interpolation is the problem.
INTERP = re.compile(r'\{[A-Za-z_][A-Za-z0-9_.]*(?:\([^)]*\))?\}')
# A literal brace inside an ATTRIBUTE VALUE is fine: the lexer treats the
# contents of onclick="..." as opaque text, which is why
# onclick="window.scrollTo({top:0})" compiles. Only a brace that appears as
# element text -- in prose, or inside <pre><code> -- aborts the parse.
ATTR = re.compile(r'="[^"]*"')


def check(path):
    problems = []
    in_html = False
    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        if '#html {' in line:
            in_html = True
            continue
        if '#css {' in line or '#js {' in line:
            in_html = False
            continue
        # A '}' in column 1 closes the function or the namespace, so the #html
        # block is over. Files with no #css and no #js would otherwise be
        # scanned to end-of-file, reporting every one of their closing braces.
        if in_html and line.startswith('}'):
            in_html = False
            continue
        if not in_html:
            continue
        # the #html macro's own closer, indented one level
        if line.strip() == '}' and line.startswith('    '):
            continue

        # 1. literal braces as element text, ignoring both the entities that
        #    fix it and anything inside an attribute value
        stripped = INTERP.sub('', ATTR.sub('', BRACE_OK.sub('', line)))
        if '{' in stripped or '}' in stripped:
            hits = [c for c in stripped if c in '{}']
            problems.append((n, 'literal %s as element text -- use &#123; / '
                                '&#125;' % hits[0]))

        # 2. a '<' followed by a digit is read as a tag name
        for m in re.finditer(r'<\d', ATTR.sub('', line)):
            problems.append((n, "'<' followed by a digit at column %d is read "
                                "as a tag -- use &lt;" % (m.start() + 1)))
    return problems


def main():
    files = sys.argv[1:] or sorted(glob('content/src/*.ch'))
    total = 0
    for path in files:
        for n, msg in check(path):
            print('  %s:%d  %s' % (path, n, msg))
            total += 1
    print()
    if total:
        print('%d problem(s)' % total)
        return 1
    print('no #html construct problems found in %d files' % len(files))
    return 0


if __name__ == '__main__':
    sys.exit(main())
