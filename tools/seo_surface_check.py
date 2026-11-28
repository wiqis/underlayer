#!/usr/bin/env python3
"""seo_surface_check.py -- crawl the generator's own URL list and check SEO.

WHY THIS EXISTS (I1).  A sitemap with a hardcoded count is a sitemap that keeps
passing after a course is added. This checker builds its expected set from
GET /api/courses and GET /api/courses/<id>, i.e. the same manifests that
generate the pages, then compares that set with the served /sitemap.xml and
fetches every URL to check the head contract:

  * exactly one non-empty <title>;
  * one <meta name="description"> of 140-158 characters;
  * one <link rel="canonical"> on the public host;
  * og:title and og:description;
  * Course + BreadcrumbList JSON-LD on course and lesson pages;
  * no aggregateRating anywhere (wiqis-seo-content: no invented ratings).

The public host is learned from robots.txt's Sitemap line, not hardcoded, so
the same checker works against localhost:9034 and underlayer.wiqis.com.

NEGATIVE CASES (no server needed for --selftest):
    python3 tools/seo_surface_check.py --selftest
  plants a short description, a missing title and an aggregateRating into
  synthetic pages and asserts each is reported; a clean synthetic page passes.

    python3 tools/seo_surface_check.py http://localhost:9034 --plant
  crawls normally, then plants a short description into one served lesson in
  memory and asserts the page check fails on it.

Usage:
    python3 tools/seo_surface_check.py [BASE] [--limit N]
Exit: 0 every URL satisfies the contract and the sitemap set matches.
      1 at least one failure.  2 the server or generator API is unusable.
"""
import argparse
import concurrent.futures
import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 20
GUIDE_PATHS = ['/help', '/shortcuts', '/faq', '/about', '/terms', '/privacy']
STATIC_PATHS = ['/', '/courses', '/search', '/learning-path'] + GUIDE_PATHS
LOCAL_PATH_MARKERS = ['file://', '\\\\', 'C:\\', '/home/', '/Users/',
                      'app/main.ch', 'underlayer.db']


def fetch(base, path, binary=False):
    url = base.rstrip('/') + path
    with urllib.request.urlopen(url, timeout=TIMEOUT) as response:
        raw = response.read()
        return response.status, (raw if binary else raw.decode('utf-8', 'replace'))


def tags(body, name):
    """All <name ...> opening tags, lowercased attribute names preserved."""
    return re.findall(r'<' + name + r'\b[^>]*>', body, flags=re.I)


def attr(tag_text, name):
    m = re.search(r'\b' + re.escape(name) + r'\s*=\s*"([^"]*)"', tag_text, flags=re.I)
    return html.unescape(m.group(1)) if m else None


def meta(body, key, key_attr='name'):
    found = []
    for tag_text in tags(body, 'meta'):
        if attr(tag_text, key_attr) == key:
            value = attr(tag_text, 'content')
            if value is not None:
                found.append(value)
    return found


def jsonld_types(body):
    types = []
    for block in re.findall(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
                            body, flags=re.I | re.S):
        try:
            data = json.loads(html.unescape(block))
        except (ValueError, TypeError):
            continue
        for node in data.get('@graph', [data]):
            if isinstance(node, dict) and '@type' in node:
                types.append(node['@type'])
    return types


def check_page(body, path, origin, kind):
    """Return a list of failures. Pure: usable by the negative plant."""
    fails = []
    titles = re.findall(r'<title>(.*?)</title>', body, flags=re.I | re.S)
    if len(titles) != 1:
        fails.append('expected exactly one <title>, found %d' % len(titles))
    elif not html.unescape(titles[0]).strip():
        fails.append('<title> is empty')

    descriptions = meta(body, 'description')
    if len(descriptions) != 1:
        fails.append('expected exactly one meta description, found %d' % len(descriptions))
    else:
        n = len(descriptions[0])
        if not 140 <= n <= 158:
            fails.append('description is %d chars, expected 140-158: %r'
                         % (n, descriptions[0][:80]))

    canonicals = [attr(t, 'href') for t in tags(body, 'link')
                  if attr(t, 'rel') == 'canonical']
    canonicals = [c for c in canonicals if c]
    expected = origin.rstrip('/') + path
    if len(canonicals) != 1:
        fails.append('expected exactly one canonical link, found %d' % len(canonicals))
    elif canonicals[0] != expected:
        fails.append('canonical %r does not match %r' % (canonicals[0], expected))

    for prop in ('og:title', 'og:description'):
        vals = meta(body, prop, 'property')
        if len(vals) != 1 or not vals[0].strip():
            fails.append('missing or empty %s' % prop)

    if 'aggregateRating' in body:
        fails.append('aggregateRating is forbidden (wiqis-seo-content)')
    if kind in ('lesson', 'course'):
        types = jsonld_types(body)
        for needed in ('Course', 'BreadcrumbList'):
            if needed not in types:
                fails.append('JSON-LD is missing @type %s (found %r)'
                             % (needed, types))
    return fails


def build_expected(base):
    status, body = fetch(base, '/api/courses')
    if status != 200:
        raise RuntimeError('GET /api/courses -> %d' % status)
    courses = json.loads(body)
    if not isinstance(courses, list) or len(courses) < 2:
        raise RuntimeError('generator returned %d courses; refusing a vacuous run'
                           % (len(courses) if isinstance(courses, list) else -1))
    pages = {}
    for path in STATIC_PATHS:
        pages[path] = 'static'
    course_ids = [c.get('id') for c in courses if c.get('id')]
    paid_ids = {c.get('id') for c in courses if c.get('paid')}
    details = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(fetch, base, '/api/courses/' + urllib.parse.quote(cid)): cid
                   for cid in course_ids}
        for future in concurrent.futures.as_completed(futures):
            cid = futures[future]
            status, detail = future.result()
            if status != 200:
                raise RuntimeError('GET /api/courses/%s -> %d' % (cid, status))
            details[cid] = json.loads(detail)
    for cid in course_ids:
        path = '/courses/' + cid
        pages[path] = 'course'
        # The landing is public store-front, but paid LESSON content correctly
        # answers 402 without an entitlement. Do not crawl that as a public URL.
        if cid in paid_ids:
            continue
        for concept in details[cid].get('concepts', []):
            concept_id = concept.get('id')
            if concept_id:
                pages[path + '/lessons/' + concept_id] = 'lesson'
    if not any(k == 'lesson' for k in pages.values()):
        raise RuntimeError('no concept URLs in the generator output')
    return pages


def origin_from_robots(base):
    status, body = fetch(base, '/robots.txt')
    if status != 200:
        raise RuntimeError('GET /robots.txt -> %d' % status)
    m = re.search(r'^Sitemap:\s*(\S+)\s*$', body, flags=re.M)
    if not m:
        raise RuntimeError('robots.txt has no Sitemap: line: %r' % body[:200])
    parts = urllib.parse.urlsplit(m.group(1))
    return '%s://%s' % (parts.scheme, parts.netloc), body


def selftest():
    origin = 'https://underlayer.wiqis.com'
    good = ('<html><head><title>Good — Underlayer</title>'
            '<meta name="description" content="%s">'
            '<link rel="canonical" href="%s/courses/elf">'
            '<meta property="og:title" content="Good">'
            '<meta property="og:description" content="Good">'
            '<script type="application/ld+json">{"@context":"https://schema.org",'
            '"@graph":[{"@type":"Course"},{"@type":"BreadcrumbList"}]}</script>'
            '</head><body></body></html>') % ('x' * 150, origin)
    fails = []
    if check_page(good, '/courses/elf', origin, 'course'):
        fails.append('clean synthetic page reported as failing')

    short = good.replace('x' * 150, 'too short')
    if not any('description is' in f for f in check_page(short, '/courses/elf', origin, 'course')):
        fails.append('planted short description was not detected')

    no_title = good.replace('<title>Good — Underlayer</title>', '')
    if not any('exactly one <title>' in f for f in check_page(no_title, '/courses/elf', origin, 'course')):
        fails.append('planted missing title was not detected')

    rated = good.replace('"@type":"Course"', '"@type":"Course","aggregateRating":{"ratingValue":5}')
    if not any('aggregateRating' in f for f in check_page(rated, '/courses/elf', origin, 'course')):
        fails.append('planted aggregateRating was not detected')

    no_ld = good.replace(re.search(r'<script.*?</script>', good).group(0), '')
    if not any('BreadcrumbList' in f for f in check_page(no_ld, '/courses/elf', origin, 'course')):
        fails.append('planted missing JSON-LD was not detected')

    if fails:
        print('SELFTEST FAIL:')
        for f in fails:
            print('  - ' + f)
        return 1
    print('SELFTEST OK: clean synthetic page passes; planted short description, '
          'missing\ntitle, aggregateRating and missing JSON-LD are all reported.')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('base', nargs='?', default='http://localhost:9000')
    ap.add_argument('--limit', type=int, default=0, help='check only the first N URLs')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--plant', action='store_true',
                    help='plant a short description in one fetched page and require detection')
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    try:
        origin, robots = origin_from_robots(args.base)
        pages = build_expected(args.base)
        status, sitemap = fetch(args.base, '/sitemap.xml')
        if status != 200:
            raise RuntimeError('GET /sitemap.xml -> %d' % status)
        fav_status, _ = fetch(args.base, '/favicon.ico', binary=True)
    except (urllib.error.URLError, OSError, ValueError, RuntimeError) as exc:
        print('FAIL: cannot build the URL set: %s' % exc)
        return 2

    failures = []
    if fav_status != 200:
        failures.append('GET /favicon.ico -> %d' % fav_status)

    locs = re.findall(r'<loc>(.*?)</loc>', sitemap, flags=re.S)
    locs = [html.unescape(x).strip() for x in locs]
    expected_urls = set(origin.rstrip('/') + p for p in pages)
    seen = set(locs)
    missing = sorted(expected_urls - seen)
    extra = sorted(seen - expected_urls)
    if missing:
        failures.append('sitemap is missing %d URL(s), first 3: %r' % (len(missing), missing[:3]))
    if extra:
        failures.append('sitemap has %d unexpected URL(s), first 3: %r' % (len(extra), extra[:3]))
    if len(locs) != len(seen):
        failures.append('sitemap has duplicate loc entries')
    for marker in LOCAL_PATH_MARKERS:
        if marker in sitemap:
            failures.append('sitemap contains a local path marker %r' % marker)
    lastmods = re.findall(r'<lastmod>(.*?)</lastmod>', sitemap, flags=re.S)
    if len(lastmods) != len(locs):
        failures.append('sitemap has %d lastmod values for %d locs'
                        % (len(lastmods), len(locs)))
    for value in lastmods[:5]:
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value.strip()):
            failures.append('bad lastmod %r' % value)

    items = list(pages.items())
    if args.limit:
        items = items[:args.limit]
    # The server answers about 2 s per request on this machine; sequential
    # crawling of 372 pages takes long enough to be mistaken for a hang.
    fetched = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(fetch, args.base, path) for path, _ in items]
        for future in futures:
            try:
                status, body = future.result()
                fetched.append((status, body, None))
            except (urllib.error.URLError, OSError, ValueError) as exc:
                fetched.append((0, '', str(exc)))

    planted_detected = False
    for index, ((path, kind), (status, body, error)) in enumerate(zip(items, fetched)):
        if error:
            failures.append('GET %s failed: %s' % (path, error))
            continue
        if status != 200:
            failures.append('GET %s -> %d' % (path, status))
            continue
        if args.plant and index == 0:
            body = re.sub(r'(<meta name="description" content=")[^"]*(")',
                          r'\1planted\2', body, count=1)
        problems = check_page(body, path, origin, kind)
        if args.plant and index == 0:
            planted_detected = any('description is' in p for p in problems)
            # The planted failure is the expected result of this mode, not a
            # finding about the served site; exclude it from the exit status.
            continue
        for problem in problems:
            failures.append('%s: %s' % (path, problem))

    print('seo_surface_check: %d URLs from the generator, %d sitemap locs, '
          'origin %s' % (len(items), len(locs), origin))
    if args.plant:
        if not planted_detected:
            failures.append('the planted short description was NOT detected')
        else:
            print('PLANT OK: short description planted in %s was detected' % items[0][0])
    if failures:
        print('FAIL: %d problem(s)' % len(failures))
        for f in failures[:40]:
            print('  - ' + f)
        if len(failures) > 40:
            print('  ... and %d more' % (len(failures) - 40))
        return 1
    print('seo_surface_check: ALL CONSISTENT over %d served pages' % len(items))
    return 0


if __name__ == '__main__':
    sys.exit(main())
