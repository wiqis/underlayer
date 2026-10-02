#!/usr/bin/env python3
"""measure_nav.py -- measure a page's nav in a real browser, not in theory.

Fetches a page from the running server, inlines a script that writes the nav's
geometry into the document, and reads it back out of headless Chrome.  Used to
check the CSS claims this change makes -- that a sticky nav needs no body
offset, that it does not cover the `position: fixed` accessibility controls
that 21 lesson pages pin to the top-left corner, and how tall the link row
gets when it wraps.

Numbers, not a screenshot: a screenshot proves a thing once, on the machine
that took it, and this file's whole reason to exist is that "it looked right"
is not a check.

Usage:
    python3 tools/measure_nav.py /courses/elf/lessons/bytes --width 1440
    python3 tools/measure_nav.py /courses/elf/lessons/bytes --width 390
    python3 tools/measure_nav.py / --screenshot /tmp/shot.png
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

PROBE = """
<script>
window.addEventListener('load', function () {
    function box(sel) {
        var el = document.querySelector(sel);
        if (!el) return null;
        var r = el.getBoundingClientRect();
        return {x: Math.round(r.left), y: Math.round(r.top),
                w: Math.round(r.width), h: Math.round(r.height),
                bottom: Math.round(r.bottom), right: Math.round(r.right)};
    }
    var nav = document.querySelector('.navbar');
    var cs = nav ? getComputedStyle(nav) : null;
    var a11y = document.querySelector('.a11y-controls');
    var hit = null;
    if (a11y) {
        var r = a11y.getBoundingClientRect();
        var el = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        hit = el ? (el.className || el.tagName) : '(none)';
    }
    var rows = null;
    var links = document.querySelector('.nav-links');
    if (links) {
        var tops = {};
        Array.prototype.forEach.call(links.children, function (a) {
            tops[Math.round(a.getBoundingClientRect().top)] = 1;
        });
        rows = Object.keys(tops).length;
    }
    var data = {
        viewport: [innerWidth, innerHeight],
        navbarCount: document.querySelectorAll('.navbar').length,
        navPosition: cs ? cs.position : null,
        navZ: cs ? cs.zIndex : null,
        navBg: cs ? cs.backgroundColor : null,
        nav: box('.navbar'),
        navInner: box('.nav-inner'),
        brand: box('.nav-brand'),
        links: box('.nav-links'),
        navRight: box('.nav-right'),
        linkRows: rows,
        a11y: box('.a11y-controls'),
        cb: box('.cb-controls'),
        a11yHitTest: hit,
        lessonTop: box('.lesson'),
        mainTop: box('main'),
        bodyScrollHeight: document.body.scrollHeight
    };
    var pre = document.createElement('script');
    pre.id = 'navprobe';
    pre.type = 'application/json';
    pre.textContent = JSON.stringify(data);
    document.body.appendChild(pre);
});
</script>
"""


def run(url, base, width, height, screenshot):
    with urllib.request.urlopen(base + url, timeout=30) as resp:
        html = resp.read().decode('utf-8', 'replace')
    html = html.replace('</body>', PROBE + '</body>')
    tmp = tempfile.mkdtemp(prefix='navmeasure-')
    path = os.path.join(tmp, 'page.html')
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(html)
    common = ['google-chrome', '--headless=new', '--disable-gpu', '--no-sandbox',
              '--hide-scrollbars', '--virtual-time-budget=4000',
              '--window-size=%d,%d' % (width, height)]
    if screenshot:
        subprocess.run(common + ['--screenshot=' + screenshot, 'file://' + path],
                       check=True, capture_output=True)
    dom = subprocess.run(common + ['--dump-dom', 'file://' + path],
                         check=True, capture_output=True, text=True).stdout
    m = re.search(r'<script id="navprobe" type="application/json">(.*?)</script>',
                  dom, re.S)
    if not m:
        print('probe did not run; the page may not have loaded', file=sys.stderr)
        return None
    return json.loads(m.group(1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('url')
    ap.add_argument('--base', default='http://localhost:9000')
    ap.add_argument('--width', type=int, default=1440)
    ap.add_argument('--height', type=int, default=900)
    ap.add_argument('--screenshot', default=None)
    args = ap.parse_args()

    data = run(args.url, args.base, args.width, args.height, args.screenshot)
    if data is None:
        return 1
    print(json.dumps(data, indent=2, sort_keys=True))
    if args.screenshot:
        print('screenshot: %s' % args.screenshot)
    return 0


if __name__ == '__main__':
    sys.exit(main())
