#!/usr/bin/env python3
"""helpful_dedupe_check.py -- prove one learner cannot inflate a review's helpful count.

This is a WRITE probe: it registers throwaway learners, submits a review and
casts votes. Run it against a TEST server with a disposable database, never
against production. It needs two register calls, so the auth limiter (8 per 5
minutes per IP) allows about four consecutive runs before it must be left alone.

Assertions:
  * anonymous POST /api/reviews/:id/helpful is refused with 401
  * the first authenticated vote answers duplicate:false, helpful:true
  * the second and third votes from the SAME learner answer duplicate:true
  * a DIFFERENT learner's first vote is not a duplicate
  * helpful_count (the value a visitor reads) moves once per distinct learner

Usage:
    python tools/helpful_dedupe_check.py [base-url]
Exit 0 all assertions hold, 1 otherwise.
"""
import json
import sys
import time
import urllib.error
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:9000'
failures = []
checks = 0


def check(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def call(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode('utf-8', 'replace'))
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', 'replace')
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {'raw': raw}


def count_for(review_id):
    st, reviews = call('GET', '/api/courses/elf/reviews')
    if st != 200:
        return None
    for rv in reviews:
        if rv.get('id') == review_id:
            return rv.get('helpful_count')
    return None


def main():
    print('helpful_dedupe_check against ' + BASE)
    try:
        call('GET', '/api/health')
    except Exception as e:
        check('server answers /api/health', False, str(e)[:60])
        return finish()

    tokens = []
    for n in (1, 2):
        st, body = call('POST', '/api/auth/register', body={
            'email': 'dedupe-%d-%d@invalid.test' % (n, time.time_ns()),
            'password': 'ProbePass123!', 'name': 'Dedupe Probe %d' % n})
        check('throwaway learner %d registered' % n, st == 200 and bool(body.get('session_token')),
              'status %s: %s' % (st, str(body)[:80]))
        tokens.append(body.get('session_token'))

    st, body = call('POST', '/api/courses/elf/reviews', tokens[0],
                    {'rating': 5, 'title': 'dedupe regression probe',
                     'review_text': 'a disposable review for the vote check'})
    check('throwaway review submitted', st == 200 and bool(body.get('id')),
          'status %s: %s' % (st, str(body)[:80]))
    rid = body.get('id')

    st, body = call('POST', '/api/reviews/%s/helpful' % rid)
    check('anonymous vote is refused', st == 401, 'status %s' % st)

    if rid:
        before = count_for(rid)
        check('review count readable before voting', before == 0, 'before=%r' % before)
        for n in range(1, 4):
            st, body = call('POST', '/api/reviews/%s/helpful' % rid, tokens[0])
            duplicate = body.get('duplicate')
            if n == 1:
                check('first vote is not a duplicate', st == 200 and duplicate is False,
                      str(body)[:80])
                check('first vote acknowledges helpful', body.get('helpful') is True)
            else:
                check('vote %d from the same learner is a duplicate' % n,
                      st == 200 and duplicate is True, str(body)[:80])
        after_first = count_for(rid)
        check('three votes from one learner move the count by exactly 1',
              after_first == 1, 'after=%r' % after_first)

        if tokens[1]:
            st, body = call('POST', '/api/reviews/%s/helpful' % rid, tokens[1])
            check("a different learner's vote is not a duplicate",
                  st == 200 and body.get('duplicate') is False, str(body)[:80])
            after_second = count_for(rid)
            check('two learners move the count by exactly 2',
                  after_second == 2, 'after=%r' % after_second)

    return finish()


def finish():
    print('\n' + ('helpful_dedupe_check: ALL %d CHECKS PASSED' % checks
                  if not failures
                  else 'helpful_dedupe_check: %d of %d CHECKS FAILED'
                       % (len(failures), checks)))
    for f in failures:
        print('  FAILED: %s' % f)
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())
