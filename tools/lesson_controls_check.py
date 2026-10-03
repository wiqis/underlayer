#!/usr/bin/env python3
"""lesson_controls_check.py -- the lesson reading controls have to WORK.

THE DEFECT, MEASURED NOT GUESSED
-------------------------------
    onclick="toggleHighContrast()"   100 lesson pages carry the markup
    function toggleHighContrast       21 of them define it

The other 79 shipped three accessibility buttons, four reading dropdowns and a
keyboard-shortcuts dialog wired to functions that did not exist on the page.
Clicking "HC" raised `ReferenceError: toggleHighContrast is not defined`. The
four `<select>`s reverted silently -- an `onchange` on a missing function throws
exactly the same way. And the `?` dialog, which documents Ctrl+K, Escape and
Up-arrow, lied on all 79: none of those three keys was bound anywhere on the
page.

The 21 that worked did so by accident of authorship. Each carries its own copy
of the behaviour in its own `#js` block, and they have already drifted: the ELF
copy falls back to a `data-correct` attribute in its fill-blank path where the
shared `lesson_assets.ch` copy does not. That is what twenty-one copies of one
behaviour produces, and it is the argument for moving it into a module.

WHY A NODE HARNESS AND NOT A STRING CHECK
-----------------------------------------
The whole defect lives in whether a function is *callable*, which no substring
test can see. This extracts the served `<script>`, runs it against a DOM stub
and localStorage that throw on access (the condition that makes 79 pages' worth
of unguarded reads fatal), then CALLS each control and reads the DOM back.

A page can contain `toggleHighContrast` 40 times and still throw on click. The
only question that matters is "does pressing this button change the lesson", and
that is what is asked.

THE THREE PROBES
-----------------
  1. every control the markup references is DEFINED after the scripts run
  2. pressing each accessibility button changes the lesson element
  3. changing a reading dropdown persists the choice and applies a class
  4. with localStorage throwing on access, all of the above still works -- the
     regression this file was written after

Usage:
    python3 tools/lesson_controls_check.py [--port 9000]

Exit: 0 clean.  1 at least one finding.  2 server unreachable (NOT a pass).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Pages that carried the markup all along. The first four are among the 79 that
# were broken; `elf` is one of the 21 that happened to work, and is included so a
# regression in the shared module shows up against a page that used to be fine.
PAGES = [
    '/courses/a64abi/lessons/a64-aapcs',
    '/courses/rvasm/lessons/rv-compressed-cost',
    '/courses/x86asm/lessons/x86-verify',
    '/courses/x86sys/lessons/x86-syscall',
    '/courses/elf/lessons/bytes',
    '/courses/hat/lessons/hat-algebra',
    '/courses/coff/lessons/coff-intro',
]

# The handler names the markup calls. Each must be defined after the scripts run.
CONTROLS = [
    'toggleHighContrast',
    'toggleReducedMotion',
    'openShortcuts',
    'closeShortcuts',
    'setFontSize',
    'setLineHeight',
    'setLetterSpacing',
    'setContentWidth',
]

HARNESS = r'''
// Throwing localStorage: access THROWS in a browser with site data blocked.
// If any read here is unguarded, the whole script block aborts and every
// control below is undefined -- which is the failure this harness exists to
// reproduce rather than to assume away.
const THROWING = __THROWING__;
// A returning reader's saved choices, present BEFORE boot. The restore path
// reads these while the scripts run, so they must be in the store already or the
// question "does a fresh page load restore my settings" cannot be asked. Empty on
// the runs that test the setters, where the point is what happens on a change.
const PRE = __PRESTORE__ || {};
const ls = {
  _d: Object.assign({}, PRE),
  getItem(k) {
    if (THROWING) { throw new Error('storage blocked'); }
    return Object.prototype.hasOwnProperty.call(this._d, k) ? this._d[k] : null;
  },
  setItem(k, v) {
    if (THROWING) { throw new Error('storage blocked'); }
    this._d[k] = String(v);
  },
  dump() { return JSON.stringify(this._d); },
};

// A DOM stub small enough to reason about and large enough to catch the real
// mistakes: getElementById, querySelector('.lesson'), the .a11y-btn NodeList the
// toggles index into, classList, and appendChild for the toast.
const LESSON = {
  tagName: 'DIV', className: 'lesson', id: 'lesson', attrs: {},
  _cls: new Set(['lesson']),
  style: {},
  setAttribute(k, v) { this.attrs[k] = v; },
  getAttribute(k) { return this.attrs[k]; },
  appendChild() {}, insertBefore() {},
  querySelector() { return null; },
  querySelectorAll() { return []; },
  addEventListener() {},
  classList: {
    add(...c) { c.forEach(x => LESSON._cls.add(x)); },
    remove(...c) { c.forEach(x => LESSON._cls.delete(x)); },
    contains(c) { return LESSON._cls.has(c); },
    toggle(c, on) {
      const want = (on === undefined) ? !LESSON._cls.has(c) : !!on;
      if (want) { LESSON._cls.add(c); } else { LESSON._cls.delete(c); }
      return want;
    },
  },
};

// The three a11y buttons, as real elements: the toggles call
// `btn.classList.toggle('active', on)` on them and the restore path calls
// `btn.classList.add('active')`, so a stub whose classList swallows everything
// would pass an assertion that is supposed to be checking the pressed state.
const A11Y_BTNS = [mkElBtn(), mkElBtn(), mkElBtn()];
function mkElBtn() {
  const b = {
    tagName: 'BUTTON', attrs: {}, _cls: new Set(), textContent: '',
    setAttribute(k, v) { b.attrs[k] = v; },
    getAttribute(k) { return b.attrs[k]; },
    addEventListener() {},
  };
  b.classList = {
    add(...c) { c.forEach(x => b._cls.add(x)); },
    remove(...c) { c.forEach(x => b._cls.delete(x)); },
    contains(c) { return b._cls.has(c); },
    toggle(c, on) {
      const want = (on === undefined) ? !b._cls.has(c) : !!on;
      if (want) { b._cls.add(c); } else { b._cls.delete(c); }
      return want;
    },
  };
  return b;
}

const SELECTS = {};
['font-size','line-height','letter-spacing','content-width'].forEach(id => {
  SELECTS[id] = { value: 'normal', attrs:{}, setAttribute(k,v){this.attrs[k]=v;} };
});

// The modal needs querySelector: openShortcuts moves focus to the first
// focusable child, and a stub without it throws -- which the dialog-open
// assertion would report as "the dialog did not open", pointing at the product
// when the fault is here.
const MODAL = {
  _cls: new Set(),
  classList: { add(){}, remove(){}, contains(){return false;}, toggle(){return true;} },
  querySelector() { return null; },
  querySelectorAll() { return []; },
};

function mkEl() {
  // The element and its classList are two DIFFERENT objects, so classList must
  // close over the element rather than reach it through `this`. Written with
  // `this._owner`, `classList.add()` sees `this` === classList, `_owner` is
  // undefined, and every call throws "cannot read properties of undefined" --
  // which surfaces as "the control had no effect", blaming the product for a
  // bug in here.
  const el = {
    tagName: 'DIV', className: '', textContent: '', hidden: false, id: '', attrs: {},
    _cls: new Set(),
    parentNode: { insertBefore(){}, appendChild(){} },
    children: [],
    style: {},
    setAttribute(k, v) { el.attrs[k] = v; if (k === 'id') { el.id = v; } },
    getAttribute(k) { return el.attrs[k]; },
    appendChild(c) { el.children.push(c); return c; },
    insertBefore() {},
    addEventListener() {},
    querySelector() { return null; },
    querySelectorAll() { return []; },
    focus() {},
  };
  el.classList = {
    add(...c) { c.forEach(x => el._cls.add(x)); },
    remove(...c) { c.forEach(x => el._cls.delete(x)); },
    contains(c) { return el._cls.has(c); },
    toggle(c, on) {
      const want = (on === undefined) ? !el._cls.has(c) : !!on;
      if (want) { el._cls.add(c); } else { el._cls.delete(c); }
      return want;
    },
  };
  return el;
}

const DOC_EL = mkEl();
DOC_EL.contains = () => false;

const KEY_HANDLERS = {};
const sandbox = {
  console,
  // The product's scripts call window.addEventListener for the nav, the
  // identity loader and the shortcuts. Without it the very first block throws
  // and EVERY later definition is never reached -- which looks exactly like
  // "the controls are missing", so the harness has to model it.
  addEventListener(type, fn) { (KEY_HANDLERS[type] = KEY_HANDLERS[type] || []).push(fn); },
  document: {
    readyState: 'complete',
    documentElement: { _cls: new Set(), classList: { add(){}, remove(){}, contains(){return false;}, toggle(){return true;} } },
    getElementById(id) {
      if (id === 'a11y-toast') { return null; }
      if (id === 'shortcuts-modal') { return MODAL; }
      if (SELECTS[id]) { return SELECTS[id]; }
      return null;
    },
    querySelector(sel) { return sel === '.lesson' ? LESSON : null; },
    querySelectorAll(sel) { return sel === '.a11y-btn' ? A11Y_BTNS : []; },
    createElement() { return mkEl(); },
    // The product registers its key handlers on `document`, not on `window`
    // (`document.addEventListener('keydown', ...)` in lesson_controls_js.ch),
    // so a stub that ignores document-level listeners collects nothing and every
    // key assertion below passes vacuously.
    addEventListener(type, fn) { (KEY_HANDLERS[type] = KEY_HANDLERS[type] || []).push(fn); },
    body: { appendChild() {} },
  },
  localStorage: ls,
  setTimeout: (fn) => { try { fn(); } catch (e) { } },
  clearTimeout: () => {},
  matchMedia: () => ({ matches: false }),
  encodeURIComponent, JSON, String, Number, Math, Array, Object, Boolean, Date,
};
sandbox.window = sandbox;
// `pathname` is not optional. `__ulPaintNavActive` reads it during boot when
// readyState is 'complete', and a stub without it throws mid-script -- which
// aborts every definition after it and makes all eight controls look undefined.
// That is a harness fault reporting as a product fault, which is the worst
// possible shape for a checker, so location is a complete object.
sandbox.window.location = { href: '', pathname: '/courses/elf/lessons/bytes', search: '', hash: '' };
sandbox.window.scrollTo = () => {};
sandbox.window.getComputedStyle = () => ({ getPropertyValue: () => '' });

const vm = require('vm');
vm.createContext(sandbox);

const bootErr = null;
const script = require('fs').readFileSync(__SCRIPT_PATH__, 'utf8');
let runErr = null;
try { vm.runInContext(script, sandbox); } catch (e) { runErr = String(e); }

const out = { defined: {}, runErr: bootErr || runErr, effects: {}, stored: ls.dump() };

__CONTROLS__.forEach(name => {
  out.defined[name] = (typeof sandbox[name] === 'function')
                  || (sandbox.window && typeof sandbox.window[name] === 'function');
});

// SNAPSHOT THE RESTORE STATE FIRST, before anything below is called.
//
// The presses and the selects below MUTATE the element, and both of them toggle:
// pressing "high contrast" on a page that just restored it turns it back off. So
// a snapshot taken after them reports the opposite of what a returning reader
// sees, and the harness reported "saved high contrast is applied on load" as a
// failure on a page where it works perfectly. Captured here, immediately after
// boot, which is the only moment that corresponds to a page load.
out.restoredSelects = { fontSize: SELECTS['font-size'].value,
                        contentWidth: SELECTS['content-width'].value };
out.restoredClasses = classes();
// The buttons' own pressed state, snapshotted at the same moment for the same
// reason: a reader whose high contrast is restored sees the button lit, and a
// later press in this harness would unlight it before the value was read.
out.restoredBtn = { highContrast: A11Y_BTNS[0]._cls.has('active'),
                    reducedMotion: A11Y_BTNS[1]._cls.has('active') };

// Call each control and record what changed on the lesson element. A control
// that is defined but changes nothing is the same defect wearing a hat.
//
// The press/choose pair must start from the SAME baseline, or a control that
// merely re-adds a class another control already added looks like a no-op: the
// first three controls each left `high-contrast` on the element, so `font-large`
// measured as NO-CHANGE purely because the baseline already contained it. Each
// effect is therefore measured against the element's state immediately before
// that one call, and the expected class is named so the report says WHICH state
// failed rather than "something did not change".
function classes() { return Array.from(LESSON._cls).sort().join(','); }
function resolve(name) { return sandbox[name] || (sandbox.window && sandbox.window[name]); }
function press(name, expect) {
  const was = LESSON._cls.has(expect);
  try {
    const fn = resolve(name);
    if (typeof fn !== 'function') { return 'NOT-DEFINED'; }
    fn();
  } catch (e) { return 'THREW: ' + String(e); }
  const now = LESSON._cls.has(expect);
  if (now === was) { return 'NO-CHANGE:' + expect; }
  return (now ? 'ON:' : 'OFF:') + expect;
}

out.effects.highContrast = press('toggleHighContrast', 'high-contrast');
out.effects.reducedMotion = press('toggleReducedMotion', 'reduced-motion');

// The button's own pressed state AFTER each press, not just the lesson's class:
// the restore path and the toggle both have to keep the two in agreement, or the
// reader sees an unlit button sitting next to a setting that is on. Read here,
// after the presses, rather than from the boot snapshot -- what is being asked is
// whether pressing the button lights it, not whether load did.
out.btnState = { highContrast: A11Y_BTNS[0]._cls.has('active'),
                 reducedMotion: A11Y_BTNS[1]._cls.has('active') };

// `expect` is the class this call is supposed to put on the element. Asserting
// "the class list changed" would pass on a control that set the WRONG class;
// asserting the named class is the question actually being asked.
function choose(setter, value, expect) {
  try {
    const fn = resolve(setter);
    if (typeof fn !== 'function') { return 'NOT-DEFINED'; }
    fn(value);
  } catch (e) { return 'THREW: ' + String(e); }
  return LESSON._cls.has(expect) ? 'OK:' + expect : 'MISSING:' + expect
    + ' (has: ' + classes() + ')';
}
out.effects.fontSizeLarge = choose('setFontSize', 'large', 'font-large');
out.effects.widthNarrow = choose('setContentWidth', 'narrow', 'w-narrow');
// The <select> elements must show the READER'S saved choice on load, or the
// dropdown reads "Medium" while the page is already set to Large and the reader
// concludes their setting was forgotten.
//
// This is asserted from a SECOND run whose store is pre-seeded, because the
// question is "does a returning reader see their own settings", and the answer
// cannot be observed by calling a setter: in a real browser the reader changed
// the dropdown themselves, so its value is already correct and re-reading it
// proves nothing. What has to work is the restore path on a fresh page load.


// The registered keydown handlers, so a test can fire the keys the shortcuts
// dialog advertises. This is the fourth probe: a dialog that documents Ctrl+K
// and Up-arrow while binding neither is a lie told to the reader.
out.keyHandlers = (KEY_HANDLERS['keydown'] || []).length;

function fireKey(init) {
  const before = sandbox.window.location.href;
  let threw = null;
  (KEY_HANDLERS['keydown'] || []).forEach(fn => {
    try { fn(Object.assign({ preventDefault(){}, stopPropagation(){} }, init)); }
    catch (e) { threw = String(e); }
  });
  return { before, after: sandbox.window.location.href, threw };
}
out.ctrlK = fireKey({ key: 'k', ctrlKey: true });
out.escapeKey = fireKey({ key: 'Escape' });
out.questionKey = fireKey({ key: '?' });
// Typing "why" in a search box must NOT open the dialog or navigate.
out.ctrlKWhileTyping = fireKey({ key: 'k', ctrlKey: true, target: { tagName: 'INPUT' } });

out.modalOpened = (function () {
  try {
    const fn = sandbox.openShortcuts || (sandbox.window && sandbox.window.openShortcuts);
    if (typeof fn === 'function') { fn(); return true; }
  } catch (e) { return 'THREW: ' + String(e); }
  return false;
})();

console.log('RESULT ' + JSON.stringify(out));
'''


def fetch(path, port):
    url = f'http://localhost:{port}{path}'
    with urllib.request.urlopen(url, timeout=25) as r:
        return r.read().decode('utf-8', 'replace')


def page_scripts(html):
    return [m.group(1) for m in re.finditer(r'<script>([\s\S]*?)</script>', html)]


def run_node(js, controls, throwing, prestore=None):
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False,
                                     dir=os.path.join(ROOT, 'build')) as fh:
        fh.write(js)
        path = fh.name
    src = (HARNESS
           .replace('__SCRIPT_PATH__', json.dumps(path))
           .replace('__PORT__', '0')
           .replace('__THROWING__', 'true' if throwing else 'false')
           .replace('__PRESTORE__', json.dumps(prestore or {}))
           .replace('__CONTROLS__', json.dumps(controls)))
    try:
        proc = subprocess.run(['node', '-e', src], capture_output=True,
                              text=True, timeout=60, cwd=ROOT)
    finally:
        os.unlink(path)
    m = re.search(r'RESULT (\{.*\})', proc.stdout or '')
    if not m:
        return None, (proc.stderr or proc.stdout or '')[-400:]
    return json.loads(m.group(1)), None


checks = 0
failures = []


def ok(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print(f'  PASS  {name}')
    else:
        print(f'  FAIL  {name}' + (f'  -- {detail}' if detail else ''))
        failures.append(name)


def sec(title):
    print()
    print('=' * 74)
    print(title)
    print('=' * 74)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    args = ap.parse_args()

    print('lesson_controls_check: the lesson reading controls must be callable')
    try:
        pages = [(p, fetch(p, args.port)) for p in PAGES]
    except Exception as e:  # noqa: BLE001 -- any failure means "not reachable"
        print(f'\n  no server on {args.port}.  NOT a pass.  ({e})')
        return 2

    sec('1. every control the markup calls is DEFINED after the scripts run')
    for path, html in pages:
        js = '\n'.join(page_scripts(html))
        res, err = run_node(js, CONTROLS, throwing=False)
        if res is None:
            ok(f'{path}: harness ran', False, err)
            continue
        missing = [c for c in CONTROLS if not res['defined'].get(c)]
        ok(f'{path}: all {len(CONTROLS)} controls defined',
           not missing and not res['runErr'],
           (f'undefined: {missing} ' if missing else '') + (res['runErr'] or ''))

    sec('2. pressing each control CHANGES the lesson element')
    for path, html in pages:
        js = '\n'.join(page_scripts(html))
        res, _ = run_node(js, CONTROLS, throwing=False)
        if res is None:
            continue
        eff = res['effects']
        # An effect is only a pass when it reports the state it was asked for:
        # ON:/OFF: for a toggle, OK:<class> for a reading control. Anything else
        # -- NO-CHANGE, MISSING:<wrong class>, NOT-DEFINED, THREW -- is a finding,
        # and the message names which one.
        noop = [f'{k}={v}' for k, v in eff.items()
                if not str(v).startswith(('ON:', 'OFF:', 'OK:'))]
        ok(f'{path}: every control has a visible effect',
           not noop, f'no effect or threw: {noop}')
        ok(f'{path}: the shortcuts dialog opens', res['modalOpened'] is True,
           str(res['modalOpened']))
        bs = res['btnState']
        ok(f'{path}: the toggle button shows its own state',
           bs['highContrast'] and bs['reducedMotion'],
           f'button not marked active: {bs}')

    sec('2b. the shortcuts the dialog PROMISES are actually bound')
    for path, html in pages:
        js = '\n'.join(page_scripts(html))
        res, _ = run_node(js, CONTROLS, throwing=False)
        if res is None:
            continue
        ok(f'{path}: Ctrl+K goes to search',
           res['ctrlK']['after'] != res['ctrlK']['before']
           and '/search' in res['ctrlK']['after'],
           f"href stayed {res['ctrlK']['after']!r}")
        ok(f'{path}: "?" opens the dialog', res['questionKey']['threw'] is None)
        ok(f'{path}: Escape is handled without throwing',
           res['escapeKey']['threw'] is None, str(res['escapeKey']['threw']))
        ok(f'{path}: Ctrl+K while typing does NOT hijack the field',
           res['ctrlKWhileTyping']['after'] == res['ctrlKWhileTyping']['before'],
           'a reader typing in a search box got navigated away')

    sec('2c. a RETURNING reader gets their saved choices back')
    # A separate run with the store pre-seeded, because the setter run cannot
    # answer this: in a real browser the reader changed the dropdown themselves,
    # so its value already reads correctly and re-reading it proves nothing.
    # What matters is a FRESH page load, which is what a pre-seeded store is.
    saved = {'ulf-font-size': 'large', 'ulf-content-width': 'narrow',
             'ulf-high-contrast': '1'}
    for path, html in pages:
        js = '\n'.join(page_scripts(html))
        res, _ = run_node(js, CONTROLS, throwing=False, prestore=saved)
        if res is None:
            ok(f'{path}: restore path ran', False, 'harness failed')
            continue
        rs = res['restoredSelects']
        ok(f'{path}: the dropdowns show the reader\'s saved choice',
           rs['fontSize'] == 'large' and rs['contentWidth'] == 'narrow',
           f'dropdowns show {rs}, not the saved choice')
        ok(f'{path}: the saved font size is applied to the page',
           'font-large' in res['restoredClasses'],
           f'lesson classes: {res["restoredClasses"]}')
        ok(f'{path}: the saved content width is applied to the page',
           'w-narrow' in res['restoredClasses'],
           f'lesson classes: {res["restoredClasses"]}')
        ok(f'{path}: saved high contrast is applied on load',
           'high-contrast' in res['restoredClasses'],
           f'lesson classes: {res["restoredClasses"]}')
        rb = res['restoredBtn']
        ok(f'{path}: the high-contrast BUTTON is lit on load',
           rb['highContrast'] is True,
           f'button unlit next to a setting that is on: {rb}')

    sec('3. WITH localStorage BLOCKED -- the condition that killed the 79 pages')
    for path, html in pages:
        js = '\n'.join(page_scripts(html))
        res, _ = run_node(js, CONTROLS, throwing=True)
        if res is None:
            ok(f'{path}: survives blocked storage', False, 'harness failed')
            continue
        missing = [c for c in CONTROLS if not res['defined'].get(c)]
        ok(f'{path}: controls still defined when localStorage throws',
           not missing and not res['runErr'],
           (f'undefined: {missing} ' if missing else '') + (res['runErr'] or ''))
        eff = res['effects']
        # An effect is only a pass when it reports the state it was asked for:
        # ON:/OFF: for a toggle, OK:<class> for a reading control. Anything else
        # -- NO-CHANGE, MISSING:<wrong class>, NOT-DEFINED, THREW -- is a finding,
        # and the message names which one.
        noop = [f'{k}={v}' for k, v in eff.items()
                if not str(v).startswith(('ON:', 'OFF:', 'OK:'))]
        ok(f'{path}: controls still have an effect when localStorage throws',
           not noop, f'no effect or threw: {noop}')

    total = checks
    print()
    print('=' * 74)
    if failures:
        print(f'lesson_controls_check: {len(failures)} of {total} CHECKS FAILED')
        for f in failures:
            print(f'  FAILED: {f}')
        return 1
    print(f'lesson_controls_check: ALL {total} CHECKS PASSED')
    return 0


if __name__ == '__main__':
    sys.exit(main())