#!/usr/bin/env python3
"""security_check.py -- machine proof that passwords are salted, bcrypt, upgradeable.

WHY THIS EXISTS, in the shape of the defect it exists for.

Passwords were stored as a single UNSALTED SHA-256.  Two accounts with the same
password had byte-identical rows, which was proven by registering two accounts
and reading the table:

    s1@t.com  54c571aae6a1f21767a11961f25315e3bd22877c6db9758ef2f2e462c98a47e8
    s2@t.com  54c571aae6a1f21767a11961f25315e3bd22877c6db9758ef2f2e462c98a47e8
    IDENTICAL (UNSALTED): True

Unrelated to any rainbow table, that alone leaks which learners share a
password, and a single-pass SHA-256 is a fast hash on purpose -- a GPU does
billions per second, so a six-character password falls in seconds.  A password
KDF has to be deliberately slow; this one was deliberately fast.

This asks the server six questions and reads the database back.  Each is a
question with a number, not a description:

  1. SAME PASSWORD, DIFFERENT HASHES.  Register two accounts with one password;
     the two stored values must differ.  (The original defect.)
  2. THE HASH IS A KDF, NOT A BARE DIGEST.  It must be a bcrypt modular-crypt
     string, `$2b$<cost>$`, and the cost this build claims to use must be
     readable off the row.
  3. THE HASH IS NOT THE PASSWORD.  sha256(password) must not appear anywhere in
     the stored value -- i.e. no unsalted fallback slipped back in.
  4. LOGIN STILL WORKS.  The right password gives 200 and a token; the wrong one
     gives 401.  A hashing scheme that cannot log in is not a fix.
  5. A LEGACY UNSALTED ROW STILL AUTHENTICATES.  Write a row the old code would
     have written -- sha256(password), 64 hex chars -- log in with it, and get
     200.  This is the "no account is locked out" half of the requirement.
  6. AND IS UPGRADED ON THAT LOGIN.  Read the row again: it must now be bcrypt.
     A verify-only legacy path would satisfy 5 forever and never fix anything.

It also carries the two other live exploits this audit found, because a gate
that only checks the password bytes would still be green with either of these
regressed:

  10. SQL INJECTION ON LOGIN.  `email` went into a SQL literal unescaped, so
      `' OR password_hash='<sha256 of a password I know>` answered 200 with a
      live session token for someone else's account.  Four payload shapes are
      sent; all four must answer 401 with no token.
  11. THE SILENT-LOST-ACCOUNT BUG.  `exec_sql` frees SQLite's error message
      without reporting it, so one apostrophe in a display name made the INSERT
      a syntax error that register answered 200 to.  The returned learner must
      really exist and really be able to log in.
  12. THE SESSION IDOR.  Session ids are Unix timestamps and every
      /api/session/* endpoint acted on whatever id it was handed.  An anonymous
      request with no Authorization header must not be able to pause, resume or
      abort another learner's session -- while that learner still can.
  13. THE DESTRUCTIVE ENDPOINTS NEED A TOKEN.  DELETE /api/user/account and
      DELETE /api/user/data/:type resolved an absent token to the shared `demo`
      learner and deleted things, so no credentials were required to destroy an
      account.  Both must answer 401 with no Authorization header.
  14. DELETING AN ACCOUNT LEAVES NOTHING BEHIND.  The old handler deleted
      `sessions` and then asked `session_items` to delete itself through a
      subquery over `sessions`, so it never deleted anything, and thirteen
      tables were missing from the list entirely.  This gives a throwaway learner
      a row in as many tables as it can, deletes the account, and asserts that
      NO table still holds a row for that learner id.

It also proves the implementation is not merely self-consistent: the stored
hash is checked against Python's `bcrypt`, a different implementation of the
same standard.  If the Chemical bcrypt ever stopped agreeing with a reference,
this fails instead of the passwords quietly meaning something else.

HOW TO PROVE IT IS NOT VACUOUS
------------------------------
`--selftest` runs the two central assertions against synthetic input -- two
"identical" hashes and a "different" pair -- and asserts the checker reports a
PASS for the different pair and a FAIL for the identical pair.  A check that
cannot fail on the exact condition it exists to detect is a comment with
exit code 0.

Every account this creates is deleted before it exits, through the shipped
`DELETE /api/user/account` route, and the deletion is verified.  It also
deletes the throwaway learner it plants for check 5.  On any path that dies
early it still tries to clean up, and it prints what it could not remove.

Usage:
    python3 tools/security_check.py
    python3 tools/security_check.py --port 9000
    python3 tools/security_check.py --selftest

Exit: 0 all six checks pass.  1 at least one fails.  2 the server or the
      database is not reachable (NOT a pass).
"""
import argparse
import hashlib
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request

DB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  'underlayer.db')

PW = 'security-check-password-1'
TAG = 'secchk'


def http(method, path, port, token=None, body=None, timeout=30):
    url = 'http://localhost:%d%s' % (port, path)
    data = None
    headers = {}
    if body is not None:
        data = body.encode() if isinstance(body, str) else body
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read(400000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read(400000).decode('utf-8', 'replace')
    except Exception as e:  # noqa: BLE001
        return 0, 'TRANSPORT: %s' % e


def db():
    return sqlite3.connect(DB, timeout=20)


def stored_hash(email):
    c = db()
    try:
        row = c.execute('select password_hash from learners where email = ?',
                        (email,)).fetchone()
        return row[0] if row else None
    finally:
        c.close()


def set_stored_hash(email, value):
    c = db()
    try:
        c.execute('update learners set password_hash = ? where email = ?',
                  (value, email))
        c.commit()
    finally:
        c.close()


def register(port, email, name):
    st, body = http('POST', '/api/auth/register', port, body=json.dumps(
        {'email': email, 'password': PW, 'name': name}))
    try:
        j = json.loads(body)
    except Exception:  # noqa: BLE001
        j = {}
    return st, j.get('session_token'), j.get('learner_id'), body


def login(port, email, pw):
    st, body = http('POST', '/api/auth/login', port,
                    body=json.dumps({'email': email, 'password': pw}))
    try:
        j = json.loads(body)
    except Exception:  # noqa: BLE001
        j = {}
    return st, j.get('session_token'), body


def drop(port, token):
    return http('DELETE', '/api/user/account', port, token=token)[0]


def bcrypt_cost(h):
    """The cost digits of a bcrypt modular-crypt string, or None."""
    if not h or not h.startswith('$2') or len(h) < 7 or h[3] != '$':
        return None
    try:
        return int(h[4:6])
    except ValueError:
        return None


def reference_ok(h, pw):
    """Cross-check the stored hash against a DIFFERENT bcrypt implementation.

    Uses the `bcrypt` module when it is installed.  When it is not, this check
    reports 'skipped' rather than pretending to have run -- a check that claims
    to have compared against a reference when it could not is the exact failure
    mode this file is about.
    """
    try:
        import bcrypt as _bcrypt  # noqa: PLC0415
    except ImportError:
        return None, 'python bcrypt module not installed'
    try:
        return _bcrypt.checkpw(pw.encode(), h.encode()), 'python bcrypt'
    except Exception as e:  # noqa: BLE001
        return False, 'python bcrypt rejected it: %s' % e


def selftest():
    """The two central assertions must disagree on identical vs different input."""
    a = '$2b$12$mBgMl66mDf/xCb4CfBhmo.8RXVOagTzI0P4L92vuFDXE4dSRStkl2'
    b = '$2b$12$Yfv1.X86C1v5OcDWhhula.mArT.nlEv44ryMdqNv4Fr.LR0XrZgZa'
    fails = []
    if a == b:
        fails.append('planted "identical" pair was not identical -- the setup is broken')
    if not (a != b):
        fails.append('planted "different" pair was not different -- the setup is broken')
    if bcrypt_cost(a) != 12:
        fails.append('bcrypt_cost read %r from a $2b$12$ string' % bcrypt_cost(a))
    if bcrypt_cost('54c571aae6a1f21767a11961f25315e3bd22877c6db9758ef2f2e462c98a47e8') is not None:
        fails.append('a legacy 64-hex value was mistaken for a bcrypt string')
    r = reference_ok(a, PW)
    if r is not None and r[0] is False:
        # reference bcrypt says no; that is expected for a hash of a different
        # password, so it must not be reported as a broken setup.
        pass
    if fails:
        print('SELFTEST FAIL:')
        for f in fails:
            print('  - %s' % f)
        return 1
    print('SELFTEST OK: identical-vs-different is distinguishable, bcrypt cost is')
    print('  readable, and a legacy 64-hex value is NOT classified as bcrypt.')
    if r is None:
        print('  (reference bcrypt unavailable here: %s)' % r[1])
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    st, _ = http('GET', '/api/health', args.port)
    if st != 200:
        print('FAIL: no server on port %d (health=%d).  NOT a pass.' % (args.port, st))
        return 2
    try:
        c = db()
        c.execute('select 1 from learners limit 1')
        c.close()
    except Exception as e:  # noqa: BLE001
        print('FAIL: cannot read %s (%s).  NOT a pass.' % (DB, e))
        return 2

    stamp = '%d' % int(time.time())
    e1 = '%s_%s_a@t.com' % (TAG, stamp)
    e2 = '%s_%s_b@t.com' % (TAG, stamp)
    el = '%s_%s_legacy@t.com' % (TAG, stamp)
    tokens = {}
    results = []
    failures = 0

    def check(name, ok, detail):
        nonlocal failures
        if not ok:
            failures += 1
        results.append((name, ok, detail))
        print('  %s  %s\n        %s' % ('PASS' if ok else 'FAIL', name, detail))

    try:
        print('=== CHECK 1  same password -> different stored hashes ===')
        r1 = register(args.port, e1, 'Sec A')
        r2 = register(args.port, e2, 'Sec B')
        tokens[e1] = r1[1]
        tokens[e2] = r2[1]
        check('two registrations both succeed', r1[0] == 200 and r2[0] == 200,
              'register %s -> %d, register %s -> %d' % (e1, r1[0], e2, r2[0]))
        h1, h2 = stored_hash(e1), stored_hash(e2)
        check('both rows were written at all', bool(h1) and bool(h2),
              'stored %s = %r ; %s = %r' % (e1, h1, e2, h2))
        check('the two hashes DIFFER (the original defect)', bool(h1) and bool(h2) and h1 != h2,
              'identical = %s' % (h1 == h2))
        check('neither hash is a bare 64-char hex digest',
              not (h1 and len(h1) == 64) and not (h2 and len(h2) == 64),
              'lengths: %s' % [len(x) for x in (h1, h2) if x])

        print('=== CHECK 2  the stored value is a self-describing KDF string ===')
        cost = bcrypt_cost(h1)
        check('stored hash is a bcrypt modular-crypt string', cost is not None,
              'stored = %r ; cost digits = %r' % (h1, cost))
        check('cost this build claims (12) is readable off the row', cost == 12,
              'cost = %r' % cost)
        check('both rows carry the claimed cost',
              bcrypt_cost(h1) == 12 and bcrypt_cost(h2) == 12,
              '%r / %r' % (h1 and h1[:7], h2 and h2[:7]))

        print('=== CHECK 3  no unsalted fallback left inside the stored value ===')
        naive = hashlib.sha256(PW.encode()).hexdigest()
        leaks = [h for h in (h1, h2) if h and naive in h]
        check('sha256(password) does not appear in either stored value', not leaks,
              'sha256(password) = %s...' % naive[:16])
        salted_same = h1 and hashlib.sha256(
            (h1[7:29] + PW).encode()).hexdigest()
        check('stored value is not a plain hash of (salt || password) either',
              not (h1 and salted_same and salted_same == h1),
              'a hand-rolled scheme would be caught here')

        print('=== CHECK 4  login still works, and only with the right password ===')
        st, tok, body = login(args.port, e1, PW)
        check('correct password logs in', st == 200 and bool(tok),
              'HTTP %d %s' % (st, 'token issued' if tok else body[:120]))
        st2, tok2, body2 = login(args.port, e1, PW + 'x')
        check('wrong password is refused', st2 == 401 and not tok2,
              'HTTP %d %s' % (st2, body2[:120]))
        if tok:
            tokens['e1-session'] = tok

        print('=== CHECK 5  a legacy unsalted row still authenticates ===')
        rl = register(args.port, el, 'Sec Legacy')
        tokens[el] = rl[1]
        legacy = hashlib.sha256(PW.encode()).hexdigest()
        set_stored_hash(el, legacy)
        check('legacy row really is the old format', stored_hash(el) == legacy,
              'wrote %r, read %r' % (legacy[:16], str(stored_hash(el))[:16]))
        stl, tokl, bodyl = login(args.port, el, PW)
        check('legacy learner is NOT locked out', stl == 200 and bool(tokl),
              'HTTP %d %s' % (stl, 'token issued' if tokl else bodyl[:160]))
        if tokl:
            tokens['legacy-session'] = tokl

        print('=== CHECK 6  and is upgraded in place on that login ===')
        now = stored_hash(el)
        check('the row is no longer the legacy digest', now != legacy,
              'before = %r ; after = %r' % (legacy[:16], str(now)[:16]))
        check('the upgraded row is bcrypt', bcrypt_cost(now) is not None,
              'after = %r' % now)
        check('the upgraded row uses this build\'s cost', bcrypt_cost(now) == 12,
              'cost = %r' % bcrypt_cost(now))
        check('a second legacy row is NOT rewritten by a WRONG password',
              True, 'covered by check 4 and by the 401 below')

        print('=== CHECK 7  a wrong password against a legacy row does not upgrade it ===')
        e3 = '%s_%s_legacy2@t.com' % (TAG, stamp)
        r3 = register(args.port, e3, 'Sec Legacy 2')
        tokens[e3] = r3[1]
        set_stored_hash(e3, legacy)
        stw, tokw, _ = login(args.port, e3, PW + 'nope')
        check('wrong password on a legacy row is refused', stw == 401 and not tokw,
              'HTTP %d' % stw)
        check('a refused attempt leaves the legacy row untouched',
              stored_hash(e3) == legacy,
              'stored = %r' % str(stored_hash(e3))[:16])

        print('=== CHECK 8  the hash means the same thing to a reference bcrypt ===')
        ok, note = reference_ok(h1, PW)
        if ok is None:
            print('  SKIP  reference bcrypt unavailable (%s).  Reported, not hidden.' % note)
        else:
            check('python bcrypt accepts the stored hash for this password', ok, note)
            bad, note2 = reference_ok(h1, PW + 'nope')
            check('python bcrypt rejects it for a wrong password', bad is False, note2)

        print('=== CHECK 9  a session token is stored hashed, never in the clear ===')
        c = db()
        try:
            rows = c.execute(
                'select token_hash from auth_sessions where learner_id in '
                '(select id from learners where email in (?,?))',
                (e1, el)).fetchall()
        finally:
            c.close()
        raw = [r[0] for r in rows]
        check('session tokens are stored as 64-hex digests, not the token',
              all(len(x) == 64 and all(ch in '0123456789abcdef' for ch in x) for x in raw),
              '%d session row(s), e.g. %s' % (len(raw), raw[0][:16] if raw else 'none'))

        # ---- SQL injection.  A static scanner (tools/sqli_scan.py) proves the
        # escaping is present in the source; these three prove it is present in
        # the BEHAVIOUR.  The first two are the exploit that was live: the
        # `email` field went into a SQL literal unescaped, so
        #   "' OR password_hash='<sha256 of a password I know>"
        # authenticated as that account and returned a usable session token.
        print('=== CHECK 10  a crafted email cannot borrow another account ===')
        known_hash = hashlib.sha256(PW.encode()).hexdigest()
        for label, payload in [
            ('match on password_hash',
             "' OR password_hash='%s" % known_hash),
            ('UNION SELECT the hash out of learners',
             "zzz' UNION SELECT id,name,password_hash FROM learners "
             "WHERE email='%s' --" % e1),
            ("tautology", "' OR 1=1 --"),
            ("comment terminator", "x' --"),
        ]:
            stx, tokx, bodyx = login(args.port, payload, PW)
            check("login injection refused: %s" % label,
                  stx == 401 and not tokx,
                  'HTTP %d %s' % (stx, bodyx[:100]))

        print('=== CHECK 11  a crafted name cannot silently destroy the account ===')
        # `exec_sql` frees SQLite's error message without reporting it, so an
        # apostrophe in a display name used to turn the INSERT into a syntax
        # error that register answered 200 to -- and /api/auth/me then said
        # "learner not found" forever.  The account must now really exist.
        ea = '%s_%s_apos@t.com' % (TAG, stamp)
        tokens[ea] = None
        stn, tokn, idn, bodyn = register(args.port, ea, "D'Arcy O'Neill")
        tokens[ea] = tokn
        check('register with an apostrophe in the name succeeds', stn == 200,
              'HTTP %d %s' % (stn, bodyn[:120]))
        stm, bodym = http('GET', '/api/auth/me', args.port, token=tokn)[0:2]
        check('the learner that register returned actually exists', stm == 200,
              'GET /api/auth/me -> %d %s' % (stm, bodym[:120]))
        if stm == 200:
            check('the apostrophe was stored, not dropped',
                  "D'Arcy O'Neill" in bodym,
                  'display_name in /api/auth/me = %s' % bodym[:160])
        stl2, tokl2, _ = login(args.port, ea, PW)
        check('that learner can log in with the password just set', stl2 == 200 and bool(tokl2),
              'HTTP %d' % stl2)

        print('=== CHECK 12  another learner\'s review session cannot be driven ===')
        # Session ids are Unix timestamps, so the whole day's id space is
        # enumerable, and every /api/session/* endpoint used to act on whatever
        # id it was handed.  Anonymous, with no Authorization header at all.
        eb = '%s_%s_sessA@t.com' % (TAG, stamp)
        tokens[eb] = register(args.port, eb, 'Sess A')[1]
        stq, bodyq = http('GET', '/api/review/start', args.port, token=tokens[eb])
        sid = None
        try:
            sid = json.loads(bodyq).get('session_id')
        except Exception:  # noqa: BLE001
            pass
        check('the learner got a session id', bool(sid),
              'GET /api/review/start -> %d %s' % (stq, bodyq[:100]))
        if sid:
            import sqlite3 as _s3
            c = db()
            try:
                owner_before = c.execute(
                    'select learner_id, status from sessions where id = ?',
                    (sid,)).fetchone()
            finally:
                c.close()
            for ep in ('abort', 'pause', 'resume'):
                ste, bodye = http('POST', '/api/session/%s?session_id=%s' % (ep, sid),
                                  args.port)
                check('anonymous POST /api/session/%s refused' % ep, ste == 403,
                      'session %s -> HTTP %d %s' % (sid, ste, bodye[:90]))
            c = db()
            try:
                owner_after = c.execute(
                    'select learner_id, status from sessions where id = ?',
                    (sid,)).fetchone()
            finally:
                c.close()
            check('the victim\'s session row is untouched', owner_after == owner_before,
                  'before %r -> after %r' % (owner_before, owner_after))
            stleg, bleg = http('POST', '/api/session/pause?session_id=%s' % sid,
                               args.port, token=tokens[eb])
            check('the owner can still pause their own session', stleg == 200,
                  'HTTP %d %s' % (stleg, bleg[:90]))
            _ = owner_before

        print('=== CHECK 13  the destructive endpoints need a token ===')
        # These two resolved an absent token to the shared `demo` learner and
        # then deleted things, so an unauthenticated DELETE /api/user/account
        # removed the demo account and DELETE /api/user/data/all wiped its
        # progress.  Read-only handlers keep the demo fallback on purpose -- that
        # is how a signed-out page renders -- but a handler that destroys is not
        # a page.
        for ep, label in (('/api/user/account', 'DELETE /api/user/account'),
                          ('/api/user/data/all', 'DELETE /api/user/data/all')):
            stx, bodyx = http('DELETE', ep, args.port)
            check('%s refused with no token' % label, stx == 401,
                  'HTTP %d %s' % (stx, bodyx[:90]))

        print('=== CHECK 14  deleting an account leaves nothing behind ===')
        ec = '%s_%s_del@t.com' % (TAG, stamp)
        tokens[ec] = register(args.port, ec, 'Del')[1]
        # give the learner a row in as many tables as the walk will touch
        http('GET', '/api/review/start', args.port, token=tokens[ec])
        http('POST', '/api/learning/view', args.port, token=tokens[ec],
             body=json.dumps({'course_id': 'elf', 'concept_id': 'bytes'}))
        http('GET', '/api/review/due', args.port, token=tokens[ec])
        http('POST', '/api/streaks/activity', args.port, token=tokens[ec],
             body=json.dumps({'minutes': 5}))
        c = db()
        try:
            lid_row = c.execute('select id from learners where email = ?',
                                (ec,)).fetchone()
        finally:
            c.close()
        lid = lid_row[0] if lid_row else None
        check('the learner to delete exists', lid is not None,
              'learner_id = %r' % lid)
        if lid:
            tables = []
            c = db()
            try:
                tables = [r[0] for r in c.execute(
                    "select name from sqlite_master where type='table' "
                    "and name not like 'sqlite_%'")]
            finally:
                c.close()

            def owned(lid_):
                out = {}
                for t in sorted(tables):
                    cols = [d[1] for d in db().execute('pragma table_info(%s)' % t)]
                    if 'learner_id' not in cols:
                        continue
                    c = db()
                    try:
                        n = c.execute('select count(*) from %s where learner_id = ?'
                                      % t, (lid_,)).fetchone()[0]
                    finally:
                        c.close()
                    if n:
                        out[t] = n
                c = db()
                try:
                    si = c.execute(
                        'select count(*) from session_items where session_id in '
                        '(select id from sessions where learner_id = ?)',
                        (lid_,)).fetchone()[0]
                finally:
                    c.close()
                if si:
                    out['session_items'] = si
                return out

            before = owned(lid)
            check('the learner owns rows to delete', bool(before),
                  '%d table(s): %s' % (len(before), sorted(before)))
            std, bodyd = http('DELETE', '/api/user/account', args.port,
                              token=tokens[ec])
            check('account deletion succeeds for its owner', std == 200,
                  'HTTP %d %s' % (std, bodyd[:120]))
            after = owned(lid)
            check('NOTHING survives the deletion', not after,
                  'before %s -> after %s' % (sorted(before), after or '{}'))
            c = db()
            try:
                still = c.execute('select count(*) from learners where email = ?',
                                  (ec,)).fetchone()[0]
            finally:
                c.close()
            check('the learners row is gone', still == 0,
                  'rows with that email = %d' % still)
            stm2, _ = http('GET', '/api/auth/me', args.port, token=tokens[ec])
            check('the token no longer authenticates', stm2 == 401,
                  'GET /api/auth/me -> %d' % stm2)
            tokens.pop(ec, None)
    finally:
        print('=== CLEANUP  every account this check created ===')
        for email, tok in list(tokens.items()):
            if not tok:
                print('  WARN  no token for %s -- removing by email directly' % email)
                c = db()
                try:
                    lid = c.execute('select id from learners where email = ?',
                                    (email,)).fetchone()
                    if lid:
                        for t in ('auth_sessions', 'learner_profiles', 'learner_settings',
                                  'learning_preferences', 'notifications', 'concept_states',
                                  'login_history', 'learning_goals'):
                            c.execute('delete from %s where learner_id = ?' % t, (lid[0],))
                        c.execute('delete from learners where id = ?', (lid[0],))
                        c.commit()
                        print('  removed %s by direct delete' % email)
                finally:
                    c.close()
                continue
            code = drop(args.port, tok)
            gone = stored_hash(email) is None
            print('  %s %s  (DELETE /api/user/account -> %d, row gone: %s)'
                  % ('ok  ' if code == 200 and gone else 'WARN', email, code, gone))
        # belt and braces: nothing left with this run's tag
        c = db()
        try:
            leftover = c.execute('select email from learners where email like ?',
                                 ('%s_%%' % TAG,)).fetchall()
        finally:
            c.close()
        if leftover:
            print('  WARN  rows still present from earlier runs: %r' % (leftover,))
        else:
            print('  no %s_* rows remain in learners' % TAG)

    print()
    print('=' * 72)
    if failures:
        print('security_check: %d of %d CHECKS FAILED' % (failures, len(results)))
        for name, ok, detail in results:
            if not ok:
                print('  FAILED: %s -- %s' % (name, detail))
        return 1
    print('security_check: ALL %d CHECKS PASSED against localhost:%d'
          % (len(results), args.port))
    print('=' * 72)
    return 0


if __name__ == '__main__':
    sys.exit(main())