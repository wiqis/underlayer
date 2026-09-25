#!/usr/bin/env python3
"""Fill in the per-concept metadata the three binary courses are missing.

The defect: all 72 ELF / PE / Mach-O concepts lack `estimated_minutes`,
`difficulty` and `importance`, so `repository/src/courses.ch` silently falls
back to its defaults (10 minutes / intermediate / core) for every one of them.
That misprices pacing in study plans, time budgets and analytics, and it makes
a 20-minute concept indistinguishable from a 10-minute one.

Where a value is already stated on the page, it is read from the page rather
than invented: PE and Mach-O concepts print their own duration in the
`lesson-meta` line, so the manifest is filled from that.

ELF pages print no duration at all, so its times come from an explicit,
documented rule keyed on the concept's place in the teaching order (see
DIFFICULTY / MINUTES below) rather than from a guess about content volume.

Usage: python3 tools/backfill_concept_metadata.py courses/
"""
import json
import os
import re
import sys

# ---- rule tables (documented; see docs/courses-todo.md) ----
#
# minutes/difficulty per module for ELF, which has no on-page duration.
# The order mirrors the teaching order: the spine of the format first, then the
# mechanisms that depend on it, then the runtime story that ties them together.
ELF_MODULES = {
    'fundamentals':     (12, 'beginner',    'core'),
    'elf-header':       (15, 'intermediate', 'core'),
    'program-headers':  (18, 'intermediate', 'core'),
    'sections':         (18, 'intermediate', 'core'),
    'symbols':          (15, 'intermediate', 'core'),
    'relocations':      (18, 'intermediate', 'core'),
    'dynamic-linking':  (20, 'advanced',     'core'),
    'loading':          (20, 'advanced',     'core'),
}
# Concepts that other lessons lean on but that a learner can skip and still
# follow the main thread. Marked supporting so analytics can tell them apart
# from the load-bearing spine.
ELF_SUPPORTING = {'file-layout', 'common-sections', 'visibility', 'dynamic-section'}

# PE and Mach-O print a section label as the third lesson-meta field. Those
# labels turned out to be far too coarse to drive difficulty (every concept in
# PE modules 1-3 is labelled "Foundation" or "Foundations", including the
# optional header and the data directories), so difficulty is taken from the
# concept's module position instead. In all three binary courses the modules
# are themselves ordered by difficulty, so position is the honest signal.
#
#   module 1        -> beginner      (what the format is, and the file layout)
#   modules 2 - 6   -> intermediate  (the structures and the linking machinery)
#   modules 7 - 8   -> advanced      (integrity, hardening, loading, execution)
def difficulty_by_module_index(index, total):
    if index == 1:
        return 'beginner'
    if index >= total - 1:
        return 'advanced'
    return 'intermediate'

META_RE = re.compile(r'lesson-meta">([^<]*)')
MIN_RE = re.compile(r'(\d+)\s*min\b')


def page_minutes(path):
    """Read the duration the page itself declares, or None."""
    try:
        src = open(path, encoding='utf-8').read()
    except OSError:
        return None
    m = META_RE.search(src)
    if not m:
        return None
    mm = MIN_RE.search(m.group(1))
    return int(mm.group(1)) if mm else None




def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'courses'
    src_dir = os.path.join('content', 'src')
    changed = 0
    for course in ('elf', 'pe', 'macho'):
        mpath = os.path.join(root, course, 'manifest.json')
        with open(mpath, encoding='utf-8') as f:
            data = json.load(f)
        mods = data.get('modules', [])
        modules = {m['id']: m for m in mods}
        order = {m['id']: i + 1 for i, m in enumerate(mods)}
        total = len(mods)
        touched = 0
        for c in data.get('concepts', []):
            before = (c.get('estimated_minutes'), c.get('difficulty'),
                      c.get('importance'))
            chfile = os.path.join(
                src_dir, c['id'].replace('-', '_') + '.ch')
            mins = page_minutes(chfile)
            if course == 'elf':
                # ELF pages declare no duration, so it comes from the module
                # table above (an explicit design decision, not a guess).
                mins, diff, imp = ELF_MODULES.get(
                    c.get('module_id'), (15, 'intermediate', 'core'))
                if c['id'] in ELF_SUPPORTING:
                    imp = 'supporting'
            else:
                # The duration is whatever the page itself prints.
                if mins is None:
                    mins = 15
                diff = difficulty_by_module_index(
                    order.get(c.get('module_id'), 1), total)
                imp = 'core'
            c['estimated_minutes'] = mins
            c['difficulty'] = diff
            c['importance'] = imp
            after = (mins, diff, imp)
            if before != after:
                touched += 1
        with open(mpath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        changed += touched
        spread = sorted({c['estimated_minutes'] for c in data['concepts']})
        diffs = sorted({c['difficulty'] for c in data['concepts']})
        print(f'{course}: filled {touched}/{len(data["concepts"])} concepts'
              f'  minutes={spread}  difficulty={diffs}')
    print(f'total concepts updated: {changed}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
