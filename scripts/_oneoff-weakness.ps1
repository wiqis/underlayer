# Split the read/write borrows in cluster_weaknesses (learning/src/weakness.ch).
$path = 'D:\Programming\Wiqis\Web\underlayer\learning\src\weakness.ch'
$t = [System.IO.File]::ReadAllText($path)

$old = @'
            // Find existing cluster for this prefix
            var found = false
            var ci : size_t = 0
            while(ci < clusters.size()) {
                var cluster = clusters.at_mut(ci)
                var prefix_copy = prefix.copy()
                if(cluster.module_prefix.equals(&prefix_copy)) {
                    cluster.weak_concepts.push(w.concept_id.copy())
                    cluster.count = cluster.count + 1
                    cluster.avg_severity = (cluster.avg_severity * ((cluster.count - 1) as f64) + (w.severity as f64)) / (cluster.count as f64)
                    found = true
                }
                ci = ci + 1
            }
'@

$new = @'
            // Find existing cluster for this prefix.  The match is decided on a
            // read borrow and the update happens on a separate, short write
            // borrow: holding one `&mut` element across the test is what
            // SAFE-BORROW-001 rejects, and splitting them is also how the lock
            // rules read (find under one borrow, mutate under the next).
            var found = false
            var ci : size_t = 0
            while(ci < clusters.size()) {
                var prefix_copy = prefix.copy()
                var matched = false
                {
                    var cluster = clusters.at_ref(ci)
                    if(cluster.module_prefix.equals(&prefix_copy)) { matched = true }
                }
                if(matched) {
                    var cluster = clusters.at_mut(ci)
                    cluster.weak_concepts.push(w.concept_id.copy())
                    cluster.count = cluster.count + 1
                    cluster.avg_severity = (cluster.avg_severity * ((cluster.count - 1) as f64) + (w.severity as f64)) / (cluster.count as f64)
                    found = true
                    break
                }
                ci = ci + 1
            }
'@

$oldN = $old.Replace("`r`n", "`n")
$tN = $t.Replace("`r`n", "`n")
if (-not $tN.Contains($oldN)) { throw 'old block not found' }
$tN = $tN.Replace($oldN, $new.Replace("`r`n", "`n"))
[System.IO.File]::WriteAllText($path, $tN, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'cluster_weaknesses borrow split'
