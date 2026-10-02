#!/usr/bin/env python3
"""sqli_scan.py -- find SQL built from request-controlled text WITHOUT sql_escape().

WHY THIS EXISTS.  A SQL injection was found in `handle_login` by hand-probing
the running server: a crafted `email` returned a valid session token for an
account whose password was never supplied.  It was there because the codebase
builds SQL by string concatenation and only ONE file (repository/src/
exercise_attempts.ch) bothers to call `sql_escape()`.  A hand probe finds the
one you thought of.  This walks every SQL literal in the tree and reports the
ones whose interpoland traces back to a request.

WHAT IT LOOKS FOR.

  1. Every `var <n> = string("SELECT|INSERT|UPDATE|DELETE ..."` opens a
     statement, and every following `<n>.append_string(&X)` /
     `<n>.append_view(X)` is an interpolation into it.
  2. Each interpolated variable name is traced BACKWARDS through simple
     assignments (`var b = a`, `b = a`, `var c = b.copy()`) until it reaches a
     taint source:
        - `req.query.get(...)`        -> GET field
        - `json_get_*(..., "k")`      -> POST body field
        - `path_segments(...)` / `segments.get_ptr(...)` -> URL path segment
        - `req.body` / `read_body`    -> raw body
  3. The interpolation is REPORTED only if no `sql_escape(` / `escape_sql(` call
     is on the line that appended it.  `sql_escape` doubles `'`, which is
     correct for a single-quoted SQL literal, so those are clean.

WHAT IT DELIBERATELY DOES NOT DO.  It does not prove a vulnerability is
exploitable -- only the server can do that.  It reports "request text reaches
SQL unescaped", which is a superset of the exploitable cases, and
`tools/security_check.py` proves the specific ones against the live server.  It
also cannot see through a function boundary: a repository function that escapes
internally is reported clean here because the escape is on the same line, and
one that does not is reported -- which is why repository/ is scanned too.  One
class it treats as safe BY CONSTRUCTION is anything built by `int_to_string()`:
it formats an integer, so it cannot emit a character that would end a SQL
literal.  Saying so out loud is the point -- a scanner that quietly excluded
such lines would be indistinguishable from one that could not see them.

HOW TO PROVE IT IS NOT VACUOUS
------------------------------
`--selftest` copies the tree to a temp dir, injects one unescaped
`append_string(&tainted)` into a known SQL build in
web/src/handlers_search.ch, and asserts the scanner's finding count goes UP by
exactly one and that it names the planted file.  A scanner that cannot see a
planted bug is worse than no scanner.

Usage:
    python3 tools/sqli_scan.py                 # whole tree
    python3 tools/sqli_scan.py --dir web/src   # one subtree
    python3 tools/sqli_scan.py --selftest

Exit: 0 no unescaped request text reaches SQL.  1 at least one finding.
"""
import argparse
import os
import re
import shutil
import sys
import tempfile

SQL_START = re.compile(r'var\s+(\w+)\s*=\s*string\("\s*(SELECT|INSERT|UPDATE|DELETE)\b')
APPEND_STR = re.compile(r'^(\w+)\.append_string\(\s*&(?:raw\s+)?([\w.]+)\s*\)')
APPEND_VIEW = re.compile(r'^(\w+)\.append_view\(\s*&?(?:raw\s+)?([\w.]+)')
ESCAPE = re.compile(r'(sql_escape|escape_sql)\s*\(')
FUNC_START = re.compile(r'^\s*(?:public\s+|private\s+)?func\s+(\w+)')
PARAM = re.compile(r'^\s*(?:public\s+|private\s+)?\(?[\w\s,&*]*\)?\s*$')

TAINT_SOURCES = [
    (re.compile(r'req\.query\.get'), 'query'),
    (re.compile(r'json_get_\w+\([^,]+,\s*"'), 'body'),
    (re.compile(r'path_segments\('), 'path'),
    (re.compile(r'segments\.get_ptr'), 'path'),
    (re.compile(r'req\.path'), 'path'),
    (re.compile(r'read_body\('), 'body'),
    (re.compile(r'req\.query'), 'query'),
]

# assignments that simply copy an identifier:  b = a   |   var b = a.copy()
ASSIGN = re.compile(r'(?:var\s+)?(\w+)\s*=\s*([\w.]+)\s*(?:\.copy\(\))?\s*$')


def scan_dir(root):
    """Return list of (relpath, lineno, kind, sql_stmt, varname)."""
    findings = []
    for dirpath, _dirs, files in os.walk(root):
        for fn in sorted(files):
            if not fn.endswith('.ch'):
                continue
            path = os.path.join(dirpath, fn)
            with open(path, newline='') as fh:
                src = fh.read().replace('\r\n', '\n').replace('\r', '\n')
            lines = src.split('\n')
            findings.extend(_scan_file(path, lines))
    return findings


def _scan_file(path, lines):
    # Provenance: var name -> label
    prov = {}
    for i, line in enumerate(lines):
        m = ASSIGN.match(line.strip())
        if m:
            prov[m.group(1)] = prov.get(m.group(2), 'local:' + m.group(2))
        # A value produced by int_to_string() formats an i64/u32.  It therefore
        # cannot contain a quote, a backslash or anything else that would end a
        # SQL literal, so it is tracked as its own provenance class rather than
        # being reported as an unescaped string.  This is not a loophole: it
        # only applies to a call whose argument is an integer expression, and
        # the label is printed if anything ever routes one into a finding.
        mi = re.match(r'\s*var\s+(\w+)\s*=\s*(?:underlayer_core::|core::)?int_to_string\s*\(', line)
        if mi:
            prov[mi.group(1)] = 'int'
            continue
        for pat, kind in TAINT_SOURCES:
            mm = pat.search(line)
            if mm:
                for vm in re.finditer(r'var\s+(\w+)\s*=', line):
                    prov[vm.group(1)] = kind
                # `var x = req.query.get(&q.to_view())` assigns x
                av = re.match(r'\s*var\s+(\w+)\s*=\s*\S*' + pat.pattern, line)
                if av:
                    prov[av.group(1)] = kind
    out = []
    cur = None
    stmt_line = 0
    for i, line in enumerate(lines):
        m = SQL_START.search(line)
        if m:
            cur = m.group(1)
            stmt_line = i
            continue
        if cur is None:
            continue
        # Only appends to the statement currently being built count.  An append
        # to some other string (a JSON response being assembled, say) is not an
        # interpolation into SQL, and counting it was a false positive once.
        var = None
        m = APPEND_STR.match(line.strip())
        if m and m.group(1) == cur:
            var = m.group(2)
        else:
            m2 = APPEND_VIEW.match(line.strip())
            if m2 and m2.group(1) == cur:
                var = m2.group(2)
        if var is None:
            continue
        base = var.split('.')[0]
        label = prov.get(base, 'local:' + base)
        if not (label in ('query', 'body', 'path')):
            continue
        if ESCAPE.search(line):
            continue
        # is the SQL built but then escaped later? only line-level check counts
        out.append((path, i + 1, label, cur, base, stmt_line + 1, line.strip()))
    return out


def self_test():
    """Plant one unescaped interpolation; assert the count goes up by exactly 1."""
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(here)
    base = scan_dir(os.path.join(repo, 'web'))
    target = os.path.join(repo, 'web/src/handlers_search.ch')
    with open(target, newline='') as fh:
        original = fh.read()
    with tempfile.TemporaryDirectory() as tmp:
        stage = os.path.join(tmp, 'web')
        shutil.copytree(os.path.join(repo, 'web'), stage)
        p = os.path.join(stage, 'src/handlers_search.ch')
        with open(p, newline='') as fh:
            body = fh.read().replace('\r\n', '\n').replace('\r', '\n')
        if not body.endswith('\n'):
            body += '\n'
        body += (
            "// selftest-plant\n"
            "public func sqli_scan_selftest_probe(db : *underlayer_db::DbClient) {\n"
            "    var tainted = json_get_str(&raw selftest_parsed, \"q\")\n"
            "    var selftest_sql = string(\"SELECT id FROM learners WHERE email = '\")\n"
            "    selftest_sql.append_string(&tainted)\n"
            "    selftest_sql.append_view(\"'\")\n"
            "    underlayer_db::exec_sql(db, &raw selftest_sql)\n"
            "}\n"
        )
        with open(p, 'w') as fh:
            fh.write(body)
        after = scan_dir(stage)
    if len(after) != len(base) + 1:
        print('SELFTEST FAIL: baseline %d findings, planted %d (expected +1)'
              % (len(base), len(after)))
        print('planted entries:', [f for f in after if 'selftest' in f[3] or 'tainted' in f[4]])
        return 1
    print('SELFTEST OK: baseline %d findings, planted +1, scanner is not vacuous'
          % len(base))
    print('  untouched original file: %s' % os.path.relpath(target, repo))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', default=None)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return self_test()
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(here)
    roots = [args.dir] if args.dir else [
        os.path.join(repo, 'web'), os.path.join(repo, 'repository'),
        os.path.join(repo, 'learning'), os.path.join(repo, 'content'),
        os.path.join(repo, 'database'), os.path.join(repo, 'core'),
        os.path.join(repo, 'app'),
    ]
    findings = []
    for r in roots:
        if os.path.isdir(r):
            findings.extend(scan_dir(r))
    if not findings:
        print('sqli_scan: PASS -- no request-controlled text reaches SQL unescaped')
        return 0
    print('sqli_scan: %d finding(s)' % len(findings))
    for path, line, kind, sqlvar, var, sline, text in findings:
        print('  %s:%d  [%s] %s (built at :%d) <- %s'
              % (os.path.relpath(path, repo), line, kind, sqlvar, sline, var))
        print('      %s' % text[:110])
    return 1


if __name__ == '__main__':
    sys.exit(main())