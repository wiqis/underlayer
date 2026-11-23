# Add libm wrappers to learning/src/fsrs.ch and rewrite the math call sites to
# use them.
$path = 'D:\Programming\Wiqis\Web\underlayer\learning\src\fsrs.ch'
$t = [System.IO.File]::ReadAllText($path)

$wrappers = @'
    // ---- libm boundary ----
    //
    // `exp`, `log` and `pow` are C library functions, so calling them is an FFI
    // operation and must be marked as one.  These three wrappers are the whole
    // boundary: the FSRS formulas below read as maths, and the `unsafe` count is
    // three lines in one place instead of nine scattered through the scheduler.
    private func m_exp(x : f64) : f64 {
        return unsafe(exp(x))
    }

    private func m_log(x : f64) : f64 {
        return unsafe(log(x))
    }

    private func m_pow(base : f64, exponent : f64) : f64 {
        return unsafe(pow(base, exponent))
    }

'@

$marker = '    public func fsrs_retrievability('
$idx = $t.IndexOf($marker)
if ($idx -lt 0) { throw 'marker not found' }
$t = $t.Substring(0, $idx) + $wrappers.Replace("`r`n", "`n") + $t.Substring($idx)

# Rewrite call sites: `pow(` -> `m_pow(`, `exp(` -> `m_exp(`, `log(` -> `m_log(`,
# but only where they are plain calls (not already `m_`-prefixed and not Math.*).
$t = [regex]::Replace($t, '(?<![A-Za-z_.])exp\(', 'm_exp(')
$t = [regex]::Replace($t, '(?<![A-Za-z_.])log\(', 'm_log(')
$t = [regex]::Replace($t, '(?<![A-Za-z_.])pow\(', 'm_pow(')
# The wrappers themselves were rewritten above; restore their bodies.
$t = $t.Replace('return unsafe(m_exp(x))', 'return unsafe(exp(x))')
$t = $t.Replace('return unsafe(m_log(x))', 'return unsafe(log(x))')
$t = $t.Replace('return unsafe(m_pow(base, exponent))', 'return unsafe(pow(base, exponent))')

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $t, $enc)
Write-Output 'fsrs math wrappers installed'
