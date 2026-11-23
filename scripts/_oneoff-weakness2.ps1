# Rewrite cluster_weaknesses so the cluster update happens through a small
# helper that owns the only mutable borrow (SAFE-BORROW-001).
$path = 'D:\Programming\Wiqis\Web\underlayer\learning\src\weakness.ch'
$t = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$startMarker = '    public func cluster_weaknesses('
$endMarker = '    public func '
$start = $t.IndexOf($startMarker)
if ($start -lt 0) { throw 'start marker not found' }
$end = $t.IndexOf($endMarker, $start + 10)
if ($end -lt 0) { throw 'end marker not found' }

$block = @'
    // One cluster, updated in place.  The write is a separate function so that
    // the mutable borrow of `clusters` it takes cannot overlap the read borrow
    // the caller used to decide which cluster to touch.
    private func add_report_to_cluster(clusters : &mut vector<WeaknessCluster>, index : size_t, concept_id : &string, severity : f64) {
        var target = clusters.at_mut(index)
        target.weak_concepts.push(concept_id.copy())
        var n = target.count + 1
        target.count = n
        target.avg_severity = (target.avg_severity * ((n - 1) as f64) + severity) / (n as f64)
    }

    public func cluster_weaknesses(weaknesses : &vector<WeaknessReport>) : vector<WeaknessCluster> {
        var clusters = vector<WeaknessCluster>()
        var i : size_t = 0
        while(i < weaknesses.size()) {
            var w = weaknesses.at_ref(i)
            // Extract module prefix (before first dot)
            var prefix = string()
            var j : size_t = 0
            while(j < w.concept_id.size()) {
                var c = w.concept_id.at(j)
                if(c == '.') { break }
                prefix.append(c)
                j = j + 1
            }
            // Which existing cluster (if any) is this report's?
            var match_index = clusters.size()
            var ci : size_t = 0
            while(ci < clusters.size()) {
                var prefix_copy = prefix.copy()
                var cluster = clusters.at_ref(ci)
                if(cluster.module_prefix.equals(&prefix_copy)) {
                    match_index = ci
                    break
                }
                ci = ci + 1
            }
            var cid = w.concept_id.copy()
            var sev = w.severity as f64
            var have_cluster = match_index < clusters.size()
            if(have_cluster) {
                add_report_to_cluster(&mut clusters, match_index, &cid, sev)
            } else {
                var new_cluster = WeaknessCluster::make()
                new_cluster.module_prefix = prefix.copy()
                new_cluster.weak_concepts.push(cid.copy())
                new_cluster.count = 1
                new_cluster.avg_severity = sev
                clusters.push(new_cluster)
            }
            i = i + 1
        }
        return clusters
    }

'@

$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n") + $t.Substring($end)
[System.IO.File]::WriteAllText($path, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'cluster_weaknesses rewritten'
