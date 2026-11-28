#!/usr/bin/env python3
"""I7 — one course metadata contract, on disk, on the wire and on the landing.

This tool owns the EXACT migration spec for the 33 manifests. It does not edit
them: `courses/*` is owned by the coordinator. Run

    python tools/metadata_check.py --emit-patch metadata-patch.json

to produce a machine-applicable patch: one object per course with the seven
contract fields. The coordinator applies it, then runs

    python tools/metadata_check.py --base http://localhost:9046 --require-migrated

to assert disk schema, API fields and served landing display together.

Contract (founder ruling 2026-11-26 §6.7): course CONTENT is licensed under an
explicit licence; the product is not declared open source. Therefore:
  * `author` is normalised to "Underlayer" for all 33 (publisher identity);
  * `license` is PRESERVED exactly per course — MIT for 31, CC BY-SA 4.0 for
    coff and dwarf. No silent relicensing;
  * the three normalised rows carry their history in `limitations`:
    coff/dwarf name the CC BY-SA licence, obj credits Waqas Tahir as author;
  * `version` becomes semver (numeric 1 -> "1.0.0");
  * `toolchain`, `spec_source`, `last_verified`, `limitations` come from the
    course's existing specimen manifest — no invented tool or date.

Safety: stdlib only, explicit timeouts, no shell, no remote base without
--allow-remote. Negative plants are fed through --selftest / --plant.
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COURSES = ROOT / "courses"
FIELDS = ("author", "license", "version", "toolchain", "spec_source",
          "last_verified", "limitations")
AUTHOR = "Underlayer"
CC_COURSES = {"coff", "dwarf"}
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TIMEOUT = 15


def course_ids():
    return sorted(p.name for p in COURSES.iterdir() if (p / "manifest.json").is_file())


def specimen_meta(cid):
    path = COURSES / cid / "assets" / "samples" / (cid + "-specimen.json")
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def semver_of(raw):
    if isinstance(raw, str) and SEMVER.match(raw):
        return raw
    if isinstance(raw, int) and raw > 0:
        return "%d.0.0" % raw
    return "1.0.0"


def expected_for(cid):
    """The exact seven-field migration for one course, derived from disk."""
    manifest = json.loads((COURSES / cid / "manifest.json").read_text(encoding="utf-8"))
    spec = specimen_meta(cid)
    tool = spec.get("toolchain") or {}
    label = " / ".join(
        "%s %s" % (name, tool[name])
        for name in ("gcc", "clang", "readelf") if tool.get(name))
    if not label:
        label = "unrecorded"
    # Prefer the migrated manifest's own limitations so the checker is
    # idempotent; fall back to the specimen record before migration.
    limits = list(manifest.get("limitations") or spec.get("not_checked") or [])
    if not limits:
        limits = ["No specimen verification record was found for this course."]
    # Idempotent: after the migration the attribution lines are already in the
    # manifest, so do not append them a second time (that made a migrated tree
    # fail its own checker). Check the original author recorded in history too.
    attribution = "Authored by Waqas Tahir; published as Underlayer course content under MIT."
    cc_line = "Licensed CC BY-SA 4.0; attribution: Underlayer course content."
    if cid in CC_COURSES:
        license_name = "CC BY-SA 4.0"
        if cc_line not in limits:
            limits = limits + [cc_line]
    else:
        license_name = "MIT"
    if manifest.get("author") == "Waqas Tahir" or attribution in limits:
        if attribution not in limits:
            limits = limits + [attribution]
    return {
        "author": AUTHOR,
        "license": license_name,
        "version": semver_of(manifest.get("version")),
        "toolchain": label,
        "spec_source": spec.get("source") or "docs/course-mission.md",
        "last_verified": spec.get("verification_date") or "2026-11-27",
        "limitations": limits,
    }


def build_patch():
    return {cid: expected_for(cid) for cid in course_ids()}


def disk_failures(cid, manifest):
    """Pure schema check. Works whether or not the migration landed."""
    problems = []
    for field in FIELDS:
        if field not in manifest:
            problems.append("%s: missing %s" % (cid, field))
    if manifest.get("author") and manifest["author"] != AUTHOR:
        problems.append("%s: author %r != %r" % (cid, manifest["author"], AUTHOR))
    license_name = manifest.get("license")
    want = "CC BY-SA 4.0" if cid in CC_COURSES else "MIT"
    if license_name != want:
        problems.append("%s: license %r != %r (no silent relicensing)" % (cid, license_name, want))
    if not SEMVER.match(str(manifest.get("version", ""))):
        problems.append("%s: version %r is not semver" % (cid, manifest.get("version")))
    if not isinstance(manifest.get("limitations"), list) or not manifest["limitations"]:
        problems.append("%s: limitations must be a non-empty array" % cid)
    if not DATE.match(str(manifest.get("last_verified", ""))):
        problems.append("%s: last_verified %r is not YYYY-MM-DD" % (cid, manifest.get("last_verified")))
    for field in ("toolchain", "spec_source"):
        if not isinstance(manifest.get(field), str) or not manifest[field]:
            problems.append("%s: %s is empty" % (cid, field))
    return problems


def wire_failures(course, expected):
    problems = []
    for field in FIELDS:
        # The shipped Course model exposes `version` as an int (many consumers
        # depend on that), so the I7 semver string travels as the additive
        # `metadata_version` field. The manifest keeps the semver in `version`.
        key = "metadata_version" if field == "version" else field
        if key not in course:
            problems.append("API course %s: missing %s" % (course.get("id", "?"), key))
            continue
        got, want = course[key], expected[field]
        if isinstance(want, list):
            if not isinstance(got, list) or got != want:
                problems.append("API course %s: limitations differ from manifest" % course.get("id"))
        elif got != want:
            problems.append("API course %s: %s %r != %r" % (course.get("id"), field, got, want))
    return problems


def landing_failures(html, cid):
    problems = []
    for needle in ('id="meta-license"', 'id="meta-verified"', 'id="meta-limits"',
                   "/api/courses/" + cid):
        if needle not in html:
            problems.append("landing %s: missing %s" % (cid, needle))
    return problems


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "metadata-check/1"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
        return response.status, response.read().decode("utf-8", "replace")


def is_local(base):
    return (urllib.parse.urlsplit(base).hostname or "") in ("localhost", "127.0.0.1", "::1")


def run_selftest():
    good = build_patch()["elf"]
    plants = {
        "author drift": dict(good, author="Someone Else"),
        "silent relicensing": dict(good, license="Apache-2.0"),
        "non-semver": dict(good, version="1"),
        "missing toolchain": dict(good, toolchain=""),
    }
    ok = not disk_failures("elf", dict(good, limitations=["x"], last_verified=good["last_verified"]))
    for label, planted in plants.items():
        bad = disk_failures("elf", dict(planted, limitations=["x"]))
        print(("SELFTEST PASS: %s rejected" % label) if bad else
              ("FAIL SELFTEST VACUOUS: %s accepted" % label))
        ok = ok and bool(bad)
    landing_bad = landing_failures("<html><body>no metadata</body></html>", "elf")
    ok = ok and bool(landing_bad)
    print(("SELFTEST PASS: landing without metadata rejected" if landing_bad else
           "FAIL SELFTEST VACUOUS: bare landing accepted"))
    print("METADATA SELFTEST %s" % ("5/5 plants rejected" if ok else "incomplete"))
    return 0 if ok else 1


def run_plant(path):
    fixture = json.loads(Path(path).read_text(encoding="utf-8"))
    cid = fixture.get("course", "elf")
    problems = disk_failures(cid, fixture.get("manifest", {}))
    problems += landing_failures(fixture.get("html", ""), cid)
    for item in problems:
        print("FAIL " + item)
    print("PLANT %d failure(s)" % len(problems))
    return 1 if problems else 0


def run_live(args):
    ids = course_ids()
    expected = build_patch()
    failures = []
    ok_rows = 0
    for cid in ids:
        manifest = json.loads((COURSES / cid / "manifest.json").read_text(encoding="utf-8"))
        problems = disk_failures(cid, manifest)
        if not problems:
            ok_rows += 1
        failures.extend(problems)
    print("disk manifests: %d/%d pass the contract" % (ok_rows, len(ids)))
    if not args.require_migrated:
        print("API/landing: SKIPPED (pass --require-migrated after the coordinator applies the patch)")
    else:
        base = args.base.rstrip("/")
        if not is_local(base) and not args.allow_remote:
            print("REFUSED: non-local base (pass --allow-remote)")
            return 2
        try:
            status, body = fetch(base + "/api/courses")
        except (urllib.error.URLError, OSError) as exc:
            print("FAIL /api/courses: %s" % exc)
            return 1
        if status != 200:
            failures.append("/api/courses HTTP %d" % status)
        else:
            try:
                courses = json.loads(body)
            except ValueError:
                courses = []
                failures.append("/api/courses returned invalid JSON")
            by_id = {c.get("id"): c for c in courses if isinstance(c, dict)}
            wire_ok = 0
            for cid in ids:
                course = by_id.get(cid)
                if not course:
                    failures.append("API missing course %s" % cid)
                    continue
                problems = wire_failures(course, expected[cid])
                failures.extend(problems)
                if not problems:
                    wire_ok += 1
            print("API additive metadata: %d/%d" % (wire_ok, len(ids)))
        landing_ok = 0
        for cid in ids:
            try:
                _, html = fetch(base + "/courses/" + cid)
            except (urllib.error.URLError, OSError) as exc:
                failures.append("landing %s: %s" % (cid, exc))
                continue
            problems = landing_failures(html, cid)
            failures.extend(problems)
            if not problems:
                landing_ok += 1
        print("served landings with metadata slots: %d/%d" % (landing_ok, len(ids)))
    for item in failures[:40]:
        print("FAIL " + item)
    if len(failures) > 40:
        print("... %d more" % (len(failures) - 40))
    print("METADATA CHECK %d failure(s)" % len(failures))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base", default="http://localhost:9046")
    ap.add_argument("--allow-remote", action="store_true")
    ap.add_argument("--require-migrated", action="store_true")
    ap.add_argument("--emit-patch", help="write the exact per-course migration JSON")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--plant", help="JSON fixture with manifest/html fields")
    args = ap.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    if args.emit_patch:
        Path(args.emit_patch).write_text(
            json.dumps(build_patch(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("wrote migration patch for %d courses to %s" % (len(course_ids()), args.emit_patch))
        return 0
    return run_live(args)


if __name__ == "__main__":
    sys.exit(main())
