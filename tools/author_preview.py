#!/usr/bin/env python3
"""G12 — serve the generated pilot lesson locally for author review.

The markup and CSS come verbatim from the generated `content/src/*.ch`-shaped
file (the text between its #html/#css/#js macros); this is a preview of that
artifact, not a second renderer. Binds loopback only. Stdlib, no shell, no
production URLs or databases. `--selftest` plants a missing/truncated macro
block and must refuse both.
"""
import argparse
import http.server
import re
import socketserver
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = ROOT / 'content/authoring/generated/elf/bytes.ch'

HTML_RE = re.compile(r'#html \{(.*?)\n        \}', re.S)
CSS_RE = re.compile(r'#css \{(.*?)\n        \}', re.S)
JS_RE = re.compile(r'#js \{(.*?)\n        \}', re.S)


def extract(source_text):
    html_m, css_m, js_m = (HTML_RE.search(source_text),
                           CSS_RE.search(source_text),
                           JS_RE.search(source_text))
    if not (html_m and css_m and js_m):
        raise ValueError('generated file is missing an #html/#css/#js block')
    body, css, js = html_m.group(1), css_m.group(1), js_m.group(1)
    if '<div class="lesson' not in body or 'authored-objective' not in body:
        raise ValueError('generated #html block is not the pilot lesson')
    return body, css, js


def page_for(source_text):
    body, css, js = extract(source_text)
    return ('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Authoring preview — Underlayer</title><style>'
            'body{font-family:system-ui,sans-serif;margin:0;line-height:1.6}'
            + css + '</style></head><body>' + body +
            '<script>' + js + '</script></body></html>').encode('utf-8')


def selftest():
    source = DEFAULT_SOURCE.read_text(encoding='utf-8') if DEFAULT_SOURCE.is_file() else ''
    ok = bool(source)
    print(('PASS' if ok else 'FAIL') + ': generated pilot file exists')
    if not ok:
        return 1
    try:
        page_for(source)
        print('PASS: generated lesson extracted')
    except ValueError as exc:
        ok = False
        print('FAIL: generated lesson not extracted: %s' % exc)
    for label, broken in (('missing #js block', source.replace('#js {', '// js {')),
                          ('truncated #html block', source.split('</div>')[0])):
        try:
            page_for(broken)
            rejected = False
        except ValueError:
            rejected = True
        ok = ok and rejected
        print(('%s: %s rejected' % ('PASS' if rejected else 'FAIL', label)))
    print('AUTHOR PREVIEW SELFTEST %s' % ('3/3 — controls accepted, plants rejected'
                                          if ok else 'incomplete'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', default=str(DEFAULT_SOURCE))
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--port', type=int, default=9067)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if args.host not in ('127.0.0.1', 'localhost', '::1'):
        print('REFUSED: preview host must be loopback (got %s)' % args.host)
        return 2
    source = Path(args.source)
    if not source.is_absolute():
        source = ROOT / source
    if not source.is_file():
        print('FAIL: run tools/author_generate.py first: %s' % source)
        return 1
    try:
        document = page_for(source.read_text(encoding='utf-8'))
    except ValueError as exc:
        print('FAIL: %s' % exc)
        return 1

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(document)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(document)

        def log_message(self, fmt, *a):
            pass

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    with Server((args.host, args.port), Handler) as srv:
        print('author preview: http://%s:%d/ (%s)' % (args.host, args.port,
                                                     source.relative_to(ROOT)))
        try:
            srv.serve_forever(poll_interval=0.2)
        except KeyboardInterrupt:
            pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
