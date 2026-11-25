#!/usr/bin/env python3
"""Validate a native lesson JSON file against docs/native-lesson-contract.md.

Stdlib only. Use it on a curl response to catch producer drift:

    curl -s http://127.0.0.1:9007/api/courses/elf/lessons/bytes/native \
      -o build/bytes.native.json
    python tools/native_json_check.py build/bytes.native.json

`--self-test` checks every block type in memory (including a regression case
for the joined-header / double-wrapped-row table bug) without a server.

Strict mode rejects tag-looking text. A lesson that literally displays markup
(`&lt;code&gt;` in the source) decodes to `<code>` as plain text, so fleet-wide
audits can pass `--allow-literal-tags` to keep the shape checks only.
"""

import argparse
import json
import re
import sys

# Plain text may contain a decoded '<' (e.g. "a < b") but never an element.
TAG = re.compile(r"<\s*/?\s*[A-Za-z][A-Za-z0-9]*(?:\s[^<>]*)?>")
ALLOW_LITERAL_TAGS = False
TOP_KEYS = {
    "schema_version", "course_id", "concept_id", "title", "minutes",
    "difficulty", "prerequisite", "objective", "units",
}
UNIT_KEYS = {"id", "kind", "title", "order", "remember", "blocks"}
# type -> {field: rule}; unknown types are allowed by the contract (clients
# ignore them) but a known type must match its frozen shape exactly.
BLOCKS = {
    "paragraph": {"text": "text"},
    "heading": {"level": "level", "text": "text"},
    "code": {"text": "text", "language": "str_none"},
    "list": {"ordered": "bool", "items": "strings"},
    "table": {"headers": "strings", "rows": "matrix"},
    "quiz": {"id": "text", "question": "text", "options": "options",
             "correct_index": "index", "explanation": "text"},
    "hex": {"bytes": "strings", "labels": "strings", "mode": "mode"},
    "fill_blank": {"text": "text", "blanks": "blanks"},
    "callout": {"variant": "text", "text": "text"},
}


def err(errors, path, msg):
    errors.append("{}: {}".format(path, msg))


def keys(obj, expected, path, errors):
    if not isinstance(obj, dict):
        err(errors, path, "expected object")
        return False
    if set(obj) != expected:
        err(errors, path, "keys mismatch (missing {}, extra {})".format(
            sorted(expected - set(obj)), sorted(set(obj) - expected)))
        return False
    return True


def text(v, path, errors):
    if not isinstance(v, str):
        err(errors, path, "expected string")
    elif TAG.search(v) and not ALLOW_LITERAL_TAGS:
        err(errors, path, "raw HTML tag in plain text: {!r}".format(v[:60]))


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def array(v, path, errors, item):
    if not isinstance(v, list):
        err(errors, path, "expected array")
        return
    for i, value in enumerate(v):
        item(value, "{}[{}]".format(path, i), errors)


def options(v, path, errors):
    def one(opt, p, e):
        if keys(opt, {"text", "explanation"}, p, e):
            text(opt["text"], p + ".text", e)
            text(opt["explanation"], p + ".explanation", e)
    array(v, path, errors, one)


def blanks(v, path, errors):
    def one(blank, p, e):
        if keys(blank, {"id", "answer", "position"}, p, e):
            text(blank["id"], p + ".id", e)
            text(blank["answer"], p + ".answer", e)
            if not is_int(blank["position"]):
                err(e, p + ".position", "expected integer")
    array(v, path, errors, one)


RULES = {
    "text": text,
    "level": lambda v, p, e: (None if is_int(v) and v in (3, 4)
                              else err(e, p, "expected 3 or 4")),
    "str_none": lambda v, p, e: (None if v is None else text(v, p, e)),
    "bool": lambda v, p, e: None if isinstance(v, bool) else err(e, p, "expected bool"),
    "strings": lambda v, p, e: array(v, p, e, text),
    "matrix": lambda v, p, e: array(v, p, e, lambda row, rp, re_: array(row, rp, re_, text)),
    "options": options,
    "blanks": blanks,
    "index": lambda v, p, e: (None if is_int(v) and v >= -1
                              else err(e, p, "expected integer >= -1")),
    "mode": lambda v, p, e: (None if v in ("dump", "interactive")
                             else err(e, p, "expected 'dump' or 'interactive'")),
}


def check_block(block, path, errors):
    if not isinstance(block, dict) or "type" not in block:
        err(errors, path, "expected object with a type")
        return
    kind = block["type"]
    if kind not in BLOCKS:
        return  # forward-compatible: clients ignore unknown types
    if not keys(block, {"type"} | set(BLOCKS[kind]), path, errors):
        return
    for field, rule in BLOCKS[kind].items():
        RULES[rule](block[field], "{}.{}".format(path, field), errors)


def check(doc, errors):
    if not keys(doc, TOP_KEYS, "root", errors):
        return errors
    if doc["schema_version"] != 1 or not is_int(doc["schema_version"]):
        err(errors, "root.schema_version", "expected 1")
    for field in ("course_id", "concept_id", "title", "difficulty", "objective"):
        text(doc[field], "root." + field, errors)
    if not is_int(doc["minutes"]):
        err(errors, "root.minutes", "expected number")
    if doc["prerequisite"] is not None:
        text(doc["prerequisite"], "root.prerequisite", errors)
    if not isinstance(doc["units"], list):
        err(errors, "root.units", "expected array")
        return errors
    for i, unit in enumerate(doc["units"]):
        path = "root.units[{}]".format(i)
        if not keys(unit, UNIT_KEYS, path, errors):
            continue
        for field in ("id", "kind", "title", "remember"):
            text(unit[field], path + "." + field, errors)
        if not is_int(unit["order"]):
            err(errors, path + ".order", "expected number")
        array(unit["blocks"], path + ".blocks", errors, check_block)
    return errors


def self_test():
    global ALLOW_LITERAL_TAGS
    ALLOW_LITERAL_TAGS = False  # self-test always exercises the strict check
    blocks = [
        {"type": "paragraph", "text": "A byte has 8 bits."},
        {"type": "heading", "level": 3, "text": "Detail"},
        {"type": "code", "text": "int x = 1;\n", "language": None},
        {"type": "list", "ordered": False, "items": ["one", "two"]},
        {"type": "table", "headers": ["Decimal", "Hex"],
         "rows": [["0", "0x00"], ["65", "0x41"]]},
        {"type": "quiz", "id": "q1", "question": "Which byte?", "correct_index": 1,
         "options": [{"text": "0", "explanation": "no"},
                     {"text": "65", "explanation": "yes"}], "explanation": "yes"},
        {"type": "hex", "bytes": ["7f"], "labels": ["127"], "mode": "interactive"},
        {"type": "fill_blank", "text": "{{0}} bits",
         "blanks": [{"id": "b1", "answer": "8", "position": 0}]},
        {"type": "callout", "variant": "tip", "text": "A quote: \" and a \\ slash"},
    ]
    doc = {"schema_version": 1, "course_id": "elf", "concept_id": "bytes",
           "title": "Bytes", "minutes": 10, "difficulty": "beginner",
           "prerequisite": None, "objective": "Read a byte.",
           "units": [{"id": "unit-model", "kind": "model", "title": "Model",
                      "order": 1, "remember": "8 bits", "blocks": blocks}]}
    if check(doc, []):
        print("SELF-TEST FAIL: valid fixture rejected")
        return 1
    broken = json.loads(json.dumps(doc))
    broken["units"][0]["blocks"][4] = {
        "type": "table", "headers": ["Decimal Hex"], "rows": [[["0", "0x00"]]]}
    if not check(broken, []):
        print("SELF-TEST FAIL: joined header / double-wrapped row accepted")
        return 1
    html = json.loads(json.dumps(doc))
    html["units"][0]["blocks"][0]["text"] = "<p>not plain text</p>"
    if not check(html, []):
        print("SELF-TEST FAIL: raw HTML in text accepted")
        return 1
    print("self-test: 9 block types pass; broken table and raw HTML rejected")
    return 0


def main():
    global ALLOW_LITERAL_TAGS
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("json_file", nargs="?")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--allow-literal-tags", action="store_true")
    args = ap.parse_args()
    ALLOW_LITERAL_TAGS = args.allow_literal_tags
    if args.self_test:
        return self_test()
    if not args.json_file:
        ap.error("provide a JSON file or --self-test")
    with open(args.json_file, encoding="utf-8") as f:
        doc = json.load(f)
    errors = check(doc, [])
    if errors:
        for e in errors:
            print("FAIL " + e)
        print("{} contract error(s) in {}".format(len(errors), args.json_file))
        return 1
    counts = {}
    for unit in doc["units"]:
        for block in unit["blocks"]:
            counts[block.get("type")] = counts.get(block.get("type"), 0) + 1
    print("OK {}: {} unit(s), block types: {}".format(
        args.json_file, len(doc["units"]),
        ", ".join("{}={}".format(k, v) for k, v in sorted(counts.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
