#!/usr/bin/env python3
r"""static_gate_negative_cases.py -- prove the six per-push source gates can fail.

H4. A source checker that exits 0 on a clean tree AND on a broken tree is
decoration. This tool breaks each of the six static/semantic gates in a
**disposable copy** of the tree and requires a non-zero exit. It deliberately
does NOT include the four live/tree-rebuild plants in checker_nonvacuity.py
whose controls are already red in this checkout; those are certified nightly
with named exclusions recorded in docs/deployment.md §5c.

Negative cases:
  check_inline_string_temporaries  plant `&string("...")` in web/src/helpers.ch
  sqli_scan                        its own --selftest plants an unescaped SQL interpolation
  bracecheck                       plant a raw `{` inside a #html block
  html_balance                     plant an unclosed <div>
  check_quotes                     plant a figure not present in the recorded artifact output
  js_escape_check                  make the checker model an INVALID \u{... escape

Every plant runs against a copy; the working tree and the database are never
touched. No network, no subprocess shell, no secrets.

Usage: python3 tools/static_gate_negative_cases.py
Exit:  0 all controls passed and all plants failed; 1 otherwise.
"""
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable
results = []


def run(cmd, cwd=None, timeout=600):
    try:
        p = subprocess.run(cmd, cwd=cwd or REPO, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        return -1, 'TIMEOUT'


def record(name, control_ok, plant_ok, note):
    results.append((name, control_ok, plant_ok))
    print('  %-36s control=%-4s plant=%-4s %s'
          % (name, 'ok' if control_ok else 'BROKEN',
             'FAIL as required' if plant_ok else 'VACUOUS', note))


def copy_tree(tmp):
    tree = os.path.join(tmp, 'r')
    shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
        '.git', 'build', 'output', 'node_modules', '__pycache__'))
    return tree


def plant_and_check(name, script, victim_rel, mutate, extra_args=()):
    rc, out = run([PY, script] + list(extra_args))
    if rc != 0:
        record(name, False, False, 'control already fails: %s' % out[-200:])
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = copy_tree(tmp)
        victim = os.path.join(tree, victim_rel.replace('/', os.sep))
        src = open(victim, encoding='utf-8').read()
        planted = mutate(src)
        if planted == src:
            record(name, True, False, 'plant did not apply (wrong source shape)')
            return
        with open(victim, 'w', encoding='utf-8') as fh:
            fh.write(planted)
        rc2, out2 = run([PY, script] + list(extra_args), cwd=tree)
    record(name, True, rc2 != 0, 'plant -> exit %d' % rc2)


def main():
    print('static_gate_negative_cases: breaking each per-push source gate in a copy')
    print()

    plant_and_check(
        'check_inline_string_temporaries',
        'tools/check_inline_string_temporaries.py',
        'web/src/helpers.ch',
        lambda s: s + ('\n// negative plant\n'
                       'public func zz_bad() : void {\n'
                       '    underlayer_web::send_error(400u, &string("bad"))\n'
                       '}\n'))

    # sqli_scan carries its own negative control.
    rc, out = run([PY, 'tools/sqli_scan.py', '--selftest'])
    record('sqli_scan --selftest', True, rc == 0 and 'SELFTEST OK' in out,
           'planted an unescaped interpolation -> %s' % out.strip().splitlines()[0])

    plant_and_check(
        'bracecheck', 'tools/bracecheck.py', 'content/src/bytes.ch',
        lambda s: s.replace('#html {', '#html {\n<p>raw { brace</p>', 1))

    plant_and_check(
        'html_balance', 'tools/html_balance.py', 'web/src/pages_search.ch',
        lambda s: s.replace('#html {', '#html {\n<div class="zz-unclosed">', 1))

    # check_quotes plants into a quoted <pre> block; reuse the certified
    # helper from checker_nonvacuity rather than inventing a weaker plant.
    sys.path.insert(0, os.path.join(REPO, 'tools'))
    import checker_nonvacuity as nv  # noqa: E402
    nv.results = []
    nv.check_quotes(False)
    r = nv.results[-1] if nv.results else ('check_quotes', False, False)
    record('check_quotes', r[1], r[2], 'certified plant from checker_nonvacuity')

    # A checker that models an escape incorrectly must notice. Put a malformed
    # escape in a COPY of the tool itself: node cannot parse `\u{B7` (no closing
    # brace), so every previously-passing codepoint must now fail.
    rc, out = run([PY, 'tools/js_escape_check.py'])
    if rc != 0:
        record('js_escape_check', False, False, 'control already fails')
    else:
        with tempfile.TemporaryDirectory() as tmp:
            tree = copy_tree(tmp)
            tool = os.path.join(tree, 'tools', 'js_escape_check.py')
            src = open(tool, encoding='utf-8').read()
            planted = src.replace("return '\\\\u{%X}' % cp",
                                  "return '\\\\u{%X' % cp", 1)
            if planted == src:
                record('js_escape_check', True, False, 'plant did not apply')
            else:
                with open(tool, 'w', encoding='utf-8') as fh:
                    fh.write(planted)
                rc2, _ = run([PY, 'tools/js_escape_check.py'], cwd=tree)
        record('js_escape_check', True, rc2 != 0,
               'malformed escape model -> exit %d' % rc2)

    print()
    bad = [r for r in results if not (r[1] and r[2])]
    if bad:
        print('static_gate_negative_cases: %d of %d gates could not be proven live'
              % (len(bad), len(results)))
        return 1
    print('static_gate_negative_cases: ALL %d gates pass on the real tree and '
          'FAIL when planted.' % len(results))
    return 0


if __name__ == '__main__':
    sys.exit(main())
