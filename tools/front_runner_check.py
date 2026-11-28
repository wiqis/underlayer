#!/usr/bin/env python3
"""front_runner_check.py -- E1 learner-authored runner checks.

Two halves:

  A. the PYTHON envelope.  Learner-authored parser code is sent as JSON to a
     short-lived subprocess with a scrubbed environment, an allowlisted AST,
     no filesystem/network builtins, bounded input and a strict 2 s timeout.
     Cases: correct code matches the verified AST by value; a wrong tree gets a
     calm specific error; open(), import and a dunder escape are refused; an
     infinite loop is killed by the timeout.

  B. the BROWSER runner (CDP via Playwright).  A real Chrome opens the static
     lesson from file://, the learner types a source expression, clicks Run,
     and the page tokenises/parses it with the lesson's code path and compares
     with an independent Pratt oracle.  A wrong expression gets a calm error;
     a snippet that tries file access is refused as source data.

No server route is added or assumed: this package owns only the course and
these two tools.  Nothing is committed or pushed.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SANDBOX = os.path.join(ROOT, 'courses', 'front', 'runner', 'sandbox.py')
PAGE = os.path.join(ROOT, 'courses', 'front', 'output', 'fe-ast.html')
TIMEOUT = 2.0

CORRECT = '''def parse_expr(tokens):
    return {"k": "num", "v": int(tokens[0][1])}
'''
WRONG = '''def parse_expr(tokens):
    return {"k": "num", "v": 43}
'''
FILE_ACCESS = '''def parse_expr(tokens):
    return open('/etc/passwd').read()
'''
NETWORK = '''def parse_expr(tokens):
    import socket
    return socket.socket()
'''
DUNDER = '''def parse_expr(tokens):
    return __import__('socket').socket()
'''
HANG = '''def parse_expr(tokens):
    while True:
        pass
'''


def invoke(code, source='42', timeout=TIMEOUT):
    """Run learner code in a fresh, constrained child process."""
    payload = json.dumps({'code': code, 'source': source})
    env = {'PATH': os.environ.get('PATH', ''),
           'SystemRoot': os.environ.get('SystemRoot', ''),
           'PYTHONIOENCODING': 'utf-8'}
    with tempfile.TemporaryDirectory(prefix='front-runner-') as cwd:
        started = time.monotonic()
        try:
            proc = subprocess.run([sys.executable, '-I', SANDBOX],
                                  input=payload, capture_output=True, text=True,
                                  timeout=timeout, env=env, cwd=cwd)
        except subprocess.TimeoutExpired:
            return {'ok': False, 'error': 'learner code timed out after 2 seconds',
                    'elapsed': time.monotonic() - started, 'killed': True}
        elapsed = time.monotonic() - started
    try:
        answer = json.loads(proc.stdout)
    except (ValueError, TypeError):
        answer = {'ok': False, 'error': 'runner returned no JSON',
                  'stderr': proc.stderr[-300:]}
    answer['elapsed'] = elapsed
    answer['killed'] = False
    return answer


def check_python_envelope():
    results = []

    def case(label, condition, detail):
        results.append((label, bool(condition), detail))
        print('  %-28s %s  %s' % (label, 'PASS' if condition else 'FAIL', detail))

    good = invoke(CORRECT)
    case('correct code matches by value',
         good.get('ok') and good.get('match') and
         good.get('ast') == {'k': 'num', 'v': 42},
         'ast=%s match=%s' % (good.get('ast'), good.get('match')))

    wrong = invoke(WRONG)
    case('wrong tree refused calmly',
         wrong.get('ok') and wrong.get('match') is False,
         'match=%s' % wrong.get('match'))

    f = invoke(FILE_ACCESS)
    case('file access refused',
         f.get('ok') is False and 'not available' in f.get('error', ''),
         repr(f.get('error')))

    net = invoke(NETWORK)
    case('network import refused',
         net.get('ok') is False and 'not available' in net.get('error', ''),
         repr(net.get('error')))

    dun = invoke(DUNDER)
    case('dunder escape refused',
         dun.get('ok') is False and 'not available' in dun.get('error', ''),
         repr(dun.get('error')))

    hang = invoke(HANG)
    case('timeout kills infinite loop',
         hang.get('killed') and 'timed out' in hang.get('error', '') and
         hang.get('elapsed', 0) < 5,
         'elapsed=%.2fs' % hang.get('elapsed', 0))

    huge = invoke(CORRECT, source='a' * 5000)
    case('bounded input refused',
         huge.get('ok') is False and '4096' in huge.get('error', ''),
         repr(huge.get('error')))
    return results


def reveal_units(page):
    """Leave the guided journey so the runner's unit is visible."""
    page.evaluate("""function () {
        if (typeof jqDeep === 'function') { try { jqDeep(); } catch (e) {} }
        var units = document.querySelectorAll('.unit');
        for (var i = 0; i < units.length; i = i + 1) {
            units[i].removeAttribute('hidden');
            if (units[i].style) { units[i].style.display = 'block'; }
        }
    }""")


def check_browser():
    results = []

    def case(label, condition, detail):
        results.append((label, bool(condition), detail))
        print('  %-28s %s  %s' % (label, 'PASS' if condition else 'FAIL', detail))

    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        print('  BROWSER SKIPPED: playwright unavailable: %s' % exc)
        return None
    if not os.path.isfile(PAGE):
        print('  BROWSER SKIPPED: generated page missing: %s' % PAGE)
        return None
    url = 'file:///' + PAGE.replace('\\', '/')
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(channel='chrome', headless=True)
            page = browser.new_page()
            errors = []
            page.on('pageerror', lambda exc: errors.append(str(exc)))
            page.goto(url, wait_until='load')
            page.wait_for_timeout(400)
            reveal_units(page)
            page.locator('#front-source').fill('a + 2 * (b - 3) / 4')
            page.locator('#front-run').click()
            verdict = page.locator('#front-verdict').text_content()
            output = page.locator('#front-output').text_content()
            case('browser specimen agrees',
                 'AGREE by value' in verdict and '11 tokens' in verdict and
                 '"k":"bin"' in output.replace(' ', ''),
                 repr(verdict))
            case('fixture checked in page',
                 'fixture' not in page.locator('#front-error').text_content(),
                 repr(page.locator('#front-error').text_content()))

            page.locator('#front-source').fill('a +')
            page.locator('#front-run').click()
            bad_error = page.locator('#front-error').text_content()
            case('wrong program calm error',
                 'expected more input' in bad_error and 'Traceback' not in bad_error,
                 repr(bad_error))

            page.locator('#front-source').fill("open('/etc/passwd')")
            page.locator('#front-run').click()
            file_error = page.locator('#front-error').text_content()
            case('file attempt refused as data',
                 'unexpected character' in file_error and 'Traceback' not in file_error,
                 repr(file_error))

            page.locator('#front-source').fill('-a * 2')
            page.locator('#front-run').click()
            unary = page.locator('#front-output').text_content()
            case('unary minus matches oracle',
                 'AGREE by value' in page.locator('#front-verdict').text_content() and
                 '"op":"USub"' in unary.replace(' ', ''),
                 repr(page.locator('#front-verdict').text_content()))

            case('no uncaught page errors', len(errors) == 0, repr(errors[:2]))
            browser.close()
    except Exception as exc:
        print('  BROWSER FAILED: %s: %s' % (type(exc).__name__, exc))
        return [(label, False, 'browser exception') for label, _, _ in results]
    return results


def main():
    print('learner-authored runner -- Python sandbox envelope:')
    py_results = check_python_envelope()
    print('\nlearner-authored runner -- real Chrome / CDP on the static page:')
    browser_results = check_browser()
    all_results = py_results + (browser_results or [])
    bad = [name for name, ok, _ in all_results if not ok]
    print('\nrunner checks: %d/%d pass%s' %
          (len(all_results) - len(bad), len(all_results),
           ' (browser unavailable, not counted)' if browser_results is None else ''))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
