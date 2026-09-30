#!/usr/bin/env python3
"""tagspace.py -- list places in a .ch source where a closing tag is followed
by a space and then a word.  The html_cbi lexer drops a same-line whitespace
run that starts immediately after a tag's '>' (html_parser
src/lexer/nextToken.ch, the `if(!is_boundary ...)` return), so `</a> word`
renders as `</a>word`.  Every shipped course avoids the construct by ending
the link on punctuation; this lists what still needs the same treatment.

Usage: python3 tools/tagspace.py content/src/*.ch
"""
import re
import sys

# a closing tag, then a run of spaces/tabs that contains no newline, then a word
PAT = re.compile(r'</([a-zA-Z][a-zA-Z0-9]*)>[ \t]+(?=[A-Za-z0-9])')

total = 0
for f in sys.argv[1:]:
    src = open(f).read().split('\n')
    n = 0
    for i, line in enumerate(src, 1):
        for m in PAT.finditer(line):
            n += 1
            if n <= 40:
                col = m.start()
                print('%s:%d:%d  </%s> %r' % (f, i, col, m.group(1),
                                             line[col:col + 46]))
    if n:
        print('  %-42s %d' % (f, n))
        total += n
print('TOTAL %d' % total)
