#!/usr/bin/env python3
"""checker_nonvacuity.py -- prove each shipped checker FAILS when its claim breaks.

WHY THIS EXISTS.  This repo has been bitten by a checker that stopped comparing
and still printed the same number as one that was working -- the reason
tools/verify_rvasm.py exists, and the reason docs/implementation-gaps.md records
it.  A checker that cannot fail is worse than no checker, because it reads as
coverage in every status report that mentions it.  So each one here is broken on
purpose, in a COPY of the tree or against a copy of the served page, and has to
report the failure.

The negative control runs first for every checker: the real tree has to PASS.
A checker that fails the control is not evidence of anything, it is a broken
checker, and saying "it failed when I broke it" about a checker that also fails
when nothing is broken would be a lie.

WHAT IS PROVEN, AND HOW.

  bracecheck      a raw `{` planted inside a #html block must be reported
  nesting_check   a unit div wrapped one level too deep must be reported
  html_balance    an unclosed <div> must be reported
  link_check      an internal href that 404s must be reported
  nav_check       --expect-nav 0 must PASS (proving the assertion can be
                   relaxed, i.e. it is an assertion and not a constant) and a
                   page whose nav lacks /search must FAIL
  todo_check      a moved checkbox must be reported
  music_todo_check same
  check_quotes    a quoted figure with no matching recorded output must be
                   reported
  sqli_scan       --selftest plants an unescaped interpolation and asserts the
                   count rises by one
  security_check  --selftest asserts identical-vs-different is distinguishable
                   and a 64-hex legacy value is not classified as bcrypt
  route_check     --selftest plants a cross-learner leak and asserts it fires
  session_js_check  the 401 contract is restored to the old
                   "silent401 RETURNS the 401" shape and the checker must fail.
  lesson_pager_check  a LENGTH is passed to string_view.subview() where it
                   takes an END INDEX -- the actual defect that shipped, which
                   truncated every lesson page while every other gate stayed
                   green.  Both of these rebuild the tree, so --quick skips
                   them.

The tree-mutating checkers run against a full COPY of the repo, so this script
cannot damage the working tree even if it is killed midway.

Usage:
    python3 tools/checker_nonvacuity.py
    python3 tools/checker_nonvacuity.py --quick     # skip the slow copies

Exit: 0 every checker failed when its claim was broken.  1 otherwise.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable
results = []


def run(cmd, cwd=None, timeout=900):
    try:
        p = subprocess.run(cmd, cwd=cwd or REPO, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        return -1, 'TIMEOUT'


def record(name, control_ok, negative_ok, note):
    results.append((name, control_ok, negative_ok, note))
    print('  %-18s control(PASS expected)=%-5s negative(FAIL expected)=%-5s  %s'
          % (name, 'ok' if control_ok else 'BROKEN',
             'ok' if negative_ok else 'COULD NOT FAIL', note))


def check_bracecheck(quick):
    """Plant a raw `{` inside a #html block."""
    rc, _ = run([PY, 'tools/bracecheck.py'], timeout=900)
    if rc != 0:
        record('bracecheck', False, False, 'control already fails; skipped')
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = None
        # bracecheck's bare scan set is content/src + courses/*/src + web/src.
        for cand in ('content/src/bytes.ch', 'web/src/pages_search.ch'):
            p = os.path.join(tree, cand)
            if os.path.exists(p):
                victim = p
                break
        src = open(victim).read()
        i = src.find('#html {')
        assert i > 0, victim
        j = src.find('\n', i)
        broken = src[:j + 1] + '            <p>oops { not a tag</p>\n' + src[j + 1:]
        open(victim, 'w').write(broken)
        rc2, out = run([PY, 'tools/bracecheck.py'], cwd=tree, timeout=900)
    record('bracecheck', True, rc2 != 0,
           'planted a raw { in %s -> exit %d' % (os.path.basename(victim), rc2))


def check_nesting(quick):
    """Plant a `.unit unit-*` that is NOT a direct child of `.lesson`.

    Getting this plant right took two attempts and both failures were the plant,
    not the checker: nesting_check's assertion is "a unit div sits at
    lesson_depth + 1", so wrapping the units in one extra div is what breaks it.
    A plant that reproduces correct nesting proves nothing.
    """
    rc, _ = run([PY, 'tools/nesting_check.py'], timeout=900)
    if rc != 0:
        record('nesting_check', False, False, 'control already fails; skipped')
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        # nesting_check's bare scan set is content/src/*.ch, so plant there.
        victim = os.path.join(tree, 'content/src/zz_nonvacuity.ch')
        open(victim, 'w').write(
            'public namespace underlayer_content {\n'
            '    public func zz_probe() {\n'
            '        #html {\n'
            '            <div class="lesson">\n'
            '                <div class="planted-wrapper">\n'
            '                    <div class="unit">\n'
            '                        <p>one</p>\n'
            '                    </div>\n'
            '                    <div class="unit unit-exercises">\n'
            '                        <p>two</p>\n'
            '                    </div>\n'
            '                </div>\n'
            '            </div>\n'
            '        }\n'
            '    }\n'
            '}\n')
        rc2, out = run([PY, 'tools/nesting_check.py'], cwd=tree, timeout=900)
        caught = 'zz_nonvacuity' in out and 'swallows' in out
    record('nesting_check', True, rc2 != 0 and caught,
           'planted a .unit-exercises one level too deep -> exit %d, named=%s'
           % (rc2, caught))


def check_html_balance(quick):
    """Plant an unclosed <div>.

    html_balance used to take file paths as arguments and iterate over an EMPTY
    list when given none, so the bare invocation always exited 0.  It now has a
    default file set, which is what makes this plant meaningful -- and the fact
    that it needed one is itself the finding this checker just earned.
    """
    rc, out = run([PY, 'tools/html_balance.py'], timeout=900)
    if rc != 0:
        record('html_balance', False, False, 'control already fails; skipped')
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = os.path.join(tree, 'web/src/pages_search.ch')
        src = open(victim).read()
        i = src.find('#html {')
        j = src.find('\n', i)
        broken = src[:j + 1] + '            <div class="planted-unclosed">\n' + src[j + 1:]
        open(victim, 'w').write(broken)
        rc2, out2 = run([PY, 'tools/html_balance.py'], cwd=tree, timeout=900)
        caught = 'planted-unclosed' in out2 or 'never closed' in out2
    record('html_balance', True, rc2 != 0 and caught,
           'planted an unclosed <div> -> exit %d, named=%s' % (rc2, caught))


def check_link(quick):
    rc, _ = run([PY, 'tools/link_check.py'], timeout=900)
    if rc != 0:
        record('link_check', False, False, 'control already fails; skipped')
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = os.path.join(tree, 'web/src/pages_search.ch')
        src = open(victim).read()
        i = src.find('#html {')
        j = src.find('\n', i)
        broken = src[:j + 1] + '            <a href="/courses/zz-no-such-page">x</a>\n' + src[j + 1:]
        open(victim, 'w').write(broken)
        rc2, out2 = run([PY, 'tools/link_check.py'], cwd=tree, timeout=900)
    record('link_check', True, rc2 != 0,
           'planted an internal href that 404s -> exit %d' % rc2)


def check_nav(quick):
    """Two controls: the assertion must be relaxable, and it must fire."""
    rc_relaxed, _ = run([PY, 'tools/nav_check.py', '--expect-nav', '0'], timeout=900)
    rc_strict, _ = run([PY, 'tools/nav_check.py'], timeout=900)
    rc_bad, _ = run([PY, 'tools/nav_check.py', '--url', '/settings'], timeout=300)
    note = ('--expect-nav 0 exit %d (must be 0) ; strict exit %d (must be 0) ; '
            '/settings exit %d (must be nonzero: it has no navbar)'
            % (rc_relaxed, rc_strict, rc_bad))
    record('nav_check', rc_strict == 0 and rc_relaxed == 0, rc_bad != 0, note)


def check_todo(quick):
    for name, doc in (('todo_check', 'docs/courses-todo.md'),
                      ('music_todo_check', 'docs/music-plan.md')):
        rc, _ = run([PY, 'tools/%s.py' % name], timeout=600)
        if rc != 0:
            record(name, False, False, 'control already fails; skipped')
            continue
        with tempfile.TemporaryDirectory() as tmp:
            tree = os.path.join(tmp, 'r')
            os.makedirs(os.path.join(tree, 'tools'))
            os.makedirs(os.path.join(tree, 'docs'))
            shutil.copy(os.path.join(REPO, 'tools', '%s.py' % name),
                        os.path.join(tree, 'tools', '%s.py' % name))
            p = os.path.join(tree, doc)
            src = open(os.path.join(REPO, doc)).read()
            # flip the first two unchecked items to checked
            n = 0
            out = []
            for line in src.split('\n'):
                if n < 2 and re.match(r'^\s*-\s\[ \]', line):
                    line = line.replace('- [ ]', '- [x]', 1)
                    n += 1
                out.append(line)
            open(p, 'w').write('\n'.join(out))
            rc2, out2 = run([PY, 'tools/%s.py' % name], cwd=tree, timeout=600)
        record(name, True, rc2 != 0,
               'checked 2 items by hand -> exit %d' % rc2)


def check_quotes(quick):
    """Plant a quoted figure that is NOT in the recorded artifact output.

    check_quotes is scoped to ONE course (x86asm by default, overridable as
    argv[1]) and reads a fixed list of page files for it.  Two earlier plants
    missed: one put a plain decimal in a file outside that course's list, the
    other put a `ticks/op` figure in the same wrong place.  Both proved nothing
    about the checker.  This one plants into a file the checker is actually
    going to open, read from its own PAGES table.
    """
    rc, _ = run([PY, 'tools/check_quotes.py'], timeout=900)
    if rc != 0:
        record('check_quotes', False, False, 'control already fails; skipped')
        return
    src_tool = open(os.path.join(REPO, 'tools/check_quotes.py')).read()
    m = re.search(r'"x86asm":\s*\(([^)]*)\)', src_tool, re.S)
    if not m:
        record('check_quotes', True, False, 'could not read the PAGES table')
        return
    page = re.findall(r'"([^"]+\.ch)"', m.group(1))[0]
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = os.path.join(tree, 'content/src', page)
        if not os.path.exists(victim):
            record('check_quotes', True, False,
                   '%s is in the PAGES table but not on disk' % page)
            return
        src = open(victim).read()
        # It must go INSIDE a quoted-output block: the checker only reads
        # <pre>...</pre> that also contains a shell prompt or a known artifact
        # command, because a page's prose decimals are the author's arithmetic
        # and not the artifact's.  Two earlier plants went into a <p>, which the
        # checker is right to ignore -- so the plant was wrong, twice, and a
        # checker that ignores prose is not a broken checker.
        blocks = list(re.finditer(r'<pre>(.*?)</pre>', src, re.S))
        target = None
        for b in blocks:
            inner = b.group(1)
            if '$ ' in inner or 'x86dec' in inner:
                target = b
                break
        if target is None:
            record('check_quotes', True, False,
                   '%s has no <pre> block with a prompt to plant into' % page)
            return
        plant = ('Measured 412.500 ticks/op on this machine.\n'
                 '$ ')
        broken = (src[:target.start(1)] + plant + src[target.start(1):])
        open(victim, 'w').write(broken)
        rc2, out2 = run([PY, 'tools/check_quotes.py'], cwd=tree, timeout=900)
        named = '412.500' in out2
    record('check_quotes', True, rc2 != 0 and named,
           'planted "412.500 ticks/op" inside a quoted <pre> block of %s '
           '-> exit %d, named=%s' % (page, rc2, named))


def check_selftests(quick):
    for name, script in (('sqli_scan', 'tools/sqli_scan.py'),
                         ('security_check', 'tools/security_check.py'),
                         ('route_check', 'tools/route_check.py')):
        rc, out = run([PY, script, '--selftest'], timeout=900)
        ok = rc == 0 and 'FAIL' not in out.upper().replace('SELFTEST FAIL', '')
        record(name + ' --selftest', True, ok,
               ('its own negative control ran' if ok
                else 'the selftest did not pass on a clean tree (exit %d)' % rc))


def check_session_js(quick):
    """Prove session_js_check.js can fail.

    A grep is not a test here.  The js_cbi macro rewrites `function(){}` into
    `(function(){})`, so the text a grep would look for is not the text that
    ships, and "the helper is in the HTML" proves nothing about whether it
    works.  session_js_check.js therefore extracts the REAL emitted script and
    executes it in Node against a DOM stub -- which means its assertions have to
    be shown failing, or it is one macro change away from being decoration.

    The plant is the smallest one that matters: restore the old 401 contract in
    web/src/session_js.ch (honour `silent401` by RETURNING the 401 instead of
    rejecting it).  That is the exact shape that made callers parse
    `{"error":"unauthorized"}` as data, so if this checker cannot see it, the
    checker is not looking at the thing it claims to look at.

    This one builds the tree, so it needs the compiler; --quick skips it.
    """
    rc, out = run(['node', 'tools/session_js_check.js',
                   os.environ.get('UL_BASE_URL', 'http://localhost:9000')],
                  timeout=900)
    if rc != 0:
        record('session_js_check', False, False,
               'control already fails on the real server; skipped')
        return
    if quick:
        record('session_js_check', True, False, 'skipped by --quick')
        return
    compiler = find_compiler()
    if not compiler:
        record('session_js_check', True, False, 'no compiler found; skipped')
        return
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = os.path.join(tree, 'web/src/session_js.ch')
        src = open(victim).read()
        planted = src.replace('if (r.status === 401) {',
                               'if (r.status === 401 && !opts.silent401) {', 1)
        if planted == src:
            record('session_js_check', True, False,
                   'the plant did not apply -- the 401 guard is not in the '
                   'shape this check expects')
            return
        open(victim, 'w').write(planted)
        port = free_port()
        rc2, _ = run([compiler, 'chemical.mod', '-o',
                      os.path.join(tree, 'build/underlayer.exe'),
                      '-bm-modules', '--no-cache', '--mode', 'debug_quick'],
                     cwd=tree, timeout=1800)
        if rc2 != 0:
            record('session_js_check', True, False,
                   'the planted tree did not build (exit %d)' % rc2)
            return
        exe = os.path.join(tree, 'build/underlayer.exe')
        srv = subprocess.Popen([exe], cwd=tree,
                               env=dict(os.environ, PORT=str(port),
                                        DATABASE_URL=os.path.join(tree, 'nv.db')),
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
        try:
            base = 'http://localhost:%d' % port
            if not wait_for_health(base, 60):
                record('session_js_check', True, False,
                       'the planted server never came up')
                return
            rc3, out3 = run(['node', 'tools/session_js_check.js', base],
                            timeout=900)
            caught = rc3 != 0 and '401' in out3
        finally:
            srv.terminate()
            try:
                srv.wait(timeout=20)
            except Exception:
                srv.kill()
    record('session_js_check', True, caught,
           'restored the old silent401-returns-the-401 contract -> exit %d, '
           'named=%s' % (rc3, caught))


def check_lesson_pager(quick):
    """Prove lesson_pager_check.py can fail, by reintroducing the bug it exists
    for: passing a LENGTH to string_view.subview() where it takes an END INDEX.

    This is the only plant in this file that reproduces a bug that shipped for
    a while without ANY gate noticing.  Every lesson page was served truncated
    -- bytes 65,866 -> 24,934, cut off mid-attribute -- while the server stayed
    healthy, every route answered 200, nav_check reported 447 good pages and
    link_check reported 462 good links.  A status code and a link target are
    both still valid in a document that has lost two thirds of itself.

    So the plant is worth more than a made-up one: it is the actual defect,
    and the checker either sees it or it does not deserve to exist.
    """
    rc, out = run([PY, 'tools/lesson_pager_check.py',
                   os.environ.get('UL_BASE_URL', 'http://localhost:9000')],
                  timeout=900)
    if rc != 0:
        record('lesson_pager_check', False, False,
               'control already fails on the real server; skipped')
        return
    if quick:
        record('lesson_pager_check', True, False, 'skipped by --quick')
        return
    compiler = find_compiler()
    if not compiler:
        record('lesson_pager_check', True, False, 'no compiler found; skipped')
        return
    victim_rel = os.path.join('web', 'src', 'lesson_pager.ch')
    with tempfile.TemporaryDirectory() as tmp:
        tree = os.path.join(tmp, 'r')
        shutil.copytree(REPO, tree, ignore=shutil.ignore_patterns(
            '.git', 'build', 'output', 'node_modules', '__pycache__'))
        victim = os.path.join(tree, victim_rel)
        src = open(victim).read()
        planted = src.replace('src.to_view().subview(after, src.size())',
                              'src.to_view().subview(after, src.size() - after)', 1)
        if planted == src:
            record('lesson_pager_check', True, False,
                   'the plant did not apply -- subview() is not called in the '
                   'shape this check expects')
            return
        open(victim, 'w').write(planted)
        rc2, _ = run([compiler, 'chemical.mod', '-o',
                      os.path.join(tree, 'build/underlayer.exe'),
                      '-bm-modules', '--no-cache', '--mode', 'debug_quick'],
                     cwd=tree, timeout=1800)
        if rc2 != 0:
            record('lesson_pager_check', True, False,
                   'the planted tree did not build (exit %d)' % rc2)
            return
        exe = os.path.join(tree, 'build/underlayer.exe')
        srv = subprocess.Popen([exe], cwd=tree,
                               env=dict(os.environ, PORT='9121',
                                        DATABASE_URL=os.path.join(tree, 'nv2.db')),
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
        try:
            base = 'http://localhost:9121'
            if not wait_for_health(base, 60):
                record('lesson_pager_check', True, False,
                       'the planted server never came up')
                return
            rc3, out3 = run([PY, 'tools/lesson_pager_check.py', base], timeout=900)
            caught = rc3 != 0 and 'truncated' in out3
        finally:
            srv.terminate()
            try:
                srv.wait(timeout=20)
            except Exception:
                srv.kill()
    record('lesson_pager_check', True, caught,
           'passed a LENGTH to subview() where it takes an END INDEX -> every '
           'lesson page truncated -> exit %d, named=%s' % (rc3, caught))


def find_compiler():
    """The Chemical compiler, the same way scripts/_common.sh looks for it."""
    env = os.environ.get('CHEMICAL_ROOT')
    if env:
        for sub in ('cmake-build-debug', 'build', '.'):
            for name in ('TCCCompiler', 'TCCCompiler.exe'):
                cand = os.path.join(env, sub, name)
                if os.path.isfile(cand):
                    return cand
    for root in ('/tmp/opencode/asan-build',):
        cand = os.path.join(root, 'TCCCompiler')
        if os.path.isfile(cand):
            return cand
    return None


def free_port():
    import socket
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]
    s.close()
    return port


def wait_for_health(base, seconds):
    import urllib.request
    for _ in range(seconds):
        try:
            with urllib.request.urlopen(base + '/api/health', timeout=5) as r:
                if r.getcode() == 200:
                    return True
        except Exception:
            pass
        time.sleep(1)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quick', action='store_true')
    args = ap.parse_args()
    print('checker_nonvacuity: proving each checker fails when its claim breaks')
    print()
    print('--- tree-mutating checkers, run against a COPY of the repo ---')
    check_bracecheck(args.quick)
    check_nesting(args.quick)
    check_html_balance(args.quick)
    check_link(args.quick)
    print()
    print('--- checkers with their own negative controls ---')
    check_selftests(args.quick)
    check_nav(args.quick)
    check_session_js(args.quick)
    check_lesson_pager(args.quick)
    print()
    print('--- document checkers ---')
    check_todo(args.quick)
    check_quotes(args.quick)
    print()
    bad = [r for r in results if not (r[1] and r[2])]
    for name, c, n, note in results:
        if not c:
            print('  NOTE: %s control did not pass (%s)' % (name, note))
    print()
    if bad:
        print('checker_nonvacuity: %d of %d checkers could not be proven live'
              % (len(bad), len(results)))
        return 1
    print('checker_nonvacuity: ALL %d checkers PASS on the real tree and FAIL '
          'when broken.' % len(results))
    print()
    print('  That is the difference between a checker and a comment.  A checker')
    print('  that cannot fail is worse than none, because it reads as coverage.')
    return 0


if __name__ == '__main__':
    sys.exit(main())