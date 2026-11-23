# Make the search-hit sort safe: swap through copies and short mutable borrows.
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\search_scan.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

$t = $t.Replace('public func sort_hits(hits : &vector<SearchHit>) {',
                'public func sort_hits(hits : &mut vector<SearchHit>) {')
$t = $t.Replace('if(best != i) { swap_hits(hits, i, best) }',
                'if(best != i) { swap_hits(hits, i, best) }')

$start = $t.IndexOf('    // Element swap through pointers.')
if ($start -lt 0) { throw 'swap marker not found' }
$end = $t.IndexOf('}', $t.IndexOf('func swap_hits'))
# find the end of the swap_hits function: the matching final "    }" before the namespace close
$endMarker = "`n    }`n" # end of swap_hits
$endIdx = $t.IndexOf($endMarker, $start)
if ($endIdx -lt 0) { throw 'swap end marker not found' }

$block = @'
    // One hit, copied out.  `SearchHit` owns its strings, so a swap cannot move
    // through a borrow; it copies each side out and writes it back.
    func copy_hit(src : &SearchHit) : SearchHit {
        var out = SearchHit::make()
        out.score = src.score
        out.concept_title = src.concept_title.copy()
        out.concept_id = src.concept_id.copy()
        out.course_id = src.course_id.copy()
        out.course_title = src.course_title.copy()
        out.concept_description = src.concept_description.copy()
        out.module_title = src.module_title.copy()
        out.href = src.href.copy()
        out.matched_field = src.matched_field.copy()
        return out
    }

    // Swap two hits.  Each side is copied out, then written back under its own
    // short mutable borrow, so the two borrows never overlap.
    func swap_hits(hits : &mut vector<SearchHit>, i : size_t, j : size_t) {
        var a_copy = copy_hit(hits.at_ref(i))
        var b_copy = copy_hit(hits.at_ref(j))
        {
            var a = hits.at_mut(i)
            a.score = b_copy.score
            a.concept_title = b_copy.concept_title.copy()
            a.concept_id = b_copy.concept_id.copy()
            a.course_id = b_copy.course_id.copy()
            a.course_title = b_copy.course_title.copy()
            a.concept_description = b_copy.concept_description.copy()
            a.module_title = b_copy.module_title.copy()
            a.href = b_copy.href.copy()
            a.matched_field = b_copy.matched_field.copy()
        }
        {
            var b = hits.at_mut(j)
            b.score = a_copy.score
            b.concept_title = a_copy.concept_title.copy()
            b.concept_id = a_copy.concept_id.copy()
            b.course_id = a_copy.course_id.copy()
            b.course_title = a_copy.course_title.copy()
            b.concept_description = a_copy.concept_description.copy()
            b.module_title = a_copy.module_title.copy()
            b.href = a_copy.href.copy()
            b.matched_field = a_copy.matched_field.copy()
        }
    }
'@

$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n") + $t.Substring($endIdx + "`n    }".Length)
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))

# The caller passes a mutable vector.
$p2 = 'D:\Programming\Wiqis\Web\underlayer\web\src\search_walk.ch'
$t2 = [System.IO.File]::ReadAllText($p2).Replace("`r`n", "`n")
$t2 = $t2.Replace('sort_hits(&hits)', 'sort_hits(&mut hits)')
[System.IO.File]::WriteAllText($p2, $t2, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'search sort rewritten'

