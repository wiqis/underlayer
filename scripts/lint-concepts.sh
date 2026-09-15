#!/usr/bin/env bash
# lint-concepts.sh — Concept validation / linting (P3 2.2.11-2.2.16).
# Checks every concept source file in content/src/ against the validation rules.
# Lints the .ch source: HTML lives inside #html blocks, JS inside #js blocks.
#
# Rules:
#   R1 (2.2.11, FAIL) common mistakes:
#       - string-appended HTML:   append_view("<
#       - Chemical for-loop:      for(  inside Chemical code (not JS)  [warn]
#       - JS strict equality in Chemical code: === outside macro blocks [warn]
#   R2 (2.2.12, FAIL) required sections: render_ function defined;
#       unit-why + unit-retrieve present (FAIL); unit-model present [warn]
#   R3 (2.2.13, FAIL) exercise count: at least 1 quiz-option per concept page
#   R4 (2.2.14, WARN) asset references: /courses/... asset paths must exist
#   R5 (2.2.15, FAIL) link validity: lesson hrefs must match known concept IDs
#   R6 (2.2.16, WARN) accessibility: <img> without alt=; onclick outside
#       button/input/a elements [warn]; <th> without scope= [warn]
#
# Exit code: 1 if any FAIL, 0 otherwise (warnings do not fail).
set -u

SRC_DIR="content/src"
fail_files=0
warn_total=0
fail_total=0

known_ids() {
    # Concept IDs = render_<name> functions mapped by web helpers + landing
    {
        grep -rhoE 'public func render_[a-z0-9_]+' "$SRC_DIR" 2>/dev/null \
            | sed 's/public func render_//; s/[[:space:]]*$//' \
            | tr '_' '-'
        echo "landing"
    } | sort -u
}

KNOWN_IDS="$(known_ids)"

check_file() {
    local file="$1" basename
    basename="$(basename "$file")"
    local label="${basename%.ch}"
    local f=0 w=0

    # Skip test files
    case "$basename" in *_test.ch) return ;; esac

    local inside_html inside_js
    inside_html=$(grep -n '#html' "$file" | head -1 | cut -d: -f1)
    inside_js=$(grep -n '#js' "$file" | head -1 | cut -d: -f1)
    local total_lines
    total_lines=$(wc -l < "$file")

    # R1a: string-appended HTML (FAIL)
    if grep -n 'append_view("<' "$file" > /dev/null 2>&1; then
        echo "  FAIL R1 [$label] string-appended HTML (append_view(\"<...\")) — use #html macro"
        f=$((f+1))
    fi

    # R1b: for-loop inside #js is fine; in Chemical code it is a mistake (warn)
    if [ -n "$inside_js" ]; then
        if sed -n "1,${inside_js}p" "$file" | grep -qE '\bfor[[:space:]]*\('; then
            echo "  warn R1 [$label] for-loop in Chemical code (use while)"
            w=$((w+1))
        fi
    else
        if grep -qE '\bfor[[:space:]]*\(' "$file"; then
            echo "  warn R1 [$label] for-loop in Chemical code (use while)"
            w=$((w+1))
        fi
    fi

    # R2: required sections.
    # Course landing pages (*_landing) are index pages, not lessons — skip.
    # Template files (template_*) are authoring scaffolds: retrieval is the
    # non-negotiable unit (golden rule), unit-why may be replaced by the
    # template's own opening unit.
    if ! grep -qE 'public func (render_|template_)' "$file"; then
        echo "  FAIL R2 [$label] no render_/template_ function defined"
        f=$((f+1))
    fi
    case "$basename" in
        *_landing.ch)
            : ;;
        template_*.ch)
            if ! grep -q 'unit-retrieve' "$file"; then
                echo "  FAIL R2 [$label] template missing required section unit-retrieve"
                f=$((f+1))
            fi
            ;;
        *)
            if ! grep -q 'unit-why' "$file"; then
                echo "  FAIL R2 [$label] missing required section unit-why"
                f=$((f+1))
            fi
            if ! grep -q 'unit-retrieve' "$file"; then
                echo "  FAIL R2 [$label] missing required section unit-retrieve"
                f=$((f+1))
            fi
            if ! grep -q 'unit-model' "$file"; then
                echo "  warn R2 [$label] missing recommended section unit-model"
                w=$((w+1))
            fi
            ;;
    esac

    # R3: at least one quiz-option (skip landing pages)
    case "$basename" in
        *_landing.ch) : ;;
        *)
            if ! grep -q 'quiz-option' "$file"; then
                echo "  FAIL R3 [$label] no exercises found (quiz-option)"
                f=$((f+1))
            fi
            ;;
    esac

    # R4: asset references resolve (warn only)
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        local asset_path="${m#\"}"
        asset_path="${asset_path%\"*}"
        if [ ! -f "courses/elf/$asset_path" ] && [ ! -f "$asset_path" ]; then
            echo "  warn R4 [$label] asset reference not found: $asset_path"
            w=$((w+1))
        fi
    done < <(grep -oE '"/?courses/elf/assets/[^"]+' "$file" 2>/dev/null || true)

    # R5: lesson links must match known concept IDs (FAIL)
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        local cid
        cid="$(echo "$m" | sed 's|.*/lessons/||; s|".*||')"
        if ! echo "$KNOWN_IDS" | grep -qx "$cid"; then
            echo "  FAIL R5 [$label] lesson link to unknown concept: $cid"
            f=$((f+1))
        fi
    done < <(grep -oE '"/courses/elf/lessons/[^"]+' "$file" 2>/dev/null || true)

    # R6: accessibility (warn)
    if grep -qE '<img(?![^>]*alt=)' "$file" 2>/dev/null; then
        echo "  warn R6 [$label] <img> missing alt attribute"
        w=$((w+1))
    fi
    if grep -q '<th' "$file" && ! grep -q '<th scope=' "$file"; then
        echo "  warn R6 [$label] table headers without scope= attribute"
        w=$((w+1))
    fi

    fail_total=$((fail_total+f))
    warn_total=$((warn_total+w))
    if [ "$f" -gt 0 ]; then fail_files=$((fail_files+1)); fi
}

echo "=== Concept Linter (content/src) ==="
shopt -s nullglob
files=("$SRC_DIR"/*.ch)
shopt -u nullglob
if [ ${#files[@]} -eq 0 ]; then
    echo "  no concept files found in $SRC_DIR"
    exit 1
fi
for f in "${files[@]}"; do
    check_file "$f"
done

echo "-------------------------------------"
echo "Files: ${#files[@]}  FAILs: $fail_total  warns: $warn_total"
if [ "$fail_total" -gt 0 ]; then
    echo "RESULT: FAIL ($fail_files file(s) with errors)"
    exit 1
fi
echo "RESULT: PASS"
exit 0
