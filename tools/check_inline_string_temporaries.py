#!/usr/bin/env python3
"""check_inline_string_temporaries.py -- forbid `&string("...")` as an argument.

WHAT THIS IS FOR.  This is the regression test for the heap-corruption abort
that killed the server mid-audit (audit 2026-10-02, finding F5).  It exists
because the defect is a CODEGEN bug, so no runtime test can reliably catch a
repeat: the same program aborts sometimes and not others, depending on what the
previous request left on the worker thread's stack.

THE DEFECT.  Passing an inline `string(...)` temporary to a `&string` parameter

    send_error(res, 400u, &string("missing query param: q"))

makes the Chemical compiler emit, at the end of the enclosing scope:

    lea    -0x730(%rbp),%rax
    mov    %rax,%rdi
    call   std_stdstringdelete

`-0x730(%rbp)` is a stack slot the compiler allocated and NEVER wrote, and the
destroy is NOT guarded by a liveness flag.  Whatever the previous call at that
stack depth left behind is therefore interpreted as a `std::string`; if its
`state` byte reads '2' (heap) the compiler calls `free()` on a pointer that has
already been freed.  That is the `double free or corruption` / `free(): double
free detected in tcache 2` abort, and it is remote and unauthenticated.

The same source written as a named local takes the compiler's correct path --
the slot is initialised and the destroy is flag-guarded:

    var err_msg = string("missing query param: q")
    send_error(res, 400u, &err_msg)

which is why this check is a source lint rather than a runtime test.

SCOPE.  Every `.ch` file in the project.  The compiler emits the same bad code
for the std library, the HTTP server and the JSON parser, so the ban is
project-wide; a hit in a library file is still a hit worth reading.

Usage:  python3 tools/check_inline_string_temporaries.py
        python3 tools/check_inline_string_temporaries.py --verbose

Exit: 0 clean.  1 at least one `&string(...)` argument.
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# `&string("literal")` or `&string(other_expr)` used as a call argument.
SITE = re.compile(r'&\s*string\s*\(')

SKIP_DIRS = {'.git', 'build', 'lab', 'modules', 'remote', '__pycache__',
             'output', 'node_modules'}


def ch_files():
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(files):
            if f.endswith('.ch'):
                yield os.path.join(root, f)


def main():
    verbose = '--verbose' in sys.argv
    hits = []
    scanned = 0
    for path in ch_files():
        scanned += 1
        data = open(path, 'rb').read().decode('utf-8')
        lines = data.replace('\r\n', '\n').split('\n')
        for i, line in enumerate(lines, 1):
            if SITE.search(line):
                hits.append((os.path.relpath(path, REPO), i, line.strip()))

    print('check_inline_string_temporaries: scanned %d .ch files' % scanned)
    if not hits:
        print('  clean: no inline `&string(...)` temporary is passed as an argument')
        return 0

    print('')
    print('=== %d INLINE `&string(...)` TEMPORARY ARGUMENTS ===' % len(hits))
    for rel, line, text in hits:
        print('  %s:%d' % (rel, line))
        print('      %s' % text)
    print('')
    print('An inline `&string(...)` temporary makes the compiler destroy a stack')
    print('slot it never initialised, which double-frees whatever the previous')
    print('request left there.  Bind the string to a named local first:')
    print('    var err_msg = string("...")')
    print('    send_error(res, 400u, &err_msg)')
    return 1


if __name__ == '__main__':
    sys.exit(main())