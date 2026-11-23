# The rate-limit gate call sites in app/main.ch: they became
# `if(!return fn(...)) { return }` when the `return` rewrite met the old `if(!` form.
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$pattern = 'if\(!return (underlayer_web::rate_limit_\w+\([^)]*\))\) \{ return \}'
$replacement = @'
var gate = $1
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
'@.Replace("`r`n", "`n")
$t = [regex]::Replace($t, $pattern, $replacement)
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ('remaining bad gates: ' + (Select-String -Path $p -Pattern 'if\(!return' | Measure-Object).Count)
